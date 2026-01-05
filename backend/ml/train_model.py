"""
Model Training Script for Road Hazard Detection
Trains a Random Forest classifier on preprocessed sensor data.
"""

import os
import json
import numpy as np
import joblib
from sklearn.model_selection import train_test_split, cross_val_score
from sklearn.ensemble import RandomForestClassifier
from sklearn.metrics import classification_report, confusion_matrix
from preprocess import preprocess_for_training


def train_model(data_path: str = None, model_path: str = None):
    """
    Train the hazard detection model.
    
    Args:
        data_path: Path to training data JSON
        model_path: Path to save the trained model
    """
    script_dir = os.path.dirname(os.path.abspath(__file__))
    
    if data_path is None:
        data_path = os.path.join(script_dir, 'training_data.json')
    
    if model_path is None:
        model_path = os.path.join(script_dir, 'model.pkl')
    
    # Load training data
    print("Loading training data...")
    with open(data_path, 'r') as f:
        data = json.load(f)
    
    print(f"Loaded {len(data)} raw samples")
    
    # Preprocess data
    print("\nPreprocessing data...")
    X, labels, feature_names = preprocess_for_training(data)
    
    print(f"Created {X.shape[0]} feature vectors with {X.shape[1]} features each")
    
    # Encode labels
    label_map = {'smooth': 0, 'pothole': 1, 'bump': 2}
    y = np.array([label_map[label] for label in labels])
    
    # Split data
    X_train, X_test, y_train, y_test = train_test_split(
        X, y, test_size=0.2, random_state=42, stratify=y
    )
    
    print(f"\nTraining set: {len(X_train)} samples")
    print(f"Test set: {len(X_test)} samples")
    
    # Train Random Forest
    print("\nTraining Random Forest classifier...")
    model = RandomForestClassifier(
        n_estimators=100,
        max_depth=10,
        min_samples_split=5,
        min_samples_leaf=2,
        random_state=42,
        n_jobs=-1
    )
    
    model.fit(X_train, y_train)
    
    # Evaluate with cross-validation
    print("\nCross-validation scores:")
    cv_scores = cross_val_score(model, X_train, y_train, cv=5)
    print(f"  Mean: {cv_scores.mean():.4f} (+/- {cv_scores.std() * 2:.4f})")
    
    # Test set evaluation
    print("\nTest set evaluation:")
    y_pred = model.predict(X_test)
    
    label_names = ['smooth', 'pothole', 'bump']
    print("\nClassification Report:")
    print(classification_report(y_test, y_pred, target_names=label_names))
    
    print("Confusion Matrix:")
    print(confusion_matrix(y_test, y_pred))
    
    # Feature importance
    print("\nTop 10 Important Features:")
    importances = list(zip(feature_names, model.feature_importances_))
    importances.sort(key=lambda x: x[1], reverse=True)
    for name, importance in importances[:10]:
        print(f"  {name}: {importance:.4f}")
    
    # Save model and metadata
    model_data = {
        'model': model,
        'feature_names': feature_names,
        'label_map': label_map,
        'label_names': label_names
    }
    
    joblib.dump(model_data, model_path)
    print(f"\n✅ Model saved to {model_path}")
    
    # Calculate and display accuracy
    accuracy = (y_pred == y_test).mean()
    print(f"\n📊 Test Accuracy: {accuracy * 100:.2f}%")
    
    return model, feature_names


if __name__ == '__main__':
    train_model()
