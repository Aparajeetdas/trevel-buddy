import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/data/local_data_repository.dart';
import '../../../core/models/app_models.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_brand_app_bar.dart';

class ReportScamScreen extends ConsumerStatefulWidget {
  const ReportScamScreen({super.key});

  @override
  ConsumerState<ReportScamScreen> createState() => _ReportScamScreenState();
}

class _ReportScamScreenState extends ConsumerState<ReportScamScreen> {
  int _currentStep = 0;

  // Step 1: What happened
  String _selectedIncidentType = 'Taxi / Auto Overcharge';
  final List<String> _incidentTypes = [
    'Taxi / Auto Overcharge',
    'Fake Tourist Office / Detour',
    'Gemstone / Souvenir Scam',
    'Closed Monument Lie',
    'Forced Snow Clothes / Equipment Rental',
    'Boat Ride Overcharge',
    'Fake Charity Donation',
  ];

  // Step 2: Details & Amount
  final TextEditingController _placeController = TextEditingController(
    text: 'Jaipur Pink City',
  );
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();

  // Step 3: Photo & submit
  bool _photoAttached = false;
  String? _generatedReportId;

  @override
  void dispose() {
    _placeController.dispose();
    _amountController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _submitReport() async {
    final amount = double.tryParse(_amountController.text.trim()) ?? 0.0;
    final randomId = 'REP-${(1000 + Random().nextInt(9000))}';

    final report = ScamReport(
      id: randomId,
      incidentType: _selectedIncidentType,
      placeName: _placeController.text.trim().isEmpty
          ? 'Local Area'
          : _placeController.text.trim(),
      amountLost: amount,
      description: _descriptionController.text.trim().isEmpty
          ? 'Reported via Travel Buddy Scam Defense.'
          : _descriptionController.text.trim(),
      photoUrl: _photoAttached ? 'assets/images/sample_receipt.jpg' : null,
      timestamp: DateTime.now(),
      status: 'Submitted',
    );

    await ref.read(scamReportsNotifierProvider.notifier).addReport(report);

    setState(() {
      _generatedReportId = randomId;
      _currentStep = 3; // Confirmation step
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: const AppBrandAppBar(
        title: 'Report a Scam',
        showBackButton: true,
      ),
      body: _generatedReportId != null
          ? _buildConfirmationView(theme)
          : Stepper(
              currentStep: _currentStep,
              onStepCancel: () {
                if (_currentStep > 0) {
                  setState(() => _currentStep -= 1);
                } else {
                  context.pop();
                }
              },
              onStepContinue: () {
                if (_currentStep < 2) {
                  setState(() => _currentStep += 1);
                } else {
                  _submitReport();
                }
              },
              steps: [
                // Step 1: What happened
                Step(
                  title: const Text('1. What Happened?'),
                  subtitle: Text(_selectedIncidentType),
                  isActive: _currentStep >= 0,
                  state: _currentStep > 0
                      ? StepState.complete
                      : StepState.indexed,
                  content: Column(
                    children: _incidentTypes.map((type) {
                      return RadioListTile<String>(
                        value: type,
                        groupValue: _selectedIncidentType,
                        title: Text(
                          type,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        activeColor: AppColors.primary,
                        onChanged: (val) {
                          if (val != null) {
                            setState(() => _selectedIncidentType = val);
                          }
                        },
                      );
                    }).toList(),
                  ),
                ),

                // Step 2: Details with amount
                Step(
                  title: const Text('2. Details & Amount'),
                  subtitle: const Text('Location, rupees lost, narrative'),
                  isActive: _currentStep >= 1,
                  state: _currentStep > 1
                      ? StepState.complete
                      : StepState.indexed,
                  content: Column(
                    children: [
                      TextField(
                        controller: _placeController,
                        decoration: const InputDecoration(
                          labelText: 'Location / Landmark',
                          prefixIcon: Icon(Icons.location_on_outlined),
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      TextField(
                        controller: _amountController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Amount Quoted / Lost (₹)',
                          prefixText: '₹ ',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      TextField(
                        controller: _descriptionController,
                        maxLines: 3,
                        decoration: const InputDecoration(
                          labelText: 'What did the tout/driver say or do?',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ],
                  ),
                ),

                // Step 3: Optional Photo
                Step(
                  title: const Text('3. Evidence (Optional)'),
                  subtitle: const Text('Photo of vehicle, receipt, or shop'),
                  isActive: _currentStep >= 2,
                  state: _currentStep > 2
                      ? StepState.complete
                      : StepState.indexed,
                  content: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      InkWell(
                        onTap: () {
                          setState(() => _photoAttached = !_photoAttached);
                        },
                        child: Container(
                          width: double.infinity,
                          height: 120,
                          decoration: BoxDecoration(
                            color: theme.cardColor,
                            borderRadius: BorderRadius.circular(AppRadius.md),
                            border: Border.all(
                              color: _photoAttached
                                  ? AppColors.success
                                  : AppColors.outlineLight,
                              width: _photoAttached ? 2 : 1,
                            ),
                          ),
                          child: Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  _photoAttached
                                      ? Icons.check_circle_rounded
                                      : Icons.add_a_photo_outlined,
                                  color: _photoAttached
                                      ? AppColors.success
                                      : AppColors.primary,
                                  size: 32,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  _photoAttached
                                      ? 'Photo Receipt Attached (Tap to remove)'
                                      : 'Tap to Attach Receipt / Vehicle Photo',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    color: _photoAttached
                                        ? AppColors.success
                                        : AppColors.primary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      const Text(
                        'Your report updates the community scam heatmap and protects future travelers.',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondaryLight,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildConfirmationView(ThemeData theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(AppSpacing.lg),
              decoration: const BoxDecoration(
                color: AppColors.successContainer,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check_circle_rounded,
                size: 64,
                color: AppColors.success,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              'Report Submitted Successfully',
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.sm),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: theme.cardColor,
                borderRadius: BorderRadius.circular(AppRadius.full),
                border: Border.all(color: AppColors.primary),
              ),
              child: Text(
                'Report ID: $_generatedReportId',
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  color: AppColors.primary,
                  fontSize: 16,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              'Your report has been saved to your profile and added to the local scam alert feed.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: AppSpacing.xl),
            ElevatedButton(
              onPressed: () => context.go('/profile'),
              child: const Text('View in My Reports'),
            ),
            const SizedBox(height: AppSpacing.sm),
            TextButton(
              onPressed: () => context.go('/'),
              child: const Text('Back to Home'),
            ),
          ],
        ),
      ),
    );
  }
}
