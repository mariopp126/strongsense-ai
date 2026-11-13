import 'package:flutter/material.dart';

/// Slate + emerald palette lifted from the original design reference.
abstract final class SsColors {
  static const slate50 = Color(0xFFF8FAFC);
  static const slate100 = Color(0xFFF1F5F9);
  static const slate200 = Color(0xFFE2E8F0);
  static const slate300 = Color(0xFFCBD5E1);
  static const slate400 = Color(0xFF94A3B8);
  static const slate500 = Color(0xFF64748B);
  static const slate600 = Color(0xFF475569);
  static const slate700 = Color(0xFF334155);
  static const slate800 = Color(0xFF1E293B);
  static const slate900 = Color(0xFF0F172A);

  static const emerald50 = Color(0xFFECFDF5);
  static const emerald100 = Color(0xFFD1FAE5);
  static const emerald200 = Color(0xFFA7F3D0);
  static const emerald300 = Color(0xFF6EE7B7);
  static const emerald400 = Color(0xFF34D399);
  static const emerald500 = Color(0xFF10B981);
  static const emerald600 = Color(0xFF059669);
  static const emerald700 = Color(0xFF047857);
  static const emerald800 = Color(0xFF065F46);

  static const amber500 = Color(0xFFF59E0B);
  static const amber100 = Color(0xFFFEF3C7);
  static const amber800 = Color(0xFF92400E);

  static const orange500 = Color(0xFFF97316);
  static const orange100 = Color(0xFFFFEDD5);
  static const orange800 = Color(0xFF9A3412);

  static const red500 = Color(0xFFEF4444);
  static const red100 = Color(0xFFFEE2E2);
  static const red800 = Color(0xFF991B1B);

  static const blue500 = Color(0xFF3B82F6);
  static const blue100 = Color(0xFFDBEAFE);
  static const blue800 = Color(0xFF1E40AF);
}

/// Spacing / radius tokens shared by the custom widgets.
abstract final class SsSpacing {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
  static const double xxl = 24;
  static const double section = 32;

  static const double radiusSm = 8;
  static const double radiusMd = 12;
  static const double radiusLg = 16;
  static const double radiusXl = 20;
  static const double radiusFull = 999;

  static const double mobileMaxWidth = 520;
  static const double contentMaxWidth = 720;
  static const double railBreakpoint = 720;
}
