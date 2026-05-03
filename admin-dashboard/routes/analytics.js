import { Router } from "express";
import pool from "../db.js";

const router = Router();

// ── GET /admin/analytics/countries ───────────────────────────────────────────
router.get("/countries", async (req, res) => {
  const [countryPrefs, poiByCountry] = await Promise.all([
    pool.query(`
      SELECT
        u.country,
        COUNT(DISTINCT u.user_id)                                        AS user_count,
        ROUND(AVG(rs.distance_km)::numeric, 2)                          AS avg_distance_km,
        MODE() WITHIN GROUP (ORDER BY rs.route_mode)                    AS top_route_mode,
        ROUND(AVG(u.reputation_score)::numeric, 2)                      AS avg_reputation
      FROM users u
      LEFT JOIN ride_sessions rs ON rs.user_id = u.user_id
      WHERE u.country IS NOT NULL
      GROUP BY u.country
      ORDER BY user_count DESC
    `),
    pool.query(`
      SELECT
        u.country,
        pv.poi_category,
        COUNT(*) AS visit_count
      FROM poi_visits pv
      JOIN users u ON u.user_id = pv.user_id
      WHERE u.country IS NOT NULL AND pv.poi_category IS NOT NULL
      GROUP BY u.country, pv.poi_category
      ORDER BY u.country, visit_count DESC
    `),
  ]);

  // Pivot: for each country pick top POI category
  const topPoiByCountry = {};
  for (const row of poiByCountry.rows) {
    if (!topPoiByCountry[row.country]) topPoiByCountry[row.country] = row.poi_category;
  }

  const result = countryPrefs.rows.map(r => ({
    ...r,
    top_poi_category: topPoiByCountry[r.country] ?? null,
  }));

  // POI breakdown per country (for grouped bar chart)
  const poiBreakdown = {};
  for (const row of poiByCountry.rows) {
    if (!poiBreakdown[row.country]) poiBreakdown[row.country] = {};
    poiBreakdown[row.country][row.poi_category] = parseInt(row.visit_count);
  }

  res.json({ table: result, poiBreakdown });
});

// ── GET /admin/analytics/poi-trends ──────────────────────────────────────────
// Query params: months (default 6)
router.get("/poi-trends", async (req, res) => {
  const months = Math.min(24, parseInt(req.query.months ?? 6));

  const rows = await pool.query(`
    SELECT
      DATE_TRUNC('month', visited_at) AS month,
      poi_category,
      COUNT(*)                        AS visits
    FROM poi_visits
    WHERE visited_at >= NOW() - ($1 || ' months')::INTERVAL
      AND poi_category IS NOT NULL
    GROUP BY month, poi_category
    ORDER BY month ASC, visits DESC
  `, [months]);

  // Collect all categories and months for chart series
  const months_set = [...new Set(rows.rows.map(r => r.month))];
  const cats_set   = [...new Set(rows.rows.map(r => r.poi_category))];

  const series = cats_set.map(cat => ({
    category: cat,
    data: months_set.map(m => {
      const found = rows.rows.find(r => r.poi_category === cat && r.month === m);
      return { month: m, visits: found ? parseInt(found.visits) : 0 };
    }),
  }));

  res.json({ series, months: months_set, categories: cats_set });
});

// ── GET /admin/analytics/route-modes ─────────────────────────────────────────
router.get("/route-modes", async (req, res) => {
  const [overall, byCountry, byHour] = await Promise.all([
    pool.query(`
      SELECT route_mode, COUNT(*) AS count
      FROM ride_sessions
      WHERE route_mode IS NOT NULL
      GROUP BY route_mode
    `),
    pool.query(`
      SELECT u.country, rs.route_mode, COUNT(*) AS count
      FROM ride_sessions rs
      JOIN users u ON u.user_id = rs.user_id
      WHERE u.country IS NOT NULL AND rs.route_mode IS NOT NULL
      GROUP BY u.country, rs.route_mode
      ORDER BY u.country, count DESC
    `),
    pool.query(`
      SELECT EXTRACT(HOUR FROM started_at) AS hour, route_mode, COUNT(*) AS count
      FROM ride_sessions
      WHERE route_mode IS NOT NULL
      GROUP BY hour, route_mode
      ORDER BY hour
    `),
  ]);

  res.json({
    overall:   overall.rows,
    byCountry: byCountry.rows,
    byHour:    byHour.rows,
  });
});

// ── GET /admin/analytics/system-health ───────────────────────────────────────
router.get("/system-health", async (req, res) => {
  const [users, hazards, rides, decay, sync, mlModel] = await Promise.all([
    pool.query(`
      SELECT
        COUNT(*)                                                          AS total_users,
        COUNT(*) FILTER (WHERE created_at >= NOW() - INTERVAL '1 day')   AS new_today,
        COUNT(*) FILTER (WHERE last_active_at >= NOW() - INTERVAL '1 day')  AS active_24h,
        COUNT(*) FILTER (WHERE last_active_at >= NOW() - INTERVAL '7 days') AS active_7d,
        COUNT(*) FILTER (WHERE last_active_at >= NOW() - INTERVAL '30 days') AS active_30d
      FROM users
    `),
    pool.query(`
      SELECT
        COUNT(*)                                                              AS total_hazards,
        COUNT(*) FILTER (WHERE status = 'verified')                          AS verified,
        COUNT(*) FILTER (WHERE status = 'pending')                           AS pending,
        COUNT(*) FILTER (WHERE first_detected >= NOW() - INTERVAL '1 day')   AS detected_today
      FROM hazards
    `),
    pool.query(`
      SELECT
        COUNT(*)                                                            AS total_rides,
        COUNT(*) FILTER (WHERE started_at >= NOW() - INTERVAL '1 day')     AS rides_today
      FROM ride_sessions
    `),
    pool.query(`
      SELECT created_at AS last_decay_run
      FROM processing_log
      WHERE event_type = 'decay_run'
      ORDER BY created_at DESC LIMIT 1
    `),
    pool.query(`
      SELECT synced_at AS last_sync, user_count, status
      FROM travalia_sync_log
      ORDER BY synced_at DESC LIMIT 1
    `),
    pool.query(`
      SELECT details
      FROM processing_log
      WHERE event_type = 'model_trained'
      ORDER BY created_at DESC LIMIT 1
    `),
  ]);

  res.json({
    users:          users.rows[0],
    hazards:        hazards.rows[0],
    rides:          rides.rows[0],
    lastDecayRun:   decay.rows[0]?.last_decay_run ?? null,
    lastTravaliaSync: sync.rows[0] ?? null,
    mlModel:        mlModel.rows[0]?.details ?? null,
  });
});

export default router;
