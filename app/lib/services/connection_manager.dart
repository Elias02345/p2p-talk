import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import '../utils/logger.dart';

/// Connection quality levels for UI display.
enum ConnectionQuality { excellent, good, fair, poor, disconnected }

/// A peer in a group session.
class PeerInfo {
  final String id;
  String username;
  bool isSpeaking;
  bool isConnected;
  bool isRelayed; // true while the media path is going through the TURN relay
  int latencyMs;
  DateTime lastActivity;

  PeerInfo({
    required this.id,
    required this.username,
    this.isSpeaking = false,
    this.isConnected = false,
    this.isRelayed = false,
    this.latencyMs = 0,
    DateTime? lastActivity,
  }) : lastActivity = lastActivity ?? DateTime.now();
}

/// Local room/group session info (realtime membership is WS-authoritative).
class RoomInfo {
  final String id;
  final String name;
  final String createdBy;
  final List<String> memberIds;
  final int maxMembers;

  RoomInfo({
    required this.id,
    required this.name,
    this.createdBy = '',
    this.memberIds = const [],
    this.maxMembers = 10,
  });

  factory RoomInfo.fromJson(Map<String, dynamic> json) => RoomInfo(
        id: json['id'],
        name: json['name'] ?? 'Room',
        createdBy: json['createdBy'] ?? json['created_by'] ?? '',
        memberIds: List<String>.from(json['members'] ?? []),
        maxMembers: json['maxMembers'] ?? json['max_members'] ?? 10,
      );
}

/// Tracks connection quality, reconnection backoff, and multi-peer (group)
/// session coordination. Latency is measured over the existing WebSocket
/// (ping/pong) rather than polling an HTTP endpoint, to avoid waking the radio.
class ConnectionManager extends ChangeNotifier {
  ConnectionQuality _quality = ConnectionQuality.disconnected;
  int _latencyMs = 0;
  int _reconnectAttempts = 0;
  static const int _maxReconnectAttempts = 10;

  RoomInfo? _currentRoom;
  final Map<String, PeerInfo> _peers = {};
  bool _isInGroup = false;

  // Getters
  ConnectionQuality get quality => _quality;
  int get latencyMs => _latencyMs;
  int get reconnectAttempts => _reconnectAttempts;
  RoomInfo? get currentRoom => _currentRoom;
  Map<String, PeerInfo> get peers => Map.unmodifiable(_peers);
  bool get isInGroup => _isInGroup;
  List<PeerInfo> get activePeers => _peers.values.where((p) => p.isConnected).toList();
  int get activePeerCount => activePeers.length;

  /// True if any connected peer's media is currently going through the relay.
  bool get isAnyPeerRelayed => _peers.values.any((p) => p.isConnected && p.isRelayed);

  /// Update connection quality from a measured round-trip latency (ms).
  void updateLatency(int ms) {
    _latencyMs = ms;
    final previous = _quality;
    if (ms <= 0) {
      _quality = ConnectionQuality.disconnected;
    } else if (ms < 50) {
      _quality = ConnectionQuality.excellent;
    } else if (ms < 150) {
      _quality = ConnectionQuality.good;
    } else if (ms < 300) {
      _quality = ConnectionQuality.fair;
    } else {
      _quality = ConnectionQuality.poor;
    }
    if (_quality != previous) notifyListeners();
  }

  void onConnected() {
    _reconnectAttempts = 0;
    _quality = ConnectionQuality.good;
    notifyListeners();
  }

  /// Returns true if a reconnect should be attempted.
  bool onDisconnected() {
    _quality = ConnectionQuality.disconnected;
    notifyListeners();
    if (_reconnectAttempts < _maxReconnectAttempts) {
      _reconnectAttempts++;
      return true;
    }
    return false;
  }

  /// Exponential backoff: 1s, 2s, 4s, ... capped at 30s.
  Duration getReconnectDelay() {
    final seconds = (1 << (_reconnectAttempts - 1)).clamp(1, 30);
    return Duration(seconds: seconds);
  }

  void resetReconnect() {
    _reconnectAttempts = 0;
    notifyListeners();
  }

  // --- group / room state (local; driven by WS) ----------------------------

  void setRoom(RoomInfo room) {
    _currentRoom = room;
    _isInGroup = true;
    notifyListeners();
  }

  void clearRoom() {
    _currentRoom = null;
    _isInGroup = false;
    _peers.clear();
    notifyListeners();
  }

  void addPeer(String id, String username) {
    _peers[id] = PeerInfo(id: id, username: username, isConnected: true);
    notifyListeners();
  }

  void removePeer(String id) {
    _peers.remove(id);
    notifyListeners();
  }

  void setPeerSpeaking(String id, bool isSpeaking) {
    final p = _peers[id];
    if (p != null) {
      p.isSpeaking = isSpeaking;
      p.lastActivity = DateTime.now();
      notifyListeners();
    }
  }

  void setPeerConnected(String id, bool isConnected) {
    final p = _peers[id];
    if (p != null) {
      p.isConnected = isConnected;
      notifyListeners();
    }
  }

  void setPeerRelayed(String id, bool relayed) {
    final p = _peers[id];
    if (p != null && p.isRelayed != relayed) {
      p.isRelayed = relayed;
      notifyListeners();
    }
  }

  /// Inspect a peer connection's stats and report whether the *nominated* ICE
  /// candidate pair is using a relay (TURN) candidate on either end. Used to
  /// decide whether to attempt an ICE restart to regain a direct P2P path.
  static Future<bool> isConnectionRelayed(RTCPeerConnection pc) async {
    try {
      final stats = await pc.getStats();
      // Map candidate id -> candidateType for quick lookup.
      final candidateTypes = <String, String>{};
      Map<dynamic, dynamic>? nominatedPair;
      for (final r in stats) {
        final v = r.values;
        if (r.type == 'local-candidate' || r.type == 'remote-candidate') {
          final t = v['candidateType'];
          if (t != null) candidateTypes[r.id] = t.toString();
        } else if (r.type == 'candidate-pair') {
          final nominated = v['nominated'] == true || v['nominated'] == 'true';
          final state = v['state']?.toString();
          if (nominated && (state == null || state == 'succeeded')) {
            nominatedPair = v;
          }
        }
      }
      if (nominatedPair == null) return false;
      final local = candidateTypes[nominatedPair['localCandidateId']];
      final remote = candidateTypes[nominatedPair['remoteCandidateId']];
      return local == 'relay' || remote == 'relay';
    } catch (e) {
      log('isConnectionRelayed error: $e');
      return false;
    }
  }
}
