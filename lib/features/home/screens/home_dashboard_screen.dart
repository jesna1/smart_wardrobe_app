import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/api_config.dart';
import 'package:geolocator/geolocator.dart';

class HomeDashboardScreen extends StatefulWidget {
  const HomeDashboardScreen({super.key});

  @override
  State<HomeDashboardScreen> createState() => _HomeDashboardScreenState();
}

class _HomeDashboardScreenState extends State<HomeDashboardScreen> {
  bool _isLoading = true;
  String? _errorMessage;

  // Parsed Response States
  Map<String, dynamic>? _weatherData;
  Map<String, dynamic>? _selectedOutfit;
  List<dynamic> _recommendationList = [];
  String _selectedOccasion = 'Work';

  final List<String> _occasions = ['Work', 'Casual', 'Formal', 'Evening', 'Sport'];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchOutfitRecommendation();
    });
  }

 
  

  Future<void> _fetchOutfitRecommendation({String? occasion}) async {
    final activeOccasion = occasion ?? _selectedOccasion;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _selectedOccasion = activeOccasion;
    });

    try {
      // 1. Get live device location (falls back to Doha if location permission is denied)
      final position = await _determinePosition();
      final double latitude = position?.latitude ?? 25.2854;
      final double longitude = position?.longitude ?? 51.5310;
      debugPrint('📍 Sending Coordinates to Backend: lat=$latitude, lon=$longitude');
      final apiClient = context.read<ApiClient>();

      // 2. Pass dynamic coordinates to the API
      final response = await apiClient.dio.get(
        '/outfits/recommendations',
        queryParameters: {
          'lat': latitude,
          'lon': longitude,
          'occasion': activeOccasion.toLowerCase(),
          'limit': 5,
        },
      );
      debugPrint('☀️ Weather Response Payload: ${response.data}');
      if (response.statusCode == 200) {
        _parseRecommendationResponse(response.data);
      } else {
        setState(() {
          _errorMessage = 'Failed to load recommendations (HTTP ${response.statusCode})';
          _isLoading = false;
        });
      }
    } on DioException catch (e) {
      // Handling error states...
    }
  }

  void _parseRecommendationResponse(dynamic data) {
    Map<String, dynamic>? extractedWeather;
    List<dynamic> extractedOutfits = [];

    if (data is List) {
      extractedOutfits = data;
      if (extractedOutfits.isNotEmpty && extractedOutfits.first is Map) {
        extractedWeather = extractedOutfits.first['weather'];
      }
    } else if (data is Map<String, dynamic>) {
      extractedWeather = data['weather'];

      if (data['outfits'] is List) {
        extractedOutfits = data['outfits'];
      } else if (data['recommendations'] is List) {
        extractedOutfits = data['recommendations'];
      }
    }

    setState(() {
      _weatherData = extractedWeather;
      _recommendationList = extractedOutfits;
      _selectedOutfit = extractedOutfits.isNotEmpty ? extractedOutfits.first : null;
      _isLoading = false;
    });
  }

  String _resolveImageUrl(String? path) {
    if (path == null || path.trim().isEmpty) return '';
    if (path.startsWith('http')) return path;

    final cleanPath = path.startsWith('/') ? path : '/$path';
    final rootHost = ApiConfig.baseUrl.replaceAll('/api/v1/', '');
    return '$rootHost$cleanPath';
  }

  /// Extracts clothing item maps from either a Map or List object structure
  List<Map<String, dynamic>> _extractOutfitItems(Map<String, dynamic>? outfit) {
    if (outfit == null) return [];

    final rawItems = outfit['items'];
    List<Map<String, dynamic>> itemList = [];

    if (rawItems is Map<String, dynamic>) {
      // Map format: {"top": {...}, "bottom": {...}, "shoes": null}
      rawItems.forEach((key, value) {
        if (value is Map<String, dynamic>) {
          itemList.add(value);
        }
      });
    } else if (rawItems is List) {
      for (var item in rawItems) {
        if (item is Map<String, dynamic>) {
          itemList.add(item);
        }
      }
    }

    return itemList;
  }

  @override
  Widget build(BuildContext context) {
    final List<Map<String, dynamic>> items = _extractOutfitItems(_selectedOutfit);

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: Text(
          'Aura Wardrobe',
          style: GoogleFonts.playfairDisplay(
            color: const Color(0xFF1E293B),
            fontWeight: FontWeight.bold,
          ),
        ),
        elevation: 0,
        backgroundColor: Colors.transparent,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Color(0xFF1E293B)),
            onPressed: () => _fetchOutfitRecommendation(),
            tooltip: 'Refresh Recommendations',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => _fetchOutfitRecommendation(),
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            // Weather & Location Banner
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF1E293B), Color(0xFF334155)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _weatherData?['location'] ?? 'Doha, Qatar',
                          style: GoogleFonts.inter(color: Colors.white70, fontSize: 13),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${_weatherData?['temperature_c'] ?? 25}°C • ${_weatherData?['condition'] ?? 'Sunny'}',
                          style: GoogleFonts.playfairDisplay(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _weatherData?['season_category'] != null
                              ? 'Season: ${_weatherData!['season_category']}'
                              : 'Light linen or breathable fabrics recommended',
                          style: GoogleFonts.inter(color: Colors.white60, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.wb_sunny_outlined, size: 42, color: Color(0xFFE07A5F)),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Occasion Filter Selector
            SizedBox(
              height: 36,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _occasions.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final occ = _occasions[index];
                  final isSelected = occ.toLowerCase() == _selectedOccasion.toLowerCase();
                  return ChoiceChip(
                    label: Text(
                      occ,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        color: isSelected ? Colors.white : const Color(0xFF1E293B),
                      ),
                    ),
                    selected: isSelected,
                    selectedColor: const Color(0xFFE07A5F),
                    backgroundColor: Colors.white,
                    onSelected: (bool selected) {
                      if (selected) {
                        _fetchOutfitRecommendation(occasion: occ);
                      }
                    },
                  );
                },
              ),
            ),
            const SizedBox(height: 20),

            // Section Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Outfit of the Day',
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF1E293B),
                  ),
                ),
                if (_selectedOutfit?['score'] != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE07A5F).withOpacity(0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${_selectedOutfit!['score']}% MATCH',
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFFE07A5F),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),

            // Body Content Logic
            if (_isLoading)
              Container(
                height: 240,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Center(
                  child: CircularProgressIndicator(color: Color(0xFF1E293B)),
                ),
              )
            else if (_errorMessage != null)
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  children: [
                    const Icon(Icons.error_outline_rounded, size: 48, color: Colors.amber),
                    const SizedBox(height: 12),
                    Text(
                      _errorMessage!,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(fontSize: 13, color: Colors.grey[700]),
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton(
                      onPressed: () => _fetchOutfitRecommendation(),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1E293B),
                      ),
                      child: const Text('Try Again', style: TextStyle(color: Colors.white)),
                    ),
                  ],
                ),
              )
            else if (_selectedOutfit == null)
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Column(
                    children: [
                      const Icon(Icons.checkroom_outlined, size: 48, color: Colors.grey),
                      const SizedBox(height: 8),
                      Text(
                        'No recommendations found',
                        style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Add more items to your wardrobe to generate $_selectedOccasion outfits.',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.inter(fontSize: 12, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                )
              else
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.04),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Items Horizontal Row
                      if (items.isNotEmpty)
                        SizedBox(
                          height: 180,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            itemCount: items.length,
                            separatorBuilder: (_, __) => const SizedBox(width: 12),
                            itemBuilder: (context, index) {
                              final item = items[index];
                              final imageUrl = _resolveImageUrl(item['image_url']);

                              return ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: Container(
                                  width: 140,
                                  color: const Color(0xFFF1F5F9),
                                  child: imageUrl.isNotEmpty
                                      ? Image.network(
                                    imageUrl,
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stackTrace) =>
                                        _buildItemPlaceholder(item['title']),
                                  )
                                      : _buildItemPlaceholder(item['title']),
                                ),
                              );
                            },
                          ),
                        )
                      else
                        Container(
                          height: 140,
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Center(
                            child: Icon(Icons.checkroom_rounded, size: 48, color: Colors.grey),
                          ),
                        ),
                      const SizedBox(height: 16),

                      // Title & Description
                      Text(
                        _selectedOutfit!['title'] ??
                            'Outfit #${_selectedOutfit!['outfit_id'] ?? 1}',
                        style: GoogleFonts.playfairDisplay(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF1E293B),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _selectedOutfit!['ai_rationale'] ??
                            _selectedOutfit!['description'] ??
                            'Tailored combination from your digital wardrobe.',
                        style: GoogleFonts.inter(fontSize: 12, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),

            // Multiple Recommendations Carousel Switcher
            if (_recommendationList.length > 1) ...[
              const SizedBox(height: 20),
              Text(
                'Alternative Options',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF1E293B),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 50,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: _recommendationList.length,
                  itemBuilder: (context, index) {
                    final outfitOption = _recommendationList[index];
                    final isSelected = outfitOption == _selectedOutfit;
                    final outfitId = outfitOption['outfit_id'] ?? (index + 1);
                    final score = outfitOption['score'];

                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          _selectedOutfit = outfitOption;
                        });
                      },
                      child: Container(
                        margin: const EdgeInsets.only(right: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: isSelected ? const Color(0xFF1E293B) : Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isSelected ? const Color(0xFF1E293B) : Colors.grey[300]!,
                          ),
                        ),
                        child: Center(
                          child: Text(
                            score != null ? 'Option $outfitId ($score%)' : 'Option $outfitId',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color: isSelected ? Colors.white : const Color(0xFF1E293B),
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildItemPlaceholder(String? title) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.checkroom_rounded, size: 40, color: Colors.grey),
        const SizedBox(height: 4),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Text(
            title ?? 'Wardrobe Item',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(fontSize: 10, color: Colors.grey[600]),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Future<Position?> _determinePosition() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return null;

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return null;
    }

    if (permission == LocationPermission.deniedForever) return null;

    return await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.low,
    );
  }
}