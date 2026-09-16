import 'dart:developer' as dev;
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/api/api_client.dart';
import 'style_input_screen.dart';

// -----------------------------------------------------------------------------
// Data Model
// -----------------------------------------------------------------------------
class UserProfileData {
  final String name;
  final String role;
  final String location;
  final String skinType;
  final String skinUndertone;
  final String seasonalColorType;
  final String bodyShape;
  final String styleArchetype;
  final String paletteName;
  final List<Color> paletteSwatches;
  final List<String> preferredStyles;
  final List<String> bodyShapeTips;
  final List<String> wardrobeInsights;

  const UserProfileData({
    required this.name,
    required this.role,
    required this.location,
    required this.skinType,
    required this.skinUndertone,
    required this.seasonalColorType,
    required this.bodyShape,
    required this.styleArchetype,
    required this.paletteName,
    required this.paletteSwatches,
    required this.preferredStyles,
    required this.bodyShapeTips,
    required this.wardrobeInsights,
  });

  factory UserProfileData.fromJson(Map<String, dynamic> json) {
    Color parseHexColor(String hexString) {
      try {
        final cleanHex = hexString.replaceAll('#', '').trim();
        if (cleanHex.length == 6) {
          return Color(int.parse('FF$cleanHex', radix: 16));
        } else if (cleanHex.length == 8) {
          return Color(int.parse(cleanHex, radix: 16));
        }
      } catch (e) {
        dev.log('Failed to parse hex color: $hexString', error: e);
      }
      return const Color(0xFF1E293B);
    }

    List<String> parseStringList(dynamic rawList) {
      if (rawList is List) {
        return rawList.map((item) => item.toString()).toList();
      }
      return [];
    }

    final hexList = parseStringList(json['palette_swatches']);

    return UserProfileData(
      name: json['name']?.toString() ?? 'User',
      role: json['role']?.toString() ?? 'Senior Application Developer',
      location: json['location']?.toString() ?? 'Doha, Qatar',
      skinType: json['skin_type']?.toString() ?? 'Combination',
      skinUndertone: json['skin_undertone']?.toString() ?? 'Warm',
      seasonalColorType: json['seasonal_color_type']?.toString() ?? 'Deep Autumn',
      bodyShape: json['body_shape']?.toString() ?? 'Hourglass',
      styleArchetype: json['style_archetype']?.toString() ?? 'Executive Formal & Traditional Fusion',
      paletteName: json['palette_name']?.toString() ?? 'Rich Oxblood & Deep Earth Palette',
      paletteSwatches: hexList.isNotEmpty
          ? hexList.map(parseHexColor).toList()
          : const [
        Color(0xFF4A0E17),
        Color(0xFF800020),
        Color(0xFF2D4A3E),
        Color(0xFFB87333),
      ],
      preferredStyles: parseStringList(json['preferred_styles']),
      bodyShapeTips: parseStringList(json['body_shape_tips']),
      wardrobeInsights: parseStringList(json['wardrobe_insights']),
    );
  }

  String get initials {
    final parts = name.trim().split(' ');
    if (parts.length > 1 && parts.last.isNotEmpty) {
      return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
    }
    return parts.first.isNotEmpty ? parts.first[0].toUpperCase() : 'U';
  }
}

// -----------------------------------------------------------------------------
// Profile Screen
// -----------------------------------------------------------------------------
class ProfileScreen extends StatefulWidget {
  final UserProfileData? userProfile;
  final Dio? dio;

  const ProfileScreen({
    super.key,
    this.userProfile,
    this.dio,
  });

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late UserProfileData _currentProfile;
  final CancelToken _cancelToken = CancelToken();
  bool _isAnalyzing = false;
  bool _isLoading = false;

  /// Helper getter to resolve Dio from explicit constructor OR BuildContext providers
  Dio? get _activeDio {
    if (widget.dio != null) return widget.dio;
    try {
      return context.read<ApiClient>().dio;
    } catch (_) {
      try {
        return context.read<Dio>();
      } catch (_) {
        return null;
      }
    }
  }

  @override
  void initState() {
    super.initState();
    _currentProfile = widget.userProfile ?? _defaultProfile;

    // Post-frame callback ensures BuildContext is safe for provider lookup
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      if (_activeDio == null) {
        dev.log(
          '⚠️ WARNING: Dio/ApiClient not found in widget or context. Using local fallback profile.',
          name: 'PROFILE_SCREEN',
        );
      } else {
        dev.log('✅ Dio client detected via context. Fetching profile...', name: 'PROFILE_SCREEN');
        _fetchInitialProfile();
      }
    });
  }

  @override
  void didUpdateWidget(covariant ProfileScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.userProfile != null && widget.userProfile != oldWidget.userProfile) {
      setState(() {
        _currentProfile = widget.userProfile!;
      });
    }
  }

  static const UserProfileData _defaultProfile = UserProfileData(
    name: 'Jesna Jose',
    role: 'Senior Application Developer',
    location: 'Doha, Qatar',
    skinType: 'Combination',
    skinUndertone: 'Warm',
    seasonalColorType: 'Deep Autumn',
    bodyShape: 'Hourglass',
    styleArchetype: 'Executive Formal & Traditional Fusion',
    paletteName: 'Rich Oxblood & Warm Copper Palette',
    paletteSwatches: [
      Color(0xFF4A0E17),
      Color(0xFF800020),
      Color(0xFF2D4A3E),
      Color(0xFFB87333),
    ],
    preferredStyles: ['Kasavu Sarees', 'Silk Sarees', 'Structured Blazers'],
    bodyShapeTips: [
      'Structured blazers with tapered waistlines to highlight natural symmetry',
      'Belted sarees and tailored wraps to preserve waist definition',
      'High-waisted wide-leg trousers paired with fitted tops'
    ],
    wardrobeInsights: [
      'Pair core neutral trousers with rich oxblood or warm copper blouses for contrast.',
      'Layer structured blazers over Kasavu saree drapes for executive fusion events.'
    ],
  );

  @override
  void dispose() {
    _cancelToken.cancel('ProfileScreen disposed');
    super.dispose();
  }

  Future<void> _fetchInitialProfile() async {
    final client = _activeDio;
    if (client == null) return;

    // Only show full loading if we don't have profile data yet
    if (mounted) setState(() => _isLoading = true);

    try {
      dev.log('==> GET /users/me/profile', name: 'PROFILE_SCREEN');
      final response = await client.get(
        '/users/me/profile',
        cancelToken: _cancelToken,
      );
      dev.log('<== Status Code: ${response.statusCode}', name: 'PROFILE_SCREEN');

      if (mounted && response.data != null) {
        setState(() {
          _currentProfile = UserProfileData.fromJson(response.data);
        });
      }
    } on DioException catch (e) {
      if (CancelToken.isCancel(e)) return;
      dev.log('⚠️ Could not fetch remote profile (using local template): ${e.message}', name: 'PROFILE_SCREEN');
    } catch (e) {
      dev.log('⚠️ Unexpected error fetching profile: $e', name: 'PROFILE_SCREEN');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _openStyleInputScreen() async {
    final result = await Navigator.push<Map<String, String>>(
      context,
      MaterialPageRoute(
        builder: (_) => StyleInputScreen(
          initialUndertone: _currentProfile.skinUndertone,
          initialSkinType: _currentProfile.skinType,
          initialBodyShape: _currentProfile.bodyShape,
        ),
      ),
    );

    if (result != null && mounted) {
      await _runAiReanalysis(result);
    }
  }

  Future<void> _runAiReanalysis(Map<String, String> attributes) async {
    setState(() => _isAnalyzing = true);

    try {
      final client = _activeDio;
      if (client != null) {
        dev.log('==> POST /users/me/reanalyze-style', name: 'PROFILE_SCREEN');
        dev.log('==> Payload: $attributes', name: 'PROFILE_SCREEN');

        final response = await client.post(
          '/users/me/reanalyze-style',
          data: attributes,
          cancelToken: _cancelToken,
        );

        dev.log('<== Status Code: ${response.statusCode}', name: 'PROFILE_SCREEN');
        dev.log('<== Response Data: ${response.data}', name: 'PROFILE_SCREEN');

        if (mounted && response.data != null) {
          setState(() {
            _currentProfile = UserProfileData.fromJson(response.data);
          });
        }
      } else {
        dev.log('⚠️ Dio client is null. Running mock local analysis.', name: 'PROFILE_SCREEN');
        await Future.delayed(const Duration(seconds: 2));
        if (mounted) {
          final isCool = attributes['skin_undertone'] == 'Cool';
          setState(() {
            _currentProfile = UserProfileData(
              name: _currentProfile.name,
              role: _currentProfile.role,
              location: _currentProfile.location,
              skinType: attributes['skin_type'] ?? 'Combination',
              skinUndertone: attributes['skin_undertone'] ?? 'Warm',
              seasonalColorType: isCool ? 'Cool Winter' : 'Deep Autumn',
              bodyShape: attributes['body_shape'] ?? 'Hourglass',
              styleArchetype: 'AI Refined Aesthetic',
              paletteName: isCool
                  ? 'Sapphire & Emerald Jewel Palette'
                  : 'Warm Oxblood & Amber Palette',
              paletteSwatches: isCool
                  ? const [
                Color(0xFF0F2C59),
                Color(0xFF1B4D3E),
                Color(0xFF701C45),
                Color(0xFF331327)
              ]
                  : _currentProfile.paletteSwatches,
              preferredStyles: _currentProfile.preferredStyles,
              bodyShapeTips: [
                'AI Adjusted Fit for ${attributes['body_shape']} body shape',
                'Tailored cuts focusing on structural proportions',
                'Optimal drape alignment for saree borders'
              ],
              wardrobeInsights: [
                'Styling updated for ${attributes['skin_undertone']} undertones and ${attributes['body_shape']} silhouette.'
              ],
            );
          });
        }
      }
    } on DioException catch (e) {
      if (CancelToken.isCancel(e)) return;
      dev.log('❌ DioException caught during re-analysis', name: 'PROFILE_SCREEN', error: e);

      String errorMsg = 'AI re-analysis failed';
      if (e.response?.data is Map && e.response?.data['detail'] != null) {
        errorMsg = e.response?.data['detail'].toString() ?? errorMsg;
      } else if (e.response?.data != null) {
        errorMsg = e.response!.data.toString();
      } else if (e.message != null) {
        errorMsg = e.message!;
      }

      _showErrorSnackBar('Error ${e.response?.statusCode ?? 'Network'}: $errorMsg');
    } catch (e, stack) {
      dev.log('❌ Unexpected Error in _runAiReanalysis', name: 'PROFILE_SCREEN', error: e, stackTrace: stack);
      _showErrorSnackBar('Unexpected error: $e');
    } finally {
      if (mounted) setState(() => _isAnalyzing = false);
    }
  }

  void _showErrorSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(color: Colors.white)),
        backgroundColor: Colors.red[800],
        duration: const Duration(seconds: 5),
        action: SnackBarAction(
          label: 'DISMISS',
          textColor: Colors.white,
          onPressed: () {},
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading || _isAnalyzing) {
      return Scaffold(
        backgroundColor: const Color(0xFFF8F9FA),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(color: Color(0xFF1E293B)),
              const SizedBox(height: 20),
              Text(
                _isAnalyzing
                    ? 'Analyzing color harmony & silhouette with Gemini AI...'
                    : 'Loading profile details...',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: const Color(0xFF64748B),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final profile = _currentProfile;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: Text(
          'AI Color & Silhouette Profile',
          style: GoogleFonts.playfairDisplay(
            color: const Color(0xFF1E293B),
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.tune_rounded, color: Color(0xFF1E293B)),
            tooltip: 'Update Attributes',
            onPressed: _openStyleInputScreen,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          if (_activeDio != null) {
            await _fetchInitialProfile();
          } else {
            _showErrorSnackBar('Dio instance is null. Cannot perform live refresh.');
          }
        },
        color: const Color(0xFF1E293B),
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            _buildHeaderCard(profile),
            const SizedBox(height: 20),
            _buildSectionHeader('AI Color & Skin Analysis'),
            _buildColorCard(profile),
            const SizedBox(height: 20),
            _buildSectionHeader('Body Shape & Silhouette Styling'),
            _buildBodyShapeCard(profile),
            const SizedBox(height: 20),
            if (profile.wardrobeInsights.isNotEmpty) ...[
              _buildSectionHeader('Wardrobe Integration Insights'),
              _buildWardrobeInsightsCard(profile),
              const SizedBox(height: 20),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderCard(UserProfileData profile) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 30,
            backgroundColor: const Color(0xFF1E293B),
            child: Text(
              profile.initials,
              style: GoogleFonts.playfairDisplay(
                fontSize: 22,
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  profile.name,
                  style: GoogleFonts.playfairDisplay(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF1E293B),
                  ),
                ),
                Text(
                  '${profile.role} • ${profile.location}',
                  style: GoogleFonts.inter(fontSize: 12, color: Colors.grey[600]),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildColorCard(UserProfileData profile) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                profile.seasonalColorType,
                style: GoogleFonts.playfairDisplay(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF1E293B),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF3C7),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${profile.skinUndertone} Undertone',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF92400E),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            profile.paletteName,
            style: GoogleFonts.inter(fontSize: 12, color: Colors.grey[600]),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: profile.paletteSwatches
                .map(
                  (color) => Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.black.withValues(alpha: 0.08),
                    width: 1,
                  ),
                ),
              ),
            )
                .toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildBodyShapeCard(UserProfileData profile) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Body Shape: ${profile.bodyShape}',
                style: GoogleFonts.inter(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF1E293B),
                ),
              ),
              const Icon(Icons.accessibility_new_rounded, color: Color(0xFF1E293B)),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            profile.styleArchetype,
            style: GoogleFonts.inter(fontSize: 12, color: Colors.grey[600]),
          ),
          const Divider(height: 24),
          Text(
            'Recommended Fits & Tailoring:',
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF475569),
            ),
          ),
          const SizedBox(height: 8),
          ...profile.bodyShapeTips.map(
                (tip) => Padding(
              padding: const EdgeInsets.only(bottom: 6.0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('• ', style: TextStyle(fontWeight: FontWeight.bold)),
                  Expanded(
                    child: Text(
                      tip,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: const Color(0xFF334155),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWardrobeInsightsCard(UserProfileData profile) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: profile.wardrobeInsights
            .map(
              (insight) => Padding(
            padding: const EdgeInsets.only(bottom: 8.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.auto_awesome, size: 16, color: Color(0xFFB87333)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    insight,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: const Color(0xFF334155),
                    ),
                  ),
                ),
              ],
            ),
          ),
        )
            .toList(),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10.0, left: 4.0),
      child: Text(
        title,
        style: GoogleFonts.inter(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.5,
          color: const Color(0xFF64748B),
        ),
      ),
    );
  }
}