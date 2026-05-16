import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_colors.dart';
import '../../core/utils/currency_formatter.dart';
import '../../core/utils/date_utils.dart';
import '../../core/widgets/app_surfaces.dart';
import '../../data/models/tenant_model.dart';
import '../../data/repositories/tenant_repository.dart';
import '../auth/auth_provider.dart';
import '../dashboard/dashboard_provider.dart';
import '../payments/payments_provider.dart';
import '../rooms/rooms_provider.dart';
import 'tenants_provider.dart';

class TenantDetailScreen extends ConsumerWidget {
  const TenantDetailScreen({required this.tenantId, super.key});

  final String tenantId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isSuperAdmin =
        ref.watch(authControllerProvider).user?.isSuperAdmin ?? false;
    final tenant = ref.watch(tenantDetailProvider(tenantId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Tenant Detail'),
        actions: [
          tenant.when(
            data: (item) => PopupMenuButton<String>(
              onSelected: (value) async {
                if (value == 'edit') {
                  context.push('/tenants/new?tenantId=${item.id}');
                } else if (value == 'leave') {
                  final confirmed = await showDialog<bool>(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: Text('Mark ${item.fullName} as left?'),
                      content: const Text(
                        'This will make the room vacant and move the tenant into history.',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(false),
                          child: const Text('Cancel'),
                        ),
                        FilledButton(
                          style: FilledButton.styleFrom(
                            backgroundColor: AppColors.danger,
                          ),
                          onPressed: () => Navigator.of(context).pop(true),
                          child: const Text('Confirm'),
                        ),
                      ],
                    ),
                  );

                  if (confirmed == true) {
                    await ref
                        .read(tenantRepositoryProvider)
                        .markTenantLeft(item.id);
                    ref.invalidate(tenantsProvider);
                    ref.invalidate(inactiveTenantsProvider);
                    ref.invalidate(roomsProvider);
                    if (context.mounted) {
                      context.pop();
                    }
                  }
                } else if (value == 'delete') {
                  final confirmed = await showDialog<bool>(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: Text('Delete ${item.fullName} permanently?'),
                      content: const Text(
                        'This will permanently erase the tenant, their payments, and related timeline records. This cannot be undone.',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(false),
                          child: const Text('Cancel'),
                        ),
                        FilledButton(
                          style: FilledButton.styleFrom(
                            backgroundColor: AppColors.danger,
                          ),
                          onPressed: () => Navigator.of(context).pop(true),
                          child: const Text('Delete permanently'),
                        ),
                      ],
                    ),
                  );

                  if (confirmed == true) {
                    await ref.read(tenantRepositoryProvider).purgeTenant(item.id);
                    ref.invalidate(tenantsProvider);
                    ref.invalidate(inactiveTenantsProvider);
                    ref.invalidate(paymentsProvider);
                    ref.invalidate(roomsProvider);
                    ref.invalidate(dashboardProvider);
                    if (context.mounted) {
                      context.pop();
                    }
                  }
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(value: 'edit', child: Text('Edit tenant')),
                const PopupMenuItem(value: 'leave', child: Text('Mark as left')),
                if (isSuperAdmin)
                  const PopupMenuItem(
                    value: 'delete',
                    child: Text('Delete permanently'),
                  ),
              ],
            ),
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
          ),
        ],
      ),
      body: tenant.when(
        data: (item) => ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
          children: [
            _HeaderBlock(tenant: item),
            const SizedBox(height: 18),
            AppSectionCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const AppSectionTitle(
                    title: 'Contact and stay',
                    subtitle:
                        'Primary contact information used by the whole family.',
                  ),
                  const SizedBox(height: 16),
                  _DetailRow(label: 'Phone', value: item.phone),
                  _DetailRow(
                    label: 'Alternate phone',
                    value: item.alternatePhone ?? '-',
                  ),
                  _DetailRow(
                    label: 'Occupation',
                    value: item.occupation ?? '-',
                  ),
                  _DetailRow(
                    label: 'Family members',
                    value: '${item.familyMembers}',
                  ),
                  _DetailRow(
                    label: 'Permanent address',
                    value: item.permanentAddress ?? '-',
                  ),
                  _DetailRow(
                    label: 'Emergency contact',
                    value: item.emergencyContact == null
                        ? '-'
                        : '${item.emergencyContact?.name ?? '-'} | ${item.emergencyContact?.phone ?? '-'} | ${item.emergencyContact?.relation ?? '-'}',
                  ),
                  if (item.notes?.isNotEmpty ?? false)
                    _DetailRow(label: 'Notes', value: item.notes!),
                ],
              ),
            ),
            const SizedBox(height: 18),
            AppSectionCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const AppSectionTitle(
                    title: 'Documents and photos',
                    subtitle:
                        'Tap any file to view it. Images open inside the app, and PDFs use the built-in viewer.',
                  ),
                  const SizedBox(height: 14),
                  if (item.documents.isEmpty)
                    const AppEmptyState(
                      title: 'No documents uploaded',
                      message:
                          'Profile photos, Aadhaar copies, and agreements will appear here once they are uploaded.',
                      icon: Icons.folder_open_outlined,
                    )
                  else
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: item.documents
                          .map(
                            (document) => _DocumentTile(
                              document: document,
                              onTap: () => _openDocument(context, document),
                            ),
                          )
                          .toList(),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            AppSectionCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const AppSectionTitle(
                    title: 'Payment history',
                    subtitle: 'Receipts and remarks recorded over time.',
                  ),
                  const SizedBox(height: 12),
                  if (item.paymentHistory.isEmpty)
                    const AppEmptyState(
                      title: 'No payment history yet',
                      message:
                          'As soon as the family records payments for this tenant, the month-by-month history will appear here.',
                      icon: Icons.payments_outlined,
                    )
                  else
                    ...item.paymentHistory.map(
                      (payment) => Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Theme.of(
                            context,
                          ).colorScheme.surface.withValues(alpha: 0.58),
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 42,
                              height: 42,
                              decoration: BoxDecoration(
                                color: payment.remainingAmount > 0
                                    ? AppColors.warning.withValues(alpha: 0.16)
                                    : AppColors.accent.withValues(alpha: 0.16),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                payment.remainingAmount > 0
                                    ? Icons.pending_actions_rounded
                                    : Icons.check_circle_rounded,
                                color: payment.remainingAmount > 0
                                    ? AppColors.warning
                                    : AppColors.accent,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          payment.month,
                                          style: Theme.of(
                                            context,
                                          ).textTheme.titleMedium,
                                        ),
                                      ),
                                      Text(
                                        payment.recordedByName ?? '-',
                                        style: Theme.of(context).textTheme.bodySmall,
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Paid ${CurrencyFormatter.inr(payment.amountPaid)} | Remaining ${CurrencyFormatter.inr(payment.remainingAmount)}',
                                  ),
                                  if (payment.remark?.isNotEmpty == true) ...[
                                    const SizedBox(height: 4),
                                    Text(
                                      payment.remark!,
                                      style: Theme.of(context).textTheme.bodySmall,
                                    ),
                                  ],
                                  const SizedBox(height: 6),
                                  Text(
                                    AppDateUtils.formatDate(payment.paymentDate),
                                    style: Theme.of(context).textTheme.bodySmall,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) =>
            Center(child: Text('Unable to load tenant\n$error')),
      ),
    );
  }

  void _openDocument(BuildContext context, TenantDocument document) {
    final uri = _isImageDocument(document)
        ? Uri(
            path: '/viewer/image',
            queryParameters: {
              'url': document.url,
              'title': document.name,
            },
          )
        : Uri(
            path: '/viewer/pdf',
            queryParameters: {
              'url': document.url,
              'title': document.name,
            },
          );

    context.push(uri.toString());
  }

  bool _isImageDocument(TenantDocument document) {
    final url = document.url.toLowerCase();
    return document.type == 'photo' ||
        url.endsWith('.jpg') ||
        url.endsWith('.jpeg') ||
        url.endsWith('.png') ||
        url.endsWith('.webp');
  }
}

class _HeaderBlock extends StatelessWidget {
  const _HeaderBlock({required this.tenant});

  final TenantModel tenant;

  @override
  Widget build(BuildContext context) {
    return AppSectionCard(
      padding: const EdgeInsets.all(0),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: const LinearGradient(
            colors: [Color(0xFF1C2250), AppColors.primary],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GestureDetector(
                onTap: tenant.profilePhoto?.isNotEmpty == true
                    ? () {
                        final uri = Uri(
                          path: '/viewer/image',
                          queryParameters: {
                            'url': tenant.profilePhoto!,
                            'title': tenant.fullName,
                          },
                        );
                        context.push(uri.toString());
                      }
                    : null,
                child: CircleAvatar(
                  radius: 34,
                  backgroundColor: Colors.white.withValues(alpha: 0.18),
                  backgroundImage: tenant.profilePhoto?.isNotEmpty == true
                      ? CachedNetworkImageProvider(tenant.profilePhoto!)
                      : null,
                  child: tenant.profilePhoto?.isNotEmpty == true
                      ? null
                      : Text(
                          tenant.fullName.isEmpty
                              ? '?'
                              : tenant.fullName[0].toUpperCase(),
                          style: Theme.of(context).textTheme.headlineSmall
                              ?.copyWith(color: Colors.white),
                        ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            tenant.fullName,
                            style: Theme.of(context).textTheme.headlineSmall
                                ?.copyWith(color: Colors.white),
                          ),
                        ),
                        StatusBadge(
                          label: tenant.isActive ? 'ACTIVE' : 'PAST TENANT',
                          color: tenant.isActive
                              ? AppColors.accent
                              : AppColors.warning,
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Room ${tenant.room?.roomNumber ?? '-'} | Joined ${AppDateUtils.formatDate(tenant.joiningDate)}',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.white.withValues(alpha: 0.88),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      tenant.phone,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.white.withValues(alpha: 0.76),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DocumentTile extends StatelessWidget {
  const _DocumentTile({
    required this.document,
    required this.onTap,
  });

  final TenantDocument document;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isImage = document.type == 'photo' ||
        document.url.toLowerCase().endsWith('.jpg') ||
        document.url.toLowerCase().endsWith('.jpeg') ||
        document.url.toLowerCase().endsWith('.png') ||
        document.url.toLowerCase().endsWith('.webp');

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        width: 156,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.54),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: Theme.of(context).dividerColor.withValues(alpha: 0.18),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: AspectRatio(
                aspectRatio: 1.1,
                child: isImage
                    ? CachedNetworkImage(
                        imageUrl: document.url,
                        fit: BoxFit.cover,
                        placeholder: (context, url) => Container(
                          color: Colors.black.withValues(alpha: 0.06),
                          child: const Center(
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        ),
                        errorWidget: (context, url, error) => Container(
                          color: AppColors.primaryLight.withValues(alpha: 0.08),
                          child: const Icon(Icons.image_not_supported_outlined),
                        ),
                      )
                    : Container(
                        color: AppColors.danger.withValues(alpha: 0.08),
                        child: const Center(
                          child: Icon(
                            Icons.picture_as_pdf_rounded,
                            color: AppColors.danger,
                            size: 34,
                          ),
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              document.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 4),
            Text(
              document.type.toUpperCase(),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 4),
          Text(value, style: Theme.of(context).textTheme.titleSmall),
        ],
      ),
    );
  }
}
