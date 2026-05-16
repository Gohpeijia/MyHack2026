import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

// Handles web vs native geolocator APIs dynamically
import 'map_web.dart' if (dart.library.io) 'map_native.dart';

// ─── SAVED PLACE DATA MODEL ──────────────────────────────────────────────────
class SavedPlace {
  final String id;
  final String label;
  final String description; // 🔼 Added description field
  final String searchedAddress;
  final LatLng latLng;
  final IconData icon;
  final Color color;

  SavedPlace({
    required this.id,
    required this.label,
    required this.description,
    required this.searchedAddress,
    required this.latLng,
    required this.icon,
    required this.color,
  });
}

// ─── MAIN MAP PAGE ───────────────────────────────────────────────────────────
class MapPage extends StatefulWidget {
  const MapPage({super.key});

  @override
  State<MapPage> createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> {
  final MapController _mapController = MapController();

  LatLng _currentLatLng = const LatLng(3.1073, 101.6067); 
  String _addressLine = 'Locating area…';
  bool _loading = true;
  bool _followUser = true;

  // Track user-saved locations
  final List<SavedPlace> _savedPlaces = [
    SavedPlace(
      id: '1',
      label: 'Sunway University',
      description: 'Campus and main library',
      searchedAddress: 'Sunway University, Jalan Universiti, Bandar Sunway',
      latLng: const LatLng(3.0648, 101.6036),
      icon: Icons.school_rounded,
      color: const Color(0xFF9B59B6),
    ),
  ];

  @override
  void initState() {
    super.initState();
    _initLocation();
  }

  Future<void> _initLocation() async {
    await LocationService.getPosition(
      onPosition: (lat, lng) async {
        await _updatePosition(LatLng(lat, lng));
      },
      onStream: (stream) {
        stream.listen((pos) async {
          await _updatePosition(LatLng(pos.$1, pos.$2));
        });
      },
      onError: () {
        if (mounted) {
          setState(() {
            _addressLine = 'Location permissions denied / unavailable';
            _loading = false;
          });
        }
      },
    );
  }

  Future<void> _updatePosition(LatLng latlng) async {
    String address = '${latlng.latitude.toStringAsFixed(5)}, ${latlng.longitude.toStringAsFixed(5)}';
    try {
      final url = Uri.parse(
        'https://nominatim.openstreetmap.org/reverse?lat=${latlng.latitude}&lon=${latlng.longitude}&format=json&addressdetails=1',
      );
      final response = await http.get(url, headers: {
        'User-Agent': 'CareConnectApp/1.0',
        'Accept-Language': 'en',
      });
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final addr = data['address'] as Map<String, dynamic>;
        final parts = [
          addr['road'],
          addr['suburb'] ?? addr['neighbourhood'],
          addr['city'] ?? addr['town'] ?? addr['village'],
        ].where((s) => s != null && (s as String).isNotEmpty).toList();
        if (parts.isNotEmpty) address = parts.join(', ');
      }
    } catch (_) {}

    if (!mounted) return;
    setState(() {
      _currentLatLng = latlng;
      _addressLine = address;
      _loading = false;
    });

    if (_followUser) {
      _mapController.move(latlng, _mapController.camera.zoom);
    }
  }

  void _centerOnUser() {
    _mapController.move(_currentLatLng, 16.0);
    setState(() => _followUser = true);
  }

  Future<LatLng?> _geocodeTypedAddress(String locationName) async {
    try {
      final encodedQuery = Uri.encodeComponent(locationName);
      final url = Uri.parse('https://nominatim.openstreetmap.org/search?q=$encodedQuery&format=json&limit=1');
      
      final response = await http.get(url, headers: {
        'User-Agent': 'CareConnectApp/1.0',
        'Accept-Language': 'en',
      });

      if (response.statusCode == 200) {
        final results = jsonDecode(response.body) as List;
        if (results.isNotEmpty) {
          final double lat = double.parse(results[0]['lat']);
          final double lon = double.parse(results[0]['lon']);
          return LatLng(lat, lon);
        }
      }
    } catch (_) {}
    return null;
  }

  // ─── Dialog: Type Address & Save Place ─────────────────────────────────────
  void _showAddPlaceDialog() {
    final labelCtrl = TextEditingController();
    final descCtrl = TextEditingController(); // 🔼 Description controller
    final addressCtrl = TextEditingController();
    
    bool isSearchingLocation = false;
    String errorMessage = '';
    IconData selectedIcon = Icons.home_rounded;
    Color selectedColor = const Color(0xFF4A90D9);

    final List<Map<String, dynamic>> iconOptions = [
      {'icon': Icons.home_rounded, 'label': 'Home'},
      {'icon': Icons.work_rounded, 'label': 'Work'},
      {'icon': Icons.local_hospital_rounded, 'label': 'Clinic'},
      {'icon': Icons.star_rounded, 'label': 'Favorite'},
    ];

    final List<Color> colorOptions = [
      const Color(0xFF4A90D9),
      const Color(0xFF2ECC8A),
      const Color(0xFFE74C3C),
      const Color(0xFF9B59B6),
      const Color(0xFFF39C12),
    ];

    showDialog(
      context: context,
      barrierDismissible: !isSearchingLocation,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: Colors.white,
              title: const Text('Add Saved Place', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: labelCtrl,
                      decoration: const InputDecoration(labelText: 'Label Name', hintText: 'e.g. Home, Grandma Clinic'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: descCtrl,
                      decoration: const InputDecoration(labelText: 'Description (Optional)', hintText: 'e.g. Call before arriving'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: addressCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Search Location Address',
                        hintText: 'e.g. Sunway Pyramid Mall',
                        suffixIcon: Icon(Icons.search_rounded, size: 20),
                      ),
                    ),
                    
                    if (errorMessage.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Text(errorMessage, style: const TextStyle(color: Color(0xFFE74C3C), fontSize: 12, fontWeight: FontWeight.w500)),
                    ],

                    const SizedBox(height: 24),
                    const Text('Select Icon:', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF9999AA))),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: iconOptions.map((opt) {
                        final icon = opt['icon'] as IconData;
                        final isSelected = selectedIcon == icon;
                        return GestureDetector(
                          onTap: () => setDialogState(() => selectedIcon = icon),
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: isSelected ? selectedColor.withOpacity(0.15) : Colors.grey[100],
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: isSelected ? selectedColor : Colors.transparent, width: 2),
                            ),
                            child: Icon(icon, color: isSelected ? selectedColor : Colors.grey[600], size: 24),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 24),
                    const Text('Select Color:', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF9999AA))),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: colorOptions.map((color) {
                        return GestureDetector(
                          onTap: () => setDialogState(() => selectedColor = color),
                          child: Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: color,
                              shape: BoxShape.circle,
                              border: Border.all(color: selectedColor == color ? Colors.black87 : Colors.transparent, width: 2.5),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(onPressed: isSearchingLocation ? null : () => Navigator.pop(context), child: const Text('Cancel')),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF4A90D9), foregroundColor: Colors.white),
                  onPressed: isSearchingLocation
                      ? null
                      : () async {
                          if (labelCtrl.text.isEmpty || addressCtrl.text.isEmpty) {
                            setDialogState(() => errorMessage = 'Please enter a label and address.');
                            return;
                          }

                          setDialogState(() {
                            isSearchingLocation = true;
                            errorMessage = '';
                          });

                          final resolvedLatLng = await _geocodeTypedAddress(addressCtrl.text);

                          if (resolvedLatLng != null) {
                            setState(() {
                              _savedPlaces.add(SavedPlace(
                                id: DateTime.now().toString(),
                                label: labelCtrl.text,
                                description: descCtrl.text,
                                searchedAddress: addressCtrl.text,
                                latLng: resolvedLatLng,
                                icon: selectedIcon,
                                color: selectedColor,
                              ));
                              _followUser = false;
                            });
                            
                            _mapController.move(resolvedLatLng, 16.0);
                            if (context.mounted) Navigator.pop(context);
                          } else {
                            setDialogState(() {
                              isSearchingLocation = false;
                              errorMessage = 'Could not find address. Try being more specific.';
                            });
                          }
                        },
                  child: isSearchingLocation
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text('Find & Save'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // ─── BOTTOM SHEET FOR PLACE DETAILS ────────────────────────────────────────
  void _showPlaceDetails(SavedPlace place) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min, // Hugs the content tightly
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Drag handle
              Center(
                child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2))),
              ),
              const SizedBox(height: 24),
              
              // Header Row: Icon + Name + Description
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(color: place.color.withOpacity(0.15), borderRadius: BorderRadius.circular(16)),
                    child: Icon(place.icon, color: place.color, size: 32),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          place.label, 
                          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF1A1A2E))
                        ),
                        if (place.description.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            place.description, 
                            style: TextStyle(fontSize: 14, color: Colors.grey[600], fontWeight: FontWeight.w500)
                          ),
                        ]
                      ],
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 20),
              const Divider(),
              const SizedBox(height: 16),

              // Address Row
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.location_on_outlined, color: Colors.grey, size: 22),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      place.searchedAddress, 
                      style: const TextStyle(fontSize: 14, height: 1.4, color: Color(0xFF1A1A2E))
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 28),

              // Action Buttons Panel (Directions removed)
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        side: BorderSide(color: Colors.grey[300]!)
                      ),
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Close', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF1A1A2E))),
                    ),
                  ),
                ],
              )
            ],
          ),
        );
      }
    );
  }

  // ─── Sliding Tray: Open Saved List Menu ────────────────────────────────────
  void _showSavedPlacesSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2))),
                  ),
                  const SizedBox(height: 16),
                  const Text('Saved Places Directory', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1A1A2E))),
                  const SizedBox(height: 12),
                  _savedPlaces.isEmpty
                      ? const Padding(
                          padding: EdgeInsets.symmetric(vertical: 32),
                          child: Center(child: Text('No saved places yet.', style: TextStyle(color: Colors.grey))),
                        )
                      : Flexible(
                          child: ListView.builder(
                            shrinkWrap: true,
                            itemCount: _savedPlaces.length,
                            itemBuilder: (context, index) {
                              final place = _savedPlaces[index];
                              return ListTile(
                                contentPadding: EdgeInsets.zero,
                                leading: Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(color: place.color.withOpacity(0.12), borderRadius: BorderRadius.circular(12)),
                                  child: Icon(place.icon, color: place.color, size: 22),
                                ),
                                title: Text(place.label, style: const TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF1A1A2E))),
                                subtitle: Text(place.searchedAddress, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: Colors.grey[500], fontSize: 12)),
                                trailing: IconButton(
                                  icon: const Icon(Icons.delete_outline_rounded, color: Color(0xFFE74C3C)),
                                  onPressed: () {
                                    setState(() => _savedPlaces.removeAt(index));
                                    setSheetState(() {}); 
                                  },
                                ),
                                onTap: () {
                                  Navigator.pop(context);
                                  setState(() => _followUser = false);
                                  _mapController.move(place.latLng, 16.0);
                                  
                                  // Optionally auto-open the details card when tapped from the list
                                  Future.delayed(const Duration(milliseconds: 300), () => _showPlaceDetails(place));
                                },
                              );
                            },
                          ),
                        ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          _AddressBar(address: _addressLine, loading: _loading),
          Expanded(
            child: Stack(
              children: [
                FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: _currentLatLng,
                    initialZoom: 15.5,
                    onPositionChanged: (_, hasGesture) {
                      if (hasGesture && _followUser) {
                        setState(() => _followUser = false);
                      }
                    },
                  ),
                  children: [
                    TileLayer(
                      urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.careconnect.app',
                      maxZoom: 19,
                    ),
                    
                    MarkerLayer(
                      markers: [
                        // Live location user pulsing dot
                        Marker(
                          point: _currentLatLng,
                          width: 60,
                          height: 60,
                          child: const _PulsingMarker(),
                        ),
                        
                        // 🔼 Map pinned saved markers
                        ..._savedPlaces.map((place) {
                          return Marker(
                            point: place.latLng,
                            width: 50,  
                            height: 50,
                            child: GestureDetector(
                              onTap: () => _showPlaceDetails(place), 
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  shape: BoxShape.circle,
                                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 6, offset: const Offset(0, 2))],
                                ),
                                child: Icon(place.icon, color: place.color, size: 26),
                              ),
                            ),
                          );
                        }),
                      ],
                    ),
                  ],
                ),

                // Control Menu Layout Panel
                Positioned(
                  top: 16,
                  right: 16,
                  child: Column(
                    children: [
                      _MapButton(
                        icon: Icons.add_location_alt_rounded,
                        onTap: _showAddPlaceDialog,
                        tooltip: 'Type and add place',
                        color: Colors.white,
                        iconColor: const Color(0xFF4A90D9),
                      ),
                      const SizedBox(height: 10),
                      _MapButton(
                        icon: Icons.folder_special_rounded,
                        onTap: _showSavedPlacesSheet,
                        tooltip: 'Open saved directory',
                        color: Colors.white,
                        iconColor: const Color(0xFF1A1A2E),
                      ),
                    ],
                  ),
                ),

                // Device geolocation re-center FAB
                Positioned(
                  bottom: 20,
                  right: 16,
                  child: _MapButton(
                    icon: _followUser ? Icons.my_location_rounded : Icons.location_searching_rounded,
                    onTap: _centerOnUser,
                    tooltip: 'My location',
                    color: _followUser ? const Color(0xFF4A90D9) : Colors.white,
                    iconColor: _followUser ? Colors.white : const Color(0xFF4A90D9),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── ADDRESS BAR WIDGET (With larger text/icons) ─────────────────────────────
class _AddressBar extends StatelessWidget {
  final String address;
  final bool loading;
  const _AddressBar({required this.address, required this.loading});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Container(
        width: double.infinity,
        color: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18), 
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFF4A90D9).withOpacity(0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.location_on_rounded, color: Color(0xFF4A90D9), size: 26),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Text(
                        'Current Location',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF9999AA), letterSpacing: 0.3),
                      ),
                      if (loading) ...[
                        const SizedBox(width: 8),
                        const SizedBox(
                          width: 12,
                          height: 12,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF4A90D9)),
                        )
                      ]
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    address,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF1A1A2E)),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── ACTION PANEL CONTROL BUTTONS (Larger Size) ──────────────────────────────
class _MapButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final String tooltip;
  final Color color;
  final Color iconColor;

  const _MapButton({
    required this.icon,
    required this.onTap,
    required this.tooltip,
    this.color = Colors.white,
    this.iconColor = const Color(0xFF1A1A2E),
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.14), blurRadius: 12, offset: const Offset(0, 4)),
            ],
          ),
          child: Icon(icon, color: iconColor, size: 28),
        ),
      ),
    );
  }
}

// ─── PULSING LIVE DOT MARKER ─────────────────────────────────────────────────
class _PulsingMarker extends StatefulWidget {
  const _PulsingMarker();
  @override
  State<_PulsingMarker> createState() => _PulsingMarkerState();
}

class _PulsingMarkerState extends State<_PulsingMarker> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;
  late final Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400))..repeat();
    _scale = Tween<double>(begin: 0.5, end: 1.0).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
    _opacity = Tween<double>(begin: 0.6, end: 0.0).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        AnimatedBuilder(
          animation: _ctrl,
          builder: (_, __) => Opacity(
            opacity: _opacity.value,
            child: Transform.scale(
              scale: _scale.value,
              child: Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(color: const Color(0xFF4A90D9).withOpacity(0.3), shape: BoxShape.circle),
              ),
            ),
          ),
        ),
        Container(
          width: 20,
          height: 20,
          decoration: BoxDecoration(
            color: const Color(0xFF4A90D9),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 3),
            boxShadow: [BoxShadow(color: const Color(0xFF4A90D9).withOpacity(0.5), blurRadius: 8, offset: const Offset(0, 2))],
          ),
        ),
      ],
    );
  }
}