import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:cryptography/cryptography.dart';
import 'package:bip39/bip39.dart' as bip39;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import '../utils/logger.dart';

/// One enrolled device of an account.
class DeviceInfo {
  final String devicePublicKey;
  final String? label;
  final int? lastSeen;
  final bool revoked;
  final bool current;
  DeviceInfo({
    required this.devicePublicKey,
    this.label,
    this.lastSeen,
    this.revoked = false,
    this.current = false,
  });
  factory DeviceInfo.fromJson(Map<String, dynamic> j) => DeviceInfo(
        devicePublicKey: j['devicePublicKey'],
        label: j['label'],
        lastSeen: j['lastSeen'],
        revoked: j['revoked'] == true,
        current: j['current'] == true,
      );
}

/// The signed authorization chain a peer presents so the other side can verify
/// its identity end-to-end (defeats a malicious signaling server: the chain
/// cannot be forged without the peer's private keys).
class AuthChain {
  final String accountId;
  final String identityPublicKey;
  final String devicePublicKey;
  final String authorizationSig; // identity-key signature over devicePublicKey
  AuthChain({
    required this.accountId,
    required this.identityPublicKey,
    required this.devicePublicKey,
    required this.authorizationSig,
  });
  Map<String, dynamic> toJson() => {
        'accountId': accountId,
        'identityPublicKey': identityPublicKey,
        'devicePublicKey': devicePublicKey,
        'authorizationSig': authorizationSig,
      };
  factory AuthChain.fromJson(Map<String, dynamic> j) => AuthChain(
        accountId: j['accountId'],
        identityPublicKey: j['identityPublicKey'],
        devicePublicKey: j['devicePublicKey'],
        authorizationSig: j['authorizationSig'],
      );
}

/// Manages the account identity (seed-derived Ed25519 key), the per-device
/// subkey, secure storage of private material, and challenge–response auth that
/// yields a short-lived session JWT.
///
/// Private keys never leave the device. The BIP39 recovery phrase is the account
/// (lose it + all devices = lose the account); it is kept in OS-backed secure
/// storage and surfaced in Settings for the user to back up.
class AccountService extends ChangeNotifier {
  // v10 manages encryption itself (Jetpack Security was deprecated upstream).
  static const _storage = FlutterSecureStorage();

  static const _kMnemonic = 'p2ptalk_mnemonic';
  static const _kAccountId = 'p2ptalk_account_id';
  static const _kUsername = 'p2ptalk_username';
  static const _kIdentityPub = 'p2ptalk_identity_pub';
  static const _kDeviceSeed = 'p2ptalk_device_seed';
  static const _kDevicePub = 'p2ptalk_device_pub';
  static const _kAuthSig = 'p2ptalk_auth_sig';
  static const _kPendingSync = 'p2ptalk_pending_sync';

  final _ed = Ed25519();

  String _apiBaseUrl = '';
  String? _accountId;
  String? _username;
  String? _identityPublicKey; // base64
  String? _devicePublicKey; // base64
  String? _authorizationSig; // base64
  List<int>? _deviceSeed; // 32 bytes, in-memory only after load
  // True when the account exists locally but isn't yet registered/enrolled on a
  // server (created offline, or server was unreachable). Synced lazily.
  bool _pendingSync = false;

  String? _token;
  DateTime? _tokenExpiry;

  // Getters
  String? get accountId => _accountId;
  String? get username => _username;
  String? get identityPublicKey => _identityPublicKey;
  String? get devicePublicKey => _devicePublicKey;
  bool get isRegistered => _accountId != null && _devicePublicKey != null;
  bool get isPendingSync => _pendingSync;

  void setApiBaseUrl(String wsOrHttpUrl) {
    _apiBaseUrl = wsOrHttpUrl
        .replaceFirst('ws://', 'http://')
        .replaceFirst('wss://', 'https://')
        .replaceAll(RegExp(r'/+$'), '');
  }

  AuthChain? get authChain {
    if (!isRegistered) return null;
    return AuthChain(
      accountId: _accountId!,
      identityPublicKey: _identityPublicKey!,
      devicePublicKey: _devicePublicKey!,
      authorizationSig: _authorizationSig!,
    );
  }

  /// Load persisted account state from secure storage (call at startup).
  Future<void> load() async {
    try {
      _accountId = await _storage.read(key: _kAccountId);
      _username = await _storage.read(key: _kUsername);
      _identityPublicKey = await _storage.read(key: _kIdentityPub);
      _devicePublicKey = await _storage.read(key: _kDevicePub);
      _authorizationSig = await _storage.read(key: _kAuthSig);
      final seedB64 = await _storage.read(key: _kDeviceSeed);
      if (seedB64 != null) _deviceSeed = base64Decode(seedB64);
      _pendingSync = (await _storage.read(key: _kPendingSync)) == 'true';
    } catch (e) {
      log('AccountService.load error: $e');
    }
    notifyListeners();
  }

  // --- crypto helpers ------------------------------------------------------

  Future<String> _accountIdFromIdentity(List<int> identityPubBytes) async {
    final hash = await Sha256().hash(identityPubBytes);
    // Matches the server: base64url(sha256(identityPublicKey)).slice(0, 32)
    return base64Url.encode(hash.bytes).substring(0, 32);
  }

  Future<String> _sign(List<int> seed, List<int> message) async {
    final kp = await _ed.newKeyPairFromSeed(seed);
    final sig = await _ed.sign(message, keyPair: kp);
    return base64Encode(sig.bytes);
  }

  /// Verify an Ed25519 signature (used to validate a peer's auth chain).
  Future<bool> _verify(String pubKeyB64, List<int> message, String sigB64) async {
    try {
      final pub = SimplePublicKey(base64Decode(pubKeyB64), type: KeyPairType.ed25519);
      return await _ed.verify(
        message,
        signature: Signature(base64Decode(sigB64), publicKey: pub),
      );
    } catch (e) {
      log('verify error: $e');
      return false;
    }
  }

  // --- account lifecycle ---------------------------------------------------

  /// Create a brand-new account. The keypair + accountId are derived and stored
  /// LOCALLY first, so this never blocks on the server — registration/enrollment
  /// happen lazily when a server is reachable. Returns the recovery mnemonic.
  Future<String> createAccount(String username) async {
    final mnemonic = bip39.generateMnemonic(strength: 256); // 24 words
    await _initFromMnemonic(mnemonic, username);
    return mnemonic;
  }

  /// Restore an existing account from its recovery phrase on a new device.
  /// Derives identity locally; enrolls the fresh device subkey lazily.
  Future<String> restoreAccount(String mnemonic) async {
    final clean = mnemonic.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
    if (!bip39.validateMnemonic(clean)) {
      throw Exception('Invalid recovery phrase');
    }
    await _initFromMnemonic(clean, null);
    return _username ?? 'account';
  }

  /// Derive keys locally, persist immediately, then sync to the server in the
  /// background. Account creation works fully offline.
  Future<void> _initFromMnemonic(String mnemonic, String? username) async {
    final seed = bip39.mnemonicToSeed(mnemonic);
    final identitySeed = seed.sublist(0, 32);
    final identityKp = await _ed.newKeyPairFromSeed(identitySeed);
    final identityPub = await identityKp.extractPublicKey();
    final identityPubB64 = base64Encode(identityPub.bytes);
    final accountId = await _accountIdFromIdentity(identityPub.bytes);

    final deviceKp = await _ed.newKeyPair();
    final deviceSeed = await deviceKp.extractPrivateKeyBytes();
    final devicePub = await deviceKp.extractPublicKey();
    final devicePubB64 = base64Encode(devicePub.bytes);
    final authSig = await _sign(identitySeed, devicePub.bytes);

    // Persist locally FIRST — the account now exists on this device.
    _accountId = accountId;
    _username = username ?? 'p2p-${accountId.substring(0, 6)}';
    _identityPublicKey = identityPubB64;
    _devicePublicKey = devicePubB64;
    _authorizationSig = authSig;
    _deviceSeed = deviceSeed;
    _pendingSync = true;
    _token = null;
    _tokenExpiry = null;

    await _storage.write(key: _kMnemonic, value: mnemonic);
    await _storage.write(key: _kAccountId, value: accountId);
    await _storage.write(key: _kUsername, value: _username);
    await _storage.write(key: _kIdentityPub, value: identityPubB64);
    await _storage.write(key: _kDeviceSeed, value: base64Encode(deviceSeed));
    await _storage.write(key: _kDevicePub, value: devicePubB64);
    await _storage.write(key: _kAuthSig, value: authSig);
    await _storage.write(key: _kPendingSync, value: 'true');

    notifyListeners();
    log('Account created locally: $_username ($accountId) — pending server sync');

    // Try to sync now (non-blocking; safe to fail offline).
    await _syncRegistration();
  }

  /// Register the account + enroll this device on the server. No-op if already
  /// synced or the server is unreachable (stays pending, retried later).
  Future<bool> _syncRegistration() async {
    if (!_pendingSync || _accountId == null) return !_pendingSync;
    try {
      final reg = await _post('/api/account/register', {
        'username': _username,
        'identityPublicKey': _identityPublicKey,
      });
      if (reg == null) return false; // server unreachable — stay pending
      if (reg.statusCode == 200) {
        final serverName = jsonDecode(reg.body)['username'] as String?;
        if (serverName != null && serverName != _username) {
          _username = serverName; // server is source of truth (e.g. on restore)
          await _storage.write(key: _kUsername, value: _username);
        }
      } else if (reg.statusCode != 409) {
        return false; // transient server error — retry later
      }
      // (409 = username taken by a different identity; keep local account, the
      //  user can change the name later. Enrollment below still proceeds.)

      final enroll = await _post('/api/account/device', {
        'accountId': _accountId,
        'devicePublicKey': _devicePublicKey,
        'authorizationSig': _authorizationSig,
        'deviceLabel': defaultTargetPlatform.name,
      });
      if (enroll == null || enroll.statusCode != 200) return false;

      _pendingSync = false;
      await _storage.write(key: _kPendingSync, value: 'false');
      notifyListeners();
      log('Account synced to server ($_accountId)');
      return true;
    } catch (e) {
      log('account sync error: $e');
      return false;
    }
  }

  /// The stored recovery phrase, for re-display/backup in Settings.
  Future<String?> getRecoveryPhrase() => _storage.read(key: _kMnemonic);

  // --- session token (challenge–response) ----------------------------------

  /// Return a valid session JWT, authenticating if needed. Null on failure
  /// (e.g. offline / not yet synced — the app then uses local signaling rungs).
  Future<String?> getToken() async {
    if (_token != null && _tokenExpiry != null && DateTime.now().isBefore(_tokenExpiry!)) {
      return _token;
    }
    // A device must be enrolled server-side before it can authenticate.
    if (_pendingSync) {
      final synced = await _syncRegistration();
      if (!synced) return null;
    }
    return _authenticate();
  }

  Future<String?> _authenticate() async {
    if (!isRegistered || _deviceSeed == null) return null;
    try {
      final ch = await _post('/api/auth/challenge', {
        'accountId': _accountId,
        'devicePublicKey': _devicePublicKey,
      });
      if (ch == null || ch.statusCode != 200) return null;
      final nonce = jsonDecode(ch.body)['nonce'] as String;
      final signature = await _sign(_deviceSeed!, utf8.encode(nonce));
      final ver = await _post('/api/auth/verify', {
        'accountId': _accountId,
        'devicePublicKey': _devicePublicKey,
        'signature': signature,
      });
      if (ver == null || ver.statusCode != 200) return null;
      final body = jsonDecode(ver.body);
      _token = body['token'] as String;
      final ttl = (body['expiresIn'] as int?) ?? 86400;
      // Refresh a minute early to avoid edge expiry.
      _tokenExpiry = DateTime.now().add(Duration(seconds: ttl - 60));
      return _token;
    } catch (e) {
      log('authenticate error: $e');
      return null;
    }
  }

  // --- peer verification (anti-MitM) ---------------------------------------

  /// Sign a peer-facing payload (e.g. the local DTLS fingerprint) with the
  /// device key so the remote peer can verify it via [verifyPeerSignature].
  Future<String?> signPayload(String payload) async {
    if (_deviceSeed == null) return null;
    return _sign(_deviceSeed!, utf8.encode(payload));
  }

  /// Verify a peer's signed payload against its presented auth chain:
  /// 1) the account id matches sha256(identity key),
  /// 2) the identity key authorized the device key,
  /// 3) the device key signed the payload.
  Future<bool> verifyPeerSignature(AuthChain chain, String payload, String signature) async {
    try {
      final expectedId = await _accountIdFromIdentity(base64Decode(chain.identityPublicKey));
      if (expectedId != chain.accountId) return false;
      final deviceAuthorized = await _verify(
        chain.identityPublicKey,
        base64Decode(chain.devicePublicKey),
        chain.authorizationSig,
      );
      if (!deviceAuthorized) return false;
      return _verify(chain.devicePublicKey, utf8.encode(payload), signature);
    } catch (e) {
      log('verifyPeerSignature error: $e');
      return false;
    }
  }

  /// A short, human-comparable safety number derived from both identity keys,
  /// for optional verbal verification on a call.
  Future<String> safetyNumber(String peerIdentityPublicKey) async {
    final mine = base64Decode(_identityPublicKey ?? '');
    final theirs = base64Decode(peerIdentityPublicKey);
    // Order-independent so both sides compute the same code.
    final ordered = _identityPublicKey!.compareTo(peerIdentityPublicKey) < 0
        ? [...mine, ...theirs]
        : [...theirs, ...mine];
    final hash = await Sha256().hash(ordered);
    final n = hash.bytes.take(5).fold<int>(0, (a, b) => (a * 256 + b) % 100000);
    return n.toString().padLeft(5, '0');
  }

  // --- device management ----------------------------------------------------

  Future<List<DeviceInfo>> listDevices() async {
    final res = await _get('/api/account/devices');
    if (res == null || res.statusCode != 200) return [];
    final List data = jsonDecode(res.body);
    return data.map((d) => DeviceInfo.fromJson(d)).toList();
  }

  Future<bool> revokeDevice(String devicePublicKey) async {
    final res = await _post('/api/account/device/revoke', {'devicePublicKey': devicePublicKey});
    return res != null && res.statusCode == 200;
  }

  /// Fetch ephemeral ICE servers (STUN + short-lived TURN credentials).
  Future<Map<String, dynamic>?> fetchIce() async {
    final res = await _get('/api/ice');
    if (res == null || res.statusCode != 200) return null;
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  // --- contacts (authenticated) --------------------------------------------

  Future<List<dynamic>> fetchContacts() async {
    if (_accountId == null) return [];
    final res = await _get('/api/users/$_accountId/contacts');
    if (res == null || res.statusCode != 200) return [];
    return jsonDecode(res.body) as List<dynamic>;
  }

  Future<List<dynamic>> fetchNearby() async {
    if (_accountId == null) return [];
    final res = await _get('/api/users/$_accountId/nearby');
    if (res == null || res.statusCode != 200) return [];
    return jsonDecode(res.body) as List<dynamic>;
  }

  /// Resolve a username to an account id. Returns null if not found.
  Future<String?> lookupUsername(String username) async {
    final res = await _get('/api/users/lookup?username=${Uri.encodeQueryComponent(username)}');
    if (res == null || res.statusCode != 200) return null;
    return jsonDecode(res.body)['id'] as String?;
  }

  /// Send a contact request to an account id. Returns an error string or null on success.
  Future<String?> sendContactRequest(String contactId) async {
    if (_accountId == null) return 'no_account';
    final res = await _post('/api/users/$_accountId/contacts', {'contact_id': contactId}, auth: true);
    if (res == null) return 'network';
    if (res.statusCode == 200) return null;
    try {
      return jsonDecode(res.body)['error'] as String?;
    } catch (_) {
      return 'error';
    }
  }

  Future<bool> acceptContactRequest(String contactId) async {
    if (_accountId == null) return false;
    final res = await _post('/api/users/$_accountId/contacts/accept', {'contact_id': contactId}, auth: true);
    return res != null && res.statusCode == 200;
  }

  // --- settings sync --------------------------------------------------------

  Future<Map<String, dynamic>> fetchSettings() async {
    final res = await _get('/api/account/settings');
    if (res == null || res.statusCode != 200) return {};
    return (jsonDecode(res.body)['settings'] as Map?)?.cast<String, dynamic>() ?? {};
  }

  Future<void> pushSettings(Map<String, dynamic> settings) async {
    await _put('/api/account/settings', {'settings': settings});
  }

  // --- HTTP plumbing --------------------------------------------------------

  Future<http.Response?> _post(String path, Map<String, dynamic> body, {bool auth = false}) =>
      _request('POST', path, body: body, auth: auth);
  Future<http.Response?> _get(String path) => _request('GET', path, auth: true);
  Future<http.Response?> _put(String path, Map<String, dynamic> body) =>
      _request('PUT', path, body: body, auth: true);

  Future<http.Response?> _request(String method, String path,
      {Map<String, dynamic>? body, bool auth = false}) async {
    if (_apiBaseUrl.isEmpty) return null;
    final uri = Uri.parse('$_apiBaseUrl$path');
    final headers = {'Content-Type': 'application/json'};
    // Auth endpoints in createAccount/restore are unauthenticated by design.
    if (auth) {
      final t = await getToken();
      if (t != null) headers['Authorization'] = 'Bearer $t';
    }
    try {
      final req = body != null ? jsonEncode(body) : null;
      switch (method) {
        case 'POST':
          return await http
              .post(uri, headers: headers, body: req)
              .timeout(const Duration(seconds: 10));
        case 'PUT':
          return await http
              .put(uri, headers: headers, body: req)
              .timeout(const Duration(seconds: 10));
        default:
          return await http.get(uri, headers: headers).timeout(const Duration(seconds: 10));
      }
    } catch (e) {
      log('$method $path error: $e');
      return null;
    }
  }
}
