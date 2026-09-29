import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../models/restaurant.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import 'restaurant_detail_screen.dart';

class MapViewScreen extends StatefulWidget {
  final List<RestaurantModel> restaurants;

  const MapViewScreen({super.key, required this.restaurants});

  @override
  State<MapViewScreen> createState() => _MapViewScreenState();
}

class _MapViewScreenState extends State<MapViewScreen> {
  final MapController _mapController = MapController();
  RestaurantModel? _selectedRestaurant;

  @override
  void initState() {
    super.initState();
    if (widget.restaurants.isNotEmpty) {
      _selectedRestaurant = widget.restaurants.first;
    }
  }

  @override
  void didUpdateWidget(covariant MapViewScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.restaurants != widget.restaurants && widget.restaurants.isNotEmpty) {
      setState(() {
        _selectedRestaurant = widget.restaurants.first;
      });
    }
  }

  void _selectRestaurant(RestaurantModel rest) {
    setState(() {
      _selectedRestaurant = rest;
    });
    _mapController.move(
      LatLng(rest.latitude, rest.longitude),
      14.5,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final initialCenter = widget.restaurants.isNotEmpty
        ? LatLng(widget.restaurants.first.latitude, widget.restaurants.first.longitude)
        : const LatLng(21.0285, 105.8542); // Default Hanoi Bờ Hồ

    // Standard OpenStreetMap Free Tile Engine
    final tileUrl = 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';

    return Scaffold(
      backgroundColor: isDark ? AppTheme.pitchBlack : AppTheme.pureWhite,
      body: Stack(
        children: [
          // OpenStreetMap / CartoDB Map View
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: initialCenter,
              initialZoom: 13.5,
              maxZoom: 18.0,
              minZoom: 5.0,
              interactionOptions: const InteractionOptions(
                flags: InteractiveFlag.all,
              ),
            ),
            children: [
              // OpenStreetMap Minimalist Tiles
              TileLayer(
                urlTemplate: tileUrl,
                userAgentPackageName: 'com.example.food_review_app',
              ),

              // Interactive Restaurant Markers
              MarkerLayer(
                markers: widget.restaurants.map((rest) {
                  final isSelected = _selectedRestaurant?.id == rest.id;

                  return Marker(
                    point: LatLng(rest.latitude, rest.longitude),
                    width: isSelected ? 120 : 90,
                    height: isSelected ? 48 : 40,
                    child: GestureDetector(
                      onTap: () => _selectRestaurant(rest),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AppTheme.fireCoral
                              : (isDark ? AppTheme.pitchBlack : AppTheme.pureWhite),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                            color: isSelected ? AppTheme.pureWhite : AppTheme.fireCoral,
                            width: isSelected ? 2.0 : 1.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(isSelected ? 0.35 : 0.2),
                              blurRadius: isSelected ? 12 : 6,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.restaurant_rounded,
                              size: isSelected ? 16 : 14,
                              color: isSelected ? AppTheme.pureWhite : AppTheme.fireCoral,
                            ),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                rest.name,
                                style: TextStyle(
                                  fontSize: isSelected ? 13 : 11,
                                  fontWeight: FontWeight.bold,
                                  color: isSelected
                                      ? AppTheme.pureWhite
                                      : (isDark ? AppTheme.pureWhite : AppTheme.pitchBlack),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),

          // Top Header Overlay Badge
          Positioned(
            top: 20,
            left: 20,
            right: 20,
            child: SafeArea(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: (isDark ? AppTheme.pitchBlack : AppTheme.pureWhite).withOpacity(0.92),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isDark ? AppTheme.darkGrayBorder : AppTheme.grayBorder,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.15),
                      blurRadius: 12,
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    const Icon(Icons.map_rounded, color: AppTheme.fireCoral, size: 22),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'OpenStreetMap (${widget.restaurants.length} địa điểm)',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: isDark ? AppTheme.pureWhite : AppTheme.pitchBlack,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppTheme.fireCoral.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        'FREE MAP',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.fireCoral,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Bottom Preview Card when a Marker is selected
          if (_selectedRestaurant != null)
            Positioned(
              bottom: 24,
              left: 20,
              right: 20,
              child: GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => RestaurantDetailScreen(
                        restaurantId: _selectedRestaurant!.id,
                      ),
                    ),
                  );
                },
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: isDark ? AppTheme.darkCardBg : AppTheme.pureWhite,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: AppTheme.fireCoral,
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.25),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: Image.network(
                          ApiService.resolveImageUrl(
                            _selectedRestaurant!.cardImageUrl ?? _selectedRestaurant!.coverImageUrl,
                          ),
                          width: 80,
                          height: 80,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => Container(
                            width: 80,
                            height: 80,
                            color: AppTheme.pitchBlack,
                            child: const Icon(Icons.restaurant, color: AppTheme.fireCoral),
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: AppTheme.fireCoral,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    _selectedRestaurant!.cuisine.toUpperCase(),
                                    style: const TextStyle(
                                      color: AppTheme.pureWhite,
                                      fontSize: 9,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  _selectedRestaurant!.priceRange,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.fireCoral,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _selectedRestaurant!.name,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: isDark ? AppTheme.pureWhite : AppTheme.pitchBlack,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                const Icon(Icons.star_rounded, size: 14, color: AppTheme.fireCoral),
                                const SizedBox(width: 2),
                                Text(
                                  _selectedRestaurant!.rating.toStringAsFixed(1),
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: isDark ? AppTheme.pureWhite : AppTheme.pitchBlack,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    _selectedRestaurant!.address,
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: isDark ? AppTheme.textMutedDark : AppTheme.textMutedLight,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.chevron_right_rounded, color: AppTheme.fireCoral, size: 24),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
