// controllers/hazardsController.js
import pool from '../config/db.js';
import ConfidenceCalculator from '../utils/ConfidenceCalculator.js';

// GET /api/hazards
export const getHazards = async (req, res) => {
  const { minLat, maxLat, minLon, maxLon, minConfidence = 0.5 } = req.query;

  if (!minLat || !maxLat || !minLon || !maxLon) {
    return res.status(400).json({
      success: false,
      error: 'Missing required parameters: minLat, maxLat, minLon, maxLon'
    });
  }

  try {
    const result = await pool.query(`
      SELECT 
        id,
        ST_Y(location::geometry) as latitude,
        ST_X(location::geometry) as longitude,
        hazard_type,
        confidence_score,
        status,
        detection_count,
        confirmation_count,
        last_updated
      FROM hazards
      WHERE status IN ('verified', 'pending')
        AND confidence_score >= $5
        AND ST_Intersects(
          location,
          ST_MakeEnvelope($1, $2, $3, $4, 4326)
        )
      ORDER BY confidence_score DESC
    `, [
      parseFloat(minLon),
      parseFloat(minLat),
      parseFloat(maxLon),
      parseFloat(maxLat),
      parseFloat(minConfidence)
    ]);

    res.json({
      success: true,
      count: result.rows.length,
      hazards: result.rows.map(h => ({
        id: h.id,
        location: { lat: parseFloat(h.latitude), lon: parseFloat(h.longitude) },
        type: h.hazard_type,
        confidence: parseFloat(h.confidence_score).toFixed(2),
        status: h.status,
        detectionCount: h.detection_count,
        confirmationCount: h.confirmation_count,
        lastUpdated: h.last_updated
      }))
    });
  } catch (error) {
    console.error('[HazardsController] Error fetching hazards:', error);
    res.status(500).json({ success: false, error: error.message });
  }
};

// GET /api/hazards/:id
export const getHazardById = async (req, res) => {
  const { id } = req.params;

  try {
    const result = await pool.query(`
      SELECT 
        id,
        ST_Y(location::geometry) as latitude,
        ST_X(location::geometry) as longitude,
        hazard_type,
        confidence_score,
        status,
        detection_count,
        confirmation_count,
        denial_count,
        first_detected,
        last_updated,
        last_confirmed,
        decay_rate,
        decay_accelerated
      FROM hazards
      WHERE id = $1
    `, [id]);

    if (!result.rows.length) return res.status(404).json({ success: false, error: 'Hazard not found' });

    const h = result.rows[0];
    res.json({
      success: true,
      hazard: {
        id: h.id,
        location: { lat: parseFloat(h.latitude), lon: parseFloat(h.longitude) },
        type: h.hazard_type,
        confidence: parseFloat(h.confidence_score).toFixed(3),
        status: h.status,
        detectionCount: h.detection_count,
        confirmationCount: h.confirmation_count,
        denialCount: h.denial_count,
        firstDetected: h.first_detected,
        lastUpdated: h.last_updated,
        lastConfirmed: h.last_confirmed,
        decayRate: parseFloat(h.decay_rate),
        decayAccelerated: h.decay_accelerated
      }
    });

  } catch (error) {
    console.error('[HazardsController] Error fetching hazard:', error);
    res.status(500).json({ success: false, error: error.message });
  }
};

// POST /api/hazards/:id/confirm
export const confirmHazard = async (req, res) => {
  const { id } = req.params;
  const user_id = req.user?.id;
  const { comment } = req.body;
  if (!user_id) return res.status(401).json({ success: false, error: 'Authentication required' });

  const client = await pool.connect();
  try {
    await client.query('BEGIN');

    const existing = await client.query(
      'SELECT * FROM user_confirmations WHERE hazard_id = $1 AND user_id = $2',
      [id, user_id]
    );
    if (existing.rows.length) {
      await client.query('ROLLBACK');
      return res.status(400).json({ success: false, error: 'User already confirmed this hazard' });
    }

    await client.query(
      'INSERT INTO user_confirmations (hazard_id, user_id, action, comment) VALUES ($1, $2, \'confirm\', $3)',
      [id, user_id, comment]
    );

    const result = await client.query(`
      UPDATE hazards
      SET 
        confidence_score = LEAST(1.0, confidence_score + $1),
        confirmation_count = confirmation_count + 1,
        last_confirmed = NOW(),
        last_updated = NOW(),
        decay_accelerated = FALSE,
        status = CASE WHEN confidence_score + $1 >= 0.80 THEN 'verified' ELSE status END
      WHERE id = $2
      RETURNING confidence_score, status
    `, [ConfidenceCalculator.SCORE_CHANGES.USER_CONFIRM, id]);

    if (!result.rows.length) { await client.query('ROLLBACK'); return res.status(404).json({ success: false, error: 'Hazard not found' }); }

    await client.query('COMMIT');

    res.json({
      success: true,
      hazard_id: id,
      new_confidence: parseFloat(result.rows[0].confidence_score).toFixed(3),
      status: result.rows[0].status,
      message: 'Thank you for confirming this hazard'
    });

  } catch (error) {
    await client.query('ROLLBACK');
    console.error('[HazardsController] Error confirming hazard:', error);
    res.status(500).json({ success: false, error: error.message });
  } finally {
    client.release();
  }
};

// POST /api/hazards/:id/deny
export const denyHazard = async (req, res) => {
  const { id } = req.params;
  const user_id = req.user?.id;
  const { comment } = req.body;
  if (!user_id) return res.status(401).json({ success: false, error: 'Authentication required' });

  const client = await pool.connect();
  try {
    await client.query('BEGIN');

    await client.query(`
      INSERT INTO user_confirmations (hazard_id, user_id, action, comment)
      VALUES ($1, $2, 'deny', $3)
      ON CONFLICT (hazard_id, user_id) DO UPDATE 
      SET action='deny', comment=$3, timestamp=NOW()
    `, [id, user_id, comment]);

    const result = await client.query(`
      UPDATE hazards
      SET 
        confidence_score = GREATEST(0, confidence_score + $1),
        denial_count = denial_count + 1,
        last_updated = NOW(),
        status = CASE WHEN confidence_score + $1 < 0.50 THEN 'expired' ELSE status END
      WHERE id = $2
      RETURNING confidence_score, status
    `, [ConfidenceCalculator.SCORE_CHANGES.USER_DENY, id]);

    if (!result.rows.length) { await client.query('ROLLBACK'); return res.status(404).json({ success: false, error: 'Hazard not found' }); }

    await client.query('COMMIT');

    res.json({
      success: true,
      hazard_id: id,
      new_confidence: parseFloat(result.rows[0].confidence_score).toFixed(3),
      status: result.rows[0].status,
      message: 'Thank you for reporting. Hazard marked for removal.'
    });

  } catch (error) {
    await client.query('ROLLBACK');
    console.error('[HazardsController] Error denying hazard:', error);
    res.status(500).json({ success: false, error: error.message });
  } finally {
    client.release();
  }
};

// GET /api/hazards/stats
export const getHazardStats = async (req, res) => {
  try {
    const result = await pool.query('SELECT * FROM system_stats');
    res.json({ success: true, stats: result.rows[0], timestamp: new Date().toISOString() });
  } catch (error) {
    console.error('[HazardsController] Error fetching stats:', error);
    res.status(500).json({ success: false, error: error.message });
  }
};
