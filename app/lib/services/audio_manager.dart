import 'package:flutter/foundation.dart';
import 'package:audio_session/audio_session.dart';
import '../utils/logger.dart';

class AudioManager extends ChangeNotifier {
  bool _isDucked = false;
  bool _isInitialized = false;
  bool _isIntercomMode = false;
  AudioSession? _session;

  bool get isDucked => _isDucked;
  bool get isInitialized => _isInitialized;
  bool get isIntercomMode => _isIntercomMode;

  Future<void> setIntercomMode(bool enabled) async {
    _isIntercomMode = enabled;
    _isInitialized = false; // Force re-initialization
    await init();
  }

  Future<void> init() async {
    if (_isInitialized) return;

    try {
      _session = await AudioSession.instance;

      if (_isIntercomMode) {
        // Intercom Mode (Motorcycle helmet / Bluetooth SCO bidirectional)
        // This configuration opens standard voice routing through bluetooth helmets/headsets.
        await _session!.configure(AudioSessionConfiguration(
          avAudioSessionCategory: AVAudioSessionCategory.playAndRecord,
          avAudioSessionCategoryOptions: 
              AVAudioSessionCategoryOptions.allowBluetooth |
              AVAudioSessionCategoryOptions.defaultToSpeaker,
          avAudioSessionMode: AVAudioSessionMode.voiceChat,
          avAudioSessionRouteSharingPolicy: AVAudioSessionRouteSharingPolicy.defaultPolicy,
          androidAudioAttributes: const AndroidAudioAttributes(
            contentType: AndroidAudioContentType.speech,
            usage: AndroidAudioUsage.voiceCommunication, // Force SCO bidirectional voice communication
          ),
          androidAudioFocusGainType: AndroidAudioFocusGainType.gainTransient, // Direct voice focus
        ));
      } else {
        // Gym Mode (Music Focus: A2DP playback + Phone Internal Microphone)
        // Mixes speech into the music stream at full A2DP quality. NO
        // defaultToSpeaker — the partner's voice must play on the headphones,
        // never the phone loudspeaker. The actual WebRTC routing is set to
        // MEDIA mode in WebRTCService so Android never switches to HFP/call mode.
        await _session!.configure(AudioSessionConfiguration(
          avAudioSessionCategory: AVAudioSessionCategory.playAndRecord,
          avAudioSessionCategoryOptions:
              AVAudioSessionCategoryOptions.mixWithOthers |
              AVAudioSessionCategoryOptions.duckOthers |
              AVAudioSessionCategoryOptions.allowBluetoothA2dp,
          avAudioSessionMode: AVAudioSessionMode.defaultMode,
          avAudioSessionRouteSharingPolicy: AVAudioSessionRouteSharingPolicy.defaultPolicy,
          androidAudioAttributes: const AndroidAudioAttributes(
            contentType: AndroidAudioContentType.speech,
            usage: AndroidAudioUsage.media, // USAGE_MEDIA keeps music on A2DP
          ),
          androidAudioFocusGainType: AndroidAudioFocusGainType.gainTransientMayDuck, // duck, don't pause
        ));
      }

      _isInitialized = true;
      notifyListeners();
      log('Audio session initialized (intercom mode: $_isIntercomMode).');
    } catch (e) {
      log('Failed to initialize audio session: $e');
    }
  }

  /// Activates the audio session which triggers automatic ducking of other audio sources (e.g. Spotify)
  Future<void> duckOthers() async {
    if (!_isInitialized || _session == null) return;
    if (_isDucked) return;

    try {
      // Activating the session ducks other players under our configuration
      final success = await _session!.setActive(true);
      if (success) {
        _isDucked = true;
        notifyListeners();
        log('Audio ducking activated.');
      } else {
        log('Failed to activate audio session for ducking.');
      }
    } catch (e) {
      log('Error activating ducking: $e');
    }
  }

  /// Deactivates the audio session, restoring original volume of other audio sources
  Future<void> unduckOthers() async {
    if (!_isInitialized || _session == null) return;
    if (!_isDucked) return;

    try {
      // Deactivating session restores other audio
      // We pass notifyPlayersOption: AVAudioSessionSetActiveOptions.notifyOthersOnDeactivation
      await _session!.setActive(false);
      _isDucked = false;
      notifyListeners();
      log('Audio ducking deactivated.');
    } catch (e) {
      log('Error deactivating ducking: $e');
    }
  }
}
