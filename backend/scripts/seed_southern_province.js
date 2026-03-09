/**
 * Seed script: Populate ml_detections with test data for Southern Province (Sri Lanka).
 * Test Area: Galle & surrounding roads
 *
 * Test scenarios covered:
 *  1. CLUSTER MERGE — Multiple detections within 10m of each other
 *  2. ISOLATED NEW — Detections far from any existing hazard
 *  3. MIXED TYPES — Same location but different hazard types
 *
 * Run:  node scripts/seed_southern_province.js
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
// ~1 meter lat ≈ 0.000009°, ~1 meter lon ≈ 0.0000105° at lat 6.0
function offsetM(lat, lon, metersLat, metersLon) {
  return {
    lat: lat + metersLat * 0.000009,
    lon: lon + metersLon * 0.0000105,
  };
}

// ──────────────────────────────────────────────────────
// Test Data (Southern Province - Galle Area)
// Base coordinates: Galle Bus Stand (~6.0333, 80.2144)
// ──────────────────────────────────────────────────────
const detections = [
  // ━━━ SCENARIO 1: CLUSTER MERGE (within 10m) ━━━━━━━
  // 5 pothole detections clustered near Galle Bus Stand
  { lat: 6.03330, lon: 80.21440, type: "pothole", conf: 0.88, device: "device_A" },
  { ...offsetM(6.03330, 80.21440, 2, 3),  type: "pothole", conf: 0.91, device: "device_B" },
  { ...offsetM(6.03330, 80.21440, -3, 1), type: "pothole", conf: 0.85, device: "device_C" },
  { ...offsetM(6.03330, 80.21440, 4, -2), type: "pothole", conf: 0.90, device: "device_A" },
  { ...offsetM(6.03330, 80.21440, 1, 4),  type: "pothole", conf: 0.87, device: "device_D" },

  // 3 bump detections clustered near Galle Fort entrance
  { lat: 6.02600, lon: 80.21700, type: "bump", conf: 0.86, device: "device_B" },
  { ...offsetM(6.02600, 80.21700, 2, 2),  type: "bump", conf: 0.84, device: "device_C" },
  { ...offsetM(6.02600, 80.21700, -1, 3), type: "bump", conf: 0.89, device: "device_A" },

  // ━━━ SCENARIO 2: ISOLATED NEW DETECTIONS ━━━━━━━━━━
  // Far from other hazards
  
  // New pothole near Dewata Beach
  { lat: 6.01800, lon: 80.24000, type: "pothole", conf: 0.90, device: "device_H" },

  // New bump on a residential road in Karapitiya
  { lat: 6.06300, lon: 80.23600, type: "bump", conf: 0.82, device: "device_H" },

  // New rough road section near Unawatuna
  { lat: 6.01200, lon: 80.24500, type: "rough", conf: 0.87, device: "device_I" },

  // ━━━ SCENARIO 3: MIXED TYPES AT SAME LOCATION ━━━━━
  // Same GPS but different type -> should create SEPARATE hazards
  // Location: Galle-Matara Road Junction
  { lat: 6.04000, lon: 80.22000, type: "pothole", conf: 0.91, device: "device_K" },
  { lat: 6.04000, lon: 80.22000, type: "bump",    conf: 0.86, device: "device_K" },

  // Additional cluster at same location (pothole) to test merge with mixed
  { ...offsetM(6.04000, 80.22000, 2, 1), type: "pothole", conf: 0.89, device: "device_L" },
  { ...offsetM(6.04000, 80.22000, -1, 2), type: "pothole", conf: 0.88, device: "device_M" },
];

async function seed() {
  console.log("🧪 Seeding ml_detections for Southern Province (Galle)...\n");
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

    console.log(`✅ Inserted ${inserted} detections in Southern Province.`);
    
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
