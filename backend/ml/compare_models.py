"""
Model Comparison Script: Random Forest vs XGBoost

Saves results to a dated comparison file — never overwrites model.pkl.
To promote the winning model, copy the versioned file manually:
    cp model_versions/model_<timestamp>.pkl model.pkl
"""

import os
import json
import time
import numpy as np
import joblib
from sklearn.model_selection import train_test_split, cross_val_score
from sklearn.ensemble import RandomForestClassifier
from sklearn.metrics import classification_report, confusion_matrix, accuracy_score
from xgboost import XGBClassifier
from preprocess import preprocess_for_training


def compare_models(data_path: str = None):
    script_dir = os.path.dirname(os.path.abspath(__file__))

    if data_path is None:
        data_path = os.path.join(script_dir, 'training_data.json')

    print("=" * 60)
    print("         RANDOM FOREST vs XGBOOST COMPARISON")
    print("=" * 60)

    print("\nLoading training data...")
    with open(data_path, 'r') as f:
        raw_data = json.load(f)

    print(f"Loaded {len(raw_data)} raw samples")

    # Temporal sort + split (consistent with train_model.py)
    try:
        raw_data = sorted(raw_data, key=lambda r: r.get('timestamp', ''))
    except Exception:
        pass

    split_idx  = int(len(raw_data) * 0.8)
    train_data = raw_data[:split_idx]
    test_data  = raw_data[split_idx:]

    print("\nPreprocessing...")
    X_train, train_labels, feature_names = preprocess_for_training(train_data)
    X_test,  test_labels,  _             = preprocess_for_training(test_data)
    print(f"Train: {X_train.shape} | Test: {X_test.shape}")

    label_map   = {'smooth': 0, 'pothole': 1, 'bump': 2, 'rough': 3}
    label_names = ['smooth', 'pothole', 'bump', 'rough']
    y_train = np.array([label_map[l] for l in train_labels if l in label_map])
    y_test  = np.array([label_map[l] for l in test_labels  if l in label_map])

    print("\nClass distribution (train):")
    for i, name in enumerate(label_names):
        count = int(np.sum(y_train == i))
        print(f"  {name}: {count} ({count / max(len(y_train), 1) * 100:.1f}%)")

    # ── Random Forest ────────────────────────────────────────
    print("\n" + "=" * 60)
    print("                 RANDOM FOREST")
    print("=" * 60)

    rf_model = RandomForestClassifier(
        n_estimators=100, max_depth=10,
        min_samples_split=5, min_samples_leaf=2,
        random_state=42, n_jobs=-1,
    )
    print("\nTraining Random Forest...")
    rf_model.fit(X_train, y_train)

    rf_cv     = cross_val_score(rf_model, X_train, y_train, cv=5)
    rf_pred   = rf_model.predict(X_test)
    rf_acc    = accuracy_score(y_test, rf_pred)

    print(f"CV: {rf_cv.mean():.4f} (+/- {rf_cv.std() * 2:.4f})")
    print(f"Test Accuracy: {rf_acc * 100:.2f}%")
    print(classification_report(y_test, rf_pred, target_names=label_names, zero_division=0))

    # ── XGBoost ──────────────────────────────────────────────
    print("\n" + "=" * 60)
    print("                   XGBOOST")
    print("=" * 60)

    xgb_model = XGBClassifier(
        n_estimators=100, max_depth=6, learning_rate=0.1,
        min_child_weight=3, subsample=0.8, colsample_bytree=0.8,
        random_state=42, eval_metric='mlogloss', verbosity=0,
    )
    print("\nTraining XGBoost...")
    xgb_model.fit(X_train, y_train)

    xgb_cv   = cross_val_score(xgb_model, X_train, y_train, cv=5)
    xgb_pred = xgb_model.predict(X_test)
    xgb_acc  = accuracy_score(y_test, xgb_pred)

    print(f"CV: {xgb_cv.mean():.4f} (+/- {xgb_cv.std() * 2:.4f})")
    print(f"Test Accuracy: {xgb_acc * 100:.2f}%")
    print(classification_report(y_test, xgb_pred, target_names=label_names, zero_division=0))

    # ── Comparison ───────────────────────────────────────────
    print("\n" + "=" * 60)
    print("                  COMPARISON")
    print("=" * 60)
    print(f"\n{'Metric':<20} {'Random Forest':>16} {'XGBoost':>16}")
    print(f"{'Test Accuracy':<20} {rf_acc*100:>15.2f}% {xgb_acc*100:>15.2f}%")
    print(f"{'CV Mean':<20} {rf_cv.mean():>16.4f} {xgb_cv.mean():>16.4f}")
    print(f"{'CV Std':<20} {rf_cv.std():>16.4f} {xgb_cv.std():>16.4f}")

    diff = xgb_acc - rf_acc
    if diff > 0.01:
        winner, winner_model, winner_acc = "XGBoost", xgb_model, xgb_acc
    elif diff < -0.01:
        winner, winner_model, winner_acc = "Random Forest", rf_model, rf_acc
    else:
        winner        = "TIE (both similar)"
        winner_model  = xgb_model if xgb_acc >= rf_acc else rf_model
        winner_acc    = max(xgb_acc, rf_acc)

    print(f"\n WINNER: {winner}  (diff: {abs(diff)*100:.2f}%)")

    # Save comparison result to a DATED file — never model.pkl
    versions_dir = os.path.join(script_dir, 'model_versions')
    os.makedirs(versions_dir, exist_ok=True)

    version         = int(time.time())
    comparison_path = os.path.join(versions_dir, f'model_comparison_{version}.pkl')

    model_data = {
        'model':        winner_model,
        'feature_names': feature_names,
        'label_map':    label_map,
        'label_names':  label_names,
        'model_type':   winner,
        'version':      version,
        'metrics': {
            'rf_accuracy':  rf_acc,
            'xgb_accuracy': xgb_acc,
            'winner':       winner,
            'cv_mean':      float(max(rf_cv.mean(), xgb_cv.mean())),
        },
    }
    joblib.dump(model_data, comparison_path)

    print(f"\n Comparison model saved → {comparison_path}")
    print(f" Final Accuracy: {winner_acc * 100:.2f}%")
    print()
    print("To promote this model to production run:")
    print(f"  cp {comparison_path} {os.path.join(script_dir, 'model.pkl')}")

    # Feature importance
    print("\n Top 10 Important Features:")
    if hasattr(winner_model, 'feature_importances_'):
        importances = sorted(
            zip(feature_names, winner_model.feature_importances_),
            key=lambda x: x[1], reverse=True,
        )
        for name, importance in importances[:10]:
            print(f"  {name}: {importance:.4f}")

    return {
        'rf_accuracy':  rf_acc,
        'xgb_accuracy': xgb_acc,
        'winner':       winner,
        'saved_to':     comparison_path,
    }


if __name__ == '__main__':
    compare_models()
