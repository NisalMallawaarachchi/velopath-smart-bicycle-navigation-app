import "dotenv/config";
import express from "express";
import cors from "cors";
import helmet from "helmet";
import { rateLimit } from "express-rate-limit";
import jwt from "jsonwebtoken";
import bcrypt from "bcryptjs";
import { fileURLToPath } from "url";
import { dirname, join } from "path";
import pool from "./db.js";
import { adminAuth } from "./middleware/adminAuth.js";
import usersRouter   from "./routes/users.js";
import analyticsRouter from "./routes/analytics.js";
import exportRouter  from "./routes/export.js";

// bcryptjs is a pure-JS fallback; install it alongside jsonwebtoken
// npm install bcryptjs  (already in dependencies)

const __dirname = dirname(fileURLToPath(import.meta.url));
const app = express();
const PORT = process.env.PORT || 5050;

// ── Security ──────────────────────────────────────────────────────────────────
app.use(helmet({ contentSecurityPolicy: false })); // CSP off — CDN scripts in HTML
app.use(cors({ origin: "*" }));                    // admin is internal only
app.use(express.json());
app.use(rateLimit({ windowMs: 15 * 60 * 1000, max: 500 }));

// ── Static frontend ───────────────────────────────────────────────────────────
app.use(express.static(join(__dirname, "public")));

// ── Auth: POST /admin/login ───────────────────────────────────────────────────
app.post("/admin/login", async (req, res) => {
  const { email, password } = req.body ?? {};
  if (!email || !password)
    return res.status(400).json({ error: "email and password required" });

  const adminEmail    = process.env.ADMIN_EMAIL;
  const adminPassword = process.env.ADMIN_PASSWORD;

  if (email !== adminEmail)
    return res.status(401).json({ error: "Invalid credentials" });

  // Support both plain-text (dev) and bcrypt-hashed passwords
  const valid = adminPassword.startsWith("$2")
    ? await bcrypt.compare(password, adminPassword)
    : password === adminPassword;

  if (!valid) return res.status(401).json({ error: "Invalid credentials" });

  const token = jwt.sign(
    { email, role: "admin" },
    process.env.ADMIN_JWT_SECRET,
    { expiresIn: "8h" }
  );

  // Log login
  await pool.query(
    `INSERT INTO admin_audit_log (admin_email, action, target_id, metadata)
     VALUES ($1, 'login', NULL, $2)`,
    [email, JSON.stringify({ ip: req.ip })]
  );

  res.json({ token, expiresIn: "8h" });
});

// ── Protected admin routes ────────────────────────────────────────────────────
app.use("/admin/users",            adminAuth, usersRouter);
app.use("/admin/analytics",        adminAuth, analyticsRouter);
app.use("/admin/export",           adminAuth, exportRouter);
app.post("/admin/users/:id/push-travalia", adminAuth, (req, res, next) => {
  req.params = { id: req.params.id };
  exportRouter.handle(req, res, next);
});
app.post("/admin/sync-travalia",   adminAuth, (req, res, next) => exportRouter.handle(req, res, next));

// ── Hazards list (for map page) ───────────────────────────────────────────────
app.get("/admin/hazards", adminAuth, async (req, res) => {
  const { type, minConfidence, dateFrom, dateTo, status } = req.query;
  const conditions = [];
  const params = [];
  let p = 1;
  if (type)          { conditions.push(`hazard_type = $${p++}`);       params.push(type); }
  if (minConfidence) { conditions.push(`confidence_score >= $${p++}`); params.push(parseFloat(minConfidence)); }
  if (dateFrom)      { conditions.push(`first_detected >= $${p++}`);   params.push(dateFrom); }
  if (dateTo)        { conditions.push(`first_detected <= $${p++}`);   params.push(dateTo); }
  if (status)        { conditions.push(`status = $${p++}`);            params.push(status); }
  const where = conditions.length ? "WHERE " + conditions.join(" AND ") : "";

  const rows = await pool.query(`
    SELECT
      h.id, h.hazard_type, h.confidence_score, h.status,
      h.detection_count, h.confirmation_count, h.denial_count,
      h.first_detected, h.last_updated,
      ST_Y(h.location::geometry) AS lat,
      ST_X(h.location::geometry) AS lon,
      json_agg(DISTINCT jsonb_build_object('user_id', uc.user_id, 'action', uc.action))
        FILTER (WHERE uc.user_id IS NOT NULL) AS reporters
    FROM hazards h
    LEFT JOIN user_confirmations uc ON uc.hazard_id = h.id
    ${where}
    GROUP BY h.id
    ORDER BY h.confidence_score DESC
    LIMIT 2000
  `, params);

  res.json(rows.rows);
});

// ── Catch-all → serve index.html for client-side routing ─────────────────────
app.get("/{*splat}", (req, res) => {
  res.sendFile(join(__dirname, "public", "index.html"));
});

// ── Global error handler ──────────────────────────────────────────────────────
app.use((err, req, res, _next) => {
  console.error(err);
  res.status(500).json({ error: err.message });
});

app.listen(PORT, () => {
  console.log(`VeloPath Admin Dashboard running on http://localhost:${PORT}`);
});
