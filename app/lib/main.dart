import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'l10n/app_localizations.dart';
import 'providers/locale_provider.dart';
import 'services/audio_manager.dart';
import 'services/webrtc_service.dart';
import 'services/vad_service.dart';
import 'services/ble_service.dart';
import 'services/geofence_service.dart';
import 'services/connection_manager.dart';
import 'services/notification_service.dart';
import 'services/account_service.dart';
import 'services/foreground_service.dart';

import 'screens/home_screen.dart';
import 'screens/contacts_screen.dart';
import 'screens/locations_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/onboarding_screen.dart';

const kPrefServerUrl = 'p2ptalk_server_url';
const kPrefIntercomMode = 'p2ptalk_intercom_mode';

/// Optional build-time default so a released APK ships preconfigured and works
/// standalone without the user typing a server URL:
///   flutter build apk --release --dart-define=DEFAULT_SERVER_URL=wss://p2p-talk.example.com
const kDefaultServerUrl = String.fromEnvironment('DEFAULT_SERVER_URL', defaultValue: '');

/// One-time migration of legacy GymTalk preference keys to the new namespace.
Future<void> _migratePrefs(SharedPreferences prefs) async {
  const map = {
    'gymtalk_server_url': kPrefServerUrl,
    'gymtalk_intercom_mode': kPrefIntercomMode,
  };
  for (final entry in map.entries) {
    if (!prefs.containsKey(entry.value) && prefs.containsKey(entry.key)) {
      final v = prefs.get(entry.key);
      if (v is String) await prefs.setString(entry.value, v);
      if (v is bool) await prefs.setBool(entry.value, v);
    }
  }
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final prefs = await SharedPreferences.getInstance();
  await _migratePrefs(prefs);

  var serverUrl = prefs.getString(kPrefServerUrl) ?? '';
  // Fall back to a build-time baked URL so a preconfigured APK works standalone.
  if (serverUrl.isEmpty && kDefaultServerUrl.isNotEmpty) {
    serverUrl = kDefaultServerUrl;
    await prefs.setString(kPrefServerUrl, serverUrl);
  }
  final isIntercomMode = prefs.getBool(kPrefIntercomMode) ?? false;

  final account = AccountService();
  await account.load();
  if (serverUrl.isNotEmpty) account.setApiBaseUrl(serverUrl);

  final localeProvider = LocaleProvider();
  await localeProvider.load();

  runApp(P2PTalkApp(
    account: account,
    localeProvider: localeProvider,
    serverUrl: serverUrl,
    isIntercomMode: isIntercomMode,
  ));
}

class P2PTalkApp extends StatelessWidget {
  final AccountService account;
  final LocaleProvider localeProvider;
  final String serverUrl;
  final bool isIntercomMode;

  const P2PTalkApp({
    super.key,
    required this.account,
    required this.localeProvider,
    required this.serverUrl,
    required this.isIntercomMode,
  });

  @override
  Widget build(BuildContext context) {
    final audioManager = AudioManager();
    final connectionManager = ConnectionManager();
    final notificationService = NotificationService();
    final webRTCService =
        WebRTCService(audioManager, connectionManager, notificationService, account);
    final vadService = VadService();
    final bleService = BleService();
    final geofenceService = GeofenceService();

    audioManager.init();
    if (isIntercomMode) audioManager.setIntercomMode(true);
    if (serverUrl.isNotEmpty) webRTCService.init(serverUrl);
    vadService.init();
    bleService.init();
    geofenceService.init();

    // VAD drives the ducking signal; wired once (not per-call) to avoid races.
    vadService.onSpeechStartCallback = () => webRTCService.setSpeechActive(true);
    vadService.onSpeechEndCallback = () => webRTCService.setSpeechActive(false);

    // Automatic gym actions.
    geofenceService.onEnterGym = (gym) async {
      webRTCService.setIntercomActive(true);
      await vadService.start();
      bleService.startScanning();
      await webRTCService.connectWebSocket();
      final token = await account.getToken();
      if (account.accountId != null) {
        final httpBase = serverUrl
            .replaceFirst('ws://', 'http://')
            .replaceFirst('wss://', 'https://');
        geofenceService.syncLocationWithServer(httpBase, account.accountId!, token);
      }
    };
    geofenceService.onExitGym = (gym) async {
      webRTCService.setIntercomActive(false);
      await vadService.stop();
      bleService.stopScanning();
      await webRTCService.disconnectCall();
      await P2PForegroundService.stop();
    };

    return MultiProvider(
      providers: [
        ChangeNotifierProvider<AccountService>.value(value: account),
        ChangeNotifierProvider<LocaleProvider>.value(value: localeProvider),
        ChangeNotifierProvider<AudioManager>.value(value: audioManager),
        ChangeNotifierProvider<ConnectionManager>.value(value: connectionManager),
        ChangeNotifierProvider<NotificationService>.value(value: notificationService),
        ChangeNotifierProvider<WebRTCService>.value(value: webRTCService),
        ChangeNotifierProvider<VadService>.value(value: vadService),
        ChangeNotifierProvider<BleService>.value(value: bleService),
        ChangeNotifierProvider<GeofenceService>.value(value: geofenceService),
      ],
      child: Consumer<LocaleProvider>(
        builder: (context, locale, _) => MaterialApp(
          title: 'p2p-talk',
          debugShowCheckedModeBanner: false,
          locale: locale.locale,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          theme: _theme(),
          home: account.isRegistered ? const MainNavigationShell() : const OnboardingScreen(),
        ),
      ),
    );
  }

  ThemeData _theme() => ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0F111A),
        fontFamily: 'Roboto',
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF00E5FF),
          secondary: Color(0xFFFF5252),
          surface: Color(0xFF181C2E),
          onPrimary: Color(0xFF0F111A),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF0F111A),
          elevation: 0,
          centerTitle: true,
        ),
        snackBarTheme: SnackBarThemeData(
          backgroundColor: const Color(0xFF1E2340),
          contentTextStyle: const TextStyle(color: Colors.white),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          behavior: SnackBarBehavior.floating,
        ),
      );
}

class MainNavigationShell extends StatefulWidget {
  const MainNavigationShell({super.key});

  @override
  State<MainNavigationShell> createState() => _MainNavigationShellState();
}

class _MainNavigationShellState extends State<MainNavigationShell> with WidgetsBindingObserver {
  int _currentIndex = 0;

  final List<Widget> _screens = const [
    HomeScreen(),
    ContactsScreen(),
    LocationsScreen(),
    SettingsScreen(),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final webRTC = Provider.of<WebRTCService>(context, listen: false);
      webRTC.connectWebSocket();
      // Intercom model: partner connections open automatically (see
      // WebRTCService.setIntercomActive) — no ringing/accept dialog.
      webRTC.onPeerVerificationFailed = (peerId) {
        if (!mounted) return;
        Provider.of<NotificationService>(context, listen: false).notifySecurityWarning(peerId);
      };
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final webRTC = Provider.of<WebRTCService>(context, listen: false);
    webRTC.setForeground(state == AppLifecycleState.resumed);
  }

  @override
  Widget build(BuildContext context) {
    const neonCyan = Color(0xFF00E5FF);
    const cardBg = Color(0xFF181C2E);
    final notifications = Provider.of<NotificationService>(context);
    final t = AppLocalizations.of(context);

    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: _screens),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: Colors.white.withValues(alpha: 0.05), width: 1)),
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (index) => setState(() => _currentIndex = index),
          type: BottomNavigationBarType.fixed,
          backgroundColor: cardBg,
          selectedItemColor: neonCyan,
          unselectedItemColor: const Color(0xFF9094A6),
          selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
          unselectedLabelStyle: const TextStyle(fontSize: 11),
          items: [
            BottomNavigationBarItem(
              icon: const Icon(Icons.mic_none_outlined),
              activeIcon: const Icon(Icons.mic),
              label: t.navIntercom,
            ),
            BottomNavigationBarItem(
              icon: Stack(
                children: [
                  const Icon(Icons.people_outline),
                  if (notifications.hasUnread)
                    const Positioned(
                      right: 0,
                      top: 0,
                      child: CircleAvatar(radius: 4, backgroundColor: Color(0xFFFF5252)),
                    ),
                ],
              ),
              activeIcon: const Icon(Icons.people),
              label: t.navPartners,
            ),
            BottomNavigationBarItem(
              icon: const Icon(Icons.location_on_outlined),
              activeIcon: const Icon(Icons.location_on),
              label: t.navGyms,
            ),
            BottomNavigationBarItem(
              icon: const Icon(Icons.settings_outlined),
              activeIcon: const Icon(Icons.settings),
              label: t.navSetup,
            ),
          ],
        ),
      ),
    );
  }
}
