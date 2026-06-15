import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_de.dart';
import 'app_localizations_en.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('de'),
    Locale('en'),
  ];

  /// No description provided for @appName.
  ///
  /// In en, this message translates to:
  /// **'p2p-talk'**
  String get appName;

  /// No description provided for @online.
  ///
  /// In en, this message translates to:
  /// **'Online'**
  String get online;

  /// No description provided for @offline.
  ///
  /// In en, this message translates to:
  /// **'Offline'**
  String get offline;

  /// No description provided for @connected.
  ///
  /// In en, this message translates to:
  /// **'Connected'**
  String get connected;

  /// No description provided for @disconnected.
  ///
  /// In en, this message translates to:
  /// **'Not connected'**
  String get disconnected;

  /// No description provided for @connecting.
  ///
  /// In en, this message translates to:
  /// **'Connecting…'**
  String get connecting;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @close.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get close;

  /// No description provided for @delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// No description provided for @copy.
  ///
  /// In en, this message translates to:
  /// **'Copy'**
  String get copy;

  /// No description provided for @retry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retry;

  /// No description provided for @navIntercom.
  ///
  /// In en, this message translates to:
  /// **'Intercom'**
  String get navIntercom;

  /// No description provided for @navPartners.
  ///
  /// In en, this message translates to:
  /// **'Partners'**
  String get navPartners;

  /// No description provided for @navGyms.
  ///
  /// In en, this message translates to:
  /// **'Gyms'**
  String get navGyms;

  /// No description provided for @navSetup.
  ///
  /// In en, this message translates to:
  /// **'Setup'**
  String get navSetup;

  /// No description provided for @homeReady.
  ///
  /// In en, this message translates to:
  /// **'READY'**
  String get homeReady;

  /// No description provided for @homeYouSpeak.
  ///
  /// In en, this message translates to:
  /// **'YOU\'RE SPEAKING'**
  String get homeYouSpeak;

  /// No description provided for @homeSearching.
  ///
  /// In en, this message translates to:
  /// **'FINDING PARTNER'**
  String get homeSearching;

  /// No description provided for @homeIntercomOff.
  ///
  /// In en, this message translates to:
  /// **'INTERCOM OFF'**
  String get homeIntercomOff;

  /// No description provided for @homeTapToStart.
  ///
  /// In en, this message translates to:
  /// **'Tap to start'**
  String get homeTapToStart;

  /// No description provided for @homeTapToStop.
  ///
  /// In en, this message translates to:
  /// **'Tap to stop'**
  String get homeTapToStop;

  /// No description provided for @homeConnectedPartners.
  ///
  /// In en, this message translates to:
  /// **'Connected partners'**
  String get homeConnectedPartners;

  /// No description provided for @homePeers.
  ///
  /// In en, this message translates to:
  /// **'{count} peers'**
  String homePeers(int count);

  /// No description provided for @homeSessionInfo.
  ///
  /// In en, this message translates to:
  /// **'Session info'**
  String get homeSessionInfo;

  /// No description provided for @homeStatus.
  ///
  /// In en, this message translates to:
  /// **'Status:'**
  String get homeStatus;

  /// No description provided for @homePartner.
  ///
  /// In en, this message translates to:
  /// **'Partner:'**
  String get homePartner;

  /// No description provided for @homeAudioMode.
  ///
  /// In en, this message translates to:
  /// **'Audio mode:'**
  String get homeAudioMode;

  /// No description provided for @homeAudioIntercom.
  ///
  /// In en, this message translates to:
  /// **'Intercom (helmet mic)'**
  String get homeAudioIntercom;

  /// No description provided for @homeAudioGym.
  ///
  /// In en, this message translates to:
  /// **'Gym mode (music focus)'**
  String get homeAudioGym;

  /// No description provided for @homeDucking.
  ///
  /// In en, this message translates to:
  /// **'Audio ducking:'**
  String get homeDucking;

  /// No description provided for @homeDuckingActive.
  ///
  /// In en, this message translates to:
  /// **'Active (music quiet)'**
  String get homeDuckingActive;

  /// No description provided for @homeDuckingReady.
  ///
  /// In en, this message translates to:
  /// **'Ready (music normal)'**
  String get homeDuckingReady;

  /// No description provided for @homeReconnect.
  ///
  /// In en, this message translates to:
  /// **'Reconnect:'**
  String get homeReconnect;

  /// No description provided for @homeReconnectAttempt.
  ///
  /// In en, this message translates to:
  /// **'Attempt {n}/10'**
  String homeReconnectAttempt(int n);

  /// No description provided for @homeRelayed.
  ///
  /// In en, this message translates to:
  /// **'Via relay (re-establishing direct…)'**
  String get homeRelayed;

  /// No description provided for @homeSecured.
  ///
  /// In en, this message translates to:
  /// **'Secured'**
  String get homeSecured;

  /// No description provided for @homeUnverified.
  ///
  /// In en, this message translates to:
  /// **'Unverified'**
  String get homeUnverified;

  /// No description provided for @homeTipIntercom.
  ///
  /// In en, this message translates to:
  /// **'Tip: In intercom mode your voice is captured through your helmet/headset microphone. The phone can stay in your pocket.'**
  String get homeTipIntercom;

  /// No description provided for @homeTipGym.
  ///
  /// In en, this message translates to:
  /// **'Tip: Keep the phone near you (e.g. chest pocket or on a rack) so the built-in microphone captures your voice clearly.'**
  String get homeTipGym;

  /// No description provided for @homeDefaultPartner.
  ///
  /// In en, this message translates to:
  /// **'Partner'**
  String get homeDefaultPartner;

  /// No description provided for @settingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsTitle;

  /// No description provided for @settingsAccount.
  ///
  /// In en, this message translates to:
  /// **'Your account'**
  String get settingsAccount;

  /// No description provided for @settingsUsername.
  ///
  /// In en, this message translates to:
  /// **'Username'**
  String get settingsUsername;

  /// No description provided for @settingsAccountId.
  ///
  /// In en, this message translates to:
  /// **'Your p2p-talk ID (share with your partner):'**
  String get settingsAccountId;

  /// No description provided for @settingsIdCopied.
  ///
  /// In en, this message translates to:
  /// **'ID copied to clipboard'**
  String get settingsIdCopied;

  /// No description provided for @settingsLoading.
  ///
  /// In en, this message translates to:
  /// **'Loading…'**
  String get settingsLoading;

  /// No description provided for @settingsConfiguration.
  ///
  /// In en, this message translates to:
  /// **'Configuration'**
  String get settingsConfiguration;

  /// No description provided for @settingsServerUrl.
  ///
  /// In en, this message translates to:
  /// **'Signaling server URL'**
  String get settingsServerUrl;

  /// No description provided for @settingsAudioSection.
  ///
  /// In en, this message translates to:
  /// **'Audio mode'**
  String get settingsAudioSection;

  /// No description provided for @settingsIntercom.
  ///
  /// In en, this message translates to:
  /// **'Intercom mode (helmet / motorcycle)'**
  String get settingsIntercom;

  /// No description provided for @settingsIntercomSub.
  ///
  /// In en, this message translates to:
  /// **'Uses the Bluetooth helmet microphone instead of the phone microphone'**
  String get settingsIntercomSub;

  /// No description provided for @settingsAutoConnect.
  ///
  /// In en, this message translates to:
  /// **'Auto-connect at the gym'**
  String get settingsAutoConnect;

  /// No description provided for @settingsAutoConnectSub.
  ///
  /// In en, this message translates to:
  /// **'Automatically connect with known partners inside a geofence'**
  String get settingsAutoConnectSub;

  /// No description provided for @settingsBackgroundLocation.
  ///
  /// In en, this message translates to:
  /// **'Background location'**
  String get settingsBackgroundLocation;

  /// No description provided for @settingsBackgroundLocationSub.
  ///
  /// In en, this message translates to:
  /// **'Detect gym geofences in the background'**
  String get settingsBackgroundLocationSub;

  /// No description provided for @settingsConnectionStatus.
  ///
  /// In en, this message translates to:
  /// **'Connection status'**
  String get settingsConnectionStatus;

  /// No description provided for @settingsServerConnection.
  ///
  /// In en, this message translates to:
  /// **'Server connection'**
  String get settingsServerConnection;

  /// No description provided for @settingsLatency.
  ///
  /// In en, this message translates to:
  /// **'Latency'**
  String get settingsLatency;

  /// No description provided for @settingsConnectedPeers.
  ///
  /// In en, this message translates to:
  /// **'Connected peers'**
  String get settingsConnectedPeers;

  /// No description provided for @settingsReconnect.
  ///
  /// In en, this message translates to:
  /// **'Reconnect'**
  String get settingsReconnect;

  /// No description provided for @settingsSecurity.
  ///
  /// In en, this message translates to:
  /// **'Account & security'**
  String get settingsSecurity;

  /// No description provided for @settingsRecoveryPhrase.
  ///
  /// In en, this message translates to:
  /// **'Recovery phrase'**
  String get settingsRecoveryPhrase;

  /// No description provided for @settingsRecoveryPhraseSub.
  ///
  /// In en, this message translates to:
  /// **'Back this up — it is the only way to recover your account'**
  String get settingsRecoveryPhraseSub;

  /// No description provided for @settingsShowRecoveryPhrase.
  ///
  /// In en, this message translates to:
  /// **'Show recovery phrase'**
  String get settingsShowRecoveryPhrase;

  /// No description provided for @settingsDevices.
  ///
  /// In en, this message translates to:
  /// **'Your devices'**
  String get settingsDevices;

  /// No description provided for @settingsRevoke.
  ///
  /// In en, this message translates to:
  /// **'Revoke'**
  String get settingsRevoke;

  /// No description provided for @settingsThisDevice.
  ///
  /// In en, this message translates to:
  /// **'This device'**
  String get settingsThisDevice;

  /// No description provided for @settingsLanguage.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get settingsLanguage;

  /// No description provided for @settingsLanguageSystem.
  ///
  /// In en, this message translates to:
  /// **'System default'**
  String get settingsLanguageSystem;

  /// No description provided for @settingsLanguageEnglish.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get settingsLanguageEnglish;

  /// No description provided for @settingsLanguageGerman.
  ///
  /// In en, this message translates to:
  /// **'Deutsch'**
  String get settingsLanguageGerman;

  /// No description provided for @settingsHelp.
  ///
  /// In en, this message translates to:
  /// **'Help & troubleshooting'**
  String get settingsHelp;

  /// No description provided for @settingsHelpMicTitle.
  ///
  /// In en, this message translates to:
  /// **'Why record through the phone microphone?'**
  String get settingsHelpMicTitle;

  /// No description provided for @settingsHelpMicBody.
  ///
  /// In en, this message translates to:
  /// **'When an app opens a Bluetooth headset microphone and speaker at the same time, the phone switches to HFP (Hands-Free Profile). That ruins your music quality (mono 8/16 kHz). p2p-talk avoids this by capturing your voice through the built-in phone microphone and playing music plus your partner\'s voice in full stereo (A2DP) through your headphones.'**
  String get settingsHelpMicBody;

  /// No description provided for @settingsHelpVadTitle.
  ///
  /// In en, this message translates to:
  /// **'Voice Activity Detection (VAD)'**
  String get settingsHelpVadTitle;

  /// No description provided for @settingsHelpVadBody.
  ///
  /// In en, this message translates to:
  /// **'p2p-talk uses Silero VAD (a neural network on the ONNX runtime) to precisely filter speech. Breathing, clattering weights and background noise are suppressed so only actual speech is transmitted.'**
  String get settingsHelpVadBody;

  /// No description provided for @settingsHelpSecurityTitle.
  ///
  /// In en, this message translates to:
  /// **'End-to-end security'**
  String get settingsHelpSecurityTitle;

  /// No description provided for @settingsHelpSecurityBody.
  ///
  /// In en, this message translates to:
  /// **'Calls are encrypted end-to-end (DTLS-SRTP). Even when a call falls back through the relay server, the server only forwards encrypted packets and cannot listen in. Your account is a private key that never leaves this device.'**
  String get settingsHelpSecurityBody;

  /// No description provided for @settingsSave.
  ///
  /// In en, this message translates to:
  /// **'Save settings'**
  String get settingsSave;

  /// No description provided for @settingsSaved.
  ///
  /// In en, this message translates to:
  /// **'Settings saved'**
  String get settingsSaved;

  /// No description provided for @settingsFieldsEmpty.
  ///
  /// In en, this message translates to:
  /// **'Username and server URL must not be empty'**
  String get settingsFieldsEmpty;

  /// No description provided for @settingsVersion.
  ///
  /// In en, this message translates to:
  /// **'p2p-talk v{version}'**
  String settingsVersion(String version);

  /// No description provided for @notifications.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get notifications;

  /// No description provided for @notificationsClearAll.
  ///
  /// In en, this message translates to:
  /// **'Clear all'**
  String get notificationsClearAll;

  /// No description provided for @notificationsEmpty.
  ///
  /// In en, this message translates to:
  /// **'No notifications'**
  String get notificationsEmpty;

  /// No description provided for @notifCallRequest.
  ///
  /// In en, this message translates to:
  /// **'{name} wants to connect'**
  String notifCallRequest(String name);

  /// No description provided for @notifContactRequest.
  ///
  /// In en, this message translates to:
  /// **'New contact request'**
  String get notifContactRequest;

  /// No description provided for @notifContactAccepted.
  ///
  /// In en, this message translates to:
  /// **'Contact request accepted'**
  String get notifContactAccepted;

  /// No description provided for @notifPeerJoined.
  ///
  /// In en, this message translates to:
  /// **'{name} joined the group'**
  String notifPeerJoined(String name);

  /// No description provided for @notifPeerLeft.
  ///
  /// In en, this message translates to:
  /// **'{name} left the group'**
  String notifPeerLeft(String name);

  /// No description provided for @notifConnectionLost.
  ///
  /// In en, this message translates to:
  /// **'Connection lost — reconnecting…'**
  String get notifConnectionLost;

  /// No description provided for @notifReconnected.
  ///
  /// In en, this message translates to:
  /// **'Connection restored'**
  String get notifReconnected;

  /// No description provided for @notifSecurityWarning.
  ///
  /// In en, this message translates to:
  /// **'Security warning: could not verify a peer'**
  String get notifSecurityWarning;

  /// No description provided for @incomingCallTitle.
  ///
  /// In en, this message translates to:
  /// **'Connection request'**
  String get incomingCallTitle;

  /// No description provided for @incomingCallBody.
  ///
  /// In en, this message translates to:
  /// **'{name} wants to connect over p2p-talk to pair your headphone audio.'**
  String incomingCallBody(String name);

  /// No description provided for @accept.
  ///
  /// In en, this message translates to:
  /// **'Accept'**
  String get accept;

  /// No description provided for @decline.
  ///
  /// In en, this message translates to:
  /// **'Decline'**
  String get decline;

  /// No description provided for @onbWelcomeTitle.
  ///
  /// In en, this message translates to:
  /// **'Welcome to p2p-talk'**
  String get onbWelcomeTitle;

  /// No description provided for @onbWelcomeSub.
  ///
  /// In en, this message translates to:
  /// **'Secure, hands-free voice for the gym and the road.'**
  String get onbWelcomeSub;

  /// No description provided for @onbHowTitle.
  ///
  /// In en, this message translates to:
  /// **'How it works'**
  String get onbHowTitle;

  /// No description provided for @onbFeatureVad.
  ///
  /// In en, this message translates to:
  /// **'Voice activation — talk hands-free, no buttons.'**
  String get onbFeatureVad;

  /// No description provided for @onbFeatureDucking.
  ///
  /// In en, this message translates to:
  /// **'Your music ducks automatically when someone speaks.'**
  String get onbFeatureDucking;

  /// No description provided for @onbFeatureNoHfp.
  ///
  /// In en, this message translates to:
  /// **'Full music quality — no HFP downgrade.'**
  String get onbFeatureNoHfp;

  /// No description provided for @onbFeatureP2p.
  ///
  /// In en, this message translates to:
  /// **'Encrypted peer-to-peer, with seamless server fallback.'**
  String get onbFeatureP2p;

  /// No description provided for @onbModesTitle.
  ///
  /// In en, this message translates to:
  /// **'Two modes'**
  String get onbModesTitle;

  /// No description provided for @onbGymModeTitle.
  ///
  /// In en, this message translates to:
  /// **'Gym mode'**
  String get onbGymModeTitle;

  /// No description provided for @onbGymModeSub.
  ///
  /// In en, this message translates to:
  /// **'Phone mic captures your voice; music stays in stereo on your headphones.'**
  String get onbGymModeSub;

  /// No description provided for @onbIntercomModeTitle.
  ///
  /// In en, this message translates to:
  /// **'Intercom mode'**
  String get onbIntercomModeTitle;

  /// No description provided for @onbIntercomModeSub.
  ///
  /// In en, this message translates to:
  /// **'Full helmet/headset voice routing for the motorcycle.'**
  String get onbIntercomModeSub;

  /// No description provided for @onbAccountTitle.
  ///
  /// In en, this message translates to:
  /// **'Create your account'**
  String get onbAccountTitle;

  /// No description provided for @onbAccountSub.
  ///
  /// In en, this message translates to:
  /// **'Your account is a private key on this device — no email, no password.'**
  String get onbAccountSub;

  /// No description provided for @onbCreateAccount.
  ///
  /// In en, this message translates to:
  /// **'Create account'**
  String get onbCreateAccount;

  /// No description provided for @onbRestoreAccount.
  ///
  /// In en, this message translates to:
  /// **'Restore from recovery phrase'**
  String get onbRestoreAccount;

  /// No description provided for @onbUsername.
  ///
  /// In en, this message translates to:
  /// **'Username'**
  String get onbUsername;

  /// No description provided for @onbServerUrl.
  ///
  /// In en, this message translates to:
  /// **'Server URL (e.g. wss://p2p-talk.example.com)'**
  String get onbServerUrl;

  /// No description provided for @onbRecoveryTitle.
  ///
  /// In en, this message translates to:
  /// **'Your recovery phrase'**
  String get onbRecoveryTitle;

  /// No description provided for @onbRecoveryWarning.
  ///
  /// In en, this message translates to:
  /// **'Write these 24 words down and keep them safe. They are the ONLY way to recover your account or add another device. Never share them.'**
  String get onbRecoveryWarning;

  /// No description provided for @onbRecoverySaved.
  ///
  /// In en, this message translates to:
  /// **'I\'ve written it down'**
  String get onbRecoverySaved;

  /// No description provided for @onbEnterRecovery.
  ///
  /// In en, this message translates to:
  /// **'Enter your 24-word recovery phrase'**
  String get onbEnterRecovery;

  /// No description provided for @onbRestoreHint.
  ///
  /// In en, this message translates to:
  /// **'Separate words with spaces'**
  String get onbRestoreHint;

  /// No description provided for @onbNext.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get onbNext;

  /// No description provided for @onbBack.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get onbBack;

  /// No description provided for @onbGetStarted.
  ///
  /// In en, this message translates to:
  /// **'Get started'**
  String get onbGetStarted;

  /// No description provided for @onbUsernameTaken.
  ///
  /// In en, this message translates to:
  /// **'That username is already taken'**
  String get onbUsernameTaken;

  /// No description provided for @onbUsernameEmpty.
  ///
  /// In en, this message translates to:
  /// **'Please enter a username'**
  String get onbUsernameEmpty;

  /// No description provided for @onbInvalidPhrase.
  ///
  /// In en, this message translates to:
  /// **'Invalid recovery phrase'**
  String get onbInvalidPhrase;

  /// No description provided for @onbServerRequired.
  ///
  /// In en, this message translates to:
  /// **'Please enter the server URL'**
  String get onbServerRequired;

  /// No description provided for @onbAccountFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not create the account. Check the server URL and try again.'**
  String get onbAccountFailed;

  /// No description provided for @onbRestoreFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not restore the account. Check the phrase and server URL.'**
  String get onbRestoreFailed;

  /// No description provided for @contactsTitle.
  ///
  /// In en, this message translates to:
  /// **'Partners'**
  String get contactsTitle;

  /// No description provided for @contactsAddByUsername.
  ///
  /// In en, this message translates to:
  /// **'Add partner by username'**
  String get contactsAddByUsername;

  /// No description provided for @contactsAdd.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get contactsAdd;

  /// No description provided for @contactsYourContacts.
  ///
  /// In en, this message translates to:
  /// **'Your contacts'**
  String get contactsYourContacts;

  /// No description provided for @contactsNearby.
  ///
  /// In en, this message translates to:
  /// **'Nearby'**
  String get contactsNearby;

  /// No description provided for @contactsBluetooth.
  ///
  /// In en, this message translates to:
  /// **'Bluetooth direct scan'**
  String get contactsBluetooth;

  /// No description provided for @contactsScan.
  ///
  /// In en, this message translates to:
  /// **'Scan'**
  String get contactsScan;

  /// No description provided for @contactsScanning.
  ///
  /// In en, this message translates to:
  /// **'Scanning…'**
  String get contactsScanning;

  /// No description provided for @contactsConnect.
  ///
  /// In en, this message translates to:
  /// **'Connect'**
  String get contactsConnect;

  /// No description provided for @contactsAcceptReq.
  ///
  /// In en, this message translates to:
  /// **'Accept'**
  String get contactsAcceptReq;

  /// No description provided for @contactsDisconnect.
  ///
  /// In en, this message translates to:
  /// **'Disconnect'**
  String get contactsDisconnect;

  /// No description provided for @contactsNoContacts.
  ///
  /// In en, this message translates to:
  /// **'No contacts yet. Add a partner by username.'**
  String get contactsNoContacts;

  /// No description provided for @contactsNoNearby.
  ///
  /// In en, this message translates to:
  /// **'No one nearby right now.'**
  String get contactsNoNearby;

  /// No description provided for @contactsNoBluetooth.
  ///
  /// In en, this message translates to:
  /// **'No p2p-talk devices found nearby.'**
  String get contactsNoBluetooth;

  /// No description provided for @contactsRequestSent.
  ///
  /// In en, this message translates to:
  /// **'Contact request sent'**
  String get contactsRequestSent;

  /// No description provided for @contactsUserNotFound.
  ///
  /// In en, this message translates to:
  /// **'User not found'**
  String get contactsUserNotFound;

  /// No description provided for @contactsSameGym.
  ///
  /// In en, this message translates to:
  /// **'Same gym'**
  String get contactsSameGym;

  /// No description provided for @contactsStatusPending.
  ///
  /// In en, this message translates to:
  /// **'Pending'**
  String get contactsStatusPending;

  /// No description provided for @locationsTitle.
  ///
  /// In en, this message translates to:
  /// **'Locations (geofences)'**
  String get locationsTitle;

  /// No description provided for @locationsBackgroundMonitoring.
  ///
  /// In en, this message translates to:
  /// **'Background monitoring'**
  String get locationsBackgroundMonitoring;

  /// No description provided for @locationsCurrentPosition.
  ///
  /// In en, this message translates to:
  /// **'Current position'**
  String get locationsCurrentPosition;

  /// No description provided for @locationsNoPosition.
  ///
  /// In en, this message translates to:
  /// **'No position yet'**
  String get locationsNoPosition;

  /// No description provided for @locationsAddCurrent.
  ///
  /// In en, this message translates to:
  /// **'Add current location as a gym'**
  String get locationsAddCurrent;

  /// No description provided for @locationsGymName.
  ///
  /// In en, this message translates to:
  /// **'Gym name'**
  String get locationsGymName;

  /// No description provided for @locationsRadius.
  ///
  /// In en, this message translates to:
  /// **'Radius (m)'**
  String get locationsRadius;

  /// No description provided for @locationsAdd.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get locationsAdd;

  /// No description provided for @locationsHere.
  ///
  /// In en, this message translates to:
  /// **'HERE'**
  String get locationsHere;

  /// No description provided for @locationsNoGyms.
  ///
  /// In en, this message translates to:
  /// **'No gyms saved yet.'**
  String get locationsNoGyms;

  /// No description provided for @locationsRadiusLabel.
  ///
  /// In en, this message translates to:
  /// **'Radius: {radius} m'**
  String locationsRadiusLabel(String radius);

  /// No description provided for @locationsPermissionDenied.
  ///
  /// In en, this message translates to:
  /// **'Location permission denied'**
  String get locationsPermissionDenied;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['de', 'en'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'de':
      return AppLocalizationsDe();
    case 'en':
      return AppLocalizationsEn();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
