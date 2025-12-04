// server.js
import express from "express";
import dotenv from "dotenv";
import cors from "cors";
import testRoutes from "./routes/testRoutes.js";
import poiRoutes from "./routes/poiRoutes.js";

dotenv.config();

const app = express();
app.use(cors());
app.use(express.json());

// Use routes
//app.use("/api", testRoutes);

app.use("/api", poiRoutes);
app.use("/uploads", express.static("uploads"));


const PORT = process.env.PORT || 5001;
app.listen(PORT, () => {
  console.log(`🚀 Server running on port ${PORT}`);
});
