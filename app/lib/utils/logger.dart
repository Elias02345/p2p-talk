import 'package:flutter/foundation.dart';

/// Lightweight debug logger. Logs only in debug/profile builds and never in
/// release, so it stays cheap and avoids leaking diagnostics in production.
void log(String message) {
  if (kDebugMode) {
    debugPrint('[p2p-talk] $message');
  }
}
