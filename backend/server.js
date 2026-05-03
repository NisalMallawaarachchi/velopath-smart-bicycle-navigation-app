// server.js
import express from "express";
import dotenv from "dotenv";
import cors from "cors";
import cron from "node-cron";

// Routes
import authRoutes from "./routes/auth/auth.routes.js";
import hazardsRouter from "./routes/hazardVerification/hazards.routes.js";
import notificationRoutes from "./routes/notifications.routes.js";
import poiRoutes from "./routes/poiRoutes.js";
import pgRoutingRoutes from "./routes/routing.js";
import hazardDetectionRoutes from "./routes/hazardRoutes.js";
import { authenticateToken } from "./middlewares/auth.middleware.js";

// Services
import DetectionProcessor from "./services/detectionProcessor.js";
import DecayService from "./services/decayService.js";

// Database
import pool from "./config/db.js";

dotenv.config();

const app = express();

// Middleware
const allowedOrigins = process.env.ALLOWED_ORIGINS
  ? process.env.ALLOWED_ORIGINS.split(",").map((o) => o.trim())
  : ["http://localhost:3000", "http://localhost:5001"];

app.use(
  cors({
    origin: (origin, callback) => {
      // Allow requests with no origin (mobile apps, curl, Postman)
      if (!origin) return callback(null, true);
      if (allowedOrigins.includes(origin)) return callback(null, true);
      callback(new Error(`CORS: origin ${origin} not allowed`));
    },
    methods: ["GET", "POST", "PUT", "DELETE"],
  })
);
app.use(express.json({ limit: "10mb" })); // Increased limit for sensor data
app.use("/uploads", express.static("uploads"));

// Routes
app.use("/api/auth", authRoutes);
app.use("/api/hazards", hazardsRouter);
app.use("/api/notifications", notificationRoutes);
app.use("/api", poiRoutes);
app.use("/api/pg-routing", pgRoutingRoutes);
app.use("/api/hazard", hazardDetectionRoutes);

// Health check
app.get("/health", async (req, res) => {
  try {
    await pool.query("SELECT 1");
    res.json({
      status: "healthy",
      database: "connected",
      timestamp: new Date().toISOString(),
    });
  } catch (error) {
    res.status(500).json({ status: "unhealthy", error: error.message });
  }
});

// Stats endpoint
app.get("/api/stats", async (req, res) => {
  try {
    const result = await pool.query("SELECT * FROM system_stats");
    res.json({
      success: true,
      stats: result.rows[0],
      timestamp: new Date().toISOString(),
    });
  } catch (error) {
    console.error("[API] Error fetching stats:", error);
    res.status(500).json({ success: false, error: error.message });
  }
});

// Initialize services
const detectionProcessor = new DetectionProcessor();
const decayService = new DecayService();

//Cron job: Process ML detections every 30 seconds
cron.schedule("*/30 * * * * *", async () => {
  try {
    await detectionProcessor.processUnprocessedDetections();
    console.log("[CRON] Detection processor run completed");
  } catch (error) {
    console.error("[CRON] Detection processor error:", error);
  }
});

// Cron job: Run decay every 6 hours
cron.schedule("0 */6 * * *", async () => {
  try {
    await decayService.runDecay();
    console.log("[CRON] Decay service run completed");
  } catch (error) {
    console.error("[CRON] Decay service error:", error);
  }
});

// Manual triggers — admin only (JWT required)
app.post("/api/admin/process-detections", authenticateToken, async (req, res) => {
  try {
    const result = await detectionProcessor.processUnprocessedDetections();
    res.json({ success: true, ...result });
  } catch (error) {
    res.status(500).json({ success: false, error: error.message });
  }
});

app.post("/api/admin/run-decay", authenticateToken, async (req, res) => {
  try {
    const result = await decayService.runDecay();
    res.json({ success: true, ...result });
  } catch (error) {
    res.status(500).json({ success: false, error: error.message });
  }
});

// Start server
const PORT = process.env.PORT || 5001;
app.listen(PORT, "0.0.0.0", () => {
  console.log("=".repeat(60));
  console.log("🚀 Hazard Verification API Server Started");
  console.log("=".repeat(60));
  console.log(`📡 Server running on: http://localhost:${PORT}`);
  console.log(`📊 Health check: http://localhost:${PORT}/health`);
  console.log(`📈 Stats: http://localhost:${PORT}/api/stats`);
  console.log(`🗺️  Hazards API: http://localhost:${PORT}/api/hazards`);
  console.log(`🤖 ML Hazard Detection: http://localhost:${PORT}/api/hazard`);
  console.log(
    `⚙️  Manual process: POST http://localhost:${PORT}/api/admin/process-detections`
  );
  console.log(
    `⚙️  Manual decay: POST http://localhost:${PORT}/api/admin/run-decay`
  );
  console.log("=".repeat(60));
  console.log("⏰ Cron jobs scheduled:");
  console.log("   - Detection processing: Every 30 seconds");
  console.log("   - Decay mechanism: Every 6 hours");
  console.log("=".repeat(60));
});