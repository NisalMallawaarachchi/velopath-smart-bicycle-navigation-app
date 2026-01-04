import pool from "../config/db.js";

export const getDashboard = async (req, res) => {
  try {
    const { deviceId } = req.params;

    // Count POIs for this device
    const poiResult = await pool.query(
      `SELECT COUNT(*) FROM custom_pois WHERE device_id = $1`,
      [deviceId]
    );

    const poiCount = parseInt(poiResult.rows[0].count);

    // 5 points per POI
    const loyaltyPoints = poiCount * 5;

    res.json({
      poiCount,
      loyaltyPoints,
    });
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: "Server error" });
  }
};
