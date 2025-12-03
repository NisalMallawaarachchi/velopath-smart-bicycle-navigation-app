// routes/routingRoutes.js
import express from "express";
import { generateRoutes } from "../controllers/routingController.js";

const router = express.Router();

// GET /api/routing/generate
router.get("/generate", generateRoutes);

export default router;
