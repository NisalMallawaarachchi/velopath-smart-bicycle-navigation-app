// server.js
import express from "express";
import dotenv from "dotenv";
import cors from "cors";
import testRoutes from "./routes/testRoutes.js";
import hazardRoutes from "./routes/hazardRoutes.js";

dotenv.config();

const app = express();
app.use(cors());
app.use(express.json({ limit: "10mb" })); // Increased limit for sensor data

// Health check
app.get("/api/health", (req, res) => {
  res.json({ status: "ok", message: "Velopath Hazard Detection API" });
});

// Routes
app.use("/api", testRoutes);
app.use("/api/hazard", hazardRoutes);

const PORT = process.env.PORT || 5001;
app.listen(PORT, () => {
  console.log(`🚀 Server running on port ${PORT}`);
});
