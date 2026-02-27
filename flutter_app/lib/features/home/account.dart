import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../core/di/injection.dart';
import '../../core/utils/pick_image_bytes.dart';
import '../../core/widgets/app_scaffold.dart';
import '../../core/widgets/auth_image.dart';
import '../../data/models/user_model.dart';
import '../../data/repositories/user_repository.dart';
import '../auth/bloc/auth_bloc.dart';
import '../auth/bloc/auth_event.dart';

class AccountPage extends StatefulWidget {
  const AccountPage({super.key});

  @override
  State<AccountPage> createState() => _AccountPageState();
}

class _AccountPageState extends State<AccountPage> {
  bool _isEditing = false;
  Uint8List? _profileImageBytes;
  late TextEditingController _nameController;
  late TextEditingController _emailController;

  @override
  void initState() {
    super.initState();
    final authBloc = context.read<AuthBloc>();
    final user = authBloc.currentUser;
    _nameController = TextEditingController(text: user?.name ?? '');
    _emailController = TextEditingController(text: user?.email ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _openCamera() async {
    try {
      final result = await pickImageBytes(context);
      if (result == null || !mounted) return;

      setState(() => _profileImageBytes = Uint8List.fromList(result.bytes));
      await _uploadProfileImage(result.bytes, result.filename);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _uploadProfileImage(List<int> bytes, String filename) async {
    final authBloc = context.read<AuthBloc>();
    try {
      final userRepo = getIt<UserRepository>();
      final updatedUser = await userRepo.uploadProfileImage(
        bytes,
        filename: filename,
      );

      if (!mounted) return;

      authBloc.add(UserUpdated(updatedUser));
      setState(() => _profileImageBytes = null);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Profile picture uploaded'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Upload failed: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _toggleEdit() {
    setState(() => _isEditing = !_isEditing);
  }

  void _saveProfile() {
    // Currently this is a local UI change only; integrate with backend when available.
    setState(() => _isEditing = false);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Profile saved')));
  }

  void _changePassword() {
    showDialog(
      context: context,
      builder: (context) {
        final oldCtrl = TextEditingController();
        final newCtrl = TextEditingController();
        return AlertDialog(
          title: const Text('Change password'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: oldCtrl,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Current password',
                ),
              ),
              TextField(
                controller: newCtrl,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'New password'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Password changed (demo)')),
                );
              },
              child: const Text('Change'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final authBloc = context.read<AuthBloc>();
    final UserModel? user = authBloc.currentUser;

    return AppScaffold(
      title: const Text('Account'),
      showAccount: false,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth >= 900;
          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: isWide ? 1100 : 720),
                child: isWide
                    ? _buildWide(context, user)
                    : _buildNarrow(context, user),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildWide(BuildContext context, UserModel? user) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(flex: 2, child: _profileCard(context, user)),
        const SizedBox(width: 24),
        Expanded(flex: 3, child: _detailsCard(context, user)),
      ],
    );
  }

  Widget _buildNarrow(BuildContext context, UserModel? user) {
    return Column(
      children: [
        _profileCard(context, user),
        const SizedBox(height: 16),
        _detailsCard(context, user),
      ],
    );
  }

  Widget _profileCard(BuildContext context, UserModel? user) {
    final authBloc = context.read<AuthBloc>();
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final secondaryText = Theme.of(
      context,
    ).textTheme.bodyMedium?.color?.withValues(alpha: 0.72);
    final initials =
        (user?.name
                    .split(' ')
                    .map((e) => e.isNotEmpty ? e[0] : '')
                    .take(2)
                    .join() ??
                '')
            .toUpperCase();
    final avatarBg = isDark
        ? scheme.surfaceContainerHighest
        : Colors.blue.shade50;
    final avatarWidget = _profileImageBytes != null
        ? CircleAvatar(
            radius: 44,
            backgroundColor: avatarBg,
            foregroundImage: MemoryImage(_profileImageBytes!),
          )
        : user?.avatarUrl != null && user!.avatarUrl!.isNotEmpty
        ? ClipOval(
            child: SizedBox(
              width: 88,
              height: 88,
              child: AuthImage(
                imageUrl: UserRepository.imageUrl(user.avatarUrl!),
                token: authBloc.currentToken,
                fit: BoxFit.cover,
              ),
            ),
          )
        : CircleAvatar(
            radius: 44,
            backgroundColor: avatarBg,
            child: Text(
              initials,
              style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w700),
            ),
          );
    return Card(
      elevation: 6,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                avatarWidget,
                _isEditing
                    ? Row(
                        children: [
                          TextButton(
                            onPressed: _toggleEdit,
                            child: const Text('Cancel'),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton.icon(
                            onPressed: _saveProfile,
                            icon: const Icon(Icons.save),
                            label: const Text('Save'),
                          ),
                        ],
                      )
                    : ElevatedButton.icon(
                        onPressed: _toggleEdit,
                        icon: const Icon(Icons.edit),
                        label: const Text('Edit'),
                      ),
              ],
            ),
            const SizedBox(height: 18),
            _isEditing
                ? TextField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      labelText: 'Name',
                      border: OutlineInputBorder(),
                    ),
                  )
                : Text(
                    user?.name ?? 'Guest',
                    style: Theme.of(context).textTheme.headlineSmall
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
            const SizedBox(height: 12),
            _isEditing
                ? TextField(
                    controller: _emailController,
                    decoration: const InputDecoration(
                      labelText: 'Email',
                      border: OutlineInputBorder(),
                    ),
                  )
                : Text(
                    user?.email ?? '',
                    style: Theme.of(context).textTheme.bodyMedium
                        ?.copyWith(color: secondaryText),
                  ),
            const SizedBox(height: 18),
            _departmentBox(context, user?.departmentName ?? '—'),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: _openCamera,
              icon: const Icon(Icons.camera_alt),
              label: const Text('Take picture'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _detailsCard(BuildContext context, UserModel? user) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Profile',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            _isEditing
                ? _editableRow('Name', _nameController)
                : _infoRow('Name', user?.name ?? ''),
            const Divider(),
            _isEditing
                ? _editableRow('Email', _emailController)
                : _infoRow('Email', user?.email ?? ''),
            const Divider(),
            _infoRow(
              'Created',
              user != null ? _formatDate(user.createdAt) : '',
            ),
            const SizedBox(height: 18),
            Text('Actions', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                ElevatedButton.icon(
                  onPressed: _changePassword,
                  icon: const Icon(Icons.key),
                  label: const Text('Change password'),
                ),
                OutlinedButton.icon(
                  onPressed: () {},
                  icon: const Icon(Icons.history),
                  label: const Text('Activity'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _editableRow(String label, TextEditingController controller) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          SizedBox(
            width: 140,
            child: Text(label, style: const TextStyle(color: Colors.black54)),
          ),
          Expanded(
            child: TextField(
              controller: controller,
              decoration: const InputDecoration(
                border: InputBorder.none,
                isDense: true,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    final labelColor = Theme.of(
      context,
    ).textTheme.bodyMedium?.color?.withValues(alpha: 0.78);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          SizedBox(
            width: 140,
            child: Text(label, style: TextStyle(color: labelColor)),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  Widget _departmentBox(BuildContext context, String value) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final labelColor = Theme.of(
      context,
    ).textTheme.bodyMedium?.color?.withValues(alpha: 0.78);
    return SizedBox(
      width: double.infinity,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
        decoration: BoxDecoration(
          color: isDark ? scheme.surfaceContainerHighest : Colors.grey.shade50,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Department', style: TextStyle(color: labelColor)),
            const SizedBox(height: 6),
            Text(
              value,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime d) {
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }
}
