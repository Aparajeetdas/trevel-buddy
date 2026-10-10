import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/data/community_repository.dart';
import '../../../../core/data/tariff_repository.dart';
import '../../../../core/models/app_models.dart';
import '../../../../core/services/google_maps_service.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/pricing_engine.dart';
import '../../../../core/widgets/app_brand_app_bar.dart';
import 'price_check_result_screen.dart';
import 'widgets/price_input_adaptive_fields.dart';
import 'widgets/price_quick_presets.dart';
import 'widgets/price_route_autocomplete_field.dart';

/// Hero Feature: "Check a Price Before You Pay" input form with Google Places Autocomplete
class CheckPriceInputScreen extends ConsumerStatefulWidget {
  final String? initialPlaceName;

  const CheckPriceInputScreen({super.key, this.initialPlaceName});

  @override
  ConsumerState<CheckPriceInputScreen> createState() =>
      _CheckPriceInputScreenState();
}

class _CheckPriceInputScreenState extends ConsumerState<CheckPriceInputScreen> {
  ServiceType _selectedType = ServiceType.auto;
  final TextEditingController _pickupController = TextEditingController();
  final TextEditingController _dropController = TextEditingController();
  final TextEditingController _quotedController = TextEditingController();
  final TextEditingController _driverOrBizController = TextEditingController();

  final int _passengers = 1;
  double _guideHours = 2.0;
  int _guideGroupSize = 2;
  int _mealPeople = 2;
  int _roomNights = 1;
  bool _meterUsed = false;
  bool _isNightTime = false;
  bool _isLoading = false;
  GoogleRouteResult? _computedRoute;

  @override
  void initState() {
    super.initState();
    if (widget.initialPlaceName != null &&
        widget.initialPlaceName!.isNotEmpty) {
      _dropController.text = widget.initialPlaceName!;
    }
  }

  @override
  void dispose() {
    _pickupController.dispose();
    _dropController.dispose();
    _quotedController.dispose();
    _driverOrBizController.dispose();
    super.dispose();
  }

  Future<void> _checkRouteComputation() async {
    if (_pickupController.text.isNotEmpty &&
        _dropController.text.isNotEmpty &&
        _isRideType()) {
      final service = ref.read(googleMapsServiceProvider);
      // Compute with sample/resolved coordinates
      final route = await service.computeRoute(
        originLat: 26.9200,
        originLng: 75.7878,
        destLat: 26.9239,
        destLng: 75.8267,
      );
      if (mounted) setState(() => _computedRoute = route);
    }
  }

  Future<void> _evaluatePrice() async {
    final quoted = double.tryParse(_quotedController.text.trim());
    if (quoted == null || quoted <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid quoted price in ₹')),
      );
      return;
    }

    setState(() => _isLoading = true);

    final tariffs = await ref.read(govTariffRepositoryProvider).getTariffs();
    final reports = await ref
        .read(communityRepositoryProvider)
        .getPriceReports();
    final traps = await ref.read(communityRepositoryProvider).getTouristTraps();

    await Future.delayed(const Duration(milliseconds: 350));
    if (!mounted) return;

    final cityMatch = _dropController.text.isNotEmpty
        ? _dropController.text
        : 'Jaipur';
    final tariff =
        tariffs.where((t) {
          final matchesService = t.serviceType == _selectedType;
          final matchesCity = cityMatch.toLowerCase().contains(
            t.city.toLowerCase(),
          );
          return matchesService && matchesCity;
        }).firstOrNull ??
        tariffs.where((t) => t.serviceType == _selectedType).firstOrNull;

    final now = DateTime.now();
    final effectiveTime = _isNightTime
        ? DateTime(now.year, now.month, now.day, 23, 30)
        : now;

    final input = PriceCheckInput(
      serviceType: _selectedType,
      pickupName: _pickupController.text.trim().isNotEmpty
          ? _pickupController.text.trim()
          : 'Pickup Hub',
      dropName: _dropController.text.trim().isNotEmpty
          ? _dropController.text.trim()
          : 'Destination',
      distanceKm: _computedRoute?.distanceKm,
      durationMinutes: _computedRoute?.durationMinutes,
      quotedPrice: quoted,
      timeOfDay: effectiveTime,
      passengers: _passengers,
      hours: _guideHours,
      groupSize: _guideGroupSize,
      mealPeople: _mealPeople,
      roomNights: _roomNights,
      meterUsed: _meterUsed,
      driverOrBusinessName: _driverOrBizController.text.trim(),
    );

    final result = PricingEngine.evaluate(
      input: input,
      tariff: tariff,
      reports: reports,
      traps: traps,
    );

    setState(() => _isLoading = false);

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PriceCheckResultScreen(result: result, input: input),
      ),
    );
  }

  void _applyQuickPreset(
    ServiceType type,
    String pickup,
    String drop,
    double quote,
  ) {
    setState(() {
      _selectedType = type;
      _pickupController.text = pickup;
      _dropController.text = drop;
      _quotedController.text = quote.toStringAsFixed(0);
    });
    _checkRouteComputation();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: const AppBrandAppBar(
        title: 'Check a Price Before You Pay',
        showBackButton: true,
      ),
      body: _isLoading
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text(
                    'Analyzing with Google Places, Tariffs & Community Benchmarks...',
                  ),
                ],
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Service Type Selector Chips
                  Text(
                    'Select Service Type',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: ServiceType.values.map((type) {
                        final isSel = _selectedType == type;
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(
                            avatar: Icon(
                              type.icon,
                              size: 16,
                              color: isSel ? Colors.white : AppColors.primary,
                            ),
                            label: Text(type.displayName),
                            selected: isSel,
                            selectedColor: AppColors.primary,
                            labelStyle: TextStyle(
                              color: isSel ? Colors.white : null,
                              fontWeight: isSel
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                            ),
                            onSelected: (_) =>
                                setState(() => _selectedType = type),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),

                  // Quoted Price Field
                  TextField(
                    controller: _quotedController,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                    ),
                    decoration: InputDecoration(
                      labelText: 'Quoted Price in Rupees *',
                      prefixText: '₹ ',
                      prefixStyle: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: AppColors.primary,
                      ),
                      hintText: 'e.g. 250',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppRadius.md),
                      ),
                      filled: true,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),

                  // Google Places Autocomplete Fields
                  PriceRouteAutocompleteField(
                    controller: _pickupController,
                    label: _isRideType()
                        ? 'Pickup Location / Station *'
                        : 'City or Area *',
                    hint: 'Type landmark or station...',
                    icon: Icons.my_location_rounded,
                    onPlaceSelected: (_) => _checkRouteComputation(),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  PriceRouteAutocompleteField(
                    controller: _dropController,
                    label: _isRideType()
                        ? 'Destination / Place *'
                        : 'Venue / Monument *',
                    hint: 'Type destination or hotel...',
                    icon: Icons.location_on_rounded,
                    iconColor: AppColors.danger,
                    onPlaceSelected: (_) => _checkRouteComputation(),
                  ),
                  const SizedBox(height: AppSpacing.sm),

                  // Live Route Estimation Tag
                  if (_computedRoute != null && _isRideType())
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primaryContainer.withOpacity(0.5),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.alt_route_rounded,
                            size: 16,
                            color: AppColors.primary,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Routes API: ${_computedRoute!.distanceKm.toStringAsFixed(1)} km • ~${_computedRoute!.durationMinutes.round()} mins',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: AppColors.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: AppSpacing.md),

                  // Adaptive Parameters
                  PriceInputAdaptiveFields(
                    serviceType: _selectedType,
                    isNightTime: _isNightTime,
                    meterUsed: _meterUsed,
                    guideHours: _guideHours,
                    guideGroupSize: _guideGroupSize,
                    mealPeople: _mealPeople,
                    roomNights: _roomNights,
                    onNightTimeChanged: (val) =>
                        setState(() => _isNightTime = val),
                    onMeterUsedChanged: (val) =>
                        setState(() => _meterUsed = val),
                    onGuideHoursChanged: (val) =>
                        setState(() => _guideHours = val),
                    onGuideGroupSizeChanged: (val) =>
                        setState(() => _guideGroupSize = val),
                    onMealPeopleChanged: (val) =>
                        setState(() => _mealPeople = val),
                    onRoomNightsChanged: (val) =>
                        setState(() => _roomNights = val),
                  ),
                  const SizedBox(height: AppSpacing.md),

                  // Quick Presets
                  PriceQuickPresets(onSelect: _applyQuickPreset),
                  const SizedBox(height: AppSpacing.lg),

                  // Check Button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _evaluatePrice,
                      icon: const Icon(Icons.speed_rounded),
                      label: const Text('Check Fair Price Verdict'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        textStyle: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  bool _isRideType() =>
      _selectedType == ServiceType.auto ||
      _selectedType == ServiceType.taxi ||
      _selectedType == ServiceType.bikeTaxi;
}
