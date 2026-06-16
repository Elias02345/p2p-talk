import 'dart:async';
import 'dart:convert';
import 'dart:io' show gzip;
import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:http/http.dart' as http;
import 'audio_manager.dart';
import 'connection_manager.dart';
import 'notification_service.dart';
import 'account_service.dart';
import '../utils/logger.dart';

enum P2PConnectionState { disconnected, connecting, connected }

class WebRTCService extends ChangeNotifier {
  final AudioManager _audioManager;
  final ConnectionManager _connectionManager;
  final NotificationService _notificationService;
  final AccountService _account;

  String _serverUrl = 'http://localhost:3000';
  bool _isWebSocketConnected = false; // true while the HTTP long-poll loop runs
  int _pollGen = 0; // bump to cancel an in-flight poll loop

  // Multi-peer WebRTC: peerId (accountId) -> objects
  final Map<String, RTCPeerConnection> _peerConnections = {};
  final Map<String, MediaStream> _remoteStreams = {};
  final Map<String, RTCDataChannel> _dataChannels = {};
  final Map<String, bool> _isInitiatorFor = {};
  final Map<String, AuthChain> _peerChains = {};
  final Set<String> _verifiedPeers = {};
  MediaStream? _localStream;

  P2PConnectionState _connectionState = P2PConnectionState.disconnected;
  String? _activePartnerId;
  String? _activePartnerName;

  Timer? _reconnectTimer;
  Timer? _latencyTimer;
  Timer? _iceMonitorTimer;
  bool _intentionalDisconnect = false;
  bool _appForeground = true;
  bool _intercomActive = false;

  // Cached ICE configuration from /api/ice
  Map<String, dynamic>? _iceConfig;
  DateTime? _iceConfigExpiry;

  // Per-peer ICE-restart backoff bookkeeping
  final Map<String, int> _relayRestartCount = {};
  final Map<String, DateTime> _lastRelayRestart = {};

  // Non-trickle pairing: per-peer ICE-gathering completer + collected candidates
  final Map<String, Completer<void>> _iceGatherComplete = {};
  final Map<String, List<RTCIceCandidate>> _pairingCandidates = {};

  // Fallback STUN config if /api/ice is unreachable.
  static const Map<String, dynamic> _fallbackIce = {
    'iceServers': [
      {'urls': 'stun:stun.l.google.com:19302'},
    ],
  };

  // Callbacks for UI
  Function(String fromId, String fromName)? onCallRequestReceived;
  Function(String fromId)? onCallEnded;
  Function(String peerId, bool isSpeaking)? onPeerSpeakingChanged;
  Function(String peerId)? onPeerVerificationFailed;

  WebRTCService(this._audioManager, this._connectionManager, this._notificationService, this._account);

  // Getters
  String get serverUrl => _serverUrl;
  bool get isWebSocketConnected => _isWebSocketConnected;
  P2PConnectionState get connectionState => _connectionState;
  String? get activePartnerId => _activePartnerId;
  String? get activePartnerName => _activePartnerName;
  int get connectedPeerCount => _peerConnections.length;
  bool isPeerVerified(String id) => _verifiedPeers.contains(id);

  Future<void> init(String serverUrl) async {
    _serverUrl = serverUrl;
    _account.setApiBaseUrl(serverUrl);
    _connectionManager.clearRoom();
  }

  void updateServerUrl(String url) {
    _serverUrl = url;
    _account.setApiBaseUrl(url);
    connectWebSocket();
  }

  /// App lifecycle hook — gates the battery-sensitive ICE regain loop.
  void setForeground(bool foreground) {
    _appForeground = foreground;
  }

  /// Marks the local intercom channel as on/off. While on, incoming connections
  /// from partners open automatically (an open channel, not a ringing call).
  void setIntercomActive(bool active) {
    _intercomActive = active;
  }

  // --- HTTP long-poll signaling (CloudGate / plain HTTP, no WebSocket) ------

  String get _httpBase => _serverUrl
      .replaceFirst('ws://', 'http://')
      .replaceFirst('wss://', 'https://')
      .replaceAll(RegExp(r'/+$'), '');

  /// Connect the signaling transport (HTTP long-poll). Name kept for callers.
  Future<void> connectWebSocket() async {
    if (!_account.isRegistered) return;
    _intentionalDisconnect = false;
    if (_isWebSocketConnected) return; // already polling

    final token = await _account.getToken();
    if (token == null) {
      log('No session token — cannot connect signaling');
      _scheduleReconnect();
      return;
    }

    log('Connecting signaling (HTTP) to: $_httpBase');
    _isWebSocketConnected = true;
    if (_connectionManager.reconnectAttempts > 0) _notificationService.notifyReconnected();
    _connectionManager.onConnected();
    _connectionManager.resetReconnect();
    notifyListeners();
    _startLatencyTimer();
    _pollLoop(++_pollGen);
  }

  Future<void> _pollLoop(int gen) async {
    while (_isWebSocketConnected && !_intentionalDisconnect && gen == _pollGen) {
      try {
        final token = await _account.getToken();
        if (token == null) {
          _onSignalingDown();
          return;
        }
        final res = await http
            .post(Uri.parse('$_httpBase/api/rtc/poll'),
                headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $token'},
                body: '{}')
            .timeout(const Duration(seconds: 35));
        if (gen != _pollGen) return; // superseded by a newer loop
        if (res.statusCode == 200) {
          final data = jsonDecode(res.body);
          final msgs = (data['messages'] as List?) ?? const [];
          for (final m in msgs) {
            await _handleSignal(Map<String, dynamic>.from(m));
          }
        } else if (res.statusCode == 401) {
          continue; // token expired — refreshed next iteration
        } else {
          _onSignalingDown();
          return;
        }
      } catch (e) {
        log('poll error: $e');
        _onSignalingDown();
        return;
      }
    }
  }

  void _onSignalingDown() {
    if (!_isWebSocketConnected) return;
    _isWebSocketConnected = false;
    _stopLatencyTimer();
    if (_peerConnections.isEmpty) _connectionState = P2PConnectionState.disconnected;
    notifyListeners();
    log('Signaling connection lost.');
    if (!_intentionalDisconnect) {
      _notificationService.notifyConnectionLost();
      _scheduleReconnect();
    }
  }

  void _scheduleReconnect() {
    if (_intentionalDisconnect) return;
    if (!_connectionManager.onDisconnected()) {
      log('Max reconnect attempts reached.');
      return;
    }
    final delay = _connectionManager.getReconnectDelay();
    log('Reconnect in ${delay.inSeconds}s (attempt ${_connectionManager.reconnectAttempts})');
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(delay, connectWebSocket);
  }

  Future<void> disconnectWebSocket({bool intentional = true}) async {
    _intentionalDisconnect = intentional;
    _reconnectTimer?.cancel();
    _stopLatencyTimer();
    _pollGen++; // cancel any in-flight poll loop
    final wasConnected = _isWebSocketConnected;
    _isWebSocketConnected = false;
    notifyListeners();
    if (intentional && wasConnected) {
      final token = await _account.getToken();
      if (token != null) {
        try {
          await http
              .post(Uri.parse('$_httpBase/api/rtc/disconnect'),
                  headers: {'Authorization': 'Bearer $token'})
              .timeout(const Duration(seconds: 5));
        } catch (_) {}
      }
    }
  }

  /// Send a signaling message (fire-and-forget HTTP POST).
  void _send(Map<String, dynamic> data) {
    if (!_isWebSocketConnected) return;
    () async {
      final token = await _account.getToken();
      if (token == null) return;
      try {
        await http
            .post(Uri.parse('$_httpBase/api/rtc/send'),
                headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $token'},
                body: jsonEncode(data))
            .timeout(const Duration(seconds: 10));
      } catch (e) {
        log('signal send error: $e');
      }
    }();
  }

  Future<void> _handleSignal(Map<String, dynamic> msg) async {
    switch (msg['type']) {
      case 'contact_request':
        _notificationService.notifyContactRequest(msg['from'] ?? '');
        break;

      case 'call_request':
        final fromId = msg['from'];
        // Intercom model (not a phone call): if the local channel is on, the
        // partner connection opens automatically — no ringing, no accept dialog.
        if (_intercomActive || msg['autoConnect'] == true) {
          acceptCall(fromId);
        }
        break;

      case 'call_response':
        final fromId = msg['from'];
        if (msg['accepted'] == true) {
          _activePartnerId = fromId;
          _connectionState = P2PConnectionState.connecting;
          notifyListeners();
          await _startCallSession(fromId, isInitiator: true);
        } else {
          _connectionState = P2PConnectionState.disconnected;
          _activePartnerId = null;
          notifyListeners();
        }
        break;

      case 'signaling':
        await _handleSignalingPayload(msg['from'], msg['payload']);
        break;

      case 'room_joined':
        final members = List<String>.from(msg['members'] ?? []);
        _connectionManager.setRoom(RoomInfo(id: msg['roomId'], name: 'Room', memberIds: members));
        for (final m in members) {
          if (m == _account.accountId) continue;
          _connectionManager.addPeer(m, 'Peer');
          if (_amOfferer(m)) await _startCallSession(m, isInitiator: true);
        }
        break;

      case 'room_member_joined':
        final peerId = msg['userId'];
        final peerName = msg['username'] ?? 'Peer';
        if (peerId != null && peerId != _account.accountId) {
          _connectionManager.addPeer(peerId, peerName);
          _notificationService.notifyPeerJoined(peerName);
          if (_amOfferer(peerId)) await _startCallSession(peerId, isInitiator: true);
        }
        break;

      case 'room_member_left':
        _connectionManager.removePeer(msg['userId']);
        await _disconnectPeer(msg['userId']);
        break;

      case 'room_signaling':
        await _handleSignalingPayload(msg['from'], msg['payload']);
        break;

      case 'error':
        log('Server: ${msg['message']}');
        break;
    }
  }

  bool _amOfferer(String peerId) =>
      (_account.accountId ?? '').compareTo(peerId) < 0;

  // --- call lifecycle -------------------------------------------------------

  Future<void> sendCallRequest(String targetId, {bool autoConnect = false}) async {
    if (_connectionState != P2PConnectionState.disconnected) return;
    _connectionState = P2PConnectionState.connecting;
    _activePartnerId = targetId;
    notifyListeners();
    _send({'type': 'call_request', 'targetId': targetId, 'autoConnect': autoConnect});
  }

  Future<void> acceptCall(String targetId) async {
    _activePartnerId = targetId;
    _connectionState = P2PConnectionState.connecting;
    notifyListeners();
    _send({'type': 'call_response', 'targetId': targetId, 'accepted': true});
    await _startCallSession(targetId, isInitiator: false);
  }

  Future<void> rejectCall(String targetId) async {
    _send({'type': 'call_response', 'targetId': targetId, 'accepted': false});
    if (_activePartnerId == targetId) {
      _activePartnerId = null;
      _connectionState = P2PConnectionState.disconnected;
      notifyListeners();
    }
  }

  Future<void> joinGroupRoom(String roomId, {String? roomName}) async {
    if (!_account.isRegistered) return;
    _send({'type': 'join_room', 'roomId': roomId, 'username': _account.username});
    _connectionState = P2PConnectionState.connecting;
    notifyListeners();
  }

  Future<void> leaveGroupRoom() async {
    final room = _connectionManager.currentRoom;
    if (room == null) return;
    _send({'type': 'leave_room', 'roomId': room.id});
    for (final peerId in List.from(_peerConnections.keys)) {
      await _disconnectPeer(peerId);
    }
    _connectionManager.clearRoom();
    _connectionState = P2PConnectionState.disconnected;
    notifyListeners();
  }

  Future<void> disconnectCall() async {
    if (_connectionState == P2PConnectionState.disconnected && _peerConnections.isEmpty) return;
    log('Disconnecting call session...');
    for (final peerId in List.from(_peerConnections.keys)) {
      await _disconnectPeer(peerId);
    }
    if (_localStream != null) {
      for (final track in _localStream!.getTracks()) {
        await track.stop();
      }
      await _localStream!.dispose();
      _localStream = null;
    }
    _connectionState = P2PConnectionState.disconnected;
    await _audioManager.unduckOthers();
    // Reset any audio device the native layer grabbed for the session.
    try {
      await Helper.clearAndroidCommunicationDevice();
    } catch (_) {}
    _stopIceMonitor();
    final partnerId = _activePartnerId;
    _activePartnerId = null;
    _activePartnerName = null;
    notifyListeners();
    if (partnerId != null && onCallEnded != null) onCallEnded!(partnerId);
  }

  Future<void> _disconnectPeer(String peerId) async {
    _dataChannels.remove(peerId)?.close();
    final pc = _peerConnections.remove(peerId);
    if (pc != null) await pc.close();
    _remoteStreams.remove(peerId);
    _peerChains.remove(peerId);
    _verifiedPeers.remove(peerId);
    _isInitiatorFor.remove(peerId);
    _relayRestartCount.remove(peerId);
    _lastRelayRestart.remove(peerId);
    _iceGatherComplete.remove(peerId);
    _pairingCandidates.remove(peerId);
  }

  // --- ICE configuration ----------------------------------------------------

  Future<Map<String, dynamic>> _getIceConfig() async {
    if (_iceConfig != null && _iceConfigExpiry != null && DateTime.now().isBefore(_iceConfigExpiry!)) {
      return {'iceServers': _iceConfig!['iceServers']};
    }
    try {
      final body = await _account.fetchIce();
      if (body != null && body['iceServers'] != null) {
        _iceConfig = body;
        final ttl = (body['ttl'] as int?) ?? 3600;
        _iceConfigExpiry = DateTime.now().add(Duration(seconds: ttl - 120));
        return {'iceServers': body['iceServers']};
      }
    } catch (e) {
      log('getIceConfig error: $e');
    }
    return _fallbackIce;
  }

  // --- WebRTC session -------------------------------------------------------

  /// Configure how WebRTC routes audio on the OS. This is the heart of the
  /// "not a phone call" behaviour and MUST be applied before the session starts
  /// (the native layer cannot change it mid-session).
  ///
  /// Gym mode: MODE_NORMAL + MEDIA/MUSIC routing → the partner's voice is mixed
  /// into the same A2DP media stream as the music (full stereo quality, never
  /// the loudspeaker), and the phone's built-in mic is used (no HFP/SCO switch,
  /// so the music is NOT downgraded to call quality).
  ///
  /// Intercom mode: full bidirectional SCO/HFP for a motorcycle-helmet headset.
  Future<void> _applyAudioRouting() async {
    try {
      if (_audioManager.isIntercomMode) {
        await Helper.setAndroidAudioConfiguration(AndroidAudioConfiguration.communication);
        await Helper.setAppleAudioConfiguration(AppleAudioConfiguration(
          appleAudioCategory: AppleAudioCategory.playAndRecord,
          appleAudioCategoryOptions: {
            AppleAudioCategoryOption.allowBluetooth,
            AppleAudioCategoryOption.mixWithOthers,
          },
          appleAudioMode: AppleAudioMode.voiceChat,
        ));
      } else {
        // Media routing: NOT communication mode → no HFP downgrade, no loudspeaker.
        // manageAudioFocus:false so we duck transiently (only while a peer speaks)
        // via AudioManager instead of holding focus for the whole session.
        await Helper.setAndroidAudioConfiguration(AndroidAudioConfiguration(
          manageAudioFocus: false,
          androidAudioMode: AndroidAudioMode.normal,
          androidAudioStreamType: AndroidAudioStreamType.music,
          androidAudioAttributesUsageType: AndroidAudioAttributesUsageType.media,
          androidAudioAttributesContentType: AndroidAudioAttributesContentType.speech,
        ));
        await Helper.setAppleAudioConfiguration(AppleAudioConfiguration(
          appleAudioCategory: AppleAudioCategory.playAndRecord,
          appleAudioCategoryOptions: {
            AppleAudioCategoryOption.mixWithOthers,
            AppleAudioCategoryOption.allowBluetoothA2DP,
            AppleAudioCategoryOption.duckOthers,
          },
          appleAudioMode: AppleAudioMode.default_,
        ));
      }
    } catch (e) {
      log('audio routing config error: $e');
    }
  }

  Future<void> _ensureLocalStream() async {
    if (_localStream != null) return;
    // Routing must be set before the WebRTC session opens the audio device.
    await _applyAudioRouting();
    final constraints = {
      'audio': {
        'channelCount': 1,
        'echoCancellation': true,
        'noiseSuppression': true,
        'autoGainControl': true,
      },
      'video': false,
    };
    _localStream = await navigator.mediaDevices.getUserMedia(constraints);
    // Start MUTED: transmit only while speaking (VAD-gated). Silence and
    // ambient gym/road noise are never sent.
    _enableLocalAudio(false);
  }

  /// Shared peer-connection wiring (connection-state + remote track handling),
  /// used by both server-signaled calls and serverless (QR/LAN) pairing.
  void _wirePeerCommon(String partnerId, RTCPeerConnection pc) {
    pc.onConnectionState = (state) {
      log('PC state ($partnerId): $state');
      if (state == RTCPeerConnectionState.RTCPeerConnectionStateConnected) {
        _connectionState = P2PConnectionState.connected;
        _connectionManager.setPeerConnected(partnerId, true);
        // Mic stays muted until VAD detects speech.
        _startIceMonitor();
        notifyListeners();
      } else if (state == RTCPeerConnectionState.RTCPeerConnectionStateDisconnected ||
          state == RTCPeerConnectionState.RTCPeerConnectionStateFailed ||
          state == RTCPeerConnectionState.RTCPeerConnectionStateClosed) {
        _connectionManager.setPeerConnected(partnerId, false);
        _disconnectPeer(partnerId);
        if (_peerConnections.isEmpty) {
          _connectionState = P2PConnectionState.disconnected;
          _stopIceMonitor();
          notifyListeners();
        }
      }
    };
    pc.onTrack = (event) {
      if (event.streams.isNotEmpty) {
        _remoteStreams[partnerId] = event.streams[0];
        log('Remote track from $partnerId.');
      }
    };
  }

  Future<void> _startCallSession(String partnerId, {required bool isInitiator}) async {
    try {
      _isInitiatorFor[partnerId] = isInitiator;
      final config = await _getIceConfig();
      final pc = await createPeerConnection(config);
      _peerConnections[partnerId] = pc;

      _wirePeerCommon(partnerId, pc);

      pc.onIceCandidate = (candidate) {
        _sendSignaling(partnerId, {
          'candidate': {
            'candidate': candidate.candidate,
            'sdpMid': candidate.sdpMid,
            'sdpMLineIndex': candidate.sdpMLineIndex,
          }
        });
      };

      await _ensureLocalStream();
      for (final track in _localStream!.getTracks()) {
        await pc.addTrack(track, _localStream!);
      }

      if (isInitiator) {
        final dc = await pc.createDataChannel(
          'p2ptalk_ctrl',
          RTCDataChannelInit()..binaryType = 'text',
        );
        _dataChannels[partnerId] = dc;
        _setupDataChannel(partnerId, dc);

        final offer = await pc.createOffer();
        final munged = RTCSessionDescription(_mungeSdp(offer.sdp!), offer.type);
        await pc.setLocalDescription(munged);
        await _sendSdp(partnerId, munged);
      } else {
        pc.onDataChannel = (channel) {
          _dataChannels[partnerId] = channel;
          _setupDataChannel(partnerId, channel);
        };
      }
    } catch (e) {
      log('Session setup failed with $partnerId: $e');
      await _disconnectPeer(partnerId);
    }
  }

  void _setupDataChannel(String peerId, RTCDataChannel channel) {
    channel.onMessage = (data) {
      final msg = data.text;
      if (msg == 'speech_start') {
        _audioManager.duckOthers();
        _connectionManager.setPeerSpeaking(peerId, true);
        onPeerSpeakingChanged?.call(peerId, true);
      } else if (msg == 'speech_end') {
        final anyoneElse = _connectionManager.peers.values.any((p) => p.id != peerId && p.isSpeaking);
        if (!anyoneElse) _audioManager.unduckOthers();
        _connectionManager.setPeerSpeaking(peerId, false);
        onPeerSpeakingChanged?.call(peerId, false);
      }
    };
  }

  /// Build the SDP signaling payload, including the signed DTLS fingerprint and
  /// the device→identity authorization chain (anti-MitM).
  Future<void> _sendSdp(String targetId, RTCSessionDescription desc) async {
    final fingerprint = _extractFingerprint(desc.sdp!);
    final payload = <String, dynamic>{'sdp': desc.sdp, 'type': desc.type};
    if (fingerprint != null) {
      final sig = await _account.signPayload(fingerprint);
      final chain = _account.authChain;
      if (sig != null && chain != null) {
        payload['fpSig'] = sig;
        payload['auth'] = chain.toJson();
      }
    }
    _sendSignaling(targetId, payload);
  }

  Future<void> _handleSignalingPayload(String fromId, dynamic payload) async {
    try {
      if (payload['sdp'] != null) {
        // Verify the peer's signed fingerprint chain before trusting the SDP.
        if (payload['auth'] != null && payload['fpSig'] != null) {
          final chain = AuthChain.fromJson(Map<String, dynamic>.from(payload['auth']));
          final fp = _extractFingerprint(payload['sdp']);
          final ok = fp != null && await _account.verifyPeerSignature(chain, fp, payload['fpSig']);
          if (!ok) {
            log('SECURITY: peer $fromId fingerprint verification FAILED — aborting.');
            onPeerVerificationFailed?.call(fromId);
            await _disconnectPeer(fromId);
            return;
          }
          _peerChains[fromId] = chain;
          _verifiedPeers.add(fromId);
        }

        if (!_peerConnections.containsKey(fromId)) {
          await _startCallSession(fromId, isInitiator: false);
        }
        final pc = _peerConnections[fromId];
        if (pc == null) return;
        await pc.setRemoteDescription(RTCSessionDescription(payload['sdp'], payload['type']));

        if (payload['type'] == 'offer') {
          final answer = await pc.createAnswer();
          final munged = RTCSessionDescription(_mungeSdp(answer.sdp!), answer.type);
          await pc.setLocalDescription(munged);
          await _sendSdp(fromId, munged);
        }
      } else if (payload['candidate'] != null) {
        final pc = _peerConnections[fromId];
        if (pc == null) return;
        final c = payload['candidate'];
        await pc.addCandidate(RTCIceCandidate(c['candidate'], c['sdpMid'], c['sdpMLineIndex']));
      }
    } catch (e) {
      log('signaling payload error from $fromId: $e');
    }
  }

  void _sendSignaling(String targetId, Map<String, dynamic> payload) {
    final inRoom = _connectionManager.isInGroup;
    _send({
      'type': inRoom ? 'room_signaling' : 'signaling',
      if (inRoom) 'roomId': _connectionManager.currentRoom?.id,
      'targetId': targetId,
      'payload': payload,
    });
  }

  // --- Serverless pairing (QR / LAN) — non-trickle SDP, no signaling server --
  //
  // The full offer/answer (with ICE candidates bundled in — non-trickle) is
  // exchanged directly between two phones via a QR code or a LAN socket. The
  // payload carries the signed DTLS-fingerprint chain, verified offline by
  // verifyPeerSignature, so it is MitM-safe without any server.

  static const _kQrKey = '__pairing__';

  /// Build a peer connection for pairing. ICE-candidate collection and the
  /// gathering-complete signal are wired up here — *before* the caller sets the
  /// local description — so we never miss the completion event (host candidates
  /// on a LAN gather almost instantly, and registering the handler afterwards
  /// races that and would force the timeout).
  Future<RTCPeerConnection> _newPairingPeer(String key, {required bool isInitiator}) async {
    final pc = await createPeerConnection(await _getIceConfig());
    _peerConnections[key] = pc;
    _isInitiatorFor[key] = isInitiator;
    _wirePeerCommon(key, pc);

    final gatherDone = Completer<void>();
    final collected = <RTCIceCandidate>[];
    _iceGatherComplete[key] = gatherDone;
    _pairingCandidates[key] = collected;
    pc.onIceCandidate = (candidate) {
      if (candidate.candidate == null || candidate.candidate!.isEmpty) {
        if (!gatherDone.isCompleted) gatherDone.complete();
      } else {
        collected.add(candidate);
      }
    };
    pc.onIceGatheringState = (state) {
      if (state == RTCIceGatheringState.RTCIceGatheringStateComplete && !gatherDone.isCompleted) {
        gatherDone.complete();
      }
    };

    await _ensureLocalStream();
    for (final track in _localStream!.getTracks()) {
      await pc.addTrack(track, _localStream!);
    }
    if (isInitiator) {
      final dc = await pc.createDataChannel('p2ptalk_ctrl', RTCDataChannelInit()..binaryType = 'text');
      _dataChannels[key] = dc;
      _setupDataChannel(key, dc);
    } else {
      pc.onDataChannel = (channel) {
        _dataChannels[key] = channel;
        _setupDataChannel(key, channel);
      };
    }
    return pc;
  }

  /// Wait for ICE gathering to finish (using the completer wired in
  /// [_newPairingPeer]), then return the local description with all gathered
  /// candidates embedded. Non-trickle: the QR payload must be self-contained.
  Future<RTCSessionDescription> _gatheredLocalDescription(String key, RTCPeerConnection pc) async {
    if (pc.iceGatheringState != RTCIceGatheringState.RTCIceGatheringStateComplete) {
      final completer = _iceGatherComplete[key];
      if (completer != null && !completer.isCompleted) {
        // Proceed with whatever candidates we have after 5s (LAN host
        // candidates are usually ready almost immediately).
        await completer.future.timeout(const Duration(seconds: 5), onTimeout: () {});
      }
    }
    final desc = (await pc.getLocalDescription())!;
    var sdp = desc.sdp!;
    if (!sdp.contains('a=candidate:')) {
      sdp = _injectCandidates(sdp, _pairingCandidates[key] ?? const []);
    }
    return RTCSessionDescription(sdp, desc.type);
  }

  /// Inject collected ICE candidates into [sdp] at the end of their respective
  /// media sections (keyed by sdpMLineIndex). Used when the platform doesn't
  /// already fold gathered candidates into getLocalDescription().
  String _injectCandidates(String sdp, List<RTCIceCandidate> candidates) {
    final byIndex = <int, List<String>>{};
    for (final c in candidates) {
      final cand = c.candidate;
      if (cand == null || cand.isEmpty) continue;
      final idx = c.sdpMLineIndex ?? 0;
      byIndex.putIfAbsent(idx, () => []).add(cand.startsWith('a=') ? cand : 'a=$cand');
    }
    if (byIndex.isEmpty) return sdp;
    final lines = sdp.split(RegExp(r'\r?\n'));
    final out = <String>[];
    var mIndex = -1;
    for (final line in lines) {
      if (line.startsWith('m=')) {
        if (mIndex >= 0 && byIndex[mIndex] != null) out.addAll(byIndex[mIndex]!);
        mIndex++;
      }
      out.add(line);
    }
    if (mIndex >= 0 && byIndex[mIndex] != null) {
      var insertAt = out.length;
      while (insertAt > 0 && out[insertAt - 1].trim().isEmpty) {
        insertAt--;
      }
      out.insertAll(insertAt, byIndex[mIndex]!);
    }
    return out.join('\r\n');
  }

  /// Move a peer connection (and its bookkeeping) from a placeholder key to the
  /// real peerId once it's known, re-wiring the connection-state/track handlers
  /// and data channel so they reference the correct id.
  void _rekeyPeer(String fromKey, String toKey) {
    if (fromKey == toKey) return;
    final pc = _peerConnections.remove(fromKey);
    if (pc == null) return;
    _peerConnections[toKey] = pc;
    _wirePeerCommon(toKey, pc);
    final dc = _dataChannels.remove(fromKey);
    if (dc != null) {
      _dataChannels[toKey] = dc;
      _setupDataChannel(toKey, dc);
    }
    final init = _isInitiatorFor.remove(fromKey);
    if (init != null) _isInitiatorFor[toKey] = init;
    final gather = _iceGatherComplete.remove(fromKey);
    if (gather != null) _iceGatherComplete[toKey] = gather;
    final cands = _pairingCandidates.remove(fromKey);
    if (cands != null) _pairingCandidates[toKey] = cands;
  }

  /// Gzip + base64 a signed pairing payload (compact enough for one QR code):
  /// the SDP, the device→identity auth chain, and the signed DTLS fingerprint.
  Future<String> _encodePairing(RTCSessionDescription desc) async {
    final fp = _extractFingerprint(desc.sdp!);
    final chain = _account.authChain;
    final payload = <String, dynamic>{'sdp': desc.sdp, 'type': desc.type};
    if (chain != null) payload['auth'] = chain.toJson();
    if (fp != null) {
      final sig = await _account.signPayload(fp);
      if (sig != null) payload['fpSig'] = sig;
    }
    return base64Encode(gzip.encode(utf8.encode(jsonEncode(payload))));
  }

  Map<String, dynamic> _decodePairing(String encoded) {
    final json = utf8.decode(gzip.decode(base64Decode(encoded.trim())));
    return Map<String, dynamic>.from(jsonDecode(json));
  }

  Future<bool> _verifyPairing(Map<String, dynamic> payload) async {
    if (payload['auth'] == null || payload['fpSig'] == null) return false;
    final chain = AuthChain.fromJson(Map<String, dynamic>.from(payload['auth']));
    final fp = _extractFingerprint(payload['sdp']);
    if (fp == null) return false;
    return _account.verifyPeerSignature(chain, fp, payload['fpSig']);
  }

  /// Step 1 (initiator): create the offer to show as a QR code. The peer's id
  /// isn't known yet, so the connection is parked under [_kQrKey] and re-keyed
  /// to the real peerId in [applyPairingAnswer].
  Future<String> createPairingOffer() async {
    // Tear down any parked connection from a previous, abandoned invite so we
    // don't leak a peer connection (and its mic track) on retry.
    if (_peerConnections.containsKey(_kQrKey)) await _disconnectPeer(_kQrKey);
    _connectionState = P2PConnectionState.connecting;
    notifyListeners();
    final pc = await _newPairingPeer(_kQrKey, isInitiator: true);
    final offer = await pc.createOffer();
    final munged = RTCSessionDescription(_mungeSdp(offer.sdp!), offer.type);
    await pc.setLocalDescription(munged);
    return await _encodePairing(await _gatheredLocalDescription(_kQrKey, pc));
  }

  /// Step 2 (responder): consume the scanned offer, return the answer QR payload.
  /// The offer carries the initiator's signed chain, so we know the peerId up
  /// front and key the connection by it directly.
  Future<String?> acceptPairingOffer(String encodedOffer) async {
    final payload = _decodePairing(encodedOffer);
    if (!await _verifyPairing(payload)) {
      onPeerVerificationFailed?.call('pairing');
      return null;
    }
    final chain = AuthChain.fromJson(Map<String, dynamic>.from(payload['auth']));
    final peerId = chain.accountId;
    _connectionState = P2PConnectionState.connecting;
    _activePartnerId = peerId;
    notifyListeners();
    final pc = await _newPairingPeer(peerId, isInitiator: false);
    _peerChains[peerId] = chain;
    _verifiedPeers.add(peerId);
    await pc.setRemoteDescription(RTCSessionDescription(payload['sdp'], payload['type']));
    final answer = await pc.createAnswer();
    final munged = RTCSessionDescription(_mungeSdp(answer.sdp!), answer.type);
    await pc.setLocalDescription(munged);
    return await _encodePairing(await _gatheredLocalDescription(peerId, pc));
  }

  /// Step 3 (initiator): consume the scanned answer to finish the connection.
  Future<bool> applyPairingAnswer(String encodedAnswer) async {
    final payload = _decodePairing(encodedAnswer);
    if (!await _verifyPairing(payload)) {
      onPeerVerificationFailed?.call('pairing');
      return false;
    }
    final chain = AuthChain.fromJson(Map<String, dynamic>.from(payload['auth']));
    final peerId = chain.accountId;
    final pc = _peerConnections[_kQrKey];
    if (pc == null) return false;
    // Now that we know who answered, re-key the parked connection so the
    // connection manager, ICE-restart logic, and data channel all use the
    // real peerId instead of the placeholder.
    _rekeyPeer(_kQrKey, peerId);
    _peerChains[peerId] = chain;
    _verifiedPeers.add(peerId);
    _activePartnerId = peerId;
    notifyListeners();
    await pc.setRemoteDescription(RTCSessionDescription(payload['sdp'], payload['type']));
    return true;
  }

  /// Apply a remote pairing payload received over a LAN socket (mDNS rung) and,
  /// if it was an offer, return the answer payload to send back.
  Future<String?> handleLanPairing(String encoded, {required bool weInitiated}) async {
    final payload = _decodePairing(encoded);
    if (!await _verifyPairing(payload)) {
      onPeerVerificationFailed?.call('pairing');
      return null;
    }
    if (weInitiated) {
      await applyPairingAnswer(encoded);
      return null;
    }
    return acceptPairingOffer(encoded);
  }

  // --- SDP munging (Opus DTX + low bitrate for data efficiency) -------------

  String _mungeSdp(String sdp) {
    final lines = sdp.split(RegExp(r'\r?\n'));
    // Find the Opus payload type.
    String? opusPt;
    final rtpmap = RegExp(r'^a=rtpmap:(\d+) opus/48000', caseSensitive: false);
    for (final l in lines) {
      final m = rtpmap.firstMatch(l);
      if (m != null) {
        opusPt = m.group(1);
        break;
      }
    }
    if (opusPt == null) return sdp;

    final out = <String>[];
    final fmtpRe = RegExp('^a=fmtp:$opusPt ');
    bool fmtpHandled = false;
    const opusParams = 'minptime=20;useinbandfec=1;usedtx=1;maxaveragebitrate=24000;stereo=0;sprop-stereo=0';
    for (final l in lines) {
      if (fmtpRe.hasMatch(l)) {
        out.add('a=fmtp:$opusPt $opusParams');
        fmtpHandled = true;
      } else {
        out.add(l);
      }
    }
    if (!fmtpHandled) {
      // Insert an fmtp line right after the opus rtpmap.
      final idx = out.indexWhere((l) => rtpmap.hasMatch(l));
      if (idx != -1) out.insert(idx + 1, 'a=fmtp:$opusPt $opusParams');
    }
    return out.join('\r\n');
  }

  String? _extractFingerprint(String sdp) {
    final m = RegExp(r'^a=fingerprint:(\S+ \S+)', multiLine: true).firstMatch(sdp);
    return m?.group(1);
  }

  // --- speech activation (drives ducking only; track stays enabled) ---------

  void _enableLocalAudio(bool enabled) {
    if (_localStream != null) {
      for (final t in _localStream!.getAudioTracks()) {
        t.enabled = enabled;
      }
    }
  }

  /// Called by VAD. Gates the mic track so audio is transmitted ONLY while the
  /// user is actually speaking (words yes; silence/noise no), and signals peers
  /// over the data channel so they duck their music while you speak.
  void setSpeechActive(bool isSpeaking) {
    if (_connectionState != P2PConnectionState.connected) return;
    _enableLocalAudio(isSpeaking);
    final signal = isSpeaking ? 'speech_start' : 'speech_end';
    for (final dc in _dataChannels.values) {
      if (dc.state == RTCDataChannelState.RTCDataChannelOpen) {
        dc.send(RTCDataChannelMessage(signal));
      }
    }
  }

  // --- latency probe (lightweight /health timing) ---------------------------

  void _startLatencyTimer() {
    _latencyTimer?.cancel();
    _probeLatency();
    _latencyTimer = Timer.periodic(const Duration(seconds: 60), (_) {
      if (_isWebSocketConnected && _appForeground) _probeLatency();
    });
  }

  void _stopLatencyTimer() {
    _latencyTimer?.cancel();
    _latencyTimer = null;
  }

  Future<void> _probeLatency() async {
    try {
      final sw = Stopwatch()..start();
      final res = await http.get(Uri.parse('$_httpBase/health')).timeout(const Duration(seconds: 5));
      sw.stop();
      if (res.statusCode == 200) _connectionManager.updateLatency(sw.elapsedMilliseconds);
    } catch (_) {}
  }

  // --- regain P2P after a relay fallback ------------------------------------

  void _startIceMonitor() {
    _iceMonitorTimer ??= Timer.periodic(const Duration(seconds: 20), (_) => _checkRelayAndRegain());
  }

  void _stopIceMonitor() {
    _iceMonitorTimer?.cancel();
    _iceMonitorTimer = null;
    _relayRestartCount.clear();
    _lastRelayRestart.clear();
  }

  Future<void> _checkRelayAndRegain() async {
    if (!_appForeground || _peerConnections.isEmpty) return;
    for (final entry in _peerConnections.entries) {
      final peerId = entry.key;
      final pc = entry.value;
      final relayed = await ConnectionManager.isConnectionRelayed(pc);
      _connectionManager.setPeerRelayed(peerId, relayed);
      if (!relayed) {
        _relayRestartCount[peerId] = 0;
        continue;
      }
      // Only the deterministic offerer drives the ICE restart.
      if (_isInitiatorFor[peerId] != true) continue;

      final attempts = _relayRestartCount[peerId] ?? 0;
      // Backoff: ~20s, 40s, 80s, then every ~3min, capped at 6 attempts.
      final minGapSec = [20, 40, 80, 180, 180, 180][attempts.clamp(0, 5)];
      final last = _lastRelayRestart[peerId];
      if (last != null && DateTime.now().difference(last).inSeconds < minGapSec) continue;
      if (attempts >= 6) continue;

      try {
        log('Relay detected with $peerId — ICE restart attempt ${attempts + 1}');
        final offer = await pc.createOffer({'iceRestart': true});
        final munged = RTCSessionDescription(_mungeSdp(offer.sdp!), offer.type);
        await pc.setLocalDescription(munged);
        await _sendSdp(peerId, munged);
        _relayRestartCount[peerId] = attempts + 1;
        _lastRelayRestart[peerId] = DateTime.now();
      } catch (e) {
        log('ICE restart error for $peerId: $e');
      }
    }
  }

  @override
  void dispose() {
    _reconnectTimer?.cancel();
    _latencyTimer?.cancel();
    _iceMonitorTimer?.cancel();
    super.dispose();
  }
}
