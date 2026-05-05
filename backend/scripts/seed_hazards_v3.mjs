// seed_hazards_v3.mjs
// Seeds realistic user-generated hazards across 7 areas.
// All coordinates taken from actual routing.ways geometry via ST_LineInterpolatePoint.
// Run: node scripts/seed_hazards_v3.mjs

import pkg from 'pg';
import dotenv from 'dotenv';
import { fileURLToPath } from 'url';
import { dirname, join } from 'path';

const __dirname = dirname(fileURLToPath(import.meta.url));
dotenv.config({ path: join(__dirname, '../.env') });
const { Client } = pkg;

// ── helpers ──────────────────────────────────────────────────────────────────

const rand      = (a, b) => Math.random() * (b - a) + a;
const randInt   = (a, b) => Math.floor(rand(a, b + 1));
const pick      = arr   => arr[Math.floor(Math.random() * arr.length)];
const daysAgo   = n     => new Date(Date.now() - n * 86_400_000);

function buildConfidence(detections, confirmations) {
  const raw = detections * 0.20 + confirmations * 0.30;
  return Math.min(0.99, parseFloat(raw.toFixed(2)));
}

function getStatus(conf) {
  if (conf >= 0.80) return 'verified';
  if (conf >= 0.50) return 'pending';
  return 'expired';
}

// Realistic detection/confirmation combos that always land in pending or verified
function realisticCounts() {
  // Bias toward verified (40%) and solid pending (60%)
  const roll = Math.random();

  if (roll < 0.20) {
    // clearly verified: 4+ detections + 1-3 confirms
    const d = randInt(4, 8);
    const c = randInt(1, 3);
    return { d, c };
  } else if (roll < 0.45) {
    // verified: many detections
    const d = randInt(5, 12);
    const c = randInt(0, 2);
    return { d, c };
  } else if (roll < 0.75) {
    // solid pending
    const d = randInt(3, 6);
    const c = randInt(0, 1);
    return { d, c };
  } else {
    // just made it to pending
    const d = randInt(2, 4);
    const c = 0;
    return { d, c };
  }
}

// ── area definitions ─────────────────────────────────────────────────────────

const AREAS = [
  {
    name: 'Weligama rural + town',
    lonMin: 80.38, latMin: 5.95, lonMax: 80.47, latMax: 6.02,
    count: 25,
  },
  {
    name: 'Ahangama–Midigama rural',
    lonMin: 80.27, latMin: 5.95, lonMax: 80.42, latMax: 6.01,
    count: 20,
  },
  {
    name: 'Koggala–Habaraduwa rural',
    lonMin: 80.20, latMin: 5.96, lonMax: 80.30, latMax: 6.03,
    count: 20,
  },
  {
    name: 'Galle outskirts rural',
    lonMin: 80.19, latMin: 6.00, lonMax: 80.25, latMax: 6.06,
    count: 15,
  },
  {
    name: 'Mathugama + rural',
    lonMin: 80.07, latMin: 6.46, lonMax: 80.18, latMax: 6.58,
    count: 25,
  },
  {
    name: 'Ampegama–Baddegama',
    lonMin: 80.12, latMin: 6.13, lonMax: 80.22, latMax: 6.23,
    count: 25,
  },
  {
    name: 'Malabe + rural',
    lonMin: 79.94, latMin: 6.87, lonMax: 80.03, latMax: 6.95,
    count: 25,
  },
];

// ── main ─────────────────────────────────────────────────────────────────────

const client = new Client({ connectionString: process.env.DATABASE_URL });
await client.connect();
console.log('Connected to database\n');

let grandTotal = 0;

for (const area of AREAS) {
  const { name, lonMin, latMin, lonMax, latMax, count } = area;

  // Pull real road points from routing.ways using ST_LineInterpolatePoint
  // Sample at 0.1, 0.2, ..., 0.9 fractions along each way — gives dense coverage
  // including rural roads (not just A2)
  const pointsRes = await client.query(`
    SELECT
      ROUND(ST_X(ST_LineInterpolatePoint(geom, frac))::numeric, 6) AS lon,
      ROUND(ST_Y(ST_LineInterpolatePoint(geom, frac))::numeric, 6) AS lat,
      COALESCE(name, 'Local Road') AS road_name
    FROM routing.ways,
      LATERAL (SELECT unnest(ARRAY[0.1,0.2,0.3,0.4,0.5,0.6,0.7,0.8,0.9]) AS frac) f
    WHERE ST_Intersects(
        geom,
        ST_MakeEnvelope($1, $2, $3, $4, 4326)
      )
      AND length_m > 40
    ORDER BY RANDOM()
    LIMIT $5
  `, [lonMin, latMin, lonMax, latMax, count * 3]); // fetch 3× then dedupe

  if (pointsRes.rows.length === 0) {
    console.log(`  ⚠  ${name}: no routing.ways found — skipping`);
    continue;
  }

  // Deduplicate points closer than ~30m
  const used = [];
  const candidates = pointsRes.rows;

  function tooClose(lat, lon) {
    const R = 111_320;
    for (const u of used) {
      const dlat = (lat - u.lat) * R;
      const dlon = (lon - u.lon) * R * Math.cos(lat * Math.PI / 180);
      if (Math.sqrt(dlat * dlat + dlon * dlon) < 30) return true;
    }
    return false;
  }

  const points = [];
  for (const row of candidates) {
    if (points.length >= count) break;
    const lat = parseFloat(row.lat);
    const lon = parseFloat(row.lon);
    if (!tooClose(lat, lon)) {
      points.push({ lat, lon, road: row.road_name });
      used.push({ lat, lon });
    }
  }

  const roadNames = [...new Set(points.map(p => p.road))].join(', ');
  let inserted = 0;

  for (const pt of points) {
    const { d: detections, c: confirmations } = realisticCounts();
    const conf    = buildConfidence(detections, confirmations);
    const status  = getStatus(conf);

    // Skip anything that decayed to expired (shouldn't happen with our combos, but safety check)
    if (status === 'expired') continue;

    const type      = Math.random() < 0.60 ? 'pothole' : 'bump';
    const decayRate = type === 'pothole' ? 0.030 : 0.008;

    // Temporal realism: first detected 3–45 days ago, last updated 0–7 days ago
    const firstDetected = daysAgo(randInt(3, 45));
    const lastUpdated   = daysAgo(randInt(0, 7));
    const lastConfirmed = confirmations > 0 ? daysAgo(randInt(0, 14)) : null;
    const decayAccel    = lastConfirmed === null && rand(0, 1) < 0.3; // 30% chance if no confirms

    await client.query(`
      INSERT INTO public.hazards (
        location, hazard_type, confidence_score, status,
        detection_count, confirmation_count,
        first_detected, last_updated, last_confirmed,
        decay_rate, decay_accelerated
      ) VALUES (
        ST_SetSRID(ST_MakePoint($1, $2), 4326),
        $3, $4, $5,
        $6, $7,
        $8, $9, $10,
        $11, $12
      )
    `, [
      pt.lon, pt.lat,
      type, conf, status,
      detections, confirmations,
      firstDetected, lastUpdated, lastConfirmed,
      decayRate, decayAccel,
    ]);

    inserted++;
  }

  grandTotal += inserted;
  console.log(`✅ ${name}: ${inserted} hazards on: ${roadNames}`);
}

// Final tally
const tally = await client.query(`
  SELECT status, COUNT(*) as n FROM public.hazards
  WHERE status IN ('pending','verified')
  GROUP BY status ORDER BY status
`);

console.log('\n══════════════════════════════════════════');
console.log(`New hazards inserted this run : ${grandTotal}`);
console.log('Current visible hazards in DB :');
tally.rows.forEach(r => console.log(`  ${r.status.padEnd(10)}: ${r.n}`));
console.log('══════════════════════════════════════════');

await client.end();
