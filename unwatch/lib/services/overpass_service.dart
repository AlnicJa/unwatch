import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import '../models/camera.dart';

class OverpassService {
  static const _endpoint = 'https://overpass-api.de/api/interpreter';
  static const _backupEndpoint = 'https://overpass.kumi.systems/api/interpreter';

  static String _buildQuery(double lat, double lng, double radiusMeters) {
    return '''[out:json][timeout:30];
(
  node["man_made"="surveillance"]["surveillance:type"="ALPR"](around:$radiusMeters,$lat,$lng);
  node["man_made"="surveillance"]["surveillance:type"="alpr"](around:$radiusMeters,$lat,$lng);
  node["man_made"="surveillance"]["manufacturer"="Flock Safety"](around:$radiusMeters,$lat,$lng);
  node["man_made"="surveillance"]["manufacturer"~"flock",i](around:$radiusMeters,$lat,$lng);
  node["man_made"="surveillance"]["manufacturer"~"Vigilant",i](around:$radiusMeters,$lat,$lng);
  node["man_made"="surveillance"]["manufacturer"~"Rekor",i](around:$radiusMeters,$lat,$lng);
  node["highway"="speed_camera"](around:$radiusMeters,$lat,$lng);
  node["amenity"="enforcement"]["enforcement"="maxspeed"](around:$radiusMeters,$lat,$lng);
  node["amenity"="enforcement"]["enforcement"="traffic_signals"](around:$radiusMeters,$lat,$lng);
  node["man_made"="surveillance"]["surveillance:zone"="traffic"](around:$radiusMeters,$lat,$lng);
);
out body;''';
  }

  static Future<List<Camera>> fetchNearby({
    required double lat,
    required double lng,
    double radiusMeters = 8000,
  }) async {
    final query = _buildQuery(lat, lng, radiusMeters);
    final body = 'data=${Uri.encodeComponent(query)}';

    http.Response response;
    try {
      response = await http
          .post(Uri.parse(_endpoint), body: body)
          .timeout(const Duration(seconds: 25));
    } catch (_) {
      // Fallback to backup server
      response = await http
          .post(Uri.parse(_backupEndpoint), body: body)
          .timeout(const Duration(seconds: 25));
    }

    if (response.statusCode != 200) {
      throw Exception('Overpass API error ${response.statusCode}');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final elements = data['elements'] as List<dynamic>;

    final cameras = <Camera>[];
    final seen = <String>{};

    for (final el in elements) {
      final node = el as Map<String, dynamic>;
      if (node['type'] != 'node') continue;
      final id = node['id'].toString();
      if (seen.contains(id)) continue;
      seen.add(id);

      final cam = Camera.fromOverpassNode(node);
      // Compute distance
      final dist = const Distance().as(
        LengthUnit.Meter,
        LatLng(lat, lng),
        cam.position,
      );
      cam.distanceMeters = dist;
      cameras.add(cam);
    }

    cameras.sort((a, b) =>
        (a.distanceMeters ?? 0).compareTo(b.distanceMeters ?? 0));

    return cameras;
  }

  /// Fetch cameras along a route polyline (within bufferMeters of any point)
  static Future<List<Camera>> fetchAlongRoute({
    required List<LatLng> polyline,
    double bufferMeters = 75,
  }) async {
    if (polyline.isEmpty) return [];

    // Sample every ~500m for the query
    final sampled = _samplePolyline(polyline, 500);
    final allCameras = <Camera>[];
    final seen = <String>{};

    // Query in chunks of 5 points to avoid huge queries
    for (var i = 0; i < sampled.length; i += 5) {
      final chunk = sampled.sublist(i, (i + 5).clamp(0, sampled.length));
      final centerLat = chunk.map((p) => p.latitude).reduce((a, b) => a + b) / chunk.length;
      final centerLng = chunk.map((p) => p.longitude).reduce((a, b) => a + b) / chunk.length;

      // Rough radius that covers all chunk points
      double maxDist = 600;
      for (final p in chunk) {
        final d = const Distance().as(LengthUnit.Meter, LatLng(centerLat, centerLng), p);
        if (d > maxDist) maxDist = d;
      }

      final cameras = await fetchNearby(
        lat: centerLat,
        lng: centerLng,
        radiusMeters: maxDist + bufferMeters,
      );

      for (final c in cameras) {
        if (!seen.contains(c.id)) {
          seen.add(c.id);
          // Filter to only cameras within buffer of the actual route line
          if (_isNearPolyline(c.position, polyline, bufferMeters)) {
            allCameras.add(c);
          }
        }
      }
    }

    return allCameras;
  }

  static List<LatLng> _samplePolyline(List<LatLng> poly, double intervalMeters) {
    if (poly.length <= 2) return poly;
    final result = [poly.first];
    double accumulated = 0;
    for (var i = 1; i < poly.length; i++) {
      final d = const Distance().as(LengthUnit.Meter, poly[i - 1], poly[i]);
      accumulated += d;
      if (accumulated >= intervalMeters) {
        result.add(poly[i]);
        accumulated = 0;
      }
    }
    result.add(poly.last);
    return result;
  }

  static bool _isNearPolyline(LatLng point, List<LatLng> poly, double thresholdMeters) {
    for (final p in poly) {
      final d = const Distance().as(LengthUnit.Meter, point, p);
      if (d <= thresholdMeters) return true;
    }
    return false;
  }
}
