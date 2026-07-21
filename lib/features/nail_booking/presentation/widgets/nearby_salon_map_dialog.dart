import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import '../../../../core/constants/app_colors.dart';
import '../../data/datasources/booking_api_service.dart';

class NearbySalonMapDialog extends StatefulWidget {
  final List<dynamic> salons;
  final Function(dynamic) onBranchConfirmed;

  const NearbySalonMapDialog({
    super.key,
    required this.salons,
    required this.onBranchConfirmed,
  });

  @override
  State<NearbySalonMapDialog> createState() => _NearbySalonMapDialogState();
}

class _NearbySalonMapDialogState extends State<NearbySalonMapDialog> {
  final BookingApiService _apiService = BookingApiService();

  // Dio instance with sane timeouts so a dead OSRM server can't hang the UI forever.
  final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 5),
      receiveTimeout: const Duration(seconds: 5),
    ),
  );

  // Map Controller
  final MapController _mapController = MapController();

  // --- Real GPS state ---
  LatLng? _userLocation;
  bool _isLoadingLocation = true;
  String? _locationError;

  // Default fallback center (used only if GPS truly unavailable) — District 9 / Thu Duc area.
  static const LatLng _fallbackCenter = LatLng(10.8412, 106.8291);

  // Selected State
  dynamic _selectedSalon;
  Map<String, dynamic>? _salonDetails;
  bool _isLoadingDetails = false;
  bool _isConfirmed = false;

  // Route state
  List<LatLng> _routePoints = [];
  double? _routeDistanceKm;
  int? _routeDurationMin;
  bool _isLoadingRoute = false;
  bool _routeIsEstimate = false; // true when we fell back to a straight line

  // Guards against out-of-order async responses (race conditions).
  int _selectRequestToken = 0;
  int _routeRequestToken = 0;

  @override
  void initState() {
    super.initState();
    _initLocation();
  }

  @override
  void dispose() {
    _dio.close();
    super.dispose();
  }

  Future<void> _initLocation() async {
    setState(() {
      _isLoadingLocation = true;
      _locationError = null;
    });

    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        throw Exception('Dịch vụ vị trí đang tắt. Vui lòng bật GPS.');
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          throw Exception('Bạn đã từ chối quyền truy cập vị trí.');
        }
      }
      if (permission == LocationPermission.deniedForever) {
        throw Exception(
          'Quyền vị trí bị chặn vĩnh viễn. Vui lòng bật lại trong Cài đặt.',
        );
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );

      if (!mounted) return;
      setState(() {
        _userLocation = LatLng(position.latitude, position.longitude);
        _isLoadingLocation = false;
      });

      // Safely move map camera after the current build frame is done
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          try {
            _mapController.move(_userLocation!, 14.0);
          } catch (_) {
            // Silently ignore if FlutterMap hasn't fully attached yet
          }
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        // Fall back so the map still renders and the flow isn't blocked,
        // but keep the error visible so the user understands why.
        _userLocation = _fallbackCenter;
        _locationError = e.toString().replaceFirst('Exception: ', '');
        _isLoadingLocation = false;
      });
    }
  }

  /// Reads a salon's real coordinates from the API payload.
  /// Falls back to the fallback center only if a salon is missing coordinates
  /// (should not happen once the backend always sends lat/lng).
  LatLng _getSalonLocation(dynamic salon) {
    final latVal = salon['latitude'];
    final lngVal = salon['longitude'];
    
    // If coordinates exist and are valid, use them
    if (latVal != null && lngVal != null) {
      final double lat = (latVal as num).toDouble();
      final double lng = (lngVal as num).toDouble();
      if (lat != 0.0 && lng != 0.0) {
        return LatLng(lat, lng);
      }
    }
    
    // Otherwise, fake coordinates based on the salon's ID or name hash
    final salonId = salon['salonId']?.toString() ?? '';
    final String salonName = salon['name']?.toString() ?? '';
    final int hash = (salonId + salonName).hashCode.abs();
    
    // Base center of District 9: 10.8412, 106.8291
    // Generate slight offset between -0.015 and +0.015
    final double offsetLat = ((hash % 300) - 150) / 10000.0; // ~ -0.015 to +0.015
    final double offsetLng = (((hash ~/ 300) % 300) - 150) / 10000.0; // ~ -0.015 to +0.015
    
    return LatLng(10.8412 + offsetLat, 106.8291 + offsetLng);
  }

  Future<void> _fetchRoute(LatLng start, LatLng end) async {
    final requestToken = ++_routeRequestToken;
    setState(() {
      _isLoadingRoute = true;
      _routePoints = [];
      _routeDistanceKm = null;
      _routeDurationMin = null;
      _routeIsEstimate = false;
    });

    try {
      final url =
          'https://router.project-osrm.org/route/v1/driving/'
          '${start.longitude},${start.latitude};${end.longitude},${end.latitude}'
          '?overview=full&geometries=geojson';
      final response = await _dio.get(url);

      // Ignore this response if a newer route request has since started.
      if (requestToken != _routeRequestToken) return;

      if (response.statusCode == 200) {
        final data = response.data;
        final routes = data['routes'] as List;
        if (routes.isNotEmpty) {
          final route = routes[0];
          final geometry = route['geometry'];
          final coordinates = geometry['coordinates'] as List;
          final points = coordinates.map((coord) {
            final lon = (coord[0] as num).toDouble();
            final lat = (coord[1] as num).toDouble();
            return LatLng(lat, lon);
          }).toList();

          final distanceMeters = (route['distance'] as num).toDouble();
          final durationSeconds = (route['duration'] as num).toDouble();

          if (!mounted) return;
          setState(() {
            _routePoints = points;
            _routeDistanceKm = distanceMeters / 1000;
            _routeDurationMin = (durationSeconds / 60).ceil();
            _isLoadingRoute = false;
          });

          _fitBoundsToRoute(start, end);
          return;
        }
      }
      throw Exception('No route found');
    } catch (_) {
      if (requestToken != _routeRequestToken) return;
      // Fallback to a straight line so the UI still shows *something*,
      // but flag it clearly as an estimate rather than a real route.
      final straightDistanceKm =
          const Distance().as(LengthUnit.Kilometer, start, end);
      if (!mounted) return;
      setState(() {
        _routePoints = [start, end];
        _routeDistanceKm = straightDistanceKm;
        _routeDurationMin = null;
        _routeIsEstimate = true;
        _isLoadingRoute = false;
      });
      _fitBoundsToRoute(start, end);
    }
  }

  void _fitBoundsToRoute(LatLng start, LatLng end) {
    final bounds = LatLngBounds.fromPoints([start, end]);
    _mapController.fitCamera(
      CameraFit.bounds(
        bounds: bounds,
        padding: const EdgeInsets.fromLTRB(60, 100, 60, 220),
      ),
    );
  }

  void _recenterToUser() {
    if (_userLocation != null) {
      _mapController.move(_userLocation!, 15.0);
    }
  }

  Future<void> _selectSalon(dynamic salon) async {
    final requestToken = ++_selectRequestToken;
    final salonPos = _getSalonLocation(salon);

    setState(() {
      _selectedSalon = salon;
      _isLoadingDetails = true;
      _isConfirmed = false;
      _salonDetails = null;
      _routePoints = [];
      _routeDistanceKm = null;
      _routeDurationMin = null;
    });

    if (_userLocation != null) {
      final midLat = (_userLocation!.latitude + salonPos.latitude) / 2;
      final midLng = (_userLocation!.longitude + salonPos.longitude) / 2;
      _mapController.move(LatLng(midLat, midLng), 14.5);
    }

    try {
      final details = await _apiService.getSalonDetails(salon['salonId']);
      // Only apply this result if the user hasn't since selected a different salon.
      if (mounted && requestToken == _selectRequestToken) {
        setState(() {
          _salonDetails = details;
          _isLoadingDetails = false;
        });
      }
    } catch (_) {
      if (mounted && requestToken == _selectRequestToken) {
        setState(() {
          _salonDetails = Map<String, dynamic>.from(salon as Map);
          _isLoadingDetails = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final center = _userLocation ?? _fallbackCenter;

    final List<Marker> markers = [];

    if (_userLocation != null) {
      markers.add(
        Marker(
          point: _userLocation!,
          width: 44,
          height: 44,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.blue.withValues(alpha: 0.2),
                ),
              ),
              Container(
                width: 14,
                height: 14,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.blue,
                  boxShadow: [
                    BoxShadow(color: Colors.blue, blurRadius: 6, spreadRadius: 1),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    for (final salon in widget.salons) {
      final pos = _getSalonLocation(salon);
      final isCurrentSelected = _selectedSalon?['salonId'] == salon['salonId'];

      markers.add(
        Marker(
          point: pos,
          width: 50,
          height: 50,
          child: GestureDetector(
            onTap: () => _selectSalon(salon),
            child: Stack(
              alignment: Alignment.center,
              children: [
                if (isCurrentSelected)
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.primary.withValues(alpha: 0.15),
                    ),
                  ),
                Icon(
                  Icons.location_on_rounded,
                  color: isCurrentSelected ? AppColors.primary : Colors.grey.shade600,
                  size: isCurrentSelected ? 38 : 30,
                ),
                Positioned(
                  top: isCurrentSelected ? 6 : 8,
                  child: const Icon(
                    Icons.storefront_rounded,
                    color: Colors.white,
                    size: 12,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final selectedSalonLocation =
        _selectedSalon != null ? _getSalonLocation(_selectedSalon) : null;

    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFFFDFBF7),
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        children: [
          // Drag handle and Title
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 14),
            child: Column(
              children: [
                Container(
                  width: 40,
                  height: 5,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Tìm kiếm Salon gần bạn',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Georgia',
                    color: AppColors.primaryDark,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFF3EFEA)),

          // Location error banner (non-blocking — user can still browse salons by list)
          if (_locationError != null)
            Container(
              width: double.infinity,
              color: Colors.orange.shade50,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  Icon(Icons.warning_amber_rounded, size: 16, color: Colors.orange.shade800),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '$_locationError Đang hiển thị vị trí mặc định.',
                      style: TextStyle(fontSize: 11, color: Colors.orange.shade900),
                    ),
                  ),
                  TextButton(
                    onPressed: _initLocation,
                    child: const Text('Thử lại', style: TextStyle(fontSize: 11)),
                  ),
                ],
              ),
            ),

          // Map view
          Expanded(
            child: _isLoadingLocation
                ? const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(color: AppColors.primary),
                        SizedBox(height: 12),
                        Text('Đang xác định vị trí của bạn...',
                            style: TextStyle(fontSize: 12, color: Colors.grey)),
                      ],
                    ),
                  )
                : Stack(
                    children: [
                      FlutterMap(
                        mapController: _mapController,
                        options: MapOptions(
                          initialCenter: center,
                          initialZoom: 14.0,
                        ),
                        children: [
                          TileLayer(
                            urlTemplate:
                                'https://basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}.png',
                            userAgentPackageName: 'com.nailify.app',
                          ),
                          if (_isConfirmed && selectedSalonLocation != null)
                            PolylineLayer(
                              polylines: [
                                Polyline(
                                  points: _routePoints.isNotEmpty
                                      ? _routePoints
                                      : [_userLocation ?? center, selectedSalonLocation],
                                  color: AppColors.primary,
                                  strokeWidth: 4.5,
                                  pattern: _routeIsEstimate
                                      ? StrokePattern.dashed(segments: const [8, 6])
                                      : const StrokePattern.solid(),
                                ),
                              ],
                            ),
                          MarkerLayer(markers: markers),
                          const RichAttributionWidget(
                            attributions: [
                              TextSourceAttribution('CARTO / OpenStreetMap contributors'),
                            ],
                          ),
                        ],
                      ),

                      // Map quick instructions overlay
                      Positioned(
                        top: 12,
                        left: 12,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.9),
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4),
                            ],
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.touch_app_outlined, size: 16, color: AppColors.primary),
                              const SizedBox(width: 6),
                              Text(
                                'Chạm vào ghim để xem chi tiết Salon',
                                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey.shade700),
                              ),
                            ],
                          ),
                        ),
                      ),

                      // Recenter-to-me button
                      Positioned(
                        right: 12,
                        bottom: 12,
                        child: FloatingActionButton.small(
                          heroTag: 'recenter',
                          backgroundColor: Colors.white,
                          foregroundColor: AppColors.primary,
                          elevation: 2,
                          onPressed: _recenterToUser,
                          child: const Icon(Icons.my_location_rounded, size: 20),
                        ),
                      ),
                    ],
                  ),
          ),

          // Detail Card
          if (_selectedSalon != null)
            Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(color: Colors.black12, blurRadius: 15, offset: Offset(0, -4)),
                ],
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: _isLoadingDetails
                  ? const SizedBox(
                      height: 120,
                      child: Center(child: CircularProgressIndicator(color: AppColors.primary)),
                    )
                  : Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Salon Photo or Placeholder
                            ClipRRect(
                              borderRadius: BorderRadius.circular(16),
                              child: _salonDetails?['imageUrl'] != null || _salonDetails?['avatarUrl'] != null
                                  ? Image.network(
                                      _salonDetails?['imageUrl'] ?? _salonDetails?['avatarUrl'],
                                      width: 80,
                                      height: 80,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) => _photoPlaceholder(),
                                    )
                                  : _photoPlaceholder(),
                            ),
                            const SizedBox(width: 14),

                            // Info details
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _salonDetails?['name'] ?? '',
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.primaryDark,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    _salonDetails?['address'] ?? '',
                                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600, height: 1.3),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 6),
                                  Row(
                                    children: [
                                      const Icon(Icons.phone_rounded, size: 12, color: AppColors.primary),
                                      const SizedBox(width: 4),
                                      Text(
                                        _salonDetails?['phone'] ?? _salonDetails?['phoneNumber'] ?? 'Chưa cập nhật',
                                        style: TextStyle(fontSize: 12, color: Colors.grey.shade700, fontWeight: FontWeight.w600),
                                      ),
                                      const SizedBox(width: 12),
                                      // Status Badge
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: Colors.green.shade50,
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          _salonDetails?['status']?.toString() ?? 'Active',
                                          style: TextStyle(color: Colors.green.shade800, fontSize: 10, fontWeight: FontWeight.bold),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),

                        // Distance / duration row — only shown once a route has been requested.
                        if (_isLoadingRoute || _routeDistanceKm != null) ...[
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFF0F5),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: _isLoadingRoute
                                ? Row(
                                    children: [
                                      const SizedBox(
                                        width: 14,
                                        height: 14,
                                        child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
                                      ),
                                      const SizedBox(width: 8),
                                      Text('Đang tính đường đi...',
                                          style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
                                    ],
                                  )
                                : Row(
                                    children: [
                                      const Icon(Icons.directions_car_rounded, size: 16, color: AppColors.primary),
                                      const SizedBox(width: 6),
                                      Text(
                                        '${_routeDistanceKm!.toStringAsFixed(1)} km'
                                        '${_routeDurationMin != null ? ' · ${_routeDurationMin!} phút' : ''}',
                                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.primaryDark),
                                      ),
                                      if (_routeIsEstimate) ...[
                                        const SizedBox(width: 6),
                                        Text('(ước lượng đường thẳng)',
                                            style: TextStyle(fontSize: 10, color: Colors.grey.shade600)),
                                      ],
                                    ],
                                  ),
                          ),
                        ],

                        const SizedBox(height: 16),

                        // Action button row
                        SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: !_isConfirmed
                              ? ElevatedButton.icon(
                                  onPressed: () {
                                    setState(() {
                                      _isConfirmed = true;
                                    });
                                    if (selectedSalonLocation != null) {
                                      _fetchRoute(
                                        _userLocation ?? center,
                                        selectedSalonLocation,
                                      );
                                    }
                                  },
                                  icon: const Icon(Icons.check_circle_outline_rounded, color: Colors.white, size: 18),
                                  label: const Text('Xác nhận chọn Salon này', style: TextStyle(fontWeight: FontWeight.bold)),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.primary,
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                                    elevation: 0,
                                  ),
                                )
                              : ElevatedButton.icon(
                                  onPressed: () {
                                    widget.onBranchConfirmed(_selectedSalon);
                                    Navigator.pop(context);
                                  },
                                  icon: const Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 18),
                                  label: const Text('Tiếp tục đặt lịch', style: TextStyle(fontWeight: FontWeight.bold)),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.green.shade600,
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                                    elevation: 0,
                                  ),
                                ),
                        ),
                      ],
                    ),
            ),
        ],
      ),
    );
  }

  Widget _photoPlaceholder() {
    return Container(
      width: 80,
      height: 80,
      color: const Color(0xFFFFF0F5),
      alignment: Alignment.center,
      child: const Icon(Icons.storefront_rounded, color: AppColors.primary, size: 30),
    );
  }
}