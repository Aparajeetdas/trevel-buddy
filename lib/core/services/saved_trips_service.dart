import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/roadmap_models.dart';

final savedTripsServiceProvider = Provider<SavedTripsService>((ref) {
  return SavedTripsService();
});

/// Service managing saved trips locally without storing proprietary route polylines
class SavedTripsService {
  static const String _savedTripsKey = 'travel_buddy_saved_trips_v1';

  Future<List<SavedTrip>> getSavedTrips() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_savedTripsKey);
      if (raw == null || raw.isEmpty) return [];
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .map((e) => SavedTrip.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> saveTrip(SavedTrip trip) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final trips = await getSavedTrips();
      trips.removeWhere((t) => t.id == trip.id);
      trips.insert(0, trip);
      final jsonList = trips.map((t) => t.toJson()).toList();
      await prefs.setString(_savedTripsKey, jsonEncode(jsonList));
    } catch (_) {}
  }

  Future<void> deleteTrip(String id) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final trips = await getSavedTrips();
      trips.removeWhere((t) => t.id == id);
      final jsonList = trips.map((t) => t.toJson()).toList();
      await prefs.setString(_savedTripsKey, jsonEncode(jsonList));
    } catch (_) {}
  }

  String formatShareText(
    RoadmapOption option,
    RoadmapLocation origin,
    RoadmapLocation dest,
  ) {
    final buffer = StringBuffer();
    buffer.writeln('🗺️ Travel Buddy Roadmap: ${origin.name} ➔ ${dest.name}');
    buffer.writeln('⏱️ Estimated Time: ~${option.totalMin.round()} mins');
    buffer.writeln(
      '💰 Fair Price Range: ₹${option.totalFairMin.round()} - ₹${option.totalFairMax.round()}',
    );
    buffer.writeln('🛡️ Overcharging Risk: ${option.riskLevel.label}');
    buffer.writeln('\nStep-by-Step Directions:');
    for (final step in option.steps) {
      buffer.writeln(
        '${step.index}. [${step.mode.toUpperCase()}] ${step.title}',
      );
      buffer.writeln('   👉 ${step.instruction}');
      if (step.boardingPoint.isNotEmpty) {
        buffer.writeln('   📍 Board at: ${step.boardingPoint}');
      }
      if (step.fairMax > 0) {
        buffer.writeln(
          '   💵 Fair: ₹${step.fairMin.round()}-₹${step.fairMax.round()} (Max: ₹${step.dontPayMoreThan.round()})',
        );
      }
    }
    buffer.writeln('\nStay protected with Travel Buddy India! 🇮🇳');
    return buffer.toString();
  }
}
