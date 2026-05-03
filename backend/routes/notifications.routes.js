import express from "express";
import {
  getApproachingHazards,
  getPassedHazards,
  respondToHazard,
} from "../controllers/notificationController.js";
import { authenticateToken } from "../middlewares/auth.middleware.js";

const router = express.Router();

router.get("/approaching", authenticateToken, getApproachingHazards);
router.get("/passed", authenticateToken, getPassedHazards);
router.post("/:id/respond", authenticateToken, respondToHazard);

export default router;
