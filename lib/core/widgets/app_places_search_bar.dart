import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/app_models.dart';
import '../services/google_maps_service.dart';
import '../theme/app_theme.dart';

class RecentPlaceItem {
  final String id;
  final String name;

  const RecentPlaceItem({required this.id, required this.name});

  Map<String, dynamic> toJson() => {'id': id, 'name': name};

  factory RecentPlaceItem.fromJson(Map<String, dynamic> json) => RecentPlaceItem(
    id: json['id'] as String? ?? '',
    name: json['name'] as String? ?? '',
  );
}

/// Shared responsive search bar with Google Places (New) autocomplete,
/// out-of-order race protection, 250ms debounce, recent searches,
/// free-form text search, and graceful offline fallback.
class AppPlacesSearchBar extends ConsumerStatefulWidget {
  final ValueChanged<GooglePlaceDetails> onPlaceSelected;
  final ValueChanged<GooglePlaceDetails>? onCitySelected;
  final VoidCallback? onUseMyLocation;
  final String hintText;
  final LatLng? biasCenter;
  final bool showRecentsInitially;

  const AppPlacesSearchBar({
    super.key,
    required this.onPlaceSelected,
    this.onCitySelected,
    this.onUseMyLocation,
    this.hintText = 'Search any city, landmark, or place worldwide...',
    this.biasCenter,
    this.showRecentsInitially = true,
  });

  @override
  ConsumerState<AppPlacesSearchBar> createState() => _AppPlacesSearchBarState();
}

class _AppPlacesSearchBarState extends ConsumerState<AppPlacesSearchBar> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  static const String _recentSearchesKey = 'travel_buddy_recent_places_v4';
  List<RecentPlaceItem> _recentSearches = [];

  Timer? _debounceTimer;
  int _latestRequestId = 0;

  bool _isLoading = false;
  bool _hasError = false;
  String? _errorMessage;

  List<GooglePlaceSuggestion> _suggestions = [];
  List<GooglePlaceDetails> _textSearchResults = [];
  int _textSearchVisibleCount = 6;
  SearchRankFilter _activeFilter = SearchRankFilter.all;

  bool _isCountryOnly = false;

  static final RegExp _coordRegex = RegExp(
    r'^\s*(-?\d{1,2}(?:\.\d+)?)\s*,\s*(-?\d{1,3}(?:\.\d+)?)\s*$',
  );

  bool _isGoogleMapsUrl(String text) {
    final lower = text.trim().toLowerCase();
    return lower.contains('maps.app.goo.gl') ||
        lower.contains('goo.gl/maps') ||
        lower.contains('google.com/maps') ||
        lower.contains('maps.google.com');
  }

  List<GooglePlaceSuggestion> get _rankedSuggestions {
    if (_activeFilter == SearchRankFilter.all ||
        _activeFilter.category == null) {
      return _suggestions;
    }
    final target = _activeFilter.category!;
    final matching = _suggestions
        .where((s) => s.categoryType == target)
        .toList();
    final nonMatching = _suggestions
        .where((s) => s.categoryType != target)
        .toList();
    return [...matching, ...nonMatching];
  }

  List<GooglePlaceDetails> get _rankedTextSearchResults {
    if (_activeFilter == SearchRankFilter.all ||
        _activeFilter.category == null) {
      return _textSearchResults;
    }
    final target = _activeFilter.category!;
    final matching = _textSearchResults
        .where((p) => p.categoryType == target)
        .toList();
    final nonMatching = _textSearchResults
        .where((p) => p.categoryType != target)
        .toList();
    return [...matching, ...nonMatching];
  }

  @override
  void initState() {
    super.initState();
    _loadRecents();
    _focusNode.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _loadRecents() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = prefs.getStringList(_recentSearchesKey) ?? [];
      final parsed = list.map((item) {
        try {
          return RecentPlaceItem.fromJson(jsonDecode(item) as Map<String, dynamic>);
        } catch (_) {
          return RecentPlaceItem(id: '', name: item);
        }
      }).where((r) => r.name.isNotEmpty).toList();
      if (mounted) setState(() => _recentSearches = parsed);
    } catch (_) {}
  }

  Future<void> _addRecent(String name, {String id = ''}) async {
    final clean = name.trim();
    if (clean.isEmpty) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      _recentSearches.removeWhere(
        (r) =>
            r.name.toLowerCase() == clean.toLowerCase() ||
            (id.isNotEmpty && r.id == id),
      );
      _recentSearches.insert(0, RecentPlaceItem(id: id, name: clean));
      if (_recentSearches.length > 8) {
        _recentSearches = _recentSearches.sublist(0, 8);
      }
      final encoded =
          _recentSearches.map((r) => jsonEncode(r.toJson())).toList();
      await prefs.setStringList(_recentSearchesKey, encoded);
      if (mounted) setState(() {});
    } catch (_) {}
  }

  Future<void> _clearRecents() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_recentSearchesKey);
      if (mounted) setState(() => _recentSearches = []);
    } catch (_) {}
  }

  void _onQueryChanged(String text) {
    _debounceTimer?.cancel();
    final query = text.trim();

    // 1. Detect coordinates 'lat, lng'
    final coordMatch = _coordRegex.firstMatch(query);
    if (coordMatch != null) {
      final lat = double.tryParse(coordMatch.group(1)!);
      final lng = double.tryParse(coordMatch.group(2)!);
      if (lat != null &&
          lng != null &&
          lat >= -90 &&
          lat <= 90 &&
          lng >= -180 &&
          lng <= 180) {
        setState(() {
          _suggestions = [
            GooglePlaceSuggestion(
              placeId: 'coord_${lat}_$lng',
              mainText:
                  'Coordinates: ${lat.toStringAsFixed(4)}, ${lng.toStringAsFixed(4)}',
              secondaryText: 'Tap to reverse geocode & view place details',
              types: const ['point_of_interest'],
            ),
          ];
          _isLoading = false;
        });
        return;
      }
    }

    // 2. Detect pasted Google Maps short link
    if (_isGoogleMapsUrl(query)) {
      setState(() {
        _suggestions = [
          GooglePlaceSuggestion(
            placeId: 'url_${query.hashCode}',
            mainText: 'Inspect Google Maps Link',
            secondaryText: query,
            types: const ['tourist_attraction'],
          ),
        ];
        _isLoading = false;
      });
      return;
    }

    if (query.length < 2) {
      setState(() {
        _suggestions = [];
        _textSearchResults = [];
        _isLoading = false;
        _hasError = false;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _hasError = false;
      _textSearchResults = [];
    });

    final currentId = ++_latestRequestId;
    _debounceTimer = Timer(const Duration(milliseconds: 250), () async {
      await _executeAutocomplete(query, currentId);
    });
  }

  Future<void> _executeAutocomplete(String query, int requestId) async {
    final mapsService = ref.read(googleMapsServiceProvider);

    try {
      final results = await mapsService.autocomplete(
        query,
        biasCenter: widget.biasCenter,
        searchInCountryOnly: _isCountryOnly,
      );

      // Discard out-of-order responses
      if (requestId != _latestRequestId || !mounted) return;

      setState(() {
        _suggestions = results;
        _isLoading = false;
        _hasError = false;
      });
    } catch (e) {
      if (requestId != _latestRequestId || !mounted) return;
      setState(() {
        _hasError = true;
        _errorMessage = 'Could not connect to search service.';
        _isLoading = false;
      });
    }
  }

  Future<void> _onSubmitted(String rawQuery) async {
    final query = rawQuery.trim();
    if (query.isEmpty) return;
    _debounceTimer?.cancel();
    _focusNode.unfocus();
    await _addRecent(query);

    // Coordinate search on submit
    final coordMatch = _coordRegex.firstMatch(query);
    if (coordMatch != null) {
      final lat = double.tryParse(coordMatch.group(1)!);
      final lng = double.tryParse(coordMatch.group(2)!);
      if (lat != null && lng != null) {
        _resolveCoordinates(lat, lng);
        return;
      }
    }

    // Link resolution on submit
    if (_isGoogleMapsUrl(query)) {
      _resolveLink(query);
      return;
    }

    setState(() {
      _isLoading = true;
      _hasError = false;
      _suggestions = [];
      _textSearchResults = [];
      _textSearchVisibleCount = 6;
    });

    final currentId = ++_latestRequestId;
    final mapsService = ref.read(googleMapsServiceProvider);

    try {
      final places = await mapsService.textSearch(
        query,
        biasCenter: widget.biasCenter,
        searchInCountryOnly: _isCountryOnly,
        maxResultCount: 20,
      );

      if (currentId != _latestRequestId || !mounted) return;

      if (places.isNotEmpty) {
        setState(() {
          _textSearchResults = places;
          _isLoading = false;
        });
      } else {
        // Try autocomplete fallback
        await _executeAutocomplete(query, currentId);
      }
    } catch (_) {
      if (currentId != _latestRequestId || !mounted) return;
      setState(() {
        _hasError = true;
        _errorMessage = 'Free-form search failed. Please try again.';
        _isLoading = false;
      });
    }
  }

  Future<void> _resolveCoordinates(double lat, double lng) async {
    setState(() => _isLoading = true);
    final mapsService = ref.read(googleMapsServiceProvider);
    try {
      final resolved = await mapsService.reverseGeocode(lat, lng);
      if (!mounted) return;
      setState(() => _isLoading = false);
      if (resolved != null) {
        _selectDetails(resolved);
      } else {
        final fallback = GooglePlaceDetails(
          placeId: 'coord_${lat}_$lng',
          name:
              'Location (${lat.toStringAsFixed(4)}, ${lng.toStringAsFixed(4)})',
          formattedAddress: 'Latitude: $lat, Longitude: $lng',
          latitude: lat,
          longitude: lng,
          fetchedAt: DateTime.now(),
          isLiveGoogle: true,
        );
        _selectDetails(fallback);
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  Future<void> _resolveLink(String link) async {
    setState(() => _isLoading = true);
    final mapsService = ref.read(googleMapsServiceProvider);
    try {
      final details = await mapsService.resolveLink(link);
      if (!mounted) return;
      setState(() => _isLoading = false);
      if (details != null) {
        _selectDetails(details);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not resolve Google Maps URL.')),
        );
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  Future<void> _selectSuggestion(GooglePlaceSuggestion suggestion) async {
    await _addRecent(suggestion.mainText, id: suggestion.placeId);
    _focusNode.unfocus();

    if (suggestion.placeId.startsWith('coord_')) {
      final coordMatch = _coordRegex.firstMatch(_controller.text);
      if (coordMatch != null) {
        final lat = double.parse(coordMatch.group(1)!);
        final lng = double.parse(coordMatch.group(2)!);
        _resolveCoordinates(lat, lng);
        return;
      }
    }

    if (suggestion.placeId.startsWith('url_') ||
        _isGoogleMapsUrl(_controller.text)) {
      _resolveLink(_controller.text);
      return;
    }

    setState(() {
      _controller.text = suggestion.mainText;
      _suggestions = [];
      _textSearchResults = [];
      _isLoading = true;
    });

    final mapsService = ref.read(googleMapsServiceProvider);

    try {
      final details = await mapsService.getPlaceDetails(suggestion.placeId);
      if (!mounted) return;
      setState(() => _isLoading = false);
      _selectDetails(details);
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  void _selectDetails(GooglePlaceDetails details) {
    _addRecent(details.name, id: details.placeId);
    _focusNode.unfocus();
    setState(() {
      _controller.text = details.name;
      _suggestions = [];
      _textSearchResults = [];
    });

    if (details.isCityOrRegion) {
      String? countryCode;
      for (final comp in details.addressComponents) {
        final types =
            (comp['types'] as List<dynamic>?)
                ?.map((t) => t.toString())
                .toList() ??
            [];
        if (types.contains('country')) {
          countryCode =
              comp['shortText'] as String? ?? comp['longText'] as String?;
          break;
        }
      }
      final activeCity = ActiveCity(
        name: details.name,
        placeId: details.placeId,
        centerLat: details.latitude,
        centerLng: details.longitude,
        countryCode: countryCode,
        viewport: details.viewport,
      );
      ref.read(activeCityProvider.notifier).setActiveCity(activeCity);
      widget.onCitySelected?.call(details);
    }

    widget.onPlaceSelected(details);
  }

  void _openVoiceSearchModal() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => _VoiceSearchSheet(
        onQuerySelected: (spoken) {
          _controller.text = spoken;
          _onSubmitted(spoken);
        },
      ),
    );
  }

  Future<void> _handleUseMyLocation() async {
    _focusNode.unfocus();
    if (widget.onUseMyLocation != null) {
      widget.onUseMyLocation!();
      return;
    }

    setState(() => _isLoading = true);
    try {
      Position? pos;
      try {
        LocationPermission permission = await Geolocator.checkPermission();
        if (permission == LocationPermission.denied) {
          permission = await Geolocator.requestPermission();
        }
        if (permission == LocationPermission.whileInUse ||
            permission == LocationPermission.always) {
          pos = await Geolocator.getCurrentPosition(
            locationSettings: const LocationSettings(
              accuracy: LocationAccuracy.medium,
            ),
          ).timeout(const Duration(seconds: 5));
        }
      } catch (geoError) {
        debugPrint('⚠️ [Location] Location timed out or unavailable: $geoError');
      }

      if (!mounted) return;
      setState(() => _isLoading = false);

      if (pos == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Could not access current location. Please choose or search a city.',
            ),
          ),
        );
        return;
      }

      final mapsService = ref.read(googleMapsServiceProvider);
      final details = await mapsService.reverseGeocode(
        pos.latitude,
        pos.longitude,
      );
      if (details != null && mounted) {
        widget.onPlaceSelected(details);
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  IconData _iconForCategory(SuggestionCategoryType type) {
    switch (type) {
      case SuggestionCategoryType.city:
        return Icons.location_city_rounded;
      case SuggestionCategoryType.area:
        return Icons.holiday_village_rounded;
      case SuggestionCategoryType.landmark:
        return Icons.fort_rounded;
      case SuggestionCategoryType.food:
        return Icons.restaurant_rounded;
      case SuggestionCategoryType.stay:
        return Icons.hotel_rounded;
      case SuggestionCategoryType.transport:
        return Icons.directions_transit_rounded;
      case SuggestionCategoryType.general:
        return Icons.place_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasInput = _controller.text.isNotEmpty;
    final isFocused = _focusNode.hasFocus || widget.showRecentsInitially;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. Text Field Box
        TextField(
          controller: _controller,
          focusNode: _focusNode,
          textInputAction: TextInputAction.search,
          onChanged: _onQueryChanged,
          onSubmitted: _onSubmitted,
          decoration: InputDecoration(
            hintText: widget.hintText,
            prefixIcon: const Icon(
              Icons.search_rounded,
              color: AppColors.primary,
            ),
            suffixIcon: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_isLoading)
                  const Padding(
                    padding: EdgeInsets.all(12),
                    child: SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                else if (hasInput)
                  IconButton(
                    icon: const Icon(Icons.clear_rounded, size: 20),
                    onPressed: () {
                      _controller.clear();
                      _onQueryChanged('');
                    },
                  ),
                IconButton(
                  icon: const Icon(
                    Icons.mic_rounded,
                    size: 20,
                    color: AppColors.primary,
                  ),
                  tooltip: 'Voice Search',
                  onPressed: _openVoiceSearchModal,
                ),
                PopupMenuButton<bool>(
                  icon: Icon(
                    _isCountryOnly ? Icons.flag_rounded : Icons.public_rounded,
                    size: 20,
                    color: _isCountryOnly ? AppColors.primary : Colors.grey,
                  ),
                  tooltip: 'Search scope',
                  onSelected: (val) {
                    setState(() => _isCountryOnly = val);
                    if (_controller.text.trim().isNotEmpty) {
                      _onQueryChanged(_controller.text);
                    }
                  },
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      value: false,
                      child: Row(
                        children: [
                          Icon(
                            Icons.public_rounded,
                            size: 18,
                            color: !_isCountryOnly
                                ? AppColors.primary
                                : Colors.grey,
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            'Search Worldwide (Default)',
                            style: TextStyle(fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: true,
                      child: Row(
                        children: [
                          Icon(
                            Icons.flag_rounded,
                            size: 18,
                            color: _isCountryOnly
                                ? AppColors.primary
                                : Colors.grey,
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            'Search in my country only',
                            style: TextStyle(fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),

        // 2. Re-Ranking Filter Chips (only re-ranks, never hides)
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: SearchRankFilter.values.map((filter) {
              final isSelected = _activeFilter == filter;
              return Padding(
                padding: const EdgeInsets.only(right: 6),
                child: FilterChip(
                  label: Text(filter.label),
                  selected: isSelected,
                  selectedColor: AppColors.primary.withOpacity(0.18),
                  checkmarkColor: AppColors.primary,
                  visualDensity: VisualDensity.compact,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  labelStyle: TextStyle(
                    fontSize: 11,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                    color: isSelected
                        ? AppColors.primary
                        : theme.textTheme.bodyMedium?.color,
                  ),
                  onSelected: (selected) {
                    setState(() {
                      _activeFilter = selected ? filter : SearchRankFilter.all;
                    });
                  },
                ),
              );
            }).toList(),
          ),
        ),

        // 3. Suggestions / Recents Dropdown
        if (isFocused ||
            _suggestions.isNotEmpty ||
            _textSearchResults.isNotEmpty ||
            _hasError)
          Container(
            margin: const EdgeInsets.only(top: 4),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.08),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Material(
              color: theme.cardColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: AppColors.primary.withOpacity(0.25)),
              ),
              clipBehavior: Clip.antiAlias,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Error State with Retry
                  if (_hasError)
                    Padding(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.cloud_off_rounded,
                            color: AppColors.danger,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _errorMessage ??
                                  'Network error. Check connection.',
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.danger,
                              ),
                            ),
                          ),
                          TextButton(
                            onPressed: () => _onQueryChanged(_controller.text),
                            child: const Text(
                              'Retry',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                  // Free-form Text Search Results
                  if (_textSearchResults.isNotEmpty) ...[
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
                      child: Text(
                        'Matching Places for "${_controller.text}"',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey,
                        ),
                      ),
                    ),
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _rankedTextSearchResults.length.clamp(
                        0,
                        _textSearchVisibleCount,
                      ),
                      separatorBuilder: (context, index) =>
                          const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final item = _rankedTextSearchResults[index];
                        return ListTile(
                          leading: const Icon(
                            Icons.place_rounded,
                            color: AppColors.primary,
                            size: 20,
                          ),
                          title: Text(
                            item.name,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                          subtitle: Text(
                            item.formattedAddress,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 11),
                          ),
                          trailing: item.rating != null
                              ? Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      Icons.star_rounded,
                                      size: 14,
                                      color: Colors.amber,
                                    ),
                                    Text(
                                      '${item.rating}',
                                      style: const TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                )
                              : null,
                          onTap: () => _selectDetails(item),
                        );
                      },
                    ),
                    if (_rankedTextSearchResults.length >
                        _textSearchVisibleCount)
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        child: Center(
                          child: OutlinedButton.icon(
                            onPressed: () {
                              setState(() {
                                _textSearchVisibleCount =
                                    (_textSearchVisibleCount + 6).clamp(
                                      0,
                                      _rankedTextSearchResults.length,
                                    );
                              });
                            },
                            icon: const Icon(
                              Icons.expand_more_rounded,
                              size: 16,
                            ),
                            label: Text(
                              'Load more results (${_rankedTextSearchResults.length - _textSearchVisibleCount} remaining)',
                              style: const TextStyle(fontSize: 12),
                            ),
                          ),
                        ),
                      ),
                  ],

                  // Autocomplete Suggestions
                  if (_suggestions.isNotEmpty)
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _rankedSuggestions.length,
                      separatorBuilder: (context, index) =>
                          const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final s = _rankedSuggestions[index];
                        final icon = _iconForCategory(s.categoryType);

                        return ListTile(
                          leading: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withOpacity(0.08),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              icon,
                              color: AppColors.primary,
                              size: 16,
                            ),
                          ),
                          title: Text(
                            s.mainText,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                          subtitle: s.secondaryText.isNotEmpty
                              ? Text(
                                  s.secondaryText,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                )
                              : null,
                          trailing: s.formattedDistance != null
                              ? Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.grey.withOpacity(0.12),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    s.formattedDistance!,
                                    style: const TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.grey,
                                    ),
                                  ),
                                )
                              : const Icon(
                                  Icons.arrow_forward_ios_rounded,
                                  size: 12,
                                  color: Colors.grey,
                                ),
                          onTap: () => _selectSuggestion(s),
                        );
                      },
                    ),

                  // No Results State
                  if (!_isLoading &&
                      !_hasError &&
                      hasInput &&
                      _suggestions.isEmpty &&
                      _textSearchResults.isEmpty &&
                      _controller.text.length >= 2)
                    Padding(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'No places found for "${_controller.text}".',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Tip: Press Enter / Search on keyboard for broad text search, or check spelling.',
                            style: TextStyle(fontSize: 11, color: Colors.grey),
                          ),
                          const SizedBox(height: 8),
                          ElevatedButton.icon(
                            onPressed: () => _onSubmitted(_controller.text),
                            icon: const Icon(Icons.search_rounded, size: 16),
                            label: Text(
                              'Run broad search for "${_controller.text}"',
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),

                  // Empty field state: "Use my location" + Recent Searches
                  if (!hasInput &&
                      _suggestions.isEmpty &&
                      _textSearchResults.isEmpty) ...[
                    ListTile(
                      leading: const Icon(
                        Icons.my_location_rounded,
                        color: AppColors.primary,
                        size: 20,
                      ),
                      title: const Text(
                        'Use my current location',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                      subtitle: const Text(
                        'Calculate routes and fair rates from here',
                        style: TextStyle(fontSize: 11, color: Colors.grey),
                      ),
                      onTap: _handleUseMyLocation,
                    ),
                    if (_recentSearches.isNotEmpty) ...[
                      const Divider(height: 1),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Recent searches',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: Colors.grey,
                              ),
                            ),
                            GestureDetector(
                              onTap: _clearRecents,
                              child: const Text(
                                'Clear',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: _recentSearches.map((rec) {
                          return Padding(
                            padding: const EdgeInsets.only(left: 12, bottom: 6),
                            child: ActionChip(
                              avatar: const Icon(
                                Icons.history_rounded,
                                size: 14,
                                color: AppColors.primary,
                              ),
                              label: Text(
                                rec.name,
                                style: const TextStyle(fontSize: 11),
                              ),
                              onPressed: () async {
                                if (rec.id.isNotEmpty && !rec.id.startsWith('coord_') && !rec.id.startsWith('url_')) {
                                  setState(() => _isLoading = true);
                                  try {
                                    final details = await ref
                                        .read(googleMapsServiceProvider)
                                        .getPlaceDetails(rec.id);
                                    if (mounted) {
                                      setState(() => _isLoading = false);
                                      _selectDetails(details);
                                      return;
                                    }
                                  } catch (_) {
                                    if (mounted) setState(() => _isLoading = false);
                                  }
                                }
                                _controller.text = rec.name;
                                _onSubmitted(rec.name);
                              },
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ],

                  // 3. Attribution footer
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      vertical: 6,
                      horizontal: 12,
                    ),
                    decoration: BoxDecoration(
                      color: theme.scaffoldBackgroundColor.withOpacity(0.5),
                      borderRadius: const BorderRadius.vertical(
                        bottom: Radius.circular(12),
                      ),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text(
                          'Powered by Google',
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.grey,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

/// Interactive Voice Search Modal with audio animation and spoken destination chips
class _VoiceSearchSheet extends StatefulWidget {
  final ValueChanged<String> onQuerySelected;

  const _VoiceSearchSheet({required this.onQuerySelected});

  @override
  State<_VoiceSearchSheet> createState() => _VoiceSearchSheetState();
}

class _VoiceSearchSheetState extends State<_VoiceSearchSheet>
    with SingleTickerProviderStateMixin {
  late AnimationController _anim;

  final List<String> _quickVoiceQueries = const [
    'Cafes in Shillong',
    'Jaipur Junction Railway Station',
    'Hotels in Goa near beach',
    'Taj Mahal Agra',
    'Taxi stand near bus stand',
    'Eiffel Tower Paris',
  ];

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: EdgeInsets.only(
        left: AppSpacing.lg,
        right: AppSpacing.lg,
        top: AppSpacing.lg,
        bottom: MediaQuery.of(context).viewInsets.bottom + AppSpacing.lg,
      ),
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.withOpacity(0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          AnimatedBuilder(
            animation: _anim,
            builder: (context, child) {
              return Container(
                width: 72 + (_anim.value * 14),
                height: 72 + (_anim.value * 14),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.primary.withOpacity(
                    0.12 + (_anim.value * 0.12),
                  ),
                  border: Border.all(
                    color: AppColors.primary.withOpacity(0.4),
                    width: 2,
                  ),
                ),
                child: const Center(
                  child: Icon(
                    Icons.mic_rounded,
                    color: AppColors.primary,
                    size: 36,
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: AppSpacing.md),
          const Text(
            'Listening for Place or City...',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 4),
          const Text(
            'Speak clearly or pick a quick spoken query below',
            style: TextStyle(fontSize: 12, color: Colors.grey),
          ),
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: _quickVoiceQueries.map((q) {
              return ActionChip(
                avatar: const Icon(
                  Icons.record_voice_over_rounded,
                  size: 14,
                  color: AppColors.primary,
                ),
                label: Text(q, style: const TextStyle(fontSize: 12)),
                onPressed: () => widget.onQuerySelected(q),
              );
            }).toList(),
          ),
          const SizedBox(height: AppSpacing.md),
        ],
      ),
    );
  }
}
