// seed_hazards_malabe.mjs
// Seeds active hazards in Malabe/Kotte using coordinates from real rides
// (expired hazards already exist at these locations — proven road points).

import pkg from 'pg';
import dotenv from 'dotenv';
import { fileURLToPath } from 'url';
import { dirname, join } from 'path';

const __dirname = dirname(fileURLToPath(import.meta.url));
dotenv.config({ path: join(__dirname, '../.env') });
const { Client } = pkg;

const randInt = (a, b) => Math.floor(Math.random() * (b - a + 1)) + a;
const daysAgo = n => new Date(Date.now() - n * 86_400_000);

function buildConfidence(d, c) {
  return Math.min(0.99, parseFloat((d * 0.20 + c * 0.30).toFixed(2)));
}
function getStatus(conf) {
  if (conf >= 0.80) return 'verified';
  if (conf >= 0.50) return 'pending';
  return 'expired';
}
function realisticCounts() {
  const roll = Math.random();
  if (roll < 0.20) return { d: randInt(4, 8),  c: randInt(1, 3) };
  if (roll < 0.45) return { d: randInt(5, 12), c: randInt(0, 2) };
  if (roll < 0.75) return { d: randInt(3, 6),  c: randInt(0, 1) };
  return             { d: randInt(2, 4),  c: 0 };
}

const client = new Client({ connectionString: process.env.DATABASE_URL });
await client.connect();
console.log('Connected\n');

// Pull real road coordinates from expired hazards in Malabe/Kotte area
// These came from actual bike rides — guaranteed to be on real roads
const existing = await client.query(`
  SELECT lon, lat, hazard_type FROM (
    SELECT DISTINCT
      ROUND(ST_X(location::geometry)::numeric, 5) AS lon,
      ROUND(ST_Y(location::geometry)::numeric, 5) AS lat,
      hazard_type
    FROM public.hazards
    WHERE status = 'expired'
      AND ST_Intersects(
        location,
        ST_MakeEnvelope(79.84, 6.85, 80.04, 6.95, 4326)
      )
  ) sub
  ORDER BY RANDOM()
  LIMIT 25
`);

if (existing.rows.length === 0) {
  console.log('No expired hazard coordinates found in Malabe/Kotte area');
  await client.end();
  process.exit(0);
}

let inserted = 0;
for (const row of existing.rows) {
  const { d: detections, c: confirmations } = realisticCounts();
  const conf   = buildConfidence(detections, confirmations);
  const status = getStatus(conf);
  if (status === 'expired') continue;

  // Use existing hazard_type or randomise
  const type      = Math.random() < 0.6 ? 'pothole' : 'bump';
  const decayRate = type === 'pothole' ? 0.030 : 0.008;

  const firstDetected = daysAgo(randInt(3, 45));
  const lastUpdated   = daysAgo(randInt(0, 7));
  const lastConfirmed = confirmations > 0 ? daysAgo(randInt(0, 14)) : null;
  const decayAccel    = lastConfirmed === null && Math.random() < 0.3;

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
    parseFloat(row.lon), parseFloat(row.lat),
    type, conf, status,
    detections, confirmations,
    firstDetected, lastUpdated, lastConfirmed,
    decayRate, decayAccel,
  ]);
  inserted++;
}

const tally = await client.query(`
  SELECT status, COUNT(*) as n FROM public.hazards
  WHERE status IN ('pending','verified')
  GROUP BY status ORDER BY status
`);

console.log(`✅ Malabe/Kotte: ${inserted} hazards inserted (from real ride coordinates)`);
console.log('\n══════════════════════════════════════════');
console.log('Total visible hazards in DB now:');
tally.rows.forEach(r => console.log(`  ${r.status.padEnd(10)}: ${r.n}`));
console.log('══════════════════════════════════════════');

await client.end();
