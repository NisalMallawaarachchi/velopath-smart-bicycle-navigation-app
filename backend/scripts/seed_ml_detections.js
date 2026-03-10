/**
 * Seed script: Populate ml_detections with test data for Malabe area.
 *
 * Test scenarios covered:
 *  1. CLUSTER MERGE — Multiple detections within 10m of each other
 *     (should merge into a single hazard with boosted confidence)
 *  2. NEAR EXISTING HAZARD — Detections close to already-seeded hazards
 *     (should update the existing hazard, not create a new one)
 *  3. ISOLATED NEW — Detections far from any existing hazard
 *     (should create brand-new hazards)
 *  4. MIXED TYPES — Same location but different hazard types
 *     (should create separate hazards per type)
 *
 * Run:  node scripts/seed_ml_detections.js
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
// ~1 meter lat ≈ 0.000009°, ~1 meter lon ≈ 0.0000105° at lat 6.9
function offsetM(lat, lon, metersLat, metersLon) {
  return {
    lat: lat + metersLat * 0.000009,
    lon: lon + metersLon * 0.0000105,
  };
}

// ──────────────────────────────────────────────────────
// Test Data
// ──────────────────────────────────────────────────────
const detections = [
  // ━━━ SCENARIO 1: CLUSTER MERGE (within 10m) ━━━━━━━
  // 5 pothole detections clustered near SLIIT main gate
  // All within ~5m of each other → should merge into 1 hazard
  { lat: 6.91460, lon: 79.97310, type: "pothole", conf: 0.88, device: "device_A" },
  { ...offsetM(6.91460, 79.97310, 2, 3),  type: "pothole", conf: 0.91, device: "device_B" },
  { ...offsetM(6.91460, 79.97310, -3, 1), type: "pothole", conf: 0.85, device: "device_C" },
  { ...offsetM(6.91460, 79.97310, 4, -2), type: "pothole", conf: 0.90, device: "device_A" },
  { ...offsetM(6.91460, 79.97310, 1, 4),  type: "pothole", conf: 0.87, device: "device_D" },

  // 3 bump detections clustered near Malabe market
  // All within ~4m → should merge into 1 hazard
  { lat: 6.91380, lon: 79.97430, type: "bump", conf: 0.86, device: "device_B" },
  { ...offsetM(6.91380, 79.97430, 2, 2),  type: "bump", conf: 0.84, device: "device_C" },
  { ...offsetM(6.91380, 79.97430, -1, 3), type: "bump", conf: 0.89, device: "device_A" },

  // ━━━ SCENARIO 2: NEAR EXISTING HAZARDS ━━━━━━━━━━━━
  // These are within 10m of hazards already in the hazards table
  // (from the previous seed). Should UPDATE existing hazards.

  // Near existing: "New Kandy Rd near Malabe junction" (6.9145, 79.9720)
  { ...offsetM(6.9145, 79.9720, 3, 2),  type: "pothole", conf: 0.92, device: "device_E" },
  { ...offsetM(6.9145, 79.9720, -2, 4), type: "pothole", conf: 0.88, device: "device_F" },

  // Near existing: "Speed bump near Malabe town" (6.9138, 79.9735)
  { ...offsetM(6.9138, 79.9735, 1, -1), type: "bump", conf: 0.85, device: "device_E" },

  // Near existing: "Road leading to SLIIT main gate" (6.9147, 79.9730)
  { ...offsetM(6.9147, 79.9730, -3, 2), type: "pothole", conf: 0.93, device: "device_G" },

  // ━━━ SCENARIO 3: ISOLATED NEW DETECTIONS ━━━━━━━━━━
  // Far from any existing hazard → should create new hazards

  // New pothole near Malabe - Kaduwela bridge (isolated area)
  { lat: 6.9200, lon: 79.9590, type: "pothole", conf: 0.90, device: "device_H" },

  // New bump on residential road
  { lat: 6.9050, lon: 79.9680, type: "bump", conf: 0.82, device: "device_H" },

  // New pothole near Athurugiriya temple road
  { lat: 6.8910, lon: 79.9860, type: "pothole", conf: 0.87, device: "device_I" },

  // New bump near Hokandara junction
  { lat: 6.9010, lon: 79.9570, type: "bump", conf: 0.84, device: "device_J" },

  // ━━━ SCENARIO 4: MIXED TYPES AT SAME LOCATION ━━━━━
  // Same GPS but different type → should create SEPARATE hazards
  // Location: Near Battaramulla flyover
  { lat: 6.9060, lon: 79.9870, type: "pothole", conf: 0.91, device: "device_K" },
  { lat: 6.9060, lon: 79.9870, type: "bump",    conf: 0.86, device: "device_K" },

  // Additional cluster at same location (pothole) to test merge with mixed
  { ...offsetM(6.9060, 79.9870, 2, 1), type: "pothole", conf: 0.89, device: "device_L" },
  { ...offsetM(6.9060, 79.9870, -1, 2), type: "pothole", conf: 0.88, device: "device_M" },
];

// ──────────────────────────────────────────────────────
async function seed() {
  console.log("🧪 Seeding ml_detections for cron job testing...\n");
  const client = await pool.connect();

  try {
    await client.query("BEGIN");

    // Check existing
    const before = await client.query(
      "SELECT COUNT(*) AS n FROM ml_detections WHERE processed = FALSE"
    );
    console.log(`📊 Existing unprocessed detections: ${before.rows[0].n}`);

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

    const after = await client.query(
      "SELECT COUNT(*) AS n FROM ml_detections WHERE processed = FALSE"
    );
    console.log(`✅ Inserted ${inserted} detections`);
    console.log(`📊 Total unprocessed now: ${after.rows[0].n}`);

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

    console.log("\n🔄 The cron job (every 30s) will now pick these up.");
    console.log("   Expected outcomes:");
    console.log("   • Cluster 1 (SLIIT gate): 5 detections → 1 merged pothole hazard");
    console.log("   • Cluster 2 (Malabe market): 3 detections → 1 merged bump hazard");
    console.log("   • Near existing: 4 detections → update 4 existing hazards");
    console.log("   • Isolated: 4 detections → 4 new hazards");
    console.log("   • Mixed types: 2 types at same spot → 2 separate hazards (pothole merges with 2 more)");

  } catch (err) {
    await client.query("ROLLBACK");
    console.error("❌ Seed failed:", err.message);
  } finally {
    client.release();
    await pool.end();
  }
}

seed();
