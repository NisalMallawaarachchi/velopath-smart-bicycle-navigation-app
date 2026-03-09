/**
 * Seed script: Populate ml_detections with test data for Ampegama, Sri Lanka.
 * Test Area: Ampegama & surrounding roads
 *
 * Test scenarios covered:
 *  1. CLUSTER MERGE — Multiple detections within 10m of each other
 *  2. ISOLATED NEW — Detections far from any existing hazard
 *  3. MIXED TYPES — Same location but different hazard types
 *
 * Run:  node scripts/seed_ampegama.js
 */

import dotenv from "dotenv";
import pkg from "pg";

dotenv.config();

const { Pool } = pkg;

const isSupabase =
  (process.env.PGHOST || "").includes("supabase.com") ||
  (process.env.PGHOST || "").includes("supabase.co");

const pool = new Pool({
  user: process.env.PGUSER,
  host: process.env.PGHOST,
  database: process.env.PGDATABASE,
  password: process.env.PGPASSWORD,
  port: Number(process.env.PGPORT || 5432),
  ssl: isSupabase ? { rejectUnauthorized: false } : false,
});

// Helper: offset lat/lon by approx meters
// ~1 meter lat ≈ 0.000009°, ~1 meter lon ≈ 0.0000105° at lat 6.1
function offsetM(lat, lon, metersLat, metersLon) {
  return {
    lat: lat + metersLat * 0.000009,
    lon: lon + metersLon * 0.0000105,
  };
}

// ──────────────────────────────────────────────────────
// Test Data (Ampegama, Southern Province, Sri Lanka)
// Base coordinates: Ampegama central area (~6.1437, 80.1265)
// ──────────────────────────────────────────────────────
const detections = [
  
  { lat: 6.14150, lon: 80.12500, type: 'pothole', conf: 0.87, device: 'device_A' },
  { lat: 6.14153, lon: 80.12497, type: 'pothole', conf: 0.91, device: 'device_B' },
  { lat: 6.14147, lon: 80.12503, type: 'pothole', conf: 0.84, device: 'device_C' },
  { lat: 6.14152, lon: 80.12504, type: 'pothole', conf: 0.78, device: 'device_A' },
  { lat: 6.14148, lon: 80.12496, type: 'pothole', conf: 0.93, device: 'device_B' },
  { lat: 6.14320, lon: 80.12680, type: 'bump', conf: 0.82, device: 'device_C' },
  { lat: 6.14324, lon: 80.12683, type: 'bump', conf: 0.89, device: 'device_A' },
  { lat: 6.14317, lon: 80.12677, type: 'bump', conf: 0.75, device: 'device_B' },
  { lat: 6.14322, lon: 80.12675, type: 'bump', conf: 0.88, device: 'device_C' },
  { lat: 6.14318, lon: 80.12684, type: 'bump', conf: 0.71, device: 'device_A' },
  { lat: 6.14318, lon: 80.12682, type: 'bump', conf: 0.95, device: 'device_B' },
  { lat: 6.13980, lon: 80.12340, type: 'pothole', conf: 0.86, device: 'device_C' },
  { lat: 6.13984, lon: 80.12344, type: 'pothole', conf: 0.79, device: 'device_A' },
  { lat: 6.13977, lon: 80.12337, type: 'pothole', conf: 0.92, device: 'device_B' },
  { lat: 6.13982, lon: 80.12336, type: 'pothole', conf: 0.83, device: 'device_C' },
  { lat: 6.13979, lon: 80.12343, type: 'pothole', conf: 0.77, device: 'device_A' },
  { lat: 6.14540, lon: 80.12150, type: 'smooth', conf: 0.90, device: 'device_B' },
  { lat: 6.14544, lon: 80.12153, type: 'smooth', conf: 0.85, device: 'device_C' },
  { lat: 6.14537, lon: 80.12147, type: 'smooth', conf: 0.73, device: 'device_A' },
  { lat: 6.14542, lon: 80.12146, type: 'smooth', conf: 0.88, device: 'device_B' },
  { lat: 6.14538, lon: 80.12154, type: 'smooth', conf: 0.96, device: 'device_C' },
  { lat: 6.14700, lon: 80.12890, type: 'pothole', conf: 0.81, device: 'device_A' },
  { lat: 6.14704, lon: 80.12893, type: 'pothole', conf: 0.87, device: 'device_B' },
  { lat: 6.14697, lon: 80.12887, type: 'pothole', conf: 0.94, device: 'device_C' },
  { lat: 6.14702, lon: 80.12886, type: 'pothole', conf: 0.76, device: 'device_A' },
  { lat: 6.14698, lon: 80.12894, type: 'pothole', conf: 0.89, device: 'device_B' },
  { lat: 6.14698, lon: 80.12891, type: 'pothole', conf: 0.82, device: 'device_C' },
  { lat: 6.13820, lon: 80.12760, type: 'bump', conf: 0.74, device: 'device_A' },
  { lat: 6.13824, lon: 80.12763, type: 'bump', conf: 0.91, device: 'device_B' },
  { lat: 6.13817, lon: 80.12757, type: 'bump', conf: 0.86, device: 'device_C' },
  { lat: 6.13822, lon: 80.12756, type: 'bump', conf: 0.79, device: 'device_A' },
  { lat: 6.13818, lon: 80.12764, type: 'bump', conf: 0.93, device: 'device_B' },
  { lat: 6.14060, lon: 80.12020, type: 'pothole', conf: 0.88, device: 'device_C' },
  { lat: 6.14064, lon: 80.12023, type: 'pothole', conf: 0.72, device: 'device_A' },
  { lat: 6.14057, lon: 80.12017, type: 'pothole', conf: 0.95, device: 'device_B' },
  { lat: 6.14062, lon: 80.12016, type: 'pothole', conf: 0.84, device: 'device_C' },
  { lat: 6.14058, lon: 80.12024, type: 'pothole', conf: 0.78, device: 'device_A' },
  { lat: 6.14058, lon: 80.12021, type: 'pothole', conf: 0.90, device: 'device_B' },
  { lat: 6.14450, lon: 80.13100, type: 'smooth', conf: 0.83, device: 'device_C' },
  { lat: 6.14454, lon: 80.13103, type: 'smooth', conf: 0.77, device: 'device_A' },
  { lat: 6.14447, lon: 80.13097, type: 'smooth', conf: 0.92, device: 'device_B' },
  { lat: 6.14452, lon: 80.13096, type: 'smooth', conf: 0.86, device: 'device_C' },
  { lat: 6.14448, lon: 80.13104, type: 'smooth', conf: 0.70, device: 'device_A' },
  { lat: 6.13700, lon: 80.12550, type: 'bump', conf: 0.89, device: 'device_B' },
  { lat: 6.13704, lon: 80.12553, type: 'bump', conf: 0.81, device: 'device_C' },
  { lat: 6.13697, lon: 80.12547, type: 'bump', conf: 0.76, device: 'device_A' },
  { lat: 6.13702, lon: 80.12546, type: 'bump', conf: 0.94, device: 'device_B' },
  { lat: 6.13698, lon: 80.12554, type: 'bump', conf: 0.87, device: 'device_C' },
  { lat: 6.14870, lon: 80.12430, type: 'pothole', conf: 0.80, device: 'device_A' },
  { lat: 6.14874, lon: 80.12433, type: 'pothole', conf: 0.91, device: 'device_B' },
  { lat: 6.14867, lon: 80.12427, type: 'pothole', conf: 0.85, device: 'device_C' },
  { lat: 6.14872, lon: 80.12426, type: 'pothole', conf: 0.73, device: 'device_A' },
  { lat: 6.14868, lon: 80.12434, type: 'pothole', conf: 0.97, device: 'device_B' },
  { lat: 6.14200, lon: 80.12200, type: 'smooth', conf: 0.88, device: 'device_C' },
  { lat: 6.14204, lon: 80.12203, type: 'smooth', conf: 0.82, device: 'device_A' },
  { lat: 6.14197, lon: 80.12197, type: 'smooth', conf: 0.76, device: 'device_B' },
  { lat: 6.14202, lon: 80.12196, type: 'smooth', conf: 0.93, device: 'device_C' },
  { lat: 6.14198, lon: 80.12204, type: 'smooth', conf: 0.79, device: 'device_A' },
  { lat: 6.14198, lon: 80.12201, type: 'smooth', conf: 0.85, device: 'device_B' },
  { lat: 6.13600, lon: 80.12900, type: 'bump', conf: 0.91, device: 'device_C' },
  { lat: 6.13604, lon: 80.12903, type: 'bump', conf: 0.74, device: 'device_A' },
  { lat: 6.13597, lon: 80.12897, type: 'bump', conf: 0.87, device: 'device_B' },
  { lat: 6.13602, lon: 80.12896, type: 'bump', conf: 0.83, device: 'device_C' },
  { lat: 6.13598, lon: 80.12904, type: 'bump', conf: 0.70, device: 'device_A' },
  { lat: 6.14980, lon: 80.12700, type: 'pothole', conf: 0.94, device: 'device_B' },
  { lat: 6.14984, lon: 80.12703, type: 'pothole', conf: 0.78, device: 'device_C' },
  { lat: 6.14977, lon: 80.12697, type: 'pothole', conf: 0.89, device: 'device_A' },
  { lat: 6.14982, lon: 80.12696, type: 'pothole', conf: 0.84, device: 'device_B' },
  { lat: 6.14978, lon: 80.12704, type: 'pothole', conf: 0.72, device: 'device_C' },
  { lat: 6.14978, lon: 80.12701, type: 'pothole', conf: 0.96, device: 'device_A' },
  { lat: 6.13500, lon: 80.12200, type: 'smooth', conf: 0.81, device: 'device_B' },
  { lat: 6.13504, lon: 80.12203, type: 'smooth', conf: 0.90, device: 'device_C' },
  { lat: 6.13497, lon: 80.12197, type: 'smooth', conf: 0.75, device: 'device_A' },
  { lat: 6.13502, lon: 80.12196, type: 'smooth', conf: 0.86, device: 'device_B' },
  { lat: 6.13498, lon: 80.12204, type: 'smooth', conf: 0.92, device: 'device_C' },
  { lat: 6.14600, lon: 80.13300, type: 'pothole', conf: 0.77, device: 'device_A' },
  { lat: 6.14604, lon: 80.13303, type: 'pothole', conf: 0.88, device: 'device_B' },
  { lat: 6.14597, lon: 80.13297, type: 'pothole', conf: 0.83, device: 'device_C' },
  { lat: 6.14602, lon: 80.13296, type: 'pothole', conf: 0.71, device: 'device_A' },
  { lat: 6.14598, lon: 80.13304, type: 'pothole', conf: 0.95, device: 'device_B' },
  { lat: 6.13380, lon: 80.12650, type: 'bump', conf: 0.84, device: 'device_C' },
  { lat: 6.13384, lon: 80.12653, type: 'bump', conf: 0.79, device: 'device_A' },
  { lat: 6.13377, lon: 80.12647, type: 'bump', conf: 0.93, device: 'device_B' },
  { lat: 6.13382, lon: 80.12646, type: 'bump', conf: 0.87, device: 'device_C' },
  { lat: 6.13378, lon: 80.12654, type: 'bump', conf: 0.76, device: 'device_A' },
  { lat: 6.13378, lon: 80.12651, type: 'bump', conf: 0.91, device: 'device_B' },
  { lat: 6.14750, lon: 80.11950, type: 'smooth', conf: 0.82, device: 'device_C' },
  { lat: 6.14754, lon: 80.11953, type: 'smooth', conf: 0.96, device: 'device_A' },
  { lat: 6.14747, lon: 80.11947, type: 'smooth', conf: 0.74, device: 'device_B' },
  { lat: 6.14752, lon: 80.11946, type: 'smooth', conf: 0.89, device: 'device_C' },
  { lat: 6.14748, lon: 80.11954, type: 'smooth', conf: 0.81, device: 'device_A' },
  { lat: 6.14248, lon: 80.12248, type: 'pothole', conf: 0.85, device: 'device_B' },
  { lat: 6.14250, lon: 80.12250, type: 'bump', conf: 0.79, device: 'device_C' },
  { lat: 6.14246, lon: 80.12246, type: 'pothole', conf: 0.92, device: 'device_A' },
  { lat: 6.14252, lon: 80.12252, type: 'bump', conf: 0.88, device: 'device_B' },
  { lat: 6.14249, lon: 80.12251, type: 'pothole', conf: 0.76, device: 'device_C' },
  { lat: 6.14251, lon: 80.12249, type: 'bump', conf: 0.94, device: 'device_A' },
  { lat: 6.13850, lon: 80.12150, type: 'pothole', conf: 0.83, device: 'device_B' },
  { lat: 6.13852, lon: 80.12152, type: 'bump', conf: 0.77, device: 'device_C' },
  { lat: 6.13848, lon: 80.12148, type: 'pothole', conf: 0.91, device: 'device_A' },
  { lat: 6.13854, lon: 80.12154, type: 'bump', conf: 0.86, device: 'device_B' },
  { lat: 6.13851, lon: 80.12153, type: 'pothole', conf: 0.73, device: 'device_C' },
  { lat: 6.13853, lon: 80.12151, type: 'bump', conf: 0.95, device: 'device_A' },
  { lat: 6.14480, lon: 80.12780, type: 'pothole', conf: 0.80, device: 'device_B' },
  { lat: 6.14482, lon: 80.12782, type: 'bump', conf: 0.90, device: 'device_C' },
  { lat: 6.14478, lon: 80.12778, type: 'pothole', conf: 0.84, device: 'device_A' },
  { lat: 6.14484, lon: 80.12784, type: 'bump', conf: 0.78, device: 'device_B' },
  { lat: 6.14481, lon: 80.12783, type: 'pothole', conf: 0.93, device: 'device_C' },
  { lat: 6.14483, lon: 80.12781, type: 'bump', conf: 0.87, device: 'device_A' },
  { lat: 6.14030, lon: 80.12580, type: 'pothole', conf: 0.72, device: 'device_B' },
  { lat: 6.14032, lon: 80.12582, type: 'bump', conf: 0.88, device: 'device_C' },
  { lat: 6.14028, lon: 80.12578, type: 'pothole', conf: 0.96, device: 'device_A' },
  { lat: 6.14034, lon: 80.12584, type: 'bump', conf: 0.81, device: 'device_B' },
  { lat: 6.14031, lon: 80.12583, type: 'pothole', conf: 0.75, device: 'device_C' },
  { lat: 6.14033, lon: 80.12581, type: 'bump', conf: 0.92, device: 'device_A' },
  { lat: 6.14900, lon: 80.13500, type: 'pothole', conf: 0.88, device: 'device_B' },
  { lat: 6.13200, lon: 80.12100, type: 'bump', conf: 0.79, device: 'device_C' },
  { lat: 6.15100, lon: 80.12050, type: 'smooth', conf: 0.91, device: 'device_A' },
  { lat: 6.13050, lon: 80.13200, type: 'pothole', conf: 0.85, device: 'device_B' },
  { lat: 6.15300, lon: 80.13100, type: 'bump', conf: 0.74, device: 'device_C' },
  { lat: 6.14100, lon: 80.11600, type: 'smooth', conf: 0.93, device: 'device_A' },
  { lat: 6.13400, lon: 80.11800, type: 'pothole', conf: 0.82, device: 'device_B' },
  { lat: 6.15200, lon: 80.12600, type: 'bump', conf: 0.76, device: 'device_C' },
  { lat: 6.13150, lon: 80.12800, type: 'smooth', conf: 0.89, device: 'device_A' },
  { lat: 6.14800, lon: 80.11700, type: 'pothole', conf: 0.95, device: 'device_B' },
  { lat: 6.13700, lon: 80.13400, type: 'bump', conf: 0.71, device: 'device_C' },
  { lat: 6.15000, lon: 80.11900, type: 'smooth', conf: 0.84, device: 'device_A' },
  { lat: 6.13300, lon: 80.13600, type: 'pothole', conf: 0.90, device: 'device_B' },
  { lat: 6.14950, lon: 80.13800, type: 'bump', conf: 0.77, device: 'device_C' },
  { lat: 6.13100, lon: 80.12450, type: 'smooth', conf: 0.86, device: 'device_A' },
  { lat: 6.15400, lon: 80.12850, type: 'pothole', conf: 0.92, device: 'device_B' },
  { lat: 6.13550, lon: 80.11650, type: 'bump', conf: 0.80, device: 'device_C' },
  { lat: 6.14650, lon: 80.13700, type: 'smooth', conf: 0.73, device: 'device_A' },
  { lat: 6.13250, lon: 80.11950, type: 'pothole', conf: 0.97, device: 'device_B' },
  { lat: 6.15150, lon: 80.13350, type: 'bump', conf: 0.83, device: 'device_C' }

];

async function seed() {
  console.log("🧪 Seeding ml_detections for Ampegama...\n");
  const client = await pool.connect();

  try {
    await client.query("BEGIN");

    let inserted = 0;

    for (const d of detections) {
      await client.query(
        `INSERT INTO ml_detections (
           latitude, longitude, hazard_type, detection_confidence,
           device_id, processed
         ) VALUES ($1, $2, $3, $4, $5, FALSE)`,
        [d.lat, d.lon, d.type, d.conf, d.device]
      );
      inserted++;
    }

    await client.query("COMMIT");

    console.log(`✅ Inserted ${inserted} detections in Ampegama.`);
    
    // Summary
    const summary = await client.query(`
      SELECT hazard_type, COUNT(*) AS n
      FROM ml_detections
      WHERE processed = FALSE
      GROUP BY hazard_type
      ORDER BY n DESC
    `);
    console.log("\n📋 Unprocessed detection breakdown:");
    summary.rows.forEach((r) => console.log(`   ${r.hazard_type}: ${r.n}`));

    console.log("\n🔄 The detection processor cron job will pick these up and map them into actual Hazards.");
    
  } catch (err) {
    await client.query("ROLLBACK");
    console.error("❌ Seed failed:", err.message);
  } finally {
    client.release();
    await pool.end();
  }
}

seed();
