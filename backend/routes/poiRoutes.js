import express from "express";
import upload from "../config/multerConfig.js";
import { addPOI, getPOIs, votePOI,  getComments,addComment, getNotifications } from "../controllers/poiController.js";
import { getDashboard} from "../controllers/dashboardController.js";
import { getRankedPOIs } from "../controllers/poiRankingController.js";


const router = express.Router();

router.post("/pois", upload.single("image"), addPOI);
router.get("/notifications/:deviceId", getNotifications);

router.get("/pois", getPOIs);
router.get("/pois/ranked", getRankedPOIs);
router.get("/dashboard/:deviceId", getDashboard);

router.post("/pois/:id/vote", votePOI);

router.get("/pois/:id/comments", getComments);
router.post("/pois/:id/comments", addComment);



export default router;
