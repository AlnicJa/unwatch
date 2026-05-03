import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

class UnwatchTheme {
  // Brand colors
  static const Color bg = Color(0xFF0A0A0F);
  static const Color surface = Color(0xFF16161E);
  static const Color surface2 = Color(0xFF1E1E28);
  static const Color surface3 = Color(0xFF252532);
  static const Color border = Color(0x18FFFFFF);
  static const Color borderMid = Color(0x28FFFFFF);

  static const Color textPrimary = Color(0xFFF2F2F6);
  static const Color textSecondary = Color(0xFF8E8EA0);
  static const Color textTertiary = Color(0xFF56566A);

  // Camera type colors
  static const Color flockAmber = Color(0xFFFFAA00);
  static const Color flockAmberDim = Color(0x28FFAA00);
  static const Color redLight = Color(0xFFFF3B3B);
  static const Color redLightDim = Color(0x28FF3B3B);
  static const Color speedBlue = Color(0xFF4FA3FF);
  static const Color speedBlueDim = Color(0x284FA3FF);
  static const Color genericPurple = Color(0xFFBF5AF2);

  // Semantic
  static const Color success = Color(0xFF30D158);
  static const Color warning = Color(0xFFFFD60A);
  static const Color danger = Color(0xFFFF453A);

  // Route colors
  static const Color routePrimary = Color(0xFF4FA3FF);
  static const Color routeAvoid = Color(0x40FF3B3B);

  static ThemeData get theme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: bg,
      colorScheme: const ColorScheme.dark(
        primary: speedBlue,
        secondary: flockAmber,
        surface: surface,
        onSurface: textPrimary,
      ),
      textTheme: GoogleFonts.interTextTheme(ThemeData.dark().textTheme).copyWith(
        displayLarge: GoogleFonts.inter(
          fontSize: 34,
          fontWeight: FontWeight.w700,
          color: textPrimary,
          letterSpacing: -1.0,
        ),
        headlineMedium: GoogleFonts.inter(
          fontSize: 22,
          fontWeight: FontWeight.w700,
          color: textPrimary,
          letterSpacing: -0.5,
        ),
        titleLarge: GoogleFonts.inter(
          fontSize: 17,
          fontWeight: FontWeight.w600,
          color: textPrimary,
          letterSpacing: -0.2,
        ),
        titleMedium: GoogleFonts.inter(
          fontSize: 15,
          fontWeight: FontWeight.w500,
          color: textPrimary,
        ),
        bodyMedium: GoogleFonts.inter(
          fontSize: 14,
          fontWeight: FontWeight.w400,
          color: textSecondary,
          height: 1.5,
        ),
        bodySmall: GoogleFonts.inter(
          fontSize: 12,
          fontWeight: FontWeight.w400,
          color: textSecondary,
        ),
        labelSmall: GoogleFonts.inter(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: textSecondary,
          letterSpacing: 0.4,
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarBrightness: Brightness.dark,
          statusBarIconBrightness: Brightness.light,
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
      ),
    );
  }

  static Color cameraColor(dynamic type) {
    switch (type.toString()) {
      case 'CameraType.flock':
        return flockAmber;
      case 'CameraType.redLight':
        return redLight;
      case 'CameraType.speed':
        return speedBlue;
      default:
        return genericPurple;
    }
  }

  static Color cameraDimColor(dynamic type) {
    switch (type.toString()) {
      case 'CameraType.flock':
        return flockAmberDim;
      case 'CameraType.redLight':
        return redLightDim;
      case 'CameraType.speed':
        return speedBlueDim;
      default:
        return genericPurple.withOpacity(0.15);
    }
  }
}
