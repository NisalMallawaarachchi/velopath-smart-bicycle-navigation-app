"""
Synthetic Sensor Data Generator for Road Hazard Detection
Generates realistic accelerometer and gyroscope patterns for:
- Smooth roads
- Potholes (sudden drops and impacts)
- Bumps (upward jolts)
"""

import numpy as np
import pandas as pd
import json
from datetime import datetime, timedelta
import os

# Sensor sampling rate (matching Flutter app: 200ms = 5Hz)
SAMPLING_RATE_MS = 200
GRAVITY = 9.81  # m/s²

def generate_smooth_road(num_samples=50):
    """Generate sensor data for smooth road riding."""
    data = []
    base_time = datetime.now()
    
    for i in range(num_samples):
        # Smooth road: gravity on z-axis with minor vibrations
        accel_x = np.random.normal(0, 0.3)
        accel_y = np.random.normal(0, 0.3)
        accel_z = np.random.normal(GRAVITY, 0.5)  # Gravity + small variation
        
        # Minimal rotation
        gyro_x = np.random.normal(0, 0.1)
        gyro_y = np.random.normal(0, 0.1)
        gyro_z = np.random.normal(0, 0.05)
        
        # Magnetometer (relatively stable)
        mag_x = np.random.normal(25, 2)
        mag_y = np.random.normal(-10, 2)
        mag_z = np.random.normal(-45, 2)
        
        timestamp = base_time + timedelta(milliseconds=i * SAMPLING_RATE_MS)
        
        data.append({
            'timestamp': timestamp.isoformat(),
            'accelX': round(accel_x, 4),
            'accelY': round(accel_y, 4),
            'accelZ': round(accel_z, 4),
            'gyroX': round(gyro_x, 4),
            'gyroY': round(gyro_y, 4),
            'gyroZ': round(gyro_z, 4),
            'magX': round(mag_x, 4),
            'magY': round(mag_y, 4),
            'magZ': round(mag_z, 4),
            'latitude': 6.9271 + np.random.normal(0, 0.0001),
            'longitude': 79.8612 + np.random.normal(0, 0.0001),
            'label': 'smooth'
        })
    
    return data


def generate_pothole(num_samples=50, pothole_position=25):
    """
    Generate sensor data with a pothole event.
    Pothole pattern: sudden negative z-spike (drop), then positive (impact)
    """
    data = []
    base_time = datetime.now()
    
    for i in range(num_samples):
        # Base values (smooth road)
        accel_x = np.random.normal(0, 0.3)
        accel_y = np.random.normal(0, 0.3)
        accel_z = np.random.normal(GRAVITY, 0.5)
        gyro_x = np.random.normal(0, 0.1)
        gyro_y = np.random.normal(0, 0.1)
        gyro_z = np.random.normal(0, 0.05)
        
        # Pothole event (3-5 samples showing the pattern)
        dist_from_pothole = abs(i - pothole_position)
        
        if dist_from_pothole == 0:
            # At pothole: sudden drop (negative g-force)
            accel_z = np.random.normal(3.0, 1.0)  # Reduced gravity (falling)
            gyro_x = np.random.normal(1.5, 0.3)  # Pitch forward
        elif dist_from_pothole == 1 and i > pothole_position:
            # Impact after pothole: high positive acceleration
            accel_z = np.random.normal(18.0, 2.0)  # High impact
            gyro_x = np.random.normal(-2.0, 0.5)  # Pitch back
            gyro_y = np.random.normal(0.8, 0.3)
        elif dist_from_pothole == 2 and i > pothole_position:
            # Recovery
            accel_z = np.random.normal(12.0, 1.5)
            gyro_x = np.random.normal(0.5, 0.2)
        
        mag_x = np.random.normal(25, 2)
        mag_y = np.random.normal(-10, 2)
        mag_z = np.random.normal(-45, 2)
        
        timestamp = base_time + timedelta(milliseconds=i * SAMPLING_RATE_MS)
        
        data.append({
            'timestamp': timestamp.isoformat(),
            'accelX': round(accel_x, 4),
            'accelY': round(accel_y, 4),
            'accelZ': round(accel_z, 4),
            'gyroX': round(gyro_x, 4),
            'gyroY': round(gyro_y, 4),
            'gyroZ': round(gyro_z, 4),
            'magX': round(mag_x, 4),
            'magY': round(mag_y, 4),
            'magZ': round(mag_z, 4),
            'latitude': 6.9271 + np.random.normal(0, 0.0001),
            'longitude': 79.8612 + np.random.normal(0, 0.0001),
            'label': 'pothole'
        })
    
    return data


def generate_bump(num_samples=50, bump_position=25):
    """
    Generate sensor data with a bump/speed breaker event.
    Bump pattern: sudden positive z-spike (upward jolt)
    """
    data = []
    base_time = datetime.now()
    
    for i in range(num_samples):
        # Base values (smooth road)
        accel_x = np.random.normal(0, 0.3)
        accel_y = np.random.normal(0, 0.3)
        accel_z = np.random.normal(GRAVITY, 0.5)
        gyro_x = np.random.normal(0, 0.1)
        gyro_y = np.random.normal(0, 0.1)
        gyro_z = np.random.normal(0, 0.05)
        
        # Bump event
        dist_from_bump = abs(i - bump_position)
        
        if dist_from_bump == 0:
            # Hitting the bump: upward acceleration
            accel_z = np.random.normal(15.0, 1.5)
            gyro_x = np.random.normal(-1.0, 0.3)  # Pitch back
        elif dist_from_bump == 1:
            # On top of bump or landing
            accel_z = np.random.normal(12.0, 1.0)
            gyro_x = np.random.normal(0.8, 0.2)
        elif dist_from_bump == 2:
            # Recovery
            accel_z = np.random.normal(10.5, 0.8)
        
        mag_x = np.random.normal(25, 2)
        mag_y = np.random.normal(-10, 2)
        mag_z = np.random.normal(-45, 2)
        
        timestamp = base_time + timedelta(milliseconds=i * SAMPLING_RATE_MS)
        
        data.append({
            'timestamp': timestamp.isoformat(),
            'accelX': round(accel_x, 4),
            'accelY': round(accel_y, 4),
            'accelZ': round(accel_z, 4),
            'gyroX': round(gyro_x, 4),
            'gyroY': round(gyro_y, 4),
            'gyroZ': round(gyro_z, 4),
            'magX': round(mag_x, 4),
            'magY': round(mag_y, 4),
            'magZ': round(mag_z, 4),
            'latitude': 6.9271 + np.random.normal(0, 0.0001),
            'longitude': 79.8612 + np.random.normal(0, 0.0001),
            'label': 'bump'
        })
    
    return data


def generate_training_dataset(samples_per_class=500):
    """Generate a balanced training dataset with focused windows."""
    all_data = []
    
    print(f"Generating {samples_per_class} samples per class...")
    
    # Generate smooth road samples (short windows, 10-15 samples each)
    for _ in range(samples_per_class // 12):
        window_size = np.random.randint(10, 16)
        all_data.extend(generate_smooth_road(window_size))
    
    # Generate pothole samples - hazard should be in the center
    for _ in range(samples_per_class // 12):
        window_size = np.random.randint(12, 18)
        pos = window_size // 2
        all_data.extend(generate_pothole(window_size, pothole_position=pos))
    
    # Generate bump samples - hazard should be in the center
    for _ in range(samples_per_class // 12):
        window_size = np.random.randint(12, 18)
        pos = window_size // 2
        all_data.extend(generate_bump(window_size, bump_position=pos))
    
    return all_data


def save_dataset(data, filename='training_data.json'):
    """Save dataset to JSON file."""
    script_dir = os.path.dirname(os.path.abspath(__file__))
    filepath = os.path.join(script_dir, filename)
    
    with open(filepath, 'w') as f:
        json.dump(data, f, indent=2)
    
    print(f"Dataset saved to {filepath}")
    print(f"Total samples: {len(data)}")
    
    # Count by label (only if labels exist)
    if data and 'label' in data[0]:
        labels = {}
        for sample in data:
            label = sample['label']
            labels[label] = labels.get(label, 0) + 1
        
        print("Samples per class:")
        for label, count in labels.items():
            print(f"  {label}: {count}")
    
    return filepath


def generate_demo_session():
    """Generate a demo session with mixed road conditions for demonstration."""
    demo_data = []
    
    # Start with smooth road
    demo_data.extend(generate_smooth_road(20))
    
    # Hit a pothole
    demo_data.extend(generate_pothole(30, pothole_position=15))
    
    # More smooth road
    demo_data.extend(generate_smooth_road(15))
    
    # Hit a bump
    demo_data.extend(generate_bump(30, bump_position=15))
    
    # End with smooth road
    demo_data.extend(generate_smooth_road(15))
    
    # Remove labels for demo (simulating real unlabeled data)
    demo_session = []
    for sample in demo_data:
        sample_copy = sample.copy()
        del sample_copy['label']
        demo_session.append(sample_copy)
    
    return demo_session


if __name__ == '__main__':
    # Generate training dataset
    print("=" * 50)
    print("Generating Training Dataset")
    print("=" * 50)
    training_data = generate_training_dataset(samples_per_class=350)
    save_dataset(training_data, 'training_data.json')
    
    # Generate demo session
    print("\n" + "=" * 50)
    print("Generating Demo Session")
    print("=" * 50)
    demo_session = generate_demo_session()
    save_dataset(demo_session, 'demo_session.json')
    
    print("\n✅ Data generation complete!")
