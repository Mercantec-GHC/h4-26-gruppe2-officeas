import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../../../data/datasources/messaging_remote_datasource.dart';
import '../../../data/models/messaging_models.dart';
import '../../../data/models/user_model.dart';
import '../../../features/auth/bloc/auth_bloc.dart';
import '../bloc/messaging_bloc.dart';
import '../bloc/messaging_event.dart';
import '../bloc/messaging_state.dart';

/// Page for searching users and starting a new conversation.
class NewConversationPage extends StatefulWidget {
  const NewConversationPage({super.key});

  @override
  State<NewConversationPage> createState() => _NewConversationPageState();
}

class _NewConversationPageState extends State<NewConversationPage> {
  final _searchController = TextEditingController();
  final _messageController = TextEditingController();
  List<UserModel> _allUsers = [];
  List<UserModel> _filteredUsers = [];
  final Set<String> _selectedUserIds = <String>{};
  bool _isLoading = true;
  bool _isSubmitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    try {
      final dataSource = MessagingRemoteDataSource();

      // Capture context-dependent values before the async gap
      final currentUserId =
          context.read<AuthBloc>().currentUser?.id.toString() ?? '';

      final users = await dataSource.getUsers();

      // Exclude the current user from the list.
      final filtered = users.where((u) => u.id != currentUserId).toList();

      if (mounted) {
        setState(() {
          _allUsers = filtered;
          _filteredUsers = filtered;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Could not fetch users. Try again.';
          _isLoading = false;
        });
      }
    }
  }

  void _onSearchChanged(String query) {
    final lower = query.toLowerCase();
    setState(() {
      _filteredUsers = _allUsers.where((u) {
        return u.name.toLowerCase().contains(lower) ||
            u.email.toLowerCase().contains(lower) ||
            (u.departmentName ?? '').toLowerCase().contains(lower) ||
            (u.departmentId ?? '').toLowerCase().contains(lower);
      }).toList();
    });
  }

  Future<void> _startConversation(UserModel user) async {
    _toggleUserSelection(user.id);
  }

  void _toggleUserSelection(String userId) {
    setState(() {
      if (_selectedUserIds.contains(userId)) {
        _selectedUserIds.remove(userId);
      } else {
        _selectedUserIds.add(userId);
      }
    });
  }

  Future<void> _createOrSendToSelection() async {
    if (_selectedUserIds.isEmpty || _isSubmitting) return;

    setState(() => _isSubmitting = true);

    final bloc = context.read<MessagingBloc>();
    final dataSource = MessagingRemoteDataSource();
    final currentUserId =
        context.read<AuthBloc>().currentUser?.id.toString() ?? '';
    final selected = _selectedUserIds.toList();
    final isGroup = selected.length > 1;
    final firstMessage = _messageController.text.trim();

    try {
      ConversationModel conv;
      if (firstMessage.isNotEmpty) {
        conv = await dataSource.sendMessageToUsers(
          userIds: selected,
          content: firstMessage,
          isGroup: isGroup,
        );
      } else {
        bloc.add(
          CreateConversation(
            userIds: [currentUserId, ...selected],
            isGroup: isGroup,
          ),
        );

        final state = await bloc.stream.firstWhere(
          (s) => s is ConversationsLoaded || s is MessagingError,
        );

        if (state is MessagingError) {
          throw Exception(state.message);
        }

        final loaded = state as ConversationsLoaded;
        conv = loaded.conversations.firstWhere(
          (c) => selected.every((id) => c.members.any((m) => m.userId == id)),
          orElse: () => loaded.conversations.first,
        );
      }

      if (!mounted) return;

      context.go('/messages/chat/${conv.id}', extra: conv);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString())));
      setState(() => _isSubmitting = false);
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final appBarForeground =
        Theme.of(context).appBarTheme.foregroundColor ??
        Theme.of(context).colorScheme.onSurface;
    return AppScaffold(
      title: const Text('New conversation'),
      showBackButtonWhenPossible: true,
      actions: [
        TextButton(
          onPressed: _selectedUserIds.isEmpty || _isSubmitting
              ? null
              : _createOrSendToSelection,
          child: Text(
            _isSubmitting ? 'SENDING...' : 'NEXT',
            style: TextStyle(color: appBarForeground),
          ),
        ),
      ],
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              controller: _searchController,
              onChanged: _onSearchChanged,
              decoration: InputDecoration(
                hintText: 'Search by name or email...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: Theme.of(
                  context,
                ).colorScheme.surfaceContainerHighest,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: TextField(
              controller: _messageController,
              maxLines: 2,
              decoration: InputDecoration(
                hintText: 'Optional: write first message to all selected users',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          if (_selectedUserIds.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '${_selectedUserIds.length} selected',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ),
          // Results
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline,
              size: 48,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(height: 16),
            Text(
              _error!,
              style: TextStyle(
                color: Theme.of(context).textTheme.bodyMedium?.color,
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  _isLoading = true;
                  _error = null;
                });
                _loadUsers();
              },
              child: const Text('Try again'),
            ),
          ],
        ),
      );
    }
    if (_filteredUsers.isEmpty) {
      return Center(
        child: Text(
          _searchController.text.isEmpty
              ? 'No users found'
              : 'No results for "${_searchController.text}"',
          style: TextStyle(
            color: Theme.of(
              context,
            ).textTheme.bodyMedium?.color?.withValues(alpha: 0.72),
          ),
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 4),
      itemCount: _filteredUsers.length,
      separatorBuilder: (_, __) =>
          const Divider(height: 1, indent: 72, endIndent: 16),
      itemBuilder: (context, index) {
        final user = _filteredUsers[index];
        return _UserTile(
          user: user,
          selected: _selectedUserIds.contains(user.id),
          onTap: () => _startConversation(user),
        );
      },
    );
  }
}

class _UserTile extends StatelessWidget {
  final UserModel user;
  final bool selected;
  final VoidCallback onTap;

  const _UserTile({
    required this.user,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final departmentLabel = user.departmentName?.trim().isNotEmpty == true
        ? user.departmentName!.trim()
        : (user.departmentId?.trim().isNotEmpty == true
              ? 'Dept ID: ${user.departmentId!.trim()}'
              : 'No department');
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: Theme.of(context).colorScheme.primary,
        child: Text(
          user.name.isNotEmpty ? user.name[0].toUpperCase() : '?',
          style: TextStyle(
            color: Theme.of(context).colorScheme.onPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      title: Text(
        user.name,
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      subtitle: Text(
        '${user.email}\n$departmentLabel',
        style: TextStyle(
          color: Theme.of(
            context,
          ).textTheme.bodyMedium?.color?.withValues(alpha: 0.72),
          fontSize: 13,
        ),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      isThreeLine: true,
      trailing: Icon(
        selected ? Icons.check_circle : Icons.radio_button_unchecked,
        color: selected
            ? Theme.of(context).colorScheme.primary
            : Theme.of(
                context,
              ).textTheme.bodyMedium?.color?.withValues(alpha: 0.72),
        size: 22,
      ),
      onTap: onTap,
    );
  }
}
