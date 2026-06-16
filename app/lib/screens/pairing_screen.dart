import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../l10n/app_localizations.dart';
import '../services/webrtc_service.dart';
import '../services/vad_service.dart';
import '../services/audio_manager.dart';
import '../services/foreground_service.dart';

/// Serverless pairing: two adjacent phones exchange the WebRTC offer/answer as
/// QR codes (no server). One phone "shows an invite", the other "scans" it and
/// shows a response back. The signed fingerprint chain is verified offline.
enum _PairMode { choose, showOffer, scanResponse, scanOffer, showResponse, connected }

class PairingScreen extends StatefulWidget {
  const PairingScreen({super.key});

  @override
  State<PairingScreen> createState() => _PairingScreenState();
}

class _PairingScreenState extends State<PairingScreen> {
  _PairMode _mode = _PairMode.choose;
  String? _qrData; // payload to display (offer or response)
  bool _busy = false;
  bool _handledScan = false;

  static const darkBg = Color(0xFF0F111A);
  static const neonCyan = Color(0xFF00E5FF);
  static const textGray = Color(0xFF9094A6);

  // Conservative byte capacity for a single QR code. A version-40 symbol holds
  // up to 2953 bytes at ECC level L, but we cap well below that for reliable
  // close-range phone-to-phone scans. Real pairing payloads (gzipped + base64
  // SDP) are ~1.1–1.9 KB, so this never triggers in practice.
  static const _maxQrBytes = 2331;

  AppLocalizations get t => AppLocalizations.of(context);
  WebRTCService get _webRTC => Provider.of<WebRTCService>(context, listen: false);

  void _snack(String msg) {
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _startInvite() async {
    setState(() => _busy = true);
    try {
      final offer = await _webRTC.createPairingOffer();
      if (offer.length > _maxQrBytes) {
        _snack(t.pairTooLarge);
        setState(() => _busy = false);
        return;
      }
      setState(() {
        _qrData = offer;
        _mode = _PairMode.showOffer;
        _busy = false;
      });
    } catch (e) {
      _snack(t.pairTooLarge);
      setState(() => _busy = false);
    }
  }

  Future<void> _onOfferScanned(String raw) async {
    if (_handledScan) return;
    _handledScan = true;
    setState(() => _busy = true);
    try {
      final answer = await _webRTC.acceptPairingOffer(raw);
      if (answer == null) {
        _snack(t.pairInvalid);
        _handledScan = false;
        setState(() => _busy = false);
        return;
      }
      if (answer.length > _maxQrBytes) {
        _snack(t.pairTooLarge);
        setState(() => _busy = false);
        return;
      }
      setState(() {
        _qrData = answer;
        _mode = _PairMode.showResponse;
        _busy = false;
      });
      _watchConnection();
    } catch (e) {
      _snack(t.pairInvalid);
      _handledScan = false;
      setState(() => _busy = false);
    }
  }

  Future<void> _onResponseScanned(String raw) async {
    if (_handledScan) return;
    _handledScan = true;
    setState(() => _busy = true);
    final ok = await _webRTC.applyPairingAnswer(raw);
    if (!ok) {
      _snack(t.pairInvalid);
      _handledScan = false;
      setState(() => _busy = false);
      return;
    }
    _watchConnection();
  }

  /// Once the peer connection is up, start the intercom so they can talk.
  void _watchConnection() {
    final audio = Provider.of<AudioManager>(context, listen: false);
    final vad = Provider.of<VadService>(context, listen: false);
    final webRTC = _webRTC;
    final appName = t.appName;
    final connectedText = t.pairConnected;
    setState(() => _mode = _PairMode.connected);
    Future.microtask(() async {
      await audio.init();
      webRTC.setIntercomActive(true);
      await vad.start();
      await P2PForegroundService.start(title: appName, text: connectedText);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: darkBg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(t.pairTitle, style: const TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: switch (_mode) {
          _PairMode.choose => _chooseView(),
          _PairMode.showOffer => _qrView(t.pairShowInvite, _qrData!, footerButton: _scanResponseButton()),
          _PairMode.scanResponse => _scannerView(t.pairScanResponse, _onResponseScanned),
          _PairMode.scanOffer => _scannerView(t.pairPointCamera, _onOfferScanned),
          _PairMode.showResponse => _qrView(t.pairShowResponse, _qrData!),
          _PairMode.connected => _connectedView(),
        },
      ),
    );
  }

  Widget _chooseView() => Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.qr_code_2, size: 72, color: neonCyan),
          const SizedBox(height: 16),
          Text(t.pairIntro, textAlign: TextAlign.center, style: const TextStyle(color: textGray)),
          const SizedBox(height: 32),
          _bigButton(t.pairShowInvite, Icons.qr_code, _busy ? null : _startInvite),
          const SizedBox(height: 12),
          _bigButton(t.pairScanInvite, Icons.qr_code_scanner, _busy ? null : () {
            _handledScan = false;
            setState(() => _mode = _PairMode.scanOffer);
          }, outlined: true),
        ],
      );

  Widget _qrView(String title, String data, {Widget? footerButton}) => Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(title, textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
            child: QrImageView(
              data: data,
              version: QrVersions.auto,
              size: 260,
              errorCorrectionLevel: QrErrorCorrectLevel.L,
              errorStateBuilder: (context, error) => SizedBox(
                width: 260,
                height: 260,
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(t.pairTooLarge,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.black87)),
                  ),
                ),
              ),
            ),
          ),
          if (footerButton != null) ...[const SizedBox(height: 24), footerButton],
        ],
      );

  Widget _scanResponseButton() => _bigButton(t.pairScanResponse, Icons.qr_code_scanner, () {
        _handledScan = false;
        setState(() => _mode = _PairMode.scanResponse);
      });

  Widget _scannerView(String hint, Future<void> Function(String) onScan) => Column(
        children: [
          Text(hint, textAlign: TextAlign.center, style: const TextStyle(color: textGray)),
          const SizedBox(height: 16),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: MobileScanner(
                onDetect: (capture) {
                  for (final b in capture.barcodes) {
                    final v = b.rawValue;
                    if (v != null && v.isNotEmpty) {
                      onScan(v);
                      break;
                    }
                  }
                },
              ),
            ),
          ),
          if (_busy) const Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator(color: neonCyan)),
        ],
      );

  Widget _connectedView() => Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.verified_user, size: 72, color: Colors.green),
          const SizedBox(height: 16),
          Text(t.pairConnected, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text(t.pairConnecting, style: const TextStyle(color: textGray)),
          const SizedBox(height: 32),
          _bigButton(t.close, Icons.check, () => Navigator.of(context).pop()),
        ],
      );

  Widget _bigButton(String label, IconData icon, VoidCallback? onTap, {bool outlined = false}) {
    final child = Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [Icon(icon, size: 18), const SizedBox(width: 8), Text(label, style: const TextStyle(fontWeight: FontWeight.bold))],
    );
    return SizedBox(
      width: double.infinity,
      child: outlined
          ? OutlinedButton(
              style: OutlinedButton.styleFrom(
                foregroundColor: neonCyan,
                side: const BorderSide(color: neonCyan),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              onPressed: onTap,
              child: child)
          : ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: neonCyan,
                foregroundColor: darkBg,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              onPressed: onTap,
              child: child),
    );
  }
}
