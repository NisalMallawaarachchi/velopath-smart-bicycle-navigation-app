import pool from "../config/db.js";

export const addPOI = async (req, res) => {
  try {
    const {
      name,
      amenity,
      description,
      lat,
      lon,
      district,
      deviceId
    } = req.body;

    if (!name || !amenity || !lat || !lon || !deviceId) {
      return res.status(400).json({ error: "Missing required fields" });
    }

    const imageUrl = req.file ? `/uploads/${req.file.filename}` : null;

    // Insert POI
    await pool.query(
      `INSERT INTO custom_pois
       (name, amenity, lat, lon, district, description, image_url, device_id)
       VALUES ($1,$2,$3,$4,$5,$6,$7,$8)`,
      [name, amenity, lat, lon, district, description, imageUrl, deviceId]
    );

    
    await pool.query(
      `
      INSERT INTO device_loyalty (device_id, loyalty_points)
      VALUES ($1, 5)
      ON CONFLICT (device_id)
      DO UPDATE SET loyalty_points = device_loyalty.loyalty_points + 5
      `,
      [deviceId]
    );

    res.status(201).json({ message: "POI added & loyalty updated" });
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

export const votePOI = async (req, res) => {
  try {
    const { id } = req.params;
    const { percentage, deviceId } = req.body;

    if (!deviceId) return res.status(400).json({ error: "Device ID is required" });
    if (percentage < 0 || percentage > 100) return res.status(400).json({ error: "Invalid vote percentage" });

    // Get current POI info
    const poiResult = await pool.query(
      `SELECT score, vote_count, voted_devices FROM custom_pois WHERE id = $1`,
      [id]
    );

    if (poiResult.rows.length === 0) {
      return res.status(404).json({ error: "POI not found" });
    }

    const { score: currentScore, vote_count: currentCount, voted_devices } = poiResult.rows[0];

    // Check if this device has already voted
    const devices = voted_devices ? voted_devices.split(",") : [];
    if (devices.includes(deviceId)) {
      return res.status(400).json({ error: "You have already voted for this POI" });
    }

    // Calculate new average
    const newCount = currentCount + 1;
    const newScore = ((currentScore * currentCount) + percentage) / newCount;

    // Add device ID to voted_devices
    devices.push(deviceId);
    const newDevices = devices.join(",");

    // Update POI
    await pool.query(
      `UPDATE custom_pois 
       SET score = $1, vote_count = $2, voted_devices = $3
       WHERE id = $4`,
      [newScore, newCount, newDevices, id]
    );

    res.json({
      message: "Vote submitted successfully",
      score: newScore,
      voteCount: newCount,
    });

  } catch (err) {
    console.error("Vote error:", err.message);
    res.status(500).json({ error: "Server error" });
  }
};

