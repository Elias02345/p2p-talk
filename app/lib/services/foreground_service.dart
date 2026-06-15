import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import '../utils/logger.dart';

/// Wraps flutter_foreground_task so an active call/VAD session keeps the mic
/// capture alive when the screen locks or the app is backgrounded — without
/// this, Android suspends the session and the connection drops ("never
/// interrupted" requirement). The service runs only while a call is active.
class P2PForegroundService {
  static bool _initialized = false;

  static void _ensureInit() {
    if (_initialized) return;
    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'p2ptalk_call',
        channelName: 'Active call',
        channelDescription: 'Shown while a p2p-talk voice session is active.',
        channelImportance: NotificationChannelImportance.LOW,
        priority: NotificationPriority.LOW,
        onlyAlertOnce: true,
      ),
      iosNotificationOptions: const IOSNotificationOptions(),
      foregroundTaskOptions: ForegroundTaskOptions(
        eventAction: ForegroundTaskEventAction.nothing(),
        allowWakeLock: true,
        allowWifiLock: true,
        autoRunOnBoot: false,
      ),
    );
    _initialized = true;
  }

  /// Start the foreground service for an active session.
  static Future<void> start({required String title, required String text}) async {
    _ensureInit();
    try {
      if (await FlutterForegroundTask.isRunningService) return;
      await FlutterForegroundTask.requestNotificationPermission();
      await FlutterForegroundTask.startService(
        serviceTypes: [ForegroundServiceTypes.microphone],
        notificationTitle: title,
        notificationText: text,
      );
    } catch (e) {
      log('Foreground service start error: $e');
    }
  }

  static Future<void> stop() async {
    try {
      if (await FlutterForegroundTask.isRunningService) {
        await FlutterForegroundTask.stopService();
      }
    } catch (e) {
      log('Foreground service stop error: $e');
    }
  }
}
