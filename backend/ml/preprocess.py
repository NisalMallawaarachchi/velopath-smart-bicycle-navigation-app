"""
Preprocessing Module for Road Hazard Detection
Extracts features from raw sensor data for ML classification.
"""

import numpy as np
import json
from typing import List, Dict, Any


def extract_features_from_window(readings: List[Dict[str, Any]]) -> Dict[str, float]:
    """
    Extract features from a window of sensor readings.
    
    Args:
        readings: List of sensor reading dictionaries
        
    Returns:
        Dictionary of extracted features
    """
    if not readings:
        return {}
    
    # Extract arrays
    accel_x = np.array([r['accelX'] for r in readings])
    accel_y = np.array([r['accelY'] for r in readings])
    accel_z = np.array([r['accelZ'] for r in readings])
    gyro_x = np.array([r['gyroX'] for r in readings])
    gyro_y = np.array([r['gyroY'] for r in readings])
    gyro_z = np.array([r['gyroZ'] for r in readings])
    
    # Calculate accelerometer magnitude
    accel_mag = np.sqrt(accel_x**2 + accel_y**2 + accel_z**2)
    
    # Calculate gyroscope magnitude
    gyro_mag = np.sqrt(gyro_x**2 + gyro_y**2 + gyro_z**2)
    
    # Calculate jerk (rate of change of acceleration)
    accel_z_jerk = np.diff(accel_z) if len(accel_z) > 1 else np.array([0])
    
    features = {
        # Accelerometer features
        'accel_mag_mean': float(np.mean(accel_mag)),
        'accel_mag_std': float(np.std(accel_mag)),
        'accel_mag_max': float(np.max(accel_mag)),
        'accel_mag_min': float(np.min(accel_mag)),
        'accel_mag_range': float(np.max(accel_mag) - np.min(accel_mag)),
        
        # Z-axis (vertical) specific features - most important for hazards
        'accel_z_mean': float(np.mean(accel_z)),
        'accel_z_std': float(np.std(accel_z)),
        'accel_z_max': float(np.max(accel_z)),
        'accel_z_min': float(np.min(accel_z)),
        'accel_z_range': float(np.max(accel_z) - np.min(accel_z)),
        
        # Jerk features (important for sudden impacts)
        'accel_z_jerk_max': float(np.max(np.abs(accel_z_jerk))),
        'accel_z_jerk_mean': float(np.mean(np.abs(accel_z_jerk))),
        
        # Gyroscope features
        'gyro_mag_mean': float(np.mean(gyro_mag)),
        'gyro_mag_std': float(np.std(gyro_mag)),
        'gyro_mag_max': float(np.max(gyro_mag)),
        
        # Gyro X (pitch) - important for pothole detection
        'gyro_x_max': float(np.max(np.abs(gyro_x))),
        'gyro_x_range': float(np.max(gyro_x) - np.min(gyro_x)),
    }
    
    return features


def create_sliding_windows(readings: List[Dict], window_size: int = 10, stride: int = 5):
    """
    Create overlapping windows from sensor readings.
    
    Args:
        readings: List of sensor readings
        window_size: Number of readings per window
        stride: Step size between windows
        
    Returns:
        List of (window_data, label) tuples
    """
    windows = []
    
    for i in range(0, len(readings) - window_size + 1, stride):
        window = readings[i:i + window_size]
        
        # Get label from the middle reading (if available)
        label = window[window_size // 2].get('label', None)
        
        windows.append((window, label))
    
    return windows


def preprocess_for_training(data: List[Dict]) -> tuple:
    """
    Preprocess labeled data for training.
    
    Args:
        data: List of labeled sensor readings
        
    Returns:
        Tuple of (feature_matrix, labels, feature_names)
    """
    windows = create_sliding_windows(data, window_size=10, stride=5)
    
    features_list = []
    labels = []
    
    for window_data, label in windows:
        if label is not None:
            features = extract_features_from_window(window_data)
            features_list.append(features)
            labels.append(label)
    
    if not features_list:
        return np.array([]), [], []
    
    # Get feature names from first sample
    feature_names = list(features_list[0].keys())
    
    # Create feature matrix
    X = np.array([[f[name] for name in feature_names] for f in features_list])
    
    return X, labels, feature_names


def preprocess_for_prediction(data: List[Dict]) -> tuple:
    """
    Preprocess unlabeled data for prediction.
    
    Args:
        data: List of sensor readings (without labels)
        
    Returns:
        Tuple of (feature_matrix, feature_names, window_indices)
    """
    windows = create_sliding_windows(data, window_size=10, stride=5)
    
    features_list = []
    window_indices = []
    
    for i, (window_data, _) in enumerate(windows):
        features = extract_features_from_window(window_data)
        features_list.append(features)
        window_indices.append(i * 5)  # Start index of window
    
    if not features_list:
        return np.array([]), [], []
    
    feature_names = list(features_list[0].keys())
    X = np.array([[f[name] for name in feature_names] for f in features_list])
    
    return X, feature_names, window_indices


if __name__ == '__main__':
    # Test preprocessing with sample data
    import os
    
    script_dir = os.path.dirname(os.path.abspath(__file__))
    training_file = os.path.join(script_dir, 'training_data.json')
    
    if os.path.exists(training_file):
        with open(training_file, 'r') as f:
            data = json.load(f)
        
        X, labels, feature_names = preprocess_for_training(data)
        
        print(f"Feature matrix shape: {X.shape}")
        print(f"Number of labels: {len(labels)}")
        print(f"Feature names: {feature_names}")
        print(f"Label distribution: {dict(zip(*np.unique(labels, return_counts=True)))}")
    else:
        print("Training data not found. Run generate_data.py first.")
