// config/db.js
import pkg from "pg";
import dotenv from "dotenv";

dotenv.config();

const { Pool } = pkg;

const pool = new Pool({
  user: process.env.PGUSER,
  host: process.env.PGHOST,
  database: process.env.PGDATABASE,
  password: process.env.PGPASSWORD,
  port: process.env.PGPORT,
  ssl: process.env.PGHOST.includes('supabase.co') ? {
    rejectUnauthorized: false,
    // Additional SSL options for Supabase
    sslmode: 'require'
  } : false,
  // Connection pool settings
  max: 20, // maximum number of clients
  idleTimeoutMillis: 30000,
  connectionTimeoutMillis: 10000, // 10 seconds timeout
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
    console.error("🔍 Connection details:");
    console.error(`   Host: ${process.env.PGHOST}`);
    console.error(`   Port: ${process.env.PGPORT}`);
    console.error(`   Database: ${process.env.PGDATABASE}`);
    console.error(`   User: ${process.env.PGUSER}`);
  });

export default pool;