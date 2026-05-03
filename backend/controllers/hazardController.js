// hazardController.js
// Controller for road hazard detection using Python ML model

import { spawn } from "child_process";
import path from "path";
import { fileURLToPath } from "url";
import fs from "fs";
import pool from "../config/db.js";

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

const PYTHON_PATH = process.env.PYTHON_PATH || "python3";
const ML_DIR = path.join(__dirname, "..", "ml");

// Serialises concurrent writes to training_data.json — prevents race condition
let _trainingWriteLock = Promise.resolve();

function safeUnlink(filePath) {
  try { fs.unlinkSync(filePath); } catch (_) { /* already gone */ }
}

function spawnPython(tempFile) {
  return new Promise((resolve, reject) => {
    const proc = spawn(PYTHON_PATH, ["predict.py", tempFile], { cwd: ML_DIR });
    let stdout = "";
    let stderr = "";
    proc.stdout.on("data", (d) => { stdout += d.toString(); });
    proc.stderr.on("data", (d) => { stderr += d.toString(); });
    proc.on("close", (code) => {
      safeUnlink(tempFile);
      if (code !== 0) return reject(new Error(stderr || "Python process failed"));
      try {
        resolve(JSON.parse(stdout));
      } catch {
        reject(new Error(`Failed to parse ML output: ${stdout.slice(0, 200)}`));
      }
    });
    proc.on("error", (err) => {
      safeUnlink(tempFile);
      reject(err);
    });
  });
}

/**
 * Health check for ML service
 */
export const healthCheck = async (req, res) => {
  try {
    const modelPath = path.join(ML_DIR, "model.pkl");
    const modelExists = fs.existsSync(modelPath);

    res.json({
      status: "ok",
      mlServiceAvailable: modelExists,
      pythonPath: PYTHON_PATH,
      modelPath: modelPath,
    });
  } catch (error) {
    res.status(500).json({
      status: "error",
      message: error.message,
    });
  }
};

/**
 * Predict hazards from sensor data
 * Expects body: { sensorData: [...] }
 */
export const predictHazard = async (req, res) => {
  try {
    const { sensorData } = req.body;
    console.log(`\n📥 ═══════════════════════════════════════`);
    console.log(`📥 [PREDICT] Received ${sensorData?.length || 0} sensor readings`);
    console.log(`📥 Device: ${req.body.deviceId || 'unknown'}`);
    console.log(`📥 ═══════════════════════════════════════`);

    if (!sensorData || !Array.isArray(sensorData)) {
      return res.status(400).json({
        success: false,
        error: "Invalid request: sensorData array required",
      });
    }

    if (sensorData.length < 10) {
      return res.status(400).json({
        success: false,
        error: "Need at least 10 sensor readings for prediction",
      });
    }

    const tempFile = path.join(ML_DIR, `temp_${Date.now()}_${Math.random().toString(36).slice(2)}.json`);
    fs.writeFileSync(tempFile, JSON.stringify(sensorData));

    try {
      const result = await spawnPython(tempFile);

      console.log(`🤖 [ML RESULT] Predictions: ${result.predictions?.length || 0} total`);
      const hazardPreds = result.predictions?.filter(p => p.hazard_type !== 'smooth') || [];
      console.log(`🤖 [ML RESULT] Hazards found: ${hazardPreds.length}`);
      hazardPreds.forEach(h =>
        console.log(`   🔴 ${h.hazard_type} at (${h.latitude}, ${h.longitude}) conf=${h.confidence}`)
      );

      await saveDetectionsToDB(result, req.body.deviceId);
      res.json(result);
    } catch (mlError) {
      console.error("ML prediction error:", mlError.message);
      res.status(500).json({ success: false, error: "ML prediction failed", details: mlError.message });
    }
  } catch (error) {
    res.status(500).json({ success: false, error: error.message });
  }
};

/**
 * Get demo prediction using pre-generated demo session
 */
export const getDemoPredict = async (req, res) => {
  try {
    const demoFile = path.join(ML_DIR, "demo_session.json");

    if (!fs.existsSync(demoFile)) {
      return res.status(404).json({
        success: false,
        error: "Demo session not found. Run generate_data.py first.",
      });
    }

    try {
      const result = await spawnPython(demoFile);
      res.json(result);
    } catch (mlError) {
      console.error("Demo ML prediction error:", mlError.message);
      res.status(500).json({ success: false, error: "ML prediction failed", details: mlError.message });
    }
  } catch (error) {
    res.status(500).json({ success: false, error: error.message });
  }
};

/**
 * Upload labeled sensor data for prediction or training
 * Expects body: { sensorData: [...], mode: 'predict' | 'train' }
 */
export const uploadLabeledData = async (req, res) => {
  try {
    console.log(`\n📥 ═══════════════════════════════════════`);
    console.log(`📥 [UPLOAD] Received sensor data upload`);
    console.log(`📥 Mode: ${req.body.mode}`);
    console.log(`📥 Data points: ${req.body.sensorData?.length || 0}`);
    console.log(`📥 Device: ${req.body.deviceId || 'unknown'}`);
    console.log(`📥 ═══════════════════════════════════════`);
    
    const { sensorData, mode } = req.body;

    if (!sensorData || !Array.isArray(sensorData)) {
      console.log("Γ¥î Invalid request: no sensorData array");
      return res.status(400).json({
        success: false,
        error: "Invalid request: sensorData array required",
      });
    }

    if (!mode || !["predict", "train"].includes(mode)) {
      console.log("Γ¥î Invalid mode:", mode);
      return res.status(400).json({
        success: false,
        error: "Invalid request: mode must be 'predict' or 'train'",
      });
    }

    if (sensorData.length < 10) {
      console.log(" Not enough data:", sensorData.length);
      return res.status(400).json({
        success: false,
        error: "Need at least 10 sensor readings",
      });
    }

    // Check if data has labels
    const hasLabels = sensorData.some((r) => r.label && r.label !== "smooth");
    
    if (mode === "train") {
      // TRAIN MODE: Append data to training_data.json
      // Serialised via _trainingWriteLock to prevent race conditions on concurrent uploads
      const trainingFile = path.join(ML_DIR, "training_data.json");
      let totalReadings = 0;

      _trainingWriteLock = _trainingWriteLock.then(async () => {
        let existingData = [];
        if (fs.existsSync(trainingFile)) {
          try {
            existingData = JSON.parse(fs.readFileSync(trainingFile, "utf-8"));
          } catch (e) {
            console.error("Failed to read existing training data:", e);
          }
        }
        const newData = [...existingData, ...sensorData];
        fs.writeFileSync(trainingFile, JSON.stringify(newData, null, 2));
        totalReadings = newData.length;
      });
      await _trainingWriteLock;
      const newData = { length: totalReadings }; // only need length for response

      // Count labels
      const labelCounts = {};
      for (const reading of sensorData) {
        const label = reading.label || "smooth";
        labelCounts[label] = (labelCounts[label] || 0) + 1;
      }

      return res.json({
        success: true,
        mode: "train",
        message: "Data added to training set",
        stats: {
          addedReadings: sensorData.length,
          totalReadings: newData.length,
          labelCounts: labelCounts,
          hasLabels: hasLabels,
        },
      });
      // end of lock scope
    } else {
      // PREDICT MODE: Run ML prediction
      const tempFile = path.join(ML_DIR, `temp_${Date.now()}_${Math.random().toString(36).slice(2)}.json`);
      fs.writeFileSync(tempFile, JSON.stringify(sensorData));

      try {
        const result = await spawnPython(tempFile);
        result.mode = "predict";
        result.inputHadLabels = hasLabels;

        console.log(`🤖 [ML RESULT] Total predictions: ${result.predictions?.length || 0}`);
        const hazardPreds = result.predictions?.filter(p => p.hazard_type !== 'smooth') || [];
        console.log(`🤖 [ML RESULT] Hazards detected: ${hazardPreds.length}`);
        hazardPreds.forEach(h =>
          console.log(`   🔴 ${h.hazard_type} at (${h.latitude}, ${h.longitude}) conf=${h.confidence}`)
        );
        console.log(`   🟢 Smooth readings: ${(result.predictions?.length || 0) - hazardPreds.length}`);

        await saveDetectionsToDB(result, req.body.deviceId);
        res.json(result);
      } catch (mlError) {
        console.error("ML prediction error:", mlError.message);
        res.status(500).json({ success: false, error: "ML prediction failed", details: mlError.message });
      }
    }
  } catch (error) {
    res.status(500).json({
      success: false,
      error: error.message,
    });
  }
};

/**
 * Save non-smooth ML predictions to ml_detections table.
 * The DetectionProcessor cron job will pick these up and create/update hazards.
 */
async function saveDetectionsToDB(result, deviceId) {
  if (!result?.success || !result?.predictions) return;

  // Only save actual hazards (not smooth)
  const hazards = result.predictions.filter(
    (p) => p.hazard_type !== "smooth" && p.latitude && p.longitude
  );

  if (hazards.length === 0) {
    console.log(`💾 [DB SAVE] No hazards to save (all readings were smooth)`);
    return;
  }

  console.log(`\n💾 ═══════════════════════════════════════`);
  console.log(`💾 [DB SAVE] Saving ${hazards.length} hazard detections to ml_detections table`);

  try {
    const client = await pool.connect();
    try {
      for (const h of hazards) {
        await client.query(
          `INSERT INTO ml_detections (latitude, longitude, hazard_type, detection_confidence, device_id)
           VALUES ($1, $2, $3, $4, $5)`,
          [
            h.latitude,
            h.longitude,
            h.hazard_type,
            h.confidence || 0.85,
            deviceId || "unknown",
          ]
        );
        console.log(`   ✅ Saved: ${h.hazard_type} at (${h.latitude}, ${h.longitude})`);
      }
      console.log(`💾 [DB SAVE] All ${hazards.length} detections saved successfully!`);
      console.log(`💾 ═══════════════════════════════════════\n`);
      console.log(`⏳ Cron job will process these into hazards within 30 seconds...\n`);
    } finally {
      client.release();
    }
  } catch (err) {
    console.error("❌ [DB SAVE] Failed to save detections:", err.message);
  }
}
