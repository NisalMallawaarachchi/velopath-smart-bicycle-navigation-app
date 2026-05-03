/* ═══════════════════════════════════════════════════════════════════════════
   VeloPath Admin Dashboard — dashboard.js
   ═══════════════════════════════════════════════════════════════════════════ */

const API = "";          // same origin
let TOKEN  = null;
let currentPage = 1;
let currentFilters = {};
let hazardMap = null, userMap = null;
let chartInstances = {};

// ── Utilities ─────────────────────────────────────────────────────────────────
const $ = id => document.getElementById(id);
const fmt = {
  date:   v => v ? new Date(v).toLocaleDateString() : "—",
  num:    v => (v == null || v === "") ? "—" : Number(v).toLocaleString(),
  pct:    v => v == null ? "—" : v + "%",
  km:     v => v == null ? "—" : Number(v).toFixed(1) + " km",
  score:  v => v == null ? "—" : Number(v).toFixed(2),
};

async function api(path, options = {}) {
  const res = await fetch(API + path, {
    ...options,
    headers: {
      "Content-Type": "application/json",
      "Authorization": "Bearer " + TOKEN,
      ...(options.headers || {}),
    },
  });
  if (!res.ok) {
    const err = await res.json().catch(() => ({ error: res.statusText }));
    throw new Error(err.error || res.statusText);
  }
  return res.json();
}

function destroyChart(key) {
  if (chartInstances[key]) {
    chartInstances[key].destroy();
    delete chartInstances[key];
  }
}

function statusBadge(status) {
  const map = { active: "green", inactive: "muted", verified: "green", pending: "yellow", expired: "red", synced: "green", exported: "yellow" };
  return `<span class="badge badge-${map[status] || "muted"}">${status}</span>`;
}

// ── Login ─────────────────────────────────────────────────────────────────────
$("login-form").addEventListener("submit", async e => {
  e.preventDefault();
  const email    = $("login-email").value.trim();
  const password = $("login-password").value;
  try {
    const data = await fetch(API + "/admin/login", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ email, password }),
    }).then(r => r.json());

    if (data.token) {
      TOKEN = data.token;
      $("admin-email-display").textContent = email;
      $("login-screen").style.display = "none";
      $("app").style.display           = "flex";
      navigateTo("users");
    } else {
      $("login-error").textContent = data.error || "Login failed";
    }
  } catch {
    $("login-error").textContent = "Server unreachable";
  }
});

$("logout-btn").addEventListener("click", () => {
  TOKEN = null;
  $("login-screen").style.display = "flex";
  $("app").style.display           = "none";
});

// ── Navigation ────────────────────────────────────────────────────────────────
function navigateTo(page, data = null) {
  document.querySelectorAll(".page").forEach(p => p.classList.remove("active"));
  document.querySelectorAll(".nav-item").forEach(n => n.classList.remove("active"));
  const pageEl = $(`page-${page}`);
  if (pageEl) pageEl.classList.add("active");
  const navEl = document.querySelector(`[data-page="${page}"]`);
  if (navEl) navEl.classList.add("active");

  $("topbar-title").textContent = {
    users: "User Overview", analytics: "Preference Analytics",
    map: "Hazard & Road Quality Map", system: "System Health",
    "user-profile": "User Profile",
  }[page] || "Dashboard";

  switch (page) {
    case "users":       loadUsers();         break;
    case "analytics":   loadAnalytics();     break;
    case "map":         loadHazardMap();     break;
    case "system":      loadSystemHealth();  break;
    case "user-profile": loadUserProfile(data); break;
  }
}

document.querySelectorAll(".nav-item").forEach(item => {
  item.addEventListener("click", () => navigateTo(item.dataset.page));
});

// ════════════════════════════════════════════════════════════════════════════
// PAGE 1 — USER OVERVIEW
// ════════════════════════════════════════════════════════════════════════════
async function loadUsers(page = 1) {
  currentPage = page;
  const tbody = $("users-tbody");
  tbody.innerHTML = `<tr><td colspan="11" class="loading"><div class="spinner"></div></td></tr>`;

  const params = new URLSearchParams({
    page,
    limit: 20,
    ...(currentFilters.country   && { country:   currentFilters.country }),
    ...(currentFilters.active    && { active:     currentFilters.active }),
    ...(currentFilters.dateFrom  && { dateFrom:   currentFilters.dateFrom }),
    ...(currentFilters.dateTo    && { dateTo:     currentFilters.dateTo }),
    ...(currentFilters.search    && { search:     currentFilters.search }),
  });

  try {
    const { data, total } = await api(`/admin/users?${params}`);
    tbody.innerHTML = "";

    if (!data.length) {
      tbody.innerHTML = `<tr><td colspan="11" class="loading text-muted">No users found</td></tr>`;
      return;
    }

    data.forEach(u => {
      const tr = document.createElement("tr");
      tr.innerHTML = `
        <td><span class="text-muted" style="font-size:11px;font-family:monospace">${u.user_id.slice(0,8)}…</span></td>
        <td>${u.username}</td>
        <td>${u.email}</td>
        <td>${u.country || "—"}</td>
        <td>${fmt.date(u.created_at)}</td>
        <td>${fmt.num(u.total_rides)}</td>
        <td>${fmt.km(u.total_distance_km)}</td>
        <td>${fmt.num(u.hazards_reported)}</td>
        <td>${fmt.date(u.last_active_at)}</td>
        <td>${statusBadge(u.account_status)}</td>
        <td>
          <button class="btn btn-sm" onclick="navigateTo('user-profile','${u.user_id}')">Profile</button>
          <button class="btn btn-sm" onclick="exportUserCSV('${u.user_id}')">CSV</button>
          <button class="btn btn-sm ${u.flagged_for_travalia ? 'btn-green' : ''}"
            onclick="toggleTravalia('${u.user_id}', ${!u.flagged_for_travalia}, this)">
            ${u.flagged_for_travalia ? '✓ Flagged' : 'Flag'}
          </button>
        </td>`;
      tbody.appendChild(tr);
    });

    const totalPages = Math.ceil(total / 20);
    $("pagination-info").textContent = `${(page-1)*20+1}–${Math.min(page*20, total)} of ${total}`;
    $("page-prev").disabled = page <= 1;
    $("page-next").disabled = page >= totalPages;
    $("page-prev").onclick = () => loadUsers(page - 1);
    $("page-next").onclick = () => loadUsers(page + 1);
  } catch (e) {
    tbody.innerHTML = `<tr><td colspan="11" class="text-red">${e.message}</td></tr>`;
  }
}

async function toggleTravalia(userId, flag, btn) {
  await api(`/admin/users/${userId}/flag-travalia`, {
    method: "PATCH",
    body: JSON.stringify({ flag }),
  });
  btn.textContent = flag ? "✓ Flagged" : "Flag";
  btn.classList.toggle("btn-green", flag);
}

async function exportUserCSV(userId) {
  window.location = API + `/admin/users/${userId}/export-csv?token=${TOKEN}`;
}

// Search / filter wire-up
$("user-search").addEventListener("input", e => {
  currentFilters.search = e.target.value;
  loadUsers(1);
});
$("filter-country").addEventListener("change", e => {
  currentFilters.country = e.target.value;
  loadUsers(1);
});
$("filter-active").addEventListener("change", e => {
  currentFilters.active = e.target.value;
  loadUsers(1);
});
$("filter-date-from").addEventListener("change", e => {
  currentFilters.dateFrom = e.target.value;
  loadUsers(1);
});
$("filter-date-to").addEventListener("change", e => {
  currentFilters.dateTo = e.target.value;
  loadUsers(1);
});
$("export-csv-btn").addEventListener("click", () => {
  window.location = API + `/admin/export/users-csv`;
});

// ════════════════════════════════════════════════════════════════════════════
// PAGE 2 — USER PROFILE
// ════════════════════════════════════════════════════════════════════════════
async function loadUserProfile(userId) {
  if (!userId) return;
  $("profile-content").innerHTML = `<div class="loading"><div class="spinner"></div> Loading profile…</div>`;

  try {
    const d = await api(`/admin/users/${userId}`);
    const u = d.personal;
    const r = d.ridingPreferences;
    const poi = d.poiInterests;
    const haz = d.hazardBehavior;
    const tc  = d.travaliaCard;

    $("profile-content").innerHTML = `
    <!-- Back -->
    <span class="back-btn" onclick="navigateTo('users')">← Back to Users</span>

    <!-- Section A: Personal Info -->
    <div class="card">
      <h3>Personal Info</h3>
      <div class="info-row"><span class="k">User ID</span><span class="v" style="font-family:monospace;font-size:11px">${u.user_id}</span></div>
      <div class="info-row"><span class="k">Name</span><span class="v">${u.username}</span></div>
      <div class="info-row"><span class="k">Email</span><span class="v">${u.email}</span></div>
      <div class="info-row"><span class="k">Country</span><span class="v">${u.country || "—"}</span></div>
      <div class="info-row"><span class="k">Device Type</span><span class="v">${u.device_type || "—"}</span></div>
      <div class="info-row"><span class="k">App Version</span><span class="v">${u.app_version || "—"}</span></div>
      <div class="info-row"><span class="k">Joined</span><span class="v">${fmt.date(u.created_at)}</span></div>
      <div class="info-row"><span class="k">Last Active</span><span class="v">${fmt.date(u.last_active_at)}</span></div>
      <div class="info-row"><span class="k">Reputation</span><span class="v">${fmt.score(u.reputation_score)}</span></div>
    </div>

    <!-- Section B: Riding Preferences -->
    <div class="card">
      <h3>Riding Preferences</h3>
      ${r.totalRides === 0 ? '<p class="text-muted">No ride sessions recorded yet — requires app update to log sessions.</p>' : `
      <div class="profile-grid">
        <div>
          <div class="info-row"><span class="k">Total Rides</span><span class="v">${fmt.num(r.totalRides)}</span></div>
          <div class="info-row"><span class="k">Avg Distance</span><span class="v">${fmt.km(r.avgDistanceKm)}</span></div>
          <div class="info-row"><span class="k">Total Distance</span><span class="v">${fmt.km(r.totalDistanceKm)}</span></div>
          <div class="info-row"><span class="k">Avg Speed</span><span class="v">${r.avgSpeedKmh} km/h</span></div>
          <div class="info-row"><span class="k">Speed Profile</span><span class="v">${r.speedProfile}</span></div>
          <div class="info-row"><span class="k">Dominant Mode</span><span class="v"><span class="badge badge-blue">${r.dominantMode}</span></span></div>
        </div>
        <div>
          <p class="text-muted" style="font-size:12px;margin-bottom:8px">Route mode breakdown</p>
          <div class="chart-container"><canvas id="chart-route-mode"></canvas></div>
        </div>
      </div>
      <div class="mt16">
        <p class="text-muted" style="font-size:12px;margin-bottom:8px">Preferred riding hours</p>
        <div class="chart-container"><canvas id="chart-time-of-day"></canvas></div>
      </div>
      `}
    </div>

    <!-- Section C: POI Interests -->
    <div class="card">
      <h3>POI Interests</h3>
      ${poi.breakdown.length === 0 ? '<p class="text-muted">No POI visits recorded yet.</p>' : `
      <div class="profile-grid">
        <div>
          <table><thead><tr><th>Category</th><th>Visits</th><th>Engagement</th></tr></thead><tbody>
          ${poi.breakdown.map(p => `<tr>
            <td>${p.poi_category}</td>
            <td>${fmt.num(p.visit_count)}</td>
            <td>${Math.round(p.engagement_score)}</td>
          </tr>`).join("")}
          </tbody></table>
          <div class="mt8 text-muted" style="font-size:12px">Loyalty Points: <b class="text-yellow">${fmt.num(poi.loyaltyPoints)}</b></div>
        </div>
        <div class="radar-wrap"><canvas id="chart-poi-radar"></canvas></div>
      </div>
      `}
    </div>

    <!-- Section D: Hazard Behavior -->
    <div class="card">
      <h3>Hazard Behavior</h3>
      <div class="profile-grid">
        <div>
          <div class="info-row"><span class="k">Confirmations Given</span><span class="v text-green">${fmt.num(haz.confirmationsGiven)}</span></div>
          <div class="info-row"><span class="k">Denials Given</span><span class="v text-red">${fmt.num(haz.denialsGiven)}</span></div>
          <div class="info-row"><span class="k">Total Responses</span><span class="v">${fmt.num(haz.totalResponses)}</span></div>
          <div class="info-row"><span class="k">Confirmation Rate</span><span class="v">${fmt.pct(haz.confirmationRate)}</span></div>
        </div>
        <div>
          <div class="info-row"><span class="k">Pothole responses</span><span class="v">${fmt.num(haz.byType.pothole)}</span></div>
          <div class="info-row"><span class="k">Bump responses</span><span class="v">${fmt.num(haz.byType.bump)}</span></div>
          <div class="info-row"><span class="k">Rough responses</span><span class="v">${fmt.num(haz.byType.rough)}</span></div>
        </div>
      </div>
    </div>

    <!-- Section E: Geographic Heatmap -->
    <div class="card">
      <h3>Geographic Activity</h3>
      ${r.totalRides === 0 ? '<p class="text-muted">No GPS data — requires ride session logging.</p>' : `
      <div id="user-map" style="height:320px;border-radius:8px;overflow:hidden"></div>
      `}
    </div>

    <!-- Section F: Travalia Export Card -->
    <div class="card">
      <h3>Travalia Export Card</h3>
      <div class="travalia-card" id="travalia-json">${JSON.stringify(tc, null, 2)}</div>
      <div class="export-actions">
        <button class="btn btn-accent" onclick="pushTravalia('${u.user_id}')">Push to Travalia DB</button>
        <button class="btn" onclick="exportTravaliaJSON('${u.user_id}')">Export as JSON</button>
        <button class="btn ${u.flagged_for_travalia ? 'btn-green' : ''}" id="flag-btn-${u.user_id}"
          onclick="toggleTravalia('${u.user_id}', ${!u.flagged_for_travalia}, this)">
          ${u.flagged_for_travalia ? '✓ Flagged for Travalia' : 'Flag for Travalia'}
        </button>
      </div>
    </div>
    `;

    // Charts
    if (r.totalRides > 0) {
      destroyChart("route-mode");
      const ctxRM = document.getElementById("chart-route-mode");
      if (ctxRM) {
        chartInstances["route-mode"] = new Chart(ctxRM, {
          type: "doughnut",
          data: {
            labels: Object.keys(r.routePreferences),
            datasets: [{ data: Object.values(r.routePreferences), backgroundColor: ["#6c63ff","#43d9a0","#ff6584","#f5c842"] }]
          },
          options: { responsive: true, maintainAspectRatio: false, plugins: { legend: { position: "right", labels: { color: "#e2e8f0" } } } }
        });
      }

      destroyChart("time-of-day");
      const ctxTD = document.getElementById("chart-time-of-day");
      if (ctxTD) {
        chartInstances["time-of-day"] = new Chart(ctxTD, {
          type: "bar",
          data: {
            labels: ["Morning", "Afternoon", "Evening"],
            datasets: [{ label: "Rides", data: [r.timeOfDay.morning, r.timeOfDay.afternoon, r.timeOfDay.evening], backgroundColor: ["#f5c842","#ff6584","#6c63ff"] }]
          },
          options: { responsive: true, maintainAspectRatio: false, scales: { y: { beginAtZero: true, ticks: { color: "#8892a4" }, grid: { color: "#2e3150" } }, x: { ticks: { color: "#8892a4" }, grid: { color: "#2e3150" } } }, plugins: { legend: { display: false } } }
        });
      }

      // Init user GPS map
      if (window.L) {
        setTimeout(() => {
          if (userMap) { userMap.remove(); userMap = null; }
          userMap = L.map("user-map").setView([7.8731, 80.7718], 8);
          L.tileLayer("https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png", {
            attribution: "© OpenStreetMap contributors", opacity: 0.7
          }).addTo(userMap);

          const recentRides = r.recentRides || [];
          recentRides.forEach(ride => {
            if (ride.start_lat && ride.start_lon) {
              L.circleMarker([ride.start_lat, ride.start_lon], { radius: 5, color: "#43d9a0", fillOpacity: .8 })
               .addTo(userMap).bindPopup(`Start — ${fmt.date(ride.started_at)}`);
            }
            if (ride.end_lat && ride.end_lon) {
              L.circleMarker([ride.end_lat, ride.end_lon], { radius: 5, color: "#ff5e5e", fillOpacity: .8 })
               .addTo(userMap).bindPopup(`End — ${fmt.date(ride.started_at)}`);
            }
            if (ride.gps_track && Array.isArray(ride.gps_track)) {
              const pts = ride.gps_track.map(p => [p.lat, p.lon]).filter(p => p[0] && p[1]);
              if (pts.length > 1) L.polyline(pts, { color: "#6c63ff", weight: 2, opacity: .6 }).addTo(userMap);
            }
          });
        }, 100);
      }
    }

    // POI radar chart
    if (poi.breakdown.length > 0) {
      destroyChart("poi-radar");
      const ctxR = document.getElementById("chart-poi-radar");
      if (ctxR) {
        chartInstances["poi-radar"] = new Chart(ctxR, {
          type: "radar",
          data: {
            labels: poi.breakdown.map(p => p.poi_category),
            datasets: [{
              label: "Engagement",
              data: poi.breakdown.map(p => Math.round(p.engagement_score)),
              backgroundColor: "rgba(108,99,255,.2)",
              borderColor: "#6c63ff",
              pointBackgroundColor: "#6c63ff",
            }]
          },
          options: {
            responsive: true, maintainAspectRatio: true,
            scales: { r: { ticks: { display: false }, grid: { color: "#2e3150" }, pointLabels: { color: "#e2e8f0", font: { size: 11 } } } },
            plugins: { legend: { display: false } }
          }
        });
      }
    }

  } catch (e) {
    $("profile-content").innerHTML = `<p class="text-red">${e.message}</p>`;
  }
}

async function pushTravalia(userId) {
  try {
    const r = await api(`/admin/export/users/${userId}/push-travalia`, { method: "POST" });
    alert(r.travaResponse?.stubbed ? "Stubbed: Travalia API not yet configured. Record logged locally." : "Pushed to Travalia!");
  } catch (e) {
    alert("Error: " + e.message);
  }
}

function exportTravaliaJSON(userId) {
  const el = $("travalia-json");
  if (!el) return;
  const blob = new Blob([el.textContent], { type: "application/json" });
  const a = document.createElement("a");
  a.href = URL.createObjectURL(blob);
  a.download = `travalia_${userId}.json`;
  a.click();
}

// ════════════════════════════════════════════════════════════════════════════
// PAGE 3 — PREFERENCE ANALYTICS
// ════════════════════════════════════════════════════════════════════════════
let analyticsTab = "countries";

async function loadAnalytics() {
  switchAnalyticsTab(analyticsTab);
}

function switchAnalyticsTab(tab) {
  analyticsTab = tab;
  document.querySelectorAll("#page-analytics .tab").forEach(t =>
    t.classList.toggle("active", t.dataset.tab === tab)
  );
  switch (tab) {
    case "countries":  loadCountryAnalytics(); break;
    case "poi-trends": loadPoiTrends();        break;
    case "routes":     loadRouteModes();       break;
    case "travalia":   loadTravaliaSyncPanel(); break;
  }
}

async function loadCountryAnalytics() {
  const el = $("analytics-content");
  el.innerHTML = `<div class="loading"><div class="spinner"></div></div>`;
  try {
    const { table, poiBreakdown } = await api("/admin/analytics/countries");

    const countries = table.map(r => r.country);
    const poiCats   = [...new Set(Object.values(poiBreakdown).flatMap(Object.keys))];
    const colors    = ["#6c63ff","#43d9a0","#ff6584","#f5c842","#ff9f40","#4bc0c0","#c9cbcf","#ff6384"];

    el.innerHTML = `
    <div class="card">
      <h3>Country-wise POI Preferences</h3>
      <div class="chart-container" style="height:300px"><canvas id="chart-country-poi"></canvas></div>
    </div>
    <div class="card">
      <h3>Country Summary Table</h3>
      <div class="table-wrap"><table>
        <thead><tr><th>Country</th><th>Users</th><th>Avg Distance</th><th>Top Route Mode</th><th>Top POI</th><th>Avg Reputation</th></tr></thead>
        <tbody>
        ${table.map(r => `<tr>
          <td>${r.country}</td>
          <td>${fmt.num(r.user_count)}</td>
          <td>${fmt.km(r.avg_distance_km)}</td>
          <td>${r.top_route_mode || "—"}</td>
          <td>${r.top_poi_category || "—"}</td>
          <td>${fmt.score(r.avg_reputation)}</td>
        </tr>`).join("")}
        </tbody>
      </table></div>
    </div>`;

    destroyChart("country-poi");
    chartInstances["country-poi"] = new Chart($("chart-country-poi"), {
      type: "bar",
      data: {
        labels: countries,
        datasets: poiCats.slice(0,8).map((cat, i) => ({
          label: cat,
          data: countries.map(c => poiBreakdown[c]?.[cat] || 0),
          backgroundColor: colors[i % colors.length],
        }))
      },
      options: {
        responsive: true, maintainAspectRatio: false,
        scales: {
          x: { stacked: true, ticks: { color: "#8892a4" }, grid: { color: "#2e3150" } },
          y: { stacked: true, ticks: { color: "#8892a4" }, grid: { color: "#2e3150" } }
        },
        plugins: { legend: { labels: { color: "#e2e8f0", font: { size: 11 } } } }
      }
    });
  } catch (e) {
    el.innerHTML = `<p class="text-red">${e.message}</p>`;
  }
}

async function loadPoiTrends() {
  const el = $("analytics-content");
  el.innerHTML = `<div class="loading"><div class="spinner"></div></div>`;
  try {
    const { series, months } = await api("/admin/analytics/poi-trends?months=6");
    const labels = months.map(m => new Date(m).toLocaleDateString("en", { month: "short", year: "2-digit" }));
    const colors = ["#6c63ff","#43d9a0","#ff6584","#f5c842","#ff9f40","#4bc0c0","#c9cbcf","#ff6384"];

    el.innerHTML = `
    <div class="card">
      <h3>POI Category Visits — Last 6 Months</h3>
      ${series.length === 0 ? '<p class="text-muted">No POI visit data yet.</p>' : `
      <div class="chart-container" style="height:300px"><canvas id="chart-poi-trends"></canvas></div>`}
    </div>`;

    if (series.length) {
      destroyChart("poi-trends");
      chartInstances["poi-trends"] = new Chart($("chart-poi-trends"), {
        type: "line",
        data: {
          labels,
          datasets: series.map((s, i) => ({
            label: s.category,
            data: s.data.map(d => d.visits),
            borderColor: colors[i % colors.length],
            backgroundColor: colors[i % colors.length] + "22",
            tension: 0.3, fill: true,
          }))
        },
        options: {
          responsive: true, maintainAspectRatio: false,
          scales: {
            x: { ticks: { color: "#8892a4" }, grid: { color: "#2e3150" } },
            y: { beginAtZero: true, ticks: { color: "#8892a4" }, grid: { color: "#2e3150" } }
          },
          plugins: { legend: { labels: { color: "#e2e8f0" } } }
        }
      });
    }
  } catch (e) {
    el.innerHTML = `<p class="text-red">${e.message}</p>`;
  }
}

async function loadRouteModes() {
  const el = $("analytics-content");
  el.innerHTML = `<div class="loading"><div class="spinner"></div></div>`;
  try {
    const { overall, byCountry } = await api("/admin/analytics/route-modes");

    el.innerHTML = `
    <div class="profile-grid">
      <div class="card">
        <h3>Overall Route Mode Distribution</h3>
        ${overall.length === 0 ? '<p class="text-muted">No route data yet.</p>' : `
        <div class="chart-container"><canvas id="chart-mode-pie"></canvas></div>`}
      </div>
      <div class="card">
        <h3>By Country</h3>
        <div class="table-wrap"><table>
          <thead><tr><th>Country</th><th>Mode</th><th>Rides</th></tr></thead>
          <tbody>
          ${byCountry.map(r => `<tr><td>${r.country}</td><td>${r.route_mode}</td><td>${r.count}</td></tr>`).join("")}
          </tbody>
        </table></div>
      </div>
    </div>`;

    if (overall.length) {
      destroyChart("mode-pie");
      chartInstances["mode-pie"] = new Chart($("chart-mode-pie"), {
        type: "doughnut",
        data: {
          labels: overall.map(r => r.route_mode),
          datasets: [{ data: overall.map(r => r.count), backgroundColor: ["#6c63ff","#43d9a0","#ff6584","#f5c842"] }]
        },
        options: {
          responsive: true, maintainAspectRatio: false,
          plugins: { legend: { position: "right", labels: { color: "#e2e8f0" } } }
        }
      });
    }
  } catch (e) {
    el.innerHTML = `<p class="text-red">${e.message}</p>`;
  }
}

async function loadTravaliaSyncPanel() {
  const el = $("analytics-content");
  el.innerHTML = `<div class="loading"><div class="spinner"></div></div>`;
  try {
    const users = await api("/admin/export/flagged-users");

    el.innerHTML = `
    <div class="card">
      <div class="flex-between" style="margin-bottom:16px">
        <h3 style="margin:0">Travalia Flagged Users</h3>
        <div style="display:flex;gap:10px">
          <button class="btn btn-green" onclick="exportTravaliaJSONL()">Export All as JSONL</button>
          <button class="btn btn-accent" onclick="syncAllTravalia()">Sync All to Travalia</button>
        </div>
      </div>
      <div id="last-sync-info" class="text-muted mt8" style="font-size:12px;margin-bottom:12px"></div>
      <div class="table-wrap"><table>
        <thead><tr><th>User</th><th>Email</th><th>Country</th><th>Status</th><th>Last Pushed</th></tr></thead>
        <tbody>
        ${users.length === 0 ? '<tr><td colspan="5" class="text-muted">No users flagged yet</td></tr>' :
          users.map(u => `<tr>
            <td>${u.username}</td>
            <td>${u.email}</td>
            <td>${u.country || "—"}</td>
            <td>${statusBadge(u.travalia_status || "pending")}</td>
            <td>${fmt.date(u.travalia_pushed_at)}</td>
          </tr>`).join("")}
        </tbody>
      </table></div>
    </div>`;
  } catch (e) {
    el.innerHTML = `<p class="text-red">${e.message}</p>`;
  }
}

function exportTravaliaJSONL() {
  window.open(API + "/admin/export/travalia", "_blank");
}

async function syncAllTravalia() {
  if (!confirm("Sync all flagged users to Travalia API?")) return;
  try {
    const r = await api("/admin/export/sync-travalia", { method: "POST" });
    alert(`Synced ${r.synced} users. (Stub mode active — no actual API call yet.)`);
    loadTravaliaSyncPanel();
  } catch (e) {
    alert("Error: " + e.message);
  }
}

// Analytics tab wiring
document.querySelectorAll("#page-analytics .tab").forEach(t => {
  t.addEventListener("click", () => switchAnalyticsTab(t.dataset.tab));
});

// ════════════════════════════════════════════════════════════════════════════
// PAGE 4 — HAZARD MAP
// ════════════════════════════════════════════════════════════════════════════
const HAZARD_COLORS = { pothole: "#ff5e5e", bump: "#f5c842", rough: "#ff9f40" };

async function loadHazardMap() {
  if (!hazardMap) {
    hazardMap = L.map("map-container").setView([7.8731, 80.7718], 8);
    L.tileLayer("https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png", {
      attribution: "© OpenStreetMap contributors", opacity: 0.7
    }).addTo(hazardMap);
  }
  applyHazardFilters();
}

let hazardLayer = null;

async function applyHazardFilters() {
  const params = new URLSearchParams();
  const type  = $("map-filter-type").value;
  const minC  = $("map-filter-confidence").value;
  const from  = $("map-filter-from").value;
  const to    = $("map-filter-to").value;
  const stat  = $("map-filter-status").value;
  if (type)  params.set("type", type);
  if (minC)  params.set("minConfidence", minC);
  if (from)  params.set("dateFrom", from);
  if (to)    params.set("dateTo", to);
  if (stat)  params.set("status", stat);

  try {
    const hazards = await api(`/admin/hazards?${params}`);
    if (hazardLayer) hazardMap.removeLayer(hazardLayer);

    hazardLayer = L.layerGroup();
    hazards.forEach(h => {
      if (!h.lat || !h.lon) return;
      const color = HAZARD_COLORS[h.hazard_type] || "#8892a4";
      const radius = 6 + parseFloat(h.confidence_score) * 8;
      L.circleMarker([h.lat, h.lon], {
        radius, color, fillColor: color, fillOpacity: 0.6, weight: 1,
      }).bindPopup(`
        <b>${h.hazard_type.toUpperCase()}</b><br>
        Confidence: <b>${(parseFloat(h.confidence_score)*100).toFixed(0)}%</b><br>
        Status: ${h.status}<br>
        Detections: ${h.detection_count}<br>
        Confirms: ${h.confirmation_count} | Denials: ${h.denial_count}<br>
        First detected: ${fmt.date(h.first_detected)}<br>
        ${h.reporters ? `Reporters: ${h.reporters.length}` : ""}
      `).addTo(hazardLayer);
    });

    hazardLayer.addTo(hazardMap);
    $("hazard-count").textContent = `${hazards.length} hazards shown`;
  } catch (e) {
    console.error(e);
  }
}

$("map-filter-btn").addEventListener("click", applyHazardFilters);
$("map-export-geojson").addEventListener("click", () => {
  window.open(API + "/admin/export/hazards-geojson", "_blank");
});

// ════════════════════════════════════════════════════════════════════════════
// PAGE 5 — SYSTEM HEALTH
// ════════════════════════════════════════════════════════════════════════════
async function loadSystemHealth() {
  const el = $("system-content");
  el.innerHTML = `<div class="loading"><div class="spinner"></div></div>`;
  try {
    const d = await api("/admin/analytics/system-health");

    el.innerHTML = `
    <div class="stat-grid">
      <div class="stat-card"><div class="label">Total Users</div><div class="value">${fmt.num(d.users.total_users)}</div><div class="sub">+${d.users.new_today} today</div></div>
      <div class="stat-card"><div class="label">Active (24h)</div><div class="value">${fmt.num(d.users.active_24h)}</div></div>
      <div class="stat-card"><div class="label">Active (7d)</div><div class="value">${fmt.num(d.users.active_7d)}</div></div>
      <div class="stat-card"><div class="label">Active (30d)</div><div class="value">${fmt.num(d.users.active_30d)}</div></div>
      <div class="stat-card"><div class="label">Total Hazards</div><div class="value">${fmt.num(d.hazards.total_hazards)}</div><div class="sub">+${d.hazards.detected_today} today</div></div>
      <div class="stat-card"><div class="label">Verified</div><div class="value text-green">${fmt.num(d.hazards.verified)}</div></div>
      <div class="stat-card"><div class="label">Pending</div><div class="value text-yellow">${fmt.num(d.hazards.pending)}</div></div>
      <div class="stat-card"><div class="label">Total Rides</div><div class="value">${fmt.num(d.rides.total_rides)}</div><div class="sub">+${d.rides.rides_today} today</div></div>
    </div>

    <div class="profile-grid">
      <div class="card">
        <h3>Cron & Sync Status</h3>
        <div class="info-row"><span class="k">Last Decay Run</span><span class="v">${d.lastDecayRun ? new Date(d.lastDecayRun).toLocaleString() : "—"}</span></div>
        <div class="info-row"><span class="k">Last Travalia Sync</span><span class="v">${d.lastTravaliaSync ? new Date(d.lastTravaliaSync.last_sync).toLocaleString() + " (" + d.lastTravaliaSync.user_count + " users)" : "—"}</span></div>
        <div class="info-row"><span class="k">Sync Status</span><span class="v">${d.lastTravaliaSync ? statusBadge(d.lastTravaliaSync.status) : "—"}</span></div>
      </div>
      <div class="card">
        <h3>ML Model</h3>
        ${d.mlModel ? `
        <div class="info-row"><span class="k">Accuracy</span><span class="v text-green">${d.mlModel.accuracy ? (d.mlModel.accuracy*100).toFixed(1)+"%" : "—"}</span></div>
        <div class="info-row"><span class="k">CV Mean</span><span class="v">${d.mlModel.cv_mean ? (d.mlModel.cv_mean*100).toFixed(1)+"%" : "—"}</span></div>
        <div class="info-row"><span class="k">Train samples</span><span class="v">${fmt.num(d.mlModel.n_train)}</span></div>
        <div class="info-row"><span class="k">Test samples</span><span class="v">${fmt.num(d.mlModel.n_test)}</span></div>
        <div class="info-row"><span class="k">Trained at</span><span class="v">${d.mlModel.timestamp ? new Date(d.mlModel.timestamp).toLocaleString() : "—"}</span></div>
        ` : '<p class="text-muted">No model training log found. Run train_model.py to generate.</p>'}
      </div>
    </div>`;
  } catch (e) {
    el.innerHTML = `<p class="text-red">${e.message}</p>`;
  }
}
