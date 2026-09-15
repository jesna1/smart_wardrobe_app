// lib/features/profile/presentation/screens/style_input_screen.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class StyleInputScreen extends StatefulWidget {
  final String? initialUndertone;
  final String? initialSkinType;
  final String? initialBodyShape;

  const StyleInputScreen({
    super.key,
    this.initialUndertone,
    this.initialSkinType,
    this.initialBodyShape,
  });

  @override
  State<StyleInputScreen> createState() => _StyleInputScreenState();
}

class _StyleInputScreenState extends State<StyleInputScreen> {
  late String _selectedUndertone;
  late String _selectedSkinType;
  late String _selectedBodyShape;

  final List<String> _undertones = ['Warm', 'Cool', 'Neutral', 'Olive'];
  final List<String> _skinTypes = ['Combination', 'Dry', 'Oily', 'Sensitive'];
  final List<String> _bodyShapes = ['Hourglass', 'Pear', 'Rectangle', 'Inverted Triangle', 'Apple'];

  @override
  void initState() {
    super.initState();
    _selectedUndertone = widget.initialUndertone ?? 'Warm';
    _selectedSkinType = widget.initialSkinType ?? 'Combination';
    _selectedBodyShape = widget.initialBodyShape ?? 'Hourglass';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: Text(
          'AI Style & Silhouette Input',
          style: GoogleFonts.playfairDisplay(
            color: const Color(0xFF1E293B),
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFF1E293B)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            'Personal Attributes for AI Analysis',
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF1E293B),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Gemini AI will analyze these characteristics along with your wardrobe to compute your optimal color seasonal archetype and silhouette tailoring.',
            style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF64748B)),
          ),
          const SizedBox(height: 24),

          _buildChipSection(
            title: 'Skin Undertone',
            options: _undertones,
            selectedValue: _selectedUndertone,
            onSelected: (val) => setState(() => _selectedUndertone = val),
          ),
          const SizedBox(height: 20),

          _buildChipSection(
            title: 'Skin Type',
            options: _skinTypes,
            selectedValue: _selectedSkinType,
            onSelected: (val) => setState(() => _selectedSkinType = val),
          ),
          const SizedBox(height: 20),

          _buildChipSection(
            title: 'Body Shape',
            options: _bodyShapes,
            selectedValue: _selectedBodyShape,
            onSelected: (val) => setState(() => _selectedBodyShape = val),
          ),
          const SizedBox(height: 32),

          ElevatedButton(
            onPressed: () {
              Navigator.pop(context, {
                'skin_undertone': _selectedUndertone,
                'skin_type': _selectedSkinType,
                'body_shape': _selectedBodyShape,
              });
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1E293B),
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.auto_awesome, color: Colors.amber, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Run AI Palette & Silhouette Analysis',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChipSection({
    required String title,
    required List<String> options,
    required String selectedValue,
    required ValueChanged<String> onSelected,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: const Color(0xFF475569),
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: options.map((option) {
            final isSelected = selectedValue == option;
            return ChoiceChip(
              label: Text(
                option,
                style: GoogleFonts.inter(
                  color: isSelected ? Colors.white : const Color(0xFF334155),
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
              selected: isSelected,
              selectedColor: const Color(0xFF1E293B),
              backgroundColor: Colors.white,
              onSelected: (_) => onSelected(option),
            );
          }).toList(),
        ),
      ],
    );
  }
}