// jobs/decayJob.js
// Manual trigger helper — useful for admin endpoints and testing
import DecayService from '../services/decayService.js';

const decayService = new DecayService();

export const runDecayOnce = async () => {
  console.log('[DecayJob] Manual decay triggered...');
  try {
    const result = await decayService.runDecay();
    console.log(`[DecayJob] Done — updated: ${result.updated}, deleted: ${result.deleted}`);
    return result;
  } catch (error) {
    console.error('[DecayJob] Failed:', error);
    throw error;
  }
};
