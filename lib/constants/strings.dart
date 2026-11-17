// AppStrings
// All user-visible string labels used in the app.
// No hardcoded strings in UI — reference this class everywhere.

class AppStrings {
  AppStrings._();

  // Home screen
  static const String appName        = 'TimeTracker';
  static const String totalHours     = 'Total';
  static const String noEntries      = 'No entries for this day';
  static const String addEntry       = 'Add entry';

  // Common
  static const String today          = 'Today';
  static const String yesterday      = 'Yesterday';

  // Entry form
  static const String newEntry       = 'New Entry';
  static const String date           = 'Date';
  static const String subcategory    = 'Subcategory';
  static const String startTime      = 'Start time';
  static const String endTime        = 'End time';
  static const String duration       = 'Duration';
  static const String notes          = 'Notes (optional)';
  static const String save           = 'Save';
  static const String cancel         = 'Cancel';

  // Overlap / gaps
  static const String overlapTitle       = 'Overlaps existing entries';
  static const String saveAnyway         = 'Save anyway';
  static const String untracked          = 'Untracked';
  static const String untrackedGaps      = 'Untracked gaps (tap to fill)';

  // Subcategory merge / duplicates
  static const String mergeSubcategory   = 'Merge into…';
  static const String mergeTitle         = 'Merge subcategory';
  static const String duplicateTitle     = 'Similar subcategory exists';
  static const String createAnyway       = 'Create anyway';

  // Categories screen
  static const String categories        = 'Categories';
  static const String addCategory       = 'Add Category';
  static const String editCategory      = 'Edit Category';
  static const String deleteCategory    = 'Delete Category';
  static const String addSubcategory    = 'Add Subcategory';
  static const String editSubcategory   = 'Edit Subcategory';
  static const String deleteSubcategory = 'Delete Subcategory';
  static const String archiveSubcategory = 'Archive Subcategory';
  static const String categoryName      = 'Category name';
  static const String subcategoryName   = 'Subcategory name';
  static const String colorLabel        = 'Color';
  static const String noSubcategories   = 'No subcategories';

  // Reports screen
  static const String reports              = 'Reports';
  static const String daily                = 'Daily';
  static const String weekly               = 'Weekly';
  static const String total                = 'Total';
  static const String noEntriesForPeriod  = 'No entries for this period';

  // Export screen
  static const String export              = 'Export';
  static const String exportDescription   = 'Export all time entries as a CSV file to your Downloads folder.';
  static const String exportCsvColumns    = 'Columns: date, category, subcategory, start_time, end_time, duration_min, notes';
  static const String exportButton        = 'Export CSV';
  static const String exporting           = 'Exporting…';
  static const String exportPermDenied    = 'Storage permission denied. Please grant it in Settings.';
  static const String exportNoData        = 'No entries to export.';
  static const String exportFailed        = 'Export failed';
  static const String exportSuccess       = 'Saved to Downloads';
}
