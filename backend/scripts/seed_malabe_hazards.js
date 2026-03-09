/**
 * Seed script: Populate hazards table with realistic data for Malabe area.
 *
 * Roads covered (SLIIT / Malabe):
 *  - New Kandy Road (main highway through Malabe)
 *  - SLIIT campus vicinity
 *  - Athurugiriya - Kaduwela Road
 *  - Battaramulla - Malabe connector roads
 *  - Kaduwela interchange area
 *
 * Run:  node scripts/seed_malabe_hazards.js
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

// ────────────────────────────────────────────────────
// Malabe area hazard data — realistic GPS coordinates
// ────────────────────────────────────────────────────
const hazards = [
  // ── New Kandy Road (passing through Malabe) ───────
  { lat: 6.9145, lon: 79.9720, type: "pothole",   conf: 0.92, count: 5,  note: "New Kandy Rd near Malabe junction" },
  { lat: 6.9138, lon: 79.9735, type: "bump",      conf: 0.87, count: 3,  note: "Speed bump near Malabe town" },
  { lat: 6.9130, lon: 79.9752, type: "pothole",   conf: 0.89, count: 4,  note: "New Kandy Rd near SLIIT turnoff" },
  { lat: 6.9124, lon: 79.9768, type: "bump",      conf: 0.85, count: 2,  note: "Rough patch - road resurfacing" },
  { lat: 6.9158, lon: 79.9695, type: "pothole",   conf: 0.91, count: 6,  note: "New Kandy Rd near Kaduwela side" },
  { lat: 6.9165, lon: 79.9680, type: "bump",      conf: 0.88, count: 4,  note: "New Kandy Rd speed bump" },
  { lat: 6.9118, lon: 79.9785, type: "pothole",   conf: 0.90, count: 3,  note: "New Kandy Rd approaching Battaramulla" },
  { lat: 6.9105, lon: 79.9805, type: "pothole",   conf: 0.83, count: 2,  note: "Rough surface near Pittipana" },

  // ── SLIIT Campus Vicinity ─────────────────────────
  { lat: 6.9147, lon: 79.9730, type: "pothole",   conf: 0.94, count: 7,  note: "Road leading to SLIIT main gate" },
  { lat: 6.9152, lon: 79.9725, type: "bump",      conf: 0.86, count: 2,  note: "Speed bump at SLIIT entrance" },
  { lat: 6.9155, lon: 79.9718, type: "pothole",   conf: 0.88, count: 3,  note: "Side road near SLIIT" },
  { lat: 6.9160, lon: 79.9712, type: "bump",      conf: 0.81, count: 1,  note: "Unpaved section near SLIIT back gate" },
  { lat: 6.9143, lon: 79.9738, type: "bump",      conf: 0.90, count: 5,  note: "Road bump near SLIIT hostel area" },

  // ── Malabe Town Center ────────────────────────────
  { lat: 6.9135, lon: 79.9745, type: "pothole",   conf: 0.93, count: 8,  note: "Malabe town center main road" },
  { lat: 6.9128, lon: 79.9755, type: "bump",      conf: 0.85, count: 3,  note: "Bus stop area speed bump" },
  { lat: 6.9140, lon: 79.9742, type: "pothole",   conf: 0.91, count: 4,  note: "Near Malabe market" },

  // ── Athurugiriya Road ─────────────────────────────
  { lat: 6.8942, lon: 79.9820, type: "pothole",   conf: 0.90, count: 4,  note: "Athurugiriya Rd main stretch" },
  { lat: 6.8935, lon: 79.9835, type: "bump",      conf: 0.84, count: 2,  note: "Rough patch Athurugiriya" },
  { lat: 6.8950, lon: 79.9810, type: "bump",      conf: 0.87, count: 3,  note: "Speed bump near Athurugiriya junction" },
  { lat: 6.8960, lon: 79.9795, type: "pothole",   conf: 0.92, count: 5,  note: "Athurugiriya toward Malabe" },
  { lat: 6.8975, lon: 79.9775, type: "pothole",   conf: 0.89, count: 3,  note: "Connecting road to New Kandy Rd" },

  // ── Kaduwela / Expressway Interchange Area ────────
  { lat: 6.9195, lon: 79.9650, type: "pothole",   conf: 0.91, count: 6,  note: "Near Kaduwela interchange" },
  { lat: 6.9202, lon: 79.9640, type: "bump",      conf: 0.86, count: 2,  note: "Speed bump Kaduwela town" },
  { lat: 6.9210, lon: 79.9625, type: "pothole",   conf: 0.82, count: 1,  note: "Rough road Kaduwela industrial area" },
  { lat: 6.9188, lon: 79.9660, type: "pothole",   conf: 0.88, count: 4,  note: "Kaduwela road to Malabe" },

  // ── Battaramulla Side ─────────────────────────────
  { lat: 6.9085, lon: 79.9830, type: "pothole",   conf: 0.90, count: 5,  note: "Battaramulla main road" },
  { lat: 6.9075, lon: 79.9845, type: "bump",      conf: 0.85, count: 3,  note: "Speed bump Battaramulla" },
  { lat: 6.9090, lon: 79.9818, type: "bump",      conf: 0.83, count: 2,  note: "Rough patch near junction" },
  { lat: 6.9068, lon: 79.9855, type: "pothole",   conf: 0.87, count: 3,  note: "Battaramulla connecting road" },

  // ── Hokandara Road ────────────────────────────────
  { lat: 6.9020, lon: 79.9600, type: "pothole",   conf: 0.91, count: 4,  note: "Hokandara main road" },
  { lat: 6.9030, lon: 79.9615, type: "bump",      conf: 0.86, count: 2,  note: "Speed bump Hokandara" },
  { lat: 6.9038, lon: 79.9628, type: "pothole",   conf: 0.80, count: 1,  note: "Gravel section Hokandara" },
  { lat: 6.9045, lon: 79.9640, type: "pothole",   conf: 0.88, count: 3,  note: "Hokandara to Malabe connector" },

  // ── Kottawa - Pannipitiya Road ────────────────────
  { lat: 6.8720, lon: 79.9625, type: "pothole",   conf: 0.93, count: 7,  note: "Kottawa main road" },
  { lat: 6.8735, lon: 79.9610, type: "bump",      conf: 0.87, count: 3,  note: "Speed bump Kottawa junction" },
  { lat: 6.8748, lon: 79.9598, type: "pothole",   conf: 0.90, count: 4,  note: "Pannipitiya road section" },
  { lat: 6.8760, lon: 79.9585, type: "bump",      conf: 0.84, count: 2,  note: "Rough surface Pannipitiya" },

  // ── Additional Malabe residential roads ───────────
  { lat: 6.9110, lon: 79.9760, type: "pothole",   conf: 0.89, count: 3,  note: "Residential road off New Kandy Rd" },
  { lat: 6.9100, lon: 79.9740, type: "bump",      conf: 0.84, count: 2,  note: "Residential speed bump" },
  { lat: 6.9095, lon: 79.9775, type: "pothole",   conf: 0.87, count: 4,  note: "Back road Malabe" },
  { lat: 6.9170, lon: 79.9705, type: "pothole",   conf: 0.90, count: 3,  note: "Near Kaduwela bridge approach" },
  { lat: 6.9180, lon: 79.9685, type: "bump",      conf: 0.82, count: 1,  note: "Unpaved section near river" },
];

// ────────────────────────────────────────────────────
async function seed() {
  console.log("🌱 Seeding hazard data for Malabe area...\n");
  const client = await pool.connect();

  try {
    await client.query("BEGIN");

    // Check how many hazards already exist
    const before = await client.query("SELECT COUNT(*) AS n FROM public.hazards");
    console.log(`📊 Existing hazards: ${before.rows[0].n}`);

    let inserted = 0;

    for (const h of hazards) {
      await client.query(
        `INSERT INTO hazards (
           location, hazard_type, confidence_score,
           detection_count, last_updated
         ) VALUES (
           ST_SetSRID(ST_MakePoint($1, $2), 4326),
           $3, $4, $5, NOW()
         )`,
        [h.lon, h.lat, h.type, h.conf, h.count]
      );
      inserted++;
    }

    await client.query("COMMIT");

    const after = await client.query("SELECT COUNT(*) AS n FROM public.hazards");
    console.log(`✅ Inserted ${inserted} hazards`);
    console.log(`📊 Total hazards now: ${after.rows[0].n}`);

    // Summary by type
    const summary = await client.query(`
      SELECT hazard_type, COUNT(*) AS n
      FROM public.hazards
      GROUP BY hazard_type
      ORDER BY n DESC
    `);
    console.log("\n📋 Hazard breakdown:");
    summary.rows.forEach((r) => console.log(`   ${r.hazard_type}: ${r.n}`));

    // Bounding box check
    const bbox = await client.query(`
      SELECT
        MIN(ST_Y(location::geometry)) AS min_lat,
        MAX(ST_Y(location::geometry)) AS max_lat,
        MIN(ST_X(location::geometry)) AS min_lon,
        MAX(ST_X(location::geometry)) AS max_lon
      FROM public.hazards
    `);
    const b = bbox.rows[0];
    console.log(`\n🗺️  Coverage: lat ${b.min_lat}–${b.max_lat}, lon ${b.min_lon}–${b.max_lon}`);

  } catch (err) {
    await client.query("ROLLBACK");
    console.error("❌ Seed failed:", err.message);
  } finally {
    client.release();
    await pool.end();
  }
}

seed();
