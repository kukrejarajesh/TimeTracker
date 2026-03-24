// ExportScreen
// Generate CSV export; save to phone Downloads folder.
// Filename format: timetracker_export_YYYYMMDD.csv
// CSV columns: date, category, subcategory, start_time, end_time, duration_min, notes

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

import '../constants/strings.dart';
import '../db/time_entry_repository.dart';

class ExportScreen extends StatefulWidget {
  const ExportScreen({super.key});

  @override
  State<ExportScreen> createState() => _ExportScreenState();
}

class _ExportScreenState extends State<ExportScreen> {
  final TimeEntryRepository _repo = TimeEntryRepository();

  bool _isExporting = false;
  String? _lastExportPath;
  String? _lastExportFile;

  // ── permission ─────────────────────────────────────────────────────────────

  /// Returns true when the app has sufficient permission to write to Downloads.
  /// On Android 11+ (API 30+) MANAGE_EXTERNAL_STORAGE is required for direct
  /// file-system access to /storage/emulated/0/Download/.
  Future<bool> _ensurePermission() async {
    // Already granted — fast path
    if (await Permission.manageExternalStorage.isGranted) return true;

    // Try the legacy storage permission first (granted automatically on API ≤ 28)
    final legacy = await Permission.storage.request();
    if (legacy.isGranted) return true;

    // On API 30+ request MANAGE_EXTERNAL_STORAGE (opens Settings on first ask)
    final manage = await Permission.manageExternalStorage.request();
    if (manage.isGranted) return true;

    // Permission permanently denied → tell the user to open Settings
    if (manage.isPermanentlyDenied || legacy.isPermanentlyDenied) {
      await openAppSettings();
    }
    return false;
  }

  // ── export logic ───────────────────────────────────────────────────────────

  Future<void> _export() async {
    setState(() {
      _isExporting = true;
      _lastExportPath = null;
      _lastExportFile = null;
    });

    try {
      final hasPermission = await _ensurePermission();
      if (!hasPermission) {
        _showSnack(AppStrings.exportPermDenied);
        return;
      }

      final entries = await _repo.getAllEntriesWithDetails();
      if (entries.isEmpty) {
        _showSnack(AppStrings.exportNoData);
        return;
      }

      // Build CSV content
      final buffer = StringBuffer();
      buffer.writeln(
          'date,category,subcategory,start_time,end_time,duration_min,notes');
      for (final e in entries) {
        final notes =
            (e['notes'] as String? ?? '').replaceAll('"', '""');
        buffer.writeln(
          '"${e['date']}","${e['category_name']}","${e['subcategory_name']}",'
          '"${e['start_time']}","${e['end_time']}",${e['duration_min']},"$notes"',
        );
      }

      // Build file path
      final now = DateTime.now();
      final stamp = '${now.year.toString().padLeft(4, '0')}'
          '${now.month.toString().padLeft(2, '0')}'
          '${now.day.toString().padLeft(2, '0')}';
      final fileName = 'timetracker_export_$stamp.csv';
      final downloadsPath = '/storage/emulated/0/Download';
      final filePath = '$downloadsPath/$fileName';

      final file = File(filePath);
      await file.writeAsString(buffer.toString(), flush: true);

      setState(() {
        _lastExportPath = filePath;
        _lastExportFile = fileName;
      });
      _showSnack('${AppStrings.exportSuccess}: $fileName');
    } catch (e) {
      _showSnack('${AppStrings.exportFailed}: $e');
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  // ── helpers ────────────────────────────────────────────────────────────────

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  // ── build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text(AppStrings.export)),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 16),
            Icon(
              Icons.file_download_outlined,
              size: 72,
              color: Theme.of(context).colorScheme.primary.withAlpha(180),
            ),
            const SizedBox(height: 24),
            Text(
              AppStrings.exportDescription,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 8),
            Text(
              AppStrings.exportCsvColumns,
              textAlign: TextAlign.center,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: Colors.grey[600]),
            ),
            const SizedBox(height: 32),
            FilledButton.icon(
              onPressed: _isExporting ? null : _export,
              icon: _isExporting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.download),
              label: Text(
                  _isExporting ? AppStrings.exporting : AppStrings.exportButton),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
            // ── Success banner ──
            if (_lastExportPath != null) ...[
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.green.shade200),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.check_circle,
                        color: Colors.green, size: 22),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _lastExportFile!,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _lastExportPath!,
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
