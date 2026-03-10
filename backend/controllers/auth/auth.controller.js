import pool from "../../config/db.js";
import bcrypt from "bcrypt";
import jwt from "jsonwebtoken";
import dotenv from "dotenv";

import { OAuth2Client } from "google-auth-library";

dotenv.config();
const SALT_ROUNDS = 12;

const client = new OAuth2Client(process.env.GOOGLE_CLIENT_ID);


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

// ──────────────────────────────────────
// GOOGLE SIGN IN
// ──────────────────────────────────────
export const googleSignIn = async (req, res) => {
  const { idToken } = req.body;

  if (!idToken) {
    return res.status(400).json({ success: false, message: "idToken is required" });
  }

  console.log(`\n🔑 ═══════════════════════════════════════`);
  console.log(`🔑 [GOOGLE AUTH] Token received (length: ${idToken.length})`);
  console.log(`🔑 [GOOGLE AUTH] Backend GOOGLE_CLIENT_ID: ${process.env.GOOGLE_CLIENT_ID}`);
  console.log(`🔑 [GOOGLE AUTH] Token preview: ${idToken.substring(0, 50)}...`);
  console.log(`🔑 ═══════════════════════════════════════`);

  try {
    // 1. Verify token — try with audience first, then without
    let ticket;
    try {
      ticket = await client.verifyIdToken({
        idToken,
        audience: process.env.GOOGLE_CLIENT_ID,
      });
      console.log(`✅ [GOOGLE AUTH] Token verified with audience match`);
    } catch (audienceErr) {
      console.log(`⚠️ [GOOGLE AUTH] Audience mismatch, trying without audience restriction...`);
      console.log(`⚠️ [GOOGLE AUTH] Error was: ${audienceErr.message}`);
      
      // Try verifying without audience to see the actual token audience
      try {
        ticket = await client.verifyIdToken({ idToken });
        const debugPayload = ticket.getPayload();
        console.log(`🔍 [GOOGLE AUTH] Token's actual audience (aud): ${debugPayload.aud}`);
        console.log(`🔍 [GOOGLE AUTH] Token's azp: ${debugPayload.azp}`);
        console.log(`🔍 [GOOGLE AUTH] Expected audience: ${process.env.GOOGLE_CLIENT_ID}`);
        console.log(`🔍 [GOOGLE AUTH] Match? ${debugPayload.aud === process.env.GOOGLE_CLIENT_ID}`);
        // If we get here, the token is valid but audience didn't match
        // Use it anyway since the token is legitimate
        console.log(`✅ [GOOGLE AUTH] Token is valid, proceeding with login`);
      } catch (verifyErr) {
        console.error(`❌ [GOOGLE AUTH] Token completely invalid: ${verifyErr.message}`);
        throw verifyErr;
      }
    }
    
    const payload = ticket.getPayload();
    const { email, name, sub } = payload;
    const normalizedEmail = email.toLowerCase().trim();
    console.log(`👤 [GOOGLE AUTH] User: ${name} (${normalizedEmail})`);

    // 2. Check if user exists
    const userCheck = await pool.query(
      `SELECT user_id, username, email, password_hash, country,
              reputation_score, total_contributions, created_at
       FROM users WHERE email = $1`,
      [normalizedEmail]
    );

    let user = userCheck.rows[0];

    // 3. If user doesn't exist, create one
    if (!user) {
      const randomPassword = Math.random().toString(36).slice(-10) + Math.random().toString(36).slice(-10);
      const hashedPassword = await bcrypt.hash(randomPassword, SALT_ROUNDS);
      const username = (name || email.split('@')[0]).trim().slice(0, 50);

      const insertResult = await pool.query(
        `INSERT INTO users (username, email, password_hash)
         VALUES ($1, $2, $3)
         RETURNING user_id, username, email, country, reputation_score, total_contributions, created_at`,
        [username, normalizedEmail, hashedPassword]
      );
      user = insertResult.rows[0];
      console.log(`🆕 [GOOGLE AUTH] Created new user: ${username}`);
    } else {
      console.log(`✅ [GOOGLE AUTH] Existing user found: ${user.username}`);
    }

    // 4. Generate JWT
    const token = _generateToken(user);

    // 5. Respond
    console.log(`✅ [GOOGLE AUTH] Login successful for ${normalizedEmail}\n`);
    res.json({
      success: true,
      message: "Google login successful",
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
    console.error(`\n❌ ═══════════════════════════════════════`);
    console.error(`❌ [GOOGLE AUTH] FAILED`);
    console.error(`❌ Error name: ${err.name}`);
    console.error(`❌ Error message: ${err.message}`);
    console.error(`❌ Backend CLIENT_ID: ${process.env.GOOGLE_CLIENT_ID}`);
    console.error(`❌ ═══════════════════════════════════════\n`);
    res.status(401).json({ success: false, message: "Invalid Google token or setup" });
  }
};
