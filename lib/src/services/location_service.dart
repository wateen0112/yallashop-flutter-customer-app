import 'package:yallashop_core/yallashop_core.dart';
import '../config/api_config.dart';

/// A location item from the API (governorate, city, or area).
class LocationItem {
  final String id;
  final String name;
  final String? nameAr;

  const LocationItem({
    required this.id,
    required this.name,
    this.nameAr,
  });

  factory LocationItem.fromJson(Map<String, dynamic> json) {
    return LocationItem(
      id: json['id'] as String,
      name: json['name'] as String,
      nameAr: json['name_ar'] as String?,
    );
  }

  @override
  String toString() => name;
}

/// Service for fetching location data (governorates, cities, areas).
class LocationService {
  final ApiClient _apiClient;

  LocationService({ApiClient? apiClient})
      : _apiClient = apiClient ?? ApiClient(baseUrl: CustomerApiConfig.baseUrl);

  /// Get all governorates.
  Future<Result<List<LocationItem>>> getGovernorates() async {
    final result = await _apiClient.get<List<dynamic>>(
      '/locations/governorates',
    );

    if (result is Success<List<dynamic>>) {
      final items = result.data
          .map((e) => LocationItem.fromJson(e as Map<String, dynamic>))
          .toList();
      return Success(items);
    }

    return Failure((result as Failure).exception);
  }

  /// Get cities for a specific governorate.
  Future<Result<List<LocationItem>>> getCities(String governorateId) async {
    final result = await _apiClient.get<List<dynamic>>(
      '/locations/cities',
      queryParams: {'governorate': governorateId},
    );

    if (result is Success<List<dynamic>>) {
      final items = result.data
          .map((e) => LocationItem.fromJson(e as Map<String, dynamic>))
          .toList();
      return Success(items);
    }

    return Failure((result as Failure).exception);
  }

  /// Get areas/villages for a specific city.
  Future<Result<List<LocationItem>>> getAreas(
    String governorateId,
    String cityId,
  ) async {
    final result = await _apiClient.get<List<dynamic>>(
      '/locations/areas',
      queryParams: {
        'governorate': governorateId,
        'city': cityId,
      },
    );

    if (result is Success<List<dynamic>>) {
      final items = result.data
          .map((e) => LocationItem.fromJson(e as Map<String, dynamic>))
          .toList();
      return Success(items);
    }

    return Failure((result as Failure).exception);
  }
}
