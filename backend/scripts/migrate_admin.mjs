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

const migrations = [
  {
    name: "extend_users_table",
    sql: `
      ALTER TABLE users
        ADD COLUMN IF NOT EXISTS last_active_at       TIMESTAMPTZ,
        ADD COLUMN IF NOT EXISTS device_type          TEXT,
        ADD COLUMN IF NOT EXISTS app_version          TEXT,
        ADD COLUMN IF NOT EXISTS flagged_for_travalia BOOLEAN DEFAULT FALSE,
        ADD COLUMN IF NOT EXISTS travalia_status      TEXT DEFAULT 'pending',
        ADD COLUMN IF NOT EXISTS travalia_pushed_at   TIMESTAMPTZ;
    `,
  },
  {
    name: "create_ride_sessions",
    sql: `
      CREATE TABLE IF NOT EXISTS ride_sessions (
        session_id    UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
        user_id       INTEGER     NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
        started_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
        ended_at      TIMESTAMPTZ,
        distance_km   NUMERIC(8,3),
        route_mode    TEXT        CHECK (route_mode IN ('shortest','safest','scenic','balanced')),
        avg_speed_kmh NUMERIC(5,2),
        gps_track     JSONB,
        start_lat     NUMERIC(10,7),
        start_lon     NUMERIC(10,7),
        end_lat       NUMERIC(10,7),
        end_lon       NUMERIC(10,7)
      );
      CREATE INDEX IF NOT EXISTS ride_sessions_user_id_idx    ON ride_sessions(user_id);
      CREATE INDEX IF NOT EXISTS ride_sessions_started_at_idx ON ride_sessions(started_at);
    `,
  },
  {
    name: "create_poi_visits",
    sql: `
      CREATE TABLE IF NOT EXISTS poi_visits (
        id            BIGSERIAL   PRIMARY KEY,
        user_id       INTEGER     NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
        poi_id        INTEGER,
        poi_name      TEXT,
        poi_category  TEXT,
        visited_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
        dwell_seconds INTEGER     DEFAULT 0
      );
      CREATE INDEX IF NOT EXISTS poi_visits_user_id_idx   ON poi_visits(user_id);
      CREATE INDEX IF NOT EXISTS poi_visits_category_idx  ON poi_visits(poi_category);
      CREATE INDEX IF NOT EXISTS poi_visits_visited_at_idx ON poi_visits(visited_at);
    `,
  },
  {
    name: "create_admin_audit_log",
    sql: `
      CREATE TABLE IF NOT EXISTS admin_audit_log (
        id          BIGSERIAL   PRIMARY KEY,
        admin_email TEXT        NOT NULL,
        action      TEXT        NOT NULL,
        target_id   TEXT,
        metadata    JSONB,
        created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
      );
    `,
  },
  {
    name: "create_travalia_sync_log",
    sql: `
      CREATE TABLE IF NOT EXISTS travalia_sync_log (
        id          BIGSERIAL   PRIMARY KEY,
        synced_at   TIMESTAMPTZ NOT NULL DEFAULT NOW(),
        user_count  INTEGER,
        status      TEXT,
        response    JSONB
      );
    `,
  },
];

async function run() {
  await client.connect();
  console.log("Connected to Supabase\n");

  for (const m of migrations) {
    try {
      await client.query(m.sql);
      console.log(`✅  ${m.name}`);
    } catch (err) {
      console.error(`❌  ${m.name}: ${err.message}`);
    }
  }

  await client.end();
  console.log("\nMigrations complete.");
}

run().catch((err) => {
  console.error("Fatal:", err.message);
  process.exit(1);
});
