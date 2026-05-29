import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/constants/app_colors.dart';
import '../../core/utils/currency_formatter.dart';
import '../../core/utils/date_utils.dart';
import '../../core/utils/validators.dart';
import '../../core/widgets/app_surfaces.dart';
import '../../data/models/room_model.dart';
import '../../data/models/tenant_model.dart';
import '../../data/repositories/tenant_repository.dart';
import '../dashboard/dashboard_provider.dart';
import '../payments/payments_provider.dart';
import '../rooms/rooms_provider.dart';
import 'tenants_provider.dart';

class AddEditTenantScreen extends ConsumerStatefulWidget {
  const AddEditTenantScreen({this.tenantId, super.key});

  final String? tenantId;

  bool get isEditing => tenantId != null && tenantId!.isNotEmpty;

  @override
  ConsumerState<AddEditTenantScreen> createState() =>
      _AddEditTenantScreenState();
}

class _AddEditTenantScreenState extends ConsumerState<AddEditTenantScreen> {
  final _formKey = GlobalKey<FormState>();
  final _fullNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _whatsappNumberController = TextEditingController();
  final _alternatePhoneController = TextEditingController();
  final _idNumberController = TextEditingController();
  final _occupationController = TextEditingController();
  final _familyMembersController = TextEditingController(text: '1');
  final _addressController = TextEditingController();
  final _emergencyNameController = TextEditingController();
  final _emergencyPhoneController = TextEditingController();
  final _emergencyRelationController = TextEditingController();
  final _notesController = TextEditingController();
  final _openingDueController = TextEditingController();
  final _openingDueRemarkController = TextEditingController();

  DateTime _joiningDate = DateTime.now();
  String? _selectedRoomId;
  String? _profilePhotoPath;
  final List<({String path, String type})> _documents = [];
  bool _initialized = false;
  bool _saving = false;

  @override
  void dispose() {
    _fullNameController.dispose();
    _phoneController.dispose();
    _whatsappNumberController.dispose();
    _alternatePhoneController.dispose();
    _idNumberController.dispose();
    _occupationController.dispose();
    _familyMembersController.dispose();
    _addressController.dispose();
    _emergencyNameController.dispose();
    _emergencyPhoneController.dispose();
    _emergencyRelationController.dispose();
    _notesController.dispose();
    _openingDueController.dispose();
    _openingDueRemarkController.dispose();
    super.dispose();
  }

  void _populateForm(TenantModel tenant) {
    if (_initialized) {
      return;
    }

    _initialized = true;
    _fullNameController.text = tenant.fullName;
    _phoneController.text = tenant.phone;
    _whatsappNumberController.text = tenant.whatsappNumber ?? '';
    _alternatePhoneController.text = tenant.alternatePhone ?? '';
    _idNumberController.text = tenant.idNumber ?? '';
    _occupationController.text = tenant.occupation ?? '';
    _familyMembersController.text = tenant.familyMembers.toString();
    _addressController.text = tenant.permanentAddress ?? '';
    _emergencyNameController.text = tenant.emergencyContact?.name ?? '';
    _emergencyPhoneController.text = tenant.emergencyContact?.phone ?? '';
    _emergencyRelationController.text = tenant.emergencyContact?.relation ?? '';
    _notesController.text = tenant.notes ?? '';
    _openingDueController.text = tenant.openingDueAmount > 0
        ? tenant.openingDueAmount.toInt().toString()
        : '';
    _openingDueRemarkController.text = tenant.openingDueRemark ?? '';
    _joiningDate = tenant.joiningDate;
    _selectedRoomId = tenant.room?.id;
  }

  Future<void> _pickProfilePhoto() async {
    final picker = ImagePicker();
    final photo = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 82,
    );
    if (photo == null) {
      return;
    }

    setState(() => _profilePhotoPath = photo.path);
  }

  Future<void> _pickDocuments() async {
    final result = await FilePicker.pickFiles(allowMultiple: true);
    if (result == null) {
      return;
    }

    for (final file in result.files) {
      if (file.path == null) {
        continue;
      }

      final type = await _pickDocumentType();
      if (type == null) {
        continue;
      }

      _documents.add((path: file.path!, type: type));
    }

    if (mounted) {
      setState(() {});
    }
  }

  Future<String?> _pickDocumentType() async {
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
    final formState = _formKey.currentState;

    if (formState == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Tenant form is not ready yet. Please try again.'),
        ),
      );
      return;
    }

    if (!formState.validate() || _selectedRoomId == null) {
      if (_selectedRoomId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please assign a room to this tenant.')),
        );
      }
      return;
    }

    setState(() => _saving = true);
    final repository = ref.read(tenantRepositoryProvider);

    final payload = {
      'fullName': _fullNameController.text.trim(),
      'phone': _phoneController.text.trim(),
      'whatsappNumber': _whatsappNumberController.text.trim(),
      'alternatePhone': _alternatePhoneController.text.trim(),
      'idNumber': _idNumberController.text.trim(),
      'occupation': _occupationController.text.trim(),
      'familyMembers': int.tryParse(_familyMembersController.text.trim()) ?? 1,
      'permanentAddress': _addressController.text.trim(),
      'joiningDate': _joiningDate.toIso8601String(),
      'room': _selectedRoomId!,
      'emergencyContactName': _emergencyNameController.text.trim(),
      'emergencyContactPhone': _emergencyPhoneController.text.trim(),
      'emergencyContactRelation': _emergencyRelationController.text.trim(),
      'notes': _notesController.text.trim(),
      if (!widget.isEditing)
        'openingDueAmount':
            num.tryParse(_openingDueController.text.trim()) ?? 0,
      if (!widget.isEditing)
        'openingDueRemark': _openingDueRemarkController.text.trim(),
    };

    try {
      final tenant = widget.isEditing
          ? await repository.updateTenant(
              widget.tenantId!,
              payload,
              profilePhotoPath: _profilePhotoPath,
              documents: _documents,
            )
          : await repository.createTenant(
              payload,
              profilePhotoPath: _profilePhotoPath,
              documents: _documents,
            );

      ref.invalidate(tenantsProvider);
      ref.invalidate(inactiveTenantsProvider);
      ref.invalidate(tenantDetailProvider(tenant.id));
      ref.invalidate(roomsProvider);
      ref.invalidate(paymentsProvider);
      ref.invalidate(pendingPaymentsProvider);
      ref.invalidate(dashboardProvider);

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            widget.isEditing
                ? '${tenant.fullName} updated.'
                : '${tenant.fullName} added.',
          ),
        ),
      );
      context.pop();
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Unable to save tenant: $error')));
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final tenantAsync = widget.isEditing
        ? ref.watch(tenantDetailProvider(widget.tenantId!))
        : const AsyncValue.data(null);
    final roomsAsync = ref.watch(roomsProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isEditing ? 'Edit Tenant' : 'Add Tenant'),
      ),
      body: tenantAsync.when(
        data: (tenant) => roomsAsync.when(
          data: (rooms) {
            if (tenant != null) {
              _populateForm(tenant);
            }

            final availableRooms = _availableRooms(
              rooms,
              currentRoomId: tenant?.room?.id,
            );
            _selectedRoomId ??= availableRooms.isNotEmpty
                ? availableRooms.first.id
                : null;
            final selectedRoom = _selectedRoom(availableRooms);
            final openingDue =
                num.tryParse(_openingDueController.text.trim()) ?? 0;
            final firstPayable = (selectedRoom?.monthlyRent ?? 0) + openingDue;

            return Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  AppHeaderPanel(
                    title: widget.isEditing
                        ? tenant?.fullName ?? 'Tenant'
                        : 'Add a new tenant',
                    subtitle: widget.isEditing
                        ? 'Keep contact, room assignment, and safety details up to date for the whole family.'
                        : 'Capture the essentials once so recurring payment entry stays quick every month.',
                  ),
                  const SizedBox(height: 18),
                  if (!widget.isEditing) ...[
                    AppSectionCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const AppSectionTitle(
                            title: 'Opening dues',
                            subtitle:
                                'Add old unpaid rent at registration, like 2 months pending before RentFlow tracking started.',
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _openingDueController,
                            keyboardType: TextInputType.number,
                            validator: (value) {
                              if ((value ?? '').trim().isEmpty) {
                                return null;
                              }
                              final parsed = num.tryParse(value!.trim());
                              if (parsed == null || parsed < 0) {
                                return 'Enter a valid opening due amount';
                              }
                              return null;
                            },
                            onChanged: (_) => setState(() {}),
                            decoration: const InputDecoration(
                              labelText: 'Opening pending balance',
                              hintText: '5000',
                              prefixText: '₹ ',
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _openingDueRemarkController,
                            maxLines: 2,
                            decoration: const InputDecoration(
                              labelText: 'Reason',
                              hintText: 'Last 2 months rent pending',
                            ),
                          ),
                          if (selectedRoom != null) ...[
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                _OpeningDueChip(
                                  label: '1 month',
                                  amount: selectedRoom.monthlyRent,
                                  onTap: () =>
                                      _setOpeningDue(selectedRoom.monthlyRent),
                                ),
                                _OpeningDueChip(
                                  label: '2 months',
                                  amount: selectedRoom.monthlyRent * 2,
                                  onTap: () => _setOpeningDue(
                                    selectedRoom.monthlyRent * 2,
                                  ),
                                ),
                                _OpeningDueChip(
                                  label: '3 months',
                                  amount: selectedRoom.monthlyRent * 3,
                                  onTap: () => _setOpeningDue(
                                    selectedRoom.monthlyRent * 3,
                                  ),
                                ),
                              ],
                            ),
                          ],
                          const SizedBox(height: 14),
                          _OpeningDuePreview(
                            monthlyRent: selectedRoom?.monthlyRent ?? 0,
                            openingDue: openingDue,
                            firstPayable: firstPayable,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                  ],
                  AppSectionCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const AppSectionTitle(
                          title: 'Identity',
                          subtitle:
                              'These details appear in rooms, payments, and reports.',
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _fullNameController,
                          validator: (value) =>
                              Validators.requiredField(value, 'Full name'),
                          decoration: const InputDecoration(
                            labelText: 'Full name',
                          ),
                        ),
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: _phoneController,
                                keyboardType: TextInputType.phone,
                                validator: Validators.phone,
                                decoration: const InputDecoration(
                                  labelText: 'Phone',
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextFormField(
                                controller: _alternatePhoneController,
                                keyboardType: TextInputType.phone,
                                decoration: const InputDecoration(
                                  labelText: 'Alternate phone',
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        TextFormField(
                          controller: _whatsappNumberController,
                          keyboardType: TextInputType.phone,
                          validator: (value) {
                            final text = (value ?? '').trim();
                            if (text.isEmpty) {
                              return null;
                            }
                            return Validators.phone(text);
                          },
                          decoration: const InputDecoration(
                            labelText: 'WhatsApp number',
                            hintText: 'Leave blank to use primary phone',
                            prefixIcon: Icon(Icons.chat_bubble_outline_rounded),
                          ),
                        ),
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: _idNumberController,
                                decoration: const InputDecoration(
                                  labelText: 'ID number',
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextFormField(
                                controller: _occupationController,
                                decoration: const InputDecoration(
                                  labelText: 'Occupation',
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        TextFormField(
                          controller: _familyMembersController,
                          keyboardType: TextInputType.number,
                          validator: (value) =>
                              Validators.requiredField(value, 'Family members'),
                          decoration: const InputDecoration(
                            labelText: 'Family members count',
                          ),
                        ),
                        const SizedBox(height: 14),
                        TextFormField(
                          controller: _addressController,
                          maxLines: 3,
                          decoration: const InputDecoration(
                            labelText: 'Permanent address',
                          ),
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
                          title: 'Stay and safety',
                          subtitle:
                              'Room assignment and emergency contact help everyone respond quickly.',
                        ),
                        const SizedBox(height: 16),
                        DropdownButtonFormField<String>(
                          initialValue: _selectedRoomId,
                          decoration: const InputDecoration(
                            labelText: 'Assign room',
                          ),
                          items: availableRooms
                              .map(
                                (room) => DropdownMenuItem(
                                  value: room.id,
                                  child: Text(
                                    'Room ${room.roomNumber} | ${room.building ?? 'Main'}',
                                  ),
                                ),
                              )
                              .toList(),
                          onChanged: (value) =>
                              setState(() => _selectedRoomId = value),
                        ),
                        if (availableRooms.isEmpty) ...[
                          const SizedBox(height: 10),
                          const Text(
                            'No vacant rooms are available right now.',
                          ),
                        ],
                        const SizedBox(height: 14),
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Joining date'),
                          subtitle: Text(AppDateUtils.formatDate(_joiningDate)),
                          trailing: const Icon(Icons.calendar_month_outlined),
                          onTap: () async {
                            final selected = await showDatePicker(
                              context: context,
                              initialDate: _joiningDate,
                              firstDate: DateTime(2020),
                              lastDate: DateTime(2100),
                            );
                            if (selected != null) {
                              setState(() => _joiningDate = selected);
                            }
                          },
                        ),
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: _emergencyNameController,
                                decoration: const InputDecoration(
                                  labelText: 'Emergency contact name',
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextFormField(
                                controller: _emergencyPhoneController,
                                keyboardType: TextInputType.phone,
                                decoration: const InputDecoration(
                                  labelText: 'Emergency contact phone',
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        TextFormField(
                          controller: _emergencyRelationController,
                          decoration: const InputDecoration(
                            labelText: 'Relation',
                          ),
                        ),
                        const SizedBox(height: 14),
                        TextFormField(
                          controller: _notesController,
                          maxLines: 4,
                          decoration: const InputDecoration(
                            labelText: 'Notes',
                            hintText:
                                'Move-in condition, family context, agreement reminders...',
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  AppSectionCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        AppSectionTitle(
                          title: 'Photos and documents',
                          subtitle:
                              '${tenant?.documents.length ?? 0} existing docs | ${_documents.length} new docs',
                          action: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              TextButton.icon(
                                onPressed: _pickProfilePhoto,
                                icon: const Icon(Icons.portrait_outlined),
                                label: const Text('Photo'),
                              ),
                              TextButton.icon(
                                onPressed: _pickDocuments,
                                icon: const Icon(Icons.file_upload_outlined),
                                label: const Text('Docs'),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),
                        if (_profilePhotoPath != null ||
                            (tenant?.profilePhoto?.isNotEmpty ?? false))
                          StatusBadge(
                            label: _profilePhotoPath != null
                                ? 'New profile photo selected'
                                : 'Profile photo already uploaded',
                            color: Colors.green,
                          )
                        else
                          const AppEmptyState(
                            title: 'No profile photo yet',
                            message:
                                'A profile photo is optional, but it makes the quick payment flow much easier for family members.',
                            icon: Icons.badge_outlined,
                          ),
                        const SizedBox(height: 14),
                        if ((tenant?.documents.isEmpty ?? true) &&
                            _documents.isEmpty)
                          const AppEmptyState(
                            title: 'No documents attached',
                            message:
                                'Add Aadhaar, agreement, or other files now, or come back later from the tenant detail screen.',
                            icon: Icons.description_outlined,
                          )
                        else
                          Column(
                            children: [
                              ...?tenant?.documents.map(
                                (document) => ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  leading: const Icon(
                                    Icons.insert_drive_file_outlined,
                                  ),
                                  title: Text(document.name),
                                  subtitle: Text(document.type.toUpperCase()),
                                ),
                              ),
                              ..._documents.map(
                                (document) => ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  leading: const Icon(
                                    Icons.upload_file_outlined,
                                  ),
                                  title: Text(_fileName(document.path)),
                                  subtitle: Text(document.type.toUpperCase()),
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 22),
                  FilledButton(
                    onPressed: _saving ? null : _save,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      child: _saving
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(
                              widget.isEditing
                                  ? 'Save tenant'
                                  : 'Create tenant',
                            ),
                    ),
                  ),
                ],
              ),
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) =>
              Center(child: Text('Unable to load rooms.\n$error')),
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) =>
            Center(child: Text('Unable to prepare tenant form.\n$error')),
      ),
    );
  }

  List<RoomModel> _availableRooms(
    List<RoomModel> rooms, {
    String? currentRoomId,
  }) {
    return rooms.where((room) {
      if (currentRoomId != null && room.id == currentRoomId) {
        return true;
      }

      return !room.isOccupied;
    }).toList();
  }

  RoomModel? _selectedRoom(List<RoomModel> rooms) {
    if (_selectedRoomId == null) {
      return null;
    }

    for (final room in rooms) {
      if (room.id == _selectedRoomId) {
        return room;
      }
    }

    return null;
  }

  void _setOpeningDue(num amount) {
    _openingDueController.text = amount.toInt().toString();
    setState(() {});
  }

  String _fileName(String path) {
    final segments = path.split(RegExp(r'[\\/]'));
    return segments.isEmpty ? path : segments.last;
  }
}

class _OpeningDuePreview extends StatelessWidget {
  const _OpeningDuePreview({
    required this.monthlyRent,
    required this.openingDue,
    required this.firstPayable,
  });

  final num monthlyRent;
  final num openingDue;
  final num firstPayable;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: openingDue > 0
            ? AppColors.warning.withValues(alpha: 0.12)
            : Theme.of(context).inputDecorationTheme.fillColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'First payment total',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 10),
          _PreviewLine(
            label: 'Current monthly rent',
            value: CurrencyFormatter.inr(monthlyRent),
          ),
          _PreviewLine(
            label: 'Opening due',
            value: CurrencyFormatter.inr(openingDue),
          ),
          const Divider(height: 18),
          _PreviewLine(
            label: 'Total visible on Add Payment',
            value: CurrencyFormatter.inr(firstPayable),
            strong: true,
          ),
        ],
      ),
    );
  }
}

class _OpeningDueChip extends StatelessWidget {
  const _OpeningDueChip({
    required this.label,
    required this.amount,
    required this.onTap,
  });

  final String label;
  final num amount;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      avatar: const Icon(Icons.add_rounded, size: 16),
      label: Text('$label ${CurrencyFormatter.inr(amount)}'),
      onPressed: onTap,
    );
  }
}

class _PreviewLine extends StatelessWidget {
  const _PreviewLine({
    required this.label,
    required this.value,
    this.strong = false,
  });

  final String label;
  final String value;
  final bool strong;

  @override
  Widget build(BuildContext context) {
    final style = strong
        ? Theme.of(context).textTheme.titleMedium
        : Theme.of(context).textTheme.bodyMedium;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(label, style: Theme.of(context).textTheme.bodySmall),
          ),
          Text(value, style: style),
        ],
      ),
    );
  }
}
