import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../models/water_log.dart';
import '../models/leaderboard_entry.dart';
import '../providers/hydration_provider.dart';
import 'app_logger.dart';
import 'db_helper.dart';
import 'pref_service.dart';

class CloudSyncService {
  static final CloudSyncService instance = CloudSyncService._init();
  CloudSyncService._init();

  FirebaseAuth get _auth => FirebaseAuth.instance;
  FirebaseAuth get auth => _auth;
  FirebaseFirestore get _firestore => FirebaseFirestore.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: ['email', 'profile'],
  );

  bool _isSyncing = false;
  bool get isSyncing => _isSyncing;

  User? get currentUser {
    try {
      return _auth.currentUser;
    } catch (_) {
      return null;
    }
  }
  bool get isSignedIn => currentUser != null;

  /// Initialize Firebase & configure Firestore offline cache
  static Future<void> init() async {
    try {
      await Firebase.initializeApp();
      FirebaseFirestore.instance.settings = const Settings(
        persistenceEnabled: true,
        cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
      );
      AppLogger.info('CloudSyncService', 'Firebase & Cloud Firestore initialized successfully.');
    } catch (e, st) {
      AppLogger.error('CloudSyncService', 'Firebase.initializeApp error: $e', e, st);
    }
  }

  /// Trigger interactive Google Sign-In flow
  Future<UserCredential?> signInWithGoogle() async {
    try {
      AppLogger.info('CloudSyncService', 'Starting Google Sign-In flow...');
      
      // Ensure any existing session is cleanly cleared to allow account picker
      try {
        await _googleSignIn.signOut();
      } catch (_) {}

      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        AppLogger.info('CloudSyncService', 'User aborted Google Sign-In prompt.');
        return null;
      }

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final userCredential = await _auth.signInWithCredential(credential);
      AppLogger.info('CloudSyncService', 'Google Sign-In successful for UID: ${userCredential.user?.uid}');
      return userCredential;
    } catch (e, st) {
      AppLogger.error('CloudSyncService', 'Google Sign-In failed: $e', e, st);
      rethrow;
    }
  }

  /// Sign out of Google & Firebase and clean local device cache
  Future<void> signOut([HydrationProvider? provider]) async {
    try {
      await _googleSignIn.signOut();
      await _auth.signOut();
      await PrefService.setLastSyncedUid(null);
      await DBHelper.instance.clearAllLogs();
      if (provider != null) {
        await provider.resetForSignOut();
      }
      AppLogger.info('CloudSyncService', 'Signed out from Google & Firebase and cleared local session.');
    } catch (e, st) {
      AppLogger.error('CloudSyncService', 'SignOut error: $e', e, st);
    }
  }

  /// Generates a deterministic document key for a water log based on timestamp
  static String logDocId(DateTime timestamp) {
    return 'log_${timestamp.millisecondsSinceEpoch}';
  }

  /// Save or update a single water log to Firestore
  Future<void> syncSingleLog(WaterLog log) async {
    final user = currentUser;
    if (user == null) return;

    try {
      final docId = logDocId(log.timestamp);
      await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('water_logs')
          .doc(docId)
          .set({
        'amount_ml': log.amountMl,
        'timestamp': log.timestamp.toIso8601String(),
        'date_string': log.dateString,
        'updated_at': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e, st) {
      AppLogger.error('CloudSyncService', 'syncSingleLog failed: $e', e, st);
    }
  }

  /// Remove a water log from Firestore when undone or deleted locally
  Future<void> deleteSingleLog(DateTime timestamp) async {
    final user = currentUser;
    if (user == null) return;

    try {
      final docId = logDocId(timestamp);
      await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('water_logs')
          .doc(docId)
          .delete();
    } catch (e, st) {
      AppLogger.error('CloudSyncService', 'deleteSingleLog failed: $e', e, st);
    }
  }

  /// Save profile settings (Daily Goal, User Name, etc.) to Firestore
  Future<void> syncProfileSettings({
    required int dailyGoalMl,
    required String userName,
    required String themeMode,
    int? customGlassMl,
    bool? hasConfiguredGlass,
  }) async {
    final user = currentUser;
    if (user == null) return;

    try {
      final data = <String, dynamic>{
        'daily_goal_ml': dailyGoalMl,
        'user_name': userName,
        'theme_mode': themeMode,
        'email': user.email,
        'display_name': user.displayName,
        'photo_url': user.photoURL,
        'last_synced_at': FieldValue.serverTimestamp(),
      };
      if (customGlassMl != null) data['custom_glass_ml'] = customGlassMl;
      if (hasConfiguredGlass != null) data['has_configured_glass'] = hasConfiguredGlass;

      await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('profile')
          .doc('settings')
          .set(data, SetOptions(merge: true));
    } catch (e, st) {
      AppLogger.error('CloudSyncService', 'syncProfileSettings failed: $e', e, st);
    }
  }

  /// Comprehensive Two-Way Synchronization:
  /// 1. Pulls all cloud water logs into local SQLite (e.g. after fresh install/new device).
  /// 2. Pushes any local SQLite logs not present in Firestore to the cloud.
  /// 3. Restores personal goal and profile settings.
  /// 4. Triggers HydrationProvider to recompute streaks, history & ranks!
  Future<int> performFullTwoWaySync(HydrationProvider provider) async {
    final user = currentUser;
    if (user == null) return 0;
    if (_isSyncing) return 0;

    _isSyncing = true;
    int syncedCount = 0;

    try {
      AppLogger.info('CloudSyncService', 'Starting full two-way cloud sync for UID ${user.uid}...');

      // 0. Account Isolation Check: If switching to a different account, wipe previous user's local logs
      final lastSyncedUid = await PrefService.getLastSyncedUid();
      if (lastSyncedUid != null && lastSyncedUid != user.uid) {
        AppLogger.info('CloudSyncService', 'Account switch detected ($lastSyncedUid -> ${user.uid}). Clearing previous user local database.');
        await DBHelper.instance.clearAllLogs();
        await provider.resetForSignOut();
      }
      await PrefService.setLastSyncedUid(user.uid);

      // 1. Fetch Cloud Settings & Profile
      final settingsDocRef = _firestore
          .collection('users')
          .doc(user.uid)
          .collection('profile')
          .doc('settings');

      final settingsSnapshot = await settingsDocRef.get();
      if (settingsSnapshot.exists && settingsSnapshot.data() != null) {
        final data = settingsSnapshot.data()!;
        final cloudGoal = (data['daily_goal_ml'] as num?)?.toInt();
        final cloudName = data['user_name']?.toString();
        final cloudTheme = data['theme_mode']?.toString();

        if (cloudGoal != null && cloudGoal > 0) {
          await provider.updateGoal(cloudGoal);
        }
        if (cloudName != null && cloudName.trim().isNotEmpty) {
          await provider.updateUserName(cloudName);
        }
        if (cloudTheme != null) {
          await provider.setThemeMode(cloudTheme);
        }
        final cloudGlass = (data['custom_glass_ml'] as num?)?.toInt();
        final cloudHasGlass = data['has_configured_glass'] as bool?;
        if (cloudGlass != null && cloudGlass >= 50 && cloudGlass <= 1000) {
          await provider.setCustomGlassMl(cloudGlass);
        } else if (cloudHasGlass == true) {
          await PrefService.setHasConfiguredGlass(true);
        }
      } else {
        // First-time sync: Upload existing local profile settings to cloud
        await syncProfileSettings(
          dailyGoalMl: provider.dailyGoalMl,
          userName: provider.userName,
          themeMode: provider.themeMode,
          customGlassMl: provider.customGlassMl,
          hasConfiguredGlass: provider.hasConfiguredGlass,
        );
      }

      // 2. Fetch all Cloud Water Logs
      final logsCollectionRef = _firestore
          .collection('users')
          .doc(user.uid)
          .collection('water_logs');

      final cloudLogsSnapshot = await logsCollectionRef.get();
      final Map<int, Map<String, dynamic>> cloudLogsByMillis = {};

      for (var doc in cloudLogsSnapshot.docs) {
        final data = doc.data();
        DateTime? dt;
        try {
          dt = DateTime.parse(data['timestamp']?.toString() ?? '');
        } catch (_) {}

        if (dt != null) {
          cloudLogsByMillis[dt.millisecondsSinceEpoch] = data;
        }
      }

      // 3. Fetch all Local SQLite Water Logs
      final localLogs = await DBHelper.instance.getAllLogs();
      final Set<int> localMillisSet = localLogs.map((l) => l.timestamp.millisecondsSinceEpoch).toSet();

      // 4. Download: Insert Cloud logs into local SQLite if missing locally
      for (var entry in cloudLogsByMillis.entries) {
        final millis = entry.key;
        if (!localMillisSet.contains(millis)) {
          final data = entry.value;
          final amount = (data['amount_ml'] as num?)?.toInt() ?? 0;
          final dateStr = data['date_string']?.toString() ?? '';
          final timestamp = DateTime.fromMillisecondsSinceEpoch(millis);

          if (amount > 0 && dateStr.isNotEmpty) {
            await DBHelper.instance.insertLog(WaterLog(
              amountMl: amount,
              timestamp: timestamp,
              dateString: dateStr,
            ));
            syncedCount++;
          }
        }
      }

      // 5. Upload: Push local SQLite logs to Cloud if missing in Firestore
      final WriteBatch batch = _firestore.batch();
      int batchCount = 0;

      for (var localLog in localLogs) {
        final millis = localLog.timestamp.millisecondsSinceEpoch;
        if (!cloudLogsByMillis.containsKey(millis)) {
          final docRef = logsCollectionRef.doc(logDocId(localLog.timestamp));
          batch.set(docRef, {
            'amount_ml': localLog.amountMl,
            'timestamp': localLog.timestamp.toIso8601String(),
            'date_string': localLog.dateString,
            'updated_at': FieldValue.serverTimestamp(),
          });
          batchCount++;

          // Firestore write batches limit = 500
          if (batchCount >= 450) {
            await batch.commit();
            batchCount = 0;
          }
        }
      }

      if (batchCount > 0) {
        await batch.commit();
      }

      // 6. Refresh provider state so streaks and UI update immediately
      await provider.loadTodayData();
      await provider.loadHistoryStats();
      await provider.loadInsightsData();

      // 7. Sync updated streak & volume to global leaderboard if opted in
      if (provider.isLeaderboardOptIn) {
        await syncLeaderboardEntry(provider);
      }

      AppLogger.info('CloudSyncService', 'Cloud sync finished successfully. Restored $syncedCount logs into local cache.');
    } catch (e, st) {
      AppLogger.error('CloudSyncService', 'performFullTwoWaySync failed: $e', e, st);
    } finally {
      _isSyncing = false;
    }

    return syncedCount;
  }

  /// Push public sanitized stats to the global leaderboard collection
  Future<void> syncLeaderboardEntry(HydrationProvider provider) async {
    final user = currentUser;
    if (user == null) return;
    if (!provider.isLeaderboardOptIn) return;

    try {
      final String name;
      final customName = provider.userName.trim();
      if (customName.isNotEmpty && customName != 'HydroBuddy') {
        name = customName;
      } else {
        // User kept default HydroBuddy -> display his email name
        final email = user.email?.trim() ?? '';
        if (email.isNotEmpty) {
          name = email.contains('@') ? email.split('@').first : email;
        } else {
          name = (user.displayName != null && user.displayName!.trim().isNotEmpty)
              ? user.displayName!.trim()
              : 'HydroBuddy';
        }
      }

      await _firestore.collection('public_leaderboard').doc(user.uid).set({
        'uid': user.uid,
        'displayName': name,
        'photoUrl': user.photoURL ?? '',
        'currentStreak': provider.currentStreak,
        'bestStreak': provider.bestStreak,
        'lifetimeVolumeMl': provider.lifetimeVolumeMl,
        'todayIntakeMl': provider.todayIntakeMl,
        'dailyGoalMl': provider.dailyGoalMl,
        'todayDate': provider.todayDateString,
        'todayPercentage': provider.dailyGoalMl > 0
            ? ((provider.todayIntakeMl / provider.dailyGoalMl) * 100).round()
            : 0,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true)).timeout(const Duration(seconds: 3));
    } catch (e, st) {
      AppLogger.error('CloudSyncService', 'syncLeaderboardEntry failed: $e', e, st);
    }
  }

  /// Updates user opt-in status in cloud profile and adds/removes public leaderboard entry
  Future<void> updateLeaderboardParticipation(HydrationProvider provider, bool isOptedIn) async {
    final user = currentUser;
    if (user == null) return;

    try {
      // 1. Record choice in private cloud profile
      await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('profile')
          .doc('settings')
          .set({'leaderboard_opt_in': isOptedIn}, SetOptions(merge: true));

      if (!isOptedIn) {
        // 2. Delist user from public leaderboard immediately
        await _firestore
            .collection('public_leaderboard')
            .doc(user.uid)
            .delete();
        AppLogger.info('CloudSyncService', 'User delisted from public leaderboard.');
      } else {
        // 3. Relist user with active stats immediately
        await syncLeaderboardEntry(provider);
        AppLogger.info('CloudSyncService', 'User relisted on public leaderboard.');
      }
    } catch (e, st) {
      AppLogger.error('CloudSyncService', 'updateLeaderboardParticipation error: $e', e, st);
    }
  }

  /// Fetches global leaderboard rankings for registered Firebase users only.
  Future<List<LeaderboardEntry>> fetchLeaderboardEntries(HydrationProvider provider) async {
    final Map<String, LeaderboardEntry> entryMap = {};

    try {
      final snapshot = await _firestore
          .collection('public_leaderboard')
          .orderBy('currentStreak', descending: true)
          .limit(100)
          .get(const GetOptions(source: Source.serverAndCache))
          .timeout(const Duration(seconds: 3));

      for (var doc in snapshot.docs) {
        if (doc.id == 'app_version_gate') continue;
        final entry = LeaderboardEntry.fromMap(doc.data(), docId: doc.id);
        if (entry.uid.isNotEmpty) {
          entryMap[entry.uid] = entry;
        }
      }
    } catch (e, st) {
      AppLogger.error('CloudSyncService', 'fetchLeaderboardEntries server query error: $e', e, st);
      // Fallback: try cache if server was unreachable or disabled
      try {
        final cachedSnapshot = await _firestore
            .collection('public_leaderboard')
            .orderBy('currentStreak', descending: true)
            .limit(100)
            .get(const GetOptions(source: Source.cache))
            .timeout(const Duration(seconds: 1));

        for (var doc in cachedSnapshot.docs) {
          if (doc.id == 'app_version_gate') continue;
          final entry = LeaderboardEntry.fromMap(doc.data(), docId: doc.id);
          if (entry.uid.isNotEmpty) {
            entryMap[entry.uid] = entry;
          }
        }
      } catch (_) {}
    }

    // Ensure current signed-in Firebase user has their latest live streak & volume reflected
    final user = currentUser;
    if (user != null && provider.isLeaderboardOptIn) {
      final String currentName;
      final customName = provider.userName.trim();
      if (customName.isNotEmpty && customName != 'HydroBuddy') {
        currentName = customName;
      } else {
        final email = user.email?.trim() ?? '';
        if (email.isNotEmpty) {
          currentName = email.contains('@') ? email.split('@').first : email;
        } else {
          currentName = (user.displayName != null && user.displayName!.trim().isNotEmpty)
              ? user.displayName!.trim()
              : 'Hydro User';
        }
      }

      entryMap[user.uid] = LeaderboardEntry(
        uid: user.uid,
        displayName: currentName,
        photoUrl: user.photoURL,
        currentStreak: provider.currentStreak,
        bestStreak: provider.bestStreak,
        lifetimeVolumeMl: provider.lifetimeVolumeMl,
        todayIntakeMl: provider.todayIntakeMl,
        dailyGoalMl: provider.dailyGoalMl,
        todayDate: provider.todayDateString,
        updatedAt: DateTime.now(),
      );
    } else if (user != null && !provider.isLeaderboardOptIn) {
      // User opted out: remove from public list
      entryMap.remove(user.uid);
    }

    // Sort strictly:
    // 1. Primary: currentStreak DESC
    // 2. Secondary Tie-Breaker: today's / current day's water intake DESC (when streaks are equal or 0)
    // 3. Tertiary Tie-Breaker: today's goal percentage achieved DESC
    // 4. Quaternary: lifetimeVolumeMl DESC
    final list = entryMap.values.toList();
    list.sort((a, b) {
      final streakCmp = b.currentStreak.compareTo(a.currentStreak);
      if (streakCmp != 0) return streakCmp;
      final todayCmp = b.effectiveTodayIntakeMl.compareTo(a.effectiveTodayIntakeMl);
      if (todayCmp != 0) return todayCmp;
      final percentCmp = b.todayPercentage.compareTo(a.todayPercentage);
      if (percentCmp != 0) return percentCmp;
      return b.lifetimeVolumeMl.compareTo(a.lifetimeVolumeMl);
    });

    for (int i = 0; i < list.length; i++) {
      list[i].rank = i + 1;
    }

    return list;
  }

  /// Real-time stream of global leaderboard rankings from Firestore.
  Stream<List<LeaderboardEntry>> streamLeaderboardEntries(HydrationProvider provider) {
    return _firestore
        .collection('public_leaderboard')
        .orderBy('currentStreak', descending: true)
        .limit(100)
        .snapshots(includeMetadataChanges: true)
        .map((snapshot) {
      final Map<String, LeaderboardEntry> entryMap = {};

      for (var doc in snapshot.docs) {
        if (doc.id == 'app_version_gate') continue;
        final entry = LeaderboardEntry.fromMap(doc.data(), docId: doc.id);
        if (entry.uid.isNotEmpty) {
          entryMap[entry.uid] = entry;
        }
      }

      final user = currentUser;
      if (user != null && provider.isLeaderboardOptIn) {
        final String currentName;
        final customName = provider.userName.trim();
        if (customName.isNotEmpty && customName != 'HydroBuddy') {
          currentName = customName;
        } else {
          final email = user.email?.trim() ?? '';
          if (email.isNotEmpty) {
            currentName = email.contains('@') ? email.split('@').first : email;
          } else {
            currentName = (user.displayName != null && user.displayName!.trim().isNotEmpty)
                ? user.displayName!.trim()
                : 'Hydro User';
          }
        }

        entryMap[user.uid] = LeaderboardEntry(
          uid: user.uid,
          displayName: currentName,
          photoUrl: user.photoURL,
          currentStreak: provider.currentStreak,
          bestStreak: provider.bestStreak,
          lifetimeVolumeMl: provider.lifetimeVolumeMl,
          todayIntakeMl: provider.todayIntakeMl,
          dailyGoalMl: provider.dailyGoalMl,
          todayDate: provider.todayDateString,
          updatedAt: DateTime.now(),
        );
      } else if (user != null && !provider.isLeaderboardOptIn) {
        entryMap.remove(user.uid);
      }

      final list = entryMap.values.toList();
      list.sort((a, b) {
        final streakCmp = b.currentStreak.compareTo(a.currentStreak);
        if (streakCmp != 0) return streakCmp;
        final todayCmp = b.effectiveTodayIntakeMl.compareTo(a.effectiveTodayIntakeMl);
        if (todayCmp != 0) return todayCmp;
        final percentCmp = b.todayPercentage.compareTo(a.todayPercentage);
        if (percentCmp != 0) return percentCmp;
        return b.lifetimeVolumeMl.compareTo(a.lifetimeVolumeMl);
      });

      for (int i = 0; i < list.length; i++) {
        list[i].rank = i + 1;
      }

      return list;
    });
  }
}
