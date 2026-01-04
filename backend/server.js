// server.js
import express from "express";
import dotenv from "dotenv";
import cors from "cors";
import authRoutes from "./routes/auth/auth.routes.js";
import poiRoutes from "./routes/poiRoutes.js";
import routingRoutes from "./routes/routingRoutes.js"; // ✅ for /api/routing/generate
import pgRoutingRoutes from "./routes/routing.js";      // ✅ for /api/routing/route

dotenv.config();

const app = express();
app.use(cors());
app.use(express.json());

// Auth routes
app.use("/api/auth", authRoutes);

// POI routes
app.use("/api", poiRoutes);
app.use("/uploads", express.static("uploads"));

// Multi-objective route list (generate best segments)
app.use("/api/routing", routingRoutes);

// pgRouting-based full path calculation
app.use("/api/pg-routing", pgRoutingRoutes);

const PORT = process.env.PORT || 5001;

app.listen(PORT,'0.0.0.0',  () => {

  console.log(`🚀 Server running on port ${PORT}`);
});