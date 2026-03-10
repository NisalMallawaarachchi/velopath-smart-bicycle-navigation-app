import pool from "../config/db.js";

// ── Validation helpers ────────────────────────────────────────────────────────

/** Returns true if the string contains any digit */
const containsNumbers = (str) => /\d/.test(str);

/**
 * Validates a text-only field.
 * @param {string|undefined} value
 * @param {string} fieldName  – used in the error message
 * @param {boolean} required  – if false, empty/null values are allowed
 * @returns {string|null}  error message, or null if valid
 */
const validateTextField = (value, fieldName, required = true) => {
  if (required && (!value || value.trim().length === 0))
    return `${fieldName} is required`;
  if (value && value.trim().length > 0 && containsNumbers(value))
    return `${fieldName} must not contain numbers`;
  return null;
};

// ── Controllers ───────────────────────────────────────────────────────────────

// Add a new POI
export const addPOI = async (req, res) => {
  try {
    const { name, amenity, description, lat, lon, district, deviceId } = req.body;

    // ── Required field presence ──
    if (!name || !amenity || !lat || !lon || !deviceId) {
      return res.status(400).json({ error: "Missing required fields" });
    }

    // ── Text-only validation ──
    const nameError = validateTextField(name, "Name");
    if (nameError) return res.status(400).json({ error: nameError });

    const amenityError = validateTextField(amenity, "Amenity");
    if (amenityError) return res.status(400).json({ error: amenityError });

    // Description is optional — only validate content if it was provided
    const descError = validateTextField(description, "Description", false);
    if (descError) return res.status(400).json({ error: descError });

    // ── Coordinate sanity ──
    const latNum = parseFloat(lat);
    const lonNum = parseFloat(lon);
    if (isNaN(latNum) || isNaN(lonNum)) {
      return res.status(400).json({ error: "Invalid coordinates" });
    }

    const imageUrl = req.file ? req.file.path : null;

    // Insert the new POI
    const poiResult = await pool.query(
      `INSERT INTO custom_pois
       (name, amenity, lat, lon, district, description, image_url, device_id)
       VALUES ($1,$2,$3,$4,$5,$6,$7,$8)
       RETURNING id`,
      [
        name.trim(),
        amenity.trim(),
        latNum,
        lonNum,
        district ?? null,
        description?.trim() ?? null,
        imageUrl,
        deviceId,
      ]
    );

    const newPoiId = poiResult.rows[0].id;

    // Insert a notification so all other users get alerted
    await pool.query(
      `INSERT INTO poi_notifications (poi_id, poi_name, amenity, district, added_by_device)
       VALUES ($1, $2, $3, $4, $5)`,
      [newPoiId.toString(), name.trim(), amenity.trim(), district ?? "Unknown", deviceId]
    );

    // Award loyalty points
    await pool.query(
      `INSERT INTO device_loyalty (device_id, loyalty_points)
       VALUES ($1, 5)
       ON CONFLICT (device_id)
       DO UPDATE SET loyalty_points = device_loyalty.loyalty_points + 5`,
      [deviceId]
    );

    res.status(201).json({ message: "POI added & loyalty updated" });
  } catch (err) {
    console.error("Error adding POI:", err.message);
    res.status(500).json({ error: "Server error" });
  }
};

// Get all POIs (unranked — kept for backward compatibility)
export const getPOIs = async (req, res) => {
  try {
    const result = await pool.query(`
      SELECT 
          id::text, name, amenity, description, lat, lon,
          district, image_url, score, vote_count, 'custom' AS source
      FROM custom_pois

      UNION ALL

      SELECT 
          p.osm_id::text AS id, p.name, p.amenity,
          NULL AS description,
          ST_Y(ST_Transform(p.way, 4326)) AS lat,
          ST_X(ST_Transform(p.way, 4326)) AS lon,
          NULL AS district, NULL AS image_url,
          0 AS score, 0 AS vote_count, 'osm' AS source
      FROM planet_osm_point p
      WHERE p.name IS NOT NULL AND p.amenity IS NOT NULL;
    `);

    res.json(result.rows);
  } catch (err) {
    console.error("Error fetching POIs:", err.message);
    res.status(500).json({ error: "Server error" });
  }
};

// Get single POI details
export const getPOIDetails = async (req, res) => {
  try {
    const { id } = req.params;

    const result = await pool.query(
      `SELECT * FROM custom_pois WHERE id = $1 OR osm_id = $1 LIMIT 1`,
      [id]
    );

    if (result.rows.length === 0) {
      return res.status(404).json({ error: "POI not found" });
    }

    res.json(result.rows[0]);
  } catch (err) {
    console.error("Error fetching POI details:", err.message);
    res.status(500).json({ error: "Server error" });
  }
};

// Vote for a POI (rating: 1–5 stars)
export const votePOI = async (req, res) => {
  try {
    const { id } = req.params;
    const { rating, deviceId, source, poi } = req.body;

    if (!deviceId)
      return res.status(400).json({ error: "Device ID is required" });

    if (!rating || rating < 1 || rating > 5)
      return res.status(400).json({ error: "Invalid rating. Must be between 1 and 5." });

    let customPoiId = id;

    if (source === "osm") {
      const existing = await pool.query(
        `SELECT id FROM custom_pois WHERE osm_id = $1`, [id]
      );

      if (existing.rows.length > 0) {
        customPoiId = existing.rows[0].id;
      } else {
        const insertResult = await pool.query(
          `INSERT INTO custom_pois
           (osm_id, name, amenity, lat, lon, district, score, vote_count, voted_devices)
           VALUES ($1,$2,$3,$4,$5,$6,0,0,'')
           RETURNING id`,
          [id, poi.name, poi.amenity, poi.lat, poi.lon, poi.district]
        );
        customPoiId = insertResult.rows[0].id;
      }
    }

    const poiResult = await pool.query(
      `SELECT score, vote_count, voted_devices FROM custom_pois WHERE id = $1`,
      [customPoiId]
    );

    if (poiResult.rows.length === 0)
      return res.status(404).json({ error: "POI not found" });

    const { score: currentScore, vote_count: currentCount, voted_devices } = poiResult.rows[0];
    const devices = voted_devices ? voted_devices.split(",") : [];

    if (devices.includes(deviceId)) {
      return res.status(409).json({
        error: "You have already voted for this place",
        score: currentScore,
        voteCount: currentCount,
        alreadyVoted: true,
      });
    }

    const newCount = currentCount + 1;
    const newScore = ((currentScore * currentCount) + rating) / newCount;
    devices.push(deviceId);

    await pool.query(
      `UPDATE custom_pois SET score=$1, vote_count=$2, voted_devices=$3 WHERE id=$4`,
      [newScore, newCount, devices.join(","), customPoiId]
    );

    await pool.query(
      `INSERT INTO device_loyalty (device_id, loyalty_points)
       VALUES ($1, 2)
       ON CONFLICT (device_id)
       DO UPDATE SET loyalty_points = device_loyalty.loyalty_points + 2`,
      [deviceId]
    );

    res.json({
      message: "Vote submitted successfully",
      score: newScore,
      voteCount: newCount,
      alreadyVoted: false,
      customPoiId,
      rewardPoints: 2,
    });
  } catch (err) {
    console.error("Vote error:", err.message);
    res.status(500).json({ error: "Server error" });
  }
};

// Get all comments for a POI
export const getComments = async (req, res) => {
  try {
    const { id } = req.params;
    const result = await pool.query(
      `SELECT id, poi_id, device_id, comment, created_at, updated_at
       FROM poi_comments WHERE poi_id = $1 ORDER BY created_at DESC`,
      [id]
    );
    res.status(200).json({ success: true, comments: result.rows, count: result.rows.length });
  } catch (err) {
    console.error("Error fetching comments:", err.message);
    res.status(500).json({ success: false, error: "Failed to fetch comments", message: err.message });
  }
};

// Add a new comment to a POI
export const addComment = async (req, res) => {
  try {
    const { id } = req.params;
    const { comment, deviceId } = req.body;

    if (!comment || !deviceId)
      return res.status(400).json({ success: false, error: "Comment and deviceId are required" });

    if (comment.trim().length === 0)
      return res.status(400).json({ success: false, error: "Comment cannot be empty" });

    if (comment.length > 1000)
      return res.status(400).json({ success: false, error: "Comment is too long (max 1000 characters)" });

    const result = await pool.query(
      `INSERT INTO poi_comments (poi_id, device_id, comment)
       VALUES ($1, $2, $3)
       RETURNING id, poi_id, device_id, comment, created_at, updated_at`,
      [id, deviceId, comment.trim()]
    );

    res.status(201).json({ success: true, message: "Comment added successfully", comment: result.rows[0] });
  } catch (err) {
    console.error("Error adding comment:", err.message);
    res.status(500).json({ success: false, error: "Failed to add comment", message: err.message });
  }
};

// ── Notifications ─────────────────────────────────────────────────────────────

// Get notifications not created by this device (so you don't see your own POI additions)
// Optionally pass ?since=ISO_TIMESTAMP to get only new ones
export const getNotifications = async (req, res) => {
  try {
    const { deviceId } = req.params;
    const { since } = req.query;

    let query = `
      SELECT id, poi_id, poi_name, amenity, district, added_by_device, created_at
      FROM poi_notifications
      WHERE added_by_device != $1
    `;
    const params = [deviceId];

    if (since) {
      params.push(since);
      query += ` AND created_at > $2`;
    }

    query += ` ORDER BY created_at DESC LIMIT 50`;

    const result = await pool.query(query, params);
    res.json({ notifications: result.rows, count: result.rows.length });
  } catch (err) {
    console.error("Error fetching notifications:", err.message);
    res.status(500).json({ error: "Server error" });
  }
};