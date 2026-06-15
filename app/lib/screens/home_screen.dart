import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../l10n/app_localizations.dart';
import '../services/webrtc_service.dart';
import '../services/vad_service.dart';
import '../services/audio_manager.dart';
import '../services/geofence_service.dart';
import '../services/connection_manager.dart';
import '../services/foreground_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(vsync: this, duration: const Duration(seconds: 2))
      ..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final webRTC = Provider.of<WebRTCService>(context);
    final vad = Provider.of<VadService>(context);
    final audio = Provider.of<AudioManager>(context);
    final geofence = Provider.of<GeofenceService>(context);
    final connMgr = Provider.of<ConnectionManager>(context);

    final isIntercomActive = vad.isListening;
    final isSpeaking = vad.isSpeaking;
    final isConnected = webRTC.connectionState == P2PConnectionState.connected;

    const darkBg = Color(0xFF0F111A);
    const cardBg = Color(0xFF181C2E);
    const neonCyan = Color(0xFF00E5FF);
    const neonCoral = Color(0xFFFF5252);
    const textGray = Color(0xFF9094A6);

    return Scaffold(
      backgroundColor: darkBg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(t.appName,
                          style: const TextStyle(
                              fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 1.2)),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: webRTC.isWebSocketConnected ? Colors.green : Colors.red,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(webRTC.isWebSocketConnected ? t.online : t.offline,
                              style: const TextStyle(fontSize: 12, color: textGray)),
                          if (webRTC.isWebSocketConnected) ...[
                            const SizedBox(width: 8),
                            _qualityBadge(connMgr.quality, connMgr.latencyMs),
                          ],
                        ],
                      ),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      if (geofence.currentGym != null)
                        _pill(neonCyan, Icons.location_on, geofence.currentGym!.name),
                      if (connMgr.isInGroup) ...[
                        const SizedBox(height: 6),
                        _pill(Colors.amber, Icons.group, t.homePeers(connMgr.activePeerCount)),
                      ],
                      if (connMgr.isAnyPeerRelayed) ...[
                        const SizedBox(height: 6),
                        _pill(Colors.orangeAccent, Icons.cell_tower, t.homeRelayed),
                      ],
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 32),
              Expanded(
                child: Center(
                  child: GestureDetector(
                    onTap: () => _toggleSession(context, vad, webRTC, audio, t),
                    child: AnimatedBuilder(
                      animation: _pulseController,
                      builder: (context, child) {
                        double pulse = 1.0;
                        if (isIntercomActive && isSpeaking) {
                          pulse = 1.0 + (_pulseController.value * 0.15);
                        } else if (isIntercomActive && isConnected) {
                          pulse = 1.0 + (_pulseController.value * 0.05);
                        }
                        Color glow = Colors.transparent;
                        Color border = Colors.white24;
                        if (isIntercomActive) {
                          if (isSpeaking) {
                            glow = neonCoral.withValues(alpha: 0.4);
                            border = neonCoral;
                          } else if (isConnected) {
                            glow = neonCyan.withValues(alpha: 0.3);
                            border = neonCyan;
                          } else {
                            glow = Colors.amber.withValues(alpha: 0.2);
                            border = Colors.amber;
                          }
                        }
                        return Container(
                          width: 220,
                          height: 220,
                          transform: Matrix4.identity()..scaleByDouble(pulse, pulse, pulse, 1.0),
                          transformAlignment: Alignment.center,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: cardBg,
                            border: Border.all(color: border, width: 3),
                            boxShadow: [
                              BoxShadow(
                                  color: glow,
                                  blurRadius: isIntercomActive ? 25 : 5,
                                  spreadRadius: isIntercomActive ? 5 : 0),
                            ],
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                isIntercomActive ? (isSpeaking ? Icons.mic : Icons.mic_none) : Icons.mic_off,
                                size: 56,
                                color: isIntercomActive
                                    ? (isSpeaking ? neonCoral : (isConnected ? neonCyan : Colors.amber))
                                    : Colors.white54,
                              ),
                              const SizedBox(height: 12),
                              Text(
                                isIntercomActive
                                    ? (isSpeaking ? t.homeYouSpeak : (isConnected ? t.homeReady : t.homeSearching))
                                    : t.homeIntercomOff,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: isIntercomActive
                                      ? (isSpeaking ? neonCoral : (isConnected ? neonCyan : Colors.amber))
                                      : Colors.white54,
                                  letterSpacing: 1.5,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(isIntercomActive ? t.homeTapToStop : t.homeTapToStart,
                                  style: const TextStyle(fontSize: 11, color: textGray)),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              if (connMgr.peers.isNotEmpty)
                Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: cardBg,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(t.homeConnectedPartners,
                          style: const TextStyle(color: textGray, fontSize: 12, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: connMgr.peers.values.map((peer) {
                          return Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: peer.isSpeaking
                                  ? neonCoral.withValues(alpha: 0.2)
                                  : neonCyan.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: peer.isSpeaking
                                    ? neonCoral.withValues(alpha: 0.5)
                                    : neonCyan.withValues(alpha: 0.2),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(peer.isSpeaking ? Icons.mic : Icons.person,
                                    size: 14, color: peer.isSpeaking ? neonCoral : neonCyan),
                                const SizedBox(width: 6),
                                Text(peer.username,
                                    style: TextStyle(
                                        color: peer.isSpeaking ? neonCoral : Colors.white70,
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold)),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.sports_gymnastics, color: textGray, size: 18),
                        const SizedBox(width: 8),
                        Text(t.homeSessionInfo,
                            style: const TextStyle(color: textGray, fontSize: 14, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _infoRow(
                      t.homeStatus,
                      isConnected
                          ? t.connected
                          : (webRTC.connectionState == P2PConnectionState.connecting ? t.connecting : t.disconnected),
                      isConnected
                          ? neonCyan
                          : (webRTC.connectionState == P2PConnectionState.connecting ? Colors.amber : Colors.white70),
                    ),
                    if (webRTC.activePartnerId != null) ...[
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(t.homePartner, style: const TextStyle(color: textGray, fontSize: 14)),
                          Row(
                            children: [
                              if (webRTC.isPeerVerified(webRTC.activePartnerId!))
                                const Padding(
                                  padding: EdgeInsets.only(right: 6),
                                  child: Icon(Icons.verified_user, color: Colors.green, size: 16),
                                ),
                              Text(webRTC.activePartnerName ?? t.homeDefaultPartner,
                                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                              const SizedBox(width: 8),
                              IconButton(
                                icon: const Icon(Icons.call_end, color: neonCoral, size: 20),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                                onPressed: () async {
                                  await webRTC.disconnectCall();
                                  await P2PForegroundService.stop();
                                },
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 12),
                    _infoRow(t.homeAudioMode, audio.isIntercomMode ? t.homeAudioIntercom : t.homeAudioGym,
                        Colors.white70),
                    const SizedBox(height: 12),
                    _infoRow(t.homeDucking, audio.isDucked ? t.homeDuckingActive : t.homeDuckingReady,
                        audio.isDucked ? neonCoral : Colors.white70),
                    if (connMgr.reconnectAttempts > 0) ...[
                      const SizedBox(height: 12),
                      _infoRow(t.homeReconnect, t.homeReconnectAttempt(connMgr.reconnectAttempts), Colors.amber),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Text(audio.isIntercomMode ? t.homeTipIntercom : t.homeTipGym,
                  style: const TextStyle(color: textGray, fontSize: 11, fontStyle: FontStyle.italic),
                  textAlign: TextAlign.center),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _toggleSession(
      BuildContext context, VadService vad, WebRTCService webRTC, AudioManager audio, AppLocalizations t) async {
    if (vad.isListening) {
      webRTC.setIntercomActive(false);
      await vad.stop();
      await webRTC.disconnectCall();
      await P2PForegroundService.stop();
    } else {
      await audio.init();
      webRTC.setIntercomActive(true);
      await vad.start();
      await P2PForegroundService.start(title: t.appName, text: t.homeReady);
      if (webRTC.activePartnerId != null) {
        webRTC.sendCallRequest(webRTC.activePartnerId!, autoConnect: true);
      }
    }
  }

  Widget _pill(Color color, IconData icon, String text) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          border: Border.all(color: color.withValues(alpha: 0.3)),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 4),
            Text(text, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.bold)),
          ],
        ),
      );

  Widget _infoRow(String label, String value, Color valueColor) => Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Color(0xFF9094A6), fontSize: 14)),
          Flexible(
            child: Text(value,
                style: TextStyle(color: valueColor, fontWeight: FontWeight.bold, fontSize: 14),
                textAlign: TextAlign.right),
          ),
        ],
      );

  Widget _qualityBadge(ConnectionQuality quality, int latencyMs) {
    Color color;
    String text;
    IconData icon;
    switch (quality) {
      case ConnectionQuality.excellent:
        color = Colors.green;
        text = '${latencyMs}ms';
        icon = Icons.signal_cellular_alt;
        break;
      case ConnectionQuality.good:
        color = Colors.lightGreen;
        text = '${latencyMs}ms';
        icon = Icons.signal_cellular_alt;
        break;
      case ConnectionQuality.fair:
        color = Colors.amber;
        text = '${latencyMs}ms';
        icon = Icons.signal_cellular_alt_2_bar;
        break;
      case ConnectionQuality.poor:
        color = Colors.red;
        text = '${latencyMs}ms';
        icon = Icons.signal_cellular_alt_1_bar;
        break;
      case ConnectionQuality.disconnected:
        color = Colors.red;
        text = 'N/A';
        icon = Icons.signal_cellular_off;
        break;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 10, color: color),
          const SizedBox(width: 3),
          Text(text, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
