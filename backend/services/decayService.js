// src/services/DecayService.js
import pool from "../config/db.js";

export default class DecayService {
  async runDecay() {
    const client = await pool.connect();

    try {
      console.log('[DecayService] Starting decay run...');

      await this.checkAcceleratedDecay(client);
      const updated = await this.applyDecay(client);
      const deleted = await this.cleanupExpired(client);

      console.log(`[DecayService] Updated ${updated} hazards, deleted ${deleted} expired hazards`);

      await client.query(`
        INSERT INTO processing_log (event_type, details)
        VALUES ('decay_run', $1)
      `, [JSON.stringify({ updated, deleted, timestamp: new Date() })]);

      return { updated, deleted };
    } catch (error) {
      console.error('[DecayService] Error:', error);
      throw error;
    } finally {
      client.release();
    }
  }

  async checkAcceleratedDecay(client) {
    await client.query(`
      UPDATE hazards
      SET decay_accelerated = TRUE
      WHERE status IN ('pending', 'verified')
        AND (
          last_confirmed IS NULL 
          OR last_confirmed < NOW() - INTERVAL '7 days'
        )
        AND decay_accelerated = FALSE
    `);
  }

  async applyDecay(client) {
    const result = await client.query(`
      WITH decay_calc AS (
        SELECT 
          id,
          confidence_score * EXP(
            -(CASE WHEN decay_accelerated THEN decay_rate * 2 ELSE decay_rate END) 
            * EXTRACT(EPOCH FROM (NOW() - last_updated)) / 86400.0
          ) as new_confidence
        FROM hazards
        WHERE status IN ('pending', 'verified')
      )
      UPDATE hazards h
      SET 
        confidence_score = dc.new_confidence,
        last_updated = NOW(),
        status = CASE
          WHEN dc.new_confidence >= 0.80 THEN 'verified'
          WHEN dc.new_confidence >= 0.50 THEN 'pending'
          ELSE 'expired'
        END
      FROM decay_calc dc
      WHERE h.id = dc.id
      RETURNING h.id
    `);

    return result.rowCount;
  }

  async cleanupExpired(client) {
    const result = await client.query(`
      DELETE FROM hazards
      WHERE confidence_score < 0.20
      RETURNING id, hazard_type
    `);

    return result.rowCount;
  }
}
