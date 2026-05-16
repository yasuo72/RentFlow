import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_colors.dart';
import '../../core/utils/date_utils.dart';
import '../../core/widgets/app_surfaces.dart';
import '../../data/models/user_model.dart';
import '../../data/repositories/user_repository.dart';
import '../auth/auth_provider.dart';

final manageUsersProvider = FutureProvider<List<UserModel>>((ref) async {
  return ref.read(userRepositoryProvider).fetchUsers();
});

class ManageUsersScreen extends ConsumerWidget {
  const ManageUsersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final usersAsync = ref.watch(manageUsersProvider);
    final authUser = ref.watch(authControllerProvider).user;
    final currentUserId = authUser?.id;
    final isSuperAdmin = authUser?.isSuperAdmin ?? false;

    return Scaffold(
      appBar: AppBar(title: const Text('Manage Users')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showUserSheet(context, ref),
        icon: const Icon(Icons.person_add_alt_1_rounded),
        label: const Text('Add member'),
      ),
      body: usersAsync.when(
        data: (users) => RefreshIndicator(
          onRefresh: () async => ref.invalidate(manageUsersProvider),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
            children: [
              AppHeaderPanel(
                title: 'Family access control',
                subtitle:
                    '${users.where((user) => user.isActive).length} active users sharing the same operational permissions. Roles stay fixed.',
              ),
              const SizedBox(height: 18),
              AppSectionCard(
                child: Row(
                  children: [
                    _UserMetric(
                      label: 'Owner role',
                      value: users.where((user) => user.isSuperAdmin).length,
                    ),
                    _UserMetric(
                      label: 'Active',
                      value: users.where((user) => user.isActive).length,
                    ),
                    _UserMetric(
                      label: 'Inactive',
                      value: users.where((user) => !user.isActive).length,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              if (users.isEmpty)
                const AppEmptyState(
                  title: 'No family users found',
                  message:
                      'Create the first family member account to start sharing updates beyond the super admin.',
                  icon: Icons.group_off_rounded,
                )
              else
                ...users.map(
                  (user) {
                    final isProtectedUser =
                        user.isSuperAdmin || user.id == currentUserId;

                    return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: AppSectionCard(
                      child: Column(
                        children: [
                          Row(
                            children: [
                              CircleAvatar(
                                backgroundColor: user.isSuperAdmin
                                    ? AppColors.primaryLight.withValues(alpha: 0.18)
                                    : AppColors.accent.withValues(alpha: 0.16),
                                child: Text(
                                  user.name.isEmpty ? '?' : user.name[0].toUpperCase(),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      user.name,
                                      style: Theme.of(context).textTheme.titleMedium,
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '${user.phone}${user.email?.isNotEmpty == true ? ' | ${user.email}' : ''}',
                                      style: Theme.of(context).textTheme.bodySmall,
                                    ),
                                  ],
                                ),
                              ),
                              StatusBadge(
                                label: user.isSuperAdmin
                                    ? 'SUPER ADMIN'
                                    : user.isActive
                                    ? 'ACTIVE'
                                    : 'INACTIVE',
                                color: user.isSuperAdmin
                                    ? AppColors.primaryLight
                                    : user.isActive
                                    ? AppColors.accent
                                    : AppColors.warning,
                              ),
                              PopupMenuButton<String>(
                                onSelected: (value) async {
                                  if (value == 'edit') {
                                    await _showUserSheet(
                                      context,
                                      ref,
                                      user: user,
                                      currentUserId: currentUserId,
                                      canManageAccess: isSuperAdmin,
                                    );
                                  } else if (value == 'toggle') {
                                    await ref.read(userRepositoryProvider).updateUser(
                                      user.id,
                                      {'isActive': !user.isActive},
                                    );
                                    ref.invalidate(manageUsersProvider);
                                  } else if (value == 'deactivate') {
                                    await _confirmDeactivate(context, ref, user);
                                  }
                                },
                                itemBuilder: (context) => [
                                  const PopupMenuItem(
                                    value: 'edit',
                                    child: Text('Edit details'),
                                  ),
                                  if (isSuperAdmin && !isProtectedUser)
                                    PopupMenuItem(
                                      value: 'toggle',
                                      child: Text(user.isActive ? 'Mark inactive' : 'Reactivate'),
                                    ),
                                  if (isSuperAdmin && !isProtectedUser)
                                    const PopupMenuItem(
                                      value: 'deactivate',
                                      child: Text('Deactivate'),
                                    ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          Row(
                            children: [
                              Expanded(
                                child: _DetailChip(
                                  label: 'Last login',
                                  value: user.lastLogin != null
                                      ? AppDateUtils.formatDateTime(user.lastLogin)
                                      : 'Never',
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: _DetailChip(
                                  label: 'Created',
                                  value: AppDateUtils.formatDate(user.createdAt),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                  },
                ),
            ],
          ),
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) =>
            Center(child: Text('Unable to load users.\n$error')),
      ),
    );
  }

  static Future<void> _confirmDeactivate(
    BuildContext context,
    WidgetRef ref,
    UserModel user,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Deactivate ${user.name}?'),
        content: const Text(
          'This removes their access to the shared app until the account is reactivated.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Deactivate'),
          ),
        ],
      ),
    );

    if (confirmed != true) {
      return;
    }

    await ref.read(userRepositoryProvider).deactivateUser(user.id);
    ref.invalidate(manageUsersProvider);
  }

  static Future<void> _showUserSheet(
    BuildContext context,
    WidgetRef ref, {
    UserModel? user,
    String? currentUserId,
    bool canManageAccess = false,
  }) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => _UserEditorSheet(
        user: user,
        currentUserId: currentUserId,
        canManageAccess: canManageAccess,
      ),
    );
    ref.invalidate(manageUsersProvider);
  }
}

class _UserMetric extends StatelessWidget {
  const _UserMetric({required this.label, required this.value});

  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text('$value', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 4),
          Text(label, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}

class _DetailChip extends StatelessWidget {
  const _DetailChip({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.52),
      ),
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

class _UserEditorSheet extends ConsumerStatefulWidget {
  const _UserEditorSheet({
    this.user,
    this.currentUserId,
    this.canManageAccess = false,
  });

  final UserModel? user;
  final String? currentUserId;
  final bool canManageAccess;

  bool get isEditing => user != null;

  bool get isProtectedAccount =>
      (user?.isSuperAdmin ?? false) || user?.id == currentUserId;

  @override
  ConsumerState<_UserEditorSheet> createState() => _UserEditorSheetState();
}

class _UserEditorSheetState extends ConsumerState<_UserEditorSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _phoneController;
  late final TextEditingController _emailController;
  late final TextEditingController _passwordController;
  late bool _isActive;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final user = widget.user;
    _nameController = TextEditingController(text: user?.name ?? '');
    _phoneController = TextEditingController(text: user?.phone ?? '');
    _emailController = TextEditingController(text: user?.email ?? '');
    _passwordController = TextEditingController();
    _isActive = user?.isActive ?? true;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _saving = true);
    final repository = ref.read(userRepositoryProvider);

    try {
      if (widget.isEditing) {
        await repository.updateUser(widget.user!.id, {
          'name': _nameController.text.trim(),
          'phone': _phoneController.text.trim(),
          'email': _emailController.text.trim(),
          'isActive': _isActive,
          if (_passwordController.text.trim().isNotEmpty)
            'password': _passwordController.text.trim(),
        });
      } else {
        await repository.createUser({
          'name': _nameController.text.trim(),
          'phone': _phoneController.text.trim(),
          'email': _emailController.text.trim(),
          'password': _passwordController.text.trim(),
        });
      }

      if (!mounted) {
        return;
      }
      Navigator.of(context).pop();
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Unable to save user: $error')));
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 20, 20, bottomInset + 24),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.isEditing ? 'Edit family member' : 'Add family member',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              Text(
                widget.isEditing
                    ? 'Update access, contact details, or reset the password.'
                    : 'Create a login for a trusted family member. They will immediately share the same live data.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 18),
              TextFormField(
                controller: _nameController,
                validator: (value) =>
                    value == null || value.trim().isEmpty ? 'Name is required.' : null,
                decoration: const InputDecoration(labelText: 'Name'),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'Phone is required.'
                    : null,
                decoration: const InputDecoration(labelText: 'Phone'),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(labelText: 'Email'),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _passwordController,
                obscureText: true,
                validator: (value) {
                  if (!widget.isEditing && (value == null || value.trim().length < 6)) {
                    return 'Password must be at least 6 characters.';
                  }
                  return null;
                },
                decoration: InputDecoration(
                  labelText: widget.isEditing ? 'New password (optional)' : 'Password',
                ),
              ),
              if (
                widget.isEditing &&
                widget.canManageAccess &&
                !widget.isProtectedAccount
              ) ...[
                const SizedBox(height: 14),
                SwitchListTile(
                  value: _isActive,
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Active account'),
                  subtitle: const Text('Inactive users cannot sign in.'),
                  onChanged: (value) => setState(() => _isActive = value),
                ),
              ],
              const SizedBox(height: 18),
              FilledButton(
                onPressed: _saving ? null : _submit,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  child: _saving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(widget.isEditing ? 'Save changes' : 'Create user'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
