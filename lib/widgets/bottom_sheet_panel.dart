import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/camera.dart';
import '../models/route.dart';
import '../providers/app_providers.dart';
import '../theme/app_theme.dart';

class BottomSheetPanel extends ConsumerStatefulWidget {
  final VoidCallback onNavigate;

  const BottomSheetPanel({super.key, required this.onNavigate});

  @override
  ConsumerState<BottomSheetPanel> createState() => _BottomSheetPanelState();
}

class _BottomSheetPanelState extends ConsumerState<BottomSheetPanel> {
  double _sheetHeight = 180;
  static const _collapsed = 180.0;
  static const _expanded = 460.0;
  bool _isExpanded = false;

  void _toggle() {
    HapticFeedback.lightImpact();
    setState(() {
      _isExpanded = !_isExpanded;
      _sheetHeight = _isExpanded ? _expanded : _collapsed;
    });
  }

  @override
  Widget build(BuildContext context) {
    final camerasAsync = ref.watch(cameraProvider);
    final filteredCameras = ref.watch(filteredCamerasProvider);
    final routeAsync = ref.watch(routeProvider);
    final routeStatus = ref.watch(routeStatusProvider);

    final route = routeAsync.valueOrNull;
    final hasRoute = route != null;

    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: GestureDetector(
        onVerticalDragUpdate: (d) {
          setState(() {
            _sheetHeight = (_sheetHeight - d.delta.dy)
                .clamp(_collapsed, _expanded);
          });
        },
        onVerticalDragEnd: (d) {
          if (_sheetHeight > (_collapsed + _expanded) / 2) {
            setState(() {
              _sheetHeight = _expanded;
              _isExpanded = true;
            });
          } else {
            setState(() {
              _sheetHeight = _collapsed;
              _isExpanded = false;
            });
          }
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
          height: _sheetHeight,
          decoration: const BoxDecoration(
            color: UnwatchTheme.surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            border: Border(top: BorderSide(color: UnwatchTheme.border)),
          ),
          child: Column(
            children: [
              // Handle
              GestureDetector(
                onTap: _toggle,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: UnwatchTheme.border,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              ),

              // Route status or stat row
              if (routeStatus == RouteStatus.calculating)
                _CalculatingRoute()
              else if (hasRoute)
                _RouteInfoBar(route: route)
              else
                _StatBar(
                  cameras: filteredCameras,
                  isLoading: camerasAsync.isLoading,
                  onNavigate: widget.onNavigate,
                ),

              const Divider(color: UnwatchTheme.border, height: 1),

              // Camera list
              Expanded(
                child: camerasAsync.when(
                  data: (_) => filteredCameras.isEmpty
                      ? _EmptyState()
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          itemCount: filteredCameras.length.clamp(0, 40),
                          itemBuilder: (_, i) =>
                              _CameraListTile(camera: filteredCameras[i]),
                        ),
                  loading: () => const Center(
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: UnwatchTheme.speedBlue,
                    ),
                  ),
                  error: (e, _) => Center(
                    child: Text('Failed to load cameras',
                        style: Theme.of(context)
                            .textTheme
                            .bodyMedium),
                  ),
                ),
              ),

              SizedBox(height: MediaQuery.of(context).padding.bottom),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatBar extends StatelessWidget {
  final List<Camera> cameras;
  final bool isLoading;
  final VoidCallback onNavigate;

  const _StatBar({
    required this.cameras,
    required this.isLoading,
    required this.onNavigate,
  });

  @override
  Widget build(BuildContext context) {
    final flock = cameras.where((c) => c.type == CameraType.flock).length;
    final red = cameras.where((c) => c.type == CameraType.redLight).length;
    final speed = cameras.where((c) => c.type == CameraType.speed).length;

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 4, 14, 12),
      child: Row(
        children: [
          _StatChip(
            value: '$flock',
            label: 'Flock',
            color: UnwatchTheme.flockAmber,
          ),
          const SizedBox(width: 8),
          _StatChip(
            value: '$red',
            label: 'Red Light',
            color: UnwatchTheme.redLight,
          ),
          const SizedBox(width: 8),
          _StatChip(
            value: '$speed',
            label: 'Speed',
            color: UnwatchTheme.speedBlue,
          ),
          const Spacer(),
          GestureDetector(
            onTap: () {
              HapticFeedback.mediumImpact();
              onNavigate();
            },
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
              decoration: BoxDecoration(
                color: UnwatchTheme.speedBlue,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.navigation_rounded,
                      color: Colors.white, size: 15),
                  const SizedBox(width: 6),
                  Text('Go',
                      style:
                          Theme.of(context).textTheme.titleMedium?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                              )),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final String value;
  final String label;
  final Color color;

  const _StatChip({
    required this.value,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Column(
        children: [
          Text(value,
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(color: color, fontWeight: FontWeight.w700)),
          Text(label,
              style: Theme.of(context)
                  .textTheme
                  .labelSmall
                  ?.copyWith(color: color.withOpacity(0.7))),
        ],
      ),
    );
  }
}

class _RouteInfoBar extends ConsumerWidget {
  final RouteResult route;
  const _RouteInfoBar({required this.route});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 4, 14, 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: UnwatchTheme.surface2,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: UnwatchTheme.border),
            ),
            child: Row(
              children: [
                Text(route.durationLabel,
                    style: Theme.of(context).textTheme.headlineMedium),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(route.distanceLabel,
                        style: Theme.of(context).textTheme.titleMedium),
                    Text(
                      route.summary,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: route.avoidedCameras.isNotEmpty
                                ? UnwatchTheme.success
                                : UnwatchTheme.textSecondary,
                          ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          if (route.unavoidableCameras.isNotEmpty)
            Expanded(
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: UnwatchTheme.danger.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: UnwatchTheme.danger.withOpacity(0.3)),
                ),
                child: Text(
                  '${route.unavoidableCameras.length} camera${route.unavoidableCameras.length == 1 ? '' : 's'} unavoidable',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: UnwatchTheme.danger,
                      ),
                ),
              ),
            ),
          const Spacer(),
          GestureDetector(
            onTap: () {
              HapticFeedback.selectionClick();
              ref.read(routeProvider.notifier).clear();
              ref.read(routeStatusProvider.notifier).state = RouteStatus.idle;
            },
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: UnwatchTheme.surface2,
                shape: BoxShape.circle,
                border: Border.all(color: UnwatchTheme.border),
              ),
              child: const Icon(Icons.close_rounded,
                  color: UnwatchTheme.textSecondary, size: 16),
            ),
          ),
        ],
      ),
    );
  }
}

class _CalculatingRoute extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 4, 14, 12),
      child: Row(
        children: [
          const SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: UnwatchTheme.flockAmber,
            ),
          ),
          const SizedBox(width: 12),
          Text('Finding camera-free route…',
              style: Theme.of(context).textTheme.titleMedium),
        ],
      ),
    );
  }
}

class _CameraListTile extends ConsumerWidget {
  final Camera camera;
  const _CameraListTile({required this.camera});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final color = UnwatchTheme.cameraColor(camera.type);

    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        ref.read(selectedCameraProvider.notifier).state = camera;
      },
      child: Container(
        color: Colors.transparent,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(_icon(camera.type), color: color, size: 16),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(camera.displayName,
                      style: Theme.of(context).textTheme.titleMedium,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                  Text(camera.typeLabel,
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: color.withOpacity(0.8))),
                ],
              ),
            ),
            if (camera.distanceMeters != null)
              Text(
                _distLabel(camera.distanceMeters!),
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: UnwatchTheme.textSecondary),
              ),
          ],
        ),
      ),
    );
  }

  String _distLabel(double m) {
    if (m < 1609) return '${(m * 3.281).round()} ft';
    return '${(m / 1609.34).toStringAsFixed(1)} mi';
  }

  IconData _icon(CameraType type) {
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

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.check_circle_outline_rounded,
              color: UnwatchTheme.success, size: 36),
          const SizedBox(height: 10),
          Text('No cameras found nearby',
              style: Theme.of(context).textTheme.titleMedium),
          Text('Move the map to search another area',
              style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}
