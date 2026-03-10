import pool from "../config/db.js";

// Dashboard Data
export const getDashboard = async (req, res) => {
  try {
    const { deviceId } = req.params;

    // Total loyalty points for this device
    const loyaltyResult = await pool.query(
      `SELECT COALESCE(loyalty_points, 0) AS loyalty_points
       FROM device_loyalty
       WHERE device_id = $1`,
      [deviceId]
    );

    const loyaltyPoints =
      loyaltyResult.rows.length > 0
        ? loyaltyResult.rows[0].loyalty_points
        : 0;

    // Count of POIs added by this device
    const poiResult = await pool.query(
      `SELECT COUNT(*) FROM custom_pois WHERE device_id = $1`,
      [deviceId]
    );

    const poiCount = parseInt(poiResult.rows[0].count);

    res.json({
      loyaltyPoints,
      poiCount,
    });

  } catch (err) {
    console.error("Dashboard error:", err.message);
    res.status(500).json({ error: "Server error" });
  }
};
