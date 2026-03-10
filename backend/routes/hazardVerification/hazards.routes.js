// routes/hazardsRoutes.js
import express from 'express';
import { 
  getHazards, 
  getHazardById, 
  confirmHazard, 
  denyHazard, 
  getHazardStats 
} from '../../controllers/hazardsController.js';

const router = express.Router();

router.get('/', getHazards);
router.get('/stats', getHazardStats);
router.get('/:id', getHazardById);
router.post('/:id/confirm', confirmHazard);
router.post('/:id/deny', denyHazard);

export default router;
