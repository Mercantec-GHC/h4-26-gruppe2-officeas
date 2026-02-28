import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';
import '../../../domain/entities/shift_entity.dart';
import '../../../domain/entities/absence_request_entity.dart';
import '../../../domain/repositories/shift_repository.dart';
import '../../../domain/repositories/absence_request_repository.dart';
import '../../../features/auth/bloc/auth_bloc.dart';
import '../../../core/utils/department_utils.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../dialogs/create_absence_request_dialog.dart';

class CalendarPage extends StatefulWidget {
  final ShiftRepository shiftRepository;
  final AbsenceRequestRepository absenceRequestRepository;

  const CalendarPage({
    super.key,
    required this.shiftRepository,
    required this.absenceRequestRepository,
  });

  @override
  State<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends State<CalendarPage> {
  /// Cancel absence request
  Future<void> _onCancelAbsenceRequest(AbsenceRequestEntity request) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel Absence Request'),
        content: const Text(
          'Are you sure you want to cancel this absence request?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('No'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Yes'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    final result = await widget.absenceRequestRepository.cancelAbsenceRequest(
      request.id,
    );
    result.when(
      success: (_) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Absence request cancelled'),
            backgroundColor: Colors.grey,
            duration: Duration(seconds: 3),
          ),
        );
        _loadAbsenceRequests();
      },
      failure: (error) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${error.message}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      },
    );
  }

  late DateTime? _startDate;
  late DateTime? _endDate;
  late DateTime _focusedDate;
  List<ShiftEntity> _shifts = [];
  List<AbsenceRequestEntity> _absenceRequests = [];
  bool _isLoading = false;
  bool _isGenerating = false;

  @override
  void initState() {
    super.initState();
    _startDate = null;
    _endDate = null;
    _focusedDate = DateTime.now();
    _loadShifts();
    _loadAbsenceRequests();
  }

  /// Load shifts from database
  Future<void> _loadShifts() async {
    setState(() {
      _isLoading = true;
    });

    final result = await widget.shiftRepository.getAllShifts();

    if (mounted) {
      setState(() {
        _isLoading = false;
        result.when(
          success: (shifts) {
            _shifts = shifts;
          },
          failure: (error) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Fejl ved indlæsning af skifter: ${error.message}',
                ),
                backgroundColor: Colors.red,
                duration: const Duration(seconds: 4),
              ),
            );
          },
        );
      });
    }
  }

  /// Load absence requests from database
  Future<void> _loadAbsenceRequests() async {
    final result = await widget.absenceRequestRepository
        .getAllAbsenceRequests();

    if (mounted) {
      result.when(
        success: (absenceRequests) {
          setState(() {
            _absenceRequests = absenceRequests;
          });
        },
        failure: (error) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Fejl ved indlæsning af absence requests: ${error.message}',
              ),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 4),
            ),
          );
        },
      );
    }
  }

  /// Get shifts for a specific date
  List<ShiftEntity> _getShiftsForDate(DateTime date) {
    return _shifts.where((shift) {
      return shift.startTime.year == date.year &&
          shift.startTime.month == date.month &&
          shift.startTime.day == date.day;
    }).toList();
  }

  /// Get shifts for a date range
  List<ShiftEntity> _getShiftsForRange(DateTime start, DateTime end) {
    return _shifts.where((shift) {
      return shift.startTime.isAfter(start) && shift.startTime.isBefore(end) ||
          shift.startTime.isAtSameMomentAs(start) ||
          shift.startTime.isAtSameMomentAs(end);
    }).toList();
  }

  /// Generate shifts for the selected date range (Ledelse only).
  Future<void> _generateShifts() async {
    if (_startDate == null || _endDate == null) return;
    setState(() => _isGenerating = true);

    final result = await widget.shiftRepository.generateShifts(
      startDate: _startDate!,
      endDate: _endDate!,
    );

    if (!mounted) return;

    setState(() => _isGenerating = false);

    result.when(
      success: (res) {
        final count = res.created.length;

        final msg = count == 0
            ? 'No new shifts created.'
            : 'Created $count shift${count == 1 ? '' : 's'}.';

        final withWarnings = res.warnings.isNotEmpty
            ? ' ${res.warnings.length} warning(s): ${res.warnings.take(2).join('; ')}${res.warnings.length > 2 ? '...' : ''}'
            : '';

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(msg + withWarnings),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 4),
          ),
        );
        _loadShifts();
      },
      failure: (error) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to generate shifts: ${error.message}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      },
    );
  }

  /// Show absence request dialog
  void _showAbsenceRequestDialog() {
    final userId = context.read<AuthBloc>().currentUser?.id ?? '';

    if (userId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('User not found. Please log in again.'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 3),
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) => CreateAbsenceRequestDialog(
        absenceRequestRepository: widget.absenceRequestRepository,
        userId: userId,
        selectedStartDate: _startDate,
        selectedEndDate: _endDate,
        onAbsenceRequestCreated: (absenceRequest) {
          setState(() {
            _absenceRequests.add(absenceRequest);
            _startDate = null;
            _endDate = null;
          });
          _loadAbsenceRequests(); // Reload to get latest data
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final mutedText = Theme.of(
      context,
    ).textTheme.bodyMedium?.color?.withValues(alpha: 0.72);
    return AppScaffold(
      title: const Text('Calendar'),
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh),
          onPressed: _isLoading
              ? null
              : () {
                  _loadShifts();
                  _loadAbsenceRequests();
                },
          tooltip: 'Refresh shifts and absence requests',
        ),
      ],
      body: _isLoading && _shifts.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Fixed Calendar at top
                Flexible(
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 500),
                        child: Container(
                          padding: const EdgeInsets.all(8.0),
                          decoration: BoxDecoration(
                            color:
                                Theme.of(context).brightness == Brightness.dark
                                ? Theme.of(
                                    context,
                                  ).colorScheme.surfaceContainerHighest
                                : Colors.blue.shade50,
                            borderRadius: BorderRadius.circular(8.0),
                            border: Border.all(
                              color:
                                  Theme.of(context).brightness ==
                                      Brightness.dark
                                  ? Theme.of(context).colorScheme.outlineVariant
                                  : Colors.blue.shade200,
                            ),
                          ),
                          child: TableCalendar(
                            firstDay: DateTime.utc(2020, 1, 1),
                            lastDay: DateTime.utc(2030, 12, 31),
                            focusedDay: _focusedDate,
                            selectedDayPredicate: (day) {
                              if (_startDate == null && _endDate == null)
                                return false;
                              if (_startDate != null && _endDate == null) {
                                return isSameDay(_startDate, day);
                              }
                              // If both dates are set, highlight range
                              return day.isAfter(_startDate!) &&
                                      day.isBefore(_endDate!) ||
                                  isSameDay(_startDate, day) ||
                                  isSameDay(_endDate, day);
                            },
                            eventLoader: _getShiftsForDate,
                            onDaySelected: (selectedDay, focusedDay) {
                              setState(() {
                                if (_startDate == null && _endDate == null) {
                                  // First selection - set start date
                                  _startDate = selectedDay;
                                } else if (_startDate != null &&
                                    _endDate == null) {
                                  // Second selection - set end date
                                  if (selectedDay.isBefore(_startDate!)) {
                                    // If selected date is before start, swap them
                                    _endDate = _startDate;
                                    _startDate = selectedDay;
                                  } else {
                                    _endDate = selectedDay;
                                  }
                                } else {
                                  // Both dates set - reset and start over
                                  _startDate = selectedDay;
                                  _endDate = null;
                                }
                                _focusedDate = focusedDay;
                              });
                            },
                            onPageChanged: (focusedDay) {
                              _focusedDate = focusedDay;
                            },
                            calendarStyle: CalendarStyle(
                              defaultTextStyle: const TextStyle(fontSize: 12),
                              weekendTextStyle: const TextStyle(
                                fontSize: 12,
                                color: Colors.red,
                              ),
                              selectedDecoration: BoxDecoration(
                                color: isDark
                                    ? scheme.primary
                                    : Colors.blue.shade700,
                                shape: BoxShape.circle,
                              ),
                              todayDecoration: BoxDecoration(
                                color: isDark
                                    ? scheme.tertiary
                                    : Colors.orange.shade300,
                                shape: BoxShape.circle,
                              ),
                              markerDecoration: BoxDecoration(
                                color: isDark
                                    ? scheme.primary.withValues(alpha: 0.8)
                                    : Colors.blue.shade400,
                                shape: BoxShape.circle,
                              ),
                              outsideTextStyle: TextStyle(
                                fontSize: 12,
                                color: mutedText,
                              ),
                            ),
                            headerStyle: HeaderStyle(
                              formatButtonVisible: false,
                              titleCentered: true,
                              titleTextStyle: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: isDark
                                    ? scheme.primary
                                    : Colors.blue.shade700,
                              ),
                              leftChevronIcon: Icon(
                                Icons.arrow_left,
                                size: 20,
                                color: isDark ? scheme.primary : Colors.blue,
                              ),
                              rightChevronIcon: Icon(
                                Icons.arrow_right,
                                size: 20,
                                color: isDark ? scheme.primary : Colors.blue,
                              ),
                            ),
                            daysOfWeekStyle: const DaysOfWeekStyle(
                              weekdayStyle: TextStyle(fontSize: 11),
                              weekendStyle: TextStyle(
                                fontSize: 11,
                                color: Colors.red,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                // Scrollable Selected Dates and Shifts Section
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(8.0),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 500),
                        child: Column(
                          children: [
                            const SizedBox(height: 4.0),
                            // Selected Date Range Info
                            Container(
                              padding: const EdgeInsets.all(8.0),
                              decoration: BoxDecoration(
                                color: isDark
                                    ? scheme.surfaceContainerHighest
                                    : Colors.green.shade50,
                                border: Border.all(
                                  color: isDark
                                      ? scheme.outlineVariant
                                      : Colors.green.shade300,
                                ),
                                borderRadius: BorderRadius.circular(6.0),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _startDate == null && _endDate == null
                                        ? 'Select a date range'
                                        : _startDate != null && _endDate == null
                                        ? 'Start date selected, select end date'
                                        : 'Date Range Selected:',
                                    style: Theme.of(context)
                                        .textTheme
                                        .labelSmall
                                        ?.copyWith(fontWeight: FontWeight.bold),
                                  ),
                                  if (_startDate != null) ...[
                                    const SizedBox(height: 6.0),
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.calendar_today,
                                          size: 14,
                                          color: isDark
                                              ? scheme.primary
                                              : Colors.green,
                                        ),
                                        const SizedBox(width: 6.0),
                                        Expanded(
                                          child: Text(
                                            'Start: ${DateFormat('MMM d, yyyy').format(_startDate!)}',
                                            style: Theme.of(context)
                                                .textTheme
                                                .labelSmall
                                                ?.copyWith(
                                                  color: isDark
                                                      ? scheme.primary
                                                      : Colors.green.shade700,
                                                ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                  if (_endDate != null) ...[
                                    const SizedBox(height: 4.0),
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.calendar_today,
                                          size: 14,
                                          color: isDark
                                              ? scheme.primary
                                              : Colors.blue,
                                        ),
                                        const SizedBox(width: 6.0),
                                        Expanded(
                                          child: Text(
                                            'End: ${DateFormat('MMM d, yyyy').format(_endDate!)}',
                                            style: Theme.of(context)
                                                .textTheme
                                                .labelSmall
                                                ?.copyWith(
                                                  color: isDark
                                                      ? scheme.primary
                                                      : Colors.blue.shade700,
                                                ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 6.0),
                                    Text(
                                      'Duration: ${_endDate!.difference(_startDate!).inDays + 1} days',
                                      style: Theme.of(context)
                                          .textTheme
                                          .labelSmall
                                          ?.copyWith(
                                            color: isDark
                                                ? scheme.primary
                                                : Colors.purple.shade700,
                                            fontWeight: FontWeight.bold,
                                          ),
                                    ),
                                  ],
                                  if (_startDate != null &&
                                      _endDate != null) ...[
                                    const SizedBox(height: 8.0),
                                    SizedBox(
                                      width: double.infinity,
                                      child: ElevatedButton.icon(
                                        onPressed: () {
                                          setState(() {
                                            _startDate = null;
                                            _endDate = null;
                                          });
                                        },
                                        icon: const Icon(Icons.clear, size: 16),
                                        label: const Text('Clear Range'),
                                        style: ElevatedButton.styleFrom(
                                          padding: const EdgeInsets.symmetric(
                                            vertical: 6.0,
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 6.0),
                                    SizedBox(
                                      width: double.infinity,
                                      child: ElevatedButton.icon(
                                        onPressed: _showAbsenceRequestDialog,
                                        icon: const Icon(
                                          Icons.event_busy,
                                          size: 16,
                                        ),
                                        label: const Text('Request Absence'),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor:
                                              Colors.orange.shade600,
                                          foregroundColor: isDark
                                              ? scheme.onTertiary
                                              : Colors.white,
                                          padding: const EdgeInsets.symmetric(
                                            vertical: 6.0,
                                          ),
                                        ),
                                      ),
                                    ),
                                    if (isLedelseDepartment(
                                      context.read<AuthBloc>().currentUser,
                                    )) ...[
                                      const SizedBox(height: 6.0),
                                      SizedBox(
                                        width: double.infinity,
                                        child: ElevatedButton.icon(
                                          onPressed: _isGenerating
                                              ? null
                                              : _generateShifts,
                                          icon: _isGenerating
                                              ? const SizedBox(
                                                  width: 16,
                                                  height: 16,
                                                  child:
                                                      CircularProgressIndicator(
                                                        strokeWidth: 2,
                                                      ),
                                                )
                                              : const Icon(
                                                  Icons.add_circle_outline,
                                                  size: 16,
                                                ),
                                          label: Text(
                                            _isGenerating
                                                ? 'Creating shifts…'
                                                : 'Create shifts',
                                          ),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: scheme.primary,
                                            foregroundColor: isDark
                                                ? scheme.onPrimary
                                                : Colors.white,
                                            padding: const EdgeInsets.symmetric(
                                              vertical: 6.0,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ],
                              ),
                            ),
                            // Display shifts for selected date range
                            const SizedBox(height: 12.0),
                            if (_startDate != null && _endDate != null) ...[
                              Container(
                                padding: const EdgeInsets.all(8.0),
                                decoration: BoxDecoration(
                                  color: isDark
                                      ? scheme.surfaceContainerHighest
                                      : Colors.purple.shade50,
                                  border: Border.all(
                                    color: isDark
                                        ? scheme.outlineVariant
                                        : Colors.purple.shade300,
                                  ),
                                  borderRadius: BorderRadius.circular(6.0),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Shifts in selected period:',
                                      style: Theme.of(context)
                                          .textTheme
                                          .labelSmall
                                          ?.copyWith(
                                            fontWeight: FontWeight.bold,
                                            color: isDark
                                                ? scheme.primary
                                                : Colors.purple.shade700,
                                          ),
                                    ),
                                    const SizedBox(height: 8.0),
                                    _buildShiftsList(
                                      _getShiftsForRange(
                                        _startDate!,
                                        _endDate!,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ] else if (_startDate != null &&
                                _endDate == null) ...[
                              Container(
                                padding: const EdgeInsets.all(8.0),
                                decoration: BoxDecoration(
                                  color: isDark
                                      ? scheme.surfaceContainerHighest
                                      : Colors.amber.shade50,
                                  border: Border.all(
                                    color: isDark
                                        ? scheme.outlineVariant
                                        : Colors.amber.shade300,
                                  ),
                                  borderRadius: BorderRadius.circular(6.0),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Shifts on ${DateFormat('MMM d, yyyy').format(_startDate!)}:',
                                      style: Theme.of(context)
                                          .textTheme
                                          .labelSmall
                                          ?.copyWith(
                                            fontWeight: FontWeight.bold,
                                            color: isDark
                                                ? scheme.primary
                                                : Colors.amber.shade700,
                                          ),
                                    ),
                                    const SizedBox(height: 8.0),
                                    _buildShiftsList(
                                      _getShiftsForDate(_startDate!),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                            // Display your absence requests
                            const SizedBox(height: 12.0),
                            Container(
                              padding: const EdgeInsets.all(8.0),
                              decoration: BoxDecoration(
                                color: isDark
                                    ? scheme.surfaceContainerHighest
                                    : Colors.red.shade50,
                                border: Border.all(
                                  color: isDark
                                      ? scheme.outlineVariant
                                      : Colors.red.shade300,
                                ),
                                borderRadius: BorderRadius.circular(6.0),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Your Absence Requests:',
                                    style: Theme.of(context)
                                        .textTheme
                                        .labelSmall
                                        ?.copyWith(
                                          fontWeight: FontWeight.bold,
                                          color: isDark
                                              ? scheme.primary
                                              : Colors.red.shade700,
                                        ),
                                  ),
                                  const SizedBox(height: 8.0),
                                  _buildAbsenceRequestsList(),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  /// Build absence requests list widget
  Widget _buildAbsenceRequestsList() {
    if (_absenceRequests.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Text(
            'No absence requests',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(
                context,
              ).textTheme.bodyMedium?.color?.withValues(alpha: 0.72),
            ),
          ),
        ),
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _absenceRequests.length,
      separatorBuilder: (context, index) => const SizedBox(height: 6.0),
      itemBuilder: (context, index) {
        final request = _absenceRequests[index];
        return _buildAbsenceRequestCard(request);
      },
    );
  }

  /// Build a single absence request card
  Widget _buildAbsenceRequestCard(AbsenceRequestEntity request) {
    final statusColor = switch (request.status) {
      AbsenceRequestStatus.pending => Colors.orange,
      AbsenceRequestStatus.approved => Colors.green,
      AbsenceRequestStatus.rejected => Colors.red,
      AbsenceRequestStatus.cancelled => Colors.grey,
    };

    return Card(
      elevation: 2.0,
      color: Theme.of(context).brightness == Brightness.dark
          ? Theme.of(context).colorScheme.surfaceContainerHighest
          : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(4.0),
        side: BorderSide(color: statusColor, width: 2.0),
      ),
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with type and status badge
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        request.type.displayName,
                        style: Theme.of(context).textTheme.labelMedium
                            ?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: statusColor,
                            ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2.0),
                      Text(
                        'Requested: ${DateFormat('MMM d, yyyy').format(request.createdAt)}',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: Theme.of(context).textTheme.bodyMedium?.color
                              ?.withValues(alpha: 0.72),
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6.0,
                    vertical: 2.0,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withAlpha((0.2 * 255).round()),
                    border: Border.all(color: statusColor),
                    borderRadius: BorderRadius.circular(3.0),
                  ),
                  child: Text(
                    request.status.displayName,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: statusColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                if (request.isPending)
                  TextButton(
                    onPressed: () => _onCancelAbsenceRequest(request),
                    child: const Text(
                      'Cancel',
                      style: TextStyle(color: Colors.red),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 6.0),
            // Date range
            Row(
              children: [
                Icon(
                  Icons.calendar_today,
                  size: 14,
                  color: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.color?.withValues(alpha: 0.72),
                ),
                const SizedBox(width: 4.0),
                Expanded(
                  child: Text(
                    '${DateFormat('MMM d').format(request.startDate)} - ${DateFormat('MMM d, yyyy').format(request.endDate)} (${request.durationInDays} days)',
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Build shifts list widget
  Widget _buildShiftsList(List<ShiftEntity> shifts) {
    if (shifts.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Text(
            'No shifts scheduled',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(
                context,
              ).textTheme.bodyMedium?.color?.withValues(alpha: 0.72),
            ),
          ),
        ),
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: shifts.length,
      separatorBuilder: (context, index) => const SizedBox(height: 6.0),
      itemBuilder: (context, index) {
        final shift = shifts[index];
        return _buildShiftCard(shift);
      },
    );
  }

  /// Build a single shift card
  Widget _buildShiftCard(ShiftEntity shift) {
    final isActive = shift.isActive;
    const backgroundColor = Colors.teal;
    final borderColor = isActive ? Colors.green : Colors.grey;

    return Card(
      elevation: 2.0,
      color: Theme.of(context).brightness == Brightness.dark
          ? Theme.of(context).colorScheme.surfaceContainerHighest
          : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(4.0),
        side: BorderSide(color: borderColor, width: 2.0),
      ),
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with time and status badge
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        shift.userName ?? 'Unknown User',
                        style: Theme.of(context).textTheme.labelMedium
                            ?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: backgroundColor,
                            ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2.0),
                      Text(
                        shift.formattedStartTime,
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: Theme.of(context).textTheme.bodyMedium?.color
                              ?.withValues(alpha: 0.72),
                        ),
                      ),
                    ],
                  ),
                ),
                if (isActive)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6.0,
                      vertical: 2.0,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.green.shade100,
                      border: Border.all(color: Colors.green),
                      borderRadius: BorderRadius.circular(3.0),
                    ),
                    child: Text(
                      'Active',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: Colors.green.shade700,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 6.0),
            // Time range
            Row(
              children: [
                Icon(
                  Icons.access_time,
                  size: 14,
                  color: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.color?.withValues(alpha: 0.72),
                ),
                const SizedBox(width: 4.0),
                Expanded(
                  child: Text(
                    '${DateFormat('HH:mm').format(shift.startTime)} - ${DateFormat('HH:mm').format(shift.endTime)} (${shift.durationString})',
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
