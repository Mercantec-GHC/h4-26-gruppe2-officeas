import 'package:flutter/material.dart';

class CalenderPage extends StatefulWidget {
  const CalenderPage({super.key});

  @override
  State<CalenderPage> createState() => _CalenderPageState();
}

class _CalenderPageState extends State<CalenderPage> {
  DateTime _visibleMonth = DateTime.now();
  DateTime _selectedDay = DateTime.now();

  // Sample shift data: date (yyyy-mm-dd) -> list of shifts
  final Map<String, List<String>> _shifts = {
    DateTime.now().toIso8601String().substring(0, 10): ['09:00 - 17:00 • Reception', '18:00 - 22:00 • Evening shift'],
  };

  void _prevMonth() {
    setState(() {
      _visibleMonth = DateTime(_visibleMonth.year, _visibleMonth.month - 1, 1);
    });
  }

  void _nextMonth() {
    setState(() {
      _visibleMonth = DateTime(_visibleMonth.year, _visibleMonth.month + 1, 1);
    });
  }

  List<DateTime> _daysInMonth(DateTime month) {
    final first = DateTime(month.year, month.month, 1);
    final days = <DateTime>[];
    final weekdayOffset = first.weekday % 7; // make Sunday = 0
    for (var i = 0; i < weekdayOffset; i++) {
      days.add(first.subtract(Duration(days: weekdayOffset - i)));
    }
    var last = DateTime(month.year, month.month + 1, 0);
    for (var d = 1; d <= last.day; d++) {
      days.add(DateTime(month.year, month.month, d));
    }
    // Fill up to complete weeks (6 rows max)
    while (days.length % 7 != 0) {
      final next = days.last.add(const Duration(days: 1));
      days.add(next);
    }
    return days;
  }

  @override
  Widget build(BuildContext context) {
    final days = _daysInMonth(_visibleMonth);
    final monthLabel = '${_visibleMonth.year} - ${_visibleMonth.month.toString().padLeft(2, '0')}';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Vagtplan'),
        backgroundColor: const Color(0xFF0A66FF),
      ),
      body: Column(
        children: [
          // Month selector
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 12),
            child: Row(
              children: [
                IconButton(
                  onPressed: _prevMonth,
                  icon: const Icon(Icons.chevron_left),
                ),
                Expanded(
                  child: Text(
                    monthLabel,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
                IconButton(
                  onPressed: _nextMonth,
                  icon: const Icon(Icons.chevron_right),
                ),
              ],
            ),
          ),

          // Weekday labels
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: const [
                _WeekdayLabel('S'),
                _WeekdayLabel('M'),
                _WeekdayLabel('T'),
                _WeekdayLabel('W'),
                _WeekdayLabel('T'),
                _WeekdayLabel('F'),
                _WeekdayLabel('S'),
              ],
            ),
          ),

          const SizedBox(height: 8),

          // Calendar grid (constrained height to avoid overflow)
          LayoutBuilder(
            builder: (context, constraints) {
              final calHeight = constraints.maxHeight * 0.45; // ~45% of available height
              return SizedBox(
                height: calHeight.clamp(200.0, 520.0),
                child: GridView.builder(
                  physics: const NeverScrollableScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 7,
                    mainAxisSpacing: 6,
                    crossAxisSpacing: 6,
                  ),
                  itemCount: days.length,
                  itemBuilder: (context, index) {
                    final day = days[index];
                    final isToday = DateTime.now().year == day.year && DateTime.now().month == day.month && DateTime.now().day == day.day;
                    final isSelected = _selectedDay.year == day.year && _selectedDay.month == day.month && _selectedDay.day == day.day;
                    final inMonth = day.month == _visibleMonth.month;
                    final key = day.toIso8601String().substring(0, 10);
                    final hasShifts = _shifts.containsKey(key);

                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          _selectedDay = day;
                        });
                      },
                      child: Container(
                        margin: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          color: isSelected ? const Color(0xFF0A66FF) : Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Stack(
                          children: [
                            Align(
                              alignment: Alignment.topCenter,
                              child: Padding(
                                padding: const EdgeInsets.only(top: 6),
                                child: Text(
                                  '${day.day}',
                                  style: TextStyle(
                                    color: inMonth ? (isSelected ? Colors.white : Colors.black87) : Colors.grey.shade400,
                                    fontWeight: isToday ? FontWeight.w700 : FontWeight.normal,
                                  ),
                                ),
                              ),
                            ),
                            if (hasShifts)
                              Align(
                                alignment: Alignment.bottomCenter,
                                child: Padding(
                                  padding: const EdgeInsets.only(bottom: 8.0),
                                  child: Container(
                                    width: 8,
                                    height: 8,
                                    decoration: BoxDecoration(color: isSelected ? Colors.white : Colors.redAccent, shape: BoxShape.circle),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              );
            },
          ),

          const Divider(),

          // Shift list for selected day
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Vagter for ${_selectedDay.toIso8601String().substring(0, 10)}',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: _buildShiftsList(_selectedDay),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildShiftsList(DateTime date) {
    final key = date.toIso8601String().substring(0, 10);
    final list = _shifts[key] ?? [];
    if (list.isEmpty) {
      return Center(child: Text('Ingen vagter i dag', style: TextStyle(color: Colors.grey.shade600)));
    }
    return ListView.separated(
      itemCount: list.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final shift = list[index];
        return Material(
          elevation: 1,
          borderRadius: BorderRadius.circular(10),
          child: ListTile(
            leading: const Icon(Icons.access_time_rounded),
            title: Text(shift),
            trailing: IconButton(onPressed: () {}, icon: const Icon(Icons.more_vert)),
          ),
        );
      },
    );
  }
}

class _WeekdayLabel extends StatelessWidget {
  final String label;
  const _WeekdayLabel(this.label, {super.key});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Center(child: Text(label, style: TextStyle(color: Colors.grey.shade600, fontWeight: FontWeight.w600))),
    );
  }
}
