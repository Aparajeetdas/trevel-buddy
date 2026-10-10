import 'package:flutter/material.dart';

import '../../../../core/models/app_models.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_brand_app_bar.dart';
import '../../../../core/widgets/ask_buddy_floating_button.dart';
import '../../ask_buddy/presentation/ask_buddy_sheet.dart';
import 'widgets/price_factors_and_explanation.dart';
import 'widgets/price_range_bar.dart';
import 'widgets/price_risk_gauge.dart';
import 'widgets/price_sources_row.dart';
import 'widgets/price_traps_and_actions.dart';
import 'widgets/price_verdict_banner.dart';

/// Full screen displaying the comprehensive AI Price Check result
class PriceCheckResultScreen extends StatelessWidget {
  final PriceCheckResult result;
  final PriceCheckInput input;

  const PriceCheckResultScreen({
    super.key,
    required this.result,
    required this.input,
  });

  @override
  Widget build(BuildContext context) {
    final placeName = input.dropName?.isNotEmpty == true
        ? input.dropName!
        : 'Jaipur';

    return Scaffold(
      appBar: const AppBrandAppBar(
        title: 'Price Intelligence Verdict',
        showBackButton: true,
      ),
      floatingActionButton: AskBuddyFloatingButton(
        place: placeName,
        initialPrompt:
            'I checked a ₹${input.quotedPrice.round()} quote for ${input.serviceType.displayName}. Verdict is ${result.level.label}. How should I negotiate?',
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Verdict Banner (icon + color + word + sentence)
            PriceVerdictBanner(result: result),
            const SizedBox(height: AppSpacing.md),

            // 2. Risk Score Gauge (0-100) & Confidence Label
            PriceRiskGauge(
              riskScore: result.riskScore,
              confidence: result.confidence,
              level: result.level,
            ),
            const SizedBox(height: AppSpacing.md),

            // 3. Fair Price Range Bar with quoted price marker + diff
            PriceRangeBar(result: result),
            const SizedBox(height: AppSpacing.md),

            // 4. Sources Row (Official tariff, Community benchmark, AI estimate)
            PriceSourcesRow(sources: result.sources),
            const SizedBox(height: AppSpacing.md),

            // 5. Why this result (Gemini AI explanation + breakdown + factor list)
            PriceFactorsAndExplanation(result: result, input: input),
            const SizedBox(height: AppSpacing.md),

            // 6 & 7. Tourist Traps Near Here & Counter-offer Actions
            PriceTrapsAndActions(
              result: result,
              input: input,
              onAskBuddy: () {
                AskBuddySheet.show(
                  context,
                  place: placeName,
                  initialPrompt:
                      'I was quoted ₹${input.quotedPrice.round()} for ${input.serviceType.displayName} from ${input.pickupName} to ${input.dropName}. Verdict is ${result.level.label} (Score ${result.riskScore}/100). Please help me handle this quote safely.',
                );
              },
            ),
            const SizedBox(height: 80), // Padding for floating button
          ],
        ),
      ),
    );
  }
}
