import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/app_models.dart';

abstract class AppDataRepository {
  Future<List<Place>> getPlaces();
  Future<Place?> getPlaceById(String id);
  Future<List<Driver>> getDrivers();
  Future<Driver?> getDriverByVehicleNumber(String vehicleNumber);
  Future<List<ScamReportZone>> getScamReportZones();
  Future<List<FairPrice>> getFairPrices({PriceCategory? category});
  Future<List<FareRule>> getFareRules();
  Future<List<ScamReport>> getScamReports();
  Future<void> submitScamReport(ScamReport report);
  Future<List<BusinessProfile>> getBusinessProfiles();
  Future<void> saveBusinessProfile(BusinessProfile profile);
  Future<void> resetAllData();
}

class LocalAppDataRepository implements AppDataRepository {
  static const String _userReportsKey = 'travel_buddy_user_reports_v1';
  static const String _userBusinessKey = 'travel_buddy_business_profiles_v1';

  List<Place>? _cachedPlaces;
  List<Driver>? _cachedDrivers;
  List<ScamReportZone>? _cachedScamZones;
  List<FairPrice>? _cachedFairPrices;
  List<FareRule>? _cachedFareRules;

  @override
  Future<List<Place>> getPlaces() async {
    if (_cachedPlaces != null) return _cachedPlaces!;
    final String raw = await rootBundle.loadString('assets/data/places.json');
    final List<dynamic> list = jsonDecode(raw) as List<dynamic>;
    _cachedPlaces = list
        .map((e) => Place.fromJson(e as Map<String, dynamic>))
        .toList();
    return _cachedPlaces!;
  }

  @override
  Future<Place?> getPlaceById(String id) async {
    final places = await getPlaces();
    try {
      return places.firstWhere((p) => p.id == id);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<List<Driver>> getDrivers() async {
    if (_cachedDrivers != null) return _cachedDrivers!;
    final String raw = await rootBundle.loadString('assets/data/drivers.json');
    final List<dynamic> list = jsonDecode(raw) as List<dynamic>;
    _cachedDrivers = list
        .map((e) => Driver.fromJson(e as Map<String, dynamic>))
        .toList();
    return _cachedDrivers!;
  }

  @override
  Future<Driver?> getDriverByVehicleNumber(String vehicleNumber) async {
    final drivers = await getDrivers();
    final cleanInput = vehicleNumber
        .replaceAll(RegExp(r'[^A-Za-z0-9]'), '')
        .toUpperCase();
    if (cleanInput.isEmpty) return null;

    return drivers.where((d) {
      final cleanD = d.vehicleNumber
          .replaceAll(RegExp(r'[^A-Za-z0-9]'), '')
          .toUpperCase();
      return cleanD == cleanInput ||
          cleanD.contains(cleanInput) ||
          cleanInput.contains(cleanD);
    }).firstOrNull;
  }

  @override
  Future<List<ScamReportZone>> getScamReportZones() async {
    if (_cachedScamZones != null) return _cachedScamZones!;
    final String raw = await rootBundle.loadString(
      'assets/data/scam_zones.json',
    );
    final List<dynamic> list = jsonDecode(raw) as List<dynamic>;
    _cachedScamZones = list
        .map((e) => ScamReportZone.fromJson(e as Map<String, dynamic>))
        .toList();
    return _cachedScamZones!;
  }

  @override
  Future<List<FairPrice>> getFairPrices({PriceCategory? category}) async {
    if (_cachedFairPrices == null) {
      final String raw = await rootBundle.loadString(
        'assets/data/fair_prices.json',
      );
      final List<dynamic> list = jsonDecode(raw) as List<dynamic>;
      _cachedFairPrices = list
          .map((e) => FairPrice.fromJson(e as Map<String, dynamic>))
          .toList();
    }
    if (category == null) return _cachedFairPrices!;
    return _cachedFairPrices!.where((fp) => fp.category == category).toList();
  }

  @override
  Future<List<FareRule>> getFareRules() async {
    if (_cachedFareRules != null) return _cachedFareRules!;
    final String raw = await rootBundle.loadString(
      'assets/data/fare_rules.json',
    );
    final List<dynamic> list = jsonDecode(raw) as List<dynamic>;
    _cachedFareRules = list
        .map((e) => FareRule.fromJson(e as Map<String, dynamic>))
        .toList();
    return _cachedFareRules!;
  }

  @override
  Future<List<ScamReport>> getScamReports() async {
    final prefs = await SharedPreferences.getInstance();
    final String? stored = prefs.getString(_userReportsKey);
    if (stored == null || stored.isEmpty) {
      // Return 2 default initial reports
      return [
        ScamReport(
          id: 'REP-7429',
          incidentType: 'Auto Rickshaw Overcharge',
          placeName: 'Jaipur Pink City',
          amountLost: 450.0,
          description:
              'Demanded ₹500 for a 2 km ride from Hawa Mahal to City Palace.',
          timestamp: DateTime.now().subtract(const Duration(days: 2)),
          status: 'Under Review',
        ),
        ScamReport(
          id: 'REP-8104',
          incidentType: 'Fake Tour Guide',
          placeName: 'Amer Fort, Jaipur',
          amountLost: 1200.0,
          description:
              'Claimed official ASI guide certification but led to gem store.',
          timestamp: DateTime.now().subtract(const Duration(days: 5)),
          status: 'Verified Warning',
        ),
      ];
    }
    final List<dynamic> list = jsonDecode(stored) as List<dynamic>;
    return list
        .map((e) => ScamReport.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<void> submitScamReport(ScamReport report) async {
    final prefs = await SharedPreferences.getInstance();
    final reports = await getScamReports();
    reports.insert(0, report);
    final String encoded = jsonEncode(reports.map((e) => e.toJson()).toList());
    await prefs.setString(_userReportsKey, encoded);
  }

  @override
  Future<List<BusinessProfile>> getBusinessProfiles() async {
    final prefs = await SharedPreferences.getInstance();
    final String? stored = prefs.getString(_userBusinessKey);
    if (stored == null || stored.isEmpty) {
      return [];
    }
    final List<dynamic> list = jsonDecode(stored) as List<dynamic>;
    return list
        .map((e) => BusinessProfile.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<void> saveBusinessProfile(BusinessProfile profile) async {
    final prefs = await SharedPreferences.getInstance();
    final profiles = await getBusinessProfiles();
    profiles.removeWhere((p) => p.id == profile.id);
    profiles.insert(0, profile);
    final String encoded = jsonEncode(profiles.map((e) => e.toJson()).toList());
    await prefs.setString(_userBusinessKey, encoded);
  }

  @override
  Future<void> resetAllData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_userReportsKey);
    await prefs.remove(_userBusinessKey);
    _cachedPlaces = null;
    _cachedDrivers = null;
    _cachedScamZones = null;
    _cachedFairPrices = null;
    _cachedFareRules = null;
  }
}

// Riverpod Provider
final appRepositoryProvider = Provider<AppDataRepository>((ref) {
  return LocalAppDataRepository();
});

// StateNotifier / FutureProviders for reactive UI
final placesFutureProvider = FutureProvider<List<Place>>((ref) async {
  final repo = ref.watch(appRepositoryProvider);
  return repo.getPlaces();
});

final scamZonesFutureProvider = FutureProvider<List<ScamReportZone>>((
  ref,
) async {
  final repo = ref.watch(appRepositoryProvider);
  return repo.getScamReportZones();
});

final fairPricesFutureProvider = FutureProvider<List<FairPrice>>((ref) async {
  final repo = ref.watch(appRepositoryProvider);
  return repo.getFairPrices();
});

final driversFutureProvider = FutureProvider<List<Driver>>((ref) async {
  final repo = ref.watch(appRepositoryProvider);
  return repo.getDrivers();
});

final fareRulesFutureProvider = FutureProvider<List<FareRule>>((ref) async {
  final repo = ref.watch(appRepositoryProvider);
  return repo.getFareRules();
});

class ScamReportsNotifier extends AsyncNotifier<List<ScamReport>> {
  @override
  Future<List<ScamReport>> build() async {
    final repo = ref.watch(appRepositoryProvider);
    return repo.getScamReports();
  }

  Future<void> loadReports() async {
    ref.invalidateSelf();
  }

  Future<void> addReport(ScamReport report) async {
    final repo = ref.read(appRepositoryProvider);
    await repo.submitScamReport(report);
    ref.invalidateSelf();
  }

  Future<void> reset() async {
    final repo = ref.read(appRepositoryProvider);
    await repo.resetAllData();
    ref.invalidateSelf();
  }
}

final scamReportsNotifierProvider =
    AsyncNotifierProvider<ScamReportsNotifier, List<ScamReport>>(
      ScamReportsNotifier.new,
    );

class BusinessProfileNotifier extends AsyncNotifier<List<BusinessProfile>> {
  @override
  Future<List<BusinessProfile>> build() async {
    final repo = ref.watch(appRepositoryProvider);
    return repo.getBusinessProfiles();
  }

  Future<void> loadProfiles() async {
    ref.invalidateSelf();
  }

  Future<void> addProfile(BusinessProfile profile) async {
    final repo = ref.read(appRepositoryProvider);
    await repo.saveBusinessProfile(profile);
    ref.invalidateSelf();
  }

  Future<void> reset() async {
    final repo = ref.read(appRepositoryProvider);
    await repo.resetAllData();
    ref.invalidateSelf();
  }
}

final businessProfileNotifierProvider =
    AsyncNotifierProvider<BusinessProfileNotifier, List<BusinessProfile>>(
      BusinessProfileNotifier.new,
    );
