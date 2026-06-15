// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for German (`de`).
class AppLocalizationsDe extends AppLocalizations {
  AppLocalizationsDe([String locale = 'de']) : super(locale);

  @override
  String get appName => 'p2p-talk';

  @override
  String get online => 'Online';

  @override
  String get offline => 'Offline';

  @override
  String get connected => 'Verbunden';

  @override
  String get disconnected => 'Nicht verbunden';

  @override
  String get connecting => 'Verbinde…';

  @override
  String get save => 'Speichern';

  @override
  String get cancel => 'Abbrechen';

  @override
  String get close => 'Schließen';

  @override
  String get delete => 'Löschen';

  @override
  String get copy => 'Kopieren';

  @override
  String get retry => 'Erneut';

  @override
  String get navIntercom => 'Intercom';

  @override
  String get navPartners => 'Partner';

  @override
  String get navGyms => 'Gyms';

  @override
  String get navSetup => 'Setup';

  @override
  String get homeReady => 'BEREIT';

  @override
  String get homeYouSpeak => 'DU SPRICHST';

  @override
  String get homeSearching => 'SUCHE PARTNER';

  @override
  String get homeIntercomOff => 'INTERCOM AUS';

  @override
  String get homeTapToStart => 'Tippen zum Starten';

  @override
  String get homeTapToStop => 'Tippen zum Stoppen';

  @override
  String get homeConnectedPartners => 'Verbundene Partner';

  @override
  String homePeers(int count) {
    return '$count Peers';
  }

  @override
  String get homeSessionInfo => 'Sitzungsinformationen';

  @override
  String get homeStatus => 'Status:';

  @override
  String get homePartner => 'Partner:';

  @override
  String get homeAudioMode => 'Audio-Modus:';

  @override
  String get homeAudioIntercom => 'Intercom (Helm-Mikro)';

  @override
  String get homeAudioGym => 'Gym-Modus (Musik-Fokus)';

  @override
  String get homeDucking => 'Audio-Ducking:';

  @override
  String get homeDuckingActive => 'Aktiv (Musik leise)';

  @override
  String get homeDuckingReady => 'Bereit (Musik normal)';

  @override
  String get homeReconnect => 'Reconnect:';

  @override
  String homeReconnectAttempt(int n) {
    return 'Versuch $n/10';
  }

  @override
  String get homeRelayed => 'Über Relay (stelle direkt wieder her…)';

  @override
  String get homeSecured => 'Gesichert';

  @override
  String get homeUnverified => 'Nicht verifiziert';

  @override
  String get homeTipIntercom =>
      'Tipp: Im Intercom-Modus wird deine Stimme über das Mikrofon deines Helms/Headsets aufgenommen. Das Handy kann in der Tasche bleiben.';

  @override
  String get homeTipGym =>
      'Tipp: Halte das Handy in deiner Nähe (z. B. Brusttasche oder Ablage), damit das eingebaute Mikrofon deine Stimme klar aufnimmt.';

  @override
  String get homeDefaultPartner => 'Partner';

  @override
  String get settingsTitle => 'Einstellungen';

  @override
  String get settingsAccount => 'Dein Account';

  @override
  String get settingsUsername => 'Benutzername';

  @override
  String get settingsAccountId =>
      'Deine p2p-talk-ID (teile sie mit deinem Partner):';

  @override
  String get settingsIdCopied => 'ID in die Zwischenablage kopiert';

  @override
  String get settingsLoading => 'Wird geladen…';

  @override
  String get settingsConfiguration => 'Konfiguration';

  @override
  String get settingsServerUrl => 'Signaling-Server-URL';

  @override
  String get settingsAudioSection => 'Audio-Modus';

  @override
  String get settingsIntercom => 'Intercom-Modus (Helm / Motorrad)';

  @override
  String get settingsIntercomSub =>
      'Nutzt das Bluetooth-Helm-Mikrofon statt des Handy-Mikrofons';

  @override
  String get settingsAutoConnect => 'Auto-Connect im Gym';

  @override
  String get settingsAutoConnectSub =>
      'Verbinde automatisch mit bekannten Partnern im Geofence';

  @override
  String get settingsBackgroundLocation => 'Hintergrund-Standort';

  @override
  String get settingsBackgroundLocationSub =>
      'Erkennt Gym-Geofences auch im Hintergrund';

  @override
  String get settingsConnectionStatus => 'Verbindungsstatus';

  @override
  String get settingsServerConnection => 'Server-Verbindung';

  @override
  String get settingsLatency => 'Latenz';

  @override
  String get settingsConnectedPeers => 'Verbundene Peers';

  @override
  String get settingsReconnect => 'Neu verbinden';

  @override
  String get settingsSecurity => 'Account & Sicherheit';

  @override
  String get settingsRecoveryPhrase => 'Wiederherstellungsphrase';

  @override
  String get settingsRecoveryPhraseSub =>
      'Sichere sie — nur damit kannst du deinen Account wiederherstellen';

  @override
  String get settingsShowRecoveryPhrase => 'Wiederherstellungsphrase anzeigen';

  @override
  String get settingsDevices => 'Deine Geräte';

  @override
  String get settingsRevoke => 'Entziehen';

  @override
  String get settingsThisDevice => 'Dieses Gerät';

  @override
  String get settingsLanguage => 'Sprache';

  @override
  String get settingsLanguageSystem => 'Systemstandard';

  @override
  String get settingsLanguageEnglish => 'English';

  @override
  String get settingsLanguageGerman => 'Deutsch';

  @override
  String get settingsHelp => 'Hilfe & Fehlerbehebung';

  @override
  String get settingsHelpMicTitle => 'Warum über das Handy-Mikrofon aufnehmen?';

  @override
  String get settingsHelpMicBody =>
      'Wenn eine App gleichzeitig ein Bluetooth-Kopfhörer-Mikrofon und den Lautsprecher öffnet, schaltet das Handy auf HFP (Hands-Free Profile) um. Das ruiniert die Soundqualität deiner Musik (Mono 8/16 kHz). p2p-talk umgeht dies, indem es deine Stimme über das eingebaute Handymikrofon aufnimmt und Musik sowie Partner-Stimmen in voller Stereo-Qualität (A2DP) über deine Kopfhörer ausgibt.';

  @override
  String get settingsHelpVadTitle => 'Voice Activity Detection (VAD)';

  @override
  String get settingsHelpVadBody =>
      'p2p-talk nutzt Silero VAD (ein neuronales Netz auf ONNX-Runtime-Basis), um Sprache präzise zu filtern. Atemgeräusche, Gewichte-Klappern und Nebengeräusche werden ausgeblendet, sodass nur tatsächliche Sprache übertragen wird.';

  @override
  String get settingsHelpSecurityTitle => 'Ende-zu-Ende-Sicherheit';

  @override
  String get settingsHelpSecurityBody =>
      'Gespräche sind Ende-zu-Ende verschlüsselt (DTLS-SRTP). Selbst wenn ein Gespräch über den Relay-Server ausweicht, leitet der Server nur verschlüsselte Pakete weiter und kann nicht mithören. Dein Account ist ein privater Schlüssel, der dieses Gerät nie verlässt.';

  @override
  String get settingsSave => 'Einstellungen speichern';

  @override
  String get settingsSaved => 'Einstellungen gespeichert';

  @override
  String get settingsFieldsEmpty =>
      'Benutzername und Server-URL dürfen nicht leer sein';

  @override
  String settingsVersion(String version) {
    return 'p2p-talk v$version';
  }

  @override
  String get notifications => 'Benachrichtigungen';

  @override
  String get notificationsClearAll => 'Alle löschen';

  @override
  String get notificationsEmpty => 'Keine Benachrichtigungen';

  @override
  String notifCallRequest(String name) {
    return '$name möchte sich verbinden';
  }

  @override
  String get notifContactRequest => 'Neue Kontaktanfrage';

  @override
  String get notifContactAccepted => 'Kontaktanfrage akzeptiert';

  @override
  String notifPeerJoined(String name) {
    return '$name ist der Gruppe beigetreten';
  }

  @override
  String notifPeerLeft(String name) {
    return '$name hat die Gruppe verlassen';
  }

  @override
  String get notifConnectionLost => 'Verbindung verloren — verbinde neu…';

  @override
  String get notifReconnected => 'Verbindung wiederhergestellt';

  @override
  String get notifSecurityWarning =>
      'Sicherheitswarnung: Ein Peer konnte nicht verifiziert werden';

  @override
  String get incomingCallTitle => 'Verbindungsanfrage';

  @override
  String incomingCallBody(String name) {
    return '$name möchte sich über p2p-talk verbinden, um eure Kopfhörer-Audioübertragung zu koppeln.';
  }

  @override
  String get accept => 'Annehmen';

  @override
  String get decline => 'Ablehnen';

  @override
  String get onbWelcomeTitle => 'Willkommen bei p2p-talk';

  @override
  String get onbWelcomeSub =>
      'Sichere, freihändige Sprache fürs Gym und unterwegs.';

  @override
  String get onbHowTitle => 'So funktioniert\'s';

  @override
  String get onbFeatureVad =>
      'Sprachaktivierung — freihändig reden, keine Knöpfe.';

  @override
  String get onbFeatureDucking =>
      'Deine Musik wird automatisch leiser, wenn jemand spricht.';

  @override
  String get onbFeatureNoHfp => 'Volle Musikqualität — kein HFP-Downgrade.';

  @override
  String get onbFeatureP2p =>
      'Verschlüsselt Peer-to-Peer, mit nahtlosem Server-Fallback.';

  @override
  String get onbModesTitle => 'Zwei Modi';

  @override
  String get onbGymModeTitle => 'Gym-Modus';

  @override
  String get onbGymModeSub =>
      'Das Handy-Mikro nimmt deine Stimme auf; Musik bleibt in Stereo auf deinen Kopfhörern.';

  @override
  String get onbIntercomModeTitle => 'Intercom-Modus';

  @override
  String get onbIntercomModeSub =>
      'Volle Helm-/Headset-Sprachführung fürs Motorrad.';

  @override
  String get onbAccountTitle => 'Erstelle deinen Account';

  @override
  String get onbAccountSub =>
      'Dein Account ist ein privater Schlüssel auf diesem Gerät — keine E-Mail, kein Passwort.';

  @override
  String get onbCreateAccount => 'Account erstellen';

  @override
  String get onbRestoreAccount =>
      'Aus Wiederherstellungsphrase wiederherstellen';

  @override
  String get onbUsername => 'Benutzername';

  @override
  String get onbServerUrl => 'Server-URL (z. B. wss://p2p-talk.example.com)';

  @override
  String get onbRecoveryTitle => 'Deine Wiederherstellungsphrase';

  @override
  String get onbRecoveryWarning =>
      'Schreibe diese 24 Wörter auf und bewahre sie sicher auf. Sie sind der EINZIGE Weg, deinen Account wiederherzustellen oder ein weiteres Gerät hinzuzufügen. Teile sie niemals.';

  @override
  String get onbRecoverySaved => 'Ich habe sie notiert';

  @override
  String get onbEnterRecovery =>
      'Gib deine 24-Wort-Wiederherstellungsphrase ein';

  @override
  String get onbRestoreHint => 'Wörter durch Leerzeichen trennen';

  @override
  String get onbNext => 'Weiter';

  @override
  String get onbBack => 'Zurück';

  @override
  String get onbGetStarted => 'Los geht\'s';

  @override
  String get onbUsernameTaken => 'Dieser Benutzername ist bereits vergeben';

  @override
  String get onbUsernameEmpty => 'Bitte gib einen Benutzernamen ein';

  @override
  String get onbInvalidPhrase => 'Ungültige Wiederherstellungsphrase';

  @override
  String get onbServerRequired => 'Bitte gib die Server-URL ein';

  @override
  String get onbAccountFailed =>
      'Account konnte nicht erstellt werden. Prüfe die Server-URL und versuche es erneut.';

  @override
  String get onbRestoreFailed =>
      'Account konnte nicht wiederhergestellt werden. Prüfe Phrase und Server-URL.';

  @override
  String get contactsTitle => 'Partner';

  @override
  String get contactsAddByUsername => 'Partner per Benutzername hinzufügen';

  @override
  String get contactsAdd => 'Hinzufügen';

  @override
  String get contactsYourContacts => 'Deine Kontakte';

  @override
  String get contactsNearby => 'In der Nähe';

  @override
  String get contactsBluetooth => 'Bluetooth-Direktsuche';

  @override
  String get contactsScan => 'Suchen';

  @override
  String get contactsScanning => 'Suche…';

  @override
  String get contactsConnect => 'Verbinden';

  @override
  String get contactsAcceptReq => 'Annehmen';

  @override
  String get contactsDisconnect => 'Trennen';

  @override
  String get contactsNoContacts =>
      'Noch keine Kontakte. Füge einen Partner per Benutzername hinzu.';

  @override
  String get contactsNoNearby => 'Gerade niemand in der Nähe.';

  @override
  String get contactsNoBluetooth =>
      'Keine p2p-talk-Geräte in der Nähe gefunden.';

  @override
  String get contactsRequestSent => 'Kontaktanfrage gesendet';

  @override
  String get contactsUserNotFound => 'Benutzer nicht gefunden';

  @override
  String get contactsSameGym => 'Gleiches Gym';

  @override
  String get contactsStatusPending => 'Ausstehend';

  @override
  String get locationsTitle => 'Standorte (Geofences)';

  @override
  String get locationsBackgroundMonitoring => 'Hintergrund-Überwachung';

  @override
  String get locationsCurrentPosition => 'Aktuelle Position';

  @override
  String get locationsNoPosition => 'Noch keine Position';

  @override
  String get locationsAddCurrent => 'Aktuellen Standort als Gym hinzufügen';

  @override
  String get locationsGymName => 'Gym-Name';

  @override
  String get locationsRadius => 'Radius (m)';

  @override
  String get locationsAdd => 'Hinzufügen';

  @override
  String get locationsHere => 'HIER';

  @override
  String get locationsNoGyms => 'Noch keine Gyms gespeichert.';

  @override
  String locationsRadiusLabel(String radius) {
    return 'Radius: $radius m';
  }

  @override
  String get locationsPermissionDenied => 'Standortberechtigung verweigert';
}
