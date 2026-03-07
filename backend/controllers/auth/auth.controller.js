import pool from "../../config/db.js";
import bcrypt from "bcrypt";
import jwt from "jsonwebtoken";
import dotenv from "dotenv";

dotenv.config();
const SALT_ROUNDS = 12;

// ──────────────────────────────────────
// REGISTER
// ──────────────────────────────────────
export const register = async (req, res) => {
  const { username, email, password, country } = req.body;

  // Validation
  if (!username || !email || !password) {
    return res.status(400).json({
      success: false,
      message: "Username, email, and password are required",
    });
  }

  if (password.length < 6) {
    return res.status(400).json({
      success: false,
      message: "Password must be at least 6 characters",
    });
  }

  const emailRegex = /^[\w-.]+@([\w-]+\.)+[\w-]{2,4}$/;
  if (!emailRegex.test(email)) {
    return res.status(400).json({
      success: false,
      message: "Invalid email format",
    });
  }

  try {
    const hashedPassword = await bcrypt.hash(password, SALT_ROUNDS);

    const result = await pool.query(
      `INSERT INTO users (username, email, password_hash, country)
       VALUES ($1, $2, $3, $4)
       RETURNING user_id, username, email, country, reputation_score, total_contributions, created_at`,
      [username.trim(), email.trim().toLowerCase(), hashedPassword, country || null]
    );

    const user = result.rows[0];

    // Generate token immediately so user can login after registration
    const token = _generateToken(user);

    res.status(201).json({
      success: true,
      message: "Account created successfully",
      token,
      user: {
        id: user.user_id,
        username: user.username,
        email: user.email,
        country: user.country,
        reputationScore: parseFloat(user.reputation_score),
        totalContributions: user.total_contributions,
        createdAt: user.created_at,
      },
    });
  } catch (err) {
    console.error("[Auth] Register error:", err);
    if (err.code === "23505") {
      // Unique constraint violation
      const field = err.constraint?.includes("email") ? "email" : "username";
      return res.status(409).json({
        success: false,
        message: `An account with this ${field} already exists`,
      });
    }
    res.status(500).json({ success: false, message: "Server error" });
  }
};

// ──────────────────────────────────────
// LOGIN
// ──────────────────────────────────────
export const login = async (req, res) => {
  const { email, password } = req.body;

  if (!email || !password) {
    return res.status(400).json({
      success: false,
      message: "Email and password are required",
    });
  }

  try {
    const result = await pool.query(
      `SELECT user_id, username, email, password_hash, country,
              reputation_score, total_contributions, created_at
       FROM users WHERE email = $1`,
      [email.trim().toLowerCase()]
    );

    const user = result.rows[0];
    if (!user) {
      return res
        .status(401)
        .json({ success: false, message: "Invalid email or password" });
    }

    const passwordMatch = await bcrypt.compare(password, user.password_hash);
    if (!passwordMatch) {
      return res
        .status(401)
        .json({ success: false, message: "Invalid email or password" });
    }

    const token = _generateToken(user);

    res.json({
      success: true,
      message: "Login successful",
      token,
      user: {
        id: user.user_id,
        username: user.username,
        email: user.email,
        country: user.country,
        reputationScore: parseFloat(user.reputation_score),
        totalContributions: user.total_contributions,
        createdAt: user.created_at,
      },
    });
  } catch (err) {
    console.error("[Auth] Login error:", err);
    res.status(500).json({ success: false, message: "Server error" });
  }
};

// ──────────────────────────────────────
// GET PROFILE (/me)
// ──────────────────────────────────────
export const getProfile = async (req, res) => {
  try {
    const result = await pool.query(
      `SELECT user_id, username, email, country,
              reputation_score, total_contributions, created_at
       FROM users WHERE user_id = $1`,
      [req.user.id]
    );

    const user = result.rows[0];
    if (!user) {
      return res
        .status(404)
        .json({ success: false, message: "User not found" });
    }

    res.json({
      success: true,
      user: {
        id: user.user_id,
        username: user.username,
        email: user.email,
        country: user.country,
        reputationScore: parseFloat(user.reputation_score),
        totalContributions: user.total_contributions,
        createdAt: user.created_at,
      },
    });
  } catch (err) {
    console.error("[Auth] Profile error:", err);
    res.status(500).json({ success: false, message: "Server error" });
  }
};

// ──────────────────────────────────────
// UPDATE PROFILE
// ──────────────────────────────────────
export const updateProfile = async (req, res) => {
  const { username, country } = req.body;

  if (!username || username.trim().length < 3) {
    return res.status(400).json({
      success: false,
      message: "Username must be at least 3 characters",
    });
  }

  try {
    const result = await pool.query(
      `UPDATE users
       SET username = $1, country = $2
       WHERE user_id = $3
       RETURNING user_id, username, email, country,
                 reputation_score, total_contributions, created_at`,
      [username.trim(), country || null, req.user.id]
    );

    const user = result.rows[0];
    if (!user) {
      return res
        .status(404)
        .json({ success: false, message: "User not found" });
    }

    res.json({
      success: true,
      message: "Profile updated successfully",
      user: {
        id: user.user_id,
        username: user.username,
        email: user.email,
        country: user.country,
        reputationScore: parseFloat(user.reputation_score),
        totalContributions: user.total_contributions,
        createdAt: user.created_at,
      },
    });
  } catch (err) {
    console.error("[Auth] Update profile error:", err);
    if (err.code === "23505") {
      return res.status(409).json({
        success: false,
        message: "Username already taken",
      });
    }
    res.status(500).json({ success: false, message: "Server error" });
  }
};

// ──────────────────────────────────────
// HELPER: Generate JWT
// ──────────────────────────────────────
function _generateToken(user) {
  return jwt.sign(
    {
      id: user.user_id,
      email: user.email,
      username: user.username,
      country: user.country,
    },
    process.env.JWT_SECRET,
    { expiresIn: process.env.JWT_EXPIRES_IN || "7d" }
  );
}
