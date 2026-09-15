import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import '../bloc/stylist_bloc.dart';

class StylistScreen extends StatefulWidget {
  const StylistScreen({super.key});

  @override
  State<StylistScreen> createState() => _StylistScreenState();
}

class _StylistScreenState extends State<StylistScreen> {
  static const List<String> _occasions = ['Work', 'Casual', 'Formal', 'Evening', 'Gym'];

  @override
  void initState() {
    super.initState();
    final bloc = context.read<StylistBloc>();
    if (bloc.state is StylistInitial) {
      bloc.add(FetchRecommendations(occasion: 'Work'));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: Text(
          'AI Daily Stylist',
          style: GoogleFonts.playfairDisplay(
            color: const Color(0xFF1E293B),
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Color(0xFF1E293B)),
            onPressed: () {
              final state = context.read<StylistBloc>().state;
              final occasion = state is StylistLoaded ? state.selectedOccasion : 'Work';
              context.read<StylistBloc>().add(FetchRecommendations(occasion: occasion));
            },
          ),
        ],
      ),
      body: BlocConsumer<StylistBloc, StylistState>(
        listener: (context, state) {
          if (state is StylistLoaded && state.actionMessage != null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.actionMessage!),
                backgroundColor: const Color(0xFF2A9D8F),
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        },
        builder: (context, state) {
          if (state is StylistLoading || state is StylistInitial) {
            return const Center(
              child: CircularProgressIndicator(color: Color(0xFF1E293B)),
            );
          }

          if (state is StylistError) {
            return _buildErrorState(context, state.message);
          }

          final loadedState = state as StylistLoaded;

          return RefreshIndicator(
            color: const Color(0xFF1E293B),
            onRefresh: () async {
              context.read<StylistBloc>().add(
                FetchRecommendations(occasion: loadedState.selectedOccasion),
              );
            },
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              children: [
                if (loadedState.weather != null) ...[
                  _buildWeatherHeader(loadedState.weather),
                  const SizedBox(height: 20),
                ],
                Text(
                  'Select Occasion',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF1E293B),
                  ),
                ),
                const SizedBox(height: 10),
                _buildOccasionSelector(context, loadedState.selectedOccasion),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'AI Suggested Look',
                      style: GoogleFonts.playfairDisplay(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF1E293B),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE07A5F).withOpacity(0.12),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        'Weather Adapted',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFFE07A5F),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                if (loadedState.recommendations.isEmpty)
                  _buildEmptyRecommendations()
                else
                  ...loadedState.recommendations.map(
                        (outfit) => _buildOutfitCard(context, outfit),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildErrorState(BuildContext context, String message) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.cloud_off_rounded, size: 60, color: Colors.grey),
            const SizedBox(height: 16),
            Text(
              'Unable to Fetch Stylist Data',
              style: GoogleFonts.playfairDisplay(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF1E293B),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(color: Colors.grey[600], fontSize: 13),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1E293B),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () {
                context.read<StylistBloc>().add(FetchRecommendations(occasion: 'Work'));
              },
              icon: const Icon(Icons.refresh, size: 18, color: Colors.white),
              label: Text('Try Again', style: GoogleFonts.inter(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyRecommendations() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Center(
        child: Text(
          'No recommendations found for this occasion.',
          style: GoogleFonts.inter(color: Colors.grey[600]),
        ),
      ),
    );
  }

  Widget _buildWeatherHeader(WeatherInfo? weather) {
    if (weather == null) return const SizedBox.shrink();

    final iconUrl = 'https://openweathermap.org/img/wn/${weather.iconCode}@2x.png';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1E293B), Color(0xFF334155)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1E293B).withOpacity(0.2),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.location_on_outlined, color: Colors.white70, size: 16),
                  const SizedBox(width: 4),
                  Text(
                    weather.location,
                    style: GoogleFonts.inter(color: Colors.white70, fontSize: 13),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                '${weather.temperatureC.toInt()}°C',
                style: GoogleFonts.playfairDisplay(
                  fontSize: 38,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              Text(
                weather.condition,
                style: GoogleFonts.inter(
                  color: const Color(0xFFE07A5F),
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Image.network(
                iconUrl,
                width: 54,
                height: 54,
                errorBuilder: (_, __, ___) => const Icon(
                  Icons.wb_sunny_rounded,
                  color: Color(0xFFF4A261),
                  size: 48,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'Humidity ${weather.humidity}%',
                  style: GoogleFonts.inter(color: Colors.white, fontSize: 11),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildOccasionSelector(BuildContext context, String currentOccasion) {
    return SizedBox(
      height: 38,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _occasions.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final occasion = _occasions[index];
          final isSelected = occasion.toLowerCase() == currentOccasion.toLowerCase();
          return ChoiceChip(
            label: Text(occasion),
            selected: isSelected,
            selectedColor: const Color(0xFF1E293B),
            backgroundColor: Colors.white,
            labelStyle: GoogleFonts.inter(
              color: isSelected ? Colors.white : const Color(0xFF1E293B),
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              fontSize: 13,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: BorderSide(
                color: isSelected ? Colors.transparent : Colors.grey[300]!,
              ),
            ),
            onSelected: (_) {
              context.read<StylistBloc>().add(FetchRecommendations(occasion: occasion));
            },
          );
        },
      ),
    );
  }

  Widget _buildOutfitCard(BuildContext context, OutfitRecommendation outfit) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
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
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    outfit.title,
                    style: GoogleFonts.playfairDisplay(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF1E293B),
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2A9D8F).withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.bolt, size: 14, color: Color(0xFF2A9D8F)),
                      const SizedBox(width: 2),
                      Text(
                        '${outfit.matchScore}% Match',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF2A9D8F),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: double.infinity,
            margin: const EdgeInsets.symmetric(horizontal: 16),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF8F9FA),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey[200]!),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.auto_awesome, size: 16, color: Color(0xFFE07A5F)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    outfit.aiRationale,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: Colors.grey[700],
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 110,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              scrollDirection: Axis.horizontal,
              itemCount: outfit.items.length,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (context, index) {
                final item = outfit.items[index];
                return Container(
                  width: 90,
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8F9FA),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey[200]!),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Expanded(
                        child: item.imageUrl != null && item.imageUrl!.isNotEmpty
                            ? Image.network(
                          item.imageUrl!,
                          fit: BoxFit.contain,
                          errorBuilder: (_, __, ___) => const Icon(
                            Icons.checkroom,
                            color: Color(0xFF1E293B),
                            size: 28,
                          ),
                        )
                            : const Icon(
                          Icons.checkroom,
                          color: Color(0xFF1E293B),
                          size: 28,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        item.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF1E293B),
                        ),
                      ),
                      Text(
                        item.category.toUpperCase(),
                        style: GoogleFonts.inter(
                          fontSize: 9,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 12),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TextButton.icon(
                  onPressed: () {
                    context.read<StylistBloc>().add(ToggleSaveOutfit(outfit.id));
                  },
                  icon: Icon(
                    outfit.isSaved ? Icons.bookmark : Icons.bookmark_border,
                    color: outfit.isSaved ? const Color(0xFFE07A5F) : Colors.grey[600],
                  ),
                  label: Text(
                    outfit.isSaved ? 'Saved' : 'Save Look',
                    style: GoogleFonts.inter(
                      color: outfit.isSaved ? const Color(0xFFE07A5F) : Colors.grey[700],
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1E293B),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                  onPressed: () {
                    context.read<StylistBloc>().add(WearOutfitToday(outfit));
                  },
                  icon: const Icon(Icons.check_circle_outline, size: 18, color: Colors.white),
                  label: Text(
                    'Wear Today',
                    style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w600),
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