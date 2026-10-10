import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../models/app_models.dart';
import '../utils/async_utils.dart';

/// Repository interface for government tariffs with bundled snapshot and optional remote fallback
abstract class GovTariffRepository {
  Future<List<GovTariff>> getTariffs({bool forceRefresh = false});
  Future<GovTariff?> findTariff({
    required String city,
    required ServiceType serviceType,
    String? vehicleType,
  });
  Future<AirportPrepaidFareDataset> getAirportDataset({
    bool forceRefresh = false,
  }) async {
    return const AirportPrepaidFareDataset(
      source: 'LGBI Airport Pre-paid Taxi Counter, Guwahati',
      verified: true,
      origin: 'LGBI Airport, Guwahati',
      routes: [],
    );
  }
  Future<List<FixedRouteTariff>> getAirportPrepaidTariffs({
    bool forceRefresh = false,
  }) async => [];
  bool get isFetchedRemotely;
  DateTime? get lastRefreshed;
}

class LocalGovTariffRepository implements GovTariffRepository {
  final String? remoteUrl;
  List<GovTariff>? _cachedTariffs;
  AirportPrepaidFareDataset? _cachedAirportDataset;
  List<FixedRouteTariff>? _cachedAirportTariffs;
  bool _isFetchedRemotely = false;
  DateTime? _lastRefreshed;

  LocalGovTariffRepository({this.remoteUrl});

  @override
  bool get isFetchedRemotely => _isFetchedRemotely;

  @override
  DateTime? get lastRefreshed => _lastRefreshed;

  @override
  Future<List<GovTariff>> getTariffs({bool forceRefresh = false}) async {
    if (_cachedTariffs != null && !forceRefresh) {
      return _cachedTariffs!;
    }

    // Try optional remote URL if provided
    if (remoteUrl != null && remoteUrl!.isNotEmpty) {
      try {
        final response = await http
            .get(Uri.parse(remoteUrl!))
            .timeout(const Duration(seconds: 4));
        if (response.statusCode == 200) {
          final List<dynamic> list = jsonDecode(response.body) as List<dynamic>;
          _cachedTariffs = list
              .map((e) => GovTariff.fromJson(e as Map<String, dynamic>))
              .toList();
          _isFetchedRemotely = true;
          _lastRefreshed = DateTime.now();
          return _cachedTariffs!;
        }
      } catch (_) {
        // Graceful fallback to bundled snapshot
      }
    }

    // Load bundled snapshot
    final String raw = await rootBundle.loadString('assets/data/tariffs.json');
    final List<dynamic> list = jsonDecode(raw) as List<dynamic>;
    _cachedTariffs = list
        .map((e) => GovTariff.fromJson(e as Map<String, dynamic>))
        .toList();
    _isFetchedRemotely = false;
    _lastRefreshed = DateTime.now();
    return _cachedTariffs!;
  }

  @override
  Future<AirportPrepaidFareDataset> getAirportDataset({
    bool forceRefresh = false,
  }) async {
    if (_cachedAirportDataset != null && !forceRefresh) {
      return _cachedAirportDataset!;
    }

    final String raw = await rootBundle
        .loadString('assets/data/airport_prepaid_taxi_fares.json');
    final dynamic parsed = jsonDecode(raw);

    if (parsed is Map<String, dynamic>) {
      _cachedAirportDataset = AirportPrepaidFareDataset.fromJson(parsed);
    } else if (parsed is List<dynamic>) {
      final routes = parsed
          .map((e) => FixedRouteTariff.fromJson(e as Map<String, dynamic>))
          .toList();
      _cachedAirportDataset = AirportPrepaidFareDataset(
        source: routes.isNotEmpty
            ? routes.first.source
            : 'LGBI Airport Pre-paid Taxi Counter, Guwahati',
        effectiveDate: null,
        verified: true,
        origin: 'LGBI Airport, Guwahati',
        routes: routes,
      );
    } else {
      _cachedAirportDataset = const AirportPrepaidFareDataset(
        source: 'LGBI Airport Pre-paid Taxi Counter, Guwahati',
        verified: true,
        origin: 'LGBI Airport, Guwahati',
        routes: [],
      );
    }

    _cachedAirportTariffs = _cachedAirportDataset!.routes;
    return _cachedAirportDataset!;
  }

  @override
  Future<List<FixedRouteTariff>> getAirportPrepaidTariffs({
    bool forceRefresh = false,
  }) async {
    if (_cachedAirportTariffs != null && !forceRefresh) {
      return _cachedAirportTariffs!;
    }
    final dataset = await getAirportDataset(forceRefresh: forceRefresh);
    return dataset.routes;
  }

  @override
  Future<GovTariff?> findTariff({
    required String city,
    required ServiceType serviceType,
    String? vehicleType,
  }) async {
    final tariffs = await getTariffs();
    final normalizedCity = city.toLowerCase().trim();

    // Find city and service matches
    final matches = tariffs.where((t) {
      final matchesCity =
          t.city.toLowerCase() == normalizedCity ||
          normalizedCity.contains(t.city.toLowerCase());
      return matchesCity && t.serviceType == serviceType;
    }).toList();

    if (matches.isEmpty) return null;

    if (vehicleType != null && vehicleType.isNotEmpty) {
      final normalizedVeh = vehicleType.toLowerCase();
      final exactVeh = matches
          .where(
            (t) =>
                t.vehicleType.toLowerCase().contains(normalizedVeh) ||
                normalizedVeh.contains(t.vehicleType.toLowerCase()),
          )
          .firstOrNull;
      if (exactVeh != null) return exactVeh;
    }

    return matches.first;
  }
}

final govTariffRepositoryProvider = Provider<GovTariffRepository>((ref) {
  return LocalGovTariffRepository();
});

final tariffsFutureProvider = FutureProvider<List<GovTariff>>((ref) async {
  final repo = ref.watch(govTariffRepositoryProvider);
  return withTimeout(
    repo.getTariffs(),
    timeout: const Duration(seconds: 4),
    fallback: <GovTariff>[],
    operationName: 'Load Tariffs',
  );
});

final airportPrepaidDatasetProvider =
    FutureProvider<AirportPrepaidFareDataset>((ref) async {
  final repo = ref.watch(govTariffRepositoryProvider);
  return withTimeout(
    repo.getAirportDataset(),
    timeout: const Duration(seconds: 4),
    fallback: const AirportPrepaidFareDataset(
      source: 'LGBI Airport Pre-paid Taxi Counter, Guwahati',
      verified: true,
      origin: 'LGBI Airport, Guwahati',
      routes: [],
    ),
    operationName: 'Load Airport Prepaid Dataset',
  );
});

final airportPrepaidFaresProvider = airportPrepaidDatasetProvider;

final airportPrepaidTariffsProvider =
    FutureProvider<List<FixedRouteTariff>>((ref) async {
  final repo = ref.watch(govTariffRepositoryProvider);
  return withTimeout(
    repo.getAirportPrepaidTariffs(),
    timeout: const Duration(seconds: 4),
    fallback: <FixedRouteTariff>[],
    operationName: 'Load Airport Prepaid Tariffs',
  );
});

