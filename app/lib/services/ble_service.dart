import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import '../utils/logger.dart';

/// BLE advertised name prefix used to discover nearby p2p-talk users.
const String kBlePrefix = 'p2ptalk_';

class NearbyDevice {
  final String id;
  final String name;
  final String username;
  final int rssi;

  NearbyDevice({
    required this.id,
    required this.name,
    required this.username,
    required this.rssi,
  });
}

class BleService extends ChangeNotifier {
  final List<NearbyDevice> _nearbyDevices = [];
  bool _isScanning = false;
  StreamSubscription<List<ScanResult>>? _scanResultsSub;
  StreamSubscription<bool>? _isScanningSub;
  DateTime? _lastScanStart;

  // Debounce: ignore repeated scan requests within this window to save battery
  // (geofence triggers can otherwise oscillate at a gym boundary).
  static const Duration _scanDebounce = Duration(seconds: 30);
  static const Duration _scanDuration = Duration(seconds: 8);

  List<NearbyDevice> get nearbyDevices => _nearbyDevices;
  bool get isScanning => _isScanning;

  Future<void> init() async {
    await _isScanningSub?.cancel();
    await _scanResultsSub?.cancel();
    _isScanningSub = FlutterBluePlus.isScanning.listen((state) {
      _isScanning = state;
      notifyListeners();
    });
    _scanResultsSub = FlutterBluePlus.scanResults.listen(_processScanResults);
  }

  Future<bool> _requestPermissions() async {
    if (kIsWeb) return false;
    final statuses = await [
      Permission.bluetooth,
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.bluetoothAdvertise,
      Permission.location,
    ].request();
    return statuses[Permission.bluetoothScan]?.isGranted == true &&
        statuses[Permission.bluetoothConnect]?.isGranted == true;
  }

  Future<void> startScanning({bool force = false}) async {
    if (_isScanning) return;
    if (!force && _lastScanStart != null &&
        DateTime.now().difference(_lastScanStart!) < _scanDebounce) {
      log('BLE scan debounced.');
      return;
    }

    if (!await _requestPermissions()) {
      log('Bluetooth scan permissions denied.');
      return;
    }
    if (await FlutterBluePlus.adapterState.first != BluetoothAdapterState.on) {
      log('Bluetooth adapter is off.');
      return;
    }

    try {
      _lastScanStart = DateTime.now();
      _nearbyDevices.clear();
      notifyListeners();
      await FlutterBluePlus.startScan(
        timeout: _scanDuration,
        androidUsesFineLocation: true,
      );
    } catch (e) {
      log('Error starting BLE scan: $e');
    }
  }

  Future<void> stopScanning() async {
    try {
      await FlutterBluePlus.stopScan();
    } catch (e) {
      log('Error stopping BLE scan: $e');
    }
  }

  void _processScanResults(List<ScanResult> results) {
    bool updated = false;
    for (final result in results) {
      final name = result.advertisementData.advName;
      if (name.isEmpty || !name.startsWith(kBlePrefix)) continue;

      final username = name.substring(kBlePrefix.length);
      final deviceId = result.device.remoteId.str;
      final existingIndex = _nearbyDevices.indexWhere((d) => d.id == deviceId);

      if (existingIndex != -1) {
        if (_nearbyDevices[existingIndex].rssi != result.rssi) {
          _nearbyDevices[existingIndex] =
              NearbyDevice(id: deviceId, name: name, username: username, rssi: result.rssi);
          updated = true;
        }
      } else {
        _nearbyDevices.add(
            NearbyDevice(id: deviceId, name: name, username: username, rssi: result.rssi));
        updated = true;
      }
    }
    if (updated) {
      _nearbyDevices.sort((a, b) => b.rssi.compareTo(a.rssi));
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _scanResultsSub?.cancel();
    _isScanningSub?.cancel();
    super.dispose();
  }
}
