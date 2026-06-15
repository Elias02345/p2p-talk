import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../l10n/app_localizations.dart';
import '../services/geofence_service.dart';

class LocationsScreen extends StatefulWidget {
  const LocationsScreen({super.key});

  @override
  State<LocationsScreen> createState() => _LocationsScreenState();
}

class _LocationsScreenState extends State<LocationsScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _radiusController = TextEditingController(text: '100');

  static const darkBg = Color(0xFF0F111A);
  static const cardBg = Color(0xFF181C2E);
  static const neonCyan = Color(0xFF00E5FF);
  static const textGray = Color(0xFF9094A6);

  @override
  void dispose() {
    _nameController.dispose();
    _radiusController.dispose();
    super.dispose();
  }

  Future<void> _addCurrentLocation(GeofenceService geofence, AppLocalizations t) async {
    await geofence.checkCurrentLocation();
    final pos = geofence.currentPosition;
    if (pos == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t.locationsPermissionDenied)));
      return;
    }
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: cardBg,
        title: Text(t.locationsAddCurrent, style: const TextStyle(color: Colors.white, fontSize: 16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _nameController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: t.locationsGymName,
                labelStyle: const TextStyle(color: textGray),
                enabledBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: neonCyan)),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _radiusController,
              style: const TextStyle(color: Colors.white),
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: t.locationsRadius,
                labelStyle: const TextStyle(color: textGray),
                enabledBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: neonCyan)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(t.cancel, style: const TextStyle(color: textGray))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: neonCyan, foregroundColor: darkBg),
            onPressed: () async {
              final name = _nameController.text.trim();
              final radius = double.tryParse(_radiusController.text) ?? 100.0;
              if (name.isNotEmpty) {
                await geofence.addGym(name, pos.latitude, pos.longitude, radius: radius);
                _nameController.clear();
                if (ctx.mounted) Navigator.pop(ctx);
              }
            },
            child: Text(t.locationsAdd),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final geofence = Provider.of<GeofenceService>(context);

    return Scaffold(
      backgroundColor: darkBg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(t.locationsTitle, style: const TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(t.locationsBackgroundMonitoring, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      Switch(
                        value: geofence.isMonitoring,
                        activeThumbColor: neonCyan,
                        onChanged: (val) => val ? geofence.startMonitoring() : geofence.stopMonitoring(),
                      ),
                    ],
                  ),
                  const Divider(color: Colors.white12),
                  const SizedBox(height: 8),
                  Text(t.locationsCurrentPosition, style: const TextStyle(color: textGray, fontSize: 12)),
                  const SizedBox(height: 4),
                  Text(
                    geofence.currentPosition != null
                        ? 'Lat: ${geofence.currentPosition!.latitude.toStringAsFixed(6)}, Lon: ${geofence.currentPosition!.longitude.toStringAsFixed(6)}'
                        : t.locationsNoPosition,
                    style: const TextStyle(color: Colors.white70, fontSize: 13, fontFamily: 'monospace'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: neonCyan,
                foregroundColor: darkBg,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              icon: const Icon(Icons.add_location_alt),
              label: Text(t.locationsAddCurrent, style: const TextStyle(fontWeight: FontWeight.bold)),
              onPressed: () => _addCurrentLocation(geofence, t),
            ),
            const SizedBox(height: 24),
            Expanded(
              child: geofence.gyms.isEmpty
                  ? Center(child: Text(t.locationsNoGyms, style: const TextStyle(color: textGray, fontSize: 13), textAlign: TextAlign.center))
                  : ListView.builder(
                      itemCount: geofence.gyms.length,
                      itemBuilder: (context, index) {
                        final gym = geofence.gyms[index];
                        final isHere = geofence.currentGym?.id == gym.id;
                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: cardBg,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: isHere ? neonCyan.withValues(alpha: 0.4) : Colors.transparent),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Flexible(child: Text(gym.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15))),
                                        if (isHere) ...[
                                          const SizedBox(width: 8),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(color: neonCyan.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(6)),
                                            child: Text(t.locationsHere, style: const TextStyle(color: neonCyan, fontSize: 9, fontWeight: FontWeight.bold)),
                                          ),
                                        ],
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      '${t.locationsRadiusLabel(gym.radius.toInt().toString())} · ${gym.latitude.toStringAsFixed(4)}, ${gym.longitude.toStringAsFixed(4)}',
                                      style: const TextStyle(color: textGray, fontSize: 12),
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                                onPressed: () => geofence.removeGym(gym.id),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
