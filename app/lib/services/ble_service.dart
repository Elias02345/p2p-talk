import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter_ble_peripheral/flutter_ble_peripheral.dart';
import 'package:permission_handler/permission_handler.dart';
import '../utils/logger.dart';

/// BLE advertised name prefix used to discover nearby p2p-talk users.
const String kBlePrefix = 'p2ptalk_';

/// Fixed app service UUID so peers can filter scans by UUID (robust on iOS,
/// where the custom local name is not reliably advertised).
const String kP2pTalkServiceUuid = '7b2dca10-9b2f-4f1e-9b6a-70747032702d';

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
  bool _isAdvertising = false;
  StreamSubscription<List<ScanResult>>? _scanResultsSub;
  StreamSubscription<bool>? _isScanningSub;
  DateTime? _lastScanStart;
  final FlutterBlePeripheral _peripheral = FlutterBlePeripheral();

  // Debounce: ignore repeated scan requests within this window to save battery
  // (geofence triggers can otherwise oscillate at a gym boundary).
  static const Duration _scanDebounce = Duration(seconds: 30);
  static const Duration _scanDuration = Duration(seconds: 8);

  List<NearbyDevice> get nearbyDevices => _nearbyDevices;
  bool get isScanning => _isScanning;
  bool get isAdvertising => _isAdvertising;

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

  Future<void> startScanning({bool force = false, String? advertiseAs}) async {
    // Make THIS phone discoverable too — otherwise two phones only ever scan and
    // never see each other (the core "no peers nearby" bug).
    if (advertiseAs != null) await startAdvertising(advertiseAs);
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
    await stopAdvertising();
  }

  /// Advertise this device so nearby p2p-talk phones can discover it. Without
  /// this, two phones would only ever scan and never find each other.
  Future<void> startAdvertising(String username) async {
    if (_isAdvertising) return;
    try {
      if (!await _peripheral.isSupported) {
        log('BLE peripheral/advertising not supported on this device.');
        return;
      }
      final data = AdvertiseData(
        serviceUuid: kP2pTalkServiceUuid,
        localName: '$kBlePrefix$username',
      );
      await _peripheral.start(advertiseData: data);
      _isAdvertising = true;
      notifyListeners();
      log('BLE advertising as $kBlePrefix$username');
    } catch (e) {
      log('Error starting BLE advertising: $e');
    }
  }

  Future<void> stopAdvertising() async {
    if (!_isAdvertising) return;
    try {
      await _peripheral.stop();
    } catch (e) {
      log('Error stopping BLE advertising: $e');
    }
    _isAdvertising = false;
    notifyListeners();
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
    stopAdvertising();
    super.dispose();
  }
}
