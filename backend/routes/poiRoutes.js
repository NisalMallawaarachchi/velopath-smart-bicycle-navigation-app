import express from "express";
import upload from "../config/multerConfig.js";
import { addPOI, getPOIs } from "../controllers/poiController.js";

const router = express.Router();

// Upload image + POI data
router.post("/pois", upload.single("image"), addPOI);

// Fetch all POIs
router.get("/pois", getPOIs);

export default router;
