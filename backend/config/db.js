// config/db.js
import pkg from "pg";
import dotenv from "dotenv";

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

  max: 20,
  idleTimeoutMillis: 30000,
  connectionTimeoutMillis: 15000,
});

// Prevent ECONNRESET / network errors from crashing the process.
// The pool will automatically replace dead connections on the next query.
pool.on("error", (err) => {
  console.error("⚠️  Idle database connection error (auto-recovering):", err.message);
});

pool
  .connect()
  .then((client) => {
    console.log("✅ Connected to PostgreSQL + PostGIS successfully!");
    console.log(`📍 Connected to: ${process.env.PGHOST}`);
    client.release();
  })
  .catch((err) => {
    console.error("❌ Database connection error:", err.message);
  });

export default pool;