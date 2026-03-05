"""
Prediction Module for Road Hazard Detection
Loads trained model and makes predictions on sensor data.
"""

import os
import sys
import json
import numpy as np
import joblib
from preprocess import preprocess_for_prediction


def load_model(model_path: str = None):
    """Load the trained model and metadata."""
    if model_path is None:
        script_dir = os.path.dirname(os.path.abspath(__file__))
        model_path = os.path.join(script_dir, 'model.pkl')
    
    if not os.path.exists(model_path):
        raise FileNotFoundError(f"Model not found at {model_path}. Run train_model.py first.")
    
    return joblib.load(model_path)


def predict(sensor_data: list, model_data: dict = None) -> dict:
    """
    Make hazard predictions on sensor data.
    
    Args:
        sensor_data: List of sensor readings
        model_data: Pre-loaded model data (optional)
        
    Returns:
        Dictionary with predictions and summary
    """
    if model_data is None:
        model_data = load_model()
    
    model = model_data['model']
    feature_names = model_data['feature_names']
    label_names = model_data['label_names']
    
    # Preprocess data
    X, _, window_indices = preprocess_for_prediction(sensor_data)
    
    if len(X) == 0:
        return {
            'success': False,
            'error': 'Not enough data for prediction (need at least 10 readings)',
            'predictions': [],
            'summary': {}
        }
    
    # Make predictions
    predictions = model.predict(X)
    probabilities = model.predict_proba(X)
    
    # Create detailed results
    detailed_predictions = []
    for i, (pred, prob, idx) in enumerate(zip(predictions, probabilities, window_indices)):
        label = label_names[pred]
        confidence = float(np.max(prob))
        
        # Get location info if available
        reading = sensor_data[min(idx, len(sensor_data) - 1)]
        
        detailed_predictions.append({
            'window_index': i,
            'reading_index': idx,
            'hazard_type': label,
            'confidence': round(confidence, 3),
            'latitude': reading.get('latitude', 0),
            'longitude': reading.get('longitude', 0),
            'timestamp': reading.get('timestamp', '')
        })
    
    # Calculate summary
    hazard_counts = {}
    for pred in detailed_predictions:
        hazard_type = pred['hazard_type']
        hazard_counts[hazard_type] = hazard_counts.get(hazard_type, 0) + 1
    
    # Find hazard events (non-smooth predictions)
    hazards_detected = [p for p in detailed_predictions if p['hazard_type'] != 'smooth']
    
    summary = {
        'total_windows': len(predictions),
        'hazard_counts': hazard_counts,
        'hazards_detected': len(hazards_detected),
        'hazard_locations': hazards_detected
    }
    
    return {
        'success': True,
        'predictions': detailed_predictions,
        'summary': summary
    }


def predict_from_json(json_input: str) -> str:
    """
    Predict from JSON string input (for subprocess calls).
    
    Args:
        json_input: JSON string of sensor data
        
    Returns:
        JSON string of prediction results
    """
    try:
        sensor_data = json.loads(json_input)
        result = predict(sensor_data)
        return json.dumps(result)
    except Exception as e:
        return json.dumps({
            'success': False,
            'error': str(e),
            'predictions': [],
            'summary': {}
        })


if __name__ == '__main__':
    # Handle command-line input for subprocess calls
    if len(sys.argv) > 1:
        # Read JSON from command line or file
        input_arg = sys.argv[1]
        
        if os.path.exists(input_arg):
            # It's a file path
            with open(input_arg, 'r') as f:
                sensor_data = json.load(f)
        else:
            # It's JSON string
            sensor_data = json.loads(input_arg)
        
        result = predict(sensor_data)
        print(json.dumps(result, indent=2))
    else:
        # Demo mode: test with demo session
        script_dir = os.path.dirname(os.path.abspath(__file__))
        demo_file = os.path.join(script_dir, 'demo_session.json')
        
        if os.path.exists(demo_file):
            print("Testing prediction with demo session...")
            with open(demo_file, 'r') as f:
                demo_data = json.load(f)
            
            result = predict(demo_data)
            
            print(f"\n Prediction Results:")
            print(f"Total windows analyzed: {result['summary']['total_windows']}")
            print(f"Hazards detected: {result['summary']['hazards_detected']}")
            print(f"\nHazard counts: {result['summary']['hazard_counts']}")
            
            if result['summary']['hazard_locations']:
                print(f"\n Hazard Locations:")
                for h in result['summary']['hazard_locations'][:5]:  # Show first 5
                    print(f"  - {h['hazard_type']} (confidence: {h['confidence']:.2f}) at index {h['reading_index']}")
        else:
            print("Demo session not found. Run generate_data.py first.")
