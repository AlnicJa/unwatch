import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import '../models/camera.dart';
import '../providers/app_providers.dart';
import '../services/location_service.dart';
import '../services/notification_service.dart';
import '../theme/app_theme.dart';
import '../widgets/camera_marker.dart';
import '../widgets/bottom_sheet_panel.dart';
import '../widgets/filter_bar.dart';
import '../widgets/proximity_alert_banner.dart';
import '../widgets/route_overlay.dart';
import 'search_screen.dart';

class MapScreen extends ConsumerStatefulWidget {
  const MapScreen({super.key});

  @override
  ConsumerState<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends ConsumerState<MapScreen>
    with TickerProviderStateMixin {
  final _mapController = MapController();
  bool _isLocating = false;
  bool _followUser = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _init());
  }

  Future<void> _init() async {
    await NotificationService.init();
    await NotificationService.requestPermission();
    await _locateAndLoad();
  }

  Future<void> _locateAndLoad() async {
    setState(() => _isLocating = true);
    final svc = ref.read(locationServiceProvider);
    final granted = await svc.requestPermissions();
    if (!granted) {
      setState(() => _isLocating = false);
      return;
    }

    final pos = await svc.getCurrentPosition();
    if (pos == null) {
      setState(() => _isLocating = false);
      return;
    }

    ref.read(userLocationProvider.notifier).state = pos;
    _mapController.move(pos, 14);

    final filters = ref.read(filterProvider);
    await ref.read(cameraProvider.notifier).fetch(
          lat: pos.latitude,
          lng: pos.longitude,
          radiusKm: filters.radiusKm,
        );

    final cameras = ref.read(cameraProvider).valueOrNull ?? [];
    svc.startTracking(cameras: cameras);

    // Listen for proximity alerts
    svc.proximityAlerts.listen((alert) {
      NotificationService.showProximityAlert(alert);
      if (mounted) {
        ref.read(proximityAlertBannerProvider.notifier).show(alert);
      }
    });

    setState(() => _isLocating = false);
    _followUser = true;
  }

  void _onMapMove(MapCamera camera, bool hasGesture) {
    if (hasGesture) _followUser = false;

    // Load cameras for new area when map moves significantly
    final center = camera.center;
    ref.read(mapCenterProvider.notifier).state = center;
  }

  void _recenter() {
    final pos = ref.read(userLocationProvider);
    if (pos == null) {
      _locateAndLoad();
      return;
    }
    _mapController.move(pos, 15);
    _followUser = true;
  }

  @override
  Widget build(BuildContext context) {
    final userPos = ref.watch(userLocationProvider);
    final filteredCameras = ref.watch(filteredCamerasProvider);
    final routeAsync = ref.watch(routeProvider);
    final selectedCam = ref.watch(selectedCameraProvider);
    final alertState = ref.watch(proximityAlertBannerProvider);

    // Follow user on location update
    ref.listen(locationStreamProvider, (_, next) {
      next.whenData((pos) {
        ref.read(userLocationProvider.notifier).state = pos;
        if (_followUser) {
          _mapController.move(pos, _mapController.camera.zoom);
        }
        // Update monitored cameras for proximity
        final cameras = ref.read(filteredCamerasProvider);
        ref.read(locationServiceProvider).updateMonitoredCameras(cameras);
      });
    });

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: UnwatchTheme.bg,
        body: Stack(
          children: [
            // ── MAP ──────────────────────────────────────────────────────
            FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: userPos ?? const LatLng(39.8, -98.5),
                initialZoom: userPos != null ? 14 : 5,
                maxZoom: 19,
                minZoom: 3,
                onMapEvent: (event) {
                  if (event is MapEventMoveStart && event.source != MapEventSource.mapController) {
                    _followUser = false;
                  }
                },
                onPositionChanged: (camera, hasGesture) =>
                    _onMapMove(camera, hasGesture),
                onTap: (_, __) {
                  ref.read(selectedCameraProvider.notifier).state = null;
                },
              ),
              children: [
                // Dark map tiles
                TileLayer(
                  urlTemplate:
                      'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png',
                  subdomains: const ['a', 'b', 'c', 'd'],
                  userAgentPackageName: 'app.unwatch.unwatch',
                  maxZoom: 19,
                ),

                // Route polyline
                if (routeAsync.valueOrNull != null)
                  RouteOverlay(route: routeAsync.value!),

                // Camera markers
                MarkerLayer(
                  markers: filteredCameras.map((cam) {
                    return Marker(
                      point: cam.position,
                      width: 36,
                      height: 36,
                      child: CameraMarkerWidget(
                        camera: cam,
                        isSelected: selectedCam?.id == cam.id,
                        onTap: () {
                          ref.read(selectedCameraProvider.notifier).state = cam;
                          HapticFeedback.lightImpact();
                        },
                      ),
                    );
                  }).toList(),
                ),

                // User location dot
                if (userPos != null)
                  MarkerLayer(
                    markers: [
                      Marker(
                        point: userPos,
                        width: 24,
                        height: 24,
                        child: _UserDot(),
                      ),
                    ],
                  ),
              ],
            ),

            // ── TOP BAR ──────────────────────────────────────────────────
            SafeArea(
              child: Column(
                children: [
                  _TopBar(
                    isLocating: _isLocating,
                    onSearch: () => _openSearch(),
                    onMenu: () => _showSettings(),
                  ),
                  const SizedBox(height: 8),
                  const FilterBar(),
                ],
              ),
            ),

            // ── PROXIMITY ALERT BANNER ────────────────────────────────────
            if (alertState != null)
              Positioned(
                top: MediaQuery.of(context).padding.top + 130,
                left: 12,
                right: 12,
                child: ProximityAlertBanner(alert: alertState),
              ),

            // ── RIGHT CONTROLS ────────────────────────────────────────────
            Positioned(
              right: 14,
              bottom: 230,
              child: Column(
                children: [
                  _MapButton(
                    icon: Icons.my_location_rounded,
                    color: _followUser ? UnwatchTheme.speedBlue : UnwatchTheme.textSecondary,
                    onTap: _recenter,
                  ),
                  const SizedBox(height: 10),
                  _MapButton(
                    icon: Icons.add,
                    onTap: () => _mapController.move(
                      _mapController.camera.center,
                      (_mapController.camera.zoom + 1).clamp(3, 19),
                    ),
                  ),
                  const SizedBox(height: 4),
                  _MapButton(
                    icon: Icons.remove,
                    onTap: () => _mapController.move(
                      _mapController.camera.center,
                      (_mapController.camera.zoom - 1).clamp(3, 19),
                    ),
                  ),
                ],
              ),
            ),

            // ── BOTTOM SHEET ──────────────────────────────────────────────
            BottomSheetPanel(
              onNavigate: _openSearch,
            ),

            // ── CAMERA DETAIL CARD ────────────────────────────────────────
            if (selectedCam != null)
              Positioned(
                left: 12,
                right: 12,
                bottom: 210,
                child: _CameraDetailCard(camera: selectedCam),
              ),
          ],
        ),
      ),
    );
  }

  void _openSearch() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const SearchScreen()),
    );
  }

  void _showSettings() {
    showModalBottomSheet(
      context: context,
      backgroundColor: UnwatchTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => const _SettingsSheet(),
    );
  }

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }
}

// ── Supporting widgets ────────────────────────────────────────────────────────

class _TopBar extends StatelessWidget {
  final bool isLocating;
  final VoidCallback onSearch;
  final VoidCallback onMenu;

  const _TopBar({
    required this.isLocating,
    required this.onSearch,
    required this.onMenu,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      child: Row(
        children: [
          // Logo / wordmark
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: UnwatchTheme.surface2,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: UnwatchTheme.border),
                ),
                child: const Icon(Icons.remove_red_eye_outlined,
                    color: UnwatchTheme.flockAmber, size: 16),
              ),
              const SizedBox(width: 8),
              Text(
                'Unwatch',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5,
                    ),
              ),
            ],
          ),
          const SizedBox(width: 10),
          // Search bar
          Expanded(
            child: GestureDetector(
              onTap: onSearch,
              child: Container(
                height: 40,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: UnwatchTheme.surface2,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: UnwatchTheme.border),
                ),
                child: Row(
                  children: [
                    Icon(Icons.search_rounded,
                        color: UnwatchTheme.textSecondary, size: 17),
                    const SizedBox(width: 8),
                    Text(
                      'Where to?',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          // Menu
          GestureDetector(
            onTap: onMenu,
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: UnwatchTheme.surface2,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: UnwatchTheme.border),
              ),
              child: isLocating
                  ? const Padding(
                      padding: EdgeInsets.all(10),
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: UnwatchTheme.speedBlue,
                      ),
                    )
                  : const Icon(Icons.tune_rounded,
                      color: UnwatchTheme.textSecondary, size: 18),
            ),
          ),
        ],
      ),
    );
  }
}

class _MapButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final Color? color;

  const _MapButton({required this.icon, required this.onTap, this.color});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: UnwatchTheme.surface.withOpacity(0.92),
          shape: BoxShape.circle,
          border: Border.all(color: UnwatchTheme.border),
        ),
        child: Icon(icon,
            color: color ?? UnwatchTheme.textSecondary, size: 20),
      ),
    );
  }
}

class _UserDot extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: UnwatchTheme.speedBlue,
        border: Border.all(color: Colors.white, width: 2.5),
        boxShadow: [
          BoxShadow(
            color: UnwatchTheme.speedBlue.withOpacity(0.5),
            blurRadius: 8,
            spreadRadius: 2,
          ),
        ],
      ),
    );
  }
}

class _CameraDetailCard extends ConsumerWidget {
  final Camera camera;
  const _CameraDetailCard({required this.camera});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final color = UnwatchTheme.cameraColor(camera.type);
    return GestureDetector(
      onTap: () {},
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: UnwatchTheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.4)),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: color.withOpacity(0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(_cameraIcon(camera.type), color: color, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(camera.displayName,
                      style: Theme.of(context).textTheme.titleMedium),
                  Text(camera.typeLabel,
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: color)),
                  if (camera.distanceMeters != null)
                    Text(
                      '${(camera.distanceMeters! * 0.000621371).toStringAsFixed(2)} mi away',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.close_rounded,
                  color: UnwatchTheme.textSecondary, size: 18),
              onPressed: () =>
                  ref.read(selectedCameraProvider.notifier).state = null,
            ),
          ],
        ),
      ),
    );
  }

  IconData _cameraIcon(CameraType type) {
    switch (type) {
      case CameraType.flock:
        return Icons.local_police_rounded;
      case CameraType.redLight:
        return Icons.traffic_rounded;
      case CameraType.speed:
        return Icons.speed_rounded;
      default:
        return Icons.videocam_rounded;
    }
  }
}

class _SettingsSheet extends ConsumerWidget {
  const _SettingsSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final avoidCams = ref.watch(avoidCamerasProvider);
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 16,
        bottom: MediaQuery.of(context).padding.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: UnwatchTheme.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text('Settings', style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 20),
          _SettingsTile(
            icon: Icons.alt_route_rounded,
            label: 'Avoid cameras when routing',
            subtitle: 'Automatically route around ALPR & red light cameras',
            trailing: Switch(
              value: avoidCams,
              onChanged: (v) =>
                  ref.read(avoidCamerasProvider.notifier).state = v,
              activeColor: UnwatchTheme.speedBlue,
            ),
          ),
          const SizedBox(height: 12),
          _SettingsTile(
            icon: Icons.notifications_rounded,
            label: 'Proximity alerts',
            subtitle: 'Notify when approaching a camera',
            trailing: const Icon(Icons.chevron_right_rounded,
                color: UnwatchTheme.textSecondary),
            onTap: () {},
          ),
          const SizedBox(height: 12),
          _SettingsTile(
            icon: Icons.info_outline_rounded,
            label: 'About Unwatch',
            subtitle: 'Data from OpenStreetMap • Community-sourced',
            trailing: const Icon(Icons.chevron_right_rounded,
                color: UnwatchTheme.textSecondary),
            onTap: () {},
          ),
        ],
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final Widget trailing;
  final VoidCallback? onTap;

  const _SettingsTile({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.trailing,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: UnwatchTheme.surface2,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: UnwatchTheme.border),
        ),
        child: Row(
          children: [
            Icon(icon, color: UnwatchTheme.flockAmber, size: 18),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: Theme.of(context).textTheme.titleMedium),
                  Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ),
            trailing,
          ],
        ),
      ),
    );
  }
}

// Proximity alert banner state
final proximityAlertBannerProvider =
    StateNotifierProvider<_AlertBannerNotifier, ProximityAlert?>(
  (ref) => _AlertBannerNotifier(),
);

class _AlertBannerNotifier extends StateNotifier<ProximityAlert?> {
  _AlertBannerNotifier() : super(null);
  void show(ProximityAlert alert) {
    state = alert;
    Future.delayed(const Duration(seconds: 5), () {
      if (mounted) state = null;
    });
  }

  void dismiss() => state = null;
}
