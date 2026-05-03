import 'dart:convert';
import 'dart:math' as math;
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import '../models/camera.dart';
import '../models/route.dart';
import 'overpass_service.dart';

class RoutingService {
  // Public OSRM instance (free, no key needed)
  static const _osrmBase = 'https://router.project-osrm.org/route/v1/driving';

  /// Get a basic route between two points (no avoidance)
  static Future<RouteResult> getRoute({
    required LatLng origin,
    required LatLng destination,
    List<LatLng> waypoints = const [],
  }) async {
    final all = [origin, ...waypoints, destination];
    final coords = all.map((p) => '${p.longitude},${p.latitude}').join(';');
    final url = '$_osrmBase/$coords?overview=full&geometries=geojson&steps=true';

    final response = await http.get(Uri.parse(url))
        .timeout(const Duration(seconds: 20));

    if (response.statusCode != 200) {
      throw Exception('Routing failed: ${response.statusCode}');
    }

    final data = jsonDecode(response.body);
    final route = data['routes'][0];
    final geometry = route['geometry']['coordinates'] as List;

    final polyline = geometry
        .map((c) => LatLng((c[1] as num).toDouble(), (c[0] as num).toDouble()))
        .toList();

    return RouteResult(
      polyline: polyline,
      distanceMeters: (route['distance'] as num).toDouble(),
      durationSeconds: (route['duration'] as num).toInt(),
      avoidedCameras: [],
      unavoidableCameras: [],
      summary: _buildSummary(route),
    );
  }

  /// Get a camera-avoiding route using iterative waypoint injection
  static Future<RouteResult> getCameraAvoidingRoute({
    required LatLng origin,
    required LatLng destination,
    required List<Camera> nearbyCameras,
    double avoidanceRadius = 80.0, // meters
  }) async {
    // Step 1: Get baseline route
    final baseline = await getRoute(origin: origin, destination: destination);

    // Step 2: Find cameras near the baseline route
    List<Camera> routeCameras = [];
    if (nearbyCameras.isNotEmpty) {
      routeCameras = nearbyCameras.where((cam) {
        return _isNearPolyline(cam.position, baseline.polyline, avoidanceRadius);
      }).toList();
    } else {
      routeCameras = await OverpassService.fetchAlongRoute(
        polyline: baseline.polyline,
        bufferMeters: avoidanceRadius,
      );
    }

    if (routeCameras.isEmpty) {
      return RouteResult(
        polyline: baseline.polyline,
        distanceMeters: baseline.distanceMeters,
        durationSeconds: baseline.durationSeconds,
        avoidedCameras: [],
        unavoidableCameras: [],
        summary: 'No cameras on this route',
      );
    }

    // Step 3: Try to route around cameras by injecting deviation waypoints
    final deviationWaypoints = _computeDeviationWaypoints(
      baseline.polyline,
      routeCameras,
      avoidanceRadius,
    );

    if (deviationWaypoints.isEmpty) {
      return RouteResult(
        polyline: baseline.polyline,
        distanceMeters: baseline.distanceMeters,
        durationSeconds: baseline.durationSeconds,
        avoidedCameras: [],
        unavoidableCameras: routeCameras,
        summary: 'Cannot avoid all cameras on this route',
      );
    }

    // Step 4: Re-route via deviation waypoints
    RouteResult avoidingRoute;
    try {
      avoidingRoute = await getRoute(
        origin: origin,
        destination: destination,
        waypoints: deviationWaypoints,
      );
    } catch (_) {
      // Fall back to baseline if deviation route fails
      return RouteResult(
        polyline: baseline.polyline,
        distanceMeters: baseline.distanceMeters,
        durationSeconds: baseline.durationSeconds,
        avoidedCameras: [],
        unavoidableCameras: routeCameras,
        summary: 'Route avoidance unavailable — showing direct route',
      );
    }

    // Step 5: Check how many cameras remain on the new route
    final remainingCameras = routeCameras.where((cam) {
      return _isNearPolyline(cam.position, avoidingRoute.polyline, avoidanceRadius);
    }).toList();

    final avoided = routeCameras.where((cam) => !remainingCameras.contains(cam)).toList();

    final extraDist = avoidingRoute.distanceMeters - baseline.distanceMeters;
    final extraMins = ((avoidingRoute.durationSeconds - baseline.durationSeconds) / 60).round();

    String summary;
    if (avoided.isNotEmpty) {
      summary = 'Avoiding ${avoided.length} camera${avoided.length == 1 ? '' : 's'}';
      if (extraDist > 100) {
        final mi = (extraDist / 1609.34);
        summary += ' (+${mi.toStringAsFixed(1)} mi';
        if (extraMins > 0) summary += ', +${extraMins}m';
        summary += ')';
      }
    } else {
      summary = 'No alternate path found — ${routeCameras.length} camera${routeCameras.length == 1 ? '' : 's'} on route';
    }

    return RouteResult(
      polyline: avoidingRoute.polyline,
      distanceMeters: avoidingRoute.distanceMeters,
      durationSeconds: avoidingRoute.durationSeconds,
      avoidedCameras: avoided,
      unavoidableCameras: remainingCameras,
      summary: summary,
    );
  }

  /// Compute waypoints that route around cameras
  static List<LatLng> _computeDeviationWaypoints(
    List<LatLng> polyline,
    List<Camera> cameras,
    double avoidanceRadius,
  ) {
    final waypoints = <LatLng>[];

    for (final cam in cameras) {
      // Find the closest point on the polyline to this camera
      int closestIdx = 0;
      double closestDist = double.infinity;

      for (var i = 0; i < polyline.length; i++) {
        final d = const Distance().as(LengthUnit.Meter, cam.position, polyline[i]);
        if (d < closestDist) {
          closestDist = d;
          closestIdx = i;
        }
      }

      if (closestDist > avoidanceRadius) continue;

      // Compute a perpendicular offset waypoint
      final refPoint = polyline[closestIdx];
      final deviationDist = avoidanceRadius * 2.5;

      // Get route bearing at this point
      double bearing = 0;
      if (closestIdx > 0) {
        bearing = _bearing(polyline[closestIdx - 1], refPoint);
      } else if (closestIdx < polyline.length - 1) {
        bearing = _bearing(refPoint, polyline[closestIdx + 1]);
      }

      // Offset perpendicular to bearing (try both sides)
      final perpBearing = (bearing + 90) % 360;
      final offset = _offsetPoint(refPoint, deviationDist, perpBearing);
      waypoints.add(offset);
    }

    return waypoints;
  }

  static LatLng _offsetPoint(LatLng point, double distMeters, double bearingDeg) {
    const R = 6371000.0;
    final lat1 = point.latitude * math.pi / 180;
    final lng1 = point.longitude * math.pi / 180;
    final brng = bearingDeg * math.pi / 180;
    final d = distMeters / R;

    final lat2 = math.asin(
      math.sin(lat1) * math.cos(d) +
          math.cos(lat1) * math.sin(d) * math.cos(brng),
    );
    final lng2 = lng1 +
        math.atan2(
          math.sin(brng) * math.sin(d) * math.cos(lat1),
          math.cos(d) - math.sin(lat1) * math.sin(lat2),
        );

    return LatLng(lat2 * 180 / math.pi, lng2 * 180 / math.pi);
  }

  static double _bearing(LatLng from, LatLng to) {
    final lat1 = from.latitude * math.pi / 180;
    final lat2 = to.latitude * math.pi / 180;
    final dLng = (to.longitude - from.longitude) * math.pi / 180;

    final y = math.sin(dLng) * math.cos(lat2);
    final x = math.cos(lat1) * math.sin(lat2) -
        math.sin(lat1) * math.cos(lat2) * math.cos(dLng);

    return (math.atan2(y, x) * 180 / math.pi + 360) % 360;
  }

  static bool _isNearPolyline(LatLng point, List<LatLng> poly, double threshold) {
    for (final p in poly) {
      final d = const Distance().as(LengthUnit.Meter, point, p);
      if (d <= threshold) return true;
    }
    return false;
  }

  static String _buildSummary(Map<String, dynamic> route) {
    final legs = route['legs'] as List;
    if (legs.isEmpty) return '';
    final steps = legs[0]['steps'] as List;
    for (final step in steps) {
      final name = step['name'] as String?;
      if (name != null && name.isNotEmpty) return name;
    }
    return '';
  }
}
