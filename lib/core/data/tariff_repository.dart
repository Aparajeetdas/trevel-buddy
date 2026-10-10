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
  bool get isFetchedRemotely;
  DateTime? get lastRefreshed;
}

class LocalGovTariffRepository implements GovTariffRepository {
  final String? remoteUrl;
  List<GovTariff>? _cachedTariffs;
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
