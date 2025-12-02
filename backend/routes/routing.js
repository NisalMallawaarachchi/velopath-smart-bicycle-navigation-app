// routes/routing.js
import express from "express";
import db from "../config/db.js";

const router = express.Router();

/**
 * GET /api/pg-routing/route
 * Query params:
 *   startLon, startLat, endLon, endLat
 */
router.get("/route", async (req, res) => {
  try {
    const { startLon, startLat, endLon, endLat } = req.query;

    if (!startLon || !startLat || !endLon || !endLat) {
      return res.status(400).json({ error: "Missing coordinates" });
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

    // 3️⃣ Run Dijkstra within that component
    const route = await db.query(
      `
      SELECT * FROM pgr_dijkstra(
        $$
          SELECT road_id AS id,
                 source,
                 target,
                 cost,
                 reverse_cost
          FROM roads
          WHERE component = ${component}
        $$,
        $1::BIGINT,
        $2::BIGINT
      );
      `,
      [startNode, endNode]
    );

    // No route found
    if (route.rows.length === 0) {
      return res.json({
        error: "No route found within this component",
        component,
        startNode,
        endNode,
      });
    }

    // 4️⃣ Get geometries for all edges in the route
    const edges = await db.query(
      `
      SELECT road_id AS id, geometry
      FROM roads
      WHERE road_id IN (
        SELECT edge FROM (
          SELECT * FROM pgr_dijkstra(
            $$
              SELECT road_id AS id,
                     source,
                     target,
                     cost,
                     reverse_cost
              FROM roads
              WHERE component = ${component}
            $$,
            $1::BIGINT,
            $2::BIGINT
          )
        ) AS path_edges
        WHERE edge <> -1
      );
      `,
      [startNode, endNode]
    );

    return res.json({
      component,
      startNode,
      endNode,
      pathCount: route.rows.length,
      edges: edges.rows,
    });
  } catch (error) {
    console.error("Routing error:", error);
    res.status(500).json({ error: "Routing failed", details: error.message });
  }
});

export default router;
