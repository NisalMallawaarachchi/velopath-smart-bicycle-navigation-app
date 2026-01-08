# 🚴‍♀️ VeloPath – Smart Bicycle Navigation System  
### A Multi-Objective Route Generation Engine for Eco-Friendly Cycling

VeloPath is a **research-driven smart bicycle navigation system** designed to provide cyclists with optimized routes based not only on distance, but also on **safety and scenic value**. The system integrates a Flutter mobile application with a powerful geospatial backend built on PostgreSQL, PostGIS, and pgRouting.

This project is developed as an undergraduate research project and focuses on designing and evaluating a **multi-objective routing engine for bicycle navigation**.

---

## 🌍 System Overview

VeloPath is a full-stack navigation platform consisting of:

📱 **Flutter Mobile App**  
🌐 **Node.js + Express Backend API**  
🗄 **PostgreSQL + PostGIS + pgRouting Spatial Database**

The system supports real-time bicycle navigation, turn-by-turn instructions, voice guidance, off-route detection, and dynamic route re-generation.

---

## 🎯 Research Focus

**Title Area:**  
Multi-Objective Route Generation Engine for Smart Bicycle Navigation

**Primary Optimization Goals:**
- 📏 Distance efficiency  
- ⚠️ Safety (hazard awareness – planned)  
- 🌿 Scenic value (POI influence – planned)

**Key Contribution:**  
Design and implementation of a **multi-objective cost-based routing engine** integrated into a real mobile navigation system.

---

## 🚀 Current Features

### 📱 Flutter Mobile Application
- Interactive map using **Flutter Map + OpenStreetMap**
- Start & destination search (Geoapify)
- Route profiles:
  - Shortest
  - Safest
  - Scenic
  - Balanced
- Real-time GPS tracking (blue live dot)
- Route polyline rendering
- Turn-by-turn navigation UI
- Voice navigation using Flutter TTS
- Arrival detection
- Off-route detection with automatic re-routing
- Optimized rendering using Selector-based rebuilds
- Modular, research-friendly architecture

---

### 🌐 Backend API
- RESTful routing service (Node.js + Express)
- PostgreSQL spatial database
- PostGIS geospatial processing
- pgRouting graph algorithms
- OpenStreetMap road network
- pgr_dijkstra shortest path algorithm
- Start/end snapping to road graph
- Geometry stitching and deduplication
- Bearing-based turn detection
- Navigation instruction generation

---

### 🗄 Spatial Database
- Graph-based road network model
- `routing.ways` – road segments (edges)
- `routing.ways_vertices_pgr` – intersections (nodes)
- Supports future hazard & POI layers

---

## 🧩 System Architecture

Flutter Mobile App
|
| HTTP (REST)
↓
Node.js / Express API
|
| SQL + PostGIS + pgRouting
↓
PostgreSQL Spatial Database


---

## 🗂 Repository Structure


velopath-smart-bicycle-navigation-system/
│
├── mobile_app/ # Flutter application
├── backend/ # Node.js routing API
├── database/ # SQL scripts, spatial setup
├── docs/ # Research diagrams & documentation
└── README.md


---

## 📱 Mobile App Structure


mobile_app/lib/
│
├── core/ # constants, themes, helpers
├── data/
│ ├── models/ # RouteModel, InstructionModel
│ └── services/ # API services
│
├── modules/
│ └── routing_engine/
│ ├── providers/ # RoutingEngineProvider
│ ├── screens/ # Map & navigation UI
│ ├── widgets/ # UI components
│ └── utils/ # navigation logic
│
├── routes/ # app routing
└── main.dart

---

## 🛠 Setup Instructions

### 🔹 Prerequisites
- Flutter SDK  
- Node.js  
- PostgreSQL  
- PostGIS  
- pgRouting  
- Android Studio / Xcode  

---

### 🔹 Clone the repository

```bash
git clone https://github.com/NisalMallawaarachchi/velopath-smart-bicycle-navigation-app
cd velopath-smart-bicycle-navigation-app