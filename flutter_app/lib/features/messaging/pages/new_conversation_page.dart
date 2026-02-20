import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/theme/colors.dart';
import '../../../data/datasources/messaging_remote_datasource.dart';
import '../../../data/models/user_model.dart';
import '../../../features/auth/bloc/auth_bloc.dart';
import '../bloc/messaging_bloc.dart';
import '../bloc/messaging_event.dart';
import '../bloc/messaging_state.dart';
import 'chat_page.dart';

/// Page for searching users and starting a new conversation.
class NewConversationPage extends StatefulWidget {
  const NewConversationPage({super.key});

  @override
  State<NewConversationPage> createState() => _NewConversationPageState();
}

class _NewConversationPageState extends State<NewConversationPage> {
  final _searchController = TextEditingController();
  List<UserModel> _allUsers = [];
  List<UserModel> _filteredUsers = [];
  bool _isLoading = true;
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
      final currentUserId = context.read<AuthBloc>().currentUser?.id.toString() ?? '';

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
          _error = 'Kunne ikke hente brugere. Prøv igen.';
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
            u.email.toLowerCase().contains(lower);
      }).toList();
    });
  }

  Future<void> _startConversation(UserModel user) async {
    final bloc = context.read<MessagingBloc>();
    final currentUserId =
        context.read<AuthBloc>().currentUser?.id.toString() ?? '';

    // The backend will return the existing 1:1 conversation if one exists,
    // or create a new one. Either way we get a ConversationModel back.
    bloc.add(
      CreateConversation(userIds: [currentUserId, user.id], isGroup: false),
    );

    // Wait for the ConversationsLoaded state which contains the conversation.
    final state = await bloc.stream.firstWhere(
      (s) => s is ConversationsLoaded || s is MessagingError,
    );

    if (!mounted) return;

    if (state is ConversationsLoaded && state.conversations.isNotEmpty) {
      // Find the conversation that has this user as a member.
      final conv = state.conversations.firstWhere(
        (c) => c.members.any((m) => m.userId == user.id),
        orElse: () => state.conversations.first,
      );
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => BlocProvider.value(
            value: bloc,
            child: ChatPage(conversation: conv),
          ),
        ),
      );
    } else if (state is MessagingError) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(state.message)));
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ny besked'),
        backgroundColor: Colors.blue.shade700,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              controller: _searchController,
              onChanged: _onSearchChanged,
              decoration: InputDecoration(
                hintText: 'Søg efter navn eller e-mail...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: AppColors.background,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
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
            const Icon(Icons.error_outline, size: 48, color: AppColors.error),
            const SizedBox(height: 16),
            Text(_error!, style: const TextStyle(color: AppColors.text)),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  _isLoading = true;
                  _error = null;
                });
                _loadUsers();
              },
              child: const Text('Prøv igen'),
            ),
          ],
        ),
      );
    }
    if (_filteredUsers.isEmpty) {
      return Center(
        child: Text(
          _searchController.text.isEmpty
              ? 'Ingen brugere fundet'
              : 'Ingen resultater for "${_searchController.text}"',
          style: const TextStyle(color: AppColors.subtitle),
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
        return _UserTile(user: user, onTap: () => _startConversation(user));
      },
    );
  }
}

class _UserTile extends StatelessWidget {
  final UserModel user;
  final VoidCallback onTap;

  const _UserTile({required this.user, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: AppColors.primary,
        child: Text(
          user.name.isNotEmpty ? user.name[0].toUpperCase() : '?',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      title: Text(
        user.name,
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      subtitle: Text(
        user.email,
        style: const TextStyle(color: AppColors.subtitle, fontSize: 13),
      ),
      trailing: const Icon(
        Icons.chat_bubble_outline,
        color: AppColors.primary,
        size: 20,
      ),
      onTap: onTap,
    );
  }
}
