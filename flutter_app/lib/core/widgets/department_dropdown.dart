import 'package:flutter/material.dart';
import '../services/departments_service.dart';
import '../../data/models/department_model.dart';

/// Reusable dropdown that loads departments from the API and shows them by name.
class DepartmentDropdown extends StatefulWidget {
  /// Currently selected department id (optional).
  final String? value;

  /// Called when the user selects a different department.
  final ValueChanged<String?> onChanged;

  /// Optional label above the dropdown.
  final String? label;

  /// Optional input decoration (border, hint, etc.).
  final InputDecoration? decoration;

  const DepartmentDropdown({
    super.key,
    this.value,
    required this.onChanged,
    this.label,
    this.decoration,
  });

  @override
  State<DepartmentDropdown> createState() => _DepartmentDropdownState();
}

class _DepartmentDropdownState extends State<DepartmentDropdown> {
  final DepartmentsService _service = DepartmentsService();
  List<DepartmentModel> _departments = [];
  bool _loading = true;
  String? _error;

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final list = await _service.getDepartments();
      if (mounted) {
        setState(() {
          _departments = list;
          _error = null;
        });

        if (list.isNotEmpty && widget.value == null) {
          widget.onChanged(list.first.id);
        }
      }
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (widget.label != null) ...[
              Text(widget.label!),
              const SizedBox(height: 4),
            ],
            const LinearProgressIndicator(),
          ],
        ),
      );
    }

    if (_error != null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (widget.label != null) ...[
              Text(widget.label!),
              const SizedBox(height: 4),
            ],
            Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
        ),
      );
    }

    if (_departments.isEmpty) {
      return const SizedBox.shrink();
    }

    final decoration =
        widget.decoration ??
        const InputDecoration(border: OutlineInputBorder());

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.label != null) ...[
          Text(widget.label!),
          const SizedBox(height: 4),
        ],
        DropdownButtonFormField<String>(
          value:
              widget.value != null &&
                  _departments.any((d) => d.id == widget.value)
              ? widget.value
              : _departments.first.id,
          decoration: decoration,
          items: _departments
              .map((d) => DropdownMenuItem(value: d.id, child: Text(d.name)))
              .toList(),
          onChanged: widget.onChanged,
        ),
      ],
    );
  }
}
