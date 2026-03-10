import NotificationService from "../services/notificationService.js";
import ConfidenceCalculator from "../utils/ConfidenceCalculator.js";

const notificationService = new NotificationService();

/**
 * GET approaching hazards
 */
export const getApproachingHazards = async (req, res) => {
  const { lat, lon, userId } = req.query;

  if (!lat || !lon || !userId) {
    return res.status(400).json({
      success: false,
      error: "Missing required parameters: lat, lon, userId",
    });
  }

  try {
    const hazards = await notificationService.getApproachingHazards(
      parseFloat(lat),
      parseFloat(lon)
    );

    const unresponded = [];
    for (const hazard of hazards) {
      const shouldPrompt = await notificationService.shouldPromptUser(
        hazard.id,
        userId
      );
      if (shouldPrompt) unresponded.push(hazard);
    }

    res.json({
      success: true,
      count: unresponded.length,
      hazards: unresponded,
    });
  } catch (error) {
    console.error("[Controller] Approaching hazards error:", error);
    res.status(500).json({ success: false, error: error.message });
  }
};

/**
 * GET passed hazards
 */
export const getPassedHazards = async (req, res) => {
  const { lat, lon, userId } = req.query;

  if (!lat || !lon || !userId) {
    return res.status(400).json({
      success: false,
      error: "Missing required parameters: lat, lon, userId",
    });
  }

  try {
    const hazards = await notificationService.getRecentlyPassedHazards(
      parseFloat(lat),
      parseFloat(lon),
      userId
    );

    res.json({
      success: true,
      count: hazards.length,
      hazards,
    });
  } catch (error) {
    console.error("[Controller] Passed hazards error:", error);
    res.status(500).json({ success: false, error: error.message });
  }
};

/**
 * POST respond to hazard
 */
export const respondToHazard = async (req, res) => {
  const { id } = req.params;
  const { userId, response } = req.body;

  if (!userId || !response) {
    return res.status(400).json({
      success: false,
      error: "Missing required fields: userId, response",
    });
  }

  if (!["yes", "no", "skip"].includes(response)) {
    return res.status(400).json({
      success: false,
      error: "Invalid response. Must be: yes, no, or skip",
    });
  }

  if (response === "skip") {
    return res.json({
      success: true,
      message: "Response skipped",
      action: "none",
    });
  }

  const action = response === "yes" ? "confirm" : "deny";

  try {
    const pool = (await import("../config/db.js")).default;
    const client = await pool.connect();

    try {
      await client.query("BEGIN");

      const existing = await client.query(
        "SELECT 1 FROM user_confirmations WHERE hazard_id = $1 AND user_id = $2",
        [id, userId]
      );

      if (existing.rows.length > 0) {
        await client.query("ROLLBACK");
        return res.json({
          success: true,
          message: "Already responded",
          action: "duplicate",
        });
      }

      await client.query(
        `INSERT INTO user_confirmations (hazard_id, user_id, action, comment)
         VALUES ($1, $2, $3, $4)`,
        [id, userId, action, `Quick response: ${response}`]
      );

      const scoreChange = action === "confirm"
        ? ConfidenceCalculator.SCORE_CHANGES.USER_CONFIRM
        : ConfidenceCalculator.SCORE_CHANGES.USER_DENY;

      const result = await client.query(
        `UPDATE hazards
         SET confidence_score = CASE
               WHEN $1 > 0 THEN LEAST(1.0, confidence_score + $1)
               ELSE GREATEST(0, confidence_score + $1)
             END,
             confirmation_count = confirmation_count + CASE WHEN $2='confirm' THEN 1 ELSE 0 END,
             denial_count = denial_count + CASE WHEN $2='deny' THEN 1 ELSE 0 END,
             last_updated = NOW(),
             status = CASE
               WHEN confidence_score + $1 >= 0.80 THEN 'verified'
               WHEN confidence_score + $1 < 0.50 THEN 'expired'
               ELSE status
             END
         WHERE id = $3
         RETURNING confidence_score, status`,
        [scoreChange, action, id]
      );

      await client.query("COMMIT");

      res.json({
        success: true,
        hazard_id: id,
        new_confidence: Number(result.rows[0].confidence_score).toFixed(3),
        status: result.rows[0].status,
        action,
      });
    } catch (err) {
      await client.query("ROLLBACK");
      throw err;
    } finally {
      client.release();
    }
  } catch (error) {
    console.error("[Controller] Respond error:", error);
    res.status(500).json({ success: false, error: error.message });
  }
};
