import pkg from "pg";
import dotenv from "dotenv";
import { fileURLToPath } from "url";
import { dirname, join } from "path";

const __dirname = dirname(fileURLToPath(import.meta.url));
dotenv.config({ path: join(__dirname, "../.env") });

const { Client } = pkg;
const client = new Client({
  user: process.env.PGUSER,
  host: process.env.PGHOST,
  database: process.env.PGDATABASE,
  password: process.env.PGPASSWORD,
  port: Number(process.env.PGPORT || 5432),
  ssl: { rejectUnauthorized: false },
});

async function run() {
  await client.connect();

  // List all tables in public schema
  const tables = await client.query(`
    SELECT tablename FROM pg_tables
    WHERE schemaname = 'public'
    ORDER BY tablename;
  `);
  console.log("=== TABLES ===");
  tables.rows.forEach(r => console.log(" ", r.tablename));

  // Get columns for users table
  const userCols = await client.query(`
    SELECT column_name, data_type, is_nullable, column_default
    FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'users'
    ORDER BY ordinal_position;
  `);
  console.log("\n=== users COLUMNS ===");
  userCols.rows.forEach(r =>
    console.log(`  ${r.column_name} | ${r.data_type} | nullable:${r.is_nullable} | default:${r.column_default}`)
  );

  // Get primary key for users
  const pk = await client.query(`
    SELECT kcu.column_name
    FROM information_schema.table_constraints tc
    JOIN information_schema.key_column_usage kcu
      ON tc.constraint_name = kcu.constraint_name
    WHERE tc.table_schema = 'public'
      AND tc.table_name = 'users'
      AND tc.constraint_type = 'PRIMARY KEY';
  `);
  console.log("\n=== users PRIMARY KEY ===");
  pk.rows.forEach(r => console.log(" ", r.column_name));

  await client.end();
}

run().catch(e => { console.error(e.message); process.exit(1); });
