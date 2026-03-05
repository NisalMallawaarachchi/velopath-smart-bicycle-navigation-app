import pool from "../config/db.js";


export const testDatabase = async (req, res) => {
  try {
    const result = await pool.query("SELECT PostGIS_Version();");
    res.json({ status: "connected", postgis_version: result.rows[0] });
  } catch (error) {
    console.error(" Database test failed:", error.message);
    res.status(500).json({ error: "Database connection failed" });
  }
};
