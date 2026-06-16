import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:vad/vad.dart';
import '../utils/logger.dart';

/// How aggressively VAD gates speech. Default is [strict] — only sustained,
/// confident voice triggers, so gym clangs / road noise are NOT transmitted.
enum VadSensitivity { strict, balanced, sensitive }

/// Silero VAD threshold presets (model v4). Higher positiveSpeechThreshold and
/// minSpeechFrames = fewer false positives on non-voice noise.
class _VadPreset {
  final double positive;
  final double negative;
  final int minSpeechFrames;
  final int redemptionFrames;
  final int preSpeechPadFrames;
  const _VadPreset(this.positive, this.negative, this.minSpeechFrames,
      this.redemptionFrames, this.preSpeechPadFrames);
}

const Map<VadSensitivity, _VadPreset> _vadPresets = {
  // Voice-only: ~0.75 confidence and ~1s of sustained speech before opening.
  VadSensitivity.strict: _VadPreset(0.75, 0.50, 10, 12, 2),
  VadSensitivity.balanced: _VadPreset(0.60, 0.40, 6, 14, 3),
  VadSensitivity.sensitive: _VadPreset(0.50, 0.35, 4, 16, 3),
};

class VadService extends ChangeNotifier {
  VadHandler? _vadHandler;
  bool _isListening = false;
  bool _isSpeaking = false;
  VadSensitivity _sensitivity = VadSensitivity.strict;

  StreamSubscription? _speechStartSub;
  StreamSubscription? _speechEndSub;
  StreamSubscription? _errorSub;

  bool get isListening => _isListening;
  bool get isSpeaking => _isSpeaking;
  VadSensitivity get sensitivity => _sensitivity;

  Function()? onSpeechStartCallback;
  Function()? onSpeechEndCallback;

  /// Change sensitivity. If currently listening, restarts VAD with the new
  /// thresholds so the change takes effect immediately.
  Future<void> setSensitivity(VadSensitivity s) async {
    if (_sensitivity == s) return;
    _sensitivity = s;
    notifyListeners();
    if (_isListening) {
      await stop();
      await start();
    }
  }

  Future<void> init() async {
    // Idempotent: cancel any previous subscriptions so repeated init() calls
    // don't stack duplicate listeners (memory/event leak).
    await _cancelSubs();
    try {
      _vadHandler ??= VadHandler.create(
        onLog: (msg) {
          if (kDebugMode) log('[VAD] $msg');
        },
      );

      _speechStartSub = _vadHandler?.onSpeechStart.listen((_) {
        _isSpeaking = true;
        notifyListeners();
        onSpeechStartCallback?.call();
      });

      _speechEndSub = _vadHandler?.onSpeechEnd.listen((_) {
        _isSpeaking = false;
        notifyListeners();
        onSpeechEndCallback?.call();
      });

      _errorSub = _vadHandler?.onError.listen((err) => log('[VAD] error: $err'));
      log('VAD initialized.');
    } catch (e) {
      log('Failed to initialize VAD: $e');
    }
  }

  Future<void> start() async {
    if (_vadHandler == null) await init();
    if (_isListening) return;
    try {
      final p = _vadPresets[_sensitivity]!;
      await _vadHandler?.startListening(
        positiveSpeechThreshold: p.positive,
        negativeSpeechThreshold: p.negative,
        minSpeechFrames: p.minSpeechFrames,
        redemptionFrames: p.redemptionFrames,
        preSpeechPadFrames: p.preSpeechPadFrames,
      );
      _isListening = true;
      _isSpeaking = false;
      notifyListeners();
      log('VAD listening (sensitivity: ${_sensitivity.name}).');
    } catch (e) {
      log('Error starting VAD: $e');
    }
  }

  Future<void> stop() async {
    if (!_isListening) return;
    try {
      await _vadHandler?.stopListening();
      _isListening = false;
      _isSpeaking = false;
      notifyListeners();
      log('VAD stopped.');
    } catch (e) {
      log('Error stopping VAD: $e');
    }
  }

  Future<void> _cancelSubs() async {
    await _speechStartSub?.cancel();
    await _speechEndSub?.cancel();
    await _errorSub?.cancel();
    _speechStartSub = null;
    _speechEndSub = null;
    _errorSub = null;
  }

  @override
  void dispose() {
    _cancelSubs();
    _vadHandler?.dispose();
    super.dispose();
  }
}
