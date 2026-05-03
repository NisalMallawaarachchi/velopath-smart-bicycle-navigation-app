import { Router } from "express";
import pool from "../db.js";

const router = Router();

async function audit(adminEmail, action, targetId, metadata) {
  await pool.query(
    `INSERT INTO admin_audit_log (admin_email, action, target_id, metadata)
     VALUES ($1, $2, $3, $4)`,
    [adminEmail, action, String(targetId ?? ""), metadata ?? null]
  );
}

async function buildTravaliaRecord(userId) {
  const [user, rides, pois, hazards] = await Promise.all([
    pool.query(`SELECT user_id, username, email, country FROM users WHERE user_id = $1`, [userId]),
    pool.query(`
      SELECT
        COUNT(*)                                                           AS total_rides,
        ROUND(AVG(distance_km)::numeric,2)                                AS avg_distance_km,
        ROUND(AVG(avg_speed_kmh)::numeric,2)                              AS avg_speed,
        MODE() WITHIN GROUP (ORDER BY route_mode)                         AS top_mode,
        COUNT(*) FILTER (WHERE EXTRACT(HOUR FROM started_at) BETWEEN 5  AND 11) AS morning,
        COUNT(*) FILTER (WHERE EXTRACT(HOUR FROM started_at) BETWEEN 12 AND 16) AS afternoon,
        COUNT(*) FILTER (WHERE EXTRACT(HOUR FROM started_at) BETWEEN 17 AND 21) AS evening
      FROM ride_sessions WHERE user_id = $1
    `, [userId]),
    pool.query(`
      SELECT poi_category, COUNT(*) * COALESCE(AVG(dwell_seconds),60) AS score
      FROM poi_visits WHERE user_id = $1
      GROUP BY poi_category ORDER BY score DESC LIMIT 5
    `, [userId]),
    pool.query(`
      SELECT COUNT(*) FILTER (WHERE action='confirm') AS confirms
      FROM user_confirmations WHERE user_id = $1::text
    `, [userId]),
  ]);

  if (!user.rows[0]) return null;

  const u = user.rows[0];
  const r = rides.rows[0];
  const totalRidesN = parseInt(r.total_rides) || 0;
  const avgSpeed = parseFloat(r.avg_speed) || 0;

  const activityLevel =
    totalRidesN === 0 ? "unknown" :
    totalRidesN < 3   ? "low" :
    totalRidesN < 10  ? "moderate" : "active";

  const preferredTime =
    r.morning >= r.afternoon && r.morning >= r.evening ? "morning" :
    r.afternoon >= r.evening ? "afternoon" : "evening";

  const speedProfile =
    avgSpeed < 10 ? "slow" : avgSpeed < 18 ? "moderate" : "fast";

  const poiInterests = pois.rows.map(p => p.poi_category).filter(Boolean);

  const geoFocus = await pool.query(
    `SELECT DISTINCT ROUND(start_lat::numeric,2) lat, ROUND(start_lon::numeric,2) lon
     FROM ride_sessions WHERE user_id = $1 AND start_lat IS NOT NULL LIMIT 5`,
    [userId]
  );

  const travaliaScore = Math.min(100, Math.round(
    (Math.min(totalRidesN, 20) / 20) * 40 +
    (pois.rows.length / 8) * 30 +
    (Math.min(parseInt(hazards.rows[0]?.confirms ?? 0), 10) / 10) * 20 +
    (parseFloat("5") / 10) * 10
  ));

  return {
    user_id:          u.user_id,
    username:         u.username,
    email:            u.email,
    country_of_origin: u.country ?? "unknown",
    poi_interests:    poiInterests,
    route_preference: r.top_mode ?? "unknown",
    activity_level:   activityLevel,
    speed_profile:    speedProfile,
    preferred_time:   preferredTime,
    geographic_focus: geoFocus.rows.map(r => `${r.lat},${r.lon}`),
    travalia_score:   travaliaScore,
    exported_at:      new Date().toISOString(),
  };
}

// ── GET /admin/export/travalia  (JSONL download) ──────────────────────────────
router.get("/travalia", async (req, res) => {
  const flaggedUsers = await pool.query(
    `SELECT user_id FROM users WHERE flagged_for_travalia = TRUE ORDER BY created_at`
  );

  const records = [];
  for (const row of flaggedUsers.rows) {
    const rec = await buildTravaliaRecord(row.user_id);
    if (rec) records.push(rec);
  }

  const jsonl = records.map(r => JSON.stringify(r)).join("\n");

  await audit(req.admin.email, "export_travalia_jsonl", "all", { count: records.length });

  res.setHeader("Content-Type", "application/x-ndjson");
  res.setHeader("Content-Disposition", `attachment; filename="travalia_export_${Date.now()}.jsonl"`);
  res.send(jsonl);
});

// ── GET /admin/export/users-csv  (full table CSV) ────────────────────────────
router.get("/users-csv", async (req, res) => {
  const rows = await pool.query(`
    SELECT
      u.user_id, u.username, u.email, u.country, u.created_at,
      u.reputation_score, u.total_contributions, u.last_active_at,
      u.flagged_for_travalia, u.travalia_status,
      COALESCE(r.total_rides, 0)    AS total_rides,
      ROUND(COALESCE(r.total_distance, 0)::numeric, 2) AS total_distance_km,
      COALESCE(h.hazards, 0)        AS hazards_reported
    FROM users u
    LEFT JOIN (SELECT user_id, COUNT(*) total_rides, SUM(distance_km) total_distance FROM ride_sessions GROUP BY user_id) r ON r.user_id = u.user_id
    LEFT JOIN (SELECT user_id, COUNT(*) hazards FROM user_confirmations WHERE action='confirm' GROUP BY user_id) h ON h.user_id = u.user_id
    ORDER BY u.created_at DESC
  `);

  if (!rows.rows.length) return res.send("No data");

  const cols  = Object.keys(rows.rows[0]);
  const lines = [cols.join(","), ...rows.rows.map(r =>
    cols.map(c => JSON.stringify(r[c] ?? "")).join(",")
  )];

  await audit(req.admin.email, "export_users_csv", "all", { count: rows.rows.length });
  res.setHeader("Content-Type", "text/csv");
  res.setHeader("Content-Disposition", `attachment; filename="velopath_users_${Date.now()}.csv"`);
  res.send(lines.join("\n"));
});

// ── GET /admin/export/hazards-geojson ────────────────────────────────────────
router.get("/hazards-geojson", async (req, res) => {
  const { type, minConfidence, dateFrom, dateTo, status } = req.query;

  const conditions = [];
  const params = [];
  let p = 1;

  if (type)          { conditions.push(`hazard_type = $${p++}`);             params.push(type); }
  if (minConfidence) { conditions.push(`confidence_score >= $${p++}`);       params.push(parseFloat(minConfidence)); }
  if (dateFrom)      { conditions.push(`first_detected >= $${p++}`);         params.push(dateFrom); }
  if (dateTo)        { conditions.push(`first_detected <= $${p++}`);         params.push(dateTo); }
  if (status)        { conditions.push(`status = $${p++}`);                  params.push(status); }

  const where = conditions.length ? "WHERE " + conditions.join(" AND ") : "";

  const rows = await pool.query(`
    SELECT
      id, hazard_type, confidence_score, status,
      detection_count, confirmation_count, denial_count,
      first_detected, last_updated,
      ST_Y(location::geometry) AS lat,
      ST_X(location::geometry) AS lon
    FROM hazards ${where}
    ORDER BY confidence_score DESC
    LIMIT 5000
  `, params);

  const geojson = {
    type: "FeatureCollection",
    features: rows.rows.map(h => ({
      type: "Feature",
      geometry: { type: "Point", coordinates: [h.lon, h.lat] },
      properties: {
        id: h.id,
        hazard_type: h.hazard_type,
        confidence_score: parseFloat(h.confidence_score),
        status: h.status,
        detection_count: h.detection_count,
        confirmation_count: h.confirmation_count,
        denial_count: h.denial_count,
        first_detected: h.first_detected,
        last_updated: h.last_updated,
      },
    })),
  };

  await audit(req.admin.email, "export_hazards_geojson", "all", { count: rows.rows.length });
  res.setHeader("Content-Type", "application/geo+json");
  res.setHeader("Content-Disposition", `attachment; filename="hazards_${Date.now()}.geojson"`);
  res.json(geojson);
});

// ── GET /admin/export/flagged-users ──────────────────────────────────────────
router.get("/flagged-users", async (req, res) => {
  const rows = await pool.query(`
    SELECT user_id, username, email, country, travalia_status, travalia_pushed_at, created_at
    FROM users WHERE flagged_for_travalia = TRUE
    ORDER BY travalia_pushed_at DESC NULLS LAST
  `);
  res.json(rows.rows);
});

// ── POST /admin/users/:id/push-travalia ──────────────────────────────────────
router.post("/users/:id/push-travalia", async (req, res) => {
  const { id } = req.params;
  const record = await buildTravaliaRecord(id);
  if (!record) return res.status(404).json({ error: "User not found" });

  // STUB — replace with real Travalia API call when available
  const travaLiaUrl = process.env.TRAVALIA_API_URL;
  const travaLiaKey = process.env.TRAVALIA_API_KEY;

  let travaResponse = { stubbed: true, message: "Travalia API not configured — record logged locally" };

  if (travaLiaUrl && travaLiaKey && !travaLiaKey.startsWith("stub_")) {
    try {
      const r = await fetch(`${travaLiaUrl}/ingest/user`, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "x-api-key": travaLiaKey,
        },
        body: JSON.stringify(record),
      });
      travaResponse = await r.json();
    } catch (e) {
      travaResponse = { error: e.message };
    }
  }

  await pool.query(
    `UPDATE users SET travalia_status = 'exported', travalia_pushed_at = NOW()
     WHERE user_id = $1`,
    [id]
  );

  await audit(req.admin.email, "push_travalia", id, { record, response: travaResponse });
  res.json({ ok: true, record, travaResponse });
});

// ── POST /admin/sync-travalia ─────────────────────────────────────────────────
router.post("/sync-travalia", async (req, res) => {
  const flagged = await pool.query(
    `SELECT user_id FROM users WHERE flagged_for_travalia = TRUE`
  );

  const results = [];
  for (const row of flagged.rows) {
    const record = await buildTravaliaRecord(row.user_id);
    if (!record) continue;
    results.push({ user_id: row.user_id, status: "stubbed", record });
  }

  await pool.query(
    `UPDATE users SET travalia_status = 'synced' WHERE flagged_for_travalia = TRUE`
  );

  await pool.query(
    `INSERT INTO travalia_sync_log (user_count, status, response)
     VALUES ($1, $2, $3)`,
    [results.length, "ok", JSON.stringify({ stubbed: true, count: results.length })]
  );

  await audit(req.admin.email, "sync_travalia", "all", { count: results.length });
  res.json({ ok: true, synced: results.length });
});

// ── GET /admin/export/hazards (list for map page) ────────────────────────────
router.get("/hazards", async (req, res) => {
  const { type, minConfidence, dateFrom, dateTo, status } = req.query;
  const conditions = [];
  const params = [];
  let p = 1;

  if (type)          { conditions.push(`h.hazard_type = $${p++}`);       params.push(type); }
  if (minConfidence) { conditions.push(`h.confidence_score >= $${p++}`); params.push(parseFloat(minConfidence)); }
  if (dateFrom)      { conditions.push(`h.first_detected >= $${p++}`);   params.push(dateFrom); }
  if (dateTo)        { conditions.push(`h.first_detected <= $${p++}`);   params.push(dateTo); }
  if (status)        { conditions.push(`h.status = $${p++}`);            params.push(status); }

  const where = conditions.length ? "WHERE " + conditions.join(" AND ") : "";

  const rows = await pool.query(`
    SELECT
      h.id, h.hazard_type, h.confidence_score, h.status,
      h.detection_count, h.confirmation_count, h.denial_count,
      h.first_detected, h.last_updated,
      ST_Y(h.location::geometry) AS lat,
      ST_X(h.location::geometry) AS lon,
      json_agg(DISTINCT jsonb_build_object('user_id', uc.user_id, 'action', uc.action))
        FILTER (WHERE uc.user_id IS NOT NULL) AS reporters
    FROM hazards h
    LEFT JOIN user_confirmations uc ON uc.hazard_id = h.id
    ${where}
    GROUP BY h.id
    ORDER BY h.confidence_score DESC
    LIMIT 2000
  `, params);

  res.json(rows.rows);
});

export default router;
