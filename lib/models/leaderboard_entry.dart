import 'package:cloud_firestore/cloud_firestore.dart';

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
