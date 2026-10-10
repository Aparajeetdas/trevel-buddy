import '../models/app_models.dart';

enum CoverageLevel {
  good('Good', 'Verified official tariffs & community benchmarks'),
  limited('Limited', 'Community reports & estimated tariffs available'),
  estimateOnly('Estimate only', 'We have limited price data for this location');

  final String label;
  final String description;
  const CoverageLevel(this.label, this.description);
}

/// Curated or generic configuration for cities in Travel Buddy
class CityConfig {
  final String cityId;
  final String name;
  final String state;
  final String country;
  final double centerLat;
  final double centerLng;
  final CoverageLevel coverage;
  final bool hasOfficialTariff;
  final bool isGeneric;
  final List<String> popularHubs;
  final Map<String, dynamic> defaultFareRates;

  const CityConfig({
    required this.cityId,
    required this.name,
    required this.state,
    required this.country,
    required this.centerLat,
    required this.centerLng,
    required this.coverage,
    this.hasOfficialTariff = true,
    this.isGeneric = false,
    this.popularHubs = const [],
    this.defaultFareRates = const {},
  });

  LatLng get center => LatLng(centerLat, centerLng);

  /// Primary Demo City: Jaipur, Rajasthan (Pink City)
  static const CityConfig jaipur = CityConfig(
    cityId: 'jaipur',
    name: 'Jaipur',
    state: 'Rajasthan',
    country: 'India',
    centerLat: 26.9124,
    centerLng: 75.7873,
    coverage: CoverageLevel.good,
    hasOfficialTariff: true,
    isGeneric: false,
    popularHubs: [
      'Jaipur Junction Railway Station',
      'Sindhi Camp Central Bus Stand',
      'Jaipur International Airport (JAI)',
      'Hawa Mahal / Badi Chaupar',
    ],
    defaultFareRates: {
      'auto': {
        'baseFare': 30.0,
        'baseKm': 1.5,
        'perKm': 12.0,
        'nightRateMultiplier': 1.25,
      },
      'cab': {
        'baseFare': 50.0,
        'baseKm': 2.0,
        'perKm': 18.0,
        'nightRateMultiplier': 1.25,
      },
      'bike': {
        'baseFare': 20.0,
        'baseKm': 1.0,
        'perKm': 8.0,
        'nightRateMultiplier': 1.15,
      },
    },
  );

  /// Curated City: New Delhi / NCR
  static const CityConfig newDelhi = CityConfig(
    cityId: 'new_delhi',
    name: 'New Delhi',
    state: 'Delhi',
    country: 'India',
    centerLat: 28.6139,
    centerLng: 77.2090,
    coverage: CoverageLevel.good,
    hasOfficialTariff: true,
    isGeneric: false,
    popularHubs: [
      'New Delhi Railway Station (NDLS)',
      'Indira Gandhi International Airport (DEL)',
      'Kashmere Gate ISBT',
      'Connaught Place (CP)',
    ],
    defaultFareRates: {
      'auto': {
        'baseFare': 30.0,
        'baseKm': 1.5,
        'perKm': 11.0,
        'nightRateMultiplier': 1.25,
      },
      'cab': {
        'baseFare': 50.0,
        'baseKm': 2.0,
        'perKm': 16.0,
        'nightRateMultiplier': 1.25,
      },
      'bike': {
        'baseFare': 20.0,
        'baseKm': 1.0,
        'perKm': 7.0,
        'nightRateMultiplier': 1.15,
      },
    },
  );

  /// Creates a fallback generic configuration for any city without curated tariffs
  factory CityConfig.generic({
    required String cityName,
    double latitude = 20.5937,
    double longitude = 78.9629,
    String? state,
    String? country,
  }) {
    return CityConfig(
      cityId:
          'generic_${cityName.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '_')}',
      name: cityName,
      state: state ?? 'India',
      country: country ?? 'India',
      centerLat: latitude,
      centerLng: longitude,
      coverage: CoverageLevel.estimateOnly,
      hasOfficialTariff: false,
      isGeneric: true,
      popularHubs: const [],
      defaultFareRates: const {
        'auto': {
          'baseFare': 35.0,
          'baseKm': 1.5,
          'perKm': 14.0,
          'nightRateMultiplier': 1.25,
        },
        'cab': {
          'baseFare': 60.0,
          'baseKm': 2.0,
          'perKm': 20.0,
          'nightRateMultiplier': 1.25,
        },
        'bike': {
          'baseFare': 25.0,
          'baseKm': 1.0,
          'perKm': 9.0,
          'nightRateMultiplier': 1.15,
        },
      },
    );
  }
}
