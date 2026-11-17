// EntryFormScreen
// Manual time entry: date picker, grouped subcategory picker,
// start/end time pickers, auto-calculated duration, optional notes.
//
// Step 8: fully implemented.

import 'package:flutter/material.dart';

import '../constants/colors.dart';
import '../constants/strings.dart';
import '../db/category_repository.dart';
import '../db/subcategory_repository.dart';
import '../db/time_entry_repository.dart';
import '../models/category.dart';
import '../models/subcategory.dart';

class EntryFormScreen extends StatefulWidget {
  final DateTime initialDate;

  /// Optional pre-filled times (HH:mm), e.g. when filling an untracked gap.
  final String? initialStart;
  final String? initialEnd;

  const EntryFormScreen({
    super.key,
    required this.initialDate,
    this.initialStart,
    this.initialEnd,
  });

  @override
  State<EntryFormScreen> createState() => _EntryFormScreenState();
}

class _EntryFormScreenState extends State<EntryFormScreen> {
  final _categoryRepo = CategoryRepository();
  final _subcategoryRepo = SubcategoryRepository();
  final _timeEntryRepo = TimeEntryRepository();
  final _notesController = TextEditingController();

  late DateTime _selectedDate;
  TimeOfDay? _startTime;
  TimeOfDay? _endTime;
  Subcategory? _selectedSub;
  Category? _selectedCat;

  List<Category> _categories = [];
  Map<int, List<Subcategory>> _subsByCategory = {};
  bool _isLoading = true;
  bool _isSaving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _selectedDate = widget.initialDate;
    _startTime = _parseTime(widget.initialStart);
    _endTime = _parseTime(widget.initialEnd);
    _loadData();
  }

  static TimeOfDay? _parseTime(String? s) {
    if (s == null) return null;
    final parts = s.split(':');
    if (parts.length != 2) return null;
    final h = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    if (h == null || m == null) return null;
    // 24:00 (end of day) isn't representable as TimeOfDay; clamp to 23:59.
    if (h >= 24) return const TimeOfDay(hour: 23, minute: 59);
    return TimeOfDay(hour: h, minute: m);
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  // ── data ──────────────────────────────────────────────────────────────────

  Future<void> _loadData() async {
    final cats = await _categoryRepo.getAllCategories();
    final subs = await _subcategoryRepo.getActiveSubcategories();

    final Map<int, List<Subcategory>> grouped = {
      for (final c in cats) c.id: [],
    };
    for (final s in subs) {
      grouped[s.categoryId]?.add(s);
    }

    if (mounted) {
      setState(() {
        _categories = cats;
        _subsByCategory = grouped;
        _isLoading = false;
      });
    }
  }

  // ── computed ───────────────────────────────────────────────────────────────

  int? get _durationMin {
    if (_startTime == null || _endTime == null) return null;
    final start = _startTime!.hour * 60 + _startTime!.minute;
    final end = _endTime!.hour * 60 + _endTime!.minute;
    return end > start ? end - start : null;
  }

  // ── formatters ────────────────────────────────────────────────────────────

  static String _dateKey(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  static String _dateDisplay(DateTime d) {
    const months = [
      '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return '${days[d.weekday - 1]}, ${d.day} ${months[d.month]} ${d.year}';
  }

  static String _timeStr(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  // ── interactions ──────────────────────────────────────────────────────────

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (picked != null) setState(() => _selectedDate = picked);
  }

  Future<void> _pickStartTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _startTime ?? TimeOfDay.now(),
    );
    if (picked != null) setState(() => _startTime = picked);
  }

  Future<void> _pickEndTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _endTime ?? _startTime ?? TimeOfDay.now(),
    );
    if (picked != null) setState(() => _endTime = picked);
  }

  void _showSubcategoryPicker() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        maxChildSize: 0.9,
        minChildSize: 0.4,
        expand: false,
        builder: (_, scrollController) => _SubcategoryPickerSheet(
          categories: _categories,
          subsByCategory: _subsByCategory,
          selectedSubId: _selectedSub?.id,
          scrollController: scrollController,
          onSelected: (cat, sub) {
            setState(() {
              _selectedCat = cat;
              _selectedSub = sub;
              _error = null;
            });
            Navigator.pop(ctx);
          },
        ),
      ),
    );
  }

  Future<void> _save() async {
    if (_selectedSub == null) {
      setState(() => _error = 'Please select a subcategory');
      return;
    }
    if (_startTime == null) {
      setState(() => _error = 'Please set a start time');
      return;
    }
    if (_endTime == null) {
      setState(() => _error = 'Please set an end time');
      return;
    }
    final duration = _durationMin;
    if (duration == null || duration <= 0) {
      setState(() => _error = 'End time must be after start time');
      return;
    }

    final overlaps = await _timeEntryRepo.findOverlappingEntries(
      date: _dateKey(_selectedDate),
      startTime: _timeStr(_startTime!),
      endTime: _timeStr(_endTime!),
    );
    if (overlaps.isNotEmpty) {
      if (!mounted) return;
      final proceed = await _confirmOverlap(overlaps);
      if (proceed != true || !mounted) return;
    }

    setState(() {
      _isSaving = true;
      _error = null;
    });

    await _timeEntryRepo.createTimeEntry(
      subcategoryId: _selectedSub!.id,
      date: _dateKey(_selectedDate),
      startTime: _timeStr(_startTime!),
      endTime: _timeStr(_endTime!),
      durationMin: duration,
      notes: _notesController.text.trim().isEmpty
          ? null
          : _notesController.text.trim(),
    );

    if (mounted) Navigator.pop(context);
  }

  Future<bool?> _confirmOverlap(List<Map<String, dynamic>> overlaps) {
    final lines = overlaps
        .map((o) =>
            '• ${o['subcategory_name']}  ${o['start_time']}–${o['end_time']}')
        .join('\n');
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text(AppStrings.overlapTitle),
        content: Text(
            'This entry overlaps:\n\n$lines\n\nOverlaps inflate your totals.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text(AppStrings.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(AppStrings.saveAnyway),
          ),
        ],
      ),
    );
  }

  // ── build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.onPrimary,
        title: const Text(AppStrings.newEntry),
        actions: [
          TextButton(
            onPressed: _isSaving ? null : _save,
            child: Text(
              AppStrings.save,
              style: TextStyle(
                color: colorScheme.onPrimary,
                fontWeight: FontWeight.w600,
                fontSize: 16,
              ),
            ),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(
                      _error!,
                      style: TextStyle(
                          color: colorScheme.error,
                          fontWeight: FontWeight.w500),
                    ),
                  ),
                _TappableField(
                  label: AppStrings.date,
                  value: _dateDisplay(_selectedDate),
                  icon: Icons.calendar_today_outlined,
                  onTap: _pickDate,
                ),
                const SizedBox(height: 12),
                _TappableField(
                  label: AppStrings.subcategory,
                  value: _selectedSub?.name ?? 'Tap to select',
                  icon: Icons.label_outline,
                  isPlaceholder: _selectedSub == null,
                  accentColor: _selectedCat != null
                      ? AppColors.hexToColor(_selectedCat!.color)
                      : null,
                  onTap: _showSubcategoryPicker,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _TappableField(
                        label: AppStrings.startTime,
                        value: _startTime != null ? _timeStr(_startTime!) : '--:--',
                        icon: Icons.access_time_outlined,
                        isPlaceholder: _startTime == null,
                        onTap: _pickStartTime,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _TappableField(
                        label: AppStrings.endTime,
                        value: _endTime != null ? _timeStr(_endTime!) : '--:--',
                        icon: Icons.access_time_outlined,
                        isPlaceholder: _endTime == null,
                        onTap: _pickEndTime,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _DurationTile(durationMin: _durationMin),
                const SizedBox(height: 12),
                _NotesTile(controller: _notesController),
                const SizedBox(height: 32),
                FilledButton(
                  onPressed: _isSaving ? null : _save,
                  child: _isSaving
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text(AppStrings.save),
                ),
              ],
            ),
    );
  }
}

// ---------------------------------------------------------------------------
// _TappableField
// ---------------------------------------------------------------------------

class _TappableField extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final bool isPlaceholder;
  final Color? accentColor;
  final VoidCallback onTap;

  const _TappableField({
    required this.label,
    required this.value,
    required this.icon,
    required this.onTap,
    this.isPlaceholder = false,
    this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final valueColor = accentColor ??
        (isPlaceholder
            ? colorScheme.onSurfaceVariant
            : colorScheme.onSurface);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          border: Border.all(color: colorScheme.outlineVariant),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Icon(icon, size: 20, color: colorScheme.onSurfaceVariant),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 11,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight:
                          isPlaceholder ? FontWeight.w400 : FontWeight.w500,
                      color: valueColor,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right,
                size: 20, color: colorScheme.onSurfaceVariant),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// _DurationTile
// ---------------------------------------------------------------------------

class _DurationTile extends StatelessWidget {
  final int? durationMin;

  const _DurationTile({this.durationMin});

  static String _fmt(int m) {
    final h = m ~/ 60;
    final min = m % 60;
    if (h == 0) return '${min}m';
    if (min == 0) return '${h}h';
    return '${h}h ${min}m';
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final hasValue = durationMin != null && durationMin! > 0;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: hasValue
            ? colorScheme.primaryContainer.withAlpha(120)
            : colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(Icons.timelapse_outlined,
              size: 20, color: colorScheme.onSurfaceVariant),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                AppStrings.duration,
                style: TextStyle(
                    fontSize: 11, color: colorScheme.onSurfaceVariant),
              ),
              const SizedBox(height: 2),
              Text(
                hasValue ? _fmt(durationMin!) : '—',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight:
                      hasValue ? FontWeight.w600 : FontWeight.w400,
                  color: hasValue
                      ? colorScheme.onPrimaryContainer
                      : colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// _NotesTile
// ---------------------------------------------------------------------------

class _NotesTile extends StatelessWidget {
  final TextEditingController controller;

  const _NotesTile({required this.controller});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(10),
      ),
      child: TextField(
        controller: controller,
        maxLines: 3,
        minLines: 3,
        decoration: InputDecoration(
          hintText: AppStrings.notes,
          hintStyle:
              TextStyle(fontSize: 14, color: colorScheme.onSurfaceVariant),
          contentPadding: const EdgeInsets.all(14),
          border: InputBorder.none,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// _SubcategoryPickerSheet
// ---------------------------------------------------------------------------

class _SubcategoryPickerSheet extends StatelessWidget {
  final List<Category> categories;
  final Map<int, List<Subcategory>> subsByCategory;
  final int? selectedSubId;
  final ScrollController scrollController;
  final void Function(Category, Subcategory) onSelected;

  const _SubcategoryPickerSheet({
    required this.categories,
    required this.subsByCategory,
    required this.selectedSubId,
    required this.scrollController,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      children: [
        // Drag handle
        Container(
          margin: const EdgeInsets.symmetric(vertical: 10),
          width: 40,
          height: 4,
          decoration: BoxDecoration(
            color: colorScheme.outlineVariant,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Select Subcategory',
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: colorScheme.onSurface),
            ),
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: ListView(
            controller: scrollController,
            children: [
              for (final cat in categories)
                if ((subsByCategory[cat.id] ?? []).isNotEmpty) ...[
                  // Category header row
                  Padding(
                    padding:
                        const EdgeInsets.fromLTRB(16, 14, 16, 4),
                    child: Row(
                      children: [
                        Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            color: AppColors.hexToColor(cat.color),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          cat.name,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: AppColors.hexToColor(cat.color),
                            letterSpacing: 0.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Subcategory tiles
                  for (final sub in subsByCategory[cat.id]!)
                    ListTile(
                      contentPadding:
                          const EdgeInsets.only(left: 34, right: 16),
                      title: Text(sub.name,
                          style: const TextStyle(fontSize: 14)),
                      selected: sub.id == selectedSubId,
                      selectedColor: AppColors.hexToColor(cat.color),
                      trailing: sub.id == selectedSubId
                          ? Icon(Icons.check,
                              color: AppColors.hexToColor(cat.color),
                              size: 18)
                          : null,
                      onTap: () => onSelected(cat, sub),
                    ),
                ],
            ],
          ),
        ),
      ],
    );
  }
}
