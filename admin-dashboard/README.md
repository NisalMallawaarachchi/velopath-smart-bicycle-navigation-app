# VeloPath Admin Dashboard

Web-based admin dashboard for the VeloPath smart bicycle navigation app.
Collects and visualizes user data for the Travalia travel itinerary platform.

## Quick Start

```bash
cd admin-dashboard
npm install
# Copy .env and fill in values (see below)
node server.js
# Open http://localhost:5050
```

Default admin credentials (change before deploying):
- Email: `admin@velopath.app`
- Password: `VeloAdmin2025!`

## Environment Variables (.env)

```
PORT=5050

# Same Supabase connection as backend/.env
PGUSER=...
PGHOST=...
PGDATABASE=...
PGPASSWORD=...
PGPORT=5432

# Admin login credentials
ADMIN_EMAIL=admin@velopath.app
ADMIN_PASSWORD=VeloAdmin2025!

# Must be different from backend JWT_SECRET
ADMIN_JWT_SECRET=velopath_admin_super_secret_2025

# Travalia integration (stubbed until API is ready)
TRAVALIA_API_URL=https://api.travalia.app
TRAVALIA_API_KEY=stub_key_replace_me
```

## Pages

| Page | URL | Description |
|------|-----|-------------|
| Users | / (sidebar) | Paginated user table with filters, CSV export, Travalia flag |
| User Profile | click any user | Full profile: preferences, POIs, hazards, GPS map, Travalia card |
| Analytics | sidebar | Country breakdown, POI trends, route modes, Travalia export panel |
| Hazard Map | sidebar | Leaflet map of all hazards with filters and GeoJSON export |
| System Health | sidebar | Live stats: users, hazards, rides, ML model, sync timestamps |

## API Endpoints

All routes require `Authorization: Bearer <token>` (obtain via `POST /admin/login`).

```
POST /admin/login                          → { token, expiresIn }
GET  /admin/users                          → paginated list (filters: country, active, dateFrom, dateTo, search)
GET  /admin/users/:id                      → full profile + Travalia card
GET  /admin/users/:id/preferences          → Travalia preference object only
PATCH /admin/users/:id/flag-travalia       → { flag: true/false }
GET  /admin/users/:id/export-csv           → CSV download
GET  /admin/analytics/countries            → country-wise POI + route breakdown
GET  /admin/analytics/poi-trends           → POI visit trends over time
GET  /admin/analytics/route-modes          → route mode distribution
GET  /admin/analytics/system-health        → live system stats
GET  /admin/export/travalia                → JSONL download of all flagged users
GET  /admin/export/users-csv               → full user table CSV
GET  /admin/export/hazards-geojson         → GeoJSON of all hazards
GET  /admin/export/flagged-users           → list of flagged users with Travalia status
POST /admin/export/users/:id/push-travalia → push single user to Travalia API (stubbed)
POST /admin/export/sync-travalia           → sync all flagged users (stubbed)
GET  /admin/hazards                        → hazard list for map (filters: type, status, minConfidence, dateFrom, dateTo)
```

## Schema Extensions (applied by migrate_admin.mjs)

Five migrations were run against the Supabase DB to support this dashboard:

1. **users** — added: `last_active_at`, `device_type`, `app_version`, `flagged_for_travalia`, `travalia_status`, `travalia_pushed_at`
2. **ride_sessions** — new table: stores completed rides with GPS tracks, route mode, distance
3. **poi_visits** — new table: tracks user POI visits with category and dwell time
4. **admin_audit_log** — new table: logs all admin actions
5. **travalia_sync_log** — new table: logs Travalia sync history

## Travalia JSON Schema

Each user exported to Travalia follows this schema:

```json
{
  "user_id": "uuid",
  "username": "string",
  "email": "string",
  "country_of_origin": "Australia",
  "poi_interests": ["Cultural Sites", "Beaches", "Temples"],
  "route_preference": "scenic",
  "activity_level": "moderate",
  "speed_profile": "slow",
  "preferred_time": "morning",
  "geographic_focus": ["6.93,79.84", "6.03,80.22"],
  "travalia_score": 74,
  "exported_at": "2026-05-03T09:00:00.000Z"
}
```

## Mobile App Integration

For full dashboard data, update the Flutter app to log:
- `POST /api/rides/start` → create ride_session row
- `POST /api/rides/end`   → update ride_session with distance, gps_track, end coords
- `POST /api/pois/visit`  → log poi_visit row on POI detail open
- `PATCH /api/auth/me`    → update last_active_at, device_type, app_version on login

Until then, ride preference and heatmap sections show "No data yet."

## Security Notes

- Change `ADMIN_EMAIL`, `ADMIN_PASSWORD`, and `ADMIN_JWT_SECRET` before any deployment
- Admin tokens expire in 8h
- All admin actions are logged in `admin_audit_log`
- Rate limited to 500 requests per 15 minutes
