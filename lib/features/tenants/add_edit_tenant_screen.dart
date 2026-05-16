import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/utils/date_utils.dart';
import '../../core/utils/validators.dart';
import '../../core/widgets/app_surfaces.dart';
import '../../data/models/room_model.dart';
import '../../data/models/tenant_model.dart';
import '../../data/repositories/tenant_repository.dart';
import '../rooms/rooms_provider.dart';
import 'tenants_provider.dart';

class AddEditTenantScreen extends ConsumerStatefulWidget {
  const AddEditTenantScreen({this.tenantId, super.key});

  final String? tenantId;

  bool get isEditing => tenantId != null && tenantId!.isNotEmpty;

  @override
  ConsumerState<AddEditTenantScreen> createState() => _AddEditTenantScreenState();
}

class _AddEditTenantScreenState extends ConsumerState<AddEditTenantScreen> {
  final _formKey = GlobalKey<FormState>();
  final _fullNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _alternatePhoneController = TextEditingController();
  final _idNumberController = TextEditingController();
  final _occupationController = TextEditingController();
  final _familyMembersController = TextEditingController(text: '1');
  final _addressController = TextEditingController();
  final _emergencyNameController = TextEditingController();
  final _emergencyPhoneController = TextEditingController();
  final _emergencyRelationController = TextEditingController();
  final _notesController = TextEditingController();

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
    _alternatePhoneController.dispose();
    _idNumberController.dispose();
    _occupationController.dispose();
    _familyMembersController.dispose();
    _addressController.dispose();
    _emergencyNameController.dispose();
    _emergencyPhoneController.dispose();
    _emergencyRelationController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _populateForm(TenantModel tenant) {
    if (_initialized) {
      return;
    }

    _initialized = true;
    _fullNameController.text = tenant.fullName;
    _phoneController.text = tenant.phone;
    _alternatePhoneController.text = tenant.alternatePhone ?? '';
    _idNumberController.text = tenant.idNumber ?? '';
    _occupationController.text = tenant.occupation ?? '';
    _familyMembersController.text = tenant.familyMembers.toString();
    _addressController.text = tenant.permanentAddress ?? '';
    _emergencyNameController.text = tenant.emergencyContact?.name ?? '';
    _emergencyPhoneController.text = tenant.emergencyContact?.phone ?? '';
    _emergencyRelationController.text = tenant.emergencyContact?.relation ?? '';
    _notesController.text = tenant.notes ?? '';
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
        const SnackBar(content: Text('Tenant form is not ready yet. Please try again.')),
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

            final availableRooms = _availableRooms(rooms, currentRoomId: tenant?.room?.id);
            _selectedRoomId ??= availableRooms.isNotEmpty ? availableRooms.first.id : null;

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
                  AppSectionCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const AppSectionTitle(
                          title: 'Identity',
                          subtitle: 'These details appear in rooms, payments, and reports.',
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
                          subtitle: 'Room assignment and emergency contact help everyone respond quickly.',
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
                          onChanged: (value) => setState(() => _selectedRoomId = value),
                        ),
                        if (availableRooms.isEmpty) ...[
                          const SizedBox(height: 10),
                          const Text('No vacant rooms are available right now.'),
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
                            hintText: 'Move-in condition, family context, agreement reminders...',
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
                        if (_profilePhotoPath != null || (tenant?.profilePhoto?.isNotEmpty ?? false))
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
                        if ((tenant?.documents.isEmpty ?? true) && _documents.isEmpty)
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
                                  leading: const Icon(Icons.insert_drive_file_outlined),
                                  title: Text(document.name),
                                  subtitle: Text(document.type.toUpperCase()),
                                ),
                              ),
                              ..._documents.map(
                                (document) => ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  leading: const Icon(Icons.upload_file_outlined),
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
                          : Text(widget.isEditing ? 'Save tenant' : 'Create tenant'),
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

  String _fileName(String path) {
    final segments = path.split(RegExp(r'[\\/]'));
    return segments.isEmpty ? path : segments.last;
  }
}
