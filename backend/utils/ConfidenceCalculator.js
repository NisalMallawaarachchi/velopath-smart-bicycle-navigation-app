export default class ConfidenceCalculator {
  static THRESHOLDS = {
    VERIFIED: 0.80,
    EXPIRED: 0.50,
    DELETED: 0.20
  };

  static SCORE_CHANGES = {
    ML_DETECTION: 0.15,
    USER_CONFIRM: 0.30,
    USER_DENY: -0.40
  };

  static DECAY_RATES = {
    pothole: 0.030,
    bump: 0.008
  };

  static getCurrentConfidence(hazard) {
    const daysSinceUpdate = this.getDaysSince(hazard.last_updated);
    const decayRate = hazard.decay_accelerated
      ? parseFloat(hazard.decay_rate) * 2
      : parseFloat(hazard.decay_rate);
    const currentScore = parseFloat(hazard.confidence_score);
    const decayedConfidence = currentScore * Math.exp(-decayRate * daysSinceUpdate);
    return Math.max(0, Math.min(1, decayedConfidence));
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
    if (score >= this.THRESHOLDS.EXPIRED) return 'pending';
    return 'expired';
  }

  static getDaysSince(timestamp) {
    const then = new Date(timestamp);
    const now = new Date();
    return (now - then) / (1000 * 60 * 60 * 24);
  }
}
