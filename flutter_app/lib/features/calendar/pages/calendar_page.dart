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

  /// Header with month navigation
  Widget _buildHeader() {
    final monthLabel = DateFormat.yMMMM().format(_focusedDate);
    return Row(
      children: [
        IconButton(
          icon: const Icon(Icons.chevron_left),
          onPressed: () => setState(() {
            _focusedDate = DateTime(_focusedDate.year, _focusedDate.month - 1, 1);
          }),
        ),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Calendar', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 2),
            Text(monthLabel, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey.shade700)),
          ]),
        ),
        IconButton(
          icon: const Icon(Icons.today),
          tooltip: 'Today',
          onPressed: () => setState(() {
            _focusedDate = DateTime.now();
          }),
        ),
        IconButton(
          icon: const Icon(Icons.chevron_right),
          onPressed: () => setState(() {
            _focusedDate = DateTime(_focusedDate.year, _focusedDate.month + 1, 1);
          }),
        ),
      ],
    );
  }

  /// Card that shows selected date(s)
  Widget _selectedInfoCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12.0),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.grey.shade100)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(
          _startDate == null && _endDate == null
              ? 'Select a date'
              : _startDate != null && _endDate == null
                  ? 'Selected: ${DateFormat('MMM d, yyyy').format(_startDate!)}'
                  : 'Range: ${DateFormat('MMM d').format(_startDate!)} - ${DateFormat('MMM d, yyyy').format(_endDate!)}',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        if (_startDate != null && _endDate != null)
          Text('Duration: ${_endDate!.difference(_startDate!).inDays + 1} days', style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 8),
        Row(children: [
          ElevatedButton(onPressed: () => setState(() { _startDate = null; _endDate = null; }), child: const Text('Clear')),
          const SizedBox(width: 8),
          OutlinedButton(onPressed: _loadShifts, child: const Text('Refresh')),
        ])
      ]),
    );
  }

  /// Panel that displays shifts based on selection or upcoming
  Widget _shiftsPanel() {
    List<ShiftEntity> list;
    if (_startDate != null && _endDate != null) {
      list = _getShiftsForRange(_startDate!, _endDate!);
    } else if (_startDate != null && _endDate == null) {
      list = _getShiftsForDate(_startDate!);
    } else {
      // upcoming: next 7 days
      final now = DateTime.now();
      final future = now.add(const Duration(days: 7));
      list = _getShiftsForRange(now, future);
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12.0),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.grey.shade100)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Shifts', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        _buildShiftsList(list),
      ]),
    );
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
          ? const Center(child: CircularProgressIndicator())
          : LayoutBuilder(builder: (context, constraints) {
              final isWide = constraints.maxWidth > 800;
              return Padding(
                padding: const EdgeInsets.all(12.0),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1200),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Top header with month and actions
                        Row(
                          children: [
                            Expanded(child: _buildHeader()),
                            ElevatedButton.icon(
                              onPressed: () {
                                // placeholder for add shift flow
                                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Add shift (not implemented)')));
                              },
                              icon: const Icon(Icons.add),
                              label: const Text('Add shift'),
                              style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),

                        // Main content: calendar + list
                        Expanded(
                          child: isWide
                              ? Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Calendar panel
                                    Expanded(
                                      flex: 5,
                                      child: Container(
                                        padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), boxShadow: [BoxShadow(color: Colors.grey.shade100, blurRadius: 8)]),
                                        child: Column(children: [
                                          Expanded(
                                            child: TableCalendar(
                                              firstDay: DateTime.utc(2020, 1, 1),
                                              lastDay: DateTime.utc(2030, 12, 31),
                                              focusedDay: _focusedDate,
                                              selectedDayPredicate: (day) {
                                                if (_startDate == null && _endDate == null) return false;
                                                if (_startDate != null && _endDate == null) return isSameDay(_startDate, day);
                                                return day.isAfter(_startDate!) && day.isBefore(_endDate!) || isSameDay(_startDate, day) || isSameDay(_endDate, day);
                                              },
                                              eventLoader: _getShiftsForDate,
                                              onDaySelected: (selectedDay, focusedDay) {
                                                setState(() {
                                                  if (_startDate == null && _endDate == null) {
                                                    _startDate = selectedDay;
                                                  } else if (_startDate != null && _endDate == null) {
                                                    if (selectedDay.isBefore(_startDate!)) {
                                                      _endDate = _startDate;
                                                      _startDate = selectedDay;
                                                    } else {
                                                      _endDate = selectedDay;
                                                    }
                                                  } else {
                                                    _startDate = selectedDay;
                                                    _endDate = null;
                                                  }
                                                  _focusedDate = focusedDay;
                                                });
                                              },
                                              onPageChanged: (focusedDay) => _focusedDate = focusedDay,
                                              calendarStyle: CalendarStyle(selectedDecoration: BoxDecoration(color: Colors.blue.shade700, shape: BoxShape.circle), todayDecoration: BoxDecoration(color: Colors.orange.shade300, shape: BoxShape.circle), markerDecoration: BoxDecoration(color: Colors.blue.shade400, shape: BoxShape.circle)),
                                              headerStyle: HeaderStyle(formatButtonVisible: false, titleCentered: true, titleTextFormatter: (date, locale) => DateFormat.yMMM(locale).format(date), leftChevronIcon: const Icon(Icons.chevron_left), rightChevronIcon: const Icon(Icons.chevron_right)),
                                            ),
                                          ),
                                        ]),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    // Right panel: selected dates & shifts
                                    Expanded(
                                      flex: 5,
                                      child: SingleChildScrollView(
                                        child: Column(children: [
                                          _selectedInfoCard(),
                                          const SizedBox(height: 12),
                                          _shiftsPanel(),
                                        ]),
                                      ),
                                    ),
                                  ],
                                )
                              : Column(
                                  children: [
                                    // compact calendar panel
                                    Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), boxShadow: [BoxShadow(color: Colors.grey.shade100, blurRadius: 8)]),
                                      child: TableCalendar(
                                        firstDay: DateTime.utc(2020, 1, 1),
                                        lastDay: DateTime.utc(2030, 12, 31),
                                        focusedDay: _focusedDate,
                                        selectedDayPredicate: (day) {
                                          if (_startDate == null && _endDate == null) return false;
                                          if (_startDate != null && _endDate == null) return isSameDay(_startDate, day);
                                          return day.isAfter(_startDate!) && day.isBefore(_endDate!) || isSameDay(_startDate, day) || isSameDay(_endDate, day);
                                        },
                                        eventLoader: _getShiftsForDate,
                                        onDaySelected: (selectedDay, focusedDay) {
                                          setState(() {
                                            if (_startDate == null && _endDate == null) {
                                              _startDate = selectedDay;
                                            } else if (_startDate != null && _endDate == null) {
                                              if (selectedDay.isBefore(_startDate!)) {
                                                _endDate = _startDate;
                                                _startDate = selectedDay;
                                              } else {
                                                _endDate = selectedDay;
                                              }
                                            } else {
                                              _startDate = selectedDay;
                                              _endDate = null;
                                            }
                                            _focusedDate = focusedDay;
                                          });
                                        },
                                        onPageChanged: (focusedDay) => _focusedDate = focusedDay,
                                        calendarStyle: CalendarStyle(selectedDecoration: BoxDecoration(color: Colors.blue.shade700, shape: BoxShape.circle), todayDecoration: BoxDecoration(color: Colors.orange.shade300, shape: BoxShape.circle), markerDecoration: BoxDecoration(color: Colors.blue.shade400, shape: BoxShape.circle)),
                                        headerStyle: HeaderStyle(formatButtonVisible: false, titleCentered: true, titleTextFormatter: (date, locale) => DateFormat.yMMM(locale).format(date)),
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    _selectedInfoCard(),
                                    const SizedBox(height: 12),
                                    _shiftsPanel(),
                                  ],
                                ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
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