import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:vad/vad.dart';
import '../utils/logger.dart';

class VadService extends ChangeNotifier {
  VadHandler? _vadHandler;
  bool _isListening = false;
  bool _isSpeaking = false;

  StreamSubscription? _speechStartSub;
  StreamSubscription? _speechEndSub;
  StreamSubscription? _errorSub;

  bool get isListening => _isListening;
  bool get isSpeaking => _isSpeaking;

  Function()? onSpeechStartCallback;
  Function()? onSpeechEndCallback;

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
      await _vadHandler?.startListening();
      _isListening = true;
      _isSpeaking = false;
      notifyListeners();
      log('VAD listening.');
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
