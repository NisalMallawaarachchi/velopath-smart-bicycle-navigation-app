// services/NotificationService.js
// This service determines when to show yes/no notifications to cyclists

import pool from "../config/db.js";

class NotificationService {
  constructor() {
    // Distance thresholds
    this.APPROACHING_DISTANCE = 50; // Show warning 50m before
    this.PASSED_DISTANCE = 20;      // Ask confirmation 20m after
    this.MAX_NOTIFICATION_AGE = 300; // Don't ask again for 5 minutes
  }

  /**
   * Get hazards that cyclist is approaching (within 50m ahead)
   * Used to show: "⚠️ POTHOLE AHEAD - Is it still there?"
   */
  async getApproachingHazards(userLat, userLon, userHeading = null) {
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
          lon: parseFloat(h.longitude)
        },
        message: `${h.hazard_type.toUpperCase()} AHEAD (${Math.round(h.distance_meters)}m)`
      }));

    } catch (error) {
      console.error("[NotificationService] Error getting approaching hazards:", error);
      return [];
    }
  }

  /**
   * Get hazards that cyclist just passed (within 20m behind)
   * Used to ask: "Did you just pass a pothole?"
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
          lon: parseFloat(h.longitude)
        },
        question: `Did you just pass a ${h.hazard_type}?`
      }));

    } catch (error) {
      console.error("[NotificationService] Error getting passed hazards:", error);
      return [];
    }
  }

  /**
   * Check if user should be prompted about a specific hazard
   */
  async shouldPromptUser(hazardId, userId) {
    try {
      // Check if user already responded
      const result = await pool.query(
        `SELECT * FROM user_confirmations 
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