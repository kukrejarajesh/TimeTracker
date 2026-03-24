// AppProvider
// Holds selected date and the enriched list of time entries for that date.
// All navigation and data loading lives here so screens stay thin.

import 'package:flutter/foundation.dart';

import '../db/time_entry_repository.dart';

class AppProvider extends ChangeNotifier {
  final TimeEntryRepository _repo = TimeEntryRepository();

  DateTime _selectedDate = _today();
  List<Map<String, dynamic>> _entries = [];
  bool isLoading = false;

  DateTime get selectedDate => _selectedDate;
  List<Map<String, dynamic>> get entries => _entries;

  int get totalMinutes =>
      _entries.fold(0, (sum, e) => sum + (e['duration_min'] as int));

  /// Entries grouped by subcategory name, preserving start_time order.
  Map<String, List<Map<String, dynamic>>> get groupedEntries {
    final result = <String, List<Map<String, dynamic>>>{};
    for (final e in _entries) {
      final key = e['subcategory_name'] as String;
      result.putIfAbsent(key, () => []).add(e);
    }
    return result;
  }

  Future<void> loadEntries() async {
    isLoading = true;
    notifyListeners();
    _entries = await _repo.getEntriesForDateWithDetails(_formatDate(_selectedDate));
    isLoading = false;
    notifyListeners();
  }

  void goToPrevDay() {
    _selectedDate = _selectedDate.subtract(const Duration(days: 1));
    loadEntries();
  }

  void goToNextDay() {
    _selectedDate = _selectedDate.add(const Duration(days: 1));
    loadEntries();
  }

  // ── helpers ────────────────────────────────────────────────────────────────

  static DateTime _today() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  static String _formatDate(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';
}
