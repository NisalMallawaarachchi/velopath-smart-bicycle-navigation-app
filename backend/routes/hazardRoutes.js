// hazardRoutes.js
// Routes for road hazard detection API

import express from "express";
import {
  healthCheck,
  predictHazard,
  getDemoPredict,
} from "../controllers/hazardController.js";

const router = express.Router();

// Health check endpoint
router.get("/health", healthCheck);

// Predict hazards from sensor data
router.post("/predict", predictHazard);

// Demo prediction using pre-generated data
router.get("/demo", getDemoPredict);

export default router;
