// controllers/confirmationController.js
import pool from '../config/db.js';

// GET /api/confirmations/user/:userId — all votes cast by a specific user
export const getUserConfirmations = async (req, res) => {
  const { userId } = req.params;
  try {
    const result = await pool.query(`
      SELECT 
        uc.id,
        uc.hazard_id,
        uc.action,
        uc.comment,
        uc.timestamp,
        h.hazard_type,
        h.status        AS hazard_status,
        h.confidence_score,
        ST_Y(h.location::geometry) AS latitude,
        ST_X(h.location::geometry) AS longitude
      FROM user_confirmations uc
      JOIN hazards h ON h.id = uc.hazard_id
      WHERE uc.user_id = $1
      ORDER BY uc.timestamp DESC
    `, [userId]);

    res.json({
      success: true,
      count: result.rows.length,
      confirmations: result.rows.map(r => ({
        id: r.id,
        hazardId: r.hazard_id,
        action: r.action,
        comment: r.comment,
        timestamp: r.timestamp,
        hazard: {
          type: r.hazard_type,
          status: r.hazard_status,
          confidence: parseFloat(r.confidence_score).toFixed(3),
          location: { lat: parseFloat(r.latitude), lon: parseFloat(r.longitude) }
        }
      }))
    });
  } catch (error) {
    console.error('[ConfirmationController] getUserConfirmations error:', error);
    res.status(500).json({ success: false, error: error.message });
  }
};

// GET /api/confirmations/hazard/:hazardId — all votes on a specific hazard
export const getHazardConfirmations = async (req, res) => {
  const { hazardId } = req.params;
  try {
    const result = await pool.query(`
      SELECT id, user_id, action, comment, timestamp
      FROM user_confirmations
      WHERE hazard_id = $1
      ORDER BY timestamp DESC
    `, [hazardId]);

    const confirms = result.rows.filter(r => r.action === 'confirm').length;
    const denies   = result.rows.filter(r => r.action === 'deny').length;

    res.json({
      success: true,
      hazard_id: hazardId,
      summary: { confirms, denies, total: result.rows.length },
      confirmations: result.rows
    });
  } catch (error) {
    console.error('[ConfirmationController] getHazardConfirmations error:', error);
    res.status(500).json({ success: false, error: error.message });
  }
};
