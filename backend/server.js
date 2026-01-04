// server.js
import express from "express";
import dotenv from "dotenv";
import cors from "cors";
import cron from "node-cron";

// Routes
import authRoutes from "./routes/auth/auth.routes.js";
import hazardsRouter from "./routes/hazardVerification/hazards.routes.js";
import poiRoutes from "./routes/poiRoutes.js";
import routingRoutes from "./routes/routingRoutes.js"; // for /api/routing/generate
import pgRoutingRoutes from "./routes/routing.js";      // for /api/routing/route

// Services
import DetectionProcessor from "./services/DetectionProcessor.js";
import DecayService from "./services/decayService.js";

// Database
import pool from "./config/db.js";

dotenv.config();

const app = express();

// Middleware
app.use(cors());
app.use(express.json());
app.use("/uploads", express.static("uploads"));

// Routes
app.use("/api/auth", authRoutes);
app.use("/api/hazards", hazardsRouter);
app.use("/api", poiRoutes);
app.use("/api/routing", routingRoutes);
app.use("/api/pg-routing", pgRoutingRoutes);

// Health check
app.get("/health", async (req, res) => {
  try {
    await pool.query("SELECT 1");
    res.json({ status: "healthy", database: "connected" });
  } catch (error) {
    res.status(500).json({ status: "unhealthy", error: error.message });
  }
});

// Initialize services
const detectionProcessor = new DetectionProcessor();
const decayService = new DecayService();

// Cron job: Process ML detections every 30 seconds
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

// Manual triggers for testing
app.post("/api/admin/process-detections", async (req, res) => {
  try {
    const result = await detectionProcessor.processUnprocessedDetections();
    res.json({ success: true, ...result });
  } catch (error) {
    res.status(500).json({ success: false, error: error.message });
  }
});

app.post("/api/admin/run-decay", async (req, res) => {
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
  console.log(`🚀 Server running on port ${PORT}`);
  console.log(`📊 Health check: http://localhost:${PORT}/health`);
  console.log(`🗺️  Hazards API: http://localhost:${PORT}/api/hazards`);
});
