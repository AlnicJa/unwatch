import 'package:flutter/material.dart';
import '../models/camera.dart';
import '../theme/app_theme.dart';

class CameraMarkerWidget extends StatefulWidget {
  final Camera camera;
  final bool isSelected;
  final VoidCallback onTap;

  const CameraMarkerWidget({
    super.key,
    required this.camera,
    required this.isSelected,
    required this.onTap,
  });

  @override
  State<CameraMarkerWidget> createState() => _CameraMarkerWidgetState();
}

class _CameraMarkerWidgetState extends State<CameraMarkerWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulse;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _scale = Tween<double>(begin: 1.0, end: 1.2).animate(
      CurvedAnimation(parent: _pulse, curve: Curves.easeInOut),
    );
  }

  @override
  void didUpdateWidget(CameraMarkerWidget old) {
    super.didUpdateWidget(old);
    if (widget.isSelected && !old.isSelected) {
      _pulse.repeat(reverse: true);
    } else if (!widget.isSelected && old.isSelected) {
      _pulse.stop();
      _pulse.reset();
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = UnwatchTheme.cameraColor(widget.camera.type);
    final dimColor = UnwatchTheme.cameraDimColor(widget.camera.type);
    final icon = _icon(widget.camera.type);

    return GestureDetector(
      onTap: widget.onTap,
      child: AnimatedBuilder(
        animation: _scale,
        builder: (_, __) => Transform.scale(
          scale: widget.isSelected ? _scale.value : 1.0,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Pulse ring when selected
              if (widget.isSelected)
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: color.withOpacity(0.15),
                    border: Border.all(color: color.withOpacity(0.4), width: 1),
                  ),
                ),
              // Main dot
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: widget.isSelected ? color : dimColor,
                  border: Border.all(
                    color: widget.isSelected
                        ? Colors.white.withOpacity(0.7)
                        : color.withOpacity(0.6),
                    width: widget.isSelected ? 2 : 1.5,
                  ),
                ),
                child: Icon(
                  icon,
                  size: widget.isSelected ? 13 : 12,
                  color: widget.isSelected ? Colors.white : color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
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
