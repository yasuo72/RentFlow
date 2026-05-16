import 'package:flutter/material.dart';

import '../../core/localization/app_localizations.dart';
import '../../core/constants/app_strings.dart';
import '../../core/widgets/app_surfaces.dart';

class PaymentQrScreen extends StatelessWidget {
  const PaymentQrScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.tr('paymentQr'))),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 32),
        children: [
          AppHeaderPanel(
            title: l10n.tr('collectRentByQr'),
            subtitle: l10n.tr('collectRentByQrSubtitle'),
          ),
          const SizedBox(height: 18),
          AppSectionCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppSectionTitle(
                  eyebrow: l10n.tr('familyCollectionQr'),
                  title: l10n.tr('readyToScan'),
                  subtitle: l10n.tr('readyToScanSubtitle'),
                ),
                const SizedBox(height: 18),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(26),
                  ),
                  child: InteractiveViewer(
                    minScale: 1,
                    maxScale: 4,
                    child: Hero(
                      tag: 'payment-qr-hero',
                      child: Image.asset(
                        AppStrings.paymentQrAsset,
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 48),
                            child: Center(
                              child: Text('${l10n.tr('paymentQr')} image is not available.'),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          AppSectionCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppSectionTitle(
                  eyebrow: l10n.tr('bestUse'),
                  title: l10n.tr('simpleCollectionFlow'),
                ),
                const SizedBox(height: 12),
                _StepTile(
                  index: '1',
                  text: l10n.tr('step1Qr'),
                ),
                const SizedBox(height: 10),
                _StepTile(
                  index: '2',
                  text: l10n.tr('step2Qr'),
                ),
                const SizedBox(height: 10),
                _StepTile(
                  index: '3',
                  text: l10n.tr('step3Qr'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StepTile extends StatelessWidget {
  const _StepTile({
    required this.index,
    required this.text,
  });

  final String index;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 28,
          height: 28,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.12),
          ),
          child: Text(
            index,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              text,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ),
      ],
    );
  }
}
