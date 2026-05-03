// src/services/DetectionProcessor.js
import pool from "../config/db.js";
import ConfidenceCalculator from "../utils/ConfidenceCalculator.js";

export default class DetectionProcessor {
  constructor() {
    this.PROXIMITY_THRESHOLD = 10; // metres
  }

  async processUnprocessedDetections() {
    const client = await pool.connect();

    try {
      const result = await client.query(`
        SELECT * FROM ml_detections
        WHERE processed = FALSE
        ORDER BY detected_at ASC
        LIMIT 100
      `);

      if (result.rows.length > 0) {
        console.log(`\n⚙️  ═══════════════════════════════════════`);
        console.log(`⚙️  [CRON] Found ${result.rows.length} unprocessed detections`);
        console.log(`⚙️  ═══════════════════════════════════════`);
      } else {
        console.log(`[DetectionProcessor] Found 0 unprocessed detections`);
      }

      for (const detection of result.rows) {
        await this.processDetection(detection, client);
      }

      return { processed: result.rows.length };
    } catch (error) {
      console.error('[DetectionProcessor] Error:', error);
      throw error;
    } finally {
      client.release();
    }
  }

  async processDetection(detection, client) {
    try {
      const nearbyHazard = await this.findNearbyHazard(
        detection.latitude,
        detection.longitude,
        detection.hazard_type,
        client
      );

      if (nearbyHazard) {
        await this.updateHazard(nearbyHazard.id, detection, client);
        console.log(`   🔄 [CRON] Updated existing hazard #${nearbyHazard.id} (${detection.hazard_type}) — ${nearbyHazard.distance?.toFixed(1)}m away`);
      } else {
        const newHazard = await this.createHazard(detection, client);
        console.log(`   🆕 [CRON] Created NEW hazard #${newHazard.id} — ${detection.hazard_type} at (${detection.latitude}, ${detection.longitude})`);
      }

      await client.query(
        'UPDATE ml_detections SET processed = TRUE, processed_at = NOW() WHERE id = $1',
        [detection.id]
      );
    } catch (error) {
      console.error(`[DetectionProcessor] Error processing detection ${detection.id}:`, error);
      throw error;
    }
  }

  async findNearbyHazard(lat, lon, type, client) {
    const result = await client.query(`
      SELECT
        id, confidence_score, detection_count,
        ST_Distance(
          location::geography,
          ST_SetSRID(ST_MakePoint($2, $1), 4326)::geography
        ) as distance
      FROM hazards
      WHERE hazard_type = $3
        AND status != 'expired'
        AND ST_DWithin(
          location::geography,
          ST_SetSRID(ST_MakePoint($2, $1), 4326)::geography,
          $4
        )
      ORDER BY distance ASC
      LIMIT 1
    `, [lat, lon, type, this.PROXIMITY_THRESHOLD]);

    return result.rows[0] || null;
  }

  async updateHazard(hazardId, detection, client) {
    const delta = ConfidenceCalculator.SCORE_CHANGES.ML_DETECTION;

    const result = await client.query(`
      UPDATE hazards
      SET
        confidence_score = LEAST(1.0, confidence_score + $1),
        detection_count  = detection_count + 1,
        last_updated     = NOW(),
        status = CASE
          WHEN confidence_score + $1 >= 0.80 THEN 'verified'
          WHEN confidence_score + $1 >= 0.50 THEN 'pending'
          ELSE 'expired'
        END
      WHERE id = $2
      RETURNING *
    `, [delta, hazardId]);

    await client.query(`
      INSERT INTO processing_log (event_type, hazard_id, details)
      VALUES ('hazard_updated', $1, $2)
    `, [
      hazardId,
      JSON.stringify({
        new_confidence: result.rows[0].confidence_score,
        detection_id: detection.id,
        detection_count: result.rows[0].detection_count,
      }),
    ]);

    return result.rows[0];
  }

  async createHazard(detection, client) {
    const initialConfidence = ConfidenceCalculator.SCORE_CHANGES.ML_DETECTION;

    // Resolve decay_rate from known types; default 0.020 for unknown types
    const decayRates = ConfidenceCalculator.DECAY_RATES;
    const decayRate = decayRates[detection.hazard_type] ?? 0.020;

    const result = await client.query(`
      INSERT INTO hazards (
        location, hazard_type, confidence_score,
        status, detection_count, first_detected, last_updated, decay_rate
      ) VALUES (
        ST_SetSRID(ST_MakePoint($1, $2), 4326),
        $3,
        $4,
        $5,
        1,
        NOW(),
        NOW(),
        $6
      )
      RETURNING id, hazard_type, confidence_score, status
    `, [
      detection.longitude,
      detection.latitude,
      detection.hazard_type,
      initialConfidence,
      ConfidenceCalculator.getStatus(initialConfidence),
      decayRate,
    ]);

    await client.query(`
      INSERT INTO processing_log (event_type, hazard_id, details)
      VALUES ('hazard_created', $1, $2)
    `, [
      result.rows[0].id,
      JSON.stringify({
        type: detection.hazard_type,
        source: 'ml_detection',
        device_id: detection.device_id,
        decay_rate: decayRate,
      }),
    ]);

    return result.rows[0];
  }
}
