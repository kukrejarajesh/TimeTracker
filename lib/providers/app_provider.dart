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

  /// Smallest untracked stretch worth surfacing, in minutes.
  static const int minGapMinutes = 15;

  /// Untracked stretches of the selected day as (startMin, endMin) minutes
  /// since midnight. Past days cover 00:00–24:00, today only up to now,
  /// future days have none. Overlapping entries are merged first so they
  /// don't hide a real gap.
  List<(int, int)> get gaps {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final int dayEnd;
    if (_selectedDate.isAfter(today)) {
      return [];
    } else if (_selectedDate == today) {
      dayEnd = now.hour * 60 + now.minute;
    } else {
      dayEnd = 24 * 60;
    }

    final ranges = _entries
        .map((e) => (_toMin(e['start_time'] as String),
            _toMin(e['end_time'] as String)))
        .toList()
      ..sort((a, b) => a.$1.compareTo(b.$1));

    final result = <(int, int)>[];
    var cursor = 0;
    for (final (s, e) in ranges) {
      if (s - cursor >= minGapMinutes && s <= dayEnd) {
        result.add((cursor, s));
      }
      if (e > cursor) cursor = e;
    }
    if (dayEnd - cursor >= minGapMinutes) result.add((cursor, dayEnd));
    return result;
  }

  int get untrackedMinutes => gaps.fold(0, (sum, g) => sum + (g.$2 - g.$1));

  static int _toMin(String hhmm) {
    final p = hhmm.split(':');
    return int.parse(p[0]) * 60 + int.parse(p[1]);
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
