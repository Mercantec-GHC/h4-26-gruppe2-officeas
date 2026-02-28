import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import '../auth/bloc/auth_bloc.dart';
import '../../../core/services/departments_service.dart';
import '../../../core/services/feedback_service.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../../../core/widgets/department_dropdown.dart';
import '../../../data/models/feedback_model.dart';
import '../../../data/models/shift_model.dart';

class FeedbackPage extends StatefulWidget {
  const FeedbackPage({super.key});

  @override
  State<FeedbackPage> createState() => _FeedbackPageState();
}

class _FeedbackPageState extends State<FeedbackPage> {
  final _messageController = TextEditingController();
  int _rating = 5;
  final _service = FeedbackService();
  bool _loading = false;
  String? _selectedDepartmentId;
  List<ShiftModel> _shifts = [];
  String? _selectedShiftId;
  bool _shiftsLoading = false;
  String? _shiftsError;
  final _departmentsService = DepartmentsService();

  Future<void> _submitFeedback() async {
    setState(() => _loading = true);
    try {
      final jwt = context.read<AuthBloc>().currentToken;
      if (jwt == null) {
        throw Exception('Please sign in to submit feedback');
      }
      final message = _messageController.text.trim();
      if (_selectedShiftId == null || _selectedShiftId!.isEmpty) {
        throw Exception('Please select a shift');
      }
      final feedback = FeedbackModel(
        message: message.isEmpty ? null : message,
        rating: _rating,
        departmentId: _selectedDepartmentId,
        shiftId: _selectedShiftId,
      );
      await _service.createFeedback(feedback: feedback, jwt: jwt);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Feedback submitted successfully')),
        );
        _messageController.clear();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to submit feedback: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadShifts() async {
    final deptId = _selectedDepartmentId;
    final jwt = context.read<AuthBloc>().currentToken;

    if (deptId == null || deptId.isEmpty || jwt == null) {
      setState(() {
        _shifts = [];
        _selectedShiftId = null;
        _shiftsError = null;
      });

      return;
    }

    setState(() {
      _shiftsLoading = true;
      _shiftsError = null;
      _selectedShiftId = null;
    });

    try {
      final list = await _departmentsService.getShiftsForDepartment(
        deptId,
        jwt,
      );

      // One entry per unique (start, end) slot — multiple users can have the same slot
      final seen = <String>{};
      final uniqueSlots = <ShiftModel>[];

      final now = DateTime.now();

      for (final s in list) {
        // Only include shifts that have started (current or past), not future
        if (s.startTime.isAfter(now)) continue;

        final key =
            '${s.startTime.millisecondsSinceEpoch}-${s.endTime.millisecondsSinceEpoch}';

        if (seen.contains(key)) continue;

        seen.add(key);
        uniqueSlots.add(s);
      }

      if (mounted && _selectedDepartmentId == deptId) {
        setState(() {
          _shifts = uniqueSlots;
          _selectedShiftId = uniqueSlots.isNotEmpty
              ? uniqueSlots.first.id
              : null;
        });
      }
    } catch (e) {
      if (mounted && _selectedDepartmentId == deptId) {
        setState(() => _shiftsError = e.toString());
      }
    } finally {
      if (mounted) setState(() => _shiftsLoading = false);
    }
  }

  static String _ordinal(int n) {
    if (n >= 11 && n <= 13) return 'th';

    switch (n % 10) {
      case 1:
        return 'st';
      case 2:
        return 'nd';
      case 3:
        return 'rd';
      default:
        return 'th';
    }
  }

  String _formatShiftSlot(DateTime start, DateTime end) {
    final month = DateFormat('MMM').format(start);
    final day = start.day;
    final startTime = DateFormat('HH:mm').format(start);
    final endTime = DateFormat('HH:mm').format(end);
    return '$month ${day}${_ordinal(day)} $startTime - $endTime';
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: const Text('Feedback'),
      showBackButtonWhenPossible: true,
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DepartmentDropdown(
              label: 'Department',
              value: _selectedDepartmentId,
              onChanged: (v) {
                setState(() => _selectedDepartmentId = v);
                _loadShifts();
              },
            ),
            const SizedBox(height: 16),
            if (_selectedDepartmentId != null &&
                _selectedDepartmentId!.isNotEmpty) ...[
              const Text('Shift (when did this happen?)'),
              const SizedBox(height: 4),
              if (_shiftsLoading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8.0),
                  child: LinearProgressIndicator(),
                )
              else if (_shiftsError != null)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: Text(
                    _shiftsError!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                )
              else if (_shifts.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: Text(
                    'No shifts for this department. Add shifts (e.g. via Calendar or Shifts) first.',
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                  ),
                )
              else
                DropdownButtonFormField<String>(
                  value: _selectedShiftId,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                  ),
                  items: _shifts
                      .map(
                        (s) => DropdownMenuItem(
                          value: s.id,
                          child: Text(_formatShiftSlot(s.startTime, s.endTime)),
                        ),
                      )
                      .toList(),
                  onChanged: (v) => setState(() => _selectedShiftId = v),
                ),
              const SizedBox(height: 16),
            ],
            TextField(
              controller: _messageController,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'Your feedback (optional)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                const Text('Rating (1–10):'),
                const SizedBox(width: 8),
                DropdownButton<int>(
                  value: _rating,
                  items: List.generate(10, (i) => i + 1)
                      .map((r) => DropdownMenuItem(value: r, child: Text('$r')))
                      .toList(),
                  onChanged: (v) =>
                      v != null ? setState(() => _rating = v) : null,
                ),
              ],
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loading ? null : _submitFeedback,
              child: _loading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Submit'),
            ),
          ],
        ),
      ),
    );
  }
}
