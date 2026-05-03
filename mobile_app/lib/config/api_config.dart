class ApiConfig {
  // ── Base URL (Railway deployment) ────────────────
  static const String baseUrl =
      "https://velopath-smart-bicycle-navigation-app-production-b3f2.up.railway.app";

  // ── POI ──────────────────────────────────────────
  static const String pois = "$baseUrl/api/pois";
  static String poiById(dynamic id) => "$baseUrl/api/pois/$id";
  static String votePoi(dynamic id) => "$baseUrl/api/pois/$id/vote";
  static String dashboard(String deviceId) =>
      "$baseUrl/api/dashboard/$deviceId";
  static String getComments(dynamic poiId) =>
      "$baseUrl/api/pois/$poiId/comments";
  static String addComment(dynamic poiId) =>
      "$baseUrl/api/pois/$poiId/comments";
  static const String rankedPois = "$baseUrl/api/pois/ranked";
  static String poiNotifications(String deviceId) =>
      "$baseUrl/api/pois/notifications/$deviceId";

  // ── Auth ─────────────────────────────────────────
  static const String login = "$baseUrl/api/auth/login";
  static const String register = "$baseUrl/api/auth/register";
  static const String googleAuth = "$baseUrl/api/auth/google";
  static const String profile = "$baseUrl/api/auth/me";

  // ── Hazards ──────────────────────────────────────
  static const String hazards = "$baseUrl/api/hazards";
  static String hazardById(dynamic id) => "$baseUrl/api/hazards/$id";
  static String confirmHazard(dynamic id) =>
      "$baseUrl/api/hazards/$id/confirm";
  static String denyHazard(dynamic id) => "$baseUrl/api/hazards/$id/deny";
  static const String hazardStats = "$baseUrl/api/hazards/stats";

  // ── Notifications ────────────────────────────────
  static const String approachingHazards =
      "$baseUrl/api/notifications/approaching";
  static const String passedHazards = "$baseUrl/api/notifications/passed";
  static String respondToHazard(dynamic id) =>
      "$baseUrl/api/notifications/$id/respond";

  // ── Routing ──────────────────────────────────────
  static const String route = "$baseUrl/api/pg-routing/route";

  // ── ML Hazard Detection ──────────────────────────
  static const String mlHazardHealth = "$baseUrl/api/hazard/health";
  static const String mlHazardPredict = "$baseUrl/api/hazard/predict";
  static const String mlHazardUpload = "$baseUrl/api/hazard/upload";

  // ── Google Auth ──────────────────────────────────
  static const String googleWebClientId =
      "1054900919770-27du4a0p06nq0bl0nn1lajsgr6l89p35.apps.googleusercontent.com";
}
