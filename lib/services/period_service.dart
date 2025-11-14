import 'package:flutter/material.dart';
import 'package:accounting_app/data/storage_service.dart';

class PeriodService extends ChangeNotifier {
  static final PeriodService _instance = PeriodService._internal();

  factory PeriodService() => _instance;

  PeriodService._internal();

  DateTime? _startDate;
  DateTime? _endDate;
  String _periodType = 'current_fy'; // 'current_fy' or 'custom'

  // Store company default for reference (only used on app startup)
  DateTime? _companyDefaultStart;
  DateTime? _companyDefaultEnd;
  String? _companyDefaultType;

  // Store session default (what's currently set in Options page)
  DateTime? _sessionDefaultStart;
  DateTime? _sessionDefaultEnd;
  String? _sessionDefaultType;

  DateTime? get startDate => _startDate;
  DateTime? get endDate => _endDate;
  String get periodType => _periodType;

  String get periodText {
    if (_startDate == null || _endDate == null) {
      // Default to current financial year
      final now = DateTime.now();
      final year = now.month >= 4 ? now.year : now.year - 1;
      return '01/04/$year to 31/03/${year + 1}';
    }
    return '${_formatDate(_startDate!)} to ${_formatDate(_endDate!)}';
  }

  String get periodTypeText {
    if (_periodType == 'current_fy') {
      return 'FY';
    }
    return 'Custom';
  }

  void setPeriod(DateTime start, DateTime end, {String? type, bool setAsSessionDefault = false}) {
    _startDate = start;
    _endDate = end;
    if (type != null) {
      _periodType = type;
    } else {
      // Auto-detect if it matches current FY
      final now = DateTime.now();
      final year = now.month >= 4 ? now.year : now.year - 1;
      final fyStart = DateTime(year, 4, 1);
      final fyEnd = DateTime(year + 1, 3, 31);

      if (start.year == fyStart.year && start.month == fyStart.month && start.day == fyStart.day &&
          end.year == fyEnd.year && end.month == fyEnd.month && end.day == fyEnd.day) {
        _periodType = 'current_fy';
      } else {
        _periodType = 'custom';
      }
    }

    // If requested, also set as session default
    if (setAsSessionDefault) {
      _sessionDefaultStart = start;
      _sessionDefaultEnd = end;
      _sessionDefaultType = _periodType;
    }

    notifyListeners();
  }

  // Set current period as session default (called when user changes period in Options page)
  void setSessionDefault() {
    _sessionDefaultStart = _startDate;
    _sessionDefaultEnd = _endDate;
    _sessionDefaultType = _periodType;
  }

  void initializeDefaultPeriod() {
    final now = DateTime.now();
    final year = now.month >= 4 ? now.year : now.year - 1;
    _startDate = DateTime(year, 4, 1);
    _endDate = DateTime(year + 1, 3, 31);
    _periodType = 'current_fy';
  }

  // Load default period from company settings (only called on app startup)
  Future<void> loadCompanyDefaultPeriod(int companyId) async {
    try {
      final settings = await StorageService.getDefaultPeriodSettings(companyId);
      final periodType = settings['period_type'] as String? ?? 'current_fy';

      _companyDefaultType = periodType;

      if (periodType == 'current_fy') {
        // Calculate current FY
        final now = DateTime.now();
        final year = now.month >= 4 ? now.year : now.year - 1;
        _companyDefaultStart = DateTime(year, 4, 1);
        _companyDefaultEnd = DateTime(year + 1, 3, 31);
      } else {
        // Load custom period
        final startStr = settings['period_start'] as String?;
        final endStr = settings['period_end'] as String?;

        if (startStr != null && endStr != null) {
          _companyDefaultStart = DateTime.parse(startStr);
          _companyDefaultEnd = DateTime.parse(endStr);
        } else {
          // Fallback to current FY if custom dates not found
          final now = DateTime.now();
          final year = now.month >= 4 ? now.year : now.year - 1;
          _companyDefaultStart = DateTime(year, 4, 1);
          _companyDefaultEnd = DateTime(year + 1, 3, 31);
        }
      }

      // Set current period to company default
      _startDate = _companyDefaultStart;
      _endDate = _companyDefaultEnd;
      _periodType = periodType;

      // Also set as initial session default
      _sessionDefaultStart = _companyDefaultStart;
      _sessionDefaultEnd = _companyDefaultEnd;
      _sessionDefaultType = periodType;

      notifyListeners();
    } catch (e) {
      debugPrint('Error loading company default period: $e');
      // Fallback to current FY on error
      initializeDefaultPeriod();
    }
  }

  // Save current period as company default
  Future<bool> saveAsCompanyDefault(int companyId) async {
    if (_startDate == null || _endDate == null) return false;

    try {
      final startStr = '${_startDate!.year}-${_startDate!.month.toString().padLeft(2, '0')}-${_startDate!.day.toString().padLeft(2, '0')}';
      final endStr = '${_endDate!.year}-${_endDate!.month.toString().padLeft(2, '0')}-${_endDate!.day.toString().padLeft(2, '0')}';

      final success = await StorageService.saveDefaultPeriodSettings(
        companyId,
        _periodType,
        startStr,
        endStr,
      );

      if (success) {
        _companyDefaultStart = _startDate;
        _companyDefaultEnd = _endDate;
        _companyDefaultType = _periodType;
      }

      return success;
    } catch (e) {
      debugPrint('Error saving company default period: $e');
      return false;
    }
  }

  // Reset to session default period (what user set in Options page)
  void resetToSessionDefault() {
    if (_sessionDefaultStart != null && _sessionDefaultEnd != null) {
      _startDate = _sessionDefaultStart;
      _endDate = _sessionDefaultEnd;
      _periodType = _sessionDefaultType ?? 'current_fy';
      notifyListeners();
    } else {
      // Fallback if no session default set - shouldn't happen in normal use
      if (_companyDefaultStart != null && _companyDefaultEnd != null) {
        _startDate = _companyDefaultStart;
        _endDate = _companyDefaultEnd;
        _periodType = _companyDefaultType ?? 'current_fy';
      } else {
        initializeDefaultPeriod();
      }
      notifyListeners();
    }
  }

  bool get isUsingCompanyDefault {
    if (_companyDefaultStart == null || _companyDefaultEnd == null) return false;
    if (_startDate == null || _endDate == null) return false;

    return _startDate!.year == _companyDefaultStart!.year &&
           _startDate!.month == _companyDefaultStart!.month &&
           _startDate!.day == _companyDefaultStart!.day &&
           _endDate!.year == _companyDefaultEnd!.year &&
           _endDate!.month == _companyDefaultEnd!.month &&
           _endDate!.day == _companyDefaultEnd!.day;
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  // Helper method to get date range for queries
  String get startDateString => _startDate != null
      ? '${_startDate!.year}-${_startDate!.month.toString().padLeft(2, '0')}-${_startDate!.day.toString().padLeft(2, '0')}'
      : '';

  String get endDateString => _endDate != null
      ? '${_endDate!.year}-${_endDate!.month.toString().padLeft(2, '0')}-${_endDate!.day.toString().padLeft(2, '0')}'
      : '';
}
