import pool from "../config/db.js";

// Helpers

/**
 * Compute a quality score from 0–100
 * Score is on a 1–5 scale, normalized to 0–100 for internal ranking.
 * 70% from average star rating (1–5 → 0–100), 30% from log-scaled vote count
 */
function computeQualityScore(score, voteCount) {
  const normalizedScore = ((score || 0) / 5) * 100;
  const scorePart = normalizedScore * 0.7;
  const votePart = Math.log1p(voteCount || 0) * (30 / Math.log1p(100));
  return Math.min(100, scorePart + votePart);
}

/**
 * Haversine distance in km between two lat/lon points
 */
function haversineKm(lat1, lon1, lat2, lon2) {
  const R = 6371;
  const dLat = ((lat2 - lat1) * Math.PI) / 180;
  const dLon = ((lon2 - lon1) * Math.PI) / 180;
  const a =
    Math.sin(dLat / 2) ** 2 +
    Math.cos((lat1 * Math.PI) / 180) *
      Math.cos((lat2 * Math.PI) / 180) *
      Math.sin(dLon / 2) ** 2;
  return R * 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
}

/**
 * Lightweight DBSCAN-inspired clustering
 */
function dbscanCluster(pois, eps = 0.5, minPts = 2) {
  const n = pois.length;
  const labels = new Array(n).fill(-1);
  let clusterId = 0;

  function getNeighbors(idx) {
    const neighbors = [];
    for (let i = 0; i < n; i++) {
      if (i === idx) continue;
      const d = haversineKm(
        pois[idx].lat, pois[idx].lon,
        pois[i].lat,   pois[i].lon
      );
      if (d <= eps) neighbors.push(i);
    }
    return neighbors;
  }

  for (let i = 0; i < n; i++) {
    if (labels[i] !== -1) continue;
    const neighbors = getNeighbors(i);
    if (neighbors.length < minPts) { labels[i] = 0; continue; }
    clusterId++;
    labels[i] = clusterId;
    const queue = [...neighbors];
    while (queue.length > 0) {
      const j = queue.shift();
      if (labels[j] === 0) labels[j] = clusterId;
      if (labels[j] !== -1) continue;
      labels[j] = clusterId;
      const jNeighbors = getNeighbors(j);
      if (jNeighbors.length >= minPts) queue.push(...jNeighbors);
    }
  }

  return labels;
}

/**
 * Classify a quality tier from adjusted score (0–100 internal).
 * POIs with zero votes bypass this and are tagged "new" before this runs.
 */
function qualityTier(qs) {
  if (qs >= 65) return "high";
  if (qs >= 35) return "medium";
  return "low";
}

// Controller

export const getRankedPOIs = async (req, res) => {
  try {
    const { district } = req.query;
    const districtFilter = district && district !== "All" ? district : null;

    // Custom POIs — already have their own votes stored directly
    const customResult = await pool.query(`
      SELECT
        id::text,
        name,
        amenity,
        description,
        lat::float,
        lon::float,
        COALESCE(district, 'Other')    AS district,
        image_url,
        COALESCE(score, 0)::float      AS score,
        COALESCE(vote_count, 0)::int   AS vote_count,
        'custom'                       AS source
      FROM custom_pois
      WHERE osm_id IS NULL
        AND ($1::text IS NULL OR district = $1)
    `, [districtFilter]);

    // OSM POIs — LEFT JOIN custom_pois to pick up votes stored there after voting
    // When someone votes on an OSM POI it gets inserted into custom_pois with osm_id set,
    // so we must use that row's score/vote_count instead of the hardcoded 0.
    const osmResult = await pool.query(`
      SELECT
        p.osm_id::text                         AS id,
        p.name,
        p.amenity,
        NULL                                   AS description,
        ST_Y(ST_Transform(p.way, 4326))::float AS lat,
        ST_X(ST_Transform(p.way, 4326))::float AS lon,
        COALESCE(p.district, 'Other')          AS district,
        NULL                                   AS image_url,
        COALESCE(c.score, 0)::float            AS score,
        COALESCE(c.vote_count, 0)::int         AS vote_count,
        'osm'                                  AS source
      FROM planet_osm_point p
      LEFT JOIN custom_pois c ON c.osm_id = p.osm_id::text
      WHERE p.name IS NOT NULL
        AND p.amenity IS NOT NULL
        AND ($1::text IS NULL OR p.district = $1)
    `, [districtFilter]);

    let allPois = [...customResult.rows, ...osmResult.rows].filter(
      (p) => p.lat != null && p.lon != null && !isNaN(p.lat) && !isNaN(p.lon)
    );

    if (allPois.length === 0) {
      return res.json({ total: 0, pois: [] });
    }

    // ── Split: unvoted POIs get tier "new", skip all ranking math ─────────
    const unvotedPois = allPois
      .filter((p) => (p.vote_count || 0) === 0)
      .map((p) => ({
        ...p,
        qualityScore:  0,
        clusterId:     null,
        adjustedScore: null,
        tier:          "new",
      }));

    const votedPois = allPois.filter((p) => (p.vote_count || 0) > 0);

    // ── Rank only voted POIs ───────────────────────────────────────────────
    let rankedPois = [];

    if (votedPois.length > 0) {
      let ranked = votedPois.map((poi) => ({
        ...poi,
        qualityScore: computeQualityScore(poi.score, poi.vote_count),
      }));

      const clusterLabels = dbscanCluster(ranked, 0.5, 2);

      const clusterStats = {};
      clusterLabels.forEach((cid, i) => {
        if (cid === 0) return;
        if (!clusterStats[cid]) clusterStats[cid] = { sum: 0, count: 0 };
        clusterStats[cid].sum   += ranked[i].qualityScore;
        clusterStats[cid].count += 1;
      });

      rankedPois = ranked.map((poi, i) => {
        const cid = clusterLabels[i];
        let adjustedScore = poi.qualityScore;

        if (cid > 0) {
          const { sum, count } = clusterStats[cid];
          const clusterAvg = sum / count;
          const delta      = poi.qualityScore - clusterAvg;
          const adjustment =
            delta > 0
              ? Math.min(delta * 0.1,   5)
              : Math.max(delta * 0.2, -10);
          adjustedScore = Math.min(100, Math.max(0, poi.qualityScore + adjustment));
        }

        // Convert internal 0–100 score back to 1–5 for display
        const adjustedScore15 = Math.round((adjustedScore / 100) * 5 * 10) / 10;

        return {
          ...poi,
          clusterId:     cid,
          adjustedScore: adjustedScore15,
          tier:          qualityTier(adjustedScore),
        };
      });

      // Sort: high → medium → low, then by adjustedScore desc
      const tierOrder = { high: 0, medium: 1, low: 2 };
      rankedPois.sort((a, b) => {
        if (tierOrder[a.tier] !== tierOrder[b.tier])
          return tierOrder[a.tier] - tierOrder[b.tier];
        return b.adjustedScore - a.adjustedScore;
      });
    }

    // ── Merge: ranked first, new/unvoted at the end ────────────────────────
    const finalPois = [...rankedPois, ...unvotedPois];

    res.json({
      total: finalPois.length,
      pois:  finalPois,
    });
  } catch (err) {
    console.error("Error ranking POIs:", err.message);
    res.status(500).json({ error: "Server error" });
  }
};