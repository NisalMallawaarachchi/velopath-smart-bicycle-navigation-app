"""
Preprocessing Module for Road Hazard Detection
Extracts statistical features from raw sensor windows for ML classification.
"""

import numpy as np
import json
from typing import List, Dict, Any, Optional


def extract_features_from_window(readings: List[Dict[str, Any]]) -> Dict[str, float]:
    """Extract statistical features from a window of sensor readings."""
    if not readings:
        return {}

    accel_x = np.array([r['accelX'] for r in readings])
    accel_y = np.array([r['accelY'] for r in readings])
    accel_z = np.array([r['accelZ'] for r in readings])
    gyro_x  = np.array([r['gyroX']  for r in readings])
    gyro_y  = np.array([r['gyroY']  for r in readings])
    gyro_z  = np.array([r['gyroZ']  for r in readings])

    accel_mag = np.sqrt(accel_x**2 + accel_y**2 + accel_z**2)
    gyro_mag  = np.sqrt(gyro_x**2  + gyro_y**2  + gyro_z**2)

    accel_z_jerk = np.diff(accel_z) if len(accel_z) > 1 else np.array([0.0])

    return {
        # Accelerometer magnitude
        'accel_mag_mean':  float(np.mean(accel_mag)),
        'accel_mag_std':   float(np.std(accel_mag)),
        'accel_mag_max':   float(np.max(accel_mag)),
        'accel_mag_min':   float(np.min(accel_mag)),
        'accel_mag_range': float(np.max(accel_mag) - np.min(accel_mag)),

        # Z-axis (vertical) — most discriminative for potholes/bumps
        'accel_z_mean':  float(np.mean(accel_z)),
        'accel_z_std':   float(np.std(accel_z)),
        'accel_z_max':   float(np.max(accel_z)),
        'accel_z_min':   float(np.min(accel_z)),
        'accel_z_range': float(np.max(accel_z) - np.min(accel_z)),

        # Jerk (rate of change of acceleration) — captures sudden impacts
        'accel_z_jerk_max':  float(np.max(np.abs(accel_z_jerk))),
        'accel_z_jerk_mean': float(np.mean(np.abs(accel_z_jerk))),

        # Gyroscope
        'gyro_mag_mean': float(np.mean(gyro_mag)),
        'gyro_mag_std':  float(np.std(gyro_mag)),
        'gyro_mag_max':  float(np.max(gyro_mag)),

        # Gyro X (pitch) — front wheel dropping into a pothole
        'gyro_x_max':   float(np.max(np.abs(gyro_x))),
        'gyro_x_range': float(np.max(gyro_x) - np.min(gyro_x)),
    }


def _priority_label(labels: List[Optional[str]]) -> Optional[str]:
    """
    Any-hazard labeling strategy: if any reading in a window is a hazard,
    the whole window is labeled with the most severe hazard present.

    Priority order (highest first): pothole > bump > rough > smooth

    Rationale: for safety-critical detection, maximising recall over precision
    is preferred — missing a pothole is worse than a false positive.
    """
    priority = {'pothole': 3, 'bump': 2, 'rough': 1, 'smooth': 0}
    best = None
    best_score = -1
    for lbl in labels:
        if lbl is None:
            continue
        score = priority.get(lbl, 0)
        if score > best_score:
            best_score = score
            best = lbl
    return best


def create_sliding_windows(readings: List[Dict], window_size: int = 10, stride: int = 5):
    """
    Create overlapping windows from a sequence of sensor readings.

    Returns list of (window_data, label) tuples where the label is determined
    by the any-hazard strategy: the most severe label across all readings in
    the window (not just the middle reading).
    """
    windows = []
    for i in range(0, len(readings) - window_size + 1, stride):
        window = readings[i:i + window_size]
        labels_in_window = [r.get('label') for r in window]
        label = _priority_label(labels_in_window)
        windows.append((window, label))
    return windows


def preprocess_for_training(data: List[Dict]) -> tuple:
    """
    Preprocess labeled sensor data for model training.

    Returns (feature_matrix X, labels list, feature_names list).
    """
    windows = create_sliding_windows(data, window_size=10, stride=5)

    features_list = []
    labels = []

    for window_data, label in windows:
        if label is not None:
            features = extract_features_from_window(window_data)
            if features:
                features_list.append(features)
                labels.append(label)

    if not features_list:
        return np.array([]), [], []

    feature_names = list(features_list[0].keys())
    X = np.array([[f[name] for name in feature_names] for f in features_list])

    return X, labels, feature_names


def preprocess_for_prediction(data: List[Dict]) -> tuple:
    """
    Preprocess unlabeled sensor data for inference.

    Returns (feature_matrix X, feature_names list, window_start_indices list).
    """
    windows = create_sliding_windows(data, window_size=10, stride=5)

    features_list  = []
    window_indices = []

    for i, (window_data, _) in enumerate(windows):
        features = extract_features_from_window(window_data)
        if features:
            features_list.append(features)
            # Use middle of window as the representative location index
            window_indices.append(i * 5 + 5)

    if not features_list:
        return np.array([]), [], []

    feature_names = list(features_list[0].keys())
    X = np.array([[f[name] for name in feature_names] for f in features_list])

    return X, feature_names, window_indices


if __name__ == '__main__':
    import os

    script_dir    = os.path.dirname(os.path.abspath(__file__))
    training_file = os.path.join(script_dir, 'training_data.json')

    if os.path.exists(training_file):
        with open(training_file, 'r') as f:
            data = json.load(f)

        X, labels, feature_names = preprocess_for_training(data)

        print(f"Feature matrix shape: {X.shape}")
        print(f"Number of labels: {len(labels)}")
        print(f"Feature names: {feature_names}")
        if labels:
            unique, counts = np.unique(labels, return_counts=True)
            print(f"Label distribution: {dict(zip(unique, counts))}")
    else:
        print("Training data not found. Run generate_data.py first.")
