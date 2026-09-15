import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:dio/dio.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/api/api_client.dart';
import '../../../core/api/api_config.dart';

// --- Data Models ---
class Category extends Equatable {
  final int id;
  final String name;

  const Category({required this.id, required this.name});

  factory Category.fromJson(Map<String, dynamic> json) {
    return Category(
      id: json['id'] as int,
      name: json['name'] as String,
    );
  }

  @override
  List<Object?> get props => [id, name];
}


class WardrobeItem extends Equatable {
  final int id;
  final String title;
  final String? color;
  final String? season;
  final String? occasion;
  final int? categoryId;
  final Category? category;
  final String? imageUrl;

  const WardrobeItem({
    required this.id,
    required this.title,
    this.color,
    this.season,
    this.occasion,
    this.categoryId,
    this.category,
    this.imageUrl,
  });

  factory WardrobeItem.fromJson(Map<String, dynamic> json) {
    String? rawUrl = json['image_url'];
    String? fullUrl;

    if (rawUrl != null && rawUrl.isNotEmpty) {
      if (rawUrl.startsWith('http')) {
        fullUrl = rawUrl; // Cloudinary or full S3 URL
      } else {
        // Strip trailing /api/v1/ to resolve backend root static uploads
        final rootHost = ApiConfig.baseUrl.replaceAll(RegExp(r'api/v1/?$'), '');
        fullUrl = '$rootHost${rawUrl.startsWith('/') ? rawUrl.substring(1) : rawUrl}';
      }
    }

    return WardrobeItem(
      id: json['id'],
      title: json['title'] ?? 'Wardrobe Item',
      color: json['color']?.toString(),
      season: json['season']?.toString(),
      occasion: json['occasion']?.toString(),
      categoryId: json['category_id'] is int ? json['category_id'] as int : null,
      category: json['category'] != null ? Category.fromJson(json['category']) : null,
      imageUrl: fullUrl,
    );
  }

  @override
  List<Object?> get props => [id, title, color, season, occasion, categoryId, category, imageUrl];
}

// --- States ---

abstract class WardrobeState extends Equatable {
  @override
  List<Object?> get props => [];
}

class WardrobeInitial extends WardrobeState {}
class WardrobeLoading extends WardrobeState {}

class WardrobeLoaded extends WardrobeState {
  final List<WardrobeItem> items;
  WardrobeLoaded(this.items);

  @override
  List<Object?> get props => [items];
}

class WardrobeError extends WardrobeState {
  final String message;
  WardrobeError(this.message);

  @override
  List<Object?> get props => [message];
}

// --- Events ---

abstract class WardrobeEvent extends Equatable {
  @override
  List<Object?> get props => [];
}

class FetchWardrobeItems extends WardrobeEvent {}

class UploadWardrobeItem extends WardrobeEvent {
  final XFile imageFile;
  final String title;
  final String color;
  final String season;
  final String occasion;
  final int categoryId;

  UploadWardrobeItem({
    required this.imageFile,
    required this.title,
    required this.color,
    required this.season,
    required this.occasion,
    required this.categoryId,
  });

  @override
  List<Object?> get props => [imageFile, title, color, season, occasion, categoryId];
}

// --- BLoC Implementation ---

class WardrobeBloc extends Bloc<WardrobeEvent, WardrobeState> {
  final ApiClient apiClient;

  WardrobeBloc(this.apiClient) : super(WardrobeInitial()) {
    on<FetchWardrobeItems>(_onFetchWardrobeItems);
    on<UploadWardrobeItem>(_onUploadWardrobeItem);
  }

  Future<void> _onFetchWardrobeItems(
      FetchWardrobeItems event,
      Emitter<WardrobeState> emit,
      ) async {
    emit(WardrobeLoading());
    try {
      final res = await apiClient.dio.get('wardrobe/items');

      List<dynamic> rawList = [];

      if (res.data is List) {
        rawList = res.data as List<dynamic>;
      } else if (res.data is Map<String, dynamic>) {
        final mapData = res.data as Map<String, dynamic>;
        rawList = (mapData['items'] ?? mapData['data'] ?? []) as List<dynamic>;
      }

      final items = rawList
          .whereType<Map<String, dynamic>>()
          .map((i) => WardrobeItem.fromJson(i))
          .toList();

      emit(WardrobeLoaded(items));
    } catch (e) {
      if (e is DioException) {
        final serverDetail = e.response?.data is Map
            ? e.response?.data['detail']
            : null;
        emit(WardrobeError(serverDetail?.toString() ?? "Failed to fetch wardrobe items."));
      } else {
        emit(WardrobeError("Failed to fetch wardrobe items: ${e.toString()}"));
      }
    }
  }

  Future<void> _onUploadWardrobeItem(
      UploadWardrobeItem event,
      Emitter<WardrobeState> emit,
      ) async {
    emit(WardrobeLoading());
    try {
      final List<int> imageBytes = await event.imageFile.readAsBytes();
      final String fileName = event.imageFile.name.isNotEmpty
          ? event.imageFile.name
          : 'clothing_item.jpg';

      final Map<String, dynamic> formMap = {
        "title": event.title,
        "remove_bg": true,
        "category_id": event.categoryId,
        "file": MultipartFile.fromBytes(
          imageBytes,
          filename: fileName,
        ),
      };

      if (event.color.trim().isNotEmpty) {
        formMap["color"] = event.color.trim();
      }
      if (event.season.trim().isNotEmpty) {
        formMap["season"] = event.season.trim();
      }
      if (event.occasion.trim().isNotEmpty) {
        formMap["occasion"] = event.occasion.trim();
      }

      final formData = FormData.fromMap(formMap);

      final response = await apiClient.dio.post(
        'wardrobe/items/upload',
        data: formData,
        options: Options(
          sendTimeout: const Duration(seconds: 60),
          receiveTimeout: const Duration(seconds: 60),
        ),
      );

      print("✅ UPLOAD SUCCESS: ${response.data}");
      add(FetchWardrobeItems());
    } catch (e) {
      if (e is DioException) {
        print("❌ UPLOAD FAILED STATUS: ${e.response?.statusCode}");
        print("❌ DIO ERROR TYPE: ${e.type}");
        print("❌ SOCKET/OS ERROR: ${e.error}");
        print("❌ REQUEST URL: ${e.requestOptions.uri}");

        final serverDetail = e.response?.data?['detail'];
        final errorMessage = e.type == DioExceptionType.receiveTimeout
            ? "Server image processing timed out. Please try again."
            : (serverDetail ?? "Failed to upload item.");

        emit(WardrobeError(errorMessage));
      } else {
        print("❌ UNKNOWN ERROR: $e");
        emit(WardrobeError("Failed to upload item."));
      }
    }
  }
}