import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';

class CalendarPage extends StatefulWidget {
  const CalendarPage({super.key});

  @override
  State<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends State<CalendarPage> {
  late DateTime? _startDate;
  late DateTime? _endDate;
  late DateTime _focusedDate;

  @override
  void initState() {
    super.initState();
    _startDate = null;
    _endDate = null;
    _focusedDate = DateTime.now();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Calendar'),
        backgroundColor: Colors.blue.shade700,
        foregroundColor: Colors.white,
      ),
      body: Column(
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
          // Scrollable Selected Dates Section
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
}
