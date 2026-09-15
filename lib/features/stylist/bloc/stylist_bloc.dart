import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:dio/dio.dart';
import '../../../core/api/api_client.dart';

// Safe Parsing Helpers
Map<String, dynamic> _asMap(dynamic value) {
  if (value is Map) {
    return value.map((key, val) => MapEntry(key.toString(), val));
  }
  if (value is String) {
    try {
      final decoded = jsonDecode(value);
      if (decoded is Map) {
        return decoded.map((key, val) => MapEntry(key.toString(), val));
      }
    } catch (_) {}
  }
  return {};
}

double _toDouble(dynamic value, [double defaultValue = 0.0]) {
  if (value == null) return defaultValue;
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value) ?? defaultValue;
  return defaultValue;
}

int _toInt(dynamic value, [int defaultValue = 0]) {
  if (value == null) return defaultValue;
  if (value is num) return value.toInt();
  if (value is String) {
    final cleaned = value.replaceAll(RegExp(r'[^\d-]'), '');
    return int.tryParse(cleaned) ?? defaultValue;
  }
  return defaultValue;
}

String _toString(dynamic value, [String defaultValue = '']) {
  if (value == null) return defaultValue;
  return value.toString();
}

// Data Models
class WeatherInfo extends Equatable {
  final double temperatureC;
  final String condition;
  final String location;
  final int humidity;
  final String iconCode;

  const WeatherInfo({
    required this.temperatureC,
    required this.condition,
    required this.location,
    required this.humidity,
    required this.iconCode,
  });

  factory WeatherInfo.fromJson(Map<String, dynamic> json) {
    return WeatherInfo(
      temperatureC: _toDouble(
        json['temperature_c'] ?? json['temp_c'] ?? json['temperature'] ?? json['temp'],
      ),
      condition: _toString(json['condition'], 'Sunny'),
      location: _toString(json['location'], 'Doha, Qatar'),
      humidity: _toInt(json['humidity']),
      iconCode: _toString(json['icon_code'] ?? json['icon'], '01d'),
    );
  }

  @override
  List<Object?> get props => [temperatureC, condition, location, humidity, iconCode];
}

class RecommendedItem extends Equatable {
  final int id;
  final String title;
  final String category;
  final String? imageUrl;
  final String? color;

  const RecommendedItem({
    required this.id,
    required this.title,
    required this.category,
    this.imageUrl,
    this.color,
  });

  factory RecommendedItem.fromJson(Map<String, dynamic> json) {
    return RecommendedItem(
      id: _toInt(json['id']),
      title: _toString(json['title'], 'Wardrobe Item'),
      category: _toString(json['category'], 'General'),
      imageUrl: json['image_url'] as String?,
      color: json['color'] as String?,
    );
  }

  @override
  List<Object?> get props => [id, title, category, imageUrl, color];
}

class OutfitRecommendation extends Equatable {
  final int id;
  final String title;
  final String occasion;
  final int matchScore;
  final String aiRationale;
  final List<RecommendedItem> items;
  final bool isSaved;

  const OutfitRecommendation({
    required this.id,
    required this.title,
    required this.occasion,
    required this.matchScore,
    required this.aiRationale,
    required this.items,
    this.isSaved = false,
  });

  OutfitRecommendation copyWith({bool? isSaved}) {
    return OutfitRecommendation(
      id: id,
      title: title,
      occasion: occasion,
      matchScore: matchScore,
      aiRationale: aiRationale,
      items: items,
      isSaved: isSaved ?? this.isSaved,
    );
  }

  factory OutfitRecommendation.fromJson(Map<String, dynamic> json, String fallbackOccasion) {
    final List<RecommendedItem> parsedItems = [];

    final itemsRaw = json['items'];
    if (itemsRaw is Map) {
      itemsRaw.forEach((categoryKey, itemVal) {
        if (itemVal != null && itemVal is Map) {
          final itemMap = _asMap(itemVal);
          itemMap['category'] ??= categoryKey.toString();
          parsedItems.add(RecommendedItem.fromJson(itemMap));
        }
      });
    } else if (itemsRaw is List) {
      for (final item in itemsRaw) {
        if (item is Map) {
          parsedItems.add(RecommendedItem.fromJson(_asMap(item)));
        }
      }
    }

    return OutfitRecommendation(
      id: _toInt(json['outfit_id'] ?? json['id']),
      title: _toString(json['title'], 'AI Curated Look'),
      occasion: _toString(json['occasion'], fallbackOccasion),
      matchScore: _toDouble(json['match_score'] ?? json['score'], 90.0).round(),
      aiRationale: _toString(
        json['ai_rationale'],
        'Recommended based on current preferences.',
      ),
      items: parsedItems,
      isSaved: json['is_saved'] as bool? ?? false,
    );
  }

  @override
  List<Object?> get props => [id, title, occasion, matchScore, aiRationale, items, isSaved];
}

// BLoC Events
abstract class StylistEvent extends Equatable {
  @override
  List<Object?> get props => [];
}

class FetchRecommendations extends StylistEvent {
  final String occasion;
  FetchRecommendations({this.occasion = 'Work'});

  @override
  List<Object?> get props => [occasion];
}

class ToggleSaveOutfit extends StylistEvent {
  final int outfitId;
  ToggleSaveOutfit(this.outfitId);

  @override
  List<Object?> get props => [outfitId];
}

class WearOutfitToday extends StylistEvent {
  final OutfitRecommendation outfit;
  WearOutfitToday(this.outfit);

  @override
  List<Object?> get props => [outfit];
}

// BLoC States
abstract class StylistState extends Equatable {
  @override
  List<Object?> get props => [];
}

class StylistInitial extends StylistState {}

class StylistLoading extends StylistState {}

class StylistLoaded extends StylistState {
  final WeatherInfo? weather;
  final String selectedOccasion;
  final List<OutfitRecommendation> recommendations;
  final String? actionMessage;

  StylistLoaded({
    this.weather,
    required this.selectedOccasion,
    required this.recommendations,
    this.actionMessage,
  });

  StylistLoaded copyWith({
    WeatherInfo? weather,
    String? selectedOccasion,
    List<OutfitRecommendation>? recommendations,
    String? actionMessage,
  }) {
    return StylistLoaded(
      weather: weather ?? this.weather,
      selectedOccasion: selectedOccasion ?? this.selectedOccasion,
      recommendations: recommendations ?? this.recommendations,
      actionMessage: actionMessage,
    );
  }

  @override
  List<Object?> get props => [weather, selectedOccasion, recommendations, actionMessage];
}

class StylistError extends StylistState {
  final String message;
  StylistError(this.message);

  @override
  List<Object?> get props => [message];
}

// BLoC Implementation
class StylistBloc extends Bloc<StylistEvent, StylistState> {
  final ApiClient apiClient;

  StylistBloc(this.apiClient) : super(StylistInitial()) {
    on<FetchRecommendations>(_onFetchRecommendations);
    on<ToggleSaveOutfit>(_onToggleSaveOutfit);
    on<WearOutfitToday>(_onWearOutfitToday);
  }

  Future<void> _onFetchRecommendations(
      FetchRecommendations event,
      Emitter<StylistState> emit,
      ) async {
    emit(StylistLoading());
    try {
      final response = await apiClient.dio.get(
        'stylist/recommendations',
        queryParameters: {'occasion': event.occasion.toLowerCase()},
      );

      final responseData = _asMap(response.data);

      final WeatherInfo? weather = responseData.containsKey('weather') && responseData['weather'] != null
          ? WeatherInfo.fromJson(_asMap(responseData['weather']))
          : null;

      final rawOutfits = (responseData['recommendations'] ?? responseData['outfits']) as List<dynamic>? ?? [];

      final recommendationsList = rawOutfits
          .where((o) => o is Map)
          .map((o) => OutfitRecommendation.fromJson(_asMap(o), event.occasion))
          .toList();

      emit(StylistLoaded(
        weather: weather,
        selectedOccasion: event.occasion,
        recommendations: recommendationsList,
      ));
    } on DioException catch (e) {
      debugPrint('Dio Error: ${e.requestOptions.uri}');
      final errorMsg =
          e.response?.data?['detail'] ?? e.response?.data?['message'] ?? e.message ?? 'Failed to load recommendations';
      emit(StylistError(errorMsg));
    } catch (e, stackTrace) {
      debugPrint('StylistBloc Exception: $e\n$stackTrace');
      emit(StylistError('An unexpected error occurred. Please try again.'));
    }
  }

  Future<void> _onToggleSaveOutfit(
      ToggleSaveOutfit event,
      Emitter<StylistState> emit,
      ) async {
    if (state is StylistLoaded) {
      final currentState = state as StylistLoaded;

      final updatedOutfits = currentState.recommendations.map((outfit) {
        if (outfit.id == event.outfitId) {
          return outfit.copyWith(isSaved: !outfit.isSaved);
        }
        return outfit;
      }).toList();

      emit(currentState.copyWith(
        recommendations: updatedOutfits,
        actionMessage: null,
      ));

      try {
        await apiClient.dio.post('stylist/outfits/${event.outfitId}/toggle-save');
      } catch (_) {
        emit(currentState);
      }
    }
  }

  Future<void> _onWearOutfitToday(
      WearOutfitToday event,
      Emitter<StylistState> emit,
      ) async {
    if (state is StylistLoaded) {
      final currentState = state as StylistLoaded;
      try {
        await apiClient.dio.post('stylist/outfits/${event.outfit.id}/wear');
        emit(currentState.copyWith(
          actionMessage: 'Set "${event.outfit.title}" as today\'s look!',
        ));
      } catch (e) {
        emit(currentState.copyWith(
          actionMessage: 'Failed to record today\'s look. Check your connection.',
        ));
      }
    }
  }
}