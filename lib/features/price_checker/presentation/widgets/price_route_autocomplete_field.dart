import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/models/app_models.dart';
import '../../../../core/models/roadmap_models.dart';
import '../../../../core/services/google_maps_service.dart';
import '../../../../core/theme/app_theme.dart';

/// Autocomplete input with live Google Places (New) suggestions
class PriceRouteAutocompleteField extends ConsumerStatefulWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  final IconData icon;
  final Color iconColor;
  final ValueChanged<String>? onPlaceSelected;
  final ValueChanged<RoadmapLocation>? onLocationSelected;
  final bool allowMyLocation;

  const PriceRouteAutocompleteField({
    super.key,
    required this.controller,
    required this.label,
    required this.hint,
    required this.icon,
    this.iconColor = AppColors.primary,
    this.onPlaceSelected,
    this.onLocationSelected,
    this.allowMyLocation = false,
  });

  @override
  ConsumerState<PriceRouteAutocompleteField> createState() =>
      _PriceRouteAutocompleteFieldState();
}

class _PriceRouteAutocompleteFieldState
    extends ConsumerState<PriceRouteAutocompleteField> {
  List<GooglePlaceSuggestion> _suggestions = [];
  bool _showDropdown = false;

  void _onChanged(String val) async {
    if (val.trim().length < 2) {
      if (_suggestions.isNotEmpty) setState(() => _suggestions = []);
      return;
    }

    final service = ref.read(googleMapsServiceProvider);
    try {
      final results = await service.autocomplete(val);
      if (mounted) {
        setState(() {
          _suggestions = results;
          _showDropdown = _suggestions.isNotEmpty;
        });
      }
    } catch (_) {}
  }

  Future<void> _selectSuggestion(GooglePlaceSuggestion s) async {
    widget.controller.text = s.mainText;
    setState(() {
      _suggestions = [];
      _showDropdown = false;
    });
    FocusScope.of(context).unfocus();
    widget.onPlaceSelected?.call(s.mainText);

    if (widget.onLocationSelected != null) {
      try {
        final details =
            await ref.read(googleMapsServiceProvider).getPlaceDetails(s.placeId);
        final loc = RoadmapLocation(
          placeId: details.placeId,
          name: details.name,
          formattedAddress: details.formattedAddress,
          lat: details.latitude,
          lng: details.longitude,
          isMyLocation: false,
        );
        widget.onLocationSelected!(loc);
      } catch (_) {
        widget.onLocationSelected!(
          RoadmapLocation(
            placeId: s.placeId,
            name: s.mainText,
            formattedAddress: s.secondaryText,
            lat: 0.0,
            lng: 0.0,
          ),
        );
      }
    }
  }

  void _selectMyLocation() {
    widget.controller.text = 'My location';
    setState(() {
      _suggestions = [];
      _showDropdown = false;
    });
    FocusScope.of(context).unfocus();
    widget.onPlaceSelected?.call('My location');
    widget.onLocationSelected?.call(
      const RoadmapLocation(
        name: 'My location',
        lat: 0.0,
        lng: 0.0,
        isMyLocation: true,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: widget.controller,
          onChanged: _onChanged,
          decoration: InputDecoration(
            labelText: widget.label,
            hintText: widget.hint,
            prefixIcon: Icon(widget.icon, color: widget.iconColor),
            suffixIcon: widget.controller.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear, size: 18),
                    onPressed: () {
                      widget.controller.clear();
                      setState(() {
                        _suggestions = [];
                        _showDropdown = false;
                      });
                    },
                  )
                : null,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            filled: true,
            fillColor: theme.cardColor,
          ),
        ),
        if (_showDropdown && _suggestions.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(top: 4),
            decoration: BoxDecoration(
              color: theme.cardColor,
              borderRadius: BorderRadius.circular(8),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.15),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
              border: Border.all(
                color: theme.brightness == Brightness.dark
                    ? AppColors.outlineDark
                    : AppColors.outlineLight,
              ),
            ),
            child: Column(
              children: [
                if (widget.allowMyLocation)
                  ListTile(
                    dense: true,
                    leading: const Icon(
                      Icons.my_location_rounded,
                      size: 18,
                      color: AppColors.primary,
                    ),
                    title: const Text(
                      'Use My Current Location',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                        color: AppColors.primary,
                      ),
                    ),
                    onTap: _selectMyLocation,
                  ),
                ..._suggestions.map((s) {
                return ListTile(
                  dense: true,
                  leading: const Icon(
                    Icons.place_rounded,
                    size: 18,
                    color: AppColors.primary,
                  ),
                  title: Text(
                    s.mainText,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                  subtitle: s.secondaryText.isNotEmpty
                      ? Text(
                          s.secondaryText,
                          style: const TextStyle(fontSize: 11),
                        )
                      : null,
                  onTap: () => _selectSuggestion(s),
                );
              }),
            ]),
          ),
      ],
    );
  }
}
