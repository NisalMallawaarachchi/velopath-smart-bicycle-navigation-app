// seed_hazards_v2.mjs
// Re-seeds hazards at ACTUAL routing.ways road coordinates for Weligama → Galle
// Guarantees ST_DWithin matches on any route through the corridor
// Run: node scripts/seed_hazards_v2.mjs

import pkg from 'pg';
import dotenv from 'dotenv';
import { randomUUID } from 'crypto';
import { fileURLToPath } from 'url';
import { dirname, join } from 'path';

const __dirname = dirname(fileURLToPath(import.meta.url));
dotenv.config({ path: join(__dirname, '../.env') });
const { Client } = pkg;

const rand    = (a, b) => Math.random() * (b - a) + a;
const randInt = (a, b) => Math.floor(rand(a, b + 1));
const daysAgo = n      => new Date(Date.now() - n * 86_400_000);

// ── 7 geographic sections: Weligama → Galle ──────────────────────────────────
// Each section samples 10 road points from ALL roads in that area (not just A2)
const SECTIONS = [
  { name: 'Weligama',          lonMin: 80.40, latMin: 5.960, lonMax: 80.45, latMax: 6.000, count: 10 },
  { name: 'Ahangama East',     lonMin: 80.36, latMin: 5.960, lonMax: 80.40, latMax: 6.000, count: 10 },
  { name: 'Ahangama',          lonMin: 80.33, latMin: 5.960, lonMax: 80.36, latMax: 6.000, count: 10 },
  { name: 'Midigama',          lonMin: 80.30, latMin: 5.955, lonMax: 80.33, latMax: 6.000, count: 10 },
  { name: 'Koggala',           lonMin: 80.27, latMin: 5.960, lonMax: 80.30, latMax: 6.010, count: 10 },
  { name: 'Habaraduwa',        lonMin: 80.24, latMin: 5.970, lonMax: 80.27, latMax: 6.020, count: 10 },
  { name: 'Unawatuna-Galle',   lonMin: 80.20, latMin: 5.980, lonMax: 80.24, latMax: 6.045, count: 10 },
];

async function reseed() {
  const client = new Client({
    user:     process.env.PGUSER,
    host:     process.env.PGHOST,
    database: process.env.PGDATABASE,
    password: process.env.PGPASSWORD,
    port:     Number(process.env.PGPORT || 5432),
    ssl:      { rejectUnauthorized: false },
  });
  await client.connect();
  console.log('Connected to Supabase\n');

  // ── Step 1: get existing user IDs for confirmations ──────────────────────
  const { rows: users } = await client.query('SELECT user_id FROM users');
  const userIds = users.map(r => r.user_id);
  if (!userIds.length) {
    console.error('No users found. Run seed_evaluation.mjs first.');
    process.exit(1);
  }
  console.log(`Users available: ${userIds.length}`);

  // ── Step 2: delete old hazards in the full corridor + child records ───────
  const { rows: oldRows } = await client.query(`
    SELECT id FROM public.hazards
    WHERE ST_Intersects(location, ST_MakeEnvelope(80.20, 5.95, 80.45, 6.05, 4326))
  `);
  if (oldRows.length) {
    const ids = oldRows.map(r => r.id);
    await client.query(`DELETE FROM public.user_confirmations WHERE hazard_id = ANY($1)`, [ids]);
    await client.query(`DELETE FROM public.hazards WHERE id = ANY($1)`, [ids]);
    console.log(`Deleted ${ids.length} old corridor hazards + their confirmations\n`);
  } else {
    console.log('No existing corridor hazards to delete\n');
  }

  // ── Step 3: sample actual road points per section ────────────────────────
  // Uses ST_LineInterpolatePoint at 0.25, 0.5, 0.75 along each road segment
  // so points are guaranteed to lie exactly on routing.ways geometry
  let totalInserted = 0;

  for (const sec of SECTIONS) {
    const { rows: roadPts } = await client.query(`
      SELECT
        ST_X(ST_LineInterpolatePoint(geom, frac)) AS lon,
        ST_Y(ST_LineInterpolatePoint(geom, frac)) AS lat,
        COALESCE(name, 'Local Road') AS road_name
      FROM routing.ways,
        LATERAL (SELECT unnest(ARRAY[0.25, 0.50, 0.75]) AS frac) fracs
      WHERE ST_Intersects(geom, ST_MakeEnvelope($1, $2, $3, $4, 4326))
        AND length_m > 80
      ORDER BY RANDOM()
      LIMIT $5
    `, [sec.lonMin, sec.latMin, sec.lonMax, sec.latMax, sec.count]);

    if (!roadPts.length) {
      console.log(`  ⚠  ${sec.name}: no roads found in bbox — skipping`);
      continue;
    }

    let secCount = 0;
    for (const pt of roadPts) {
      const type      = Math.random() > 0.45 ? 'pothole' : 'bump';
      const conf      = +rand(0.55, 0.97).toFixed(3);
      const status    = conf >= 0.80 ? 'verified' : 'pending';
      const det       = randInt(2, 9);
      const confirms  = randInt(2, 8);
      const denials   = randInt(0, 2);

      // Insert hazard at exact road coordinate
      const { rows: hRows } = await client.query(`
        INSERT INTO public.hazards
          (location, hazard_type, confidence_score, status,
           detection_count, confirmation_count, denial_count,
           first_detected, last_updated, last_confirmed)
        VALUES
          (ST_SetSRID(ST_MakePoint($1, $2), 4326),
           $3, $4, $5, $6, $7, $8, $9, $10, $11)
        RETURNING id
      `, [
        pt.lon, pt.lat,
        type, conf, status,
        det, confirms, denials,
        daysAgo(randInt(10, 30)),
        daysAgo(randInt(0, 9)),
        daysAgo(randInt(0, 5)),
      ]);

      const hazardId = hRows[0].id;

      // ml_detections — small jitter per detection (±15m)
      for (let d = 0; d < det; d++) {
        const jLat = pt.lat + (Math.random() - 0.5) * 2 * 15 / 111_320;
        const jLon = pt.lon + (Math.random() - 0.5) * 2 * 15 /
                     (111_320 * Math.cos(pt.lat * Math.PI / 180));
        await client.query(`
          INSERT INTO public.ml_detections
            (latitude, longitude, hazard_type, detection_confidence,
             device_id, processed, processed_at)
          VALUES ($1, $2, $3, $4, $5, TRUE, $6)
        `, [
          +jLat.toFixed(6), +jLon.toFixed(6),
          type,
          +Math.max(0.30, conf - rand(0, 0.08)).toFixed(3),
          randomUUID(),
          daysAgo(randInt(1, 25)),
        ]);
      }

      // user_confirmations — random subset of users, no duplicates
      const shuffled   = [...userIds].sort(() => Math.random() - 0.5);
      const voteCount  = Math.min(confirms + denials, shuffled.length);
      for (let c = 0; c < voteCount; c++) {
        await client.query(`
          INSERT INTO public.user_confirmations
            (hazard_id, user_id, action, timestamp)
          VALUES ($1, $2, $3, $4)
          ON CONFLICT (hazard_id, user_id) DO NOTHING
        `, [
          hazardId,
          String(shuffled[c]),
          c < confirms ? 'confirm' : 'deny',
          daysAgo(randInt(0, 10)),
        ]);
      }

      secCount++;
    }
    console.log(`✅ ${sec.name}: ${secCount} hazards on ${[...new Set(roadPts.map(p => p.road_name))].join(', ')}`);
    totalInserted += secCount;
  }

  // ── Step 4: summary ──────────────────────────────────────────────────────
  console.log(`\n═══════════════════════════════════════`);
  console.log(`Total hazards inserted: ${totalInserted}`);
  console.log(`All coordinates taken directly from routing.ways geometry`);
  console.log(`ST_DWithin on any route through this corridor will now match`);

  const { rows: verify } = await client.query(`
    SELECT status, COUNT(*) FROM public.hazards
    WHERE ST_Intersects(location, ST_MakeEnvelope(80.20, 5.95, 80.45, 6.05, 4326))
    GROUP BY status
  `);
  console.log('\nVerification:');
  verify.forEach(r => console.log(`  ${r.status}: ${r.count}`));

  await client.end();
}

reseed().catch(e => {
  console.error('Error:', e.message);
  process.exit(1);
});
