import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../bloc/wardrobe_bloc.dart';

class AddWardrobeItemSheet extends StatefulWidget {
  const AddWardrobeItemSheet({super.key});

  @override
  State<AddWardrobeItemSheet> createState() => _AddWardrobeItemSheetState();
}

class _AddWardrobeItemSheetState extends State<AddWardrobeItemSheet> {
  final _titleController = TextEditingController();
  final _colorController = TextEditingController();

  String _selectedSeason = 'All Season';
  String _selectedOccasion = 'Work';
  int _selectedCategoryId = 1;

  XFile? _selectedImage;
  final _picker = ImagePicker();

  final List<String> _seasons = ['All Season', 'Summer', 'Winter', 'Spring', 'Autumn'];
  final List<String> _occasions = ['Work', 'Casual', 'Formal', 'Evening', 'Sport'];

  final List<Map<String, dynamic>> _categories = [
    {'id': 1, 'name': 'Top'},
    {'id': 2, 'name': 'Bottom'},
    {'id': 3, 'name': 'Shoes'},
    {'id': 4, 'name': 'Outerwear'},
    {'id': 5, 'name': 'Accessory'},
  ];

  Future<void> _pickImage(ImageSource source) async {
    final pickedFile = await _picker.pickImage(source: source, imageQuality: 80);
    if (pickedFile != null) {
      setState(() => _selectedImage = pickedFile);
    }
  }

  // Camera + Gallery Picker Modal
  void _showImageSourceDialog() {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Photo Gallery'),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.gallery);
              },
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Camera'),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.camera);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _submit() {
    if (_selectedImage == null || _titleController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select an image and enter a title')),
      );
      return;
    }

    context.read<WardrobeBloc>().add(
      UploadWardrobeItem(
        imageFile: _selectedImage!,
        title: _titleController.text.trim(),
        color: _colorController.text.trim().isEmpty ? 'Multi' : _colorController.text.trim(),
        season: _selectedSeason,
        occasion: _selectedOccasion,
        categoryId: _selectedCategoryId,
      ),
    );
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 20,
        right: 20,
        top: 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Add Wardrobe Item',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
            ),
            const SizedBox(height: 16),
            GestureDetector(
              onTap: _showImageSourceDialog, // Updated to launch dialog
              child: Container(
                height: 140,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey[300]!),
                ),
                child: _selectedImage != null
                    ? ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.file(File(_selectedImage!.path), fit: BoxFit.cover),
                )
                    : const Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.add_a_photo_outlined, size: 36, color: Colors.grey),
                    SizedBox(height: 8),
                    Text('Tap to pick clothing image', style: TextStyle(color: Colors.grey)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _titleController,
              decoration: InputDecoration(
                labelText: 'Title (e.g., Terracotta Blazer)',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _colorController,
              decoration: InputDecoration(
                labelText: 'Color (e.g., Navy Blue)',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<int>(
              value: _selectedCategoryId,
              items: _categories.map((c) {
                return DropdownMenuItem<int>(
                  value: c['id'] as int,
                  child: Text(c['name'] as String),
                );
              }).toList(),
              onChanged: (val) => setState(() => _selectedCategoryId = val!),
              decoration: InputDecoration(
                labelText: 'Category',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _selectedOccasion,
              items: _occasions.map((o) => DropdownMenuItem(value: o, child: Text(o))).toList(),
              onChanged: (val) => setState(() => _selectedOccasion = val!),
              decoration: InputDecoration(
                labelText: 'Occasion',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _selectedSeason,
              items: _seasons.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
              onChanged: (val) => setState(() => _selectedSeason = val!),
              decoration: InputDecoration(
                labelText: 'Season',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1E293B),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: _submit,
                child: const Text('Upload & Extract Embeddings', style: TextStyle(color: Colors.white)),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}