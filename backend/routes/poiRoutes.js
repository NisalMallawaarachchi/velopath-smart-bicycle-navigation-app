import express from "express";
import upload from "../config/multerConfig.js";
import { addPOI, getPOIs, votePOI } from "../controllers/poiController.js";
import { getDashboard} from "../controllers/dashboardController.js";



const router = express.Router();

router.post("/pois", upload.single("image"), addPOI);

router.get("/pois", getPOIs);
router.get("/dashboard/:deviceId", getDashboard);

router.post("/pois/:id/vote", votePOI);

export default router;
