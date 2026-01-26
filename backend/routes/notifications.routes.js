import express from "express";
import {
  getApproachingHazards,
  getPassedHazards,
  respondToHazard,
} from "../controllers/notificationController.js";

const router = express.Router();

router.get("/approaching", getApproachingHazards);
router.get("/passed", getPassedHazards);
router.post("/:id/respond", respondToHazard);

export default router;
