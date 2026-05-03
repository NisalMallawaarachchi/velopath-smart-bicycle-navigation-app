"""
Model Training Script for Road Hazard Detection

Trains a Random Forest classifier on preprocessed sensor data.
Saves versioned model files and only promotes to model.pkl when the new
model outperforms (or matches) the currently deployed one.
"""

import os
import json
import time
import numpy as np
import joblib
from sklearn.model_selection import train_test_split, cross_val_score
from sklearn.ensemble import RandomForestClassifier
from sklearn.metrics import classification_report, confusion_matrix
from preprocess import preprocess_for_training


MODELS_DIR_NAME = "model_versions"


def _load_current_best_accuracy(script_dir: str) -> float:
    """Return the test accuracy of the currently deployed model, or 0 if none."""
    model_path = os.path.join(script_dir, 'model.pkl')
    if not os.path.exists(model_path):
        return 0.0
    try:
        data = joblib.load(model_path)
        return data.get('metrics', {}).get('accuracy', 0.0)
    except Exception:
        return 0.0


def train_model(data_path: str = None, model_path: str = None):
    """
    Train the hazard detection model with temporal train/test split.

    Temporal split is used instead of random shuffle to simulate real-world
    deployment: the model is evaluated on the most recent data, not a random
    sample, which detects concept drift that random splits would hide.

    Args:
        data_path:  Path to training data JSON (defaults to training_data.json)
        model_path: Path to save deployed model (defaults to model.pkl)
    """
    script_dir = os.path.dirname(os.path.abspath(__file__))

    if data_path is None:
        data_path = os.path.join(script_dir, 'training_data.json')
    if model_path is None:
        model_path = os.path.join(script_dir, 'model.pkl')

    versions_dir = os.path.join(script_dir, MODELS_DIR_NAME)
    os.makedirs(versions_dir, exist_ok=True)

    # Load training data
    print("Loading training data...")
    with open(data_path, 'r') as f:
        raw_data = json.load(f)

    print(f"Loaded {len(raw_data)} raw samples")

    # Temporal sort — use chronological order for honest evaluation
    try:
        raw_data_sorted = sorted(raw_data, key=lambda r: r.get('timestamp', ''))
    except Exception:
        raw_data_sorted = raw_data

    # 80/20 temporal split
    split_idx  = int(len(raw_data_sorted) * 0.8)
    train_data = raw_data_sorted[:split_idx]
    test_data  = raw_data_sorted[split_idx:]

    print(f"Temporal split — train: {len(train_data)} samples, test: {len(test_data)} samples")

    # Preprocess
    print("\nPreprocessing training data...")
    X_train, train_labels, feature_names = preprocess_for_training(train_data)

    print("\nPreprocessing test data...")
    X_test, test_labels, _ = preprocess_for_training(test_data)

    if X_train.shape[0] == 0 or X_test.shape[0] == 0:
        print("ERROR: Not enough labeled data after windowing. Aborting.")
        return None, None

    print(f"Train feature matrix: {X_train.shape}")
    print(f"Test  feature matrix: {X_test.shape}")

    label_map   = {'smooth': 0, 'pothole': 1, 'bump': 2, 'rough': 3}
    label_names = ['smooth', 'pothole', 'bump', 'rough']

    y_train = np.array([label_map[l] for l in train_labels if l in label_map])
    y_test  = np.array([label_map[l] for l in test_labels  if l in label_map])

    # Filter rows with unknown labels (in case of bad data)
    train_mask = np.array([l in label_map for l in train_labels])
    test_mask  = np.array([l in label_map for l in test_labels])
    X_train, y_train = X_train[train_mask], y_train
    X_test,  y_test  = X_test[test_mask],   y_test

    print("\nLabel distribution (train):")
    for i, name in enumerate(label_names):
        count = int(np.sum(y_train == i))
        print(f"  {name}: {count} ({count / max(len(y_train), 1) * 100:.1f}%)")

    # Train Random Forest
    print("\nTraining Random Forest classifier...")
    model = RandomForestClassifier(
        n_estimators=100,
        max_depth=10,
        min_samples_split=5,
        min_samples_leaf=2,
        random_state=42,
        n_jobs=-1,
    )
    model.fit(X_train, y_train)

    # Cross-validation on training set
    print("\nCross-validation scores (5-fold, training set):")
    cv_scores = cross_val_score(model, X_train, y_train, cv=5)
    print(f"  Mean: {cv_scores.mean():.4f} (+/- {cv_scores.std() * 2:.4f})")

    # Temporal test set evaluation
    print("\nTemporal test set evaluation (most recent 20% of data):")
    y_pred   = model.predict(X_test)
    accuracy = float((y_pred == y_test).mean())
    print(f"Test Accuracy: {accuracy * 100:.2f}%")

    print("\nClassification Report:")
    print(classification_report(y_test, y_pred, target_names=label_names, zero_division=0))

    print("Confusion Matrix:")
    print(confusion_matrix(y_test, y_pred))

    # Feature importance
    print("\nTop 10 Important Features:")
    importances = sorted(
        zip(feature_names, model.feature_importances_),
        key=lambda x: x[1], reverse=True
    )
    for name, importance in importances[:10]:
        print(f"  {name}: {importance:.4f}")

    # Version metadata
    version   = int(time.time())
    metrics   = {
        'accuracy':  accuracy,
        'cv_mean':   float(cv_scores.mean()),
        'cv_std':    float(cv_scores.std()),
        'n_train':   int(X_train.shape[0]),
        'n_test':    int(X_test.shape[0]),
        'timestamp': version,
    }
    model_data = {
        'model':         model,
        'feature_names': feature_names,
        'label_map':     label_map,
        'label_names':   label_names,
        'version':       version,
        'metrics':       metrics,
    }

    # Always save a versioned copy
    versioned_path = os.path.join(versions_dir, f'model_{version}.pkl')
    joblib.dump(model_data, versioned_path)
    print(f"\nVersioned model saved → {versioned_path}")

    # Promote to model.pkl only if better than current deployed model
    current_best = _load_current_best_accuracy(script_dir)
    if accuracy >= current_best:
        joblib.dump(model_data, model_path)
        print(f"Promoted to model.pkl (accuracy {accuracy:.4f} >= current best {current_best:.4f})")
    else:
        print(f"NOT promoted — new accuracy {accuracy:.4f} < current best {current_best:.4f}")
        print(f"Inspect {versioned_path} before manual promotion.")

    # Keep only the 5 most recent versioned models
    _prune_old_versions(versions_dir, keep=5)

    return model, feature_names


def _prune_old_versions(versions_dir: str, keep: int = 5):
    """Delete old versioned models, keeping the N most recent."""
    files = sorted([
        f for f in os.listdir(versions_dir) if f.startswith('model_') and f.endswith('.pkl')
    ])
    for old_file in files[:-keep]:
        os.remove(os.path.join(versions_dir, old_file))
        print(f"Pruned old version: {old_file}")


if __name__ == '__main__':
    train_model()
