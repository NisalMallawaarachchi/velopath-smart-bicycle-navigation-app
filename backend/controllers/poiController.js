import pool from "../config/db.js";

export const addPOI = async (req, res) => {
  try {
    const { name, amenity, description, lat, lon, district } = req.body;

    if (!name || !amenity || !lat || !lon) {
      return res.status(400).json({ error: "Missing required fields" });
    }

    const imageUrl = req.file ? `/uploads/${req.file.filename}` : null;

    const result = await pool.query(
      `INSERT INTO custom_pois (name, amenity, lat, lon, district, description, image_url)
       VALUES ($1, $2, $3, $4, $5, $6, $7)
       RETURNING *`,
      [name, amenity, lat, lon, district, description, imageUrl]
    );

    res.status(201).json(result.rows[0]);
  } catch (err) {
    console.error("Error adding POI:", err.message);
    res.status(500).json({ error: "Server error" });
  }
};

export const getPOIs = async (req, res) => {
  try {
    const result = await pool.query(`
      
-- Custom POIs
SELECT 
    id::text,
    name,
    amenity,
    description,
    lat,
    lon,
    district,
    image_url,
    'custom' AS source
FROM custom_pois

UNION ALL

-- POIs from selected districts
SELECT 
    p.osm_id::text AS id,
    p.name,
    p.amenity,
    NULL AS description,
    ST_Y(ST_Transform(p.way, 4326)) AS lat,
    ST_X(ST_Transform(p.way, 4326)) AS lon,
    NULL AS district,
    NULL AS image_url,
    'osm' AS source
FROM planet_osm_point p
WHERE p.name IS NOT NULL
  AND p.amenity IS NOT NULL;


    `);

    res.json(result.rows);
  } catch (err) {
    console.error("Error fetching POIs:", err.message);
    res.status(500).json({ error: "Server error" });
  }
};
