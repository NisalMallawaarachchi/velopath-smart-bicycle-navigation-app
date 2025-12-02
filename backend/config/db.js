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
});

pool
  .connect()
  .then((client) => {
    console.log("✅ Connected to PostgreSQL + PostGIS successfully!");
    client.release();
  })
  .catch((err) => {
    console.error("❌ Database connection error:", err.message);
  });

export default pool;
