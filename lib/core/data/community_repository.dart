import 'dart:convert';
import 'dart:math';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import '../models/app_models.dart';
import '../utils/report_security_validator.dart';

abstract class CommunityRepository {
  Future<List<PriceReport>> getPriceReports();
  Future<void> submitPriceReport(PriceReport report);
  Future<void> flagReport(String reportId);
  Future<List<TouristTrap>> getTouristTraps();
  Future<void> submitTouristTrap(TouristTrap trap);
  Future<void> flagTrap(String trapId);
  Future<List<AreaInsight>> getAreaInsights();
  Future<void> submitTakedownAppeal({
    required String entityName,
    required String reason,
    required String details,
    String? contactEmail,
  });
  Future<String> getAnonymousUserId();
  Future<void> clearAllLocalData();
  Future<void> resetCommunityData();
}

class LocalCommunityRepository implements CommunityRepository {
  static const String _userPriceReportsKey = 'travel_buddy_price_reports_v2';
  static const String _userTrapsKey = 'travel_buddy_tourist_traps_v2';
  static const String _takedownAppealsKey = 'travel_buddy_takedown_appeals';
  static const String _anonUserIdKey = 'travel_buddy_anon_user_id';

  List<PriceReport>? _cachedReports;
  List<TouristTrap>? _cachedTraps;
  List<AreaInsight>? _cachedAreaInsights;

  @override
  Future<String> getAnonymousUserId() async {
    final prefs = await SharedPreferences.getInstance();
    String? uid = prefs.getString(_anonUserIdKey);
    if (uid == null || uid.isEmpty) {
      uid = 'anon_${DateTime.now().millisecondsSinceEpoch}_${(1000 + (DateTime.now().microsecond % 9000))}';
      await prefs.setString(_anonUserIdKey, uid);
    }
    return uid;
  }

  @override
  Future<List<PriceReport>> getPriceReports() async {
    if (_cachedReports != null) return _cachedReports!;

    // 1. Load seed reports
    final String raw = await rootBundle.loadString(
      'assets/data/price_reports.json',
    );
    final List<dynamic> seedList = jsonDecode(raw) as List<dynamic>;
    final reports = seedList
        .map((e) => PriceReport.fromJson(e as Map<String, dynamic>))
        .toList();

    // 2. Load locally persisted user reports
    final prefs = await SharedPreferences.getInstance();
    final String? userJson = prefs.getString(_userPriceReportsKey);
    if (userJson != null && userJson.isNotEmpty) {
      final List<dynamic> userList = jsonDecode(userJson) as List<dynamic>;
      final userReports = userList
          .map((e) => PriceReport.fromJson(e as Map<String, dynamic>))
          .toList();
      reports.insertAll(0, userReports);
    }

    // 3. Fetch remote reports from proxy if available
    try {
      final proxyUrl = Uri.parse('${ApiConfig.proxyBaseUrl}/reports');
      final res = await http.get(proxyUrl).timeout(const Duration(seconds: 2));
      if (res.statusCode == 200) {
        final body = jsonDecode(res.body);
        if (body is Map && body['reports'] is List) {
          final remoteList = (body['reports'] as List)
              .map((e) => PriceReport.fromJson(e as Map<String, dynamic>))
              .toList();
          for (final rem in remoteList) {
            if (!reports.any((r) => r.id == rem.id)) {
              reports.insert(0, rem);
            }
          }
        }
      }
    } catch (_) {
      // Offline fallback
    }

    _cachedReports = reports;
    return _cachedReports!;
  }

  @override
  Future<void> submitPriceReport(PriceReport report) async {
    final prefs = await SharedPreferences.getInstance();
    final userId = report.userId ?? await getAnonymousUserId();
    final allReports = await getPriceReports();

    // 1. Price Sanity Validation
    final priceCheck = ReportSecurityValidator.validatePriceSanity(
      report.serviceType,
      report.pricePaid,
    );
    if (!priceCheck.isValid) {
      throw ArgumentError(priceCheck.errorMessage ?? 'Invalid price submitted');
    }

    // 2. Daily Rate Limit per User (max 20/day)
    if (!ReportSecurityValidator.checkDailyRateLimit(userId, allReports)) {
      throw StateError('Daily limit reached: Maximum 20 reports permitted per day.');
    }

    // 3. Deduplication Check (same route/place within 10 minutes)
    if (ReportSecurityValidator.isDuplicateReport(report, allReports)) {
      throw StateError('Duplicate submission: A similar report was submitted within the last 10 minutes.');
    }

    // 4. Calculate Account Trust Weight (0.5 for new user, 1.0 for consistent user)
    final weight = ReportSecurityValidator.calculateUserWeight(userId, allReports);

    // 5. Sanitize Text Fields (strip URLs, redact Phone/Email, strip control chars)
    final sanitizedRoute = ReportSecurityValidator.sanitizeReportText(report.routeOrPlace, maxLength: 200);
    final sanitizedNotes = report.notes != null
        ? ReportSecurityValidator.sanitizeReportText(report.notes, maxLength: 500)
        : null;

    // 6. Round GPS Coordinates to ~100m for privacy
    final roundedPickupLat = ReportSecurityValidator.roundCoordinate(report.pickupLat);
    final roundedPickupLng = ReportSecurityValidator.roundCoordinate(report.pickupLng);
    final roundedDropLat = ReportSecurityValidator.roundCoordinate(report.dropLat);
    final roundedDropLng = ReportSecurityValidator.roundCoordinate(report.dropLng);

    final hardenedReport = report.copyWith(
      userId: userId,
      weight: weight,
      routeOrPlace: sanitizedRoute,
      notes: sanitizedNotes,
      pickupLat: roundedPickupLat,
      pickupLng: roundedPickupLng,
      dropLat: roundedDropLat,
      dropLng: roundedDropLng,
    );

    // Optimistic local update: insert immediately at the top
    allReports.insert(0, hardenedReport);
    _cachedReports = allReports;

    final String? existingUser = prefs.getString(_userPriceReportsKey);
    List<dynamic> userList = [];
    if (existingUser != null && existingUser.isNotEmpty) {
      userList = jsonDecode(existingUser) as List<dynamic>;
    }
    userList.insert(0, hardenedReport.toJson());
    await prefs.setString(_userPriceReportsKey, jsonEncode(userList));

    // Submit to proxy server
    try {
      final proxyUrl = Uri.parse('${ApiConfig.proxyBaseUrl}/reports');
      final payload = jsonEncode({
        'serviceType': hardenedReport.serviceType.name,
        'vehicleType': hardenedReport.vehicleType,
        'routeOrPlace': hardenedReport.routeOrPlace,
        'pricePaid': hardenedReport.pricePaid,
        'areaId': hardenedReport.areaId,
        'status': hardenedReport.status,
        'createdAt': hardenedReport.createdAt.toIso8601String(),
        'wasFair': hardenedReport.wasFair,
        'notes': hardenedReport.notes,
        'userId': hardenedReport.userId,
        'pickupLat': hardenedReport.pickupLat,
        'pickupLng': hardenedReport.pickupLng,
        'dropLat': hardenedReport.dropLat,
        'dropLng': hardenedReport.dropLng,
      });

      final res = await http.post(
        proxyUrl,
        headers: {'Content-Type': 'application/json'},
        body: payload,
      ).timeout(const Duration(seconds: 4));

      if (res.statusCode >= 400 && res.body.isNotEmpty) {
        // Rollback optimistic update on server validation error
        allReports.remove(hardenedReport);
        userList.removeWhere((u) => u['id'] == hardenedReport.id);
        await prefs.setString(_userPriceReportsKey, jsonEncode(userList));

        String errorMessage = 'Failed to submit report';
        try {
          final errBody = jsonDecode(res.body);
          if (errBody is Map && errBody['reason'] != null) {
            errorMessage = errBody['reason'].toString();
          } else if (errBody is Map && errBody['error'] != null) {
            errorMessage = errBody['error'].toString();
          }
        } catch (_) {}
        throw StateError(errorMessage);
      }
    } catch (e) {
      if (e is StateError) rethrow;
      // Network timeout / offline: allow optimistic offline save to persist
    }
  }

  @override
  Future<void> flagReport(String reportId) async {
    final prefs = await SharedPreferences.getInstance();
    final allReports = await getPriceReports();

    final idx = allReports.indexWhere((r) => r.id == reportId);
    if (idx != -1) {
      final updated = allReports[idx].copyWith(
        isFlagged: true,
        flagCount: allReports[idx].flagCount + 1,
      );
      allReports[idx] = updated;

      // Update in user list if present
      final String? existingUser = prefs.getString(_userPriceReportsKey);
      if (existingUser != null && existingUser.isNotEmpty) {
        final List<dynamic> userList = jsonDecode(existingUser) as List<dynamic>;
        final userIdx = userList.indexWhere((u) => u['id'] == reportId);
        if (userIdx != -1) {
          userList[userIdx] = updated.toJson();
          await prefs.setString(_userPriceReportsKey, jsonEncode(userList));
        }
      }
    }
  }

  @override
  Future<List<TouristTrap>> getTouristTraps() async {
    if (_cachedTraps != null) return _cachedTraps!;

    final String raw = await rootBundle.loadString(
      'assets/data/tourist_traps.json',
    );
    final List<dynamic> seedList = jsonDecode(raw) as List<dynamic>;
    final traps = seedList
        .map((e) => TouristTrap.fromJson(e as Map<String, dynamic>))
        .toList();

    final prefs = await SharedPreferences.getInstance();
    final String? userJson = prefs.getString(_userTrapsKey);
    if (userJson != null && userJson.isNotEmpty) {
      final List<dynamic> userList = jsonDecode(userJson) as List<dynamic>;
      final userTraps = userList
          .map((e) => TouristTrap.fromJson(e as Map<String, dynamic>))
          .toList();
      traps.insertAll(0, userTraps);
    }

    _cachedTraps = traps;
    return _cachedTraps!;
  }

  @override
  Future<void> submitTouristTrap(TouristTrap trap) async {
    final prefs = await SharedPreferences.getInstance();
    final traps = await getTouristTraps();

    // Sanitize trap text and round coordinates
    final sanitizedDesc = ReportSecurityValidator.sanitizeReportText(trap.description, maxLength: 500);
    final sanitizedAvoid = ReportSecurityValidator.sanitizeReportText(trap.avoidTip, maxLength: 500);
    final roundedLat = ReportSecurityValidator.roundCoordinate(trap.latitude) ?? trap.latitude;
    final roundedLng = ReportSecurityValidator.roundCoordinate(trap.longitude) ?? trap.longitude;

    final hardenedTrap = TouristTrap(
      id: trap.id,
      latitude: roundedLat,
      longitude: roundedLng,
      radiusMeters: trap.radiusMeters,
      serviceType: trap.serviceType,
      type: trap.type,
      description: sanitizedDesc,
      avoidTip: sanitizedAvoid,
      severity: trap.severity,
      reportCount: trap.reportCount,
      lastReported: trap.lastReported,
      source: trap.source,
    );

    traps.insert(0, hardenedTrap);

    final String? existingUser = prefs.getString(_userTrapsKey);
    List<dynamic> userList = [];
    if (existingUser != null && existingUser.isNotEmpty) {
      userList = jsonDecode(existingUser) as List<dynamic>;
    }
    userList.insert(0, hardenedTrap.toJson());
    await prefs.setString(_userTrapsKey, jsonEncode(userList));
  }

  @override
  Future<void> flagTrap(String trapId) async {
    // Increment local flag count on trap
    final allTraps = await getTouristTraps();
    final idx = allTraps.indexWhere((t) => t.id == trapId);
    if (idx != -1) {
      final t = allTraps[idx];
      allTraps[idx] = TouristTrap(
        id: t.id,
        latitude: t.latitude,
        longitude: t.longitude,
        radiusMeters: t.radiusMeters,
        serviceType: t.serviceType,
        type: t.type,
        description: t.description,
        avoidTip: t.avoidTip,
        severity: t.severity,
        reportCount: max(0, t.reportCount - 1),
        lastReported: t.lastReported,
        source: 'flagged_review',
      );
    }
  }

  @override
  Future<List<AreaInsight>> getAreaInsights() async {
    if (_cachedAreaInsights != null) return _cachedAreaInsights!;

    final String raw = await rootBundle.loadString(
      'assets/data/area_insights.json',
    );
    final List<dynamic> seedList = jsonDecode(raw) as List<dynamic>;
    _cachedAreaInsights = seedList
        .map((e) => AreaInsight.fromJson(e as Map<String, dynamic>))
        .toList();
    return _cachedAreaInsights!;
  }

  @override
  Future<void> submitTakedownAppeal({
    required String entityName,
    required String reason,
    required String details,
    String? contactEmail,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final appeal = {
      'id': 'appeal_${DateTime.now().millisecondsSinceEpoch}',
      'entityName': ReportSecurityValidator.sanitizeReportText(entityName, maxLength: 100),
      'reason': ReportSecurityValidator.sanitizeReportText(reason, maxLength: 100),
      'details': ReportSecurityValidator.sanitizeReportText(details, maxLength: 500),
      'contactEmail': contactEmail?.trim() ?? '',
      'timestamp': DateTime.now().toIso8601String(),
      'status': 'submitted',
    };

    final raw = prefs.getString(_takedownAppealsKey);
    List<dynamic> list = [];
    if (raw != null && raw.isNotEmpty) {
      list = jsonDecode(raw) as List<dynamic>;
    }
    list.add(appeal);
    await prefs.setString(_takedownAppealsKey, jsonEncode(list));
  }

  @override
  Future<void> clearAllLocalData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    _cachedReports = null;
    _cachedTraps = null;
    _cachedAreaInsights = null;
  }

  @override
  Future<void> resetCommunityData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_userPriceReportsKey);
    await prefs.remove(_userTrapsKey);
    await prefs.remove(_takedownAppealsKey);
    _cachedReports = null;
    _cachedTraps = null;
    _cachedAreaInsights = null;
  }
}

final communityRepositoryProvider = Provider<CommunityRepository>((ref) {
  return LocalCommunityRepository();
});

final priceReportsFutureProvider = FutureProvider<List<PriceReport>>((
  ref,
) async {
  final repo = ref.watch(communityRepositoryProvider);
  return repo.getPriceReports();
});

final touristTrapsFutureProvider = FutureProvider<List<TouristTrap>>((
  ref,
) async {
  final repo = ref.watch(communityRepositoryProvider);
  return repo.getTouristTraps();
});

final areaInsightsFutureProvider = FutureProvider<List<AreaInsight>>((
  ref,
) async {
  final repo = ref.watch(communityRepositoryProvider);
  return repo.getAreaInsights();
});
