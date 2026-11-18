import 'package:cloud_firestore/cloud_firestore.dart';
import 'app_logger.dart';

class UpdateGateResult {
  final bool needsForceUpdate;
  final String title;
  final String message;
  final String playStoreUrl;

  const UpdateGateResult({
    required this.needsForceUpdate,
    this.title = 'Update Required',
    this.message =
        'A mandatory update of Hydro Tracker is available on Google Play. Please update to continue tracking your hydration, competing on the leaderboard, and using the smart home widget.',
    this.playStoreUrl =
        'https://play.google.com/store/apps/details?id=com.threestack.hydrotracker',
  });
}

class AppUpdateService {
  static const int currentVersionCode = 5;
  static const String currentVersionName = '2.1.0';

  /// Publishes or updates the server-side version gate document in Cloud Firestore.
  /// When called, sets the remote min_version_code to 5 and enables mandatory force update.
  static Future<bool> publishVersionGate({
    int minVersionCode = 5,
    String latestVersionName = '2.1.0',
    bool isForceUpdate = true,
  }) async {
    try {
      final docRef = FirebaseFirestore.instance
          .collection('public_leaderboard')
          .doc('app_version_gate');

      await docRef.set({
        'min_version_code': minVersionCode,
        'latest_version_name': latestVersionName,
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

  /// Cloud Firestore Version Gate (Server-side killswitch / mandatory update barrier)
  ///
  /// Document path: `/public_leaderboard/app_version_gate`
  /// Reads config without requiring user authentication. If `is_force_update == true`
  /// and the installed app's `currentVersionCode < min_version_code`, it returns
  /// `needsForceUpdate: true` which renders the un-dismissible ForceUpdateScreen.
  static Future<UpdateGateResult> checkFirestoreVersionGate() async {
    try {
      final docRef = FirebaseFirestore.instance
          .collection('public_leaderboard')
          .doc('app_version_gate');

      final snapshot = await docRef.get(const GetOptions(source: Source.serverAndCache));

      if (!snapshot.exists || snapshot.data() == null) {
        return const UpdateGateResult(needsForceUpdate: false);
      }

      final data = snapshot.data()!;
      final minVersionCode = (data['min_version_code'] as num?)?.toInt() ?? 1;
      final isForceUpdate = (data['is_force_update'] as bool?) ?? false;
      final title = data['title'] as String? ?? 'Update Required';
      final message = data['message'] as String? ??
          'A mandatory update of Hydro Tracker is available on Google Play. Please update to continue.';
      final storeUrl = data['play_store_url'] as String? ??
          'https://play.google.com/store/apps/details?id=com.threestack.hydrotracker';

      if (isForceUpdate && currentVersionCode < minVersionCode) {
        AppLogger.warn(
          'AppUpdateService',
          'Current versionCode ($currentVersionCode) is below required minVersionCode ($minVersionCode). Blocking user.',
        );
        return UpdateGateResult(
          needsForceUpdate: true,
          title: title,
          message: message,
          playStoreUrl: storeUrl,
        );
      }

      return const UpdateGateResult(needsForceUpdate: false);
    } catch (e, st) {
      AppLogger.error('AppUpdateService', 'Error checking Firestore version gate', e, st);
      return const UpdateGateResult(needsForceUpdate: false);
    }
  }
}
