import 'package:cloud_firestore/cloud_firestore.dart';
import 'app_logger.dart';

class UpdateGateResult {
  final bool needsForceUpdate;
  final bool isUpdateAvailable;
  final String title;
  final String message;
  final String playStoreUrl;
  final String latestVersionName;
  final int minVersionCode;

  const UpdateGateResult({
    required this.needsForceUpdate,
    this.isUpdateAvailable = false,
    this.title = 'Update Required',
    this.message =
        'A new update of Hydro Tracker is available on Google Play. Please update to enjoy the latest features, sleek widget, and improvements.',
    this.playStoreUrl =
        'https://play.google.com/store/apps/details?id=com.threestack.hydrotracker',
    this.latestVersionName = '2.2.1',
    this.minVersionCode = 1,
  });
}

class AppUpdateService {
  static const int currentVersionCode = 16;
  static const String currentVersionName = '2.2.1';

  /// Publishes or updates the server-side version gate document in Cloud Firestore.
  static Future<bool> publishVersionGate({
    int minVersionCode = 16,
    String latestVersionName = '2.2.1',
    bool isForceUpdate = true,
  }) async {
    try {
      final docRef = FirebaseFirestore.instance
          .collection('public_leaderboard')
          .doc('app_version_gate');

      await docRef.set({
        'min_version_code': minVersionCode,
        'latest_version_name': latestVersionName,
        'latest_version_code': minVersionCode,
        'is_force_update': isForceUpdate,
        'title': 'Update Required',
        'message':
            'A mandatory update of Hydro Tracker is available on Google Play. Please update to continue tracking your hydration, competing on the leaderboard, and using the smart home widget.',
        'play_store_url':
            'https://play.google.com/store/apps/details?id=com.threestack.hydrotracker',
        'updated_at': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      AppLogger.info('AppUpdateService', 'Successfully published version gate (minVersionCode: $minVersionCode, isForceUpdate: $isForceUpdate)');
      return true;
    } catch (e, st) {
      AppLogger.error('AppUpdateService', 'Error publishing version gate: $e', e, st);
      return false;
    }
  }

  /// Parses Firestore version gate document data into an UpdateGateResult
  static UpdateGateResult parseData(Map<String, dynamic>? data) {
    if (data == null || data.isEmpty) {
      return const UpdateGateResult(needsForceUpdate: false, isUpdateAvailable: false);
    }

    num? rawMinCode;
    num? rawLatestCode;
    bool? rawForceUpdate;
    String? rawTitle;
    String? rawMessage;
    String? rawStoreUrl;
    String? rawLatestName;

    for (final entry in data.entries) {
      final key = entry.key.trim().toLowerCase();
      if (key == 'min_version_code') rawMinCode = entry.value as num?;
      if (key == 'latest_version_code') rawLatestCode = entry.value as num?;
      if (key == 'is_force_update') rawForceUpdate = entry.value as bool?;
      if (key == 'title') rawTitle = entry.value as String?;
      if (key == 'message') rawMessage = entry.value as String?;
      if (key == 'play_store_url') rawStoreUrl = entry.value as String?;
      if (key == 'latest_version_name') rawLatestName = entry.value as String?;
    }

    final minVersionCode = rawMinCode?.toInt() ?? 1;
    final latestVersionCode = rawLatestCode?.toInt() ?? minVersionCode;
    final isForceUpdate = rawForceUpdate ?? false;
    final title = rawTitle ?? 'Update Required';
    final message = rawMessage ??
        'A new update of Hydro Tracker is available on Google Play. Please update to enjoy the latest features and widget improvements.';
    final storeUrl = rawStoreUrl ??
        'https://play.google.com/store/apps/details?id=com.threestack.hydrotracker';
    final latestVersionName = rawLatestName ?? currentVersionName;

    // Compulsory / Force update (blocks entry completely):
    final needsForce = isForceUpdate && (currentVersionCode < minVersionCode);

    // Any update available (shows soft banner or modal):
    final isUpdateAvail = (currentVersionCode < minVersionCode) ||
        (currentVersionCode < latestVersionCode) ||
        (latestVersionName.isNotEmpty && latestVersionName != currentVersionName);

    return UpdateGateResult(
      needsForceUpdate: needsForce,
      isUpdateAvailable: isUpdateAvail,
      title: title,
      message: message,
      playStoreUrl: storeUrl,
      latestVersionName: latestVersionName,
      minVersionCode: minVersionCode,
    );
  }

  /// Real-time stream of the version gate document
  static Stream<UpdateGateResult> streamVersionGate() {
    return FirebaseFirestore.instance
        .collection('public_leaderboard')
        .doc('app_version_gate')
        .snapshots()
        .map((snap) => parseData(snap.data()));
  }

  /// Cloud Firestore Version Gate check
  static Future<UpdateGateResult> checkFirestoreVersionGate() async {
    try {
      final docRef = FirebaseFirestore.instance
          .collection('public_leaderboard')
          .doc('app_version_gate');

      DocumentSnapshot<Map<String, dynamic>> snapshot;
      try {
        snapshot = await docRef
            .get(const GetOptions(source: Source.server))
            .timeout(const Duration(seconds: 4));
      } catch (_) {
        snapshot = await docRef.get(const GetOptions(source: Source.serverAndCache));
      }

      final result = parseData(snapshot.data());
      if (result.needsForceUpdate) {
        AppLogger.warn(
          'AppUpdateService',
          'Current versionCode ($currentVersionCode) is below required minVersionCode (${result.minVersionCode}). Blocking user.',
        );
      }
      return result;
    } catch (e, st) {
      AppLogger.error('AppUpdateService', 'Error checking Firestore version gate', e, st);
      return const UpdateGateResult(needsForceUpdate: false, isUpdateAvailable: false);
    }
  }
}
