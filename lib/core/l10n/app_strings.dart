/// Centralized localization dictionary for Travel Buddy.
/// Provides typed strings, currency symbols, and multi-language capability (English & Hindi).
class AppStrings {
  AppStrings._();

  static const String currencySymbol = '₹';
  static const String appName = 'Travel Buddy';
  static const String appTagline = 'Travel Trap Detector';

  // Navigation Tabs
  static const String navHome = 'Home';
  static const String navExplore = 'Explore';
  static const String navProfile = 'Profile';

  // Home Screen
  static const String heroTitle = 'Check a Price Before You Pay';
  static const String heroSubtitle =
      'Instant verdict: Fair, Suspicious or High Risk. Based on official tariffs, community benchmarks & scam alerts.';
  static const String checkPriceNow = 'Check Any Quoted Price Now';
  static const String rideMode = 'Ride Mode';
  static const String verifyDriver = 'Verify Driver';
  static const String featuredDestinations = 'Featured Destinations';
  static const String searchPrompt =
      'Search any city, landmark, or place worldwide...';

  // Check Price Form
  static const String checkPriceTitle = 'Fair Price Checker';
  static const String serviceType = 'Service Type';
  static const String pickupLocation = 'Pickup / Origin';
  static const String dropoffLocation = 'Drop-off / Destination';
  static const String quotedPrice = 'Quoted Price (₹)';
  static const String passengers = 'Passengers';
  static const String meterUsed = 'Meter was used';
  static const String timeOfDay = 'Time of day';
  static const String extraChargesTitle = 'Extra Charges Checklist';
  static const String situationCheckerTitle = 'Situation Checker';
  static const String evaluatePrice = 'Evaluate Fair Price';

  // Verdicts
  static const String verdictFair = 'Fair Price';
  static const String verdictSuspicious = 'Suspicious Quote';
  static const String verdictHighRisk = 'High Risk (Overcharged)';

  // Sources
  static const String sourceOfficial = 'Official Tariff';
  static const String sourceCommunity = 'Community Benchmark';
  static const String sourceEstimate = 'Estimate Only';
  static const String sampleDataBadge = 'Sample Data';

  // Actions
  static const String copyCounterOffer = 'Copy Counter-Offer';
  static const String reportThisPrice = 'Report this price';
  static const String openInMaps = 'Open in Maps';
  static const String askBuddy = 'Ask Buddy';

  // Coverage Banners
  static String limitedDataBanner(String cityName) =>
      'We have limited price data for $cityName. Showing generic estimates.';

  // Error States
  static const String retry = 'Retry';
  static const String connectionError =
      'Could not reach server. Using offline data.';
  static const String noResults = 'No results found.';
}
