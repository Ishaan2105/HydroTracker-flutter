import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class LeaderboardEntry {
  final String uid;
  final String displayName;
  final String? photoUrl;
  final int currentStreak;
  final int bestStreak;
  final int lifetimeVolumeMl;
  final int todayIntakeMl;
  final int dailyGoalMl;
  final String? todayDate;
  final DateTime? updatedAt;
  int rank;

  LeaderboardEntry({
    required this.uid,
    required this.displayName,
    this.photoUrl,
    required this.currentStreak,
    required this.bestStreak,
    required this.lifetimeVolumeMl,
    this.todayIntakeMl = 0,
    this.dailyGoalMl = 2500,
    this.todayDate,
    this.updatedAt,
    this.rank = 0,
  });

  /// Current day's effective intake in ml.
  /// If the record was saved on a previous day, today's intake is 0 until water is logged today.
  int get effectiveTodayIntakeMl {
    final todayStr = DateTime.now().toIso8601String().substring(0, 10);
    if (todayDate != null && todayDate!.isNotEmpty && todayDate != todayStr) {
      return 0;
    }
    return todayIntakeMl;
  }

  /// Current day's percentage of goal achieved
  int get todayPercentage {
    if (dailyGoalMl <= 0) return 0;
    return ((effectiveTodayIntakeMl / dailyGoalMl) * 100).round();
  }

  /// Hydration rank tier title based on today's intake percentage
  String get rankTitle {
    final ratio = dailyGoalMl > 0 ? (effectiveTodayIntakeMl / dailyGoalMl) : 0.0;
    if (ratio >= 0.90) return 'Ocean Master';
    if (ratio >= 0.80) return 'Shield Guardian';
    if (ratio >= 0.70) return 'Wave Rider';
    if (ratio >= 0.60) return 'Current Commander';
    if (ratio >= 0.50) return 'River Guide';
    if (ratio >= 0.40) return 'Stream Sailor';
    if (ratio >= 0.30) return 'Puddle Jumper';
    if (ratio >= 0.20) return 'Dew Dropper';
    if (ratio >= 0.10) return 'Mist Seeker';
    return 'Desert Dweller';
  }

  /// Associated color for the hydration rank tier
  Color get rankColor {
    final ratio = dailyGoalMl > 0 ? (effectiveTodayIntakeMl / dailyGoalMl) : 0.0;
    if (ratio >= 0.90) return const Color(0xFF00E5FF); // Ocean Master - Diamond/Cyan
    if (ratio >= 0.80) return const Color(0xFF10B981); // Shield Guardian - Emerald
    if (ratio >= 0.70) return const Color(0xFF06B6D4); // Wave Rider - Cyan
    if (ratio >= 0.60) return const Color(0xFF3B82F6); // Current Commander - Blue
    if (ratio >= 0.50) return const Color(0xFF6366F1); // River Guide - Indigo
    if (ratio >= 0.40) return const Color(0xFF8B5CF6); // Stream Sailor - Violet
    if (ratio >= 0.30) return const Color(0xFFEC4899); // Puddle Jumper - Pink
    if (ratio >= 0.20) return const Color(0xFFF97316); // Dew Dropper - Orange
    if (ratio >= 0.10) return const Color(0xFFEAB308); // Mist Seeker - Amber
    return const Color(0xFFEF4444); // Desert Dweller - Red
  }

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'displayName': displayName,
      if (photoUrl != null && photoUrl!.isNotEmpty) 'photoUrl': photoUrl,
      'currentStreak': currentStreak,
      'bestStreak': bestStreak,
      'lifetimeVolumeMl': lifetimeVolumeMl,
      'todayIntakeMl': todayIntakeMl,
      'dailyGoalMl': dailyGoalMl,
      if (todayDate != null) 'todayDate': todayDate,
      'todayPercentage': todayPercentage,
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  factory LeaderboardEntry.fromMap(Map<String, dynamic> map, {String? docId}) {
    DateTime? dt;
    try {
      final updatedRaw = map['updatedAt'];
      if (updatedRaw is Timestamp) {
        dt = updatedRaw.toDate();
      } else if (updatedRaw is String) {
        dt = DateTime.parse(updatedRaw);
      }
    } catch (_) {}

    return LeaderboardEntry(
      uid: map['uid']?.toString() ?? docId ?? '',
      displayName: (map['displayName']?.toString() ?? 'Hydro User').trim().isEmpty
          ? 'Hydro User'
          : map['displayName']?.toString() ?? 'Hydro User',
      photoUrl: map['photoUrl']?.toString(),
      currentStreak: (map['currentStreak'] as num?)?.toInt() ?? 0,
      bestStreak: (map['bestStreak'] as num?)?.toInt() ?? 0,
      lifetimeVolumeMl: (map['lifetimeVolumeMl'] as num?)?.toInt() ?? 0,
      todayIntakeMl: (map['todayIntakeMl'] as num?)?.toInt() ?? (map['today_intake_ml'] as num?)?.toInt() ?? 0,
      dailyGoalMl: (map['dailyGoalMl'] as num?)?.toInt() ?? (map['daily_goal_ml'] as num?)?.toInt() ?? 2500,
      todayDate: map['todayDate']?.toString() ?? map['today_date']?.toString(),
      updatedAt: dt,
    );
  }
}
