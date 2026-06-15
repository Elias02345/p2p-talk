import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../l10n/app_localizations.dart';
import '../main.dart';
import '../providers/locale_provider.dart';
import '../services/webrtc_service.dart';
import '../services/audio_manager.dart';
import '../services/connection_manager.dart';
import '../services/notification_service.dart';
import '../services/account_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _serverUrlController = TextEditingController();
  bool _isSaving = false;
  bool _autoConnect = true;
  bool _backgroundMonitoring = true;

  static const darkBg = Color(0xFF0F111A);
  static const cardBg = Color(0xFF181C2E);
  static const neonCyan = Color(0xFF00E5FF);
  static const neonCoral = Color(0xFFFF5252);
  static const textGray = Color(0xFF9094A6);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _serverUrlController.text = Provider.of<WebRTCService>(context, listen: false).serverUrl;
      _loadPreferences();
    });
  }

  @override
  void dispose() {
    _serverUrlController.dispose();
    super.dispose();
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _autoConnect = prefs.getBool('p2ptalk_auto_connect') ?? true;
      _backgroundMonitoring = prefs.getBool('p2ptalk_background_monitoring') ?? true;
    });
  }

  Future<void> _saveSettings() async {
    final t = AppLocalizations.of(context);
    setState(() => _isSaving = true);
    final serverUrl = _serverUrlController.text.trim();
    if (serverUrl.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t.settingsFieldsEmpty)));
      setState(() => _isSaving = false);
      return;
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(kPrefServerUrl, serverUrl);
      await prefs.setBool('p2ptalk_auto_connect', _autoConnect);
      await prefs.setBool('p2ptalk_background_monitoring', _backgroundMonitoring);
      if (!mounted) return;
      Provider.of<WebRTCService>(context, listen: false).updateServerUrl(serverUrl);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t.settingsSaved)));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final webRTC = Provider.of<WebRTCService>(context);
    final audio = Provider.of<AudioManager>(context);
    final connMgr = Provider.of<ConnectionManager>(context);
    final notifications = Provider.of<NotificationService>(context);
    final account = Provider.of<AccountService>(context);

    return Scaffold(
      backgroundColor: darkBg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(t.settingsTitle, style: const TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: Icon(notifications.hasUnread ? Icons.notifications : Icons.notifications_none,
                color: notifications.hasUnread ? neonCyan : textGray),
            onPressed: () => _showNotifications(context, notifications, t),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _card(t.settingsAccount, [
              Text('${t.settingsUsername}: ${account.username ?? t.settingsLoading}',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              Text(t.settingsAccountId, style: const TextStyle(color: textGray, fontSize: 11)),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(color: Colors.black26, borderRadius: BorderRadius.circular(10)),
                      child: Text(account.accountId ?? t.settingsLoading,
                          style: const TextStyle(
                              color: neonCyan, fontSize: 11, fontFamily: 'monospace', fontWeight: FontWeight.bold),
                          overflow: TextOverflow.ellipsis),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.copy, color: neonCyan, size: 20),
                    onPressed: () {
                      if (account.accountId != null) {
                        Clipboard.setData(ClipboardData(text: account.accountId!));
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t.settingsIdCopied)));
                      }
                    },
                  ),
                ],
              ),
            ]),
            const SizedBox(height: 20),

            _card(t.settingsConfiguration, [
              TextField(
                controller: _serverUrlController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: t.settingsServerUrl,
                  labelStyle: const TextStyle(color: textGray),
                  enabledBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                  focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: neonCyan)),
                ),
              ),
            ]),
            const SizedBox(height: 20),

            _card(t.settingsAudioSection, [
              _switchRow(Icons.sports_motorsports, Colors.amber, t.settingsIntercom, t.settingsIntercomSub,
                  audio.isIntercomMode, (val) async {
                audio.setIntercomMode(val);
                final prefs = await SharedPreferences.getInstance();
                await prefs.setBool(kPrefIntercomMode, val);
              }),
              const Divider(color: Colors.white12, height: 24),
              _switchRow(Icons.wifi_tethering, neonCyan, t.settingsAutoConnect, t.settingsAutoConnectSub,
                  _autoConnect, (val) => setState(() => _autoConnect = val)),
              const Divider(color: Colors.white12, height: 24),
              _switchRow(Icons.location_searching, Colors.lightGreen, t.settingsBackgroundLocation,
                  t.settingsBackgroundLocationSub, _backgroundMonitoring,
                  (val) => setState(() => _backgroundMonitoring = val)),
            ]),
            const SizedBox(height: 20),

            _card(t.settingsLanguage, [_languageSelector(t)]),
            const SizedBox(height: 20),

            _card(t.settingsSecurity, [
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.vpn_key, color: neonCyan),
                title: Text(t.settingsRecoveryPhrase, style: const TextStyle(color: Colors.white, fontSize: 14)),
                subtitle: Text(t.settingsRecoveryPhraseSub, style: const TextStyle(color: textGray, fontSize: 11)),
                trailing: TextButton(
                  onPressed: () => _showRecoveryPhrase(account, t),
                  child: Text(t.settingsShowRecoveryPhrase, style: const TextStyle(color: neonCyan, fontSize: 11)),
                ),
              ),
              const Divider(color: Colors.white12, height: 16),
              Text(t.settingsDevices, style: const TextStyle(color: textGray, fontSize: 12, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              _devicesList(account, t),
            ]),
            const SizedBox(height: 20),

            _card(t.settingsConnectionStatus, [
              _statusRow(t.settingsServerConnection, webRTC.isWebSocketConnected ? t.connected : t.disconnected,
                  webRTC.isWebSocketConnected ? Colors.green : neonCoral),
              const SizedBox(height: 8),
              _statusRow(t.settingsLatency, connMgr.latencyMs > 0 ? '${connMgr.latencyMs}ms' : 'N/A',
                  connMgr.latencyMs < 100 ? Colors.green : (connMgr.latencyMs < 300 ? Colors.amber : neonCoral)),
              const SizedBox(height: 8),
              _statusRow(t.settingsConnectedPeers, '${webRTC.connectedPeerCount}', neonCyan),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: neonCyan),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: const Icon(Icons.refresh, color: neonCyan, size: 18),
                  label: Text(t.settingsReconnect, style: const TextStyle(color: neonCyan)),
                  onPressed: () {
                    connMgr.resetReconnect();
                    webRTC.connectWebSocket();
                  },
                ),
              ),
            ]),
            const SizedBox(height: 20),

            _card(t.settingsHelp, [
              _helpBlock(t.settingsHelpSecurityTitle, t.settingsHelpSecurityBody),
              const SizedBox(height: 12),
              _helpBlock(t.settingsHelpMicTitle, t.settingsHelpMicBody),
              const SizedBox(height: 12),
              _helpBlock(t.settingsHelpVadTitle, t.settingsHelpVadBody),
            ]),
            const SizedBox(height: 24),

            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: neonCyan,
                foregroundColor: darkBg,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              onPressed: _isSaving ? null : _saveSettings,
              child: _isSaving
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: darkBg))
                  : Text(t.settingsSave, style: const TextStyle(fontWeight: FontWeight.bold)),
            ),
            const SizedBox(height: 16),
            Center(child: Text(t.settingsVersion('2.0.0'), style: const TextStyle(color: textGray, fontSize: 11))),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _languageSelector(AppLocalizations t) {
    final lp = Provider.of<LocaleProvider>(context);
    final code = lp.locale?.languageCode;
    Widget tile(String label, String? value) {
      final selected = code == value;
      return ListTile(
        contentPadding: EdgeInsets.zero,
        dense: true,
        onTap: () => lp.setLocale(value == null ? null : Locale(value)),
        leading: Icon(selected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
            color: selected ? neonCyan : textGray, size: 20),
        title: Text(label, style: const TextStyle(color: Colors.white, fontSize: 14)),
      );
    }

    return Column(children: [
      tile(t.settingsLanguageSystem, null),
      tile(t.settingsLanguageEnglish, 'en'),
      tile(t.settingsLanguageGerman, 'de'),
    ]);
  }

  Widget _devicesList(AccountService account, AppLocalizations t) {
    return FutureBuilder<List<DeviceInfo>>(
      future: account.listDevices(),
      builder: (context, snap) {
        if (!snap.hasData) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2, color: neonCyan)),
          );
        }
        final devices = snap.data!.where((d) => !d.revoked).toList();
        return Column(
          children: devices.map((d) {
            return ListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              leading: Icon(d.current ? Icons.smartphone : Icons.devices_other,
                  color: d.current ? neonCyan : textGray, size: 20),
              title: Text(d.label ?? d.devicePublicKey.substring(0, 12),
                  style: const TextStyle(color: Colors.white, fontSize: 13)),
              subtitle: d.current ? Text(t.settingsThisDevice, style: const TextStyle(color: textGray, fontSize: 11)) : null,
              trailing: d.current
                  ? null
                  : TextButton(
                      onPressed: () async {
                        await account.revokeDevice(d.devicePublicKey);
                        if (mounted) setState(() {});
                      },
                      child: Text(t.settingsRevoke, style: const TextStyle(color: neonCoral, fontSize: 12)),
                    ),
            );
          }).toList(),
        );
      },
    );
  }

  Future<void> _showRecoveryPhrase(AccountService account, AppLocalizations t) async {
    final phrase = await account.getRecoveryPhrase();
    if (!mounted || phrase == null) return;
    final words = phrase.split(' ');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: cardBg,
        title: Text(t.settingsRecoveryPhrase, style: const TextStyle(color: neonCyan, fontWeight: FontWeight.bold)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(t.onbRecoveryWarning, style: const TextStyle(color: textGray, fontSize: 12)),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: Colors.black26, borderRadius: BorderRadius.circular(12)),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: List.generate(words.length,
                      (i) => Text('${i + 1}. ${words[i]}',
                          style: const TextStyle(color: Colors.white, fontFamily: 'monospace', fontSize: 13))),
                ),
              ),
            ],
          ),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: Text(t.close, style: const TextStyle(color: neonCyan)))],
      ),
    );
  }

  Widget _card(String title, List<Widget> children) => Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 16),
            ...children,
          ],
        ),
      );

  Widget _switchRow(IconData icon, Color iconColor, String title, String subtitle, bool value,
          ValueChanged<bool> onChanged) =>
      Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(color: iconColor.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, color: iconColor, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
                const SizedBox(height: 2),
                Text(subtitle, style: const TextStyle(color: textGray, fontSize: 11)),
              ],
            ),
          ),
          Switch(value: value, activeThumbColor: neonCyan, onChanged: onChanged),
        ],
      );

  Widget _statusRow(String label, String value, Color valueColor) => Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: textGray, fontSize: 13)),
          Text(value, style: TextStyle(color: valueColor, fontWeight: FontWeight.bold, fontSize: 13)),
        ],
      );

  Widget _helpBlock(String title, String body) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(color: neonCyan, fontWeight: FontWeight.bold, fontSize: 13)),
          const SizedBox(height: 6),
          Text(body, style: const TextStyle(color: textGray, fontSize: 12)),
        ],
      );

  String _notifText(AppLocalizations t, P2PNotification n) {
    switch (n.type) {
      case P2PNotificationType.callRequest:
        return t.notifCallRequest(n.name ?? '');
      case P2PNotificationType.contactRequest:
        return t.notifContactRequest;
      case P2PNotificationType.contactAccepted:
        return t.notifContactAccepted;
      case P2PNotificationType.peerJoinedRoom:
        return t.notifPeerJoined(n.name ?? '');
      case P2PNotificationType.peerLeftRoom:
        return t.notifPeerLeft(n.name ?? '');
      case P2PNotificationType.connectionLost:
        return t.notifConnectionLost;
      case P2PNotificationType.reconnected:
        return t.notifReconnected;
      case P2PNotificationType.securityWarning:
        return t.notifSecurityWarning;
    }
  }

  IconData _notifIcon(P2PNotificationType type) {
    switch (type) {
      case P2PNotificationType.callRequest:
        return Icons.call_received;
      case P2PNotificationType.contactRequest:
        return Icons.person_add;
      case P2PNotificationType.contactAccepted:
        return Icons.how_to_reg;
      case P2PNotificationType.peerJoinedRoom:
        return Icons.group_add;
      case P2PNotificationType.peerLeftRoom:
        return Icons.group_remove;
      case P2PNotificationType.connectionLost:
        return Icons.wifi_off;
      case P2PNotificationType.reconnected:
        return Icons.wifi;
      case P2PNotificationType.securityWarning:
        return Icons.gpp_bad;
    }
  }

  void _showNotifications(BuildContext context, NotificationService service, AppLocalizations t) {
    service.markAllAsRead();
    showModalBottomSheet(
      context: context,
      backgroundColor: cardBg,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) {
        final items = service.notifications;
        return Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(t.notifications, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
                  TextButton(
                    onPressed: () {
                      service.clearAll();
                      Navigator.pop(context);
                    },
                    child: Text(t.notificationsClearAll, style: const TextStyle(color: textGray)),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (items.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 32),
                  child: Center(child: Text(t.notificationsEmpty, style: const TextStyle(color: textGray))),
                )
              else
                ConstrainedBox(
                  constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.4),
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: items.length.clamp(0, 15),
                    itemBuilder: (context, index) {
                      final n = items[index];
                      return ListTile(
                        leading: Icon(_notifIcon(n.type), color: neonCyan, size: 20),
                        title: Text(_notifText(t, n), style: const TextStyle(color: Colors.white, fontSize: 14)),
                        dense: true,
                      );
                    },
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
