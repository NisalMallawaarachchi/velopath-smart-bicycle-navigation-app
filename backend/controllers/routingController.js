// controllers/routingController.js
import pool from "../config/db.js";

export const generateRoutes = async (req, res) => {
  try {
    // 1. Fetch top 20 best road segments based on final_weight
    const query = `
      SELECT 
        r.road_id AS id,
        COALESCE(r.name, 'Unnamed road') AS start_point,
        COALESCE(r.name, 'Unnamed road') AS end_point,
        r.length_meters / 1000.0 AS distance,
        rs.poi_score,
        rs.hazard_count AS hazard_score
      FROM roads r
      JOIN road_segment_data rs
        ON r.road_id = rs.road_id
      ORDER BY rs.final_weight ASC   -- best lowest score first
      LIMIT 20;
    `;

    const result = await pool.query(query);

    return res.json({ routes: result.rows });
  } catch (error) {
    console.error("❌ Error generating real routes:", error.message);
    res.status(500).json({ error: "Failed to generate real routes" });
  }
};
