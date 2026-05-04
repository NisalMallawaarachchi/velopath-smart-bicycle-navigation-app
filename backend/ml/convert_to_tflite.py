"""
convert_to_tflite.py
Converts a trained Keras CNN or LSTM model to TFLite format for on-device
inference in the Flutter app.

Usage:
    python convert_to_tflite.py --model cnn     # default
    python convert_to_tflite.py --model lstm

Output:
    model_versions/hazard_detector.tflite
    Copy this file to mobile_app/assets/ml/hazard_detector.tflite
"""

import os
import argparse
import json
import numpy as np

try:
    import tensorflow as tf
    TF_AVAILABLE = True
except ImportError:
    TF_AVAILABLE = False

SCRIPT_DIR  = os.path.dirname(os.path.abspath(__file__))
MODELS_DIR  = os.path.join(SCRIPT_DIR, 'model_versions')
OUTPUT_PATH = os.path.join(MODELS_DIR, 'hazard_detector.tflite')
META_PATH   = os.path.join(MODELS_DIR, 'tflite_meta.json')


def convert(model_type: str = 'cnn'):
    if not TF_AVAILABLE:
        print("❌ TensorFlow not installed: pip install tensorflow")
        return

    model_path = os.path.join(MODELS_DIR, f'{model_type}_model.h5')
    if not os.path.exists(model_path):
        print(f"❌ {model_path} not found. Run train_cnn_lstm.py first.")
        return

    print(f"Loading {model_type.upper()} model from {model_path}…")
    model = tf.keras.models.load_model(model_path)
    model.summary()

    print("\nConverting to TFLite (float32 + dynamic range quantization)…")
    converter = tf.lite.TFLiteConverter.from_keras_model(model)
    converter.optimizations = [tf.lite.Optimize.DEFAULT]
    tflite_model = converter.convert()

    os.makedirs(MODELS_DIR, exist_ok=True)
    with open(OUTPUT_PATH, 'wb') as f:
        f.write(tflite_model)

    size_kb = os.path.getsize(OUTPUT_PATH) / 1024
    print(f"✅ TFLite model saved → {OUTPUT_PATH}  ({size_kb:.1f} KB)")

    # Save metadata Flutter needs for inference
    norm_mean_path = os.path.join(MODELS_DIR, 'norm_mean.npy')
    norm_std_path  = os.path.join(MODELS_DIR, 'norm_std.npy')

    meta = {
        'model_type':  model_type,
        'window_size': 10,
        'n_channels':  6,
        'channel_order': ['accelX', 'accelY', 'accelZ', 'gyroX', 'gyroY', 'gyroZ'],
        'label_names': ['smooth', 'pothole', 'bump', 'rough'],
    }

    if os.path.exists(norm_mean_path) and os.path.exists(norm_std_path):
        mean = np.load(norm_mean_path).flatten().tolist()
        std  = np.load(norm_std_path).flatten().tolist()
        meta['norm_mean'] = mean
        meta['norm_std']  = std
        print("✅ Normalisation stats embedded in metadata")

    with open(META_PATH, 'w') as f:
        json.dump(meta, f, indent=2)
    print(f"✅ Metadata saved → {META_PATH}")

    print(f"""
Next steps:
  1. Copy the TFLite model to Flutter assets:
       cp {OUTPUT_PATH}
          mobile_app/assets/ml/hazard_detector.tflite

  2. Copy the metadata:
       cp {META_PATH}
          mobile_app/assets/ml/tflite_meta.json

  3. The OnDeviceHazardDetector in Flutter will load these files
     and run inference without a backend call (fully offline).
""")


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--model', choices=['cnn', 'lstm'], default='cnn',
                        help='Which model to convert (default: cnn)')
    args = parser.parse_args()
    convert(args.model)


if __name__ == '__main__':
    main()
