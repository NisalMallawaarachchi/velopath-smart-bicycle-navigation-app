import express from "express";
import {
  register,
  login,
  getProfile,
  updateProfile,
} from "../../controllers/auth/auth.controller.js";
import { authenticateToken } from "../../middlewares/auth.middleware.js";

const router = express.Router();

router.post("/register", register);
router.post("/login", login);
router.get("/me", authenticateToken, getProfile);
router.put("/me", authenticateToken, updateProfile);

export default router;