export default class ConfidenceCalculator {
  static THRESHOLDS = {
    VERIFIED: 0.80,
    PENDING:  0.50,
    EXPIRED:  0.20,  // below this threshold hazards are deleted by cleanupExpired
  };

  static SCORE_CHANGES = {
    ML_DETECTION: 0.20,  // raised from 0.15 — initial score must be >= EXPIRED threshold
    USER_CONFIRM: 0.30,
    USER_DENY:   -0.40,
  };

  // Decay rates per day (k in: confidence(t) = C0 * e^(-k * days))
  static DECAY_RATES = {
    pothole: 0.030,  // ~23 days to 50% confidence
    bump:    0.008,  // ~87 days to 50% confidence
    rough:   0.015,  // ~46 days to 50% confidence
  };

  static getCurrentConfidence(hazard) {
    const daysSinceUpdate = this.getDaysSince(hazard.last_updated);
    const decayRate = hazard.decay_accelerated
      ? parseFloat(hazard.decay_rate) * 2
      : parseFloat(hazard.decay_rate);
    const currentScore = parseFloat(hazard.confidence_score);
    return Math.max(0, Math.min(1, currentScore * Math.exp(-decayRate * daysSinceUpdate)));
  }

  static shouldAccelerateDecay(hazard) {
    if (!hazard.last_confirmed) return false;
    return this.getDaysSince(hazard.last_confirmed) > 7;
  }

  static updateConfidence(currentConfidence, eventType) {
    const change = this.SCORE_CHANGES[eventType] || 0;
    return Math.max(0, Math.min(1, parseFloat(currentConfidence) + change));
  }

  static getStatus(confidence) {
    const score = parseFloat(confidence);
    if (score >= this.THRESHOLDS.VERIFIED) return 'verified';
    if (score >= this.THRESHOLDS.PENDING)  return 'pending';
    return 'expired';
  }

  static getDaysSince(timestamp) {
    const then = new Date(timestamp);
    const now  = new Date();
    return (now - then) / (1000 * 60 * 60 * 24);
  }
}
