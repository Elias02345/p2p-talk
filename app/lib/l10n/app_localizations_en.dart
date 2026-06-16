// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appName => 'p2p-talk';

  @override
  String get online => 'Online';

  @override
  String get offline => 'Offline';

  @override
  String get connected => 'Connected';

  @override
  String get disconnected => 'Not connected';

  @override
  String get connecting => 'Connecting…';

  @override
  String get save => 'Save';

  @override
  String get cancel => 'Cancel';

  @override
  String get close => 'Close';

  @override
  String get delete => 'Delete';

  @override
  String get copy => 'Copy';

  @override
  String get retry => 'Retry';

  @override
  String get navIntercom => 'Intercom';

  @override
  String get navPartners => 'Partners';

  @override
  String get navGyms => 'Gyms';

  @override
  String get navSetup => 'Setup';

  @override
  String get homeReady => 'READY';

  @override
  String get homeYouSpeak => 'YOU\'RE SPEAKING';

  @override
  String get homeSearching => 'FINDING PARTNER';

  @override
  String get homeIntercomOff => 'INTERCOM OFF';

  @override
  String get homeTapToStart => 'Tap to start';

  @override
  String get homeTapToStop => 'Tap to stop';

  @override
  String get homeConnectedPartners => 'Connected partners';

  @override
  String homePeers(int count) {
    return '$count peers';
  }

  @override
  String get homeSessionInfo => 'Session info';

  @override
  String get homeStatus => 'Status:';

  @override
  String get homePartner => 'Partner:';

  @override
  String get homeAudioMode => 'Audio mode:';

  @override
  String get homeAudioIntercom => 'Intercom (helmet mic)';

  @override
  String get homeAudioGym => 'Gym mode (music focus)';

  @override
  String get homeDucking => 'Audio ducking:';

  @override
  String get homeDuckingActive => 'Active (music quiet)';

  @override
  String get homeDuckingReady => 'Ready (music normal)';

  @override
  String get homeReconnect => 'Reconnect:';

  @override
  String homeReconnectAttempt(int n) {
    return 'Attempt $n/10';
  }

  @override
  String get homeRelayed => 'Via relay (re-establishing direct…)';

  @override
  String get homeSecured => 'Secured';

  @override
  String get homeUnverified => 'Unverified';

  @override
  String get homeTipIntercom =>
      'Tip: In intercom mode your voice is captured through your helmet/headset microphone. The phone can stay in your pocket.';

  @override
  String get homeTipGym =>
      'Tip: Keep the phone near you (e.g. chest pocket or on a rack) so the built-in microphone captures your voice clearly.';

  @override
  String get homeDefaultPartner => 'Partner';

  @override
  String get settingsTitle => 'Settings';

  @override
  String get settingsAccount => 'Your account';

  @override
  String get settingsUsername => 'Username';

  @override
  String get settingsAccountId => 'Your p2p-talk ID (share with your partner):';

  @override
  String get settingsIdCopied => 'ID copied to clipboard';

  @override
  String get settingsLoading => 'Loading…';

  @override
  String get settingsConfiguration => 'Configuration';

  @override
  String get settingsServerUrl => 'Signaling server URL';

  @override
  String get settingsVadTitle => 'Microphone sensitivity';

  @override
  String get settingsVadStrict => 'Strict — voice only (recommended)';

  @override
  String get settingsVadBalanced => 'Balanced';

  @override
  String get settingsVadSensitive => 'Sensitive — picks up more';

  @override
  String get settingsAudioSection => 'Audio mode';

  @override
  String get settingsIntercom => 'Intercom mode (helmet / motorcycle)';

  @override
  String get settingsIntercomSub =>
      'Uses the Bluetooth helmet microphone instead of the phone microphone';

  @override
  String get settingsAutoConnect => 'Auto-connect at the gym';

  @override
  String get settingsAutoConnectSub =>
      'Automatically connect with known partners inside a geofence';

  @override
  String get settingsBackgroundLocation => 'Background location';

  @override
  String get settingsBackgroundLocationSub =>
      'Detect gym geofences in the background';

  @override
  String get settingsConnectionStatus => 'Connection status';

  @override
  String get settingsServerConnection => 'Server connection';

  @override
  String get settingsLatency => 'Latency';

  @override
  String get settingsConnectedPeers => 'Connected peers';

  @override
  String get settingsReconnect => 'Reconnect';

  @override
  String get settingsSecurity => 'Account & security';

  @override
  String get settingsRecoveryPhrase => 'Recovery phrase';

  @override
  String get settingsRecoveryPhraseSub =>
      'Back this up — it is the only way to recover your account';

  @override
  String get settingsShowRecoveryPhrase => 'Show recovery phrase';

  @override
  String get settingsDevices => 'Your devices';

  @override
  String get settingsRevoke => 'Revoke';

  @override
  String get settingsThisDevice => 'This device';

  @override
  String get settingsLanguage => 'Language';

  @override
  String get settingsLanguageSystem => 'System default';

  @override
  String get settingsLanguageEnglish => 'English';

  @override
  String get settingsLanguageGerman => 'Deutsch';

  @override
  String get settingsHelp => 'Help & troubleshooting';

  @override
  String get settingsHelpMicTitle => 'Why record through the phone microphone?';

  @override
  String get settingsHelpMicBody =>
      'When an app opens a Bluetooth headset microphone and speaker at the same time, the phone switches to HFP (Hands-Free Profile). That ruins your music quality (mono 8/16 kHz). p2p-talk avoids this by capturing your voice through the built-in phone microphone and playing music plus your partner\'s voice in full stereo (A2DP) through your headphones.';

  @override
  String get settingsHelpVadTitle => 'Voice Activity Detection (VAD)';

  @override
  String get settingsHelpVadBody =>
      'p2p-talk uses Silero VAD (a neural network on the ONNX runtime) to precisely filter speech. Breathing, clattering weights and background noise are suppressed so only actual speech is transmitted.';

  @override
  String get settingsHelpSecurityTitle => 'End-to-end security';

  @override
  String get settingsHelpSecurityBody =>
      'Calls are encrypted end-to-end (DTLS-SRTP). Even when a call falls back through the relay server, the server only forwards encrypted packets and cannot listen in. Your account is a private key that never leaves this device.';

  @override
  String get settingsSave => 'Save settings';

  @override
  String get settingsSaved => 'Settings saved';

  @override
  String get settingsFieldsEmpty => 'Username and server URL must not be empty';

  @override
  String settingsVersion(String version) {
    return 'p2p-talk v$version';
  }

  @override
  String get notifications => 'Notifications';

  @override
  String get notificationsClearAll => 'Clear all';

  @override
  String get notificationsEmpty => 'No notifications';

  @override
  String notifCallRequest(String name) {
    return '$name wants to connect';
  }

  @override
  String get notifContactRequest => 'New contact request';

  @override
  String get notifContactAccepted => 'Contact request accepted';

  @override
  String notifPeerJoined(String name) {
    return '$name joined the group';
  }

  @override
  String notifPeerLeft(String name) {
    return '$name left the group';
  }

  @override
  String get notifConnectionLost => 'Connection lost — reconnecting…';

  @override
  String get notifReconnected => 'Connection restored';

  @override
  String get notifSecurityWarning =>
      'Security warning: could not verify a peer';

  @override
  String get incomingCallTitle => 'Connection request';

  @override
  String incomingCallBody(String name) {
    return '$name wants to connect over p2p-talk to pair your headphone audio.';
  }

  @override
  String get accept => 'Accept';

  @override
  String get decline => 'Decline';

  @override
  String get onbWelcomeTitle => 'Welcome to p2p-talk';

  @override
  String get onbWelcomeSub =>
      'Secure, hands-free voice for the gym and the road.';

  @override
  String get onbHowTitle => 'How it works';

  @override
  String get onbFeatureVad => 'Voice activation — talk hands-free, no buttons.';

  @override
  String get onbFeatureDucking =>
      'Your music ducks automatically when someone speaks.';

  @override
  String get onbFeatureNoHfp => 'Full music quality — no HFP downgrade.';

  @override
  String get onbFeatureP2p =>
      'Encrypted peer-to-peer, with seamless server fallback.';

  @override
  String get onbModesTitle => 'Two modes';

  @override
  String get onbGymModeTitle => 'Gym mode';

  @override
  String get onbGymModeSub =>
      'Phone mic captures your voice; music stays in stereo on your headphones.';

  @override
  String get onbIntercomModeTitle => 'Intercom mode';

  @override
  String get onbIntercomModeSub =>
      'Full helmet/headset voice routing for the motorcycle.';

  @override
  String get onbAccountTitle => 'Create your account';

  @override
  String get onbAccountSub =>
      'Your account is a private key on this device — no email, no password.';

  @override
  String get onbCreateAccount => 'Create account';

  @override
  String get onbRestoreAccount => 'Restore from recovery phrase';

  @override
  String get onbSkip => 'Use without an account';

  @override
  String get onbLocalModeNote =>
      'Without an account you can explore the app; connecting with partners needs a server.';

  @override
  String get settingsNoAccount => 'No account yet';

  @override
  String get settingsCreateAccount => 'Set up account';

  @override
  String get onbUsername => 'Username';

  @override
  String get onbServerUrl =>
      'Server URL (e.g. https://p2p-talk.example.com or http://192.168.1.129:3000)';

  @override
  String get onbRecoveryTitle => 'Your recovery phrase';

  @override
  String get onbRecoveryWarning =>
      'Write these 24 words down and keep them safe. They are the ONLY way to recover your account or add another device. Never share them.';

  @override
  String get onbRecoverySaved => 'I\'ve written it down';

  @override
  String get onbEnterRecovery => 'Enter your 24-word recovery phrase';

  @override
  String get onbRestoreHint => 'Separate words with spaces';

  @override
  String get onbNext => 'Next';

  @override
  String get onbBack => 'Back';

  @override
  String get onbGetStarted => 'Get started';

  @override
  String get onbUsernameTaken => 'That username is already taken';

  @override
  String get onbUsernameEmpty => 'Please enter a username';

  @override
  String get onbInvalidPhrase => 'Invalid recovery phrase';

  @override
  String get onbServerRequired => 'Please enter the server URL';

  @override
  String get onbAccountFailed =>
      'Could not create the account. Check the server URL and try again.';

  @override
  String get onbRestoreFailed =>
      'Could not restore the account. Check the phrase and server URL.';

  @override
  String get contactsTitle => 'Partners';

  @override
  String get contactsAddByUsername => 'Add partner by username';

  @override
  String get contactsAdd => 'Add';

  @override
  String get contactsYourContacts => 'Your contacts';

  @override
  String get contactsNearby => 'Nearby';

  @override
  String get contactsBluetooth => 'Bluetooth direct scan';

  @override
  String get contactsScan => 'Scan';

  @override
  String get contactsScanning => 'Scanning…';

  @override
  String get contactsConnect => 'Connect';

  @override
  String get contactsAcceptReq => 'Accept';

  @override
  String get contactsDisconnect => 'Disconnect';

  @override
  String get contactsNoContacts =>
      'No contacts yet. Add a partner by username.';

  @override
  String get contactsNoNearby => 'No one nearby right now.';

  @override
  String get contactsNoBluetooth => 'No p2p-talk devices found nearby.';

  @override
  String get contactsRequestSent => 'Contact request sent';

  @override
  String get contactsUserNotFound => 'User not found';

  @override
  String get contactsSameGym => 'Same gym';

  @override
  String get contactsStatusPending => 'Pending';

  @override
  String get locationsTitle => 'Locations (geofences)';

  @override
  String get locationsBackgroundMonitoring => 'Background monitoring';

  @override
  String get locationsCurrentPosition => 'Current position';

  @override
  String get locationsNoPosition => 'No position yet';

  @override
  String get locationsAddCurrent => 'Add current location as a gym';

  @override
  String get locationsGymName => 'Gym name';

  @override
  String get locationsRadius => 'Radius (m)';

  @override
  String get locationsAdd => 'Add';

  @override
  String get locationsHere => 'HERE';

  @override
  String get locationsNoGyms => 'No gyms saved yet.';

  @override
  String locationsRadiusLabel(String radius) {
    return 'Radius: $radius m';
  }

  @override
  String get locationsPermissionDenied => 'Location permission denied';
}
