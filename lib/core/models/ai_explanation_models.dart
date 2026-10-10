/// Item in the AI explanation cost breakdown
class AiExplanationBreakdownItem {
  final String item;
  final double amount;
  final String note;

  const AiExplanationBreakdownItem({
    required this.item,
    required this.amount,
    required this.note,
  });

  Map<String, dynamic> toJson() => {
    'item': item,
    'amount': amount,
    'note': note,
  };

  factory AiExplanationBreakdownItem.fromJson(Map<String, dynamic> json) =>
      AiExplanationBreakdownItem(
        item: json['item'] as String? ?? 'Item',
        amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
        note: json['note'] as String? ?? '',
      );
}

/// Structured response returned by Gemini Proxy /explain endpoint
class AiExplanationResult {
  final String summary;
  final List<AiExplanationBreakdownItem> breakdown;
  final String counterOfferPhrase;
  final String culturalContext;
  final String safetyNote;
  final bool isFallback;

  const AiExplanationResult({
    required this.summary,
    required this.breakdown,
    required this.counterOfferPhrase,
    required this.culturalContext,
    required this.safetyNote,
    this.isFallback = false,
  });

  Map<String, dynamic> toJson() => {
    'summary': summary,
    'breakdown': breakdown.map((b) => b.toJson()).toList(),
    'counterOfferPhrase': counterOfferPhrase,
    'culturalContext': culturalContext,
    'safetyNote': safetyNote,
    'isFallback': isFallback,
  };

  factory AiExplanationResult.fromJson(Map<String, dynamic> json) =>
      AiExplanationResult(
        summary: json['summary'] as String? ?? '',
        breakdown:
            (json['breakdown'] as List<dynamic>?)
                ?.map(
                  (e) => AiExplanationBreakdownItem.fromJson(
                    e as Map<String, dynamic>,
                  ),
                )
                .toList() ??
            [],
        counterOfferPhrase: json['counterOfferPhrase'] as String? ?? '',
        culturalContext: json['culturalContext'] as String? ?? '',
        safetyNote: json['safetyNote'] as String? ?? '',
        isFallback: json['isFallback'] as bool? ?? false,
      );

  /// Validates that the explanation result fulfills all required schema fields
  bool get isValidSchema =>
      summary.trim().isNotEmpty &&
      breakdown.isNotEmpty &&
      counterOfferPhrase.trim().isNotEmpty;
}
