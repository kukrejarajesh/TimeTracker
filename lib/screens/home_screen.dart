// HomeScreen
// Default view: today's date, list of entries for selected date,
// day total at top, date navigation arrows, FAB to add entry.
//
// Step 7: wired to real database via AppProvider.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../constants/colors.dart';
import '../constants/strings.dart';
import '../providers/app_provider.dart';
import 'entry_form_screen.dart';

String _formatDuration(int minutes) {
  final h = minutes ~/ 60;
  final m = minutes % 60;
  if (h == 0) return '${m}m';
  if (m == 0) return '${h}h';
  return '${h}h ${m}m';
}

// ---------------------------------------------------------------------------

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AppProvider>().loadEntries();
    });
  }

  // ── helpers ────────────────────────────────────────────────────────────────

  String _headerLabel(DateTime selectedDate) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    if (selectedDate == today) return AppStrings.today;
    if (selectedDate == yesterday) return AppStrings.yesterday;
    return _formatDateLong(selectedDate);
  }

  String _formatDateLong(DateTime d) {
    const months = [
      '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final weekday = days[d.weekday - 1];
    return '$weekday, ${d.day} ${months[d.month]} ${d.year}';
  }

  static String _hhmm(int minutes) =>
      '${(minutes ~/ 60).toString().padLeft(2, '0')}:'
      '${(minutes % 60).toString().padLeft(2, '0')}';

  Future<void> _openEntryForm(BuildContext context,
      {String? start, String? end}) async {
    final provider = context.read<AppProvider>();
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => EntryFormScreen(
          initialDate: provider.selectedDate,
          initialStart: start,
          initialEnd: end,
        ),
      ),
    );
    if (mounted) provider.loadEntries();
  }

  // ── build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final colorScheme = Theme.of(context).colorScheme;
    final grouped = provider.groupedEntries;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: _buildAppBar(context, provider, colorScheme),
      body: provider.isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                _TotalHoursBar(
                  label: AppStrings.totalHours,
                  formatted: _formatDuration(provider.totalMinutes),
                  entryCount: provider.entries.length,
                  untrackedMinutes: provider.untrackedMinutes,
                ),
                Expanded(
                  child: grouped.isEmpty
                      ? _EmptyState()
                      : ListView(
                          padding: const EdgeInsets.fromLTRB(12, 8, 12, 80),
                          children: [
                            if (provider.gaps.isNotEmpty)
                              _GapsSection(
                                gaps: provider.gaps,
                                hhmm: _hhmm,
                                onTap: (g) => _openEntryForm(context,
                                    start: _hhmm(g.$1), end: _hhmm(g.$2)),
                              ),
                            for (final group in grouped.entries)
                              _SubcategoryGroup(
                                subcategory: group.key,
                                entries: group.value,
                              ),
                          ],
                        ),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openEntryForm(context),
        tooltip: AppStrings.addEntry,
        child: const Icon(Icons.add),
      ),
    );
  }

  AppBar _buildAppBar(
      BuildContext context, AppProvider provider, ColorScheme colorScheme) {
    final selected = provider.selectedDate;
    return AppBar(
      backgroundColor: colorScheme.primary,
      foregroundColor: colorScheme.onPrimary,
      centerTitle: true,
      leading: IconButton(
        icon: const Icon(Icons.chevron_left),
        tooltip: 'Previous day',
        onPressed: provider.goToPrevDay,
      ),
      title: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            _headerLabel(selected),
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          ),
          Text(
            _formatDateLong(selected),
            style: TextStyle(
              fontSize: 12,
              color: colorScheme.onPrimary.withAlpha(200),
            ),
          ),
        ],
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.chevron_right),
          tooltip: 'Next day',
          onPressed: provider.goToNextDay,
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Sub-widgets
// ---------------------------------------------------------------------------

class _TotalHoursBar extends StatelessWidget {
  final String label;
  final String formatted;
  final int entryCount;
  final int untrackedMinutes;

  const _TotalHoursBar({
    required this.label,
    required this.formatted,
    required this.entryCount,
    required this.untrackedMinutes,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      color: colorScheme.primaryContainer,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Row(
        children: [
          Icon(Icons.access_time_rounded,
              size: 18, color: colorScheme.onPrimaryContainer),
          const SizedBox(width: 8),
          Text(
            '$label: $formatted',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: colorScheme.onPrimaryContainer,
            ),
          ),
          const Spacer(),
          if (untrackedMinutes > 0) ...[
            Text(
              '${AppStrings.untracked}: ${_formatDuration(untrackedMinutes)}',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: colorScheme.error,
              ),
            ),
            const SizedBox(width: 12),
          ],
          Text(
            '$entryCount ${entryCount == 1 ? 'entry' : 'entries'}',
            style: TextStyle(
              fontSize: 13,
              color: colorScheme.onPrimaryContainer.withAlpha(180),
            ),
          ),
        ],
      ),
    );
  }
}

class _GapsSection extends StatelessWidget {
  final List<(int, int)> gaps;
  final String Function(int) hhmm;
  final void Function((int, int)) onTap;

  const _GapsSection({
    required this.gaps,
    required this.hhmm,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            AppStrings.untrackedGaps,
            style: TextStyle(
              fontSize: 12,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 4),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: [
              for (final g in gaps)
                ActionChip(
                  label: Text(
                      '${hhmm(g.$1)}–${hhmm(g.$2)} · ${_formatDuration(g.$2 - g.$1)}'),
                  onPressed: () => onTap(g),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SubcategoryGroup extends StatelessWidget {
  final String subcategory;
  final List<Map<String, dynamic>> entries;

  const _SubcategoryGroup({
    required this.subcategory,
    required this.entries,
  });

  String _groupTotal() {
    final total =
        entries.fold(0, (sum, e) => sum + (e['duration_min'] as int));
    return _formatDuration(total);
  }

  @override
  Widget build(BuildContext context) {
    final color = AppColors.hexToColor(entries.first['category_color'] as String);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Group header
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 16, 4, 6),
          child: Row(
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  subcategory,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: color,
                  ),
                ),
              ),
              Text(
                _groupTotal(),
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: color,
                ),
              ),
            ],
          ),
        ),
        // Entry cards
        ...entries.map((e) => _EntryCard(entry: e, accentColor: color)),
      ],
    );
  }
}

class _EntryCard extends StatelessWidget {
  final Map<String, dynamic> entry;
  final Color accentColor;

  const _EntryCard({required this.entry, required this.accentColor});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final startTime = entry['start_time'] as String;
    final endTime = entry['end_time'] as String;
    final durationMin = entry['duration_min'] as int;
    final notes = entry['notes'] as String?;

    return Card(
      margin: const EdgeInsets.only(bottom: 6),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: colorScheme.outlineVariant),
      ),
      child: IntrinsicHeight(
        child: Row(
          children: [
            // Accent bar
            Container(
              width: 4,
              decoration: BoxDecoration(
                color: accentColor,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(10),
                  bottomLeft: Radius.circular(10),
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          '$startTime – $endTime',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: accentColor.withAlpha(30),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            _formatDuration(durationMin),
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: accentColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (notes != null && notes.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        notes,
                        style: TextStyle(
                          fontSize: 12,
                          color: colorScheme.onSurfaceVariant,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.hourglass_empty_rounded,
              size: 56, color: colorScheme.outlineVariant),
          const SizedBox(height: 12),
          Text(
            AppStrings.noEntries,
            style: TextStyle(
              fontSize: 15,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
