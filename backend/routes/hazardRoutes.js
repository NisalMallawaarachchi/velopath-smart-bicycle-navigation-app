// hazardRoutes.js
// Routes for road hazard detection API

import express from "express";
import {
  healthCheck,
  predictHazard,
  getDemoPredict,
  uploadLabeledData,
} from "../controllers/hazardController.js";

const router = express.Router();

// Health check endpoint
router.get("/health", healthCheck);

// Predict hazards from sensor data
router.post("/predict", predictHazard);

// Demo prediction using pre-generated data
router.get("/demo", getDemoPredict);

// Upload labeled data for prediction or training
router.post("/upload", uploadLabeledData);

export default router;
