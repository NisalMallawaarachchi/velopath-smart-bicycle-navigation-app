// backend/scripts/seed_evaluation.mjs
// Research evaluation seed — 50 users, rides, hazards, POIs along Weligama→Galle
// Run once: node scripts/seed_evaluation.mjs

import pkg      from 'pg';
import bcrypt   from 'bcrypt';
import dotenv   from 'dotenv';
import { fileURLToPath } from 'url';
import { dirname, join } from 'path';
import { randomUUID }    from 'crypto';

const __dirname = dirname(fileURLToPath(import.meta.url));
dotenv.config({ path: join(__dirname, '../.env') });
const { Client } = pkg;

// ── Helpers ───────────────────────────────────────────────────────────────────
const rand    = (a, b) => Math.random() * (b - a) + a;
const randInt = (a, b) => Math.floor(rand(a, b + 1));
const pick    = arr  => arr[randInt(0, arr.length - 1)];
const daysAgo = n    => new Date(Date.now() - n * 86_400_000);

function jitter(lat, lon, meters = 10) {
  return [
    lat + (Math.random() - 0.5) * 2 * meters / 111_320,
    lon + (Math.random() - 0.5) * 2 * meters / (111_320 * Math.cos(lat * Math.PI / 180)),
  ];
}

// ── A2 highway waypoints: Weligama → Galle  (east → west, 34 pts ≈ 28 km) ───
const WP = [
  [5.9729, 80.4295], // 0  Weligama Bay
  [5.9724, 80.4218], // 1
  [5.9718, 80.4140], // 2
  [5.9712, 80.4055], // 3
  [5.9704, 80.3965], // 4
  [5.9696, 80.3875], // 5  Ahangama east
  [5.9688, 80.3785], // 6
  [5.9682, 80.3655], // 7  Ahangama
  [5.9675, 80.3565], // 8
  [5.9620, 80.3520], // 9
  [5.9573, 80.3481], // 10 Midigama
  [5.9590, 80.3390], // 11
  [5.9630, 80.3310], // 12
  [5.9660, 80.3240], // 13
  [5.9720, 80.3170], // 14
  [5.9780, 80.3100], // 15 Koggala
  [5.9840, 80.3030], // 16
  [5.9895, 80.2965], // 17
  [5.9950, 80.2900], // 18
  [6.0005, 80.2835], // 19 Habaraduwa
  [6.0040, 80.2770], // 20
  [6.0065, 80.2705], // 21
  [6.0090, 80.2645], // 22
  [6.0110, 80.2580], // 23
  [6.0130, 80.2520], // 24
  [6.0148, 80.2490], // 25 Unawatuna
  [6.0168, 80.2440], // 26
  [6.0195, 80.2390], // 27
  [6.0220, 80.2345], // 28
  [6.0248, 80.2300], // 29
  [6.0270, 80.2255], // 30
  [6.0290, 80.2215], // 31
  [6.0310, 80.2190], // 32
  [6.0325, 80.2175], // 33 Galle Fort
];

const SEGMENTS = [
  { from:  0, to: 33 }, // Weligama → Galle (full)
  { from: 33, to:  0 }, // Galle → Weligama (return)
  { from:  0, to:  7 }, // Weligama → Ahangama
  { from:  7, to: 33 }, // Ahangama → Galle
  { from:  0, to: 10 }, // Weligama → Midigama
  { from: 10, to: 33 }, // Midigama → Galle
  { from:  7, to: 25 }, // Ahangama → Unawatuna
  { from: 25, to:  0 }, // Unawatuna → Weligama
  { from: 33, to: 25 }, // Galle → Unawatuna (short)
  { from: 10, to: 19 }, // Midigama → Habaraduwa
];

function segTrack(seg) {
  const step = seg.from < seg.to ? 1 : -1;
  const pts  = [];
  for (let i = seg.from; i !== seg.to + step; i += step) {
    const [jLat, jLon] = jitter(WP[i][0], WP[i][1], 8);
    pts.push({ lat: +jLat.toFixed(6), lon: +jLon.toFixed(6) });
  }
  return pts;
}

function segKm(seg) {
  const step = seg.from < seg.to ? 1 : -1;
  let d = 0;
  for (let i = seg.from; i !== seg.to; i += step) {
    const [la1, lo1] = WP[i], [la2, lo2] = WP[i + step];
    const dx = (lo2 - lo1) * 111_320 * Math.cos(la1 * Math.PI / 180);
    const dy = (la2 - la1) * 111_320;
    d += Math.sqrt(dx * dx + dy * dy) / 1000;
  }
  return +d.toFixed(3);
}

// ── 39 new users (diverse nationalities) ─────────────────────────────────────
const NEW_USERS = [
  // Sri Lankan locals (12)
  { username: 'kavindu_perera',      email: 'kavindu.perera.vp@gmail.com',     country: 'Sri Lanka',      device: 'android' },
  { username: 'sachini_fernando',    email: 'sachini.fernando.vp@gmail.com',   country: 'Sri Lanka',      device: 'android' },
  { username: 'dimuthu_jayawardena', email: 'dimuthu.jaya.vp@gmail.com',       country: 'Sri Lanka',      device: 'android' },
  { username: 'thisara_bandara',     email: 'thisara.bandara.vp@gmail.com',    country: 'Sri Lanka',      device: 'android' },
  { username: 'oshada_wickrama',     email: 'oshada.wickrama.vp@gmail.com',    country: 'Sri Lanka',      device: 'android' },
  { username: 'kavindi_silva',       email: 'kavindi.silva.vp@gmail.com',      country: 'Sri Lanka',      device: 'ios'     },
  { username: 'ashen_dissanayake',   email: 'ashen.dis.vp@gmail.com',          country: 'Sri Lanka',      device: 'android' },
  { username: 'maleesha_rajapaksha', email: 'maleesha.raja.vp@gmail.com',      country: 'Sri Lanka',      device: 'android' },
  { username: 'tharusha_liyanage',   email: 'tharusha.liyanage.vp@gmail.com',  country: 'Sri Lanka',      device: 'ios'     },
  { username: 'senuri_pathirana',    email: 'senuri.path.vp@gmail.com',        country: 'Sri Lanka',      device: 'android' },
  { username: 'lasitha_kumara',      email: 'lasitha.kumara.vp@gmail.com',     country: 'Sri Lanka',      device: 'android' },
  { username: 'amaya_wijesinghe',    email: 'amaya.wije.vp@gmail.com',         country: 'Sri Lanka',      device: 'ios'     },
  // Australian tourists / surfers (8)
  { username: 'liam_thompson_au',    email: 'liam.thompson.vp@gmail.com',      country: 'Australia',      device: 'ios'     },
  { username: 'emma_watson_au',      email: 'emma.watson.vp@gmail.com',        country: 'Australia',      device: 'ios'     },
  { username: 'jake_morrison_au',    email: 'jake.morrison.vp@gmail.com',      country: 'Australia',      device: 'android' },
  { username: 'sarah_collins_au',    email: 'sarah.collins.vp@gmail.com',      country: 'Australia',      device: 'ios'     },
  { username: 'matt_henderson_au',   email: 'matt.henderson.vp@gmail.com',     country: 'Australia',      device: 'android' },
  { username: 'olivia_brown_au',     email: 'olivia.brown.vp@gmail.com',       country: 'Australia',      device: 'ios'     },
  { username: 'ryan_mitchell_au',    email: 'ryan.mitchell.vp@gmail.com',      country: 'Australia',      device: 'android' },
  { username: 'chloe_wilson_au',     email: 'chloe.wilson.vp@gmail.com',       country: 'Australia',      device: 'ios'     },
  // German tourists (5)
  { username: 'felix_mueller',       email: 'felix.mueller.vp@gmail.com',      country: 'Germany',        device: 'android' },
  { username: 'anna_schmidt',        email: 'anna.schmidt.vp@gmail.com',       country: 'Germany',        device: 'ios'     },
  { username: 'lukas_weber',         email: 'lukas.weber.vp@gmail.com',        country: 'Germany',        device: 'android' },
  { username: 'sophie_fischer',      email: 'sophie.fischer.vp@gmail.com',     country: 'Germany',        device: 'ios'     },
  { username: 'max_hoffmann',        email: 'max.hoffmann.vp@gmail.com',       country: 'Germany',        device: 'android' },
  // French tourists (4)
  { username: 'pierre_dubois',       email: 'pierre.dubois.vp@gmail.com',      country: 'France',         device: 'ios'     },
  { username: 'marie_laurent',       email: 'marie.laurent.vp@gmail.com',      country: 'France',         device: 'ios'     },
  { username: 'antoine_bernard',     email: 'antoine.bernard.vp@gmail.com',    country: 'France',         device: 'android' },
  { username: 'camille_moreau',      email: 'camille.moreau.vp@gmail.com',     country: 'France',         device: 'ios'     },
  // British tourists (4)
  { username: 'james_wilson_uk',     email: 'james.wilson.vp@gmail.com',       country: 'United Kingdom', device: 'ios'     },
  { username: 'emily_davies_uk',     email: 'emily.davies.vp@gmail.com',       country: 'United Kingdom', device: 'ios'     },
  { username: 'tom_clarke_uk',       email: 'tom.clarke.vp@gmail.com',         country: 'United Kingdom', device: 'android' },
  { username: 'lucy_evans_uk',       email: 'lucy.evans.vp@gmail.com',         country: 'United Kingdom', device: 'ios'     },
  // Japanese tourists (3)
  { username: 'yuki_tanaka',         email: 'yuki.tanaka.vp@gmail.com',        country: 'Japan',          device: 'ios'     },
  { username: 'kenji_watanabe',      email: 'kenji.watanabe.vp@gmail.com',     country: 'Japan',          device: 'android' },
  { username: 'hana_yamamoto',       email: 'hana.yamamoto.vp@gmail.com',      country: 'Japan',          device: 'ios'     },
  // US tourists (3)
  { username: 'tyler_johnson_us',    email: 'tyler.johnson.vp@gmail.com',      country: 'United States',  device: 'ios'     },
  { username: 'megan_brown_us',      email: 'megan.brown.vp@gmail.com',        country: 'United States',  device: 'ios'     },
  { username: 'dylan_anderson_us',   email: 'dylan.anderson.vp@gmail.com',     country: 'United States',  device: 'android' },
];

// ── 20 real POIs along Weligama-Galle route ───────────────────────────────────
const NEW_POIS = [
  { name: 'Weligama Bay Beach',          amenity: 'scenic',           lat: 5.9715, lon: 80.4298, district: 'Matara', description: 'Crescent bay ideal for beginner surfers and sea kayaking' },
  { name: 'Taprobane Island Viewpoint',  amenity: 'landmark',         lat: 5.9718, lon: 80.4325, district: 'Matara', description: 'Iconic private island accessible on foot at low tide' },
  { name: 'Weligama Surf Camp',          amenity: 'tourism',          lat: 5.9720, lon: 80.4260, district: 'Matara', description: 'Popular surf school with certified instructors' },
  { name: 'Sun Smile Cafe Weligama',     amenity: 'cafe',             lat: 5.9726, lon: 80.4210, district: 'Matara', description: 'Local cafe with fresh coconut drinks and sea views' },
  { name: 'Stilt Fishermen Viewpoint',   amenity: 'attraction',       lat: 5.9700, lon: 80.4020, district: 'Matara', description: 'Traditional Sri Lankan stilt fishing — iconic photo spot' },
  { name: 'Ahangama Surf Point',         amenity: 'scenic',           lat: 5.9680, lon: 80.3650, district: 'Galle',  description: 'Right-hand reef break, intermediate to advanced surfers' },
  { name: 'Ahangama Beach Bar & Grill',  amenity: 'restaurant',       lat: 5.9678, lon: 80.3630, district: 'Galle',  description: 'Beachfront restaurant with grilled seafood and sunset views' },
  { name: 'Ahangama Surf School',        amenity: 'tourism',          lat: 5.9682, lon: 80.3660, district: 'Galle',  description: 'Certified surf lessons for all levels, board rental available' },
  { name: 'Midigama Left Point',         amenity: 'scenic',           lat: 5.9570, lon: 80.3475, district: 'Galle',  description: 'World-famous left-hand surf break, long rides at high tide' },
  { name: 'Midigama Beach Shacks',       amenity: 'restaurant',       lat: 5.9573, lon: 80.3490, district: 'Galle',  description: 'Casual beachfront eateries serving fresh rice and curry' },
  { name: 'Koggala Lake Boat Safari',    amenity: 'boat_rental',      lat: 5.9780, lon: 80.3105, district: 'Galle',  description: 'Explore Koggala Lake mangroves and cinnamon island by boat' },
  { name: 'Koggala Air Force Museum',    amenity: 'museum',           lat: 5.9800, lon: 80.3050, district: 'Galle',  description: 'Vintage WWII-era aircraft and Sri Lanka Air Force history' },
  { name: 'Habaraduwa Beach',            amenity: 'scenic',           lat: 6.0005, lon: 80.2830, district: 'Galle',  description: 'Quiet local beach with calm water, great for morning swims' },
  { name: 'Kabalana Beach',              amenity: 'scenic',           lat: 6.0065, lon: 80.2700, district: 'Galle',  description: 'Rocky shoreline with excellent snorkeling at low tide' },
  { name: 'Japanese Peace Pagoda',       amenity: 'place_of_worship', lat: 6.0170, lon: 80.2450, district: 'Galle',  description: 'Buddhist stupa on hilltop with panoramic Indian Ocean views' },
  { name: 'Jungle Beach',               amenity: 'scenic',           lat: 6.0148, lon: 80.2490, district: 'Galle',  description: 'Hidden beach through jungle trail, calm shallow lagoon' },
  { name: 'Unawatuna Beach',             amenity: 'scenic',           lat: 6.0100, lon: 80.2500, district: 'Galle',  description: 'Famous crescent beach, great for swimming and snorkeling' },
  { name: 'Rumassala Sanctuary',         amenity: 'forest',           lat: 6.0160, lon: 80.2430, district: 'Galle',  description: 'Jungle reserve with rare medicinal herbs from the Ramayana legend' },
  { name: 'Galle Fort',                  amenity: 'landmark',         lat: 6.0281, lon: 80.2174, district: 'Galle',  description: 'UNESCO World Heritage Site — 17th-century Dutch colonial fort' },
  { name: 'Galle Lighthouse',            amenity: 'landmark',         lat: 6.0245, lon: 80.2163, district: 'Galle',  description: 'Operational lighthouse at the tip of Galle Fort, built 1938' },
];

// ── 33 hazards at real problem spots on A2 (types: pothole | bump) ───────────
const NEW_HAZARDS = [
  // Weligama town
  { lat: 5.9724, lon: 80.4218, type: 'pothole', conf: 0.87, det: 5 },
  { lat: 5.9720, lon: 80.4170, type: 'bump',    conf: 0.91, det: 7 },
  { lat: 5.9716, lon: 80.4130, type: 'pothole', conf: 0.82, det: 4 },
  // Weligama → Ahangama
  { lat: 5.9710, lon: 80.4055, type: 'pothole', conf: 0.79, det: 3 },
  { lat: 5.9701, lon: 80.3980, type: 'bump',    conf: 0.93, det: 8 },
  { lat: 5.9694, lon: 80.3890, type: 'pothole', conf: 0.76, det: 3 },
  { lat: 5.9686, lon: 80.3800, type: 'pothole', conf: 0.83, det: 5 },
  // Ahangama
  { lat: 5.9682, lon: 80.3655, type: 'bump',    conf: 0.95, det: 9 },
  { lat: 5.9678, lon: 80.3600, type: 'pothole', conf: 0.88, det: 6 },
  { lat: 5.9673, lon: 80.3555, type: 'pothole', conf: 0.71, det: 3 },
  // Ahangama → Midigama
  { lat: 5.9630, lon: 80.3520, type: 'pothole', conf: 0.80, det: 4 },
  { lat: 5.9590, lon: 80.3495, type: 'bump',    conf: 0.89, det: 6 },
  // Midigama
  { lat: 5.9573, lon: 80.3481, type: 'bump',    conf: 0.92, det: 8 },
  { lat: 5.9578, lon: 80.3450, type: 'pothole', conf: 0.77, det: 4 },
  // Midigama → Koggala
  { lat: 5.9595, lon: 80.3390, type: 'pothole', conf: 0.83, det: 5 },
  { lat: 5.9635, lon: 80.3300, type: 'pothole', conf: 0.74, det: 3 },
  { lat: 5.9668, lon: 80.3235, type: 'bump',    conf: 0.90, det: 7 },
  // Koggala
  { lat: 5.9725, lon: 80.3165, type: 'pothole', conf: 0.81, det: 4 },
  { lat: 5.9785, lon: 80.3095, type: 'pothole', conf: 0.78, det: 4 },
  { lat: 5.9845, lon: 80.3025, type: 'bump',    conf: 0.86, det: 6 },
  // Habaraduwa
  { lat: 5.9900, lon: 80.2960, type: 'pothole', conf: 0.80, det: 4 },
  { lat: 6.0005, lon: 80.2840, type: 'bump',    conf: 0.93, det: 8 },
  { lat: 6.0010, lon: 80.2810, type: 'pothole', conf: 0.75, det: 3 },
  // Habaraduwa → Unawatuna
  { lat: 6.0042, lon: 80.2765, type: 'pothole', conf: 0.79, det: 4 },
  { lat: 6.0068, lon: 80.2698, type: 'pothole', conf: 0.84, det: 5 },
  { lat: 6.0093, lon: 80.2638, type: 'bump',    conf: 0.91, det: 7 },
  // Unawatuna
  { lat: 6.0115, lon: 80.2575, type: 'pothole', conf: 0.76, det: 3 },
  { lat: 6.0132, lon: 80.2515, type: 'pothole', conf: 0.82, det: 5 },
  // Unawatuna → Galle
  { lat: 6.0170, lon: 80.2435, type: 'bump',    conf: 0.94, det: 8 },
  { lat: 6.0198, lon: 80.2385, type: 'pothole', conf: 0.86, det: 6 },
  { lat: 6.0225, lon: 80.2340, type: 'pothole', conf: 0.78, det: 4 },
  // Galle approach
  { lat: 6.0272, lon: 80.2248, type: 'bump',    conf: 0.92, det: 7 },
  { lat: 6.0292, lon: 80.2210, type: 'pothole', conf: 0.85, det: 5 },
];

// ── Main ──────────────────────────────────────────────────────────────────────
async function seed() {
  const client = new Client({
    user:     process.env.PGUSER,
    host:     process.env.PGHOST,
    database: process.env.PGDATABASE,
    password: process.env.PGPASSWORD,
    port:     Number(process.env.PGPORT || 5432),
    ssl:      { rejectUnauthorized: false },
  });
  await client.connect();
  console.log('Connected to Supabase\n');

  // ── Step 1: fetch all 50 user IDs (already seeded) ──────────────────────
  const { rows: existingUsers } = await client.query('SELECT user_id FROM users');
  const allUserIds = existingUsers.map(r => r.user_id);
  console.log(`✅ Users: ${allUserIds.length} found`);

  // ── Step 2: fix custom_pois sequence, then resolve POI IDs ───────────────
  // Sync sequence to current max so new inserts don't collide with gaps
  await client.query(
    `SELECT setval('custom_pois_id_seq', (SELECT MAX(id) FROM custom_pois))`
  );

  const poiIds = [];
  const poiNames = NEW_POIS.map(p => p.name);
  const { rows: existingPois } = await client.query(
    `SELECT DISTINCT ON (name) id, name, amenity FROM custom_pois
     WHERE name = ANY($1) ORDER BY name, id DESC`,
    [poiNames]
  );
  const existingByName = Object.fromEntries(existingPois.map(r => [r.name, r]));

  for (const p of NEW_POIS) {
    if (existingByName[p.name]) {
      poiIds.push({ id: existingByName[p.name].id, name: p.name, amenity: p.amenity });
    } else {
      const { rows } = await client.query(
        `INSERT INTO custom_pois
           (name, amenity, lat, lon, district, description,
            score, vote_count, voted_devices, geom)
         VALUES ($1,$2,$3,$4,$5,$6,$7,$8,''::text,
                 ST_SetSRID(ST_MakePoint($9,$10),4326))
         RETURNING id`,
        [p.name, p.amenity, p.lat, p.lon, p.district, p.description,
         rand(3.8, 5.0).toFixed(2), randInt(5, 30), p.lon, p.lat]
      );
      poiIds.push({ id: rows[0].id, name: p.name, amenity: p.amenity });
    }
  }
  const existingRoutePois = [
    { id: 15, name: 'Epic Unawatuna',   amenity: 'restaurant'       },
    { id: 16, name: 'Jetty',            amenity: 'boat_rental'      },
    { id: 17, name: 'LemonGrass',       amenity: 'restaurant'       },
    { id: 63, name: 'Chethiya Aramaya', amenity: 'place_of_worship' },
    { id: 64, name: 'Laguna',           amenity: 'cafe'             },
  ];
  const allPois = [...poiIds, ...existingRoutePois];
  console.log(`✅ POIs: ${poiIds.length} resolved (new + existing), ${existingRoutePois.length} route POIs`);

  // ── Step 3: insert 33 hazards + ml_detections + user_confirmations ─────────
  for (const h of NEW_HAZARDS) {
    // raw ML detections
    for (let d = 0; d < h.det; d++) {
      const [jLat, jLon] = jitter(h.lat, h.lon, 15);
      await client.query(
        `INSERT INTO ml_detections
           (latitude, longitude, hazard_type, detection_confidence,
            device_id, processed, processed_at)
         VALUES ($1,$2,$3,$4,$5,TRUE,$6)`,
        [+jLat.toFixed(6), +jLon.toFixed(6), h.type,
         +(h.conf - rand(0, 0.08)).toFixed(3),
         randomUUID(),
         daysAgo(randInt(1, 25))]
      );
    }

    // hazard record
    const confirmCount = randInt(3, 8);
    const denyCount    = randInt(0, 2);
    const status       = h.conf >= 0.80 ? 'verified' : 'pending';
    const { rows: haz } = await client.query(
      `INSERT INTO hazards
         (location, hazard_type, confidence_score, status,
          detection_count, confirmation_count, denial_count,
          first_detected, last_updated, last_confirmed)
       VALUES
         (ST_SetSRID(ST_MakePoint($1,$2),4326),
          $3,$4,$5,$6,$7,$8,$9,$10,$11)
       RETURNING id`,
      [h.lon, h.lat, h.type, h.conf.toFixed(3), status,
       h.det, confirmCount, denyCount,
       daysAgo(randInt(10, 30)),
       daysAgo(randInt(0,  9)),
       daysAgo(randInt(0,  5))]
    );
    const hazardId = haz[0].id;

    // user confirmations (random subset, no duplicates per hazard)
    const shuffled = [...allUserIds].sort(() => Math.random() - 0.5);
    const total    = Math.min(confirmCount + denyCount, shuffled.length);
    for (let c = 0; c < total; c++) {
      await client.query(
        `INSERT INTO user_confirmations
           (hazard_id, user_id, action, timestamp)
         VALUES ($1,$2,$3,$4)
         ON CONFLICT (hazard_id, user_id) DO NOTHING`,
        [hazardId, String(shuffled[c]),
         c < confirmCount ? 'confirm' : 'deny',
         daysAgo(randInt(0, 10))]
      );
    }
  }
  console.log(`✅ Hazards: ${NEW_HAZARDS.length} inserted with detections & confirmations`);

  // ── Step 4: 5 ride sessions per user (250 total) ─────────────────────────
  let rideCount = 0;
  for (const userId of allUserIds) {
    for (let s = 0; s < 5; s++) {
      const seg       = pick(SEGMENTS);
      const track     = segTrack(seg);
      const km        = segKm(seg);
      const speedKmh  = rand(12, 22);
      const startedAt = daysAgo(rand(1, 28));
      const endedAt   = new Date(startedAt.getTime() + (km / speedKmh) * 3_600_000);

      await client.query(
        `INSERT INTO ride_sessions
           (user_id, started_at, ended_at, distance_km, route_mode,
            avg_speed_kmh, gps_track, start_lat, start_lon, end_lat, end_lon)
         VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11)`,
        [userId, startedAt, endedAt, km,
         pick(['shortest', 'safest', 'scenic', 'balanced']),
         +speedKmh.toFixed(2),
         JSON.stringify(track),
         track[0].lat, track[0].lon,
         track[track.length - 1].lat, track[track.length - 1].lon]
      );
      rideCount++;
    }

    // update user stats
    await client.query(
      `UPDATE users
       SET last_active_at     = $1,
           reputation_score   = $2,
           total_contributions= $3
       WHERE user_id = $4`,
      [daysAgo(randInt(0, 3)),
       rand(4.0, 9.8).toFixed(2),
       randInt(5, 50),
       userId]
    );
  }
  console.log(`✅ Ride sessions: ${rideCount} inserted`);

  // ── Step 5: 4-7 poi_visits per user ──────────────────────────────────────
  let visitCount = 0;
  for (const userId of allUserIds) {
    const n      = randInt(4, 7);
    const chosen = [...allPois].sort(() => Math.random() - 0.5).slice(0, n);
    for (const poi of chosen) {
      await client.query(
        `INSERT INTO poi_visits
           (user_id, poi_id, poi_name, poi_category, visited_at, dwell_seconds)
         VALUES ($1,$2,$3,$4,$5,$6)`,
        [userId, poi.id, poi.name, poi.amenity,
         daysAgo(rand(0, 28)), randInt(120, 3600)]
      );
      visitCount++;
    }
  }
  console.log(`✅ POI visits: ${visitCount} inserted`);

  // ── Done ─────────────────────────────────────────────────────────────────
  await client.end();
  console.log('\n🎉 Seed complete! Summary:');
  console.log(`   Users:        ${allUserIds.length} total`);
  console.log(`   POIs:         ${poiIds.length} new custom POIs added`);
  console.log(`   Hazards:      ${NEW_HAZARDS.length} new along Weligama-Galle route`);
  console.log(`   Ride sessions:${rideCount}`);
  console.log(`   POI visits:   ${visitCount}`);
}

seed().catch(e => { console.error('FATAL:', e.message); process.exit(1); });
