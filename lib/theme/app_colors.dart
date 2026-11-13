import 'package:flutter/material.dart';

class AppColors {
  final bool isDark;

  const AppColors({required this.isDark});

  Color get scaffoldBg => isDark ? Colors.black : const Color(0xFFF8FAFC);
  Color get cardBg => isDark ? const Color(0xFF1E293B) : Colors.white;
  Color get cardBgAlt => isDark ? const Color(0xFF0F172A) : const Color(0xFFF0F9FF);
  Color get surfaceBorder => isDark ? Colors.white12 : const Color(0xFFE0F2FE);
  Color get surfaceBorderSubtle => isDark ? Colors.white.withValues(alpha: 0.08) : const Color(0xFFBAE6FD);
  Color get textPrimary => isDark ? Colors.white : const Color(0xFF0F172A);
  Color get textSecondary => isDark ? const Color(0xFF94A3B8) : const Color(0xFF0369A1);
  Color get textMuted => isDark ? Colors.white38 : const Color(0xFF64748B);
  Color get primaryBlue => const Color(0xFF1565C0);
  Color get cyanAccent => isDark ? const Color(0xFF00E5FF) : const Color(0xFF0284C7);
  Color get topBarBg => isDark ? const Color(0xFF0F172A) : Colors.white;
  Color get bottomNavBg => isDark ? const Color(0xFF0F172A) : Colors.white;
  Color get bottomNavUnselected => isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8);
  Color get wavesBg => isDark ? Colors.black : const Color(0xFFF8FAFC);
  Color get wavesLine => isDark ? const Color(0x1F00E5FF) : const Color(0x1F0284C7);
  Color get ringBg => isDark ? const Color(0xFF1E293B) : const Color(0xFFE0F2FE);
  Color get chipBg => isDark ? const Color(0xFF1E293B) : const Color(0xFFF0F9FF);
  Color get inputBorder => isDark ? Colors.transparent : const Color(0xFFBAE6FD);
  Color get shadowColor => isDark ? Colors.black.withValues(alpha: 0.35) : const Color(0x140284C7);

  // Buttons, pills, unselected toggles & components in Light Mode (replaces black with theme blue)
  Color get secondaryBtnBg => isDark ? const Color(0xFF0F172A) : const Color(0xFFE0F2FE);
  Color get secondaryBtnBorder => isDark ? const Color(0xFF00E5FF).withValues(alpha: 0.4) : const Color(0xFFBAE6FD);
  Color get secondaryBtnText => isDark ? const Color(0xFF00E5FF) : const Color(0xFF0284C7);

  // Heatmap 0% / empty tile & progress bar empty track
  Color get emptyComponentBg => isDark ? const Color(0xFF0F172A) : const Color(0xFFE0F2FE);
  Color get emptyComponentBorder => isDark ? Colors.white10 : const Color(0xFFBAE6FD);
  Color get emptyComponentText => isDark ? Colors.white60 : const Color(0xFF0369A1);

  // 7-Day Trend Chart Stat Badges
  Color get statBadgeBg => isDark ? const Color(0xFF0F172A) : const Color(0xFFF0F9FF);
  Color get statBadgeBorder => isDark ? const Color(0xFF00E5FF).withValues(alpha: 0.3) : const Color(0xFFBAE6FD);

  // 7-Day Trend Chart Day Chips (Fri, Sat, etc.)
  Color get dayBadgeBg => isDark ? const Color(0xFF0F172A) : const Color(0xFFE0F2FE);
  Color get dayBadgeBorder => isDark ? Colors.white.withValues(alpha: 0.05) : const Color(0xFFBAE6FD);
  Color get dayBadgeText => isDark ? const Color(0xFF94A3B8) : const Color(0xFF0369A1);
}

