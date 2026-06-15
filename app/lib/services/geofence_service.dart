import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import '../utils/logger.dart';

class GymLocation {
  final String id;
  final String name;
  final double latitude;
  final double longitude;
  final double radius; // metres

  GymLocation({
    required this.id,
    required this.name,
    required this.latitude,
    required this.longitude,
    this.radius = 100.0,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'latitude': latitude,
        'longitude': longitude,
        'radius': radius,
      };

  factory GymLocation.fromJson(Map<String, dynamic> json) => GymLocation(
        id: json['id'],
        name: json['name'],
        latitude: (json['latitude'] as num).toDouble(),
        longitude: (json['longitude'] as num).toDouble(),
        radius: (json['radius'] as num?)?.toDouble() ?? 100.0,
      );
}

class GeofenceService extends ChangeNotifier {
  static const _prefsKey = 'p2ptalk_gyms';
  static const _legacyPrefsKey = 'gymtalk_gyms';

  final List<GymLocation> _gyms = [];
  GymLocation? _currentGym;
  Position? _currentPosition;
  StreamSubscription<Position>? _positionStreamSub;
  bool _isMonitoring = false;

  Function(GymLocation gym)? onEnterGym;
  Function(GymLocation gym)? onExitGym;

  List<GymLocation> get gyms => _gyms;
  GymLocation? get currentGym => _currentGym;
  Position? get currentPosition => _currentPosition;
  bool get isMonitoring => _isMonitoring;

  Future<void> init() async {
    await loadGyms();
    await checkCurrentLocation();
  }

  Future<void> loadGyms() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      var list = prefs.getStringList(_prefsKey);
      // One-time migration from the old GymTalk key.
      if (list == null) {
        final legacy = prefs.getStringList(_legacyPrefsKey);
        if (legacy != null) {
          await prefs.setStringList(_prefsKey, legacy);
          await prefs.remove(_legacyPrefsKey);
          list = legacy;
        }
      }
      _gyms
        ..clear()
        ..addAll((list ?? []).map((i) => GymLocation.fromJson(jsonDecode(i))));
      notifyListeners();
      log('Loaded ${_gyms.length} gym locations.');
    } catch (e) {
      log('Error loading gyms: $e');
    }
  }

  Future<void> saveGyms() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_prefsKey, _gyms.map((g) => jsonEncode(g.toJson())).toList());
    } catch (e) {
      log('Error saving gyms: $e');
    }
  }

  Future<bool> addGym(String name, double latitude, double longitude, {double radius = 100.0}) async {
    try {
      _gyms.add(GymLocation(
        id: 'gym_${DateTime.now().millisecondsSinceEpoch}',
        name: name,
        latitude: latitude,
        longitude: longitude,
        radius: radius,
      ));
      await saveGyms();
      notifyListeners();
      await checkCurrentLocation();
      return true;
    } catch (e) {
      log('Error adding gym: $e');
      return false;
    }
  }

  Future<void> removeGym(String id) async {
    _gyms.removeWhere((g) => g.id == id);
    await saveGyms();
    if (_currentGym?.id == id) _currentGym = null;
    notifyListeners();
  }

  Future<void> checkCurrentLocation() async {
    try {
      if (!await _handlePermission()) return;
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.medium),
      );
      _updatePosition(position);
    } catch (e) {
      log('Error getting current location: $e');
    }
  }

  Future<void> startMonitoring() async {
    if (_isMonitoring) return;
    if (!await _handlePermission()) return;

    // Battery-friendly: balanced accuracy + 25m filter is plenty for a ~100m
    // gym geofence, and keeps the GPS chip from running continuously.
    const locationSettings = LocationSettings(
      accuracy: LocationAccuracy.medium,
      distanceFilter: 25,
    );
    _positionStreamSub =
        Geolocator.getPositionStream(locationSettings: locationSettings).listen(_updatePosition);
    _isMonitoring = true;
    notifyListeners();
    log('Started geofence monitoring.');
  }

  void stopMonitoring() {
    _positionStreamSub?.cancel();
    _positionStreamSub = null;
    _isMonitoring = false;
    notifyListeners();
    log('Stopped geofence monitoring.');
  }

  void _updatePosition(Position position) {
    _currentPosition = position;

    GymLocation? detectedGym;
    for (final gym in _gyms) {
      final distance = Geolocator.distanceBetween(
          position.latitude, position.longitude, gym.latitude, gym.longitude);
      if (distance <= gym.radius) {
        detectedGym = gym;
        break;
      }
    }

    if (detectedGym != null && _currentGym?.id != detectedGym.id) {
      _currentGym = detectedGym;
      notifyListeners();
      log('Entered gym: ${detectedGym.name}');
      onEnterGym?.call(detectedGym);
    } else if (detectedGym == null && _currentGym != null) {
      final exited = _currentGym!;
      _currentGym = null;
      notifyListeners();
      log('Exited gym: ${exited.name}');
      onExitGym?.call(exited);
    } else {
      notifyListeners();
    }
  }

  Future<bool> _handlePermission() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      log('Location services disabled.');
      return false;
    }
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        log('Location permission denied.');
        return false;
      }
    }
    if (permission == LocationPermission.deniedForever) {
      log('Location permission permanently denied.');
      return false;
    }
    return true;
  }

  /// Push the current position + gym to the server (authenticated).
  Future<void> syncLocationWithServer(String apiBaseUrl, String accountId, String? token) async {
    if (_currentPosition == null || token == null) return;
    try {
      final res = await http
          .post(
            Uri.parse('$apiBaseUrl/api/users/$accountId/location'),
            headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $token'},
            body: jsonEncode({
              'latitude': _currentPosition!.latitude,
              'longitude': _currentPosition!.longitude,
              'gym_id': _currentGym?.id,
            }),
          )
          .timeout(const Duration(seconds: 10));
      if (res.statusCode == 200) {
        log('Synced location with server.');
      } else {
        log('Location sync failed: ${res.statusCode}');
      }
    } catch (e) {
      log('Error syncing location: $e');
    }
  }

  @override
  void dispose() {
    _positionStreamSub?.cancel();
    super.dispose();
  }
}
