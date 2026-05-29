import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_colors.dart';
import '../../core/widgets/app_surfaces.dart';
import '../../data/repositories/tenant_repository.dart';
import '../dashboard/dashboard_provider.dart';
import '../rooms/rooms_provider.dart';
import 'tenants_provider.dart';

class TenantDocumentUploadScreen extends ConsumerStatefulWidget {
  const TenantDocumentUploadScreen({
    required this.tenantId,
    this.initialType,
    super.key,
  });

  final String tenantId;
  final String? initialType;

  @override
  ConsumerState<TenantDocumentUploadScreen> createState() =>
      _TenantDocumentUploadScreenState();
}

class _TenantDocumentUploadScreenState
    extends ConsumerState<TenantDocumentUploadScreen> {
  final List<({String path, String type})> _documents = [];
  bool _saving = false;

  Future<void> _pickDocuments() async {
    final result = await FilePicker.pickFiles(allowMultiple: true);
    if (result == null) {
      return;
    }

    for (final file in result.files) {
      if (file.path == null) {
        continue;
      }

      final hintedType = widget.initialType;
      final type = hintedType == null || hintedType == 'other'
          ? await _showDocumentTypePicker()
          : hintedType;
      if (type == null) {
        continue;
      }

      _documents.add((path: file.path!, type: type));
    }

    if (mounted) {
      setState(() {});
    }
  }

  Future<String?> _showDocumentTypePicker() {
    return showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: ['aadhaar', 'agreement', 'photo', 'other']
              .map(
                (type) => ListTile(
                  title: Text(type.toUpperCase()),
                  onTap: () => Navigator.of(context).pop(type),
                ),
              )
              .toList(),
        ),
      ),
    );
  }

  Future<void> _save() async {
    if (_documents.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least one document.')),
      );
      return;
    }

    setState(() => _saving = true);

    try {
      final tenant = await ref
          .read(tenantRepositoryProvider)
          .uploadTenantDocuments(widget.tenantId, _documents);

      ref.invalidate(tenantDetailProvider(widget.tenantId));
      ref.invalidate(tenantsProvider);
      ref.invalidate(roomsProvider);
      ref.invalidate(dashboardProvider);

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${tenant.fullName} documents uploaded.')),
      );
      context.pop();
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to upload documents: $error')),
      );
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final tenant = ref.watch(tenantDetailProvider(widget.tenantId));

    return Scaffold(
      appBar: AppBar(title: const Text('Upload Documents')),
      body: tenant.when(
        data: (item) => ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
          children: [
            AppHeaderPanel(
              title: item.fullName,
              subtitle:
                  'Attach Aadhaar, agreement, photos, or other files. Existing documents stay safe.',
            ),
            const SizedBox(height: 18),
            AppSectionCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AppSectionTitle(
                    title: 'Documents',
                    subtitle:
                        '${item.documents.length} existing | ${_documents.length} selected now',
                    action: TextButton.icon(
                      onPressed: _saving ? null : _pickDocuments,
                      icon: const Icon(Icons.file_upload_outlined),
                      label: const Text('Add'),
                    ),
                  ),
                  const SizedBox(height: 14),
                  if (item.documents.isEmpty)
                    const AppEmptyState(
                      title: 'No existing documents',
                      message:
                          'Upload the tenant Aadhaar, agreement, or photos from here.',
                      icon: Icons.folder_open_outlined,
                    )
                  else
                    ...item.documents.map(
                      (document) => ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.insert_drive_file_outlined),
                        title: Text(document.name),
                        subtitle: Text(document.type.toUpperCase()),
                      ),
                    ),
                  if (_documents.isNotEmpty) ...[
                    const Divider(height: 26),
                    Text(
                      'Selected for upload',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const SizedBox(height: 8),
                    ..._documents.indexed.map(
                      (entry) => ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(
                          Icons.upload_file_outlined,
                          color: AppColors.primary,
                        ),
                        title: Text(_fileName(entry.$2.path)),
                        subtitle: Text(entry.$2.type.toUpperCase()),
                        trailing: IconButton(
                          icon: const Icon(Icons.close_rounded),
                          onPressed: _saving
                              ? null
                              : () {
                                  setState(() => _documents.removeAt(entry.$1));
                                },
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 22),
            FilledButton.icon(
              onPressed: _saving ? null : _save,
              icon: _saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.cloud_upload_rounded),
              label: Padding(
                padding: const EdgeInsets.symmetric(vertical: 14),
                child: Text(_saving ? 'Uploading' : 'Save documents'),
              ),
            ),
          ],
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) =>
            Center(child: Text('Unable to prepare upload page.\n$error')),
      ),
    );
  }

  String _fileName(String path) {
    final segments = path.split(RegExp(r'[\\/]'));
    return segments.isEmpty ? path : segments.last;
  }
}
