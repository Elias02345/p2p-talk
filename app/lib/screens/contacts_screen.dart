import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../l10n/app_localizations.dart';
import '../services/webrtc_service.dart';
import '../services/ble_service.dart';
import '../services/geofence_service.dart';
import '../services/account_service.dart';
import 'pairing_screen.dart';

class ContactsScreen extends StatefulWidget {
  const ContactsScreen({super.key});

  @override
  State<ContactsScreen> createState() => _ContactsScreenState();
}

class _ContactsScreenState extends State<ContactsScreen> {
  final TextEditingController _addContactController = TextEditingController();
  List<dynamic> _contacts = [];
  List<dynamic> _serverNearby = [];
  bool _isLoading = false;

  static const darkBg = Color(0xFF0F111A);
  static const cardBg = Color(0xFF181C2E);
  static const neonCyan = Color(0xFF00E5FF);
  static const neonCoral = Color(0xFFFF5252);
  static const textGray = Color(0xFF9094A6);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _refreshAll());
  }

  @override
  void dispose() {
    _addContactController.dispose();
    super.dispose();
  }

  Future<void> _refreshAll() async {
    setState(() => _isLoading = true);
    final webRTC = Provider.of<WebRTCService>(context, listen: false);
    final account = Provider.of<AccountService>(context, listen: false);
    final geofence = Provider.of<GeofenceService>(context, listen: false);
    final ble = Provider.of<BleService>(context, listen: false);
    if (!webRTC.isWebSocketConnected) await webRTC.connectWebSocket();

    // Sync location (authenticated) before nearby matching.
    final httpBase = webRTC.serverUrl.replaceFirst('ws://', 'http://').replaceFirst('wss://', 'https://');
    final token = await account.getToken();
    if (account.accountId != null) {
      await geofence.syncLocationWithServer(httpBase, account.accountId!, token);
    }

    final contacts = await account.fetchContacts();
    final nearby = await account.fetchNearby();
    ble.startScanning(advertiseAs: account.username);
    if (mounted) {
      setState(() {
        _contacts = contacts;
        _serverNearby = nearby;
        _isLoading = false;
      });
    }
  }

  Future<void> _addByUsername(String username, AppLocalizations t) async {
    if (username.isEmpty) return;
    final account = Provider.of<AccountService>(context, listen: false);
    final id = await account.lookupUsername(username);
    if (!mounted) return;
    if (id == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t.contactsUserNotFound)));
      return;
    }
    final err = await account.sendContactRequest(id);
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(err == null ? t.contactsRequestSent : t.contactsUserNotFound)));
    _addContactController.clear();
    _refreshAll();
  }

  Future<void> _sendRequestToId(String id, AppLocalizations t) async {
    final account = Provider.of<AccountService>(context, listen: false);
    final err = await account.sendContactRequest(id);
    if (!mounted) return;
    if (err == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t.contactsRequestSent)));
      _refreshAll();
    }
  }

  Future<void> _accept(String id) async {
    final account = Provider.of<AccountService>(context, listen: false);
    if (await account.acceptContactRequest(id)) _refreshAll();
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final webRTC = Provider.of<WebRTCService>(context);
    final ble = Provider.of<BleService>(context);

    return Scaffold(
      backgroundColor: darkBg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(t.contactsTitle, style: const TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            tooltip: t.pairTitle,
            icon: const Icon(Icons.qr_code_2, color: neonCyan),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const PairingScreen()),
            ),
          ),
          IconButton(
            icon: _isLoading
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: neonCyan))
                : const Icon(Icons.refresh, color: neonCyan),
            onPressed: _isLoading ? null : _refreshAll,
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _addContactController,
                      style: const TextStyle(color: Colors.white),
                      onSubmitted: (v) => _addByUsername(v.trim(), t),
                      decoration: InputDecoration(
                        hintText: t.contactsAddByUsername,
                        hintStyle: const TextStyle(color: textGray, fontSize: 14),
                        border: InputBorder.none,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.person_add, color: neonCyan),
                    onPressed: () => _addByUsername(_addContactController.text.trim(), t),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Expanded(
              child: ListView(
                children: [
                  _sectionTitle(t.contactsYourContacts),
                  const SizedBox(height: 12),
                  if (_contacts.isEmpty)
                    _emptyCard(t.contactsNoContacts)
                  else
                    ..._contacts.map((c) => _contactTile(c, webRTC, t)),
                  const SizedBox(height: 24),
                  _sectionTitle(t.contactsNearby),
                  const SizedBox(height: 12),
                  if (_serverNearby.isEmpty)
                    _emptyCard(t.contactsNoNearby)
                  else
                    ..._serverNearby.map((n) => _nearbyTile(n, t)),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _sectionTitle(t.contactsBluetooth),
                      if (ble.isScanning)
                        const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 1.5, color: neonCyan)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (ble.nearbyDevices.isEmpty)
                    _emptyCard(t.contactsNoBluetooth)
                  else
                    ...ble.nearbyDevices.map((d) => _bleTile(d, t)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(String text) =>
      Text(text, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold));

  Widget _emptyCard(String text) => Card(
        color: cardBg,
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Text(text, style: const TextStyle(color: textGray, fontSize: 13), textAlign: TextAlign.center),
        ),
      );

  Widget _contactTile(dynamic c, WebRTCService webRTC, AppLocalizations t) {
    final isAccepted = c['status'] == 'accepted';
    final isOnline = c['isOnline'] == true;
    final isActive = webRTC.activePartnerId == c['id'];
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isActive ? neonCyan.withValues(alpha: 0.4) : Colors.transparent),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(c['username'] ?? '', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Container(width: 6, height: 6, decoration: BoxDecoration(shape: BoxShape.circle, color: isOnline ? Colors.green : textGray)),
                    const SizedBox(width: 6),
                    Text(isOnline ? t.online : t.offline, style: const TextStyle(color: textGray, fontSize: 11)),
                    if (c['gymId'] != null) ...[
                      const SizedBox(width: 8),
                      const Icon(Icons.fitness_center, color: neonCyan, size: 10),
                      const SizedBox(width: 2),
                      Text(t.contactsSameGym, style: const TextStyle(color: neonCyan, fontSize: 11)),
                    ],
                  ],
                ),
              ],
            ),
          ),
          if (isAccepted)
            if (isActive && webRTC.connectionState == P2PConnectionState.connected)
              _btn(t.contactsDisconnect, neonCoral, Colors.white, () => webRTC.disconnectCall())
            else if (isOnline)
              _btn(t.contactsConnect, neonCyan, darkBg, () => webRTC.sendCallRequest(c['id']))
            else
              Text(c['status'] == 'accepted' ? '' : t.contactsStatusPending, style: const TextStyle(color: textGray, fontSize: 12))
          else
            _btn(t.contactsAcceptReq, Colors.amber, darkBg, () => _accept(c['id'])),
        ],
      ),
    );
  }

  Widget _nearbyTile(dynamic n, AppLocalizations t) {
    final hasRelation = n['relation'] != 'none';
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(16)),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(n['username'] ?? '', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(n['reason'] == 'same_gym' ? t.contactsSameGym : (n['reason'] ?? ''),
                    style: const TextStyle(color: neonCyan, fontSize: 11)),
              ],
            ),
          ),
          if (!hasRelation)
            _btn(t.contactsAdd, Colors.white10, Colors.white, () => _sendRequestToId(n['id'], t))
          else
            Text(t.contactsStatusPending, style: const TextStyle(color: textGray, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _bleTile(NearbyDevice d, AppLocalizations t) => Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(16)),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(d.username, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.bluetooth, color: neonCyan, size: 12),
                      const SizedBox(width: 4),
                      Text('${d.rssi} dBm', style: const TextStyle(color: textGray, fontSize: 11)),
                    ],
                  ),
                ],
              ),
            ),
            _btn(t.contactsAdd, Colors.white10, Colors.white, () => _addByUsername(d.username, t)),
          ],
        ),
      );

  Widget _btn(String label, Color bg, Color fg, VoidCallback onPressed) => ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: bg,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        ),
        onPressed: onPressed,
        child: Text(label, style: TextStyle(color: fg, fontSize: 12, fontWeight: FontWeight.bold)),
      );
}
