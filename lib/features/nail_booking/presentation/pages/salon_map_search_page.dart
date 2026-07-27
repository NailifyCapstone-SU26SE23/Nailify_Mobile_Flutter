import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:dio/dio.dart';
import '../../../../core/constants/app_colors.dart';

class SalonMapSearchPage extends StatefulWidget {
  final List<dynamic> salons;
  final Function(dynamic) onSalonSelected;

  const SalonMapSearchPage({
    super.key,
    required this.salons,
    required this.onSalonSelected,
  });

  @override
  State<SalonMapSearchPage> createState() => _SalonMapSearchPageState();
}

class _SalonMapSearchPageState extends State<SalonMapSearchPage> {
  final LatLng _customerLocation = const LatLng(10.8444, 106.8122);
  final MapController _mapController = MapController();

  dynamic _selectedSalon;
  List<LatLng> _routePoints = [];
  bool _isLoadingRoute = false;
  double _distanceKm = 0.0;
  int _durationMin = 0;

  // Helper to map salon names to mock coordinates surrounding customer
  LatLng _getSalonLatLng(dynamic salon) {
    final name = (salon['name']?.toString() ?? '').toLowerCase();
    if (name.contains('fpt') || name.contains('đại học fpt')) {
      return const LatLng(10.8411, 106.8099);
    } else if (name.contains('công nghệ cao') || name.contains('khu công')) {
      return const LatLng(10.8480, 106.8105);
    } else if (name.contains('thanhdt') || name.contains('nauythanhdt')) {
      return const LatLng(10.8455, 106.8150);
    } else if (name.contains('nauy')) {
      return const LatLng(10.8425, 106.8175);
    } else if (name.contains('quan 9') || name.contains('quận 9')) {
      return const LatLng(10.8395, 106.8120);
    } else if (name.contains('string')) {
      return const LatLng(10.8465, 106.8080);
    }
    // Fallback: slight random offset around customer location
    final int index = widget.salons.indexOf(salon);
    final double offsetLat = 0.003 * ((index % 3) - 1);
    final double offsetLng = 0.003 * (((index ~/ 3) % 3) - 1);
    return LatLng(
      _customerLocation.latitude + offsetLat,
      _customerLocation.longitude + offsetLng,
    );
  }

  // Get distance in Km between two coords (Manhattan calculation for visual placeholder fallback)
  double _calculateDirectDistance(LatLng start, LatLng end) {
    final double latDiff = (start.latitude - end.latitude).abs() * 111.0;
    final double lngDiff =
        (start.longitude - end.longitude).abs() * 111.0 * 0.98;
    return double.parse((latDiff + lngDiff).toStringAsFixed(1));
  }

  Future<void> _fetchRoute(LatLng endLoc) async {
    setState(() {
      _isLoadingRoute = true;
      _routePoints = [];
    });

    final start = _customerLocation;
    try {
      final dio = Dio();
      final url =
          'https://router.project-osrm.org/route/v1/driving/${start.longitude},${start.latitude};${endLoc.longitude},${endLoc.latitude}?overview=full&geometries=geojson';
      final response = await dio.get(url);

      if (response.statusCode == 200) {
        final data = response.data;
        if (data['routes'] != null && data['routes'].isNotEmpty) {
          final route = data['routes'][0];
          final geometry = route['geometry'];
          final coordinates = geometry['coordinates'] as List;

          final List<LatLng> points = coordinates.map((c) {
            return LatLng(c[1] as double, c[0] as double);
          }).toList();

          final double meters = (route['distance'] as num?)?.toDouble() ?? 0.0;
          final double seconds = (route['duration'] as num?)?.toDouble() ?? 0.0;

          if (mounted) {
            setState(() {
              _routePoints = points;
              _distanceKm = double.parse((meters / 1000).toStringAsFixed(1));
              _durationMin = (seconds / 60).round();
              _isLoadingRoute = false;
            });
          }
          return;
        }
      }
    } catch (e) {
      debugPrint('OSRM routing failed: $e');
    }

    // Fallback direct driving route simulator
    if (mounted) {
      final double directDist = _calculateDirectDistance(start, endLoc);
      setState(() {
        _distanceKm = directDist;
        _durationMin = (directDist * 3.5).round(); // ~20km/h average driving
        _routePoints = [
          start,
          LatLng(
            start.latitude + (endLoc.latitude - start.latitude) * 0.4,
            start.longitude,
          ),
          LatLng(
            start.latitude + (endLoc.latitude - start.latitude) * 0.4,
            endLoc.longitude,
          ),
          endLoc,
        ];
        _isLoadingRoute = false;
      });
    }
  }

  void _onMarkerTapped(dynamic salon) {
    setState(() {
      _selectedSalon = salon;
      _routePoints = [];
    });
    final latLng = _getSalonLatLng(salon);
    _mapController.move(latLng, 15.5);
    _fetchRoute(latLng);
  }

  @override
  Widget build(BuildContext context) {
    final LatLng selectedLoc = _selectedSalon != null
        ? _getSalonLatLng(_selectedSalon)
        : _customerLocation;

    return Scaffold(
      body: Stack(
        children: [
          // ── MAP ────────────────────────────────────────────────────────────
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _customerLocation,
              initialZoom: 14.5,
              maxZoom: 18.0,
              minZoom: 10.0,
            ),
            children: [
              TileLayer(
                urlTemplate:
                    'https://basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.nailify.app',
              ),
              if (_routePoints.isNotEmpty)
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: _routePoints,
                      color: AppColors.primary,
                      strokeWidth: 5.0,
                    ),
                  ],
                ),
              MarkerLayer(
                markers: [
                  // Customer Marker
                  Marker(
                    point: _customerLocation,
                    width: 60,
                    height: 60,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Container(
                          width: 30,
                          height: 30,
                          decoration: BoxDecoration(
                            color: Colors.blue.withOpacity(0.2),
                            shape: BoxShape.circle,
                          ),
                        ),
                        Container(
                          width: 14,
                          height: 14,
                          decoration: BoxDecoration(
                            color: Colors.blue,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Salons Markers
                  ...widget.salons.map((salon) {
                    final latLng = _getSalonLatLng(salon);
                    final isSelected =
                        _selectedSalon != null &&
                        _selectedSalon['salonId'] == salon['salonId'];

                    return Marker(
                      point: latLng,
                      width: 50,
                      height: 50,
                      child: GestureDetector(
                        onTap: () => _onMarkerTapped(salon),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 250),
                          curve: Curves.easeInOut,
                          child: Icon(
                            Icons.location_on_rounded,
                            size: isSelected ? 44 : 34,
                            color: isSelected
                                ? AppColors.primary
                                : AppColors.primaryDark.withOpacity(0.7),
                          ),
                        ),
                      ),
                    );
                  }),
                ],
              ),
            ],
          ),

          // ── TOP NAVIGATION BAR ─────────────────────────────────────────────
          Positioned(
            top: MediaQuery.of(context).padding.top + 10,
            left: 16,
            right: 16,
            child: Row(
              children: [
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.12),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.arrow_back_ios_new_rounded,
                      size: 18,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Container(
                    height: 50,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(25),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.12),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.search_rounded,
                          color: Colors.grey,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Tìm salon xung quanh bạn',
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ── BOTTOM SALON DETAIL WINDOW ─────────────────────────────────────
          Positioned(
            bottom: 24,
            left: 16,
            right: 16,
            child: _selectedSalon == null
                ? Container(
                    padding: const EdgeInsets.symmetric(
                      vertical: 14,
                      horizontal: 16,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.12),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.info_outline_rounded,
                          size: 16,
                          color: Colors.grey.shade600,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Nhấn vào ghim trên bản đồ để xem Salon',
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  )
                : Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.15),
                          blurRadius: 16,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // ── Salon Photo (if available) ──
                            if (_selectedSalon['imageUrl'] != null ||
                                _selectedSalon['avatarUrl'] != null ||
                                _selectedSalon['image'] != null) ...[
                              ClipRRect(
                                borderRadius: BorderRadius.circular(16),
                                child: Image.network(
                                  _selectedSalon['imageUrl'] ??
                                      _selectedSalon['avatarUrl'] ??
                                      _selectedSalon['image'],
                                  width: 80,
                                  height: 80,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, _, _) =>
                                      const SizedBox.shrink(),
                                ),
                              ),
                              const SizedBox(width: 14),
                            ],
                            // ── Detail Details ──
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Text(
                                          _selectedSalon['name'] ?? '',
                                          style: const TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                            color: AppColors.textPrimary,
                                          ),
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.green.shade50,
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                          border: Border.all(
                                            color: Colors.green.shade200,
                                            width: 0.8,
                                          ),
                                        ),
                                        child: Text(
                                          _selectedSalon['status']
                                                  ?.toString() ??
                                              'Hoạt động',
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.green.shade800,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      const Icon(
                                        Icons.location_on_rounded,
                                        size: 14,
                                        color: AppColors.primary,
                                      ),
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: Text(
                                          _selectedSalon['address'] ?? '',
                                          style: TextStyle(
                                            color: Colors.grey.shade600,
                                            fontSize: 13,
                                            height: 1.3,
                                          ),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      const Icon(
                                        Icons.phone_rounded,
                                        size: 14,
                                        color: Colors.grey,
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        _selectedSalon['phone']?.toString() ??
                                            '090 123 4567',
                                        style: TextStyle(
                                          color: Colors.grey.shade600,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ],
                                  ),
                                  // ── Auto distance & duration ──
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      const Icon(
                                        Icons.directions_car_rounded,
                                        size: 14,
                                        color: AppColors.primary,
                                      ),
                                      const SizedBox(width: 6),
                                      if (_isLoadingRoute)
                                        const SizedBox(
                                          width: 12,
                                          height: 12,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 1.5,
                                            color: AppColors.primary,
                                          ),
                                        )
                                      else
                                        Text(
                                          _routePoints.isNotEmpty
                                              ? '$_distanceKm km - $_durationMin phút đi xe'
                                              : 'Đang tải thông tin đường đi...',
                                          style: const TextStyle(
                                            color: AppColors.textPrimary,
                                            fontSize: 13,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // Action Buttons
                        Row(
                          children: [
                            if (_routePoints.isEmpty && _isLoadingRoute)
                              const Expanded(
                                child: SizedBox(
                                  height: 48,
                                  child: Center(
                                    child: CircularProgressIndicator(
                                      color: AppColors.primary,
                                    ),
                                  ),
                                ),
                              )
                            else ...[
                              if (_routePoints.isNotEmpty) ...[
                                Expanded(
                                  child: SizedBox(
                                    height: 48,
                                    child: OutlinedButton(
                                      onPressed: () =>
                                          setState(() => _routePoints = []),
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: AppColors.textPrimary,
                                        side: BorderSide(
                                          color: Colors.grey.shade300,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            16,
                                          ),
                                        ),
                                      ),
                                      child: const Text(
                                        'Ẩn đường đi',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                              ],
                              Expanded(
                                child: SizedBox(
                                  height: 48,
                                  child: ElevatedButton(
                                    onPressed: () {
                                      widget.onSalonSelected(_selectedSalon);
                                      Navigator.pop(context);
                                    },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppColors.primary,
                                      foregroundColor: Colors.white,
                                      elevation: 0,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                    ),
                                    child: const Text(
                                      'Đặt lịch tại đây',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
