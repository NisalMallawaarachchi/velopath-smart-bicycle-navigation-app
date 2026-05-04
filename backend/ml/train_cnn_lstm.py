"""
train_cnn_lstm.py
Trains CNN and LSTM models for road hazard detection and compares them
against the baseline Random Forest.

Usage:
    python train_cnn_lstm.py

Outputs:
    model_versions/cnn_model.h5   — best CNN weights
    model_versions/lstm_model.h5  — best LSTM weights
    model_versions/comparison_<timestamp>.json — accuracy comparison table
"""

import os
import json
import time
import numpy as np
import joblib
from collections import Counter

os.environ['TF_CPP_MIN_LOG_LEVEL'] = '2'  # suppress TF info logs

try:
    import tensorflow as tf
    from tensorflow import keras
    from tensorflow.keras import layers
    TF_AVAILABLE = True
except ImportError:
    TF_AVAILABLE = False
    print("⚠  TensorFlow not installed. Install with: pip install tensorflow")
    print("   Random Forest comparison will still run.\n")

from sklearn.ensemble import RandomForestClassifier
from sklearn.metrics import classification_report, accuracy_score
from preprocess import create_sliding_windows

LABEL_MAP   = {'smooth': 0, 'pothole': 1, 'bump': 2, 'rough': 3}
LABEL_NAMES = ['smooth', 'pothole', 'bump', 'rough']
WINDOW_SIZE = 10
STRIDE      = 5
N_CHANNELS  = 6   # accelX/Y/Z + gyroX/Y/Z
MODELS_DIR  = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'model_versions')


# ── Data preparation ──────────────────────────────────────────────────────────

def load_raw_windows(data_path: str):
    """
    Load training data and build raw sensor windows (no feature engineering).
    Returns (X_raw, y, X_feat, y_feat) for sequence models and RF respectively.

    X_raw shape: (n_windows, WINDOW_SIZE, N_CHANNELS)
    """
    with open(data_path) as f:
        raw = json.load(f)

    try:
        raw = sorted(raw, key=lambda r: r.get('timestamp', ''))
    except Exception:
        pass

    split = int(len(raw) * 0.8)
    train_raw = raw[:split]
    test_raw  = raw[split:]

    def build_raw(data):
        wins = create_sliding_windows(data, WINDOW_SIZE, STRIDE)
        X, y = [], []
        for window, label in wins:
            if label not in LABEL_MAP:
                continue
            channels = []
            for r in window:
                channels.append([
                    r.get('accelX', 0), r.get('accelY', 0), r.get('accelZ', 0),
                    r.get('gyroX',  0), r.get('gyroY',  0), r.get('gyroZ',  0),
                ])
            X.append(channels)
            y.append(LABEL_MAP[label])
        return np.array(X, dtype=np.float32), np.array(y)

    def build_features(data):
        from preprocess import preprocess_for_training
        X, labels, _ = preprocess_for_training(data)
        y = np.array([LABEL_MAP[l] for l in labels if l in LABEL_MAP])
        mask = np.array([l in LABEL_MAP for l in labels])
        return X[mask], y

    X_train_raw, y_train = build_raw(train_raw)
    X_test_raw,  y_test  = build_raw(test_raw)
    X_train_feat, y_train_feat = build_features(train_raw)
    X_test_feat,  y_test_feat  = build_features(test_raw)

    return (X_train_raw, y_train, X_test_raw, y_test,
            X_train_feat, y_train_feat, X_test_feat, y_test_feat)


# ── Model builders ────────────────────────────────────────────────────────────

def build_cnn():
    """
    1D-CNN: captures local temporal patterns (pothole spike shape).
    Two conv layers with max-pooling → dense classification head.
    """
    inp = keras.Input(shape=(WINDOW_SIZE, N_CHANNELS))
    x   = layers.Conv1D(32, kernel_size=3, activation='relu', padding='same')(inp)
    x   = layers.BatchNormalization()(x)
    x   = layers.Conv1D(64, kernel_size=3, activation='relu', padding='same')(x)
    x   = layers.GlobalMaxPooling1D()(x)
    x   = layers.Dense(64, activation='relu')(x)
    x   = layers.Dropout(0.3)(x)
    out = layers.Dense(len(LABEL_MAP), activation='softmax')(x)
    model = keras.Model(inp, out, name='CNN_HazardDetector')
    model.compile(
        optimizer=keras.optimizers.Adam(1e-3),
        loss='sparse_categorical_crossentropy',
        metrics=['accuracy'],
    )
    return model


def build_lstm():
    """
    LSTM: captures temporal dependencies across the full 2-second window.
    Bidirectional LSTM → dense classification head.
    """
    inp = keras.Input(shape=(WINDOW_SIZE, N_CHANNELS))
    x   = layers.Bidirectional(layers.LSTM(32, return_sequences=True))(inp)
    x   = layers.Bidirectional(layers.LSTM(16))(x)
    x   = layers.Dense(32, activation='relu')(x)
    x   = layers.Dropout(0.3)(x)
    out = layers.Dense(len(LABEL_MAP), activation='softmax')(x)
    model = keras.Model(inp, out, name='LSTM_HazardDetector')
    model.compile(
        optimizer=keras.optimizers.Adam(1e-3),
        loss='sparse_categorical_crossentropy',
        metrics=['accuracy'],
    )
    return model


# ── Training ──────────────────────────────────────────────────────────────────

def train_keras_model(model, X_train, y_train, X_test, y_test, epochs=30):
    cb = [
        keras.callbacks.EarlyStopping(patience=5, restore_best_weights=True),
        keras.callbacks.ReduceLROnPlateau(factor=0.5, patience=3, verbose=0),
    ]
    model.fit(
        X_train, y_train,
        validation_data=(X_test, y_test),
        epochs=epochs,
        batch_size=32,
        callbacks=cb,
        verbose=0,
    )
    y_pred = np.argmax(model.predict(X_test, verbose=0), axis=1)
    acc    = float(accuracy_score(y_test, y_pred))
    return acc, y_pred


def train_rf(X_train, y_train, X_test, y_test):
    rf = RandomForestClassifier(n_estimators=100, max_depth=10,
                                min_samples_split=5, min_samples_leaf=2,
                                random_state=42, n_jobs=-1)
    rf.fit(X_train, y_train)
    y_pred = rf.predict(X_test)
    acc    = float(accuracy_score(y_test, y_pred))
    return acc, y_pred, rf


# ── Main ──────────────────────────────────────────────────────────────────────

def main():
    script_dir = os.path.dirname(os.path.abspath(__file__))
    data_path  = os.path.join(script_dir, 'training_data.json')
    os.makedirs(MODELS_DIR, exist_ok=True)

    if not os.path.exists(data_path):
        print("❌ training_data.json not found. Run generate_training_data.py first.")
        return

    print("=" * 60)
    print("CNN vs LSTM vs Random Forest — Hazard Detection Comparison")
    print("=" * 60)
    print("Loading data…")

    (X_train_raw, y_train, X_test_raw, y_test,
     X_train_feat, y_train_feat, X_test_feat, y_test_feat) = load_raw_windows(data_path)

    print(f"Raw windows  — train: {len(X_train_raw)}, test: {len(X_test_raw)}")
    print(f"Feature vecs — train: {len(X_train_feat)}, test: {len(X_test_feat)}")
    dist = Counter(y_train.tolist())
    print("Train label dist:", {LABEL_NAMES[k]: v for k, v in sorted(dist.items())})
    print()

    results = {}

    # ── Random Forest ─────────────────────────────────────────────────────────
    print("Training Random Forest…")
    rf_acc, rf_pred, rf_model = train_rf(X_train_feat, y_train_feat,
                                          X_test_feat, y_test_feat)
    results['RandomForest'] = rf_acc
    print(f"  RF Test Accuracy: {rf_acc * 100:.2f}%")
    print(classification_report(y_test_feat, rf_pred,
                                 target_names=LABEL_NAMES, zero_division=0))

    if TF_AVAILABLE:
        # Normalize raw windows for neural nets
        mean = X_train_raw.mean(axis=(0, 1), keepdims=True)
        std  = X_train_raw.std(axis=(0, 1), keepdims=True) + 1e-8
        X_tr_n = (X_train_raw - mean) / std
        X_te_n = (X_test_raw  - mean) / std

        # ── CNN ───────────────────────────────────────────────────────────────
        print("Training CNN…")
        cnn = build_cnn()
        cnn_acc, cnn_pred = train_keras_model(cnn, X_tr_n, y_train, X_te_n, y_test)
        results['CNN'] = cnn_acc
        print(f"  CNN Test Accuracy: {cnn_acc * 100:.2f}%")
        print(classification_report(y_test, cnn_pred,
                                     target_names=LABEL_NAMES, zero_division=0))

        cnn_path = os.path.join(MODELS_DIR, 'cnn_model.h5')
        cnn.save(cnn_path)
        print(f"  Saved → {cnn_path}")

        # ── LSTM ──────────────────────────────────────────────────────────────
        print("\nTraining LSTM…")
        lstm = build_lstm()
        lstm_acc, lstm_pred = train_keras_model(lstm, X_tr_n, y_train, X_te_n, y_test)
        results['LSTM'] = lstm_acc
        print(f"  LSTM Test Accuracy: {lstm_acc * 100:.2f}%")
        print(classification_report(y_test, lstm_pred,
                                     target_names=LABEL_NAMES, zero_division=0))

        lstm_path = os.path.join(MODELS_DIR, 'lstm_model.h5')
        lstm.save(lstm_path)
        print(f"  Saved → {lstm_path}")

        # Save normalisation stats alongside models
        np.save(os.path.join(MODELS_DIR, 'norm_mean.npy'), mean)
        np.save(os.path.join(MODELS_DIR, 'norm_std.npy'),  std)

    # ── Summary ───────────────────────────────────────────────────────────────
    print("\n" + "=" * 60)
    print("Model Comparison Summary")
    print("=" * 60)
    best_model = max(results, key=results.get)
    for name, acc in sorted(results.items(), key=lambda x: -x[1]):
        marker = " ← BEST" if name == best_model else ""
        print(f"  {name:15s}: {acc * 100:.2f}%{marker}")

    comparison = {
        'timestamp': int(time.time()),
        'results':   results,
        'best':      best_model,
        'train_size': len(X_train_raw),
        'test_size':  len(X_test_raw),
    }
    comp_path = os.path.join(MODELS_DIR, f'comparison_{comparison["timestamp"]}.json')
    with open(comp_path, 'w') as f:
        json.dump(comparison, f, indent=2)
    print(f"\nComparison saved → {comp_path}")

    if best_model != 'RandomForest':
        print(f"\n💡 {best_model} outperforms Random Forest.")
        if best_model == 'CNN':
            print("   Convert to TFLite: python convert_to_tflite.py --model cnn")
        elif best_model == 'LSTM':
            print("   Convert to TFLite: python convert_to_tflite.py --model lstm")


if __name__ == '__main__':
    main()
