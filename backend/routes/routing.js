// routes/routing.js
import express from "express";
import db from "../config/db.js";
import * as turf from "@turf/turf";

const router = express.Router();

/* ================================================== */
/* BEARING HELPERS                                    */
/* ================================================== */
function bearing(p1, p2) {
  const toRad = (d) => (d * Math.PI) / 180;
  const lat1 = toRad(p1.lat);
  const lat2 = toRad(p2.lat);
  const dLon = toRad(p2.lon - p1.lon);

  const y = Math.sin(dLon) * Math.cos(lat2);
  const x =
    Math.cos(lat1) * Math.sin(lat2) -
    Math.sin(lat1) * Math.cos(lat2) * Math.cos(dLon);

  // [-180, 180]
  return (Math.atan2(y, x) * 180) / Math.PI;
}

function normalizeAngle(a) {
  // -> (-180, 180]
  return ((a + 540) % 360) - 180;
}

function safeJsonGeom(geojsonStr) {
  try {
    return JSON.parse(geojsonStr);
  } catch {
    return null;
  }
}

/* ================================================== */
/* ROUTE GEOMETRY HELPERS                             */
/* ================================================== */
function stitchRouteCoordinates(routeRows) {
  const coords = [];

  for (let i = 0; i < routeRows.length; i++) {
    const g = safeJsonGeom(routeRows[i].geojson);
    if (!g || !Array.isArray(g.coordinates) || g.coordinates.length < 2)
      continue;

    const edge = g.coordinates;

    if (coords.length === 0) {
      coords.push(...edge);
      continue;
    }

    const last = coords[coords.length - 1];
    const first = edge[0];

    const same =
      last &&
      first &&
      Array.isArray(last) &&
      Array.isArray(first) &&
      last.length === 2 &&
      first.length === 2 &&
      last[0] === first[0] &&
      last[1] === first[1];

    if (same) coords.push(...edge.slice(1));
    else coords.push(...edge);
  }

  return coords;
}

function removeNearDuplicatePoints(coords, epsilonDeg = 0.00001) {
  if (!Array.isArray(coords) || coords.length < 2) return coords;
  const out = [coords[0]];

  for (let i = 1; i < coords.length; i++) {
    const a = out[out.length - 1];
    const b = coords[i];
    if (!a || !b || a.length !== 2 || b.length !== 2) continue;

    const dLon = Math.abs(a[0] - b[0]);
    const dLat = Math.abs(a[1] - b[1]);
    if (dLon < epsilonDeg && dLat < epsilonDeg) continue;

    out.push(b);
  }

  return out;
}

function simplifyLine(coords, tolerance = 0.00003) {
  // ~3e-5 degrees ~ few meters. Tune if needed.
  if (!Array.isArray(coords) || coords.length < 2) return coords;

  const line = turf.lineString(coords);
  const simplified = turf.simplify(line, {
    tolerance,
    highQuality: true,
    mutate: false,
  });

  const out = simplified?.geometry?.coordinates;
  if (Array.isArray(out) && out.length >= 2) return out;
  return coords;
}

/* ================================================== */
/* TURN ACCURACY (MERGE SMALL SEGMENTS)               */
/* ================================================== */
function mergeRouteSegments(routeRows, opts = {}) {
  const {
    minMergeLengthM = 30, // merge tiny edges (noise)
    maxMergeAngleDeg = 10, // merge if direction change is tiny
    preferSameName = true, // merge same named roads
  } = opts;

  const segments = [];
  if (!routeRows.length) return segments;

  const edgeCoords = (row) => {
    const g = safeJsonGeom(row.geojson);
    return g?.coordinates;
  };

  const edgeEndBearing = (coords) => {
    if (!Array.isArray(coords) || coords.length < 2) return null;
    const a = coords[coords.length - 2];
    const b = coords[coords.length - 1];
    return bearing({ lon: a[0], lat: a[1] }, { lon: b[0], lat: b[1] });
  };

  let cur = {
    name: routeRows[0].name || null,
    length_m: Number(routeRows[0].length_m) || 0,
    coords: Array.isArray(edgeCoords(routeRows[0]))
      ? [...edgeCoords(routeRows[0])]
      : [],
  };

  for (let i = 1; i < routeRows.length; i++) {
    const row = routeRows[i];
    const rowName = row.name || null;
    const rowLen = Number(row.length_m) || 0;
    const rowCoords = edgeCoords(row);

    if (!Array.isArray(rowCoords) || rowCoords.length < 2) continue;

    const bCur = edgeEndBearing(cur.coords);
    const bNext = edgeEndBearing(rowCoords);

    let angleDelta = 0;
    if (bCur !== null && bNext !== null) {
      angleDelta = normalizeAngle(bNext - bCur);
    }

    const sameName =
      preferSameName && cur.name && rowName && cur.name === rowName;

    const tiny = rowLen > 0 && rowLen <= minMergeLengthM;
    const smallAngle = Math.abs(angleDelta) <= maxMergeAngleDeg;

    const shouldMerge = sameName || tiny || smallAngle;

    if (shouldMerge) {
      const last = cur.coords[cur.coords.length - 1];
      const first = rowCoords[0];
      const sameJoin =
        last && first && last[0] === first[0] && last[1] === first[1];

      if (sameJoin) cur.coords.push(...rowCoords.slice(1));
      else cur.coords.push(...rowCoords);

      cur.length_m += rowLen;

      if (!cur.name && rowName) cur.name = rowName;
    } else {
      segments.push(cur);
      cur = {
        name: rowName,
        length_m: rowLen,
        coords: [...rowCoords],
      };
    }
  }

  segments.push(cur);
  return segments;
}

/* ================================================== */
/* TURN CLASSIFICATION (U-turn + keep + slight etc.)  */
/* ================================================== */
function classifyTurn(deltaDeg) {
  const d = normalizeAngle(deltaDeg);
  const a = Math.abs(d);

  if (a >= 165) return { type: "uturn", text: "Make a U-turn" };
  if (a >= 120)
    return { type: "sharp", text: d > 0 ? "Sharp right" : "Sharp left" };
  if (a >= 45)
    return { type: "turn", text: d > 0 ? "Turn right" : "Turn left" };

  // keep vs slight (helps those “slight left/right”, “keep left/right” cases)
  if (a >= 25)
    return { type: "slight", text: d > 0 ? "Slight right" : "Slight left" };
  if (a >= 10)
    return { type: "keep", text: d > 0 ? "Keep right" : "Keep left" };

  return null; // straight-ish
}

function generateInstructionsFromSegments(segments) {
  const instructions = [];
  if (!segments.length) return instructions;

  // START
  const start = segments[0].coords?.[0];
  if (start) {
    instructions.push({
      type: "start",
      textEn: "Start riding",
      lon: start[0],
      lat: start[1],
    });
  }

  // TURNS
  let lastContinueAt = -999;

  for (let i = 1; i < segments.length; i++) {
    const prev = segments[i - 1];
    const curr = segments[i];

    if (!prev.coords || prev.coords.length < 2) continue;
    if (!curr.coords || curr.coords.length < 2) continue;

    const p1Arr = prev.coords[prev.coords.length - 2];
    const p2Arr = prev.coords[prev.coords.length - 1];
    const p3Arr = curr.coords[1];

    const b1 = bearing(
      { lon: p1Arr[0], lat: p1Arr[1] },
      { lon: p2Arr[0], lat: p2Arr[1] },
    );
    const b2 = bearing(
      { lon: p2Arr[0], lat: p2Arr[1] },
      { lon: p3Arr[0], lat: p3Arr[1] },
    );
    const delta = normalizeAngle(b2 - b1);

    const classified = classifyTurn(delta);

    // "Continue straight" on long segments (but don’t spam)
    const currLen = Number(curr.length_m) || 0;
    const isLong = currLen >= 250;

    if (!classified) {
      if (isLong && i - lastContinueAt >= 3) {
        instructions.push({
          type: "continue",
          textEn: `Continue straight for ${Math.round(currLen)} m`,
          lon: p2Arr[0],
          lat: p2Arr[1],
        });
        lastContinueAt = i;
      }
      continue;
    }

    const roadName = curr.name ? ` onto ${curr.name}` : "";
    instructions.push({
      type: classified.type,
      textEn: `${classified.text}${roadName}`,
      lon: p2Arr[0],
      lat: p2Arr[1],
    });
  }

  // ARRIVE
  const lastSeg = segments[segments.length - 1];
  const lastCoord =
    lastSeg?.coords && lastSeg.coords.length
      ? lastSeg.coords[lastSeg.coords.length - 1]
      : null;

  if (lastCoord) {
    instructions.push({
      type: "arrive",
      textEn: "Arrived at your destination",
      lon: lastCoord[0],
      lat: lastCoord[1],
    });
  }

  return instructions;
}

/* ================================================== */
/* ROUTE ENDPOINT                                     */
/* ================================================== */
router.get("/route", async (req, res) => {
  try {
    const { mode = "shortest" } = req.query;
    const allowedModes = new Set(["shortest", "balanced", "safest", "scenic"]);
    const safeMode = allowedModes.has(mode) ? mode : "shortest";

    // Parse and validate all coordinate params before any SQL use
    const startLon = parseFloat(req.query.startLon);
    const startLat = parseFloat(req.query.startLat);
    const endLon   = parseFloat(req.query.endLon);
    const endLat   = parseFloat(req.query.endLat);

    if (isNaN(startLon) || isNaN(startLat) || isNaN(endLon) || isNaN(endLat)) {
      return res.status(400).json({ error: "Missing or invalid coordinates" });
    }

    console.log("🧭 Routing mode:", safeMode);

    // SNAP
    const snap = async (lon, lat) =>
      db.query(
        `
        SELECT id
        FROM routing.ways_vertices_pgr
        ORDER BY geom <-> ST_SetSRID(ST_Point($1,$2),4326)
        LIMIT 1;
        `,
        [lon, lat],
      );

    const s = await snap(startLon, startLat);
    const e = await snap(endLon, endLat);

    if (!s.rows.length || !e.rows.length) {
      return res.status(500).json({ error: "Snap failed" });
    }

    const startNode = parseInt(s.rows[0].id);
    const endNode = parseInt(e.rows[0].id);

    console.log(`📌 [ROUTING] Nodes: ${startNode} (type: ${typeof startNode}) -> ${endNode} (type: ${typeof endNode})`);

    // ROUTING
    // General mathematical structure: C(e) = w_d * Distance + w_s * HazardRisk + w_q * RoadDifficulty - w_sc * ScenicValue

    let w_d = 1.0;
    let w_s = 0.0;
    let w_q = 0.0; // Currently disabled as no surface data exists in table
    let w_sc = 0.0;

    if (safeMode === "safest") {
      w_d = 0.4;
      w_s = 0.6;
    } else if (safeMode === "scenic") {
      w_d = 0.4;
      w_sc = 0.6;
    } else if (safeMode === "balanced") {
      w_d = 0.4;
      w_s = 0.3;
      w_sc = 0.3;
    } // else shortest (defaults above)

    // Bounding Box: dynamically expand based on euclidean trip distance
    const distDeg = Math.sqrt(Math.pow(endLon - startLon, 2) + Math.pow(endLat - startLat, 2));
    const expandDeg = Math.max(0.15, distDeg * 1.5);

    // Multiplicative Cost formula
    let costExpr = `length_m * ${w_d}`;
    let hazardExpr = w_s > 0 ? `(1.0 + (${w_s} * COALESCE((SELECT COUNT(*) FROM public.hazards h WHERE ST_DWithin(w.geom, h.location, 0.0005)), 0) * 10.0))` : `1.0`;
    let scenicExpr = w_sc > 0 ? `GREATEST(0.01, 1.0 - (${w_sc} * COALESCE((SELECT SUM(p.score) FROM public.custom_pois p WHERE ST_DWithin(w.geom, p.geom, 0.001)), 0) / 5.0))` : `1.0`;

    const bboxFilter = `ST_Intersects(w.geom, ST_Expand(ST_SetSRID(ST_MakeBox2D(ST_Point(${startLon}, ${startLat}), ST_Point(${endLon}, ${endLat})), 4326), ${expandDeg}))`;

    const edgeSqlBbox = `
      SELECT id, source, target,
        (${costExpr} * ${hazardExpr} * ${scenicExpr}) AS cost,
        (${costExpr} * ${hazardExpr} * ${scenicExpr}) AS reverse_cost
      FROM routing.ways w
      WHERE source IS NOT NULL AND target IS NOT NULL
        AND ${bboxFilter}
    `;

    // NOTE: Node IDs are embedded directly to avoid parameterized query issues with pgr_dijkstra
    const outerQuery = (innerEdgeSql) => `
SELECT w.id, w.length_m, w.name,
  EXISTS (SELECT 1 FROM public.hazards h WHERE ST_DWithin(w.geom, h.location, 0.0005)) AS has_hazard,
  COALESCE((SELECT AVG(p.score) FROM public.custom_pois p WHERE ST_DWithin(w.geom, p.geom, 0.0005)), 0) AS poi_score,
  ST_AsGeoJSON(CASE WHEN r.node = w.target THEN ST_Reverse(w.geom) ELSE w.geom END) AS geojson,
  r.seq
FROM pgr_dijkstra($$ ${innerEdgeSql} $$, ${startNode}, ${endNode}, true) AS r
JOIN routing.ways w ON r.edge = w.id
ORDER BY r.seq;
`;

    // Attempt 1: bbox-filtered with full cost formula
    console.log(`🧭 [ROUTING] Attempt 1: bbox=${expandDeg.toFixed(3)}° with full cost formula`);
    let routeQ = { rows: [] };
    try {
      routeQ = await db.query(outerQuery(edgeSqlBbox));
      console.log(`   Attempt 1 result: ${routeQ.rows.length} rows`);
    } catch (err) {
      console.log(`⚠️ [ROUTING] Attempt 1 failed: ${err.message.substring(0, 200)}`);
    }

    // Attempt 2: full table with simple length_m cost (fast, always finds a path if one exists)
    if (!routeQ.rows.length) {
      console.log(`🧭 [ROUTING] Attempt 2: full table with simple cost`);
      const edgeSqlSimple = `SELECT id, source, target, length_m AS cost, length_m AS reverse_cost FROM routing.ways WHERE source IS NOT NULL AND target IS NOT NULL`;
      try {
        routeQ = await db.query(outerQuery(edgeSqlSimple));
        console.log(`   Attempt 2 result: ${routeQ.rows.length} rows`);
      } catch (err) {
        console.log(`⚠️ [ROUTING] Attempt 2 failed: ${err.message.substring(0, 200)}`);
      }
    }

    if (routeQ.rows.length) {
      console.log(`✅ [ROUTING] Found path: ${routeQ.rows.length} segments`);
    }

    if (!routeQ.rows.length) {
      return res.json({ error: "No path found" });
    }

    // ===== COMPUTE TOTALS =====

    // Distance
    const totalMeters = routeQ.rows.reduce(
      (sum, r) => sum + Number(r.length_m || 0),
      0,
    );

    // Hazard count + POI total
    let totalHazards = 0;
    let totalPoiScore = 0;

    routeQ.rows.forEach((r) => {
      if (r.has_hazard) totalHazards++;
      totalPoiScore += Number(r.poi_score || 0);
    });

    // Average POI score
    const avgPoiScore =
      routeQ.rows.length > 0 ? totalPoiScore / routeQ.rows.length : 0;

    // GEOMETRY (single polyline)
    const stitched = stitchRouteCoordinates(routeQ.rows);
    const deduped = removeNearDuplicatePoints(stitched, 0.00001);

    const cleaned = turf.cleanCoords({
      type: "LineString",
      coordinates: deduped,
    }).coordinates;

    const geometry = [...cleaned];

    // Anchor the polyline exactly to the user's requested Start and End coordinates 
    // to prevent Flutter mapping gaps from drawing detached straight lines.
    if (startLon && startLat) {
       geometry.unshift([Number(startLon), Number(startLat)]);
    }
    if (endLon && endLat) {
       geometry.push([Number(endLon), Number(endLat)]);
    }

    // INSTRUCTIONS (merge tiny segments + better turn labels)
    const segments = mergeRouteSegments(routeQ.rows, {
      minMergeLengthM: 30,
      maxMergeAngleDeg: 10,
      preferSameName: true,
    });

    const instructions = generateInstructionsFromSegments(segments);

    // ==========================================
    // EXTRACT POIS & HAZARDS ALONG THE ROUTE NATIVELY
    // ==========================================
    let routePoisRows = [];
    let routeHazardsRows = [];
    
    // Convert the exact geometry array into a PostGIS LineString for localized queries
    if (geometry && geometry.length > 1) {
      const lineStringWKT = `SRID=4326;LINESTRING(${geometry.map((c) => `${c[0]} ${c[1]}`).join(", ")})`;

      // Fetch Top 5 POIs along this precise route
      const routePoisQ = await db.query(
        `
        SELECT id, name, amenity, score, vote_count, ST_Y(geom) as lat, ST_X(geom) as lon
        FROM public.custom_pois
        WHERE ST_DWithin(geom, ST_GeomFromEWKT($1), 0.001) -- within ~100m
        ORDER BY score DESC, vote_count DESC
        LIMIT 5;
        `,
        [lineStringWKT]
      );
      routePoisRows = routePoisQ.rows;

      const routeHazardsQ = await db.query(
        `
        SELECT id::text, hazard_type as type, confidence_score, ST_Y(location) as lat, ST_X(location) as lon
        FROM public.hazards
        WHERE ST_DWithin(location, ST_GeomFromEWKT($1), 0.001) -- within ~110m
          AND status IN ('pending', 'verified')
        ORDER BY confidence_score DESC
        LIMIT 50;
        `,
        [lineStringWKT]
      );
      routeHazardsRows = routeHazardsQ.rows;
    }

    // RESPONSE
    res.json({
      mode: safeMode,
      geometry,
      instructions,
      pois: routePoisRows,
      hazards: routeHazardsRows,
      summary: {
        totalDistanceKm: totalMeters / 1000,
        totalHazards,
        avgPoiScore,
      },
    });
  } catch (err) {
    console.error("ROUTING ERROR", err);
    res.status(500).json({ error: err.message });
  }
});

export default router;

