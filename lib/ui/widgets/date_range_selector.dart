import 'package:flutter/material.dart';
import 'package:accounting_app/ui/widgets/custom_date_spinner_wheel.dart';

typedef DateRangeCallback = void Function(DateTime start, DateTime end);

enum _ActivePicker { none, start, end }

class DateRangeSelector extends StatefulWidget {
  final DateTime? initialStartDate;
  final DateTime? initialEndDate;
  final DateRangeCallback onDateRangeSelected;
  final DateTime? minSelectableDate;
  final VoidCallback? onCancel;
  final VoidCallback? onResetToDefault;
  final bool showResetButton;

  const DateRangeSelector({
    Key? key,
    this.initialStartDate,
    this.initialEndDate,
    required this.onDateRangeSelected,
    this.minSelectableDate,
    this.onCancel,
    this.onResetToDefault,
    this.showResetButton = false,
  }) : super(key: key);

  @override
  State<DateRangeSelector> createState() => _DateRangeSelectorState();
}

class _DateRangeSelectorState extends State<DateRangeSelector> {
  late DateTime _currentStartDate;
  late DateTime _currentEndDate;
  _ActivePicker _activePicker = _ActivePicker.none;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    final minDate = widget.minSelectableDate ?? DateTime(1900);

    // Initialize start date, ensuring it's not before the minimum date
    _currentStartDate = widget.initialStartDate ?? now;
    if (_currentStartDate.isBefore(minDate)) {
      _currentStartDate = minDate;
    }

    // Initialize end date, ensuring it's not before the start date
    _currentEndDate = widget.initialEndDate ?? _currentStartDate;
    if (_currentEndDate.isBefore(_currentStartDate)) {
      _currentEndDate = _currentStartDate;
    }
  }

  String _formatDate(DateTime d) {
    final dd = d.day.toString().padLeft(2, '0');
    final mm = d.month.toString().padLeft(2, '0');
    return '$dd/$mm/${d.year}';
  }

  @override
  Widget build(BuildContext context) {
    final minDate = widget.minSelectableDate ?? DateTime(1900);

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Select Period',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildDateSelector('From Date', _currentStartDate, _ActivePicker.start),
                  if (_activePicker == _ActivePicker.start)
                    _DatePickerSpinner(
                      key: const ValueKey('start-picker'),
                      initialDate: _currentStartDate,
                      minDate: minDate,
                      maxDate: DateTime(DateTime.now().year + 50), // Allow future dates for start date too
                      onDateChanged: (newDate) {
                        setState(() {
                          _currentStartDate = newDate;
                          if (_currentEndDate.isBefore(_currentStartDate)) {
                            _currentEndDate = _currentStartDate;
                          }
                        });
                      },
                    ),
                  const SizedBox(height: 16),
                  _buildDateSelector('To Date', _currentEndDate, _ActivePicker.end),
                  if (_activePicker == _ActivePicker.end)
                    _DatePickerSpinner(
                      key: const ValueKey('end-picker'),
                      initialDate: _currentEndDate,
                      minDate: _currentStartDate,
                      maxDate: DateTime(DateTime.now().year + 50), // Allow much further future dates
                      onDateChanged: (newDate) {
                        setState(() {
                          _currentEndDate = newDate;
                        });
                      },
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          // Reset button above OK/Cancel
          if (widget.showResetButton && widget.onResetToDefault != null) ...[
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: widget.onResetToDefault,
                icon: const Icon(Icons.refresh, size: 18, color: Color(0xFF2C5545)),
                label: const Text(
                  'Reset to Default Period',
                  style: TextStyle(color: Color(0xFF2C5545), fontSize: 14),
                ),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Color(0xFF2C5545)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],
          // OK and Cancel buttons
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: widget.onCancel ?? () => Navigator.of(context).pop(),
                child: const Text('CANCEL', style: TextStyle(color: Colors.black54)),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: () {
                  // Ensure start date is not before the minimum date
                  if (widget.minSelectableDate != null && _currentStartDate.isBefore(widget.minSelectableDate!)) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('From date cannot be before ${_formatDate(widget.minSelectableDate!)}'),
                        duration: const Duration(seconds: 2),
                      ),
                    );
                    return;
                  }

                  // Ensure end date is not before start date
                  if (_currentEndDate.isBefore(_currentStartDate)) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('To Date cannot be before From Date'),
                        duration: Duration(seconds: 2),
                      ),
                    );
                    return;
                  }

                  // Call the callback to update the selected date range
                  widget.onDateRangeSelected(_currentStartDate, _currentEndDate);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2C5545),
                  foregroundColor: Colors.white,
                ),
                child: const Text('OK'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDateSelector(String label, DateTime date, _ActivePicker pickerType) {
    final selected = _activePicker == pickerType;
    return GestureDetector(
      onTap: () => setState(() {
        _activePicker = selected ? _ActivePicker.none : pickerType;
      }),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 16, color: Colors.black54)),
          const SizedBox(height: 4),
          Text(
            _formatDate(date),
            style: TextStyle(
              fontSize: 18,
              color: selected ? Theme.of(context).primaryColor : Colors.black87,
            ),
          ),
          Divider(
            color: selected ? Theme.of(context).primaryColor : Colors.black54,
            thickness: selected ? 2 : 1,
          ),
        ],
      ),
    );
  }
}

class _DatePickerSpinner extends StatefulWidget {
  final DateTime initialDate;
  final DateTime minDate;
  final DateTime maxDate;
  final ValueChanged<DateTime> onDateChanged;

  const _DatePickerSpinner({
    Key? key,
    required this.initialDate,
    required this.minDate,
    required this.maxDate,
    required this.onDateChanged,
  }) : super(key: key);

  @override
  _DatePickerSpinnerState createState() => _DatePickerSpinnerState();
}

class _DatePickerSpinnerState extends State<_DatePickerSpinner> {
  late int _selectedYear;
  late int _selectedMonth;
  late int _selectedDay;

  @override
  void initState() {
    super.initState();
    _initialize(widget.initialDate);
  }

  void _initialize(DateTime date) {
    _selectedYear = date.year;
    _selectedMonth = date.month;
    _selectedDay = date.day;
  }

  void _handleChange() {
    final maxDays = _daysInMonth(_selectedYear, _selectedMonth);
    if (_selectedDay > maxDays) _selectedDay = maxDays;
    DateTime newDate = DateTime(_selectedYear, _selectedMonth, _selectedDay);
    if (newDate.isBefore(widget.minDate)) newDate = widget.minDate;
    if (newDate.isAfter(widget.maxDate)) newDate = widget.maxDate;
    _initialize(newDate);
    widget.onDateChanged(newDate);
  }

  int _daysInMonth(int year, int month) {
    if (month == DateTime.february) {
      final leap = (year % 4 == 0 && year % 100 != 0) || (year % 400 == 0);
      return leap ? 29 : 28;
    }
    const days = [0, 31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31];
    return days[month];
  }

  @override
  Widget build(BuildContext context) {
    List<String> years = [for (int y = widget.minDate.year; y <= widget.maxDate.year; y++) y.toString()];
    if (!years.contains(_selectedYear.toString())) _selectedYear = int.parse(years.first);

    int minM = (_selectedYear == widget.minDate.year) ? widget.minDate.month : 1;
    int maxM = (_selectedYear == widget.maxDate.year) ? widget.maxDate.month : 12;
    List<String> months = [for (int m = minM; m <= maxM; m++) m.toString().padLeft(2, '0')];
    if (!months.contains(_selectedMonth.toString().padLeft(2, '0'))) _selectedMonth = int.parse(months.first);

    int minD = (_selectedYear == widget.minDate.year && _selectedMonth == widget.minDate.month)
        ? widget.minDate.day
        : 1;
    int maxD = (_selectedYear == widget.maxDate.year && _selectedMonth == widget.maxDate.month)
        ? widget.maxDate.day
        : _daysInMonth(_selectedYear, _selectedMonth);
    List<String> days = [for (int d = minD; d <= maxD; d++) d.toString().padLeft(2, '0')];
    if (!days.contains(_selectedDay.toString().padLeft(2, '0'))) _selectedDay = int.parse(days.first);

    return SizedBox(
      height: 150,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          CustomDateSpinnerWheel(
            items: days,
            initialValue: _selectedDay.toString().padLeft(2, '0'),
            onSelectedItemChanged: (v) {
              setState(() {
                _selectedDay = int.parse(v);
                _handleChange();
              });
            },
          ),
          CustomDateSpinnerWheel(
            items: months,
            initialValue: _selectedMonth.toString().padLeft(2, '0'),
            onSelectedItemChanged: (v) {
              setState(() {
                _selectedMonth = int.parse(v);
                _handleChange();
              });
            },
          ),
          CustomDateSpinnerWheel(
            items: years,
            initialValue: _selectedYear.toString(),
            onSelectedItemChanged: (v) {
              setState(() {
                _selectedYear = int.parse(v);
                _handleChange();
              });
            },
          ),
        ],
      ),
    );
  }
}
