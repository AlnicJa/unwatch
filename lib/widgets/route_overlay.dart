import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import '../models/route.dart';
import '../theme/app_theme.dart';

class RouteOverlay extends StatelessWidget {
  final RouteResult route;
  const RouteOverlay({super.key, required this.route});

  @override
  Widget build(BuildContext context) {
    return PolylineLayer(
      polylines: [
        // Shadow line
        Polyline(
          points: route.polyline,
          strokeWidth: 8,
          color: Colors.black.withOpacity(0.3),
          borderStrokeWidth: 0,
        ),
        // Main route line
        Polyline(
          points: route.polyline,
          strokeWidth: 5,
          color: UnwatchTheme.routePrimary,
          borderStrokeWidth: 0,
        ),
      ],
    );
  }
}
