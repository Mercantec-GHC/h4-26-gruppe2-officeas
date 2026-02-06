import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';
import '../../../domain/entities/shift_entity.dart';
import '../../../domain/repositories/shift_repository.dart';

class CalendarPage extends StatefulWidget {
  final ShiftRepository shiftRepository;

  const CalendarPage({
    super.key,
    required this.shiftRepository,
  });

  @override
  State<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends State<CalendarPage> {
  late DateTime? _startDate;
  late DateTime? _endDate;
  late DateTime _focusedDate;
  List<ShiftEntity> _shifts = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _startDate = null;
    _endDate = null;
    _focusedDate = DateTime.now();
    _loadShifts();
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
                content: Text('Fejl ved indlæsning af skifter: ${error.message}'),
                backgroundColor: Colors.red,
                duration: const Duration(seconds: 4),
              ),
            );
          },
        );
      });
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
      return shift.startTime.isAfter(start) &&
              shift.startTime.isBefore(end) ||
          shift.startTime.isAtSameMomentAs(start) ||
          shift.startTime.isAtSameMomentAs(end);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Calendar'),
        backgroundColor: Colors.blue.shade700,
        foregroundColor: Colors.white,
        actions: [
          // Refresh button
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _isLoading ? null : _loadShifts,
            tooltip: 'Refresh shifts',
          ),
        ],
      ),
      body: _isLoading && _shifts.isEmpty
          ? const Center(
              child: CircularProgressIndicator(),
            )
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
                            color: Colors.blue.shade50,
                            borderRadius: BorderRadius.circular(8.0),
                            border: Border.all(color: Colors.blue.shade200),
                          ),
                          child: TableCalendar(
                            firstDay: DateTime.utc(2020, 1, 1),
                            lastDay: DateTime.utc(2030, 12, 31),
                            focusedDay: _focusedDate,
                            selectedDayPredicate: (day) {
                              if (_startDate == null && _endDate == null) return false;
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
                                } else if (_startDate != null && _endDate == null) {
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
                              weekendTextStyle: const TextStyle(fontSize: 12, color: Colors.red),
                              selectedDecoration: BoxDecoration(
                                color: Colors.blue.shade700,
                                shape: BoxShape.circle,
                              ),
                              todayDecoration: BoxDecoration(
                                color: Colors.orange.shade300,
                                shape: BoxShape.circle,
                              ),
                              markerDecoration: BoxDecoration(
                                color: Colors.blue.shade400,
                                shape: BoxShape.circle,
                              ),
                              outsideTextStyle: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade400,
                              ),
                            ),
                            headerStyle: HeaderStyle(
                              formatButtonVisible: false,
                              titleCentered: true,
                              titleTextStyle: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Colors.blue.shade700,
                              ),
                              leftChevronIcon: const Icon(
                                Icons.arrow_left,
                                size: 20,
                                color: Colors.blue,
                              ),
                              rightChevronIcon: const Icon(
                                Icons.arrow_right,
                                size: 20,
                                color: Colors.blue,
                              ),
                            ),
                            daysOfWeekStyle: const DaysOfWeekStyle(
                              weekdayStyle: TextStyle(fontSize: 11),
                              weekendStyle: TextStyle(fontSize: 11, color: Colors.red),
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
                                color: Colors.green.shade50,
                                border: Border.all(color: Colors.green.shade300),
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
                                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                          fontWeight: FontWeight.bold,
                                        ),
                                  ),
                                  if (_startDate != null) ...[
                                    const SizedBox(height: 6.0),
                                    Row(
                                      children: [
                                        const Icon(Icons.calendar_today, size: 14, color: Colors.green),
                                        const SizedBox(width: 6.0),
                                        Expanded(
                                          child: Text(
                                            'Start: ${DateFormat('MMM d, yyyy').format(_startDate!)}',
                                            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                                  color: Colors.green.shade700,
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
                                        const Icon(Icons.calendar_today, size: 14, color: Colors.blue),
                                        const SizedBox(width: 6.0),
                                        Expanded(
                                          child: Text(
                                            'End: ${DateFormat('MMM d, yyyy').format(_endDate!)}',
                                            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                                  color: Colors.blue.shade700,
                                                ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 6.0),
                                    Text(
                                      'Duration: ${_endDate!.difference(_startDate!).inDays + 1} days',
                                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                            color: Colors.purple.shade700,
                                            fontWeight: FontWeight.bold,
                                          ),
                                    ),
                                  ],
                                  if (_startDate != null && _endDate != null) ...[
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
                                          padding: const EdgeInsets.symmetric(vertical: 6.0),
                                        ),
                                      ),
                                    ),
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
                                  color: Colors.purple.shade50,
                                  border: Border.all(color: Colors.purple.shade300),
                                  borderRadius: BorderRadius.circular(6.0),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Shifts in selected period:',
                                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                            fontWeight: FontWeight.bold,
                                            color: Colors.purple.shade700,
                                          ),
                                    ),
                                    const SizedBox(height: 8.0),
                                    _buildShiftsList(
                                      _getShiftsForRange(_startDate!, _endDate!),
                                    ),
                                  ],
                                ),
                              ),
                            ] else if (_startDate != null && _endDate == null) ...[
                              Container(
                                padding: const EdgeInsets.all(8.0),
                                decoration: BoxDecoration(
                                  color: Colors.amber.shade50,
                                  border: Border.all(color: Colors.amber.shade300),
                                  borderRadius: BorderRadius.circular(6.0),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Shifts on ${DateFormat('MMM d, yyyy').format(_startDate!)}:',
                                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                            fontWeight: FontWeight.bold,
                                            color: Colors.amber.shade700,
                                          ),
                                    ),
                                    const SizedBox(height: 8.0),
                                    _buildShiftsList(_getShiftsForDate(_startDate!)),
                                  ],
                                ),
                              ),
                            ],
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

  /// Build shifts list widget
  Widget _buildShiftsList(List<ShiftEntity> shifts) {
    if (shifts.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Text(
            'No shifts scheduled',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.grey,
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
      color: Colors.white,
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
                        style: Theme.of(context).textTheme.labelMedium?.copyWith(
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
                              color: Colors.grey.shade700,
                            ),
                      ),
                    ],
                  ),
                ),
                if (isActive)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6.0, vertical: 2.0),
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
                const Icon(Icons.access_time, size: 14, color: Colors.grey),
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
  }}