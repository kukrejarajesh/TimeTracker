import '../models/time_entry.dart';
import 'db_helper.dart';

class TimeEntryRepository {
  final DBHelper _dbHelper = DBHelper();

  /// Create a new time entry
  Future<int> createTimeEntry({
    required int subcategoryId,
    required String date,
    required String startTime,
    required String endTime,
    required int durationMin,
    String? notes,
  }) async {
    final db = await _dbHelper.getDatabase();
    final now = DateTime.now().toIso8601String();

    return await db.insert(
      DBHelper.tableTimeEntries,
      {
        DBHelper.colTimeEntrySubcategoryId: subcategoryId,
        DBHelper.colTimeEntryDate: date,
        DBHelper.colTimeEntryStartTime: startTime,
        DBHelper.colTimeEntryEndTime: endTime,
        DBHelper.colTimeEntryDurationMin: durationMin,
        DBHelper.colTimeEntryNotes: notes,
        DBHelper.colTimeEntryCreatedAt: now,
      },
    );
  }

  /// Get a single entry by id
  Future<TimeEntry?> getTimeEntryById(int id) async {
    final db = await _dbHelper.getDatabase();

    final result = await db.query(
      DBHelper.tableTimeEntries,
      where: '${DBHelper.colTimeEntryId} = ?',
      whereArgs: [id],
    );

    if (result.isEmpty) return null;
    return TimeEntry.fromMap(result.first);
  }

  /// Update an existing entry
  Future<int> updateTimeEntry({
    required int id,
    required int subcategoryId,
    required String date,
    required String startTime,
    required String endTime,
    required int durationMin,
    String? notes,
  }) async {
    final db = await _dbHelper.getDatabase();

    return await db.update(
      DBHelper.tableTimeEntries,
      {
        DBHelper.colTimeEntrySubcategoryId: subcategoryId,
        DBHelper.colTimeEntryDate: date,
        DBHelper.colTimeEntryStartTime: startTime,
        DBHelper.colTimeEntryEndTime: endTime,
        DBHelper.colTimeEntryDurationMin: durationMin,
        DBHelper.colTimeEntryNotes: notes,
      },
      where: '${DBHelper.colTimeEntryId} = ?',
      whereArgs: [id],
    );
  }

  /// Delete a time entry
  Future<bool> deleteTimeEntry(int id) async {
    final db = await _dbHelper.getDatabase();
    final deleted = await db.delete(
      DBHelper.tableTimeEntries,
      where: '${DBHelper.colTimeEntryId} = ?',
      whereArgs: [id],
    );
    return deleted > 0;
  }

  /// Get all time entries for a given date (YYYY-MM-DD)
  Future<List<TimeEntry>> getEntriesForDate(String date) async {
    final db = await _dbHelper.getDatabase();

    final result = await db.query(
      DBHelper.tableTimeEntries,
      where: '${DBHelper.colTimeEntryDate} = ?',
      whereArgs: [date],
      orderBy: '${DBHelper.colTimeEntryStartTime} ASC',
    );

    return result.map((row) => TimeEntry.fromMap(row)).toList();
  }

  /// Get all entries joined with subcategory and category details, ordered by
  /// date and start_time ascending. Used for CSV export.
  Future<List<Map<String, dynamic>>> getAllEntriesWithDetails() async {
    final db = await _dbHelper.getDatabase();

    const sql = '''
      SELECT te.id,
             te.subcategory_id,
             s.name  AS subcategory_name,
             c.id    AS category_id,
             c.name  AS category_name,
             c.color AS category_color,
             te.date,
             te.start_time,
             te.end_time,
             te.duration_min,
             te.notes,
             te.created_at
      FROM time_entries te
      JOIN subcategories s ON te.subcategory_id = s.id
      JOIN categories    c ON s.category_id     = c.id
      ORDER BY te.date ASC, te.start_time ASC
    ''';

    final rows = await db.rawQuery(sql);
    return rows.map((r) => Map<String, dynamic>.from(r)).toList();
  }

  /// Get entries for a date joined with subcategory and category details.
  /// Each map contains: id, subcategory_id, subcategory_name, category_id,
  /// category_name, category_color, date, start_time, end_time,
  /// duration_min, notes, created_at.
  Future<List<Map<String, dynamic>>> getEntriesForDateWithDetails(
      String date) async {
    final db = await _dbHelper.getDatabase();

    final sql = '''
      SELECT te.id,
             te.subcategory_id,
             s.name  AS subcategory_name,
             c.id    AS category_id,
             c.name  AS category_name,
             c.color AS category_color,
             te.date,
             te.start_time,
             te.end_time,
             te.duration_min,
             te.notes,
             te.created_at
      FROM ${DBHelper.tableTimeEntries} te
      JOIN ${DBHelper.tableSubcategories} s ON te.subcategory_id = s.id
      JOIN ${DBHelper.tableCategories}    c ON s.category_id    = c.id
      WHERE te.date = ?
      ORDER BY te.start_time ASC
    ''';

    final rows = await db.rawQuery(sql, [date]);
    return rows.map((r) => Map<String, dynamic>.from(r)).toList();
  }

  /// Get total duration (min) grouped by subcategory for a date range (inclusive).
  /// Returns rows: {category_id, category_name, category_color,
  ///                subcategory_id, subcategory_name, total_duration_min}
  Future<List<Map<String, dynamic>>> getTotalDurationBySubcategoryForRange({
    required String startDate,
    required String endDate,
  }) async {
    final db = await _dbHelper.getDatabase();

    final sql = '''
      SELECT c.id   AS category_id,
             c.name AS category_name,
             c.color AS category_color,
             s.id   AS subcategory_id,
             s.name AS subcategory_name,
             SUM(te.${DBHelper.colTimeEntryDurationMin}) AS total_duration_min
      FROM ${DBHelper.tableTimeEntries} te
      JOIN ${DBHelper.tableSubcategories} s ON te.${DBHelper.colTimeEntrySubcategoryId} = s.${DBHelper.colSubcategoryId}
      JOIN ${DBHelper.tableCategories}    c ON s.${DBHelper.colSubcategoryCategoryId}   = c.${DBHelper.colCategoryId}
      WHERE te.${DBHelper.colTimeEntryDate} BETWEEN ? AND ?
      GROUP BY c.id, c.name, c.color, s.id, s.name
      ORDER BY c.name ASC, s.name ASC
    ''';

    final result = await db.rawQuery(sql, [startDate, endDate]);

    return result
        .map((row) => {
              'category_id': row['category_id'],
              'category_name': row['category_name'],
              'category_color': row['category_color'],
              'subcategory_id': row['subcategory_id'],
              'subcategory_name': row['subcategory_name'],
              'total_duration_min': row['total_duration_min'],
            })
        .toList();
  }

  /// Get total duration (min) grouped by category for a date range (inclusive)
  /// Returns list of maps: {category_id, category_name, total_duration_min}
  Future<List<Map<String, dynamic>>> getTotalDurationByCategoryForRange({
    required String startDate,
    required String endDate,
  }) async {
    final db = await _dbHelper.getDatabase();

    final sql = '''
      SELECT c.id AS category_id,
             c.name AS category_name,
             SUM(te.duration_min) AS total_duration_min
      FROM ${DBHelper.tableTimeEntries} te
      JOIN ${DBHelper.tableSubcategories} s ON te.${DBHelper.colTimeEntrySubcategoryId} = s.${DBHelper.colSubcategoryId}
      JOIN ${DBHelper.tableCategories} c ON s.${DBHelper.colSubcategoryCategoryId} = c.${DBHelper.colCategoryId}
      WHERE te.${DBHelper.colTimeEntryDate} BETWEEN ? AND ?
      GROUP BY c.id, c.name
      ORDER BY c.name ASC
    ''';

    final result = await db.rawQuery(sql, [startDate, endDate]);

    return result
        .map((row) => {
              'category_id': row['category_id'],
              'category_name': row['category_name'],
              'total_duration_min': row['total_duration_min'],
            })
        .toList();
  }
}
