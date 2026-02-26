class ApiConfig {
  static const String baseUrl = "http://10.75.197.45:5001";

  static const String pois = "$baseUrl/api/pois";
  static String poiById(dynamic id) => "$baseUrl/api/pois/$id";
  static String votePoi(dynamic id) => "$baseUrl/api/pois/$id/vote";
  static String dashboard(String deviceId) =>
      "$baseUrl/api/dashboard/$deviceId";
  
static String getComments(dynamic poiId) => "$baseUrl/api/pois/$poiId/comments";
static String addComment(dynamic poiId) => "$baseUrl/api/pois/$poiId/comments";
}
