import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/services/departments_service.dart';
import '../../../core/widgets/app_topbar_actions.dart';
import '../../../data/datasources/users_remote_datasource.dart';
import '../../../data/models/department_model.dart';
import '../../../data/models/user_model.dart';
import '../../auth/bloc/auth_bloc.dart';

/// Overview of users and their feedback ratings. Visible only to Ledelse and HR.
/// Supports filtering by department and sorting by rating (ascending/descending).
class UserRatingsOverviewPage extends StatefulWidget {
  const UserRatingsOverviewPage({super.key});

  @override
  State<UserRatingsOverviewPage> createState() =>
      _UserRatingsOverviewPageState();
}

class _UserRatingsOverviewPageState extends State<UserRatingsOverviewPage> {
  final UsersRemoteDataSource _usersDataSource = UsersRemoteDataSource();
  final DepartmentsService _departmentsService = DepartmentsService();

  List<UserModel> _users = [];
  List<DepartmentModel> _departments = [];
  bool _loading = true;
  String? _error;

  /// null or empty = show all departments
  String? _selectedDepartmentId;
  bool _sortAscending = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _load();
    });
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final jwt = context.read<AuthBloc>().currentToken;
      final userList = await _usersDataSource.getUsers();
      List<DepartmentModel> deptList = [];
      if (jwt != null && jwt.isNotEmpty) {
        try {
          deptList = await _departmentsService.getDepartments(jwt);
        } catch (_) {
          // Continue without department filter
        }
      }
      if (!mounted) return;
      setState(() {
        _users = userList;
        _departments = deptList;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  List<UserModel> get _filteredAndSortedUsers {
    var list = List<UserModel>.from(_users);
    if (_selectedDepartmentId != null &&
        _selectedDepartmentId!.isNotEmpty) {
      list = list
          .where((u) => u.departmentId == _selectedDepartmentId)
          .toList();
    }
    list.sort((a, b) {
      final cmp = a.feedbackRating.compareTo(b.feedbackRating);
      return _sortAscending ? cmp : -cmp;
    });
    return list;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('User ratings'),
        actions: const [AppTopBarActions()],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _error!,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: () => _load(),
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                )
              : _buildContent(context),
    );
  }

  Widget _buildContent(BuildContext context) {
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: _RatingsFilters(
              departments: _departments,
              selectedDepartmentId: _selectedDepartmentId,
              sortAscending: _sortAscending,
              onDepartmentChanged: (id) {
                setState(() => _selectedDepartmentId = id);
              },
              onSortChanged: (asc) {
                setState(() => _sortAscending = asc);
              },
            ),
          ),
        ),
        SliverToBoxAdapter(child: const SizedBox(height: 8)),
        _users.isEmpty
            ? const SliverFillRemaining(
                child: Center(child: Text('No users')),
              )
            : _filteredAndSortedUsers.isEmpty
                ? const SliverFillRemaining(
                    child: Center(
                        child: Text('No users in the selected department')),
                  )
                : SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final user = _filteredAndSortedUsers[index];
                        return _UserRatingTile(
                          name: user.name,
                          departmentName:
                              user.departmentName ?? 'No department',
                          rating: user.feedbackRating,
                        );
                      },
                      childCount: _filteredAndSortedUsers.length,
                    ),
                  ),
      ],
    );
  }

}

class _RatingsFilters extends StatelessWidget {
  const _RatingsFilters({
    required this.departments,
    required this.selectedDepartmentId,
    required this.sortAscending,
    required this.onDepartmentChanged,
    required this.onSortChanged,
  });

  final List<DepartmentModel> departments;
  final String? selectedDepartmentId;
  final bool sortAscending;
  final ValueChanged<String?> onDepartmentChanged;
  final ValueChanged<bool> onSortChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: DropdownButtonFormField<String?>(
            value: selectedDepartmentId,
            decoration: const InputDecoration(
              labelText: 'Department',
              border: OutlineInputBorder(),
            ),
            items: [
              const DropdownMenuItem<String?>(
                value: null,
                child: Text('All departments'),
              ),
              ...departments
                  .map(
                    (d) => DropdownMenuItem<String?>(
                      value: d.id,
                      child: Text(d.name),
                    ),
                  )
                  .toList(),
            ],
            onChanged: onDepartmentChanged,
          ),
        ),
        const SizedBox(width: 12),
        IconButton(
          tooltip: sortAscending
              ? 'Sort: low to high (tap to switch)'
              : 'Sort: high to low (tap to switch)',
          icon: Icon(
            sortAscending ? Icons.arrow_upward : Icons.arrow_downward,
          ),
          onPressed: () => onSortChanged(!sortAscending),
        ),
      ],
    );
  }
}

class _UserRatingTile extends StatelessWidget {
  const _UserRatingTile({
    required this.name,
    required this.departmentName,
    required this.rating,
  });

  final String name;
  final String departmentName;
  final int rating;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: ListTile(
        title: Text(name),
        subtitle: Text(departmentName),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            '$rating/10',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
        ),
      ),
    );
  }
}
