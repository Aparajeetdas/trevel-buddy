import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/models/app_models.dart';
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

  const PriceRouteAutocompleteField({
    super.key,
    required this.controller,
    required this.label,
    required this.hint,
    required this.icon,
    this.iconColor = AppColors.primary,
    this.onPlaceSelected,
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

  void _selectSuggestion(GooglePlaceSuggestion s) {
    widget.controller.text = s.mainText;
    setState(() {
      _suggestions = [];
      _showDropdown = false;
    });
    FocusScope.of(context).unfocus();
    widget.onPlaceSelected?.call(s.mainText);
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
              children: _suggestions.map((s) {
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
              }).toList(),
            ),
          ),
      ],
    );
  }
}
