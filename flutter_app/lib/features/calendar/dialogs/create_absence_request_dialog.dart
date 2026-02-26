import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../domain/entities/absence_request_entity.dart';
import '../../../domain/repositories/absence_request_repository.dart';

class CreateAbsenceRequestDialog extends StatefulWidget {
  final AbsenceRequestRepository absenceRequestRepository;
  final String userId;
  final DateTime? selectedStartDate;
  final DateTime? selectedEndDate;
  final Function(AbsenceRequestEntity) onAbsenceRequestCreated;

  const CreateAbsenceRequestDialog({
    super.key,
    required this.absenceRequestRepository,
    required this.userId,
    this.selectedStartDate,
    this.selectedEndDate,
    required this.onAbsenceRequestCreated,
  });

  @override
  State<CreateAbsenceRequestDialog> createState() =>
      _CreateAbsenceRequestDialogState();
}

class _CreateAbsenceRequestDialogState
    extends State<CreateAbsenceRequestDialog> {
  late DateTime _startDate;
  late DateTime _endDate;
  late AbsenceType _absenceType;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _startDate = widget.selectedStartDate ?? DateTime.now();
    _endDate = widget.selectedEndDate ?? DateTime.now();
    _absenceType = AbsenceType.vacation;
  }

  /// Select start date
  Future<void> _selectStartDate() async {
    final selectedDate = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );

    if (selectedDate != null) {
      setState(() {
        _startDate = selectedDate;
        // Ensure end date is not before start date
        if (_endDate.isBefore(_startDate)) {
          _endDate = _startDate;
        }
      });
    }
  }

  /// Select end date
  Future<void> _selectEndDate() async {
    final selectedDate = await showDatePicker(
      context: context,
      initialDate: _endDate,
      firstDate: _startDate,
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );

    if (selectedDate != null) {
      setState(() {
        _endDate = selectedDate;
      });
    }
  }

  /// Create absence request
  Future<void> _createAbsenceRequest() async {
    if (_startDate.isAfter(_endDate)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Start date must be before end date'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 3),
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final result = await widget.absenceRequestRepository.createAbsenceRequest(
        userId: widget.userId,
        type: _absenceType,
        startDate: _startDate,
        endDate: _endDate,
      );

      if (!mounted) return;

      result.when(
        success: (absenceRequest) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Absence request created successfully'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 3),
            ),
          );
          widget.onAbsenceRequestCreated(absenceRequest);
          Navigator.of(context).pop();
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
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString()}'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 4),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final secondaryText = Theme.of(
      context,
    ).textTheme.bodyMedium?.color?.withValues(alpha: 0.72);
    final durationDays = _endDate.difference(_startDate).inDays + 1;

    return AlertDialog(
      title: const Text('Request Absence'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Absence Type Dropdown
            Container(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Absence Type',
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 6.0),
                  DropdownButton<AbsenceType>(
                    value: _absenceType,
                    isExpanded: true,
                    items: AbsenceType.values.map((type) {
                      return DropdownMenuItem(
                        value: type,
                        child: Text(type.displayName),
                      );
                    }).toList(),
                    onChanged: _isLoading
                        ? null
                        : (value) {
                            if (value != null) {
                              setState(() {
                                _absenceType = value;
                              });
                            }
                          },
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12.0),

            // Start Date
            Container(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Start Date',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: secondaryText,
                        ),
                      ),
                      const SizedBox(height: 4.0),
                      Text(
                        DateFormat('MMM d, yyyy').format(_startDate),
                        style: Theme.of(context).textTheme.labelMedium
                            ?.copyWith(
                              color: scheme.primary,
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                    ],
                  ),
                  ElevatedButton.icon(
                    onPressed: _isLoading ? null : _selectStartDate,
                    icon: const Icon(Icons.calendar_today, size: 16),
                    label: const Text('Change'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8.0,
                        vertical: 6.0,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12.0),

            // End Date
            Container(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'End Date',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: secondaryText,
                        ),
                      ),
                      const SizedBox(height: 4.0),
                      Text(
                        DateFormat('MMM d, yyyy').format(_endDate),
                        style: Theme.of(context).textTheme.labelMedium
                            ?.copyWith(
                              color: scheme.primary,
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                    ],
                  ),
                  ElevatedButton.icon(
                    onPressed: _isLoading ? null : _selectEndDate,
                    icon: const Icon(Icons.calendar_today, size: 16),
                    label: const Text('Change'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8.0,
                        vertical: 6.0,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12.0),

            // Duration display
            Container(
              padding: const EdgeInsets.all(8.0),
              decoration: BoxDecoration(
                color: Theme.of(context).brightness == Brightness.dark
                    ? scheme.surfaceContainerHighest
                    : Colors.blue.shade50,
                border: Border.all(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? scheme.outlineVariant
                      : Colors.blue.shade200,
                ),
                borderRadius: BorderRadius.circular(6.0),
              ),
              child: Row(
                children: [
                  Icon(Icons.info, size: 16, color: scheme.primary),
                  const SizedBox(width: 8.0),
                  Expanded(
                    child: Text(
                      'Duration: $durationDays days',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: scheme.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton.icon(
          onPressed: _isLoading ? null : _createAbsenceRequest,
          icon: _isLoading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.check, size: 16),
          label: _isLoading
              ? const Text('Creating...')
              : const Text('Request Absence'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green.shade600,
            foregroundColor: Colors.white,
          ),
        ),
      ],
    );
  }
}
