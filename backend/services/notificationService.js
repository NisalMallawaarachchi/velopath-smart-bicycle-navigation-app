// services/NotificationService.js
import pool from "../config/db.js";

class NotificationService {
  constructor() {
    this.APPROACHING_DISTANCE  = 50;   // metres — show warning 50m before hazard
    this.PASSED_DISTANCE       = 20;   // metres — ask confirmation 20m after hazard
    this.MAX_NOTIFICATION_AGE  = 300;  // seconds — re-prompt cooldown after skip

    // In-memory cooldown tracker: key `${userId}_${hazardId}` → timestamp (ms)
    // Resets on server restart, which is acceptable for a 5-minute cooldown window.
    this._notifiedAt = new Map();
  }

  /**
   * Record that a notification was shown (or skipped) for this user+hazard pair.
   * Prevents re-prompting within MAX_NOTIFICATION_AGE seconds.
   */
  markNotified(hazardId, userId) {
    this._notifiedAt.set(`${userId}_${hazardId}`, Date.now());
  }

  /**
   * Get hazards that cyclist is approaching (within APPROACHING_DISTANCE metres).
   */
  async getApproachingHazards(userLat, userLon) {
    try {
      const result = await pool.query(
        `
        SELECT
          id,
          ST_Y(location::geometry) as latitude,
          ST_X(location::geometry) as longitude,
          hazard_type,
          confidence_score,
          status,
          ST_Distance(
            location,
            ST_SetSRID(ST_MakePoint($1, $2), 4326)::geography
          ) as distance_meters
        FROM hazards
        WHERE status IN ('verified', 'pending')
          AND confidence_score >= 0.50
          AND ST_DWithin(
            location,
            ST_SetSRID(ST_MakePoint($1, $2), 4326)::geography,
            $3
          )
        ORDER BY distance_meters ASC
        LIMIT 5
        `,
        [userLon, userLat, this.APPROACHING_DISTANCE]
      );

      return result.rows.map(h => ({
        id: h.id,
        type: h.hazard_type,
        confidence: parseFloat(h.confidence_score),
        status: h.status,
        distance: Math.round(h.distance_meters),
        location: {
          lat: parseFloat(h.latitude),
          lon: parseFloat(h.longitude),
        },
        message: `${h.hazard_type.toUpperCase()} AHEAD (${Math.round(h.distance_meters)}m)`,
      }));
    } catch (error) {
      console.error("[NotificationService] Error getting approaching hazards:", error);
      return [];
    }
  }

  /**
   * Get hazards the cyclist just passed (within PASSED_DISTANCE metres)
   * that the user has not yet confirmed or denied.
   */
  async getRecentlyPassedHazards(userLat, userLon, userId) {
    try {
      const result = await pool.query(
        `
        SELECT
          h.id,
          ST_Y(h.location::geometry) as latitude,
          ST_X(h.location::geometry) as longitude,
          h.hazard_type,
          h.confidence_score,
          h.status,
          ST_Distance(
            h.location,
            ST_SetSRID(ST_MakePoint($1, $2), 4326)::geography
          ) as distance_meters,
          uc.user_id as already_responded
        FROM hazards h
        LEFT JOIN user_confirmations uc
          ON h.id = uc.hazard_id AND uc.user_id = $3
        WHERE h.status IN ('verified', 'pending')
          AND h.confidence_score >= 0.30
          AND ST_DWithin(
            h.location,
            ST_SetSRID(ST_MakePoint($1, $2), 4326)::geography,
            $4
          )
          AND uc.user_id IS NULL
        ORDER BY distance_meters ASC
        LIMIT 3
        `,
        [userLon, userLat, userId, this.PASSED_DISTANCE]
      );

      return result.rows.map(h => ({
        id: h.id,
        type: h.hazard_type,
        confidence: parseFloat(h.confidence_score),
        status: h.status,
        distance: Math.round(h.distance_meters),
        location: {
          lat: parseFloat(h.latitude),
          lon: parseFloat(h.longitude),
        },
        question: `Did you just pass a ${h.hazard_type}?`,
      }));
    } catch (error) {
      console.error("[NotificationService] Error getting passed hazards:", error);
      return [];
    }
  }

  /**
   * Returns true only if:
   *  1. The user has never confirmed/denied this hazard (permanent block), AND
   *  2. The user was not shown this notification within the last MAX_NOTIFICATION_AGE
   *     seconds (handles skips and rapid re-polls).
   */
  async shouldPromptUser(hazardId, userId) {
    // Check in-memory cooldown (covers skip + rapid polling)
    const key = `${userId}_${hazardId}`;
    const lastShown = this._notifiedAt.get(key);
    if (lastShown) {
      const elapsedSeconds = (Date.now() - lastShown) / 1000;
      if (elapsedSeconds < this.MAX_NOTIFICATION_AGE) return false;
      this._notifiedAt.delete(key); // cooldown expired — clean up
    }

    try {
      // Permanent block if user already confirmed or denied
      const result = await pool.query(
        `SELECT 1 FROM user_confirmations
         WHERE hazard_id = $1 AND user_id = $2`,
        [hazardId, userId]
      );
      return result.rows.length === 0;
    } catch (error) {
      console.error("[NotificationService] Error checking prompt status:", error);
      return false;
    }
  }
}

export default NotificationService;
