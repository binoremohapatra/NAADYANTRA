"""
Acoustic Leak Detection Inference Engine for NAADYANTRA / HazGuard
==================================================================
Loads trained baseline model artifacts (Random Forest or Logistic Regression)
and runs inference on contact-piezo acoustic time series or extracted feature vectors.

Firmware / Signal Specification:
  - Acoustic transducer: Contact Piezo Sensor with virtual ground bias (1.65V DC)
  - Sampling Rate: 4000 Hz
  - Window Size: 1000 ms (4000 samples)
  - Preprocessing: First-order IIR DC-blocking filter (R = 0.995)
  - Features: 9 time & frequency domain metrics (RMS, STD, Peak, Crest Factor,
              Zero-Crossing Rate, Band Energies [0-500Hz, 500-1000Hz, 1000-2000Hz], Total Energy)
  - Classes: 'leak_like', 'noise', 'normal'

Usage:
  python ml/src/inference.py --synthetic-test
  python ml/src/inference.py --model-dir ml/models/random_forest_baseline --input-file sample.csv
"""

import argparse
import json
import sys
from pathlib import Path
from typing import Dict, Any, Optional, Union, List
import numpy as np
import joblib

# Import repository signal tools
try:
    from ml.src.preprocessing import SignalPreprocessor
    from ml.src.generate_synthetic import SyntheticSignalGenerator
except ImportError:
    from preprocessing import SignalPreprocessor
    from generate_synthetic import SyntheticSignalGenerator


class AcousticLeakClassifier:
    """Production inference engine for acoustic leak detection."""

    def __init__(self, model_dir: Union[str, Path]):
        self.model_dir = Path(model_dir)
        self.model_path = self.model_dir / "model.joblib"
        self.scaler_path = self.model_dir / "scaler.joblib"
        self.label_encoder_path = self.model_dir / "label_encoder.joblib"
        self.metadata_path = self.model_dir / "metadata.json"

        if not self.model_path.exists():
            raise FileNotFoundError(f"Model file not found: {self.model_path}")

        # Load artifacts
        self.model = joblib.load(self.model_path)
        self.scaler = joblib.load(self.scaler_path) if self.scaler_path.exists() else None
        self.label_encoder = joblib.load(self.label_encoder_path) if self.label_encoder_path.exists() else None

        if self.metadata_path.exists():
            with open(self.metadata_path, "r") as f:
                self.metadata = json.load(f)
        else:
            self.metadata = {}

        self.feature_names = self.metadata.get("feature_names", [
            "rms", "std", "peak_amplitude", "crest_factor", "zero_crossing_rate",
            "band_energy_0_500", "band_energy_500_1000", "band_energy_1000_2000", "total_energy"
        ])

        # Resolve human-readable class names
        if self.label_encoder is not None and hasattr(self.label_encoder, "classes_"):
            self.class_names = list(self.label_encoder.classes_)
        elif "label_classes" in self.metadata:
            self.class_names = list(self.metadata["label_classes"])
        else:
            self.class_names = ["leak_like", "noise", "normal"]

        self.preprocessor = SignalPreprocessor(sample_rate=4000, window_duration_ms=1000, dc_block_coeff=0.995)

    def extract_features_from_signal(self, signal: np.ndarray) -> Dict[str, float]:
        """Extract the authoritative 9 features from raw 4000 Hz ADC samples."""
        return self.preprocessor.extract_features(signal)

    def predict_features(self, features: Dict[str, float]) -> Dict[str, Any]:
        """Run ML inference on an extracted feature dictionary."""
        # Align features with expected order
        vec = np.array([features[name] for name in self.feature_names], dtype=np.float32).reshape(1, -1)

        # Scale if scaler available
        if self.scaler is not None:
            vec_scaled = self.scaler.transform(vec)
        else:
            vec_scaled = vec

        # Compute probabilities
        if hasattr(self.model, "predict_proba"):
            raw_probs = self.model.predict_proba(vec_scaled)[0]
        else:
            pred = self.model.predict(vec_scaled)[0]
            raw_probs = np.zeros(len(self.class_names))
            raw_probs[int(pred)] = 1.0

        class_probs = {self.class_names[i]: float(raw_probs[i]) for i in range(len(self.class_names))}
        top_idx = int(np.argmax(raw_probs))
        top_class = self.class_names[top_idx]
        leak_p = class_probs.get("leak_like", class_probs.get("leak", 0.0))

        return {
            "predicted_label": str(top_class),
            "confidence": float(np.max(raw_probs)),
            "probabilities": class_probs,
            "leak_probability": float(leak_p),
            "rms": float(features.get("rms", 0.0)),
            "is_model_based": True,
            "model_type": self.metadata.get("model_type", "scikit-learn"),
            "model_name": self.metadata.get("model_name", self.model_dir.name)
        }

    def predict_signal(self, signal: np.ndarray) -> Dict[str, Any]:
        """Run end-to-end preprocessing, feature extraction, and ML inference."""
        features = self.extract_features_from_signal(signal)
        res = self.predict_features(features)
        res["features"] = features
        return res


def main():
    parser = argparse.ArgumentParser(description="NAADYANTRA Acoustic Leak Model Inference")
    parser.add_argument("--model-dir", type=str, default="ml/models/random_forest_baseline",
                        help="Path to trained model directory containing model.joblib and metadata.json")
    parser.add_argument("--input-file", type=str, default=None,
                        help="Optional CSV file of raw audio samples or feature vector")
    parser.add_argument("--synthetic-test", action="store_true",
                        help="Run verification inference across synthetic leak, noise, and normal benchmark signals")
    args = parser.parse_args()

    model_dir = Path(args.model_dir)
    if not model_dir.exists():
        print(f"Error: Model directory not found: {model_dir}", file=sys.stderr)
        sys.exit(1)

    classifier = AcousticLeakClassifier(model_dir)
    print(f"Loaded classifier: {classifier.metadata.get('model_name', model_dir.name)}")
    print(f"Authoritative Classes: {classifier.class_names}")
    print(f"Feature count: {len(classifier.feature_names)}")

    if args.synthetic_test:
        print("\n=== Running Synthetic Benchmark Signals ===")
        generator = SyntheticSignalGenerator(sample_rate=4000, window_duration_ms=1000, random_seed=42)
        benchmarks = {
            "leak": generator.generate_leak_like(duration_ms=1000),
            "noise": generator.generate_noise(duration_ms=1000),
            "normal": generator.generate_normal(duration_ms=1000),
        }
        for sig_kind, sig in benchmarks.items():
            result = classifier.predict_signal(sig)
            print(f"\n[Test Signal: {sig_kind.upper()}]")
            print(f"  Predicted Label : {result['predicted_label']}")
            print(f"  Confidence      : {result['confidence']:.3f}")
            print(f"  Leak Probability: {result['leak_probability']:.3f}")
            print(f"  RMS             : {result['rms']:.2f}")
            print(f"  Class Probs     : {result['probabilities']}")
            print(f"  Model-based     : {result['is_model_based']}")
    elif args.input_file:
        data = np.loadtxt(args.input_file, delimiter=",")
        if data.ndim == 1 and len(data) >= 1000:
            result = classifier.predict_signal(data)
        else:
            result = classifier.predict_signal(data.flatten())
        print(json.dumps(result, indent=2))
    else:
        print("\nSpecify --synthetic-test to evaluate with benchmark signals, or provide --input-file <path>.")


if __name__ == "__main__":
    main()
