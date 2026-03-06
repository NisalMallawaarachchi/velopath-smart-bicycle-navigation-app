"""
Model Comparison Script: Random Forest vs XGBoost
Compares both models and shows which performs better for road hazard detection.
"""

import os
import json
import numpy as np
import joblib
from sklearn.model_selection import train_test_split, cross_val_score
from sklearn.ensemble import RandomForestClassifier
from sklearn.metrics import classification_report, confusion_matrix, accuracy_score
from xgboost import XGBClassifier
from preprocess import preprocess_for_training


def compare_models(data_path: str = None):
    """
    Train and compare Random Forest vs XGBoost models.
    """
    script_dir = os.path.dirname(os.path.abspath(__file__))
    
    if data_path is None:
        data_path = os.path.join(script_dir, 'training_data.json')
    
    # Load training data
    print("=" * 60)
    print("         RANDOM FOREST vs XGBOOST COMPARISON")
    print("=" * 60)
    print("\nLoading training data...")
    with open(data_path, 'r') as f:
        data = json.load(f)
    
    print(f"Loaded {len(data)} raw samples")
    
    # Preprocess data
    print("\nPreprocessing data...")
    X, labels, feature_names = preprocess_for_training(data)
    print(f"Created {X.shape[0]} feature vectors with {X.shape[1]} features each")
    
    # Encode labels
    label_map = {'smooth': 0, 'pothole': 1, 'bump': 2, 'rough': 3}
    label_names = ['smooth', 'pothole', 'bump', 'rough']
    y = np.array([label_map[label] for label in labels])
    
    # Show class distribution
    print("\nClass distribution:")
    for i, name in enumerate(label_names):
        count = np.sum(y == i)
        print(f"  {name}: {count} ({count/len(y)*100:.1f}%)")
    
    # Split data
    X_train, X_test, y_train, y_test = train_test_split(
        X, y, test_size=0.2, random_state=42, stratify=y
    )
    
    print(f"\nTraining set: {len(X_train)} samples")
    print(f"Test set: {len(X_test)} samples")
    
    # ============= RANDOM FOREST =============
    print("\n" + "=" * 60)
    print("                 RANDOM FOREST")
    print("=" * 60)
    
    rf_model = RandomForestClassifier(
        n_estimators=100,
        max_depth=10,
        min_samples_split=5,
        min_samples_leaf=2,
        random_state=42,
        n_jobs=-1
    )
    
    print("\nTraining Random Forest...")
    rf_model.fit(X_train, y_train)
    
    # Cross-validation
    rf_cv_scores = cross_val_score(rf_model, X_train, y_train, cv=5)
    print(f"Cross-validation: {rf_cv_scores.mean():.4f} (+/- {rf_cv_scores.std() * 2:.4f})")
    
    # Test set
    rf_pred = rf_model.predict(X_test)
    rf_accuracy = accuracy_score(y_test, rf_pred)
    print(f"\nTest Accuracy: {rf_accuracy * 100:.2f}%")
    
    print("\nClassification Report:")
    print(classification_report(y_test, rf_pred, target_names=label_names, zero_division=0))
    
    # ============= XGBOOST =============
    print("\n" + "=" * 60)
    print("                   XGBOOST")
    print("=" * 60)
    
    xgb_model = XGBClassifier(
        n_estimators=100,
        max_depth=6,
        learning_rate=0.1,
        min_child_weight=3,
        subsample=0.8,
        colsample_bytree=0.8,
        random_state=42,
        eval_metric='mlogloss',
        verbosity=0
    )
    
    print("\nTraining XGBoost...")
    xgb_model.fit(X_train, y_train)
    
    # Cross-validation
    xgb_cv_scores = cross_val_score(xgb_model, X_train, y_train, cv=5)
    print(f"Cross-validation: {xgb_cv_scores.mean():.4f} (+/- {xgb_cv_scores.std() * 2:.4f})")
    
    # Test set
    xgb_pred = xgb_model.predict(X_test)
    xgb_accuracy = accuracy_score(y_test, xgb_pred)
    print(f"\nTest Accuracy: {xgb_accuracy * 100:.2f}%")
    
    print("\nClassification Report:")
    print(classification_report(y_test, xgb_pred, target_names=label_names, zero_division=0))
    
    # ============= COMPARISON =============
    print("\n" + "=" * 60)
    print("                  COMPARISON")
    print("=" * 60)
    
    print("\n+--------------------+------------------+------------------+")
    print("| Metric             | Random Forest    | XGBoost          |")
    print("+--------------------+------------------+------------------+")
    print(f"| Test Accuracy      | {rf_accuracy*100:>14.2f}% | {xgb_accuracy*100:>14.2f}% |")
    print(f"| CV Mean            | {rf_cv_scores.mean():>15.4f} | {xgb_cv_scores.mean():>15.4f} |")
    print(f"| CV Std             | {rf_cv_scores.std():>15.4f} | {xgb_cv_scores.std():>15.4f} |")
    print("+--------------------+------------------+------------------+")
    
    # Determine winner
    diff = xgb_accuracy - rf_accuracy
    if diff > 0.01:
        winner = "XGBoost"
        winner_model = xgb_model
        winner_accuracy = xgb_accuracy
    elif diff < -0.01:
        winner = "Random Forest"
        winner_model = rf_model
        winner_accuracy = rf_accuracy
    else:
        winner = "TIE (Both similar)"
        winner_model = xgb_model if xgb_accuracy >= rf_accuracy else rf_model
        winner_accuracy = max(xgb_accuracy, rf_accuracy)
    
    print(f"\n WINNER: {winner}")
    print(f"   Difference: {abs(diff)*100:.2f}%")
    
    # Save best model
    model_path = os.path.join(script_dir, 'model.pkl')
    model_data = {
        'model': winner_model,
        'feature_names': feature_names,
        'label_map': label_map,
        'label_names': label_names,
        'model_type': winner
    }
    
    joblib.dump(model_data, model_path)
    print(f"\n Best model ({winner}) saved to {model_path}")
    print(f" Final Accuracy: {winner_accuracy * 100:.2f}%")
    
    # Feature importance
    print("\n Top 10 Important Features:")
    if hasattr(winner_model, 'feature_importances_'):
        importances = list(zip(feature_names, winner_model.feature_importances_))
        importances.sort(key=lambda x: x[1], reverse=True)
        for name, importance in importances[:10]:
            print(f"  {name}: {importance:.4f}")
    
    return {
        'rf_accuracy': rf_accuracy,
        'xgb_accuracy': xgb_accuracy,
        'winner': winner
    }


if __name__ == '__main__':
    compare_models()
