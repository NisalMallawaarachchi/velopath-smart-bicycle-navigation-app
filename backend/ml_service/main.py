"""
ml_service/main.py
FastAPI microservice for road hazard detection.

Replaces the Python subprocess approach in hazardController.js.
The model is loaded ONCE at startup and stays in memory — no per-request
process spawn, no disk reload, no cold-start latency.

Endpoints:
    GET  /health          — liveness + model info
    POST /predict         — run inference on sensor readings
    POST /reload          — hot-reload model.pkl without restarting

Latency improvement:
    subprocess approach : ~1000-3000 ms (process spawn + model load each call)
    FastAPI approach    : ~10-50 ms (model already in memory, HTTP round-trip)

Run locally:
    pip install fastapi uvicorn joblib scikit-learn numpy
    uvicorn main:app --host 0.0.0.0 --port 8001 --reload

Railway deployment:
    Add as a separate service, Root Directory = backend/ml_service
    Start Command: uvicorn main:app --host 0.0.0.0 --port $PORT
"""

import os
import sys
import json
import time
import logging
from typing import List, Optional, Dict, Any
from contextlib import asynccontextmanager

import numpy as np
import joblib
from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel, field_validator

# Ensure we can import preprocess.py from the parent ml/ directory
ML_DIR = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', 'ml')
sys.path.insert(0, ML_DIR)

from preprocess import preprocess_for_prediction   # noqa: E402

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger("ml_service")

MODEL_PATH = os.path.join(ML_DIR, 'model.pkl')

# ── In-memory model state ─────────────────────────────────────────────────────
_model_state: Dict[str, Any] = {
    'model':         None,
    'feature_names': None,
    'label_names':   ['smooth', 'pothole', 'bump', 'rough'],
    'version':       None,
    'loaded_at':     None,
    'metrics':       {},
}


def _load_model():
    if not os.path.exists(MODEL_PATH):
        logger.warning(f"model.pkl not found at {MODEL_PATH} — service running without model")
        return False
    try:
        data = joblib.load(MODEL_PATH)
        _model_state['model']         = data['model']
        _model_state['feature_names'] = data.get('feature_names', [])
        _model_state['label_names']   = data.get('label_names', ['smooth','pothole','bump','rough'])
        _model_state['version']       = data.get('version')
        _model_state['metrics']       = data.get('metrics', {})
        _model_state['loaded_at']     = int(time.time())
        logger.info(f"Model loaded — version {_model_state['version']}, "
                    f"accuracy {_model_state['metrics'].get('accuracy', 'N/A')}")
        return True
    except Exception as e:
        logger.error(f"Failed to load model: {e}")
        return False


@asynccontextmanager
async def lifespan(app: FastAPI):
    _load_model()
    yield


# ── App ───────────────────────────────────────────────────────────────────────
app = FastAPI(
    title="VeloPath ML Hazard Detection Service",
    description="Road hazard classification from bicycle IMU sensor data",
    version="2.0.0",
    lifespan=lifespan,
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)


# ── Request / Response models ─────────────────────────────────────────────────

class SensorReading(BaseModel):
    timestamp:  Optional[str]   = None
    accelX:     float
    accelY:     float
    accelZ:     float
    gyroX:      float
    gyroY:      float
    gyroZ:      float
    magX:       Optional[float] = None
    magY:       Optional[float] = None
    magZ:       Optional[float] = None
    latitude:   Optional[float] = None
    longitude:  Optional[float] = None
    speed_kmh:  Optional[float] = 20.0
    label:      Optional[str]   = None

    @field_validator('accelX', 'accelY', 'accelZ', 'gyroX', 'gyroY', 'gyroZ')
    @classmethod
    def must_be_finite(cls, v):
        if not np.isfinite(v):
            raise ValueError('sensor value must be finite (not NaN or Inf)')
        return v


class PredictRequest(BaseModel):
    sensorData:         List[SensorReading]
    deviceId:           Optional[str]   = None
    calibration_bias:   Optional[Dict[str, float]] = None   # {bias_x, bias_y, bias_z}


class PredictionResult(BaseModel):
    window_index:   int
    reading_index:  int
    hazard_type:    str
    confidence:     float
    latitude:       Optional[float]
    longitude:      Optional[float]
    timestamp:      Optional[str]


class PredictResponse(BaseModel):
    success:      bool
    predictions:  List[PredictionResult]
    summary:      Dict[str, Any]
    latency_ms:   float


# ── Endpoints ─────────────────────────────────────────────────────────────────

@app.get("/health")
def health():
    model_ok = _model_state['model'] is not None
    return {
        "status":       "ok" if model_ok else "degraded",
        "model_loaded": model_ok,
        "model_version": _model_state['version'],
        "model_accuracy": _model_state['metrics'].get('accuracy'),
        "loaded_at":    _model_state['loaded_at'],
        "approach":     "fastapi_in_memory",
        "latency_note": "model is loaded once at startup — no per-request spawn",
    }


@app.post("/predict", response_model=PredictResponse)
def predict(req: PredictRequest):
    t0 = time.perf_counter()

    if _model_state['model'] is None:
        raise HTTPException(status_code=503, detail="Model not loaded. Check /health.")

    if len(req.sensorData) < 10:
        raise HTTPException(status_code=400, detail="Need at least 10 sensor readings.")

    # Convert Pydantic models to dicts for preprocess.py
    data = [r.model_dump() for r in req.sensorData]

    bias = req.calibration_bias  # may be None — preprocess handles that

    X, feature_names, window_indices = preprocess_for_prediction(data, bias)

    if X.shape[0] == 0:
        raise HTTPException(status_code=422, detail="No valid windows extracted from sensor data.")

    model        = _model_state['model']
    label_names  = _model_state['label_names']

    y_pred  = model.predict(X)
    y_proba = model.predict_proba(X)

    predictions = []
    hazard_counts: Dict[str, int] = {}

    for i, (pred_idx, proba, win_idx) in enumerate(zip(y_pred, y_proba, window_indices)):
        label      = label_names[pred_idx] if pred_idx < len(label_names) else 'unknown'
        confidence = float(np.max(proba))

        # Representative reading for GPS/timestamp
        rep_idx = min(win_idx, len(data) - 1)
        rep     = data[rep_idx]

        hazard_counts[label] = hazard_counts.get(label, 0) + 1

        predictions.append(PredictionResult(
            window_index  = i,
            reading_index = win_idx,
            hazard_type   = label,
            confidence    = round(confidence, 4),
            latitude      = rep.get('latitude'),
            longitude     = rep.get('longitude'),
            timestamp     = rep.get('timestamp'),
        ))

    hazard_locs = [p for p in predictions if p.hazard_type != 'smooth']

    latency_ms = (time.perf_counter() - t0) * 1000

    return PredictResponse(
        success     = True,
        predictions = predictions,
        summary     = {
            'total_windows':    len(predictions),
            'hazard_counts':    hazard_counts,
            'hazards_detected': len(hazard_locs),
            'hazard_locations': [p.model_dump() for p in hazard_locs],
        },
        latency_ms = round(latency_ms, 2),
    )


@app.post("/reload")
def reload_model():
    """Hot-reload model.pkl without restarting the service."""
    ok = _load_model()
    if ok:
        return {"success": True, "version": _model_state['version'],
                "message": "Model reloaded successfully"}
    raise HTTPException(status_code=500, detail="Failed to reload model — check logs")
