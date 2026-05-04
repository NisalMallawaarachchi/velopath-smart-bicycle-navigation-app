"""
generate_training_data.py
Physics-based synthetic training data generator for road hazard detection.

Addresses 4 real-world variation sources:
  1. Phone mounting position  — 3D rotation matrix (handlebar/pocket/bag)
  2. Speed variation          — amplitude × (speed/20)²
  3. Road surface texture     — frequency-specific noise per road type
  4. Bike type damping        — suspension absorption factor

Output: training_data.json compatible with preprocess.py pipeline
Run:    python generate_training_data.py
"""

import json
import numpy as np
import os
import random
from datetime import datetime, timedelta
from collections import Counter

random.seed(42)
np.random.seed(42)

# ── GPS sections: 14 real points along Weligama → Galle corridor ─────────────
GPS_SECTIONS = [
    (5.9729, 80.4295, 'worn_tarmac',  'Weligama Bay'),
    (5.9718, 80.4140, 'worn_tarmac',  'Weligama-Ahangama'),
    (5.9704, 80.3965, 'good_tarmac',  'Ahangama East'),
    (5.9696, 80.3875, 'rough_patch',  'Ahangama'),
    (5.9688, 80.3785, 'worn_tarmac',  'Ahangama mid'),
    (5.9682, 80.3655, 'good_tarmac',  'Ahangama West'),
    (5.9573, 80.3481, 'rough_patch',  'Midigama'),
    (5.9595, 80.3390, 'worn_tarmac',  'Midigama-Koggala'),
    (5.9780, 80.3100, 'good_tarmac',  'Koggala'),
    (5.9895, 80.2965, 'local_road',   'Habaraduwa'),
    (6.0005, 80.2835, 'worn_tarmac',  'Habaraduwa North'),
    (6.0148, 80.2490, 'good_tarmac',  'Unawatuna'),
    (6.0270, 80.2255, 'local_road',   'Galle approach'),
    (6.0325, 80.2175, 'good_tarmac',  'Galle Fort'),
]

# Road texture: Z-axis baseline noise std (m/s²)
ROAD_TEXTURE_STD = {
    'good_tarmac': 0.04,
    'worn_tarmac': 0.13,
    'rough_patch': 0.28,
    'local_road':  0.18,
}

# Bike damping: (event_spike_factor, texture_noise_factor)
BIKE_PROFILES = {
    'road':     {'spike': 1.00, 'texture': 1.00},
    'hybrid':   {'spike': 0.65, 'texture': 0.50},
    'mountain': {'spike': 0.35, 'texture': 0.20},
    'ebike':    {'spike': 0.55, 'texture': 0.45},
}

# Mount tilt range in degrees
MOUNT_TILT = {
    'handlebar': (0,  15),
    'pocket':    (25, 55),
    'bag':       (60, 85),
}

FREQ_HZ  = 5
DT       = 1.0 / FREQ_HZ   # 200 ms per reading
GRAVITY  = 9.81             # m/s²


# ── Rotation helpers ──────────────────────────────────────────────────────────

def _rot_x(a):
    c, s = np.cos(a), np.sin(a)
    return np.array([[1, 0, 0], [0, c, -s], [0, s, c]])

def _rot_y(a):
    c, s = np.cos(a), np.sin(a)
    return np.array([[c, 0, s], [0, 1, 0], [-s, 0, c]])

def _rot_z(a):
    c, s = np.cos(a), np.sin(a)
    return np.array([[c, -s, 0], [s, c, 0], [0, 0, 1]])

def make_rotation_matrix(rx_deg, ry_deg, rz_deg):
    """Build phone-mount rotation matrix from Euler angles (degrees)."""
    return _rot_z(np.radians(rz_deg)) @ _rot_y(np.radians(ry_deg)) @ _rot_x(np.radians(rx_deg))

def rotate_vec(v, R):
    return (R @ np.array(v)).tolist()


# ── User profile ─────────────────────────────────────────────────────────────

def new_user_profile():
    bike  = random.choice(list(BIKE_PROFILES.keys()))
    mount = random.choice(list(MOUNT_TILT.keys()))
    speed = random.uniform(10, 28)

    tmin, tmax = MOUNT_TILT[mount]
    rx = random.uniform(tmin, tmax)
    ry = random.uniform(-12, 12)
    rz = random.uniform(-20, 20)

    section = random.choice(GPS_SECTIONS)

    return {
        'bike':         bike,
        'mount':        mount,
        'speed_kmh':    speed,
        'speed_factor': (speed / 20.0) ** 2,
        'R':            make_rotation_matrix(rx, ry, rz),
        'section':      section,
    }


# ── Single reading generator ──────────────────────────────────────────────────

def _make_reading(ax_w, ay_w, az_w, profile, base_time, t_offset, label):
    """
    Convert world-frame accelerations to phone-frame, add gyro/mag/GPS noise,
    return a sensor reading dict.
    """
    bike = BIKE_PROFILES[profile['bike']]
    R    = profile['R']
    lat, lon, _, _ = profile['section']

    # Phone-frame accelerations
    pf = rotate_vec([ax_w, ay_w, az_w], R)

    # Gaussian sensor noise (phone hardware)
    pf[0] += np.random.normal(0, 0.020)
    pf[1] += np.random.normal(0, 0.020)
    pf[2] += np.random.normal(0, 0.015)

    # Gyroscope: small random rotations
    gx = np.random.normal(0, 0.012)
    gy = np.random.normal(0, 0.012)
    gz = np.random.normal(0, 0.008)

    # Magnetometer (Sri Lanka approx)
    mx = 23.5  + np.random.normal(0, 0.4)
    my = -11.0 + np.random.normal(0, 0.4)
    mz = -44.0 + np.random.normal(0, 0.4)

    ts = (base_time + timedelta(seconds=t_offset)).isoformat()

    return {
        'timestamp':  ts,
        'accelX':     round(float(pf[0]), 6),
        'accelY':     round(float(pf[1]), 6),
        'accelZ':     round(float(pf[2]), 6),
        'gyroX':      round(float(gx), 6),
        'gyroY':      round(float(gy), 6),
        'gyroZ':      round(float(gz), 6),
        'magX':       round(float(mx), 3),
        'magY':       round(float(my), 3),
        'magZ':       round(float(mz), 3),
        'latitude':   round(float(lat + np.random.normal(0, 0.00002)), 6),
        'longitude':  round(float(lon + np.random.normal(0, 0.00002)), 6),
        'speed_kmh':  round(float(profile['speed_kmh'] + np.random.normal(0, 0.5)), 2),
        'label':      label,
    }


# ── Scenario generators ───────────────────────────────────────────────────────

def _base_time():
    return datetime(2026, 1, 1) + timedelta(
        days=random.randint(0, 120),
        hours=random.randint(6, 18),
        minutes=random.randint(0, 59),
    )


def _smooth_az(profile):
    """World-frame Z baseline: gravity + pedaling + road texture."""
    bike   = BIKE_PROFILES[profile['bike']]
    speed  = profile['speed_kmh']
    _, _, road_type, _ = profile['section']
    noise_std = ROAD_TEXTURE_STD[road_type] * bike['texture']
    pedal_amp = 0.06
    pedal_hz  = max(0.3, speed / 60.0)
    return lambda t: (GRAVITY
                      + pedal_amp * np.sin(2 * np.pi * pedal_hz * t)
                      + np.random.normal(0, noise_std))

def _smooth_ax(profile):
    speed = profile['speed_kmh']
    pedal_hz = max(0.3, speed / 60.0)
    return lambda t: 0.04 * np.sin(2 * np.pi * pedal_hz * t + 0.5) + np.random.normal(0, 0.025)

def _smooth_ay(profile):
    return lambda _: np.random.normal(0, 0.020)


def gen_smooth(n=22):
    p   = new_user_profile()
    bt  = _base_time()
    az_fn = _smooth_az(p)
    ax_fn = _smooth_ax(p)
    ay_fn = _smooth_ay(p)
    return [_make_reading(ax_fn(i*DT), ay_fn(i*DT), az_fn(i*DT), p, bt, i*DT, 'smooth')
            for i in range(n)]


def gen_pothole(n=22):
    """
    Sharp negative Z dip (wheel drops) followed by positive spike (impact).
    Amplitude scales with speed². Duration: 1-2 readings.
    """
    p    = new_user_profile()
    bt   = _base_time()
    bike = BIKE_PROFILES[p['bike']]
    amp  = 4.5 * p['speed_factor'] * bike['spike']   # world-frame spike m/s²
    amp  = max(1.2, amp)

    az_fn = _smooth_az(p)
    ax_fn = _smooth_ax(p)
    ay_fn = _smooth_ay(p)

    event_idx = random.randint(5, n - 5)
    readings  = []

    for i in range(n):
        t   = i * DT
        az  = az_fn(t)
        ax  = ax_fn(t)
        ay  = ay_fn(t)
        lbl = 'smooth'

        if i == event_idx:
            az  = GRAVITY - amp * 0.45 + np.random.normal(0, 0.25)   # drop
            ax += np.random.normal(0, 0.12)
            lbl = 'pothole'
        elif i == event_idx + 1:
            az  = GRAVITY + amp + np.random.normal(0, 0.30)           # impact spike
            ax += np.random.normal(0, 0.10)
            lbl = 'pothole'

        readings.append(_make_reading(ax, ay, az, p, bt, t, lbl))

    return readings


def gen_bump(n=22):
    """
    Smooth sinusoidal Z rise-fall over 3 readings. Smaller amplitude than pothole.
    Models a speed bump approached at typical cycling speed.
    """
    p    = new_user_profile()
    bt   = _base_time()
    bike = BIKE_PROFILES[p['bike']]
    amp  = 2.2 * p['speed_factor'] * bike['spike']
    amp  = max(0.8, amp)

    az_fn = _smooth_az(p)
    ax_fn = _smooth_ax(p)
    ay_fn = _smooth_ay(p)

    event_idx = random.randint(4, n - 6)
    readings  = []
    bump_shape = [0.45, 1.0, 0.55, 0.15]   # gradual rise then fall

    for i in range(n):
        t   = i * DT
        az  = az_fn(t)
        ax  = ax_fn(t)
        ay  = ay_fn(t)
        lbl = 'smooth'

        offset = i - event_idx
        if 0 <= offset < len(bump_shape):
            az  = GRAVITY + amp * bump_shape[offset] + np.random.normal(0, 0.12)
            lbl = 'bump'

        readings.append(_make_reading(ax, ay, az, p, bt, t, lbl))

    return readings


def gen_rough(n=22):
    """
    Sustained high-frequency vibration: elevated Z std for an extended section.
    No sharp spikes — distinguishable from pothole by lack of jerk.
    """
    p    = new_user_profile()
    bt   = _base_time()
    bike = BIKE_PROFILES[p['bike']]

    _, _, road_type, _ = p['section']
    base_std   = ROAD_TEXTURE_STD.get(road_type, 0.15)
    rough_std  = (base_std + 0.30) * bike['texture']

    az_fn = _smooth_az(p)
    ax_fn = _smooth_ax(p)

    rough_start  = random.randint(2, 5)
    rough_length = random.randint(10, 15)

    readings = []
    for i in range(n):
        t   = i * DT
        az  = az_fn(t)
        ax  = ax_fn(t)
        ay  = np.random.normal(0, 0.02)
        lbl = 'smooth'

        if rough_start <= i < rough_start + rough_length:
            az   = GRAVITY + np.random.normal(0, rough_std)
            ax  += np.random.normal(0, rough_std * 0.35)
            ay  += np.random.normal(0, rough_std * 0.25)
            lbl  = 'rough'

        readings.append(_make_reading(ax, ay, az, p, bt, t, lbl))

    return readings


# ── Main ──────────────────────────────────────────────────────────────────────

def main():
    script_dir  = os.path.dirname(os.path.abspath(__file__))
    output_path = os.path.join(script_dir, 'training_data.json')

    print("=" * 60)
    print("Physics-Based Synthetic Training Data Generator")
    print("=" * 60)
    print("Modelling:")
    print("  - Mount rotation  : handlebar (0-15 deg), pocket (25-55 deg), bag (60-85 deg)")
    print("  - Speed scaling   : 10-28 km/h -> amplitude x (speed/20)^2")
    print("  - Road texture    : good / worn tarmac, rough patch, local road")
    print("  - Bike damping    : road 1.0x, hybrid 0.65x, mountain 0.35x, ebike 0.55x")
    print()

    SCENARIOS_PER_CLASS  = 350   # × ~22 readings × 4 classes ≈ 30,800 raw readings
    READINGS_PER_SCENARIO = 22   # → ~7 windows per scenario after 10/5 sliding window

    generators = {
        'smooth':  gen_smooth,
        'pothole': gen_pothole,
        'bump':    gen_bump,
        'rough':   gen_rough,
    }

    all_readings = []

    for label, gen_fn in generators.items():
        batch = []
        for _ in range(SCENARIOS_PER_CLASS):
            batch.extend(gen_fn(READINGS_PER_SCENARIO))
        labeled = sum(1 for r in batch if r['label'] == label)
        print(f"  OK {label:8s}: {SCENARIOS_PER_CLASS} scenarios, "
              f"{len(batch)} readings, {labeled} labeled '{label}'")
        all_readings.extend(batch)

    # Shuffle at reading level — train_model.py sorts by timestamp anyway
    # but shuffle ensures good mixing before the temporal sort
    random.shuffle(all_readings)

    print()
    print(f"Total readings : {len(all_readings):,}")
    dist = Counter(r['label'] for r in all_readings)
    print("Label distribution:")
    for lbl in ['smooth', 'pothole', 'bump', 'rough']:
        cnt = dist.get(lbl, 0)
        print(f"  {lbl:8s}: {cnt:5d}  ({cnt/len(all_readings)*100:.1f}%)")

    with open(output_path, 'w') as f:
        json.dump(all_readings, f, indent=2)

    print(f"\nSaved -> {output_path}")
    print(f"\nNext step: python train_model.py")


if __name__ == '__main__':
    main()
