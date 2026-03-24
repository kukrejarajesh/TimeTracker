// ReportsScreen
// Daily and weekly summaries grouped by category with duration totals.
// Week runs Monday–Sunday.

import 'package:flutter/material.dart';

import '../constants/colors.dart';
import '../constants/strings.dart';
import '../db/time_entry_repository.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final TimeEntryRepository _repo = TimeEntryRepository();

  DateTime _selectedDay = _today();
  DateTime _weekStart = _mondayOf(_today());

  bool _isLoadingDaily = false;
  bool _isLoadingWeekly = false;

  List<Map<String, dynamic>> _dailyRows = [];
  List<Map<String, dynamic>> _weeklyRows = [];

  final Set<int> _dailyExpanded = {};
  final Set<int> _weeklyExpanded = {};

  // ── lifecycle ──────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        if (_tabController.index == 0) {
          _loadDaily();
        } else {
          _loadWeekly();
        }
      }
    });
    _loadDaily();
    _loadWeekly();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // ── helpers ────────────────────────────────────────────────────────────────

  static DateTime _today() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  static DateTime _mondayOf(DateTime d) =>
      d.subtract(Duration(days: d.weekday - 1));

  static String _fmt(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  String _fmtMin(int min) {
    final h = min ~/ 60;
    final m = min % 60;
    if (h == 0) return '${m}m';
    if (m == 0) return '${h}h';
    return '${h}h ${m}m';
  }

  String _dailyLabel() {
    final today = _today();
    if (_selectedDay == today) return AppStrings.today;
    if (_selectedDay == today.subtract(const Duration(days: 1))) {
      return AppStrings.yesterday;
    }
    return '${_selectedDay.day}/${_selectedDay.month}/${_selectedDay.year}';
  }

  String _weekLabel() {
    final end = _weekStart.add(const Duration(days: 6));
    final s = '${_weekStart.day}/${_weekStart.month}';
    final e = '${end.day}/${end.month}/${end.year}';
    return '$s – $e';
  }

  // ── data loading ───────────────────────────────────────────────────────────

  Future<void> _loadDaily() async {
    setState(() => _isLoadingDaily = true);
    final rows = await _repo.getTotalDurationBySubcategoryForRange(
      startDate: _fmt(_selectedDay),
      endDate: _fmt(_selectedDay),
    );
    setState(() {
      _dailyRows = rows;
      _isLoadingDaily = false;
    });
  }

  Future<void> _loadWeekly() async {
    setState(() => _isLoadingWeekly = true);
    final weekEnd = _weekStart.add(const Duration(days: 6));
    final rows = await _repo.getTotalDurationBySubcategoryForRange(
      startDate: _fmt(_weekStart),
      endDate: _fmt(weekEnd),
    );
    setState(() {
      _weeklyRows = rows;
      _isLoadingWeekly = false;
    });
  }

  // ── aggregation ────────────────────────────────────────────────────────────

  List<_CategorySummary> _buildSummary(List<Map<String, dynamic>> rows) {
    final map = <int, _CategorySummary>{};
    for (final row in rows) {
      final catId = row['category_id'] as int;
      final min = (row['total_duration_min'] as num).toInt();
      map.putIfAbsent(
        catId,
        () => _CategorySummary(
          id: catId,
          name: row['category_name'] as String,
          color: AppColors.hexToColor(row['category_color'] as String),
          subcategories: [],
        ),
      );
      map[catId]!.subcategories.add(
            _SubcategorySummary(
              name: row['subcategory_name'] as String,
              totalMin: min,
            ),
          );
    }
    final list = map.values.toList();
    // Sort categories by descending total duration
    list.sort((a, b) => b.totalMin.compareTo(a.totalMin));
    return list;
  }

  // ── build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(AppStrings.reports),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: AppStrings.daily),
            Tab(text: AppStrings.weekly),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildDailyTab(),
          _buildWeeklyTab(),
        ],
      ),
    );
  }

  Widget _buildDailyTab() {
    return Column(
      children: [
        _buildNavRow(
          label: _dailyLabel(),
          onPrev: () {
            setState(() {
              _selectedDay =
                  _selectedDay.subtract(const Duration(days: 1));
              _dailyExpanded.clear();
            });
            _loadDaily();
          },
          onNext: () {
            setState(() {
              _selectedDay = _selectedDay.add(const Duration(days: 1));
              _dailyExpanded.clear();
            });
            _loadDaily();
          },
        ),
        Expanded(
          child: _isLoadingDaily
              ? const Center(child: CircularProgressIndicator())
              : _buildReportBody(_dailyRows, _dailyExpanded),
        ),
      ],
    );
  }

  Widget _buildWeeklyTab() {
    return Column(
      children: [
        _buildNavRow(
          label: _weekLabel(),
          onPrev: () {
            setState(() {
              _weekStart =
                  _weekStart.subtract(const Duration(days: 7));
              _weeklyExpanded.clear();
            });
            _loadWeekly();
          },
          onNext: () {
            setState(() {
              _weekStart = _weekStart.add(const Duration(days: 7));
              _weeklyExpanded.clear();
            });
            _loadWeekly();
          },
        ),
        Expanded(
          child: _isLoadingWeekly
              ? const Center(child: CircularProgressIndicator())
              : _buildReportBody(_weeklyRows, _weeklyExpanded),
        ),
      ],
    );
  }

  Widget _buildNavRow({
    required String label,
    required VoidCallback onPrev,
    required VoidCallback onNext,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: onPrev,
          ),
          Text(label, style: Theme.of(context).textTheme.titleMedium),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: onNext,
          ),
        ],
      ),
    );
  }

  Widget _buildReportBody(
    List<Map<String, dynamic>> rows,
    Set<int> expanded,
  ) {
    final summary = _buildSummary(rows);

    if (summary.isEmpty) {
      return const Center(child: Text(AppStrings.noEntriesForPeriod));
    }

    final totalMin = summary.fold(0, (s, c) => s + c.totalMin);

    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 16),
      children: [
        // ── Total banner ──
        Card(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  AppStrings.total,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(
                  _fmtMin(totalMin),
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        // ── Category cards ──
        for (final cat in summary)
          _buildCategoryCard(cat, expanded),
      ],
    );
  }

  Widget _buildCategoryCard(_CategorySummary cat, Set<int> expanded) {
    final isExpanded = expanded.contains(cat.id);
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Column(
        children: [
          ListTile(
            leading: Container(
              width: 14,
              height: 14,
              decoration: BoxDecoration(
                color: cat.color,
                shape: BoxShape.circle,
              ),
            ),
            title: Text(
              cat.name,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _fmtMin(cat.totalMin),
                  style: TextStyle(
                    color: cat.color,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(width: 4),
                Icon(
                  isExpanded ? Icons.expand_less : Icons.expand_more,
                  size: 20,
                ),
              ],
            ),
            onTap: () => setState(() {
              if (isExpanded) {
                expanded.remove(cat.id);
              } else {
                expanded.add(cat.id);
              }
            }),
          ),
          if (isExpanded)
            for (final sub in cat.subcategories)
              Padding(
                padding: const EdgeInsets.only(
                  left: 44,
                  right: 16,
                  bottom: 10,
                ),
                child: Row(
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      margin: const EdgeInsets.only(right: 10),
                      decoration: BoxDecoration(
                        color: cat.color.withAlpha(160),
                        shape: BoxShape.circle,
                      ),
                    ),
                    Expanded(
                      child: Text(
                        sub.name,
                        style: TextStyle(
                          color: Colors.grey[700],
                          fontSize: 13,
                        ),
                      ),
                    ),
                    Text(
                      _fmtMin(sub.totalMin),
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
        ],
      ),
    );
  }
}

// ── Local data classes ─────────────────────────────────────────────────────

class _CategorySummary {
  final int id;
  final String name;
  final Color color;
  final List<_SubcategorySummary> subcategories;

  _CategorySummary({
    required this.id,
    required this.name,
    required this.color,
    required this.subcategories,
  });

  int get totalMin => subcategories.fold(0, (s, sub) => s + sub.totalMin);
}

class _SubcategorySummary {
  final String name;
  final int totalMin;

  const _SubcategorySummary({required this.name, required this.totalMin});
}
