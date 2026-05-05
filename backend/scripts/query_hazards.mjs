import pkg from 'pg';
import dotenv from 'dotenv';
import { fileURLToPath } from 'url';
import { dirname, join } from 'path';

const __dirname = dirname(fileURLToPath(import.meta.url));
dotenv.config({ path: join(__dirname, '../.env') });
const { Client } = pkg;

const client = new Client({ connectionString: process.env.DATABASE_URL });
await client.connect();

// Summary by status and type
const summary = await client.query(`
  SELECT status, hazard_type, COUNT(*) as count
  FROM public.hazards
  GROUP BY status, hazard_type
  ORDER BY status, hazard_type
`);

// All hazards with location
const all = await client.query(`
  SELECT
    id,
    hazard_type,
    status,
    ROUND(confidence_score::numeric, 2) as confidence,
    detection_count,
    ROUND(ST_Y(location::geometry)::numeric, 5) as lat,
    ROUND(ST_X(location::geometry)::numeric, 5) as lon
  FROM public.hazards
  ORDER BY status, confidence_score DESC
`);

console.log('=== TOTAL:', all.rows.length, 'hazards ===\n');

console.log('--- Summary by status & type ---');
summary.rows.forEach(r => {
  console.log(`  ${r.status.padEnd(10)} ${r.hazard_type.padEnd(10)} x${r.count}`);
});

console.log('\n--- All hazards ---');
all.rows.forEach(r => {
  console.log(`  [${r.status}] ${r.hazard_type.padEnd(8)} conf=${r.confidence} detections=${r.detection_count}  (${r.lat}, ${r.lon})`);
});

await client.end();
