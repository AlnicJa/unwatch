import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/camera.dart';
import '../providers/app_providers.dart';
import '../theme/app_theme.dart';

class FilterBar extends ConsumerWidget {
  const FilterBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filters = ref.watch(filterProvider);

    return SizedBox(
      height: 36,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        children: [
          _FilterPill(
            label: 'Flock / ALPR',
            color: UnwatchTheme.flockAmber,
            isActive: filters.showFlock,
            onTap: () {
              HapticFeedback.selectionClick();
              ref.read(filterProvider.notifier).toggle(CameraType.flock);
            },
          ),
          const SizedBox(width: 8),
          _FilterPill(
            label: 'Red Light',
            color: UnwatchTheme.redLight,
            isActive: filters.showRedLight,
            onTap: () {
              HapticFeedback.selectionClick();
              ref.read(filterProvider.notifier).toggle(CameraType.redLight);
            },
          ),
          const SizedBox(width: 8),
          _FilterPill(
            label: 'Speed Cam',
            color: UnwatchTheme.speedBlue,
            isActive: filters.showSpeed,
            onTap: () {
              HapticFeedback.selectionClick();
              ref.read(filterProvider.notifier).toggle(CameraType.speed);
            },
          ),
          const SizedBox(width: 8),
          _RadiusPill(),
        ],
      ),
    );
  }
}

class _FilterPill extends StatelessWidget {
  final String label;
  final Color color;
  final bool isActive;
  final VoidCallback onTap;

  const _FilterPill({
    required this.label,
    required this.color,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isActive ? color.withOpacity(0.15) : UnwatchTheme.surface2,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isActive ? color.withOpacity(0.5) : UnwatchTheme.border,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isActive ? color : UnwatchTheme.textTertiary,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: isActive ? color : UnwatchTheme.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RadiusPill extends ConsumerStatefulWidget {
  @override
  ConsumerState<_RadiusPill> createState() => _RadiusPillState();
}

class _RadiusPillState extends ConsumerState<_RadiusPill> {
  final _radii = [4.0, 8.0, 16.0];
  final _labels = ['2.5 mi', '5 mi', '10 mi'];
  int _idx = 1;

  void _cycle() {
    HapticFeedback.selectionClick();
    setState(() => _idx = (_idx + 1) % _radii.length);
    ref.read(filterProvider.notifier).setRadius(_radii[_idx]);
    // Reload cameras
    final pos = ref.read(userLocationProvider);
    if (pos != null) {
      ref.read(cameraProvider.notifier).fetch(
            lat: pos.latitude,
            lng: pos.longitude,
            radiusKm: _radii[_idx],
          );
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _cycle,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: UnwatchTheme.surface2,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: UnwatchTheme.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.radar_rounded,
                color: UnwatchTheme.textSecondary, size: 13),
            const SizedBox(width: 5),
            Text(
              _labels[_idx],
              style: Theme.of(context).textTheme.labelSmall,
            ),
          ],
        ),
      ),
    );
  }
}
