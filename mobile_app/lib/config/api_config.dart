class ApiConfig {
  static const String baseUrl = "http://10.255.73.44:5001";

  static const String pois = "$baseUrl/api/pois";
  static String poiById(dynamic id) => "$baseUrl/api/pois/$id";
  static String votePoi(dynamic id) => "$baseUrl/api/pois/$id/vote";
  static String dashboard(String deviceId) =>
      "$baseUrl/api/dashboard/$deviceId";
  
static String getComments(dynamic poiId) => "$baseUrl/api/pois/$poiId/comments";
static String addComment(dynamic poiId) => "$baseUrl/api/pois/$poiId/comments";

static const String rankedPois = "$baseUrl/api/pois/ranked";

static String notifications(String deviceId) =>
    "$baseUrl/api/pois/notifications/$deviceId";
}
