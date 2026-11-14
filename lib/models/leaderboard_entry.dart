import 'package:cloud_firestore/cloud_firestore.dart';

class LeaderboardEntry {
  final String uid;
  final String displayName;
  final String? photoUrl;
  final int currentStreak;
  final int bestStreak;
  final int lifetimeVolumeMl;
  final DateTime? updatedAt;
  int rank;

  LeaderboardEntry({
    required this.uid,
    required this.displayName,
    this.photoUrl,
    required this.currentStreak,
    required this.bestStreak,
    required this.lifetimeVolumeMl,
    this.updatedAt,
    this.rank = 0,
  });

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'displayName': displayName,
      if (photoUrl != null && photoUrl!.isNotEmpty) 'photoUrl': photoUrl,
      'currentStreak': currentStreak,
      'bestStreak': bestStreak,
      'lifetimeVolumeMl': lifetimeVolumeMl,
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
      updatedAt: dt,
    );
  }
}
