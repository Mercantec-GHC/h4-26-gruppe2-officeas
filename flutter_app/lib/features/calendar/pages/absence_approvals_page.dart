import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../../../domain/entities/absence_request_entity.dart';
import '../../../domain/repositories/absence_request_repository.dart';

class AbsenceApprovalsPage extends StatefulWidget {
  const AbsenceApprovalsPage({
    super.key,
    required this.absenceRequestRepository,
  });

  final AbsenceRequestRepository absenceRequestRepository;

  @override
  State<AbsenceApprovalsPage> createState() => _AbsenceApprovalsPageState();
}

class _AbsenceApprovalsPageState extends State<AbsenceApprovalsPage> {
  bool _isLoading = true;
  String? _error;
  List<AbsenceRequestEntity> _pendingRequests = [];
  final Set<String> _updatingIds = <String>{};

  @override
  void initState() {
    super.initState();
    _loadPendingRequests();
  }

  Future<void> _loadPendingRequests() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    final result = await widget.absenceRequestRepository.getAllAbsenceRequests();
    if (!mounted) return;

    result.when(
      success: (requests) {
        final pending = requests
            .where((request) => request.status == AbsenceRequestStatus.pending)
            .toList()
          ..sort((a, b) => a.startDate.compareTo(b.startDate));
        setState(() {
          _pendingRequests = pending;
          _isLoading = false;
        });
      },
      failure: (error) {
        setState(() {
          _error = error.message;
          _isLoading = false;
        });
      },
    );
  }

  Future<void> _reviewRequest(
    AbsenceRequestEntity request,
    AbsenceRequestStatus newStatus,
  ) async {
    setState(() => _updatingIds.add(request.id));

    final result = await widget.absenceRequestRepository.updateAbsenceRequest(
      id: request.id,
      userId: request.userId,
      type: request.type,
      startDate: request.startDate,
      endDate: request.endDate,
      shiftId: request.shiftId,
      status: newStatus,
    );

    if (!mounted) return;

    result.when(
      success: (_) {
        final action = newStatus == AbsenceRequestStatus.approved
            ? 'approved'
            : 'rejected';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Request $action')),
        );
        _loadPendingRequests();
      },
      failure: (error) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to review request: ${error.message}')),
        );
      },
    );

    if (!mounted) return;
    setState(() => _updatingIds.remove(request.id));
  }

  String _formatDateRange(AbsenceRequestEntity request) {
    final formatter = DateFormat('dd/MM/yyyy');
    return '${formatter.format(request.startDate)} - ${formatter.format(request.endDate)}';
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: const Text('Absence approvals'),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(child: Text('Error: $_error'))
          : _pendingRequests.isEmpty
          ? RefreshIndicator(
              onRefresh: _loadPendingRequests,
              child: ListView(
                children: const [
                  SizedBox(height: 240),
                  Center(child: Text('No pending absence requests')),
                ],
              ),
            )
          : RefreshIndicator(
              onRefresh: _loadPendingRequests,
              child: ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: _pendingRequests.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final request = _pendingRequests[index];
                  final isUpdating = _updatingIds.contains(request.id);
                  return Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            request.userName?.trim().isNotEmpty == true
                                ? request.userName!
                                : request.userId,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 8),
                          Text('Type: ${request.type.displayName}'),
                          Text('Dates: ${_formatDateRange(request)}'),
                          Text('Duration: ${request.durationInDays} day(s)'),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              ElevatedButton.icon(
                                onPressed: isUpdating
                                    ? null
                                    : () => _reviewRequest(
                                          request,
                                          AbsenceRequestStatus.approved,
                                        ),
                                icon: const Icon(Icons.check),
                                label: const Text('Approve'),
                              ),
                              const SizedBox(width: 12),
                              OutlinedButton.icon(
                                onPressed: isUpdating
                                    ? null
                                    : () => _reviewRequest(
                                          request,
                                          AbsenceRequestStatus.rejected,
                                        ),
                                icon: const Icon(Icons.close),
                                label: const Text('Reject'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
    );
  }
}
