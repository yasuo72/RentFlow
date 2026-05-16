import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/widgets/app_surfaces.dart';

class PaymentQrCard extends StatelessWidget {
  const PaymentQrCard({
    required this.onOpen,
    this.compact = false,
    this.heroTag = 'payment-qr-hero',
    super.key,
  });

  final VoidCallback onOpen;
  final bool compact;
  final String heroTag;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final preview = _QrPreview(
      heroTag: heroTag,
      compact: compact,
      onTap: onOpen,
    );

    if (compact) {
      return AppSectionCard(
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.tr('paymentQr'),
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    l10n.tr('paymentQrCompactMessage'),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 14),
                  FilledButton.tonalIcon(
                    onPressed: onOpen,
                    icon: const Icon(Icons.qr_code_2_rounded),
                    label: Text(l10n.tr('openQr')),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 14),
            preview,
          ],
        ),
      );
    }

    return AppSectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppSectionTitle(
            eyebrow: l10n.tr('collectByQr'),
            title: l10n.tr('showThisQr'),
            subtitle: l10n.tr('saveAfterQr'),
            action: TextButton.icon(
              onPressed: onOpen,
              icon: const Icon(Icons.open_in_full_rounded),
              label: Text(l10n.tr('fullScreen')),
            ),
          ),
          const SizedBox(height: 16),
          Center(child: preview),
        ],
      ),
    );
  }
}

class _QrPreview extends StatelessWidget {
  const _QrPreview({
    required this.heroTag,
    required this.compact,
    required this.onTap,
  });

  final String heroTag;
  final bool compact;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final size = compact ? 92.0 : 220.0;

    return InkWell(
      borderRadius: BorderRadius.circular(compact ? 18 : 24),
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        padding: EdgeInsets.all(compact ? 10 : 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(compact ? 18 : 24),
          border: Border.all(color: AppColors.bgCardBorderStrongLight),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: compact ? 12 : 24,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: Hero(
          tag: heroTag,
          child: Image.asset(
            AppStrings.paymentQrAsset,
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) {
              return const Center(
                child: Icon(
                  Icons.broken_image_outlined,
                  color: AppColors.textMutedLight,
                  size: 32,
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
