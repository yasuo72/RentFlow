import 'package:flutter/material.dart';

import '../../../core/utils/currency_formatter.dart';

class StatCardWidget extends StatelessWidget {
  const StatCardWidget({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    this.isCurrency = false,
    this.badge,
    super.key,
  });

  final String label;
  final num value;
  final IconData icon;
  final Color color;
  final bool isCurrency;
  final String? badge;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          gradient: LinearGradient(
            colors: [
              color.withValues(alpha: 0.12),
              Colors.transparent,
            ],
            begin: Alignment.topRight,
            end: Alignment.bottomLeft,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(11),
                    ),
                    child: Icon(icon, color: color, size: 18),
                  ),
                  const Spacer(),
                  if (badge != null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(9),
                      ),
                      child: Text(
                        badge!,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: color,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 20),
              Text(
                isCurrency
                    ? CurrencyFormatter.inr(value)
                    : value.toInt().toString(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontSize: 22,
                ),
              ),
              const SizedBox(height: 4),
              Text(label, style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ),
      ),
    );
  }
}
