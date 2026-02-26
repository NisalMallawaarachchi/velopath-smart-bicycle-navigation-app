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
    const { startLon, startLat, endLon, endLat, mode = "shortest" } = req.query;
    const allowedModes = new Set(["shortest", "balanced"]);
    const safeMode = allowedModes.has(mode) ? mode : "shortest";

    console.log("🧭 Routing mode:", safeMode);

    if (!startLon || !startLat || !endLon || !endLat) {
      return res.status(400).json({ error: "Missing coordinates" });
    }

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

    const startNode = s.rows[0].id;
    const endNode = e.rows[0].id;

    // ROUTING

    let edgeSql;

    if (safeMode === "balanced") {
      edgeSql = `
    SELECT id, source, target,
           length_m * 1.05 AS cost,
           length_m * 1.05 AS reverse_cost
    FROM routing.ways
    WHERE source IS NOT NULL AND target IS NOT NULL
  `;
    } else {
      // shortest
      edgeSql = `
    SELECT id, source, target,
           length_m AS cost,
           length_m AS reverse_cost
    FROM routing.ways
    WHERE source IS NOT NULL AND target IS NOT NULL
  `;
    }

    const routeQ = await db.query(
      `
WITH r AS (
  SELECT * FROM pgr_dijkstra(
    $1,
    $2::BIGINT,
    $3::BIGINT,
    false
  )
)
SELECT
  w.id,
  w.length_m,
  ST_AsGeoJSON(w.geom) AS geojson,
  r.seq
FROM r
JOIN routing.ways w ON r.edge = w.id
WHERE r.edge <> -1
ORDER BY r.seq;
`,
      [edgeSql, startNode, endNode],
    );

    if (!routeQ.rows.length) {
      return res.json({ error: "No path found" });
    }

    // DISTANCE
    const totalMeters = routeQ.rows.reduce(
      (sum, r) => sum + Number(r.length_m || 0),
      0,
    );

    // GEOMETRY (single polyline)
    const stitched = stitchRouteCoordinates(routeQ.rows);
    const deduped = removeNearDuplicatePoints(stitched, 0.00001);

    const cleaned = turf.cleanCoords({
      type: "LineString",
      coordinates: deduped,
    }).coordinates;

    // simplify a bit to reduce visual artifacts
    const geometry = simplifyLine(cleaned, 0.00003);

    // INSTRUCTIONS (merge tiny segments + better turn labels)
    const segments = mergeRouteSegments(routeQ.rows, {
      minMergeLengthM: 30,
      maxMergeAngleDeg: 10,
      preferSameName: true,
    });

    const instructions = generateInstructionsFromSegments(segments);

    // RESPONSE
    res.json({
  mode: safeMode,
  geometry,
  instructions,
  summary: {
    totalDistanceKm: totalMeters / 1000
  }
});
  } catch (err) {
    console.error("ROUTING ERROR", err);
    res.status(500).json({ error: err.message });
  }
});

export default router;
