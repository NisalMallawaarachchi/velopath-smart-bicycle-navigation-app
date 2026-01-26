# 🚴 VeloPath - Smart Bicycle Navigation System

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Node.js Version](https://img.shields.io/badge/node-%3E%3D18.0.0-brightgreen)](https://nodejs.org/)
[![Flutter Version](https://img.shields.io/badge/flutter-%3E%3D3.0.0-blue)](https://flutter.dev/)
[![PostgreSQL](https://img.shields.io/badge/PostgreSQL-14+-316192?logo=postgresql)](https://www.postgresql.org/)

> An intelligent bicycle navigation system designed to enhance tourist safety in rural Sri Lanka through crowdsourced hazard verification and real-time route optimization.

---

## 📖 Table of Contents

- [Overview](#overview)
- [Features](#features)
- [System Architecture](#system-architecture)
- [Technology Stack](#technology-stack)
- [Prerequisites](#prerequisites)
- [Installation](#installation)
- [Configuration](#configuration)
- [Running the Application](#running-the-application)
- [API Documentation](#api-documentation)
- [Database Schema](#database-schema)
- [Testing](#testing)
- [Deployment](#deployment)
- [Contributing](#contributing)
- [Team](#team)
- [License](#license)

---

## 🎯 Overview

VeloPath is a comprehensive bicycle navigation system developed as a research project at Sri Lanka Institute of Information Technology (SLIIT). The system addresses critical safety challenges faced by tourist cyclists in rural areas by providing:

- **Real-time hazard detection** using smartphone sensors and machine learning
- **Crowdsourced verification** with confidence-based scoring
- **Self-healing hazard maps** through temporal decay algorithms
- **Offline-first architecture** for areas with poor connectivity
- **Safe route optimization** avoiding verified hazards
- **Multi-objective** cost based routing engine

### Problem Statement

Tourist cyclists in rural Sri Lanka encounter unreported road hazards (potholes, bumps, gravel) that compromise safety. Existing navigation systems like Google Maps fail to account for localized, real-time road conditions, leaving riders vulnerable to accidents.

### Solution

This intelligent system that:
1. **Detects** hazards automatically using ML-based sensor analysis (Component 1)
2. **Verifies** hazards through community consensus and confidence scoring (Component 2)
3. **Navigates** cyclists via safe, optimized routes (Component 3)

---

## ✨ Features

### 🔍 Hazard Detection (Component 1)
- Automatic hazard detection using smartphone accelerometer and gyroscope
- Machine learning classification (potholes vs. bumps)
- Offline data collection with background synchronization
- GPS-tagged hazard reporting

### ✅ Hazard Verification (Component 2) 
- **Proximity-based duplicate detection** (10-meter radius using Haversine distance)
- **Dynamic confidence scoring** with community-based verification
- **Exponential decay algorithm** for temporal relevance
- **Self-healing maps** that automatically remove outdated hazards
- **User reputation system** for quality assurance
- **RESTful API** for seamless integration

### 🗺️ Multi-Objective Route Generation Engine (Component 3)
- Real-time GPS tracking
- Route polyline rendering
- Safe route calculation avoiding verified hazards
- Real-time hazard alerts (approaching & passed notifications)
- Interactive map with hazard visualization
- Points of Interest (POI) integration
- Turn-by-turn navigation
- Voice navigation using Flutter TTS
- Arrival detection
- Off-route detection with automatic re-routing
- Optimized rendering using Selector-based rebuilds

### 🗺️ POI Gamification (Component 4)
- Motivate cyclists to explore scenic and culturally significant hidden locations
- Improve POI data accuracy through community interaction
- Distance-based POI suggestions along active routes
- Up vote and down vote sytstem

### 📱 Mobile Application
- Cross-platform (Android & iOS) using Flutter
- One-tap hazard confirmation (YES/NO/SKIP)
- Offline map caching
- User profile and statistics
- Community leaderboard
- Start & destination search (Geoapify)
- Route profiles:
  - Shortest
  - Safest
  - Scenic
  - Balanced

---

## 🏗️ System Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                         MOBILE APPLICATION                      │
│                            (Flutter)                            │
├─────────────────────────────────────────────────────────────────┤
│  • Map Display          • Hazard Alerts    • User Profile      │
│  • Sensor Collection    • Navigation       • Offline Cache     │
└────────────┬────────────────────────────────────────────────────┘
             │ REST API (HTTP/HTTPS)
             ▼
┌─────────────────────────────────────────────────────────────────┐
│                       BACKEND SERVICES                          │
│                      (Node.js + Express)                        │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  ┌──────────────────┐  ┌──────────────────┐  ┌──────────────┐ │
│  │  Component 1     │  │  Component 2     │  │ Component 3  │ │
│  │  ML Detection    │  │  Verification    │  │  Routing     │ │
│  │                  │  │                  │  │              │ │
│  │  • Sensor Data   │  │  • Proximity     │  │  • Route     │ │
│  │  • ML Model      │  │  • Confidence    │  │    Planning  │ │
│  │  • Classification│  │  • Decay         │  │  • POI       │ │
│  └──────────────────┘  └──────────────────┘  └──────────────┘ │
│                                                                 │
│  ┌─────────────────────────────────────────────────────────┐  │
│  │              Scheduled Jobs (node-cron)                 │  │
│  │  • Detection Processor (every 30 seconds)              │  │
│  │  • Decay Service (every 6 hours)                       │  │
│  └─────────────────────────────────────────────────────────┘  │
└────────────┬────────────────────────────────────────────────────┘
             │
             ▼
┌─────────────────────────────────────────────────────────────────┐
│                    DATABASE LAYER                               │
│                 (PostgreSQL 14 + PostGIS)                       │
├─────────────────────────────────────────────────────────────────┤
│  • ml_detections        • hazards         • user_confirmations │
│  • users                • processing_log  • spatial_indexes    │
└─────────────────────────────────────────────────────────────────┘
```

---

## 🛠️ Technology Stack

### Backend
- **Runtime:** Node.js 18+
- **Framework:** Express.js 4.18+
- **Database:** PostgreSQL 14+ with PostGIS 3.3+
- **Task Scheduling:** node-cron
- **Authentication:** JWT (JSON Web Tokens)
- **API Testing:** Postman

### Frontend (Mobile)
- **Framework:** Flutter 3.0+
- **Language:** Dart
- **State Management:** Provider / Riverpod
- **Maps:** flutter_map (Leaflet-based)
- **Local Storage:** Hive / SQLite

### Machine Learning (Component 1)
- **Library:** TensorFlow Lite
- **Language:** Python 3.9+
- **Sensors:** Accelerometer, Gyroscope, GPS

### Development Tools
- **Version Control:** Git & GitHub
- **Code Editor:** VS Code
- **Database Management:** pgAdmin 4
- **API Testing:** Postman
- **Containerization:** Docker (optional)

---

## 📋 Prerequisites

### Required Software

1. **Node.js & npm**
   ```bash
   # Check version (must be 18+)
   node --version
   npm --version
   ```

2. **PostgreSQL with PostGIS**
   ```bash
   # Check PostgreSQL version (must be 14+)
   psql --version
   
   # Verify PostGIS extension
   psql -U postgres -c "SELECT PostGIS_Version();"
   ```

3. **Flutter SDK**
   ```bash
   # Check Flutter version
   flutter --version
   flutter doctor
   ```

4. **Git**
   ```bash
   git --version
   ```

### System Requirements
- **OS:** Windows 10+, macOS 11+, or Linux (Ubuntu 20.04+)
- **RAM:** 8GB minimum, 16GB recommended
- **Storage:** 10GB free space
- **Network:** Stable internet connection for setup

---

## 🚀 Installation

### 1. Clone the Repository

```bash
git clone https://github.com/your-org/velopath-smart-bicycle-navigation.git
cd velopath-smart-bicycle-navigation
```

### 2. Database Setup

#### Install PostgreSQL with PostGIS (if not already installed)

**Ubuntu/Debian:**
```bash
sudo apt update
sudo apt install postgresql postgresql-contrib postgis
```

**macOS (using Homebrew):**
```bash
brew install postgresql postgis
brew services start postgresql
```

**Windows:**
Download and install from [PostgreSQL Official Site](https://www.postgresql.org/download/windows/)

#### Create Database and Enable PostGIS

```bash
# Connect to PostgreSQL
psql -U postgres

# Create database
CREATE DATABASE velopath_db;

# Connect to the database
\c velopath_db

# Enable PostGIS extension
CREATE EXTENSION postgis;

# Verify installation
SELECT PostGIS_Version();

# Exit
\q
```

#### Run Database Schema

```bash
# Navigate to backend folder
cd backend

# Run schema creation script
psql -U postgres -d velopath_db -f database/schema.sql

# Verify tables created
psql -U postgres -d velopath_db -c "\dt"
```

### 3. Backend Setup

```bash
# Navigate to backend directory
cd backend

# Install dependencies
npm install

# Create environment file
cp .env.example .env

# Edit .env with your configuration
nano .env  # or use your preferred editor
```

#### Configure `.env` File

```env
# Database Configuration
DB_HOST=localhost
DB_PORT=5432
DB_NAME=velopath_db
DB_USER=postgres
DB_PASSWORD=your_password_here

# Server Configuration
PORT=5001
NODE_ENV=development

# JWT Secret (generate a secure random string)
JWT_SECRET=your_jwt_secret_key_here

# Cron Job Intervals
DETECTION_PROCESSOR_INTERVAL=*/30 * * * * *  # Every 30 seconds
DECAY_SERVICE_INTERVAL=0 */6 * * *            # Every 6 hours

# API Keys (if needed)
# GOOGLE_MAPS_API_KEY=your_api_key_here
```

#### Verify Backend Installation

```bash
# Run database migrations (if applicable)
npm run migrate

# Start development server
npm run dev

# You should see:
# 🚀 Server running on port 5001
# ✅ Database connected successfully
```

### 4. Mobile App Setup (Flutter)

```bash
# Navigate to mobile app directory
cd ../mobile_app

# Get Flutter dependencies
flutter pub get

# Check for any issues
flutter doctor

# Run on emulator or device
flutter run
```

---

## ⚙️ Configuration

### Database Configuration

**Connection Pooling:**
```javascript
// backend/src/config/database.js
const pool = new Pool({
  host: process.env.DB_HOST,
  port: process.env.DB_PORT,
  database: process.env.DB_NAME,
  user: process.env.DB_USER,
  password: process.env.DB_PASSWORD,
  max: 20,                    // Maximum connections
  idleTimeoutMillis: 30000,
  connectionTimeoutMillis: 2000,
});
```

### Cron Job Configuration

**Detection Processor:**
```javascript
// Runs every 30 seconds
cron.schedule('*/30 * * * * *', async () => {
  await detectionProcessor.processUnprocessedDetections();
});
```

**Decay Service:**
```javascript
// Runs every 6 hours (00:00, 06:00, 12:00, 18:00)
cron.schedule('0 */6 * * *', async () => {
  await decayService.runDecay();
});
```

### Algorithm Configuration

**Confidence Scoring Parameters:**
```javascript
// backend/src/utils/ConfidenceCalculator.js
static SCORE_CHANGES = {
  ML_DETECTION: 0.15,   // Increase for each ML detection
  USER_CONFIRM: 0.30,   // Increase for user confirmation
  USER_DENY: -0.40      // Decrease for user denial
};

static THRESHOLDS = {
  VERIFIED: 0.80,       // Minimum for verified status
  EXPIRED: 0.50,        // Below this = expired
  DELETED: 0.20         // Below this = auto-deleted
};
```

**Decay Rates:**
```javascript
static DECAY_RATES = {
  pothole: 0.030,  // 3% per day (~23 days to 50%)
  bump: 0.008      // 0.8% per day (~87 days to 50%)
};
```

**Proximity Threshold:**
```javascript
// backend/src/services/DetectionProcessor.js
this.PROXIMITY_THRESHOLD = 10; // meters
```

---

## 🏃 Running the Application

### Development Mode

**Backend:**
```bash
cd backend
npm run dev

# Server runs on http://localhost:5001
# Auto-restarts on file changes (using nodemon)
```

**Mobile App:**
```bash
cd mobile_app
flutter run

# Or specify device
flutter run -d chrome          # Web
flutter run -d android          # Android
flutter run -d emulator-5554    # Specific emulator
```

### Production Mode

**Backend:**
```bash
cd backend
npm start

# Or with PM2 (recommended)
pm2 start src/index.js --name velopath-api
pm2 save
pm2 startup
```

**Mobile App:**
```bash
# Build APK (Android)
flutter build apk --release

# Build IPA (iOS - macOS only)
flutter build ios --release

# Build Web
flutter build web
```

---

## 📚 API Documentation

### Base URL
```
Development: http://localhost:5001/api
Production: https://api.velopath.com/api
```

### Authentication

Most endpoints require JWT authentication:
```bash
# Include in request headers
Authorization: Bearer <your_jwt_token>
```

### Core Endpoints

#### 1. System Health

**Check Server Status**
```http
GET /health

Response 200 OK:
{
  "status": "healthy",
  "database": "connected",
  "timestamp": "2026-01-20T10:30:00Z"
}
```

**Get System Statistics**
```http
GET /api/stats

Response 200 OK:
{
  "success": true,
  "stats": {
    "unprocessed_detections": "0",
    "verified_hazards": "12",
    "pending_hazards": "8",
    "expired_hazards": "3",
    "total_confirmations": "45",
    "total_denials": "7",
    "active_users": "23"
  },
  "timestamp": "2026-01-20T10:30:00Z"
}
```

#### 2. Hazard Management

**Get Hazards in Area (For Map Display)**
```http
GET /api/hazards?minLat=7.20&maxLat=7.22&minLon=79.83&maxLon=79.84&minConfidence=0.5

Query Parameters:
- minLat: Minimum latitude (required)
- maxLat: Maximum latitude (required)
- minLon: Minimum longitude (required)
- maxLon: Maximum longitude (required)
- minConfidence: Minimum confidence score (optional, default: 0.5)

Response 200 OK:
{
  "success": true,
  "count": 3,
  "hazards": [
    {
      "id": "uuid-here",
      "location": {
        "lat": 7.2088,
        "lon": 79.8358
      },
      "type": "pothole",
      "confidence": "0.85",
      "status": "verified",
      "detectionCount": 5,
      "confirmationCount": 3,
      "lastUpdated": "2026-01-20T09:15:00Z"
    }
  ]
}
```

**Get Single Hazard Details**
```http
GET /api/hazards/:id

Response 200 OK:
{
  "success": true,
  "hazard": {
    "id": "uuid",
    "location": {"lat": 7.2088, "lon": 79.8358},
    "type": "pothole",
    "confidence": "0.850",
    "status": "verified",
    "detectionCount": 5,
    "confirmationCount": 3,
    "denialCount": 0,
    "firstDetected": "2026-01-15T08:30:00Z",
    "lastUpdated": "2026-01-20T09:15:00Z",
    "lastConfirmed": "2026-01-20T09:15:00Z",
    "decayRate": 0.03,
    "decayAccelerated": false
  }
}
```

#### 3. User Actions

**Confirm Hazard (Detailed)**
```http
POST /api/hazards/:id/confirm
Content-Type: application/json

Request Body:
{
  "user_id": "user_123",
  "comment": "Big pothole, be careful!"
}

Response 200 OK:
{
  "success": true,
  "hazard_id": "uuid",
  "new_confidence": "0.900",
  "status": "verified",
  "message": "Thank you for confirming this hazard"
}
```

**Deny Hazard (Report as Fixed)**
```http
POST /api/hazards/:id/deny
Content-Type: application/json

Request Body:
{
  "user_id": "user_123",
  "comment": "Road was repaired yesterday"
}

Response 200 OK:
{
  "success": true,
  "hazard_id": "uuid",
  "new_confidence": "0.450",
  "status": "expired",
  "message": "Thank you for reporting. Hazard marked for removal."
}
```

#### 4. Notifications (Mobile App)

**Get Approaching Hazards**
```http
GET /api/notifications/approaching?lat=7.2088&lon=79.8357&userId=user_123

Query Parameters:
- lat: Current latitude (required)
- lon: Current longitude (required)
- userId: User identifier (required)

Response 200 OK:
{
  "success": true,
  "count": 2,
  "hazards": [
    {
      "id": "uuid",
      "type": "pothole",
      "confidence": 0.85,
      "status": "verified",
      "distance": 47,
      "location": {"lat": 7.2088, "lon": 79.8358},
      "message": "POTHOLE AHEAD (47m)"
    }
  ]
}
```

**Get Recently Passed Hazards**
```http
GET /api/notifications/passed?lat=7.2089&lon=79.8359&userId=user_123

Response 200 OK:
{
  "success": true,
  "count": 1,
  "hazards": [
    {
      "id": "uuid",
      "type": "pothole",
      "confidence": 0.75,
      "status": "pending",
      "distance": 15,
      "location": {"lat": 7.2088, "lon": 79.8358},
      "question": "Did you just pass a pothole?"
    }
  ]
}
```

**Quick Response (YES/NO/SKIP)**
```http
POST /api/notifications/:id/respond
Content-Type: application/json

Request Body:
{
  "userId": "user_123",
  "response": "yes"  // or "no" or "skip"
}

Response 200 OK:
{
  "success": true,
  "message": "Thank you for confirming!",
  "hazard_id": "uuid",
  "new_confidence": "0.900",
  "status": "verified",
  "action": "confirm"
}
```

#### 5. Admin Tools

**Manually Process ML Detections**
```http
POST /api/admin/process-detections

Response 200 OK:
{
  "success": true,
  "processed": 15
}
```

**Manually Run Decay**
```http
POST /api/admin/run-decay

Response 200 OK:
{
  "success": true,
  "updated": 42,
  "deleted": 5
}
```

### Error Responses

**400 Bad Request:**
```json
{
  "success": false,
  "error": "Missing required parameters: lat, lon, userId"
}
```

**404 Not Found:**
```json
{
  "success": false,
  "error": "Hazard not found"
}
```

**500 Internal Server Error:**
```json
{
  "success": false,
  "error": "Database connection failed"
}
```

---

## 🗄️ Database Schema

### Entity Relationship Diagram

```
┌─────────────────────┐
│   ml_detections     │
├─────────────────────┤
│ id (PK)            │
│ latitude           │
│ longitude          │
│ hazard_type        │
│ detection_confidence│
│ detected_at        │
│ processed          │◄─── Processed by DetectionProcessor
│ device_id          │
└─────────────────────┘
         │
         │ Aggregated into
         ▼
┌─────────────────────┐
│      hazards        │
├─────────────────────┤
│ id (PK)            │
│ location (GEOGRAPHY)│◄─── PostGIS spatial type
│ hazard_type        │
│ confidence_score   │
│ status             │
│ detection_count    │
│ confirmation_count │
│ denial_count       │
│ first_detected     │
│ last_updated       │
│ last_confirmed     │
│ decay_rate         │
│ decay_accelerated  │
└─────────────────────┘
         │
         │ 1:N
         ▼
┌──────────────────────┐
│ user_confirmations   │
├──────────────────────┤
│ id (PK)             │
│ hazard_id (FK)      │◄─── References hazards(id)
│ user_id             │
│ action              │     ('confirm' or 'deny')
│ comment             │
│ timestamp           │
│ UNIQUE(hazard_id, user_id)
└──────────────────────┘
```

### Key Tables

#### 1. ml_detections
Stores raw hazard detections from ML model (Component 1).

```sql
CREATE TABLE ml_detections (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    latitude DECIMAL(10, 8) NOT NULL,
    longitude DECIMAL(11, 8) NOT NULL,
    hazard_type VARCHAR(20) NOT NULL CHECK (hazard_type IN ('pothole', 'bump')),
    detection_confidence DECIMAL(3, 2),
    detected_at TIMESTAMP DEFAULT NOW(),
    processed BOOLEAN DEFAULT FALSE,
    processed_at TIMESTAMP NULL,
    device_id VARCHAR(50)
);
```

#### 2. hazards
Stores verified hazards with confidence scores.

```sql
CREATE TABLE hazards (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    location GEOGRAPHY(POINT, 4326) NOT NULL,
    hazard_type VARCHAR(20) NOT NULL,
    confidence_score DECIMAL(4, 3) DEFAULT 0.150,
    status VARCHAR(20) DEFAULT 'pending',
    detection_count INTEGER DEFAULT 1,
    confirmation_count INTEGER DEFAULT 0,
    denial_count INTEGER DEFAULT 0,
    first_detected TIMESTAMP DEFAULT NOW(),
    last_updated TIMESTAMP DEFAULT NOW(),
    last_confirmed TIMESTAMP NULL,
    decay_rate DECIMAL(5, 4) DEFAULT 0.030,
    decay_accelerated BOOLEAN DEFAULT FALSE
);

CREATE INDEX idx_hazards_location ON hazards USING GIST(location);
CREATE INDEX idx_hazards_status ON hazards(status, confidence_score);
```

#### 3. user_confirmations
Tracks user feedback on hazards.

```sql
CREATE TABLE user_confirmations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    hazard_id UUID REFERENCES hazards(id) ON DELETE CASCADE,
    user_id VARCHAR(50) NOT NULL,
    action VARCHAR(10) NOT NULL CHECK (action IN ('confirm', 'deny')),
    comment TEXT,
    timestamp TIMESTAMP DEFAULT NOW(),
    UNIQUE (hazard_id, user_id)
);
```

### Views

#### system_stats
Provides real-time system statistics.

```sql
CREATE OR REPLACE VIEW system_stats AS
SELECT 
    (SELECT COUNT(*) FROM ml_detections WHERE processed = FALSE) as unprocessed_detections,
    (SELECT COUNT(*) FROM hazards WHERE status = 'verified') as verified_hazards,
    (SELECT COUNT(*) FROM hazards WHERE status = 'pending') as pending_hazards,
    (SELECT COUNT(*) FROM hazards WHERE status = 'expired') as expired_hazards,
    (SELECT COUNT(*) FROM user_confirmations WHERE action = 'confirm') as total_confirmations,
    (SELECT COUNT(*) FROM user_confirmations WHERE action = 'deny') as total_denials,
    (SELECT COUNT(DISTINCT user_id) FROM user_confirmations) as active_users;
```

---

## 🧪 Testing

### Backend API Testing

#### Using Postman

1. **Import Collection:**
   ```bash
   # Import from file
   backend/tests/VeloPath_API.postman_collection.json
   ```

2. **Set Environment Variables:**
   - `base_url`: `http://localhost:5001`
   - `test_user_id`: `test_user_001`
   - `test_hazard_id`: (copy from API response)

3. **Run Test Suite:**
   - Execute tests in order (1-15)
   - Verify all responses are 200 OK
   - Check confidence score changes

#### Using curl

```bash
# Health check
curl http://localhost:5001/health

# Get system stats
curl http://localhost:5001/api/stats

# Get hazards
curl "http://localhost:5001/api/hazards?minLat=7.20&maxLat=7.22&minLon=79.83&maxLon=79.84"

# Confirm hazard
curl -X POST http://localhost:5001/api/hazards/{id}/confirm \
  -H "Content-Type: application/json" \
  -d '{"user_id":"test_user","comment":"Confirmed!"}'
```

### Database Testing

```sql
-- Check hazards view
SELECT * FROM hazards_view ORDER BY confidence DESC;

-- Verify confidence scoring
SELECT id, confidence_score, status, detection_count, confirmation_count 
FROM hazards 
WHERE hazard_type = 'pothole';

-- Check user activity
SELECT user_id, COUNT(*) as total_confirmations
FROM user_confirmations
WHERE action = 'confirm'
GROUP BY user_id
ORDER BY total_confirmations DESC;

-- Test proximity query
SELECT id, hazard_type, 
       ST_Distance(
         location, 
         ST_SetSRID(ST_MakePoint(79.8358, 7.2088), 4326)::geography
       ) as distance_meters
FROM hazards
WHERE ST_DWithin(
  location,
  ST_SetSRID(ST_MakePoint(79.8358, 7.2088), 4326)::geography,
  10
);
```

### Mobile App Testing

```bash
# Run unit tests
cd mobile_app
flutter test

# Run integration tests
flutter test integration_test/

# Check for issues
flutter analyze

# Format code
flutter format lib/
```

---

## 🚢 Deployment

### Backend Deployment

#### Using PM2 (Recommended)

```bash
# Install PM2 globally
npm install -g pm2

# Start application
pm2 start src/index.js --name velopath-api

# Enable auto-restart on system reboot
pm2 startup
pm2 save

# Monitor
pm2 monit

# View logs
pm2 logs velopath-api

# Restart
pm2 restart velopath-api
```

#### Using Docker

```dockerfile
# Dockerfile
FROM node:18-alpine

WORKDIR /app

COPY package*.json ./
RUN npm ci --production

COPY . .

EXPOSE 5001

CMD ["node", "src/index.js"]
```

```bash
# Build image
docker build -t velopath-api .

# Run container
docker run -d \
  --name velopath-api \
  -p 5001:5001 \
  --env-file .env \
  velopath-api

# Or use docker-compose
docker-compose up -d
```

### Database Backup

```bash
# Backup database
pg_dump -U postgres -d velopath_db > backup_$(date +%Y%m%d).sql

# Restore database
psql -U postgres -d velopath_db < backup_20260120.sql

# Automated daily backup (cron)
0 2 * * * pg_dump -U postgres velopath_db > /backups/velopath_$(date +\%Y\%m\%d).sql
```

### Mobile App Deployment

#### Android (Google Play Store)

```bash
# Build signed APK
flutter build apk --release

# Or build App Bundle (recommended for Play Store)
flutter build appbundle --release

# APK location: build/app/outputs/flutter-apk/app-release.apk
# Bundle location: build/app/outputs/bundle/release/app-release.aab
```

#### iOS (App Store)

```bash
# Build iOS app (macOS only)
flutter build ios --release

# Open Xcode for final steps
open ios/Runner.xcworkspace
```

---

## 🤝 Contributing

We welcome contributions from the community! Please follow these guidelines:

### Development Workflow

1. **Fork the repository**
2. **Create a feature branch:**
   ```bash
   git checkout -b feature/your-feature-name
   ```
3. **Make your changes**
4. **Write/update tests**
5. **Commit with meaningful messages:**
   ```bash
   git commit -m "feat: add user reputation system"
   ```
6. **Push to your fork:**
   ```bash
   git push origin feature/your-feature-name
   ```
7. **Create a Pull Request**

### Commit Message Convention

Follow [Conventional Commits](https://www.conventionalcommits.org/):

- `feat:` New feature
- `fix:` Bug fix
- `docs:` Documentation changes
- `style:` Code style changes (formatting)
- `refactor:` Code refactoring
- `test:` Adding tests
- `chore:` Maintenance tasks

### Code Style

- **JavaScript:** Follow [Airbnb JavaScript Style Guide](https://github.com/airbnb/javascript)
- **Dart/Flutter:** Follow [Effective Dart](https://dart.dev/guides/language/effective-dart)
- **SQL:** Use uppercase for keywords, snake_case for identifiers

---

## 👥 Team

### Research Team

| Component | Responsibility | Developer | ID |
|-----------|---------------|-----------|-----|
| **Component 1** | ML-based Hazard Detection | Gayasri Pethum | IT22031266 |
| **Component 2** | Hazard Verification System | Nisal Mallawaarachchi | IT22899538|
| **Component 3** | Multi-Objective Route Generation Engine | Shakya K. Gurusinghe| IT22893352 |
| **Component 4** | Gamified Discovery of Local Points-of-Interest (POI) | Thiruni Jayasinghe| IT22341990 |
