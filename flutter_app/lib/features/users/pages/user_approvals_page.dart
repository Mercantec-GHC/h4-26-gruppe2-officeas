import 'package:flutter/material.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../../../data/datasources/users_remote_datasource.dart';
import '../../../data/models/user_model.dart';

class UserApprovalsPage extends StatefulWidget {
  const UserApprovalsPage({super.key});

  @override
  State<UserApprovalsPage> createState() => _UserApprovalsPageState();
}

class _UserApprovalsPageState extends State<UserApprovalsPage> {
  final UsersRemoteDataSource _dataSource = UsersRemoteDataSource();
  bool _isLoading = true;
  bool _isApproving = false;
  String? _error;
  List<UserModel> _pendingUsers = [];

  @override
  void initState() {
    super.initState();
    _loadPendingUsers();
  }

  Future<void> _loadPendingUsers() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final pending = await _dataSource.getPendingUsers();

      if (!mounted) return;
      setState(() {
        _pendingUsers = pending;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Failed to load pending users: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _approve(UserModel user) async {
    setState(() => _isApproving = true);
    try {
      await _dataSource.approveUser(user.id);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Approved ${user.name}')));
      await _loadPendingUsers();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Approval failed')));
      setState(() => _isApproving = false);
    } finally {
      if (mounted) setState(() => _isApproving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: const Text('Account approvals'),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(child: Text(_error!))
          : _pendingUsers.isEmpty
          ? const Center(child: Text('No pending accounts'))
          : RefreshIndicator(
              onRefresh: _loadPendingUsers,
              child: ListView.separated(
                itemCount: _pendingUsers.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final user = _pendingUsers[index];
                  return ListTile(
                    leading: CircleAvatar(
                      child: Text(
                        user.name.isNotEmpty ? user.name[0].toUpperCase() : '?',
                      ),
                    ),
                    title: Text(user.name),
                    subtitle: Text(
                      '${user.email}\nDept ID: ${user.departmentId ?? '-'}',
                    ),
                    isThreeLine: true,
                    trailing: ElevatedButton(
                      onPressed: _isApproving ? null : () => _approve(user),
                      child: const Text('Approve'),
                    ),
                  );
                },
              ),
            ),
    );
  }
}
