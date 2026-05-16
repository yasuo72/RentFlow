import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/constants/app_colors.dart';
import '../../core/utils/currency_formatter.dart';
import '../../core/utils/validators.dart';
import '../../core/widgets/app_surfaces.dart';
import '../../data/models/room_model.dart';
import '../../data/repositories/room_repository.dart';
import '../auth/auth_provider.dart';
import 'rooms_provider.dart';

class AddEditRoomScreen extends ConsumerStatefulWidget {
  const AddEditRoomScreen({this.roomId, super.key});

  final String? roomId;

  bool get isEditing => roomId != null && roomId!.isNotEmpty;

  @override
  ConsumerState<AddEditRoomScreen> createState() => _AddEditRoomScreenState();
}

class _AddEditRoomScreenState extends ConsumerState<AddEditRoomScreen> {
  final _formKey = GlobalKey<FormState>();
  final _roomNumberController = TextEditingController();
  final _floorController = TextEditingController();
  final _buildingController = TextEditingController(text: 'Main');
  final _monthlyRentController = TextEditingController();
  final _depositController = TextEditingController(text: '0');
  final _meterController = TextEditingController();
  final _notesController = TextEditingController();

  bool _initialized = false;
  bool _saving = false;
  String _status = 'vacant';
  final List<String> _newPhotoPaths = [];

  @override
  void dispose() {
    _roomNumberController.dispose();
    _floorController.dispose();
    _buildingController.dispose();
    _monthlyRentController.dispose();
    _depositController.dispose();
    _meterController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _populateForm(RoomModel room) {
    if (_initialized) {
      return;
    }

    _initialized = true;
    _roomNumberController.text = room.roomNumber;
    _floorController.text = room.floor ?? '';
    _buildingController.text = room.building ?? 'Main';
    _monthlyRentController.text = room.monthlyRent.toString();
    _depositController.text = room.depositAmount.toString();
    _meterController.text = room.electricityMeterNumber ?? '';
    _notesController.text = room.notes ?? '';
    _status = room.status;
  }

  Future<void> _pickPhotos() async {
    final picker = ImagePicker();
    final files = await picker.pickMultiImage(imageQuality: 82);
    if (files.isEmpty) {
      return;
    }

    setState(() {
      _newPhotoPaths.addAll(files.map((file) => file.path));
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _saving = true);
    final repository = ref.read(roomRepositoryProvider);

    try {
      final payload = {
        'roomNumber': _roomNumberController.text.trim(),
        'floor': _floorController.text.trim(),
        'building': _buildingController.text.trim(),
        'monthlyRent': num.parse(_monthlyRentController.text.trim()),
        'depositAmount': num.tryParse(_depositController.text.trim()) ?? 0,
        'status': _status,
        'electricityMeterNumber': _meterController.text.trim(),
        'notes': _notesController.text.trim(),
      };

      final room = widget.isEditing
          ? await repository.updateRoom(widget.roomId!, payload)
          : await repository.createRoom(payload);

      if (_newPhotoPaths.isNotEmpty) {
        await repository.uploadRoomPhotos(room.id, _newPhotoPaths);
      }

      ref.invalidate(roomsProvider);
      ref.invalidate(roomDetailProvider(room.id));

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            widget.isEditing
                ? 'Room ${room.roomNumber} updated.'
                : 'Room ${room.roomNumber} created.',
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
      ).showSnackBar(SnackBar(content: Text('Unable to save room: $error')));
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  Future<void> _deleteRoom() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete room'),
        content: const Text(
          'This permanently removes the room if it is vacant. This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true || widget.roomId == null) {
      return;
    }

    try {
      await ref.read(roomRepositoryProvider).deleteRoom(widget.roomId!);
      ref.invalidate(roomsProvider);
      if (!mounted) {
        return;
      }
      context.pop();
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Unable to delete room: $error')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final isSuperAdmin =
        ref.watch(authControllerProvider).user?.isSuperAdmin ?? false;
    final detail = widget.isEditing
        ? ref.watch(roomDetailProvider(widget.roomId!))
        : const AsyncValue.data(null);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isEditing ? 'Edit Room' : 'Add Room'),
        actions: [
          if (widget.isEditing && isSuperAdmin)
            IconButton(
              onPressed: _deleteRoom,
              icon: const Icon(Icons.delete_outline_rounded),
            ),
        ],
      ),
      body: detail.when(
        data: (room) {
          if (room != null) {
            _populateForm(room);
          }

          final existingPhotos = room?.photos ?? const <String>[];
          final occupiedAndLocked = room?.currentTenant != null;

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              AppHeaderPanel(
                title: widget.isEditing
                    ? 'Room ${room?.roomNumber ?? ''}'
                    : 'Create a new room',
                subtitle: widget.isEditing
                    ? 'Update pricing, utilities, notes, and photo coverage without losing history.'
                    : 'Add the room once, then attach tenants and payments as the family starts using it.',
                trailing: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Text(
                    _status.toUpperCase(),
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              AppSectionCard(
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const AppSectionTitle(
                        title: 'Room details',
                        subtitle: 'Keep the room identity and pricing tidy so payment summaries stay accurate.',
                      ),
                      const SizedBox(height: 18),
                      TextFormField(
                        controller: _roomNumberController,
                        validator: (value) =>
                            Validators.requiredField(value, 'Room number'),
                        decoration: const InputDecoration(
                          labelText: 'Room number',
                        ),
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _floorController,
                              decoration: const InputDecoration(
                                labelText: 'Floor',
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextFormField(
                              controller: _buildingController,
                              decoration: const InputDecoration(
                                labelText: 'Building',
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
                              controller: _monthlyRentController,
                              keyboardType: TextInputType.number,
                              validator: Validators.amount,
                              decoration: const InputDecoration(
                                labelText: 'Monthly rent',
                                prefixText: '₹ ',
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextFormField(
                              controller: _depositController,
                              keyboardType: TextInputType.number,
                              validator: Validators.amount,
                              decoration: const InputDecoration(
                                labelText: 'Deposit',
                                prefixText: '₹ ',
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: _meterController,
                        decoration: const InputDecoration(
                          labelText: 'Electricity meter number',
                        ),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        'Occupancy status',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        children: ['vacant', 'occupied']
                            .map(
                              (value) => ChoiceChip(
                                label: Text(value.toUpperCase()),
                                selected: _status == value,
                                onSelected: occupiedAndLocked
                                    ? null
                                    : (_) => setState(() => _status = value),
                              ),
                            )
                            .toList(),
                      ),
                      if (occupiedAndLocked) ...[
                        const SizedBox(height: 10),
                        Text(
                          'This room has an active tenant, so status changes should happen through tenant reassignment.',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: _notesController,
                        maxLines: 4,
                        decoration: const InputDecoration(
                          labelText: 'Notes',
                          hintText: 'Repairs due, furnishing notes, tenant preferences...',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 18),
              AppSectionCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AppSectionTitle(
                      title: 'Photos',
                      subtitle:
                          '${existingPhotos.length} uploaded | ${_newPhotoPaths.length} pending upload',
                      action: TextButton.icon(
                        onPressed: _pickPhotos,
                        icon: const Icon(Icons.add_photo_alternate_outlined),
                        label: const Text('Add'),
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (existingPhotos.isNotEmpty || _newPhotoPaths.isNotEmpty)
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          ...existingPhotos.map(
                            (photo) => _PhotoToken(
                              label: 'Existing photo',
                              subtitle: photo,
                              color: AppColors.accent,
                            ),
                          ),
                          ..._newPhotoPaths.map(
                            (photo) => _PhotoToken(
                              label: 'New upload',
                              subtitle: _fileName(photo),
                              color: AppColors.primaryLight,
                            ),
                          ),
                        ],
                      )
                    else
                      const AppEmptyState(
                        title: 'No room photos yet',
                        message:
                            'Photos are optional, but they help family members identify rooms faster when recording payments.',
                        icon: Icons.photo_library_outlined,
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              AppSectionCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Quick preview',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Rent ${CurrencyFormatter.inr(num.tryParse(_monthlyRentController.text) ?? 0)} | Deposit ${CurrencyFormatter.inr(num.tryParse(_depositController.text) ?? 0)}',
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _notesController.text.trim().isEmpty
                          ? 'No additional notes yet.'
                          : _notesController.text.trim(),
                      style: Theme.of(context).textTheme.bodySmall,
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
                      : Text(widget.isEditing ? 'Save changes' : 'Create room'),
                ),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) =>
            Center(child: Text('Unable to load room form.\n$error')),
      ),
    );
  }

  String _fileName(String path) {
    final segments = path.split(RegExp(r'[\\/]'));
    return segments.isEmpty ? path : segments.last;
  }
}

class _PhotoToken extends StatelessWidget {
  const _PhotoToken({
    required this.label,
    required this.subtitle,
    required this.color,
  });

  final String label;
  final String subtitle;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 150,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.photo_outlined, color: color),
          const SizedBox(height: 10),
          Text(label, style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 4),
          Text(
            subtitle,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}
