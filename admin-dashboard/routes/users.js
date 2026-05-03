import { Router } from "express";
import pool from "../db.js";

const router = Router();

// ── audit helper ─────────────────────────────────────────────────────────────
async function audit(adminEmail, action, targetId, metadata) {
  await pool.query(
    `INSERT INTO admin_audit_log (admin_email, action, target_id, metadata)
     VALUES ($1, $2, $3, $4)`,
    [adminEmail, action, String(targetId ?? ""), metadata ?? null]
  );
}

// ── GET /admin/users ──────────────────────────────────────────────────────────
// Query params: page, limit, country, active, dateFrom, dateTo, search
router.get("/", async (req, res) => {
  const page    = Math.max(1, parseInt(req.query.page  ?? 1));
  const limit   = Math.min(100, parseInt(req.query.limit ?? 20));
  const offset  = (page - 1) * limit;
  const { country, active, dateFrom, dateTo, search } = req.query;

  const conditions = [];
  const params = [];
  let p = 1;

  if (country) { conditions.push(`u.country = $${p++}`); params.push(country); }
  if (dateFrom) { conditions.push(`u.created_at >= $${p++}`); params.push(dateFrom); }
  if (dateTo)   { conditions.push(`u.created_at <= $${p++}`); params.push(dateTo); }
  if (search)   {
    conditions.push(`(u.username ILIKE $${p} OR u.email ILIKE $${p})`);
    params.push(`%${search}%`); p++;
  }
  if (active === "true") {
    conditions.push(`u.last_active_at >= NOW() - INTERVAL '30 days'`);
  } else if (active === "false") {
    conditions.push(`(u.last_active_at IS NULL OR u.last_active_at < NOW() - INTERVAL '30 days')`);
  }

  const where = conditions.length ? "WHERE " + conditions.join(" AND ") : "";

  const sql = `
    SELECT
      u.user_id,
      u.username,
      u.email,
      u.country,
      u.created_at,
      u.reputation_score,
      u.total_contributions,
      u.last_active_at,
      u.flagged_for_travalia,
      u.travalia_status,
      COALESCE(r.total_rides, 0)         AS total_rides,
      COALESCE(r.total_distance, 0)      AS total_distance_km,
      COALESCE(h.hazards_reported, 0)    AS hazards_reported,
      CASE
        WHEN u.last_active_at >= NOW() - INTERVAL '30 days' THEN 'active'
        ELSE 'inactive'
      END AS account_status
    FROM users u
    LEFT JOIN (
      SELECT user_id,
             COUNT(*)              AS total_rides,
             SUM(distance_km)      AS total_distance
      FROM ride_sessions
      GROUP BY user_id
    ) r ON r.user_id = u.user_id
    LEFT JOIN (
      SELECT user_id, COUNT(*) AS hazards_reported
      FROM user_confirmations
      WHERE action = 'confirm'
      GROUP BY user_id
    ) h ON h.user_id = u.user_id::text
    ${where}
    ORDER BY u.created_at DESC
    LIMIT $${p} OFFSET $${p + 1}
  `;

  const countSql = `
    SELECT COUNT(*) FROM users u ${where}
  `;

  params.push(limit, offset);

  const [rows, countRow] = await Promise.all([
    pool.query(sql, params),
    pool.query(countSql, params.slice(0, params.length - 2)),
  ]);

  await audit(req.admin.email, "list_users", null, { page, limit, country, search });

  res.json({
    data:  rows.rows,
    total: parseInt(countRow.rows[0].count),
    page,
    limit,
  });
});

// ── GET /admin/users/:id ──────────────────────────────────────────────────────
router.get("/:id", async (req, res) => {
  const { id } = req.params;

  const [userRow, ridesRow, poiRow, hazardRow, badgesRow] = await Promise.all([
    // Section A — personal info
    pool.query(
      `SELECT user_id, username, email, country, device_type, app_version,
              created_at, last_active_at, reputation_score, total_contributions,
              flagged_for_travalia, travalia_status
       FROM users WHERE user_id = $1`,
      [id]
    ),

    // Section B — ride preferences
    pool.query(
      `SELECT
         COUNT(*)                                               AS total_rides,
         ROUND(AVG(distance_km)::numeric, 2)                   AS avg_distance_km,
         ROUND(SUM(distance_km)::numeric, 2)                   AS total_distance_km,
         ROUND(AVG(avg_speed_kmh)::numeric, 2)                 AS avg_speed_kmh,
         COUNT(*) FILTER (WHERE route_mode = 'shortest')       AS mode_shortest,
         COUNT(*) FILTER (WHERE route_mode = 'safest')         AS mode_safest,
         COUNT(*) FILTER (WHERE route_mode = 'scenic')         AS mode_scenic,
         COUNT(*) FILTER (WHERE route_mode = 'balanced')       AS mode_balanced,
         COUNT(*) FILTER (WHERE EXTRACT(HOUR FROM started_at) BETWEEN 5  AND 11) AS morning_rides,
         COUNT(*) FILTER (WHERE EXTRACT(HOUR FROM started_at) BETWEEN 12 AND 16) AS afternoon_rides,
         COUNT(*) FILTER (WHERE EXTRACT(HOUR FROM started_at) BETWEEN 17 AND 21) AS evening_rides,
         json_agg(json_build_object(
           'session_id', session_id,
           'started_at', started_at,
           'distance_km', distance_km,
           'route_mode', route_mode,
           'start_lat', start_lat, 'start_lon', start_lon,
           'end_lat', end_lat, 'end_lon', end_lon,
           'gps_track', gps_track
         ) ORDER BY started_at DESC) FILTER (WHERE session_id IS NOT NULL) AS rides
       FROM ride_sessions
       WHERE user_id = $1`,
      [id]
    ),

    // Section C — POI interests
    pool.query(
      `SELECT
         poi_category,
         COUNT(*)            AS visit_count,
         SUM(dwell_seconds)  AS total_dwell_seconds,
         COUNT(*) * COALESCE(AVG(dwell_seconds), 60) AS engagement_score
       FROM poi_visits
       WHERE user_id = $1
       GROUP BY poi_category
       ORDER BY engagement_score DESC
       LIMIT 10`,
      [id]
    ),

    // Section D — hazard behavior
    pool.query(
      `SELECT
         COUNT(*) FILTER (WHERE uc.action = 'confirm') AS confirmations_given,
         COUNT(*) FILTER (WHERE uc.action = 'deny')    AS denials_given,
         COUNT(*) AS total_responses,
         COUNT(*) FILTER (WHERE h.hazard_type = 'pothole') AS pothole_responses,
         COUNT(*) FILTER (WHERE h.hazard_type = 'bump')    AS bump_responses,
         COUNT(*) FILTER (WHERE h.hazard_type = 'rough')   AS rough_responses
       FROM user_confirmations uc
       JOIN hazards h ON h.id = uc.hazard_id
       WHERE uc.user_id = $1::text`,
      [id]
    ),

    // Section C — gamification: device_loyalty via device_type linkage
    pool.query(
      `SELECT COALESCE(SUM(dl.loyalty_points), 0) AS loyalty_points
       FROM device_loyalty dl
       JOIN users u ON u.device_type = dl.device_id
       WHERE u.user_id = $1`,
      [id]
    ),
  ]);

  if (!userRow.rows[0]) return res.status(404).json({ error: "User not found" });

  const user     = userRow.rows[0];
  const rides    = ridesRow.rows[0];
  const pois     = poiRow.rows;
  const hazards  = hazardRow.rows[0];
  const badges   = badgesRow.rows[0];

  // Compute dominant route mode
  const modeCounts = {
    shortest: parseInt(rides.mode_shortest),
    safest:   parseInt(rides.mode_safest),
    scenic:   parseInt(rides.mode_scenic),
    balanced: parseInt(rides.mode_balanced),
  };
  const totalRides = parseInt(rides.total_rides) || 1;
  const routePreferences = Object.fromEntries(
    Object.entries(modeCounts).map(([k, v]) => [k, Math.round((v / totalRides) * 100)])
  );
  const dominantMode = Object.entries(modeCounts).sort((a, b) => b[1] - a[1])[0]?.[0] ?? "unknown";

  // Speed profile bucket
  const avgSpeed = parseFloat(rides.avg_speed_kmh) || 0;
  const speedProfile =
    avgSpeed < 10 ? "slow tourist" :
    avgSpeed < 18 ? "moderate" : "fast";

  // Activity level for Travalia
  const totalRidesN = parseInt(rides.total_rides) || 0;
  const activityLevel =
    totalRidesN === 0  ? "unknown" :
    totalRidesN < 3    ? "low" :
    totalRidesN < 10   ? "moderate" : "active";

  // Preferred time bucket
  const { morning_rides, afternoon_rides, evening_rides } = rides;
  const preferredTime =
    morning_rides >= afternoon_rides && morning_rides >= evening_rides ? "morning" :
    afternoon_rides >= evening_rides ? "afternoon" : "evening";

  // Top POI interests
  const poiInterests = pois.slice(0, 5).map(p => p.poi_category).filter(Boolean);

  // Travalia score (0-100): contributions + ride count + POI diversity
  const travaliaScore = Math.min(100, Math.round(
    (Math.min(totalRidesN, 20) / 20) * 40 +
    (pois.length / 8) * 30 +
    (parseInt(hazards.confirmations_given) / 10) * 20 +
    (parseFloat(user.reputation_score) / 10) * 10
  ));

  // Geographic focus — distinct areas from ride GPS endpoints
  const geoFocusQuery = await pool.query(
    `SELECT DISTINCT
       ROUND(start_lat::numeric, 2) AS lat,
       ROUND(start_lon::numeric, 2) AS lon
     FROM ride_sessions WHERE user_id = $1 AND start_lat IS NOT NULL
     LIMIT 5`,
    [id]
  );

  await audit(req.admin.email, "view_user", id, null);

  res.json({
    personal: user,
    ridingPreferences: {
      totalRides:       parseInt(rides.total_rides) || 0,
      avgDistanceKm:    parseFloat(rides.avg_distance_km) || 0,
      totalDistanceKm:  parseFloat(rides.total_distance_km) || 0,
      avgSpeedKmh:      avgSpeed,
      speedProfile,
      routePreferences,
      dominantMode,
      timeOfDay: {
        morning:   parseInt(rides.morning_rides),
        afternoon: parseInt(rides.afternoon_rides),
        evening:   parseInt(rides.evening_rides),
      },
      recentRides: rides.rides ?? [],
    },
    poiInterests: {
      breakdown: pois,
      top5: poiInterests,
      loyaltyPoints: parseInt(badges.loyalty_points) || 0,
    },
    hazardBehavior: {
      confirmationsGiven: parseInt(hazards.confirmations_given),
      denialsGiven:       parseInt(hazards.denials_given),
      totalResponses:     parseInt(hazards.total_responses),
      confirmationRate:   hazards.total_responses > 0
        ? Math.round((hazards.confirmations_given / hazards.total_responses) * 100)
        : 0,
      byType: {
        pothole: parseInt(hazards.pothole_responses),
        bump:    parseInt(hazards.bump_responses),
        rough:   parseInt(hazards.rough_responses),
      },
    },
    travaliaCard: {
      user_id:          user.user_id,
      country_of_origin: user.country ?? "unknown",
      poi_interests:    poiInterests,
      route_preference: dominantMode,
      activity_level:   activityLevel,
      preferred_time:   preferredTime,
      geographic_focus: geoFocusQuery.rows.map(r => `${r.lat},${r.lon}`),
      travalia_score:   travaliaScore,
    },
  });
});

// ── GET /admin/users/:id/preferences ─────────────────────────────────────────
router.get("/:id/preferences", async (req, res) => {
  // Re-use full profile and return only the travaliaCard
  const profileRes = await fetch(
    `http://localhost:${process.env.PORT || 5050}/admin/users/${req.params.id}`,
    { headers: { authorization: req.headers["authorization"] } }
  );
  const data = await profileRes.json();
  res.json(data.travaliaCard ?? data);
});

// ── PATCH /admin/users/:id/flag-travalia ─────────────────────────────────────
router.patch("/:id/flag-travalia", async (req, res) => {
  const { id } = req.params;
  const { flag } = req.body; // true / false
  await pool.query(
    `UPDATE users SET flagged_for_travalia = $1 WHERE user_id = $2`,
    [!!flag, id]
  );
  await audit(req.admin.email, "flag_travalia", id, { flag });
  res.json({ ok: true });
});

// ── GET /admin/users/:id/export-csv ──────────────────────────────────────────
router.get("/:id/export-csv", async (req, res) => {
  const { id } = req.params;
  const row = await pool.query(
    `SELECT u.user_id, u.username, u.email, u.country, u.created_at,
            u.reputation_score, u.total_contributions, u.last_active_at,
            COALESCE(r.total_rides, 0)    AS total_rides,
            COALESCE(r.total_distance, 0) AS total_distance_km,
            COALESCE(h.hazards, 0)        AS hazards_reported
     FROM users u
     LEFT JOIN (SELECT user_id, COUNT(*) total_rides, SUM(distance_km) total_distance FROM ride_sessions GROUP BY user_id) r ON r.user_id = u.user_id
     LEFT JOIN (SELECT user_id, COUNT(*) hazards FROM user_confirmations WHERE action='confirm' GROUP BY user_id) h ON h.user_id = u.user_id
     WHERE u.user_id = $1`,
    [id]
  );
  if (!row.rows[0]) return res.status(404).json({ error: "Not found" });

  const cols = Object.keys(row.rows[0]);
  const csv  = [cols.join(","), Object.values(row.rows[0]).join(",")].join("\n");

  await audit(req.admin.email, "export_user_csv", id, null);
  res.setHeader("Content-Type", "text/csv");
  res.setHeader("Content-Disposition", `attachment; filename="user_${id}.csv"`);
  res.send(csv);
});

export default router;
