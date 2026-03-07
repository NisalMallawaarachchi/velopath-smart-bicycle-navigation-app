// hazardController.js
// Controller for road hazard detection using Python ML model

import { spawn } from "child_process";
import path from "path";
import { fileURLToPath } from "url";
import fs from "fs";
import pool from "../config/db.js";

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

// Path to Python interpreter (Anaconda)
const PYTHON_PATH = "C:\\Users\\Droofy\\anaconda3\\python.exe";
const ML_DIR = path.join(__dirname, "..", "ml");

/**
 * Health check for ML service
 */
export const healthCheck = async (req, res) => {
  try {
    const modelPath = path.join(ML_DIR, "model.pkl");
    const modelExists = fs.existsSync(modelPath);

    res.json({
      status: "ok",
      mlServiceAvailable: modelExists,
      pythonPath: PYTHON_PATH,
      modelPath: modelPath,
    });
  } catch (error) {
    res.status(500).json({
      status: "error",
      message: error.message,
    });
  }
};

/**
 * Predict hazards from sensor data
 * Expects body: { sensorData: [...] }
 */
export const predictHazard = async (req, res) => {
  try {
    const { sensorData } = req.body;

    if (!sensorData || !Array.isArray(sensorData)) {
      return res.status(400).json({
        success: false,
        error: "Invalid request: sensorData array required",
      });
    }

    if (sensorData.length < 10) {
      return res.status(400).json({
        success: false,
        error: "Need at least 10 sensor readings for prediction",
      });
    }

    // Write sensor data to temp file
    const tempFile = path.join(ML_DIR, `temp_${Date.now()}.json`);
    fs.writeFileSync(tempFile, JSON.stringify(sensorData));

    // Call Python predict script
    const pythonProcess = spawn(PYTHON_PATH, ["predict.py", tempFile], {
      cwd: ML_DIR,
    });

    let stdout = "";
    let stderr = "";

    pythonProcess.stdout.on("data", (data) => {
      stdout += data.toString();
    });

    pythonProcess.stderr.on("data", (data) => {
      stderr += data.toString();
    });

    pythonProcess.on("close", async (code) => {
      // Clean up temp file
      try {
        fs.unlinkSync(tempFile);
      } catch (e) {
        console.error("Failed to clean up temp file:", e);
      }

      if (code !== 0) {
        console.error("Python process error:", stderr);
        return res.status(500).json({
          success: false,
          error: "ML prediction failed",
          details: stderr,
        });
      }

      try {
        const result = JSON.parse(stdout);

        // Save hazard detections to ml_detections table
        await saveDetectionsToDB(result, req.body.deviceId);

        res.json(result);
      } catch (e) {
        res.status(500).json({
          success: false,
          error: "Failed to parse prediction result",
          raw: stdout,
        });
      }
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      error: error.message,
    });
  }
};

/**
 * Get demo prediction using pre-generated demo session
 */
export const getDemoPredict = async (req, res) => {
  try {
    const demoFile = path.join(ML_DIR, "demo_session.json");

    if (!fs.existsSync(demoFile)) {
      return res.status(404).json({
        success: false,
        error: "Demo session not found. Run generate_data.py first.",
      });
    }

    // Call Python predict script with demo file
    const pythonProcess = spawn(PYTHON_PATH, ["predict.py", demoFile], {
      cwd: ML_DIR,
    });

    let stdout = "";
    let stderr = "";

    pythonProcess.stdout.on("data", (data) => {
      stdout += data.toString();
    });

    pythonProcess.stderr.on("data", (data) => {
      stderr += data.toString();
    });

    pythonProcess.on("close", (code) => {
      if (code !== 0) {
        console.error("Python process error:", stderr);
        return res.status(500).json({
          success: false,
          error: "ML prediction failed",
          details: stderr,
        });
      }

      try {
        const result = JSON.parse(stdout);
        res.json(result);
      } catch (e) {
        res.status(500).json({
          success: false,
          error: "Failed to parse prediction result",
          raw: stdout,
        });
      }
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      error: error.message,
    });
  }
};

/**
 * Upload labeled sensor data for prediction or training
 * Expects body: { sensorData: [...], mode: 'predict' | 'train' }
 */
export const uploadLabeledData = async (req, res) => {
  try {
    console.log("≡ƒôÑ Upload request received");
    console.log("   Mode:", req.body.mode);
    console.log("   Data points:", req.body.sensorData?.length || 0);
    
    const { sensorData, mode } = req.body;

    if (!sensorData || !Array.isArray(sensorData)) {
      console.log("Γ¥î Invalid request: no sensorData array");
      return res.status(400).json({
        success: false,
        error: "Invalid request: sensorData array required",
      });
    }

    if (!mode || !["predict", "train"].includes(mode)) {
      console.log("Γ¥î Invalid mode:", mode);
      return res.status(400).json({
        success: false,
        error: "Invalid request: mode must be 'predict' or 'train'",
      });
    }

    if (sensorData.length < 10) {
      console.log(" Not enough data:", sensorData.length);
      return res.status(400).json({
        success: false,
        error: "Need at least 10 sensor readings",
      });
    }

    // Check if data has labels
    const hasLabels = sensorData.some((r) => r.label && r.label !== "smooth");
    
    if (mode === "train") {
      // TRAIN MODE: Append data to training_data.json
      const trainingFile = path.join(ML_DIR, "training_data.json");
      
      let existingData = [];
      if (fs.existsSync(trainingFile)) {
        try {
          existingData = JSON.parse(fs.readFileSync(trainingFile, "utf-8"));
        } catch (e) {
          console.error("Failed to read existing training data:", e);
        }
      }

      // Append new data
      const newData = [...existingData, ...sensorData];
      fs.writeFileSync(trainingFile, JSON.stringify(newData, null, 2));

      // Count labels
      const labelCounts = {};
      for (const reading of sensorData) {
        const label = reading.label || "smooth";
        labelCounts[label] = (labelCounts[label] || 0) + 1;
      }

      return res.json({
        success: true,
        mode: "train",
        message: "Data added to training set",
        stats: {
          addedReadings: sensorData.length,
          totalReadings: newData.length,
          labelCounts: labelCounts,
          hasLabels: hasLabels,
        },
      });
    } else {
      // PREDICT MODE: Run ML prediction
      const tempFile = path.join(ML_DIR, `temp_${Date.now()}.json`);
      fs.writeFileSync(tempFile, JSON.stringify(sensorData));

      const pythonProcess = spawn(PYTHON_PATH, ["predict.py", tempFile], {
        cwd: ML_DIR,
      });

      let stdout = "";
      let stderr = "";

      pythonProcess.stdout.on("data", (data) => {
        stdout += data.toString();
      });

      pythonProcess.stderr.on("data", (data) => {
        stderr += data.toString();
      });

      pythonProcess.on("close", async (code) => {
        // Clean up temp file
        try {
          fs.unlinkSync(tempFile);
        } catch (e) {
          console.error("Failed to clean up temp file:", e);
        }

        if (code !== 0) {
          console.error("Python process error:", stderr);
          return res.status(500).json({
            success: false,
            error: "ML prediction failed",
            details: stderr,
          });
        }

        try {
          const result = JSON.parse(stdout);
          result.mode = "predict";
          result.inputHadLabels = hasLabels;

          // Save hazard detections to ml_detections table
          await saveDetectionsToDB(result, req.body.deviceId);

          res.json(result);
        } catch (e) {
          res.status(500).json({
            success: false,
            error: "Failed to parse prediction result",
            raw: stdout,
          });
        }
      });
    }
  } catch (error) {
    res.status(500).json({
      success: false,
      error: error.message,
    });
  }
};

/**
 * Save non-smooth ML predictions to ml_detections table.
 * The DetectionProcessor cron job will pick these up and create/update hazards.
 */
async function saveDetectionsToDB(result, deviceId) {
  if (!result?.success || !result?.predictions) return;

  // Only save actual hazards (not smooth)
  const hazards = result.predictions.filter(
    (p) => p.hazard_type !== "smooth" && p.latitude && p.longitude
  );

  if (hazards.length === 0) return;

  try {
    const client = await pool.connect();
    try {
      for (const h of hazards) {
        await client.query(
          `INSERT INTO ml_detections (latitude, longitude, hazard_type, detection_confidence, device_id)
           VALUES ($1, $2, $3, $4, $5)`,
          [
            h.latitude,
            h.longitude,
            h.hazard_type,
            h.confidence || 0.85,
            deviceId || "unknown",
          ]
        );
      }
      console.log(
        `[HazardController] Saved ${hazards.length} detections to ml_detections`
      );
    } finally {
      client.release();
    }
  } catch (err) {
    console.error("[HazardController] Failed to save detections:", err.message);
  }
}
