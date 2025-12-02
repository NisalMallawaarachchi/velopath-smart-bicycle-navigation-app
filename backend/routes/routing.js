// routes/routing.js
import express from "express";
import db from "../config/db.js";

const router = express.Router();

/**
 * GET /api/pg-routing/route
 *
 * Required query params:
 *   - startLon, startLat, endLon, endLat
 *
 * Optional:
 *   - profile = shortest | safest | scenic | balanced
 */
router.get("/route", async (req, res) => {
  try {
    const { startLon, startLat, endLon, endLat, profile } = req.query;

    if (!startLon || !startLat || !endLon || !endLat) {
      return res.status(400).json({ error: "Missing coordinates" });
    }

    // 0️⃣ Decide weights based on profile
    let wDist, wHazard, wScenic;
    switch ((profile || "balanced").toLowerCase()) {
      case "shortest":
        wDist = 0.7;
        wHazard = 0.2;
        wScenic = 0.1;
        break;
      case "safest":
        wDist = 0.2;
        wHazard = 0.7;
        wScenic = 0.1;
        break;
      case "scenic":
        wDist = 0.2;
        wHazard = 0.1;
        wScenic = 0.7;
        break;
      case "balanced":
      default:
        wDist = 0.4;
        wHazard = 0.3;
        wScenic = 0.3;
        break;
    }

    // 1️⃣ Detect component near the START point
    const compQuery = await db.query(
      `
      SELECT component
      FROM roads
      ORDER BY geometry <-> ST_SetSRID(ST_Point($1,$2),4326)
      LIMIT 1;
      `,
      [startLon, startLat]
    );

    if (compQuery.rows.length === 0) {
      return res.status(400).json({ error: "No component detected" });
    }

    const component = compQuery.rows[0].component;

    // 2️⃣ Find nearest nodes inside the same component
    const nearest = await db.query(
      `
      WITH start_n AS (
        SELECT source AS node
        FROM roads
        WHERE component = $5
        ORDER BY geometry <-> ST_SetSRID(ST_Point($1,$2),4326)
        LIMIT 1
      ),
      end_n AS (
        SELECT source AS node
        FROM roads
        WHERE component = $5
        ORDER BY geometry <-> ST_SetSRID(ST_Point($3,$4),4326)
        LIMIT 1
      )
      SELECT 
        (SELECT node FROM start_n) AS start_node,
        (SELECT node FROM end_n)   AS end_node;
      `,
      [startLon, startLat, endLon, endLat, component]
    );

    const startNode = nearest.rows[0]?.start_node;
    const endNode = nearest.rows[0]?.end_node;

    if (!startNode || !endNode) {
      return res.status(400).json({
        error: "Cannot find valid start/end nodes in this component",
      });
    }

    // 3️⃣ Run Dijkstra with multi-objective cost
    const route = await db.query(
      `
      WITH route AS (
        SELECT * FROM pgr_dijkstra(
          $$
            SELECT 
              r.road_id AS id,
              r.source,
              r.target,
              (
                ${wDist}   * (r.length_meters / 1000.0) +
                ${wHazard} * COALESCE(rs.hazard_count, 0) +
                ${wScenic} * (1.0 / (1.0 + COALESCE(rs.poi_score, 0)))
              ) AS cost,
              (
                ${wDist}   * (r.length_meters / 1000.0) +
                ${wHazard} * COALESCE(rs.hazard_count, 0) +
                ${wScenic} * (1.0 / (1.0 + COALESCE(rs.poi_score, 0)))
              ) AS reverse_cost
            FROM roads r
            LEFT JOIN road_segment_data rs
              ON r.road_id = rs.road_id
            WHERE r.component = ${component}
          $$,
          $1::BIGINT,
          $2::BIGINT
        )
      )
      SELECT 
        r.road_id AS id,
        r.length_meters,
        ST_AsGeoJSON(r.geometry) AS geojson,
        COALESCE(rs.hazard_count, 0) AS hazard_count,
        COALESCE(rs.poi_score, 0) AS poi_score,
        route.seq,
        route.cost
      FROM route
      JOIN roads r
        ON route.edge = r.road_id
      LEFT JOIN road_segment_data rs
        ON r.road_id = rs.road_id
      WHERE route.edge <> -1
      ORDER BY route.seq;
      `,
      [startNode, endNode]
    );

    const edges = route.rows;

    if (edges.length === 0) {
      return res.json({
        error: "No route found within this component",
        component,
        startNode,
        endNode,
      });
    }

    // 4️⃣ Compute summary statistics in JS
    let totalDistanceKm = 0;
    let totalHazard = 0;
    let totalPoiScore = 0;

    edges.forEach((row) => {
      totalDistanceKm += (row.length_meters || 0) / 1000.0;
      totalHazard += row.hazard_count || 0;
      totalPoiScore += row.poi_score || 0;
    });

    const avgPoiScore = edges.length > 0 ? totalPoiScore / edges.length : 0;

    // 5️⃣ Prepare response
    const edgesFormatted = edges.map((row) => ({
      id: row.id,
      length_meters: row.length_meters,
      hazard_count: row.hazard_count,
      poi_score: row.poi_score,
      cost: row.cost,
      geojson: JSON.parse(row.geojson), // LineString with coordinates
    }));

    return res.json({
      profile: (profile || "balanced").toLowerCase(),
      weights: {
        wDist,
        wHazard,
        wScenic,
      },
      component,
      startNode,
      endNode,
      pathCount: edges.length,
      summary: {
        totalDistanceKm,
        totalHazard,
        avgPoiScore,
      },
      edges: edgesFormatted,
    });
  } catch (error) {
    console.error("Routing error:", error);
    res.status(500).json({ error: "Routing failed", details: error.message });
  }
});

export default router;
