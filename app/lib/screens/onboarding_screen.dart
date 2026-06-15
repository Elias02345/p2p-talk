import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../l10n/app_localizations.dart';
import '../main.dart';
import '../providers/locale_provider.dart';
import '../services/account_service.dart';
import '../services/webrtc_service.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  bool _busy = false;
  final _usernameController = TextEditingController();
  final _serverController =
      TextEditingController(text: kDefaultServerUrl.isNotEmpty ? kDefaultServerUrl : 'wss://');

  static const neonCyan = Color(0xFF00E5FF);
  static const darkBg = Color(0xFF0F111A);
  static const cardBg = Color(0xFF181C2E);
  static const textGray = Color(0xFF9094A6);

  AppLocalizations get t => AppLocalizations.of(context);

  @override
  void dispose() {
    _pageController.dispose();
    _usernameController.dispose();
    _serverController.dispose();
    super.dispose();
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: darkBg,
      body: SafeArea(
        child: Column(
          children: [
            _languageBar(),
            Expanded(
              child: PageView(
                controller: _pageController,
                onPageChanged: (i) => setState(() => _currentPage = i),
                children: [
                  _welcomePage(),
                  _howItWorksPage(),
                  _modesPage(),
                  _accountPage(),
                ],
              ),
            ),
            if (_currentPage < 3) _navBar(),
          ],
        ),
      ),
    );
  }

  Widget _languageBar() {
    final lp = Provider.of<LocaleProvider>(context);
    final current = lp.locale?.languageCode;
    Widget chip(String label, String? code) => TextButton(
          onPressed: () => lp.setLocale(code == null ? null : Locale(code)),
          child: Text(label,
              style: TextStyle(
                color: current == code ? neonCyan : textGray,
                fontWeight: current == code ? FontWeight.bold : FontWeight.normal,
              )),
        );
    return Align(
      alignment: Alignment.centerRight,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Row(mainAxisSize: MainAxisSize.min, children: [chip('EN', 'en'), chip('DE', 'de')]),
      ),
    );
  }

  Widget _navBar() {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: List.generate(
              4,
              (i) => AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                margin: const EdgeInsets.symmetric(horizontal: 4),
                width: _currentPage == i ? 24 : 8,
                height: 8,
                decoration: BoxDecoration(
                  color: _currentPage == i ? neonCyan : textGray.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: neonCyan,
              foregroundColor: darkBg,
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
            onPressed: () => _pageController.nextPage(
              duration: const Duration(milliseconds: 400),
              curve: Curves.easeInOut,
            ),
            child: Text(t.onbNext, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          ),
        ],
      ),
    );
  }

  Widget _welcomePage() => Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(colors: [neonCyan.withValues(alpha: 0.3), Colors.transparent], radius: 0.8),
              ),
              child: const Icon(Icons.mic, size: 64, color: neonCyan),
            ),
            const SizedBox(height: 40),
            Text(t.onbWelcomeTitle,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.white, height: 1.2)),
            const SizedBox(height: 16),
            Text(t.onbWelcomeSub,
                textAlign: TextAlign.center, style: const TextStyle(fontSize: 16, color: textGray, height: 1.5)),
          ],
        ),
      );

  Widget _howItWorksPage() => Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.auto_awesome, size: 48, color: neonCyan),
            const SizedBox(height: 32),
            Text(t.onbHowTitle, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white)),
            const SizedBox(height: 32),
            _featureRow(Icons.record_voice_over, t.onbFeatureVad),
            const SizedBox(height: 20),
            _featureRow(Icons.volume_down, t.onbFeatureDucking),
            const SizedBox(height: 20),
            _featureRow(Icons.headphones, t.onbFeatureNoHfp),
            const SizedBox(height: 20),
            _featureRow(Icons.lock, t.onbFeatureP2p),
          ],
        ),
      );

  Widget _modesPage() => Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(t.onbModesTitle, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white)),
            const SizedBox(height: 32),
            _modeCard(Icons.fitness_center, neonCyan, t.onbGymModeTitle, t.onbGymModeSub),
            const SizedBox(height: 16),
            _modeCard(Icons.sports_motorsports, Colors.amber, t.onbIntercomModeTitle, t.onbIntercomModeSub),
          ],
        ),
      );

  Widget _accountPage() => SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          children: [
            const SizedBox(height: 20),
            const Icon(Icons.shield_outlined, size: 48, color: neonCyan),
            const SizedBox(height: 24),
            Text(t.onbAccountTitle,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white)),
            const SizedBox(height: 12),
            Text(t.onbAccountSub, textAlign: TextAlign.center, style: const TextStyle(color: textGray, fontSize: 13)),
            const SizedBox(height: 28),
            _field(_usernameController, t.onbUsername, Icons.person_outline),
            const SizedBox(height: 16),
            _field(_serverController, t.onbServerUrl, Icons.dns_outlined, small: true),
            const SizedBox(height: 28),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: neonCyan,
                  foregroundColor: darkBg,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                onPressed: _busy ? null : _createAccount,
                child: _busy
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: darkBg))
                    : Text(t.onbCreateAccount, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              ),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: _busy ? null : _restoreAccount,
              child: Text(t.onbRestoreAccount, style: const TextStyle(color: textGray)),
            ),
          ],
        ),
      );

  Widget _field(TextEditingController c, String label, IconData icon, {bool small = false}) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
        ),
        child: TextField(
          controller: c,
          style: TextStyle(color: Colors.white, fontSize: small ? 14 : 16),
          decoration: InputDecoration(
            labelText: label,
            labelStyle: const TextStyle(color: textGray),
            border: InputBorder.none,
            prefixIcon: Icon(icon, color: neonCyan),
          ),
        ),
      );

  Widget _featureRow(IconData icon, String text) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(color: neonCyan.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, color: neonCyan, size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(child: Text(text, style: const TextStyle(color: Colors.white, fontSize: 14))),
        ],
      );

  Widget _modeCard(IconData icon, Color color, String title, String sub) => Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(14)),
              child: Icon(icon, color: color),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 4),
                  Text(sub, style: const TextStyle(color: textGray, fontSize: 12)),
                ],
              ),
            ),
          ],
        ),
      );

  // --- actions --------------------------------------------------------------

  Future<bool> _prepare() async {
    final server = _serverController.text.trim();
    if (server.isEmpty || server == 'wss://') {
      _snack(t.onbServerRequired);
      return false;
    }
    final account = Provider.of<AccountService>(context, listen: false);
    account.setApiBaseUrl(server);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(kPrefServerUrl, server);
    return true;
  }

  Future<void> _createAccount() async {
    final username = _usernameController.text.trim();
    if (username.isEmpty) {
      _snack(t.onbUsernameEmpty);
      return;
    }
    if (!await _prepare()) return;
    if (!mounted) return;
    setState(() => _busy = true);
    final account = Provider.of<AccountService>(context, listen: false);
    try {
      final mnemonic = await account.createAccount(username);
      if (!mounted) return;
      await _showRecoveryPhrase(mnemonic);
      _finish();
    } catch (e) {
      _snack(e.toString().contains('taken') ? t.onbUsernameTaken : t.onbAccountFailed);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _restoreAccount() async {
    if (!await _prepare()) return;
    if (!mounted) return;
    final controller = TextEditingController();
    final phrase = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: cardBg,
        title: Text(t.onbEnterRecovery, style: const TextStyle(color: Colors.white, fontSize: 16)),
        content: TextField(
          controller: controller,
          maxLines: 3,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(hintText: t.onbRestoreHint, hintStyle: const TextStyle(color: textGray)),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(t.cancel, style: const TextStyle(color: textGray))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: neonCyan, foregroundColor: darkBg),
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: Text(t.onbRestoreAccount),
          ),
        ],
      ),
    );
    if (phrase == null || phrase.isEmpty) return;
    if (!mounted) return;
    setState(() => _busy = true);
    final account = Provider.of<AccountService>(context, listen: false);
    try {
      await account.restoreAccount(phrase);
      _finish();
    } catch (e) {
      _snack(e.toString().contains('Invalid') ? t.onbInvalidPhrase : t.onbRestoreFailed);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _showRecoveryPhrase(String mnemonic) async {
    final words = mnemonic.split(' ');
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: cardBg,
        title: Text(t.onbRecoveryTitle, style: const TextStyle(color: neonCyan, fontWeight: FontWeight.bold)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(t.onbRecoveryWarning, style: const TextStyle(color: textGray, fontSize: 12)),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: Colors.black26, borderRadius: BorderRadius.circular(12)),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: List.generate(
                    words.length,
                    (i) => Text('${i + 1}. ${words[i]}',
                        style: const TextStyle(color: Colors.white, fontFamily: 'monospace', fontSize: 13)),
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: neonCyan, foregroundColor: darkBg),
            onPressed: () => Navigator.pop(ctx),
            child: Text(t.onbRecoverySaved),
          ),
        ],
      ),
    );
  }

  void _finish() {
    if (!mounted) return;
    final server = _serverController.text.trim();
    // Wire the transport to the chosen server (providers live above this screen).
    Provider.of<WebRTCService>(context, listen: false).init(server);
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const MainNavigationShell()),
    );
  }
}
