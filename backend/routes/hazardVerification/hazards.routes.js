// routes/hazardVerification/hazards.routes.js
import express from 'express';
import { 
  getHazards, 
  getHazardById, 
  confirmHazard, 
  denyHazard, 
  getHazardStats 
} from '../../controllers/hazardsController.js';
import { authenticateToken } from '../../middlewares/auth.middleware.js';

const router = express.Router();

// Public routes — no auth needed to view hazards
router.get('/', getHazards);
router.get('/stats', getHazardStats);
router.get('/:id', getHazardById);

// Protected routes — must be logged in to vote
router.post('/:id/confirm', authenticateToken, confirmHazard);
router.post('/:id/deny', authenticateToken, denyHazard);

export default router;
