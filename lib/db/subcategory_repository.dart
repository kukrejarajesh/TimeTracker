import 'package:sqflite/sqflite.dart';
import '../models/subcategory.dart';
import '../constants/seed_data.dart';
import 'db_helper.dart';

class SubcategoryRepository {
  final DBHelper _dbHelper = DBHelper();

  /// Create a new subcategory
  Future<int> createSubcategory({
    required int categoryId,
    required String name,
  }) async {
    final db = await _dbHelper.getDatabase();
    final now = DateTime.now().toIso8601String();

    return await db.insert(
      DBHelper.tableSubcategories,
      {
        DBHelper.colSubcategoryCategoryId: categoryId,
        DBHelper.colSubcategoryName: name,
        DBHelper.colSubcategoryIsArchived: 0,
        DBHelper.colSubcategoryCreatedAt: now,
      },
    );
  }

  /// Get all active (non-archived) subcategories, optionally filtered by category
  Future<List<Subcategory>> getActiveSubcategories({int? categoryId}) async {
    final db = await _dbHelper.getDatabase();

    final whereArgs = categoryId == null ? [] : [categoryId];

    final result = await db.query(
      DBHelper.tableSubcategories,
      where: categoryId == null
          ? '${DBHelper.colSubcategoryIsArchived} = 0'
          : '${DBHelper.colSubcategoryCategoryId} = ? AND ${DBHelper.colSubcategoryIsArchived} = 0',
      whereArgs: whereArgs,
      orderBy: '${DBHelper.colSubcategoryName} ASC',
    );

    return result.map((map) => Subcategory.fromMap(map)).toList();
  }

  /// Get all subcategories (including archived), optionally filtered by category
  Future<List<Subcategory>> getAllSubcategories({int? categoryId}) async {
    final db = await _dbHelper.getDatabase();

    final result = await db.query(
      DBHelper.tableSubcategories,
      where: categoryId == null
          ? null
          : '${DBHelper.colSubcategoryCategoryId} = ?',
      whereArgs: categoryId == null ? [] : [categoryId],
      orderBy: '${DBHelper.colSubcategoryName} ASC',
    );

    return result.map((map) => Subcategory.fromMap(map)).toList();
  }

  /// Get subcategory by id
  Future<Subcategory?> getSubcategoryById(int id) async {
    final db = await _dbHelper.getDatabase();

    final result = await db.query(
      DBHelper.tableSubcategories,
      where: '${DBHelper.colSubcategoryId} = ?',
      whereArgs: [id],
    );

    if (result.isEmpty) return null;
    return Subcategory.fromMap(result.first);
  }

  /// Update a subcategory (name, category_id)
  Future<int> updateSubcategory({
    required int id,
    required int categoryId,
    required String name,
  }) async {
    final db = await _dbHelper.getDatabase();

    return await db.update(
      DBHelper.tableSubcategories,
      {
        DBHelper.colSubcategoryCategoryId: categoryId,
        DBHelper.colSubcategoryName: name,
      },
      where: '${DBHelper.colSubcategoryId} = ?',
      whereArgs: [id],
    );
  }

  /// Archive a subcategory (set is_archived = 1)
  /// Always succeeds for soft delete / archiving
  Future<int> archiveSubcategory(int id) async {
    final db = await _dbHelper.getDatabase();

    return await db.update(
      DBHelper.tableSubcategories,
      {DBHelper.colSubcategoryIsArchived: 1},
      where: '${DBHelper.colSubcategoryId} = ?',
      whereArgs: [id],
    );
  }

  /// Unarchive a subcategory (set is_archived = 0)
  Future<int> unarchiveSubcategory(int id) async {
    final db = await _dbHelper.getDatabase();

    return await db.update(
      DBHelper.tableSubcategories,
      {DBHelper.colSubcategoryIsArchived: 0},
      where: '${DBHelper.colSubcategoryId} = ?',
      whereArgs: [id],
    );
  }

  /// Delete a subcategory (hard delete)
  /// Returns false if the subcategory has time entries (cannot delete)
  /// Returns true if deletion was successful
  /// Only allow hard delete if the subcategory has zero time entries
  Future<bool> deleteSubcategory(int id) async {
    final db = await _dbHelper.getDatabase();

    // Check if subcategory has any time entries
    final timeEntryCount = Sqflite.firstIntValue(
      await db.rawQuery(
        'SELECT COUNT(*) FROM ${DBHelper.tableTimeEntries} '
        'WHERE ${DBHelper.colTimeEntrySubcategoryId} = ?',
        [id],
      ),
    );

    if (timeEntryCount != null && timeEntryCount > 0) {
      // Has time entries, cannot hard delete
      return false;
    }

    // Safe to hard delete
    final deletedRows = await db.delete(
      DBHelper.tableSubcategories,
      where: '${DBHelper.colSubcategoryId} = ?',
      whereArgs: [id],
    );

    return deletedRows > 0;
  }

  /// Check if subcategory can be hard-deleted (has no time entries)
  Future<bool> canDeleteSubcategory(int id) async {
    final db = await _dbHelper.getDatabase();

    final timeEntryCount = Sqflite.firstIntValue(
      await db.rawQuery(
        'SELECT COUNT(*) FROM ${DBHelper.tableTimeEntries} '
        'WHERE ${DBHelper.colTimeEntrySubcategoryId} = ?',
        [id],
      ),
    );

    return timeEntryCount == null || timeEntryCount == 0;
  }

  /// Load seed data: populate all default categories and subcategories
  /// Call this after the database is created if it's the first launch
  /// (DBHelper already calls this, but exposed here for manual resets if needed)
  Future<void> loadSeedData() async {
    final db = await _dbHelper.getDatabase();
    final now = DateTime.now().toIso8601String();

    // Insert all seed categories
    for (final category in SeedData.categories) {
      await db.insert(
        DBHelper.tableCategories,
        {
          DBHelper.colCategoryName: category['name'] as String,
          DBHelper.colCategoryColor: category['color'] as String,
          DBHelper.colCategoryCreatedAt: now,
        },
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
    }

    // Fetch all inserted categories to get their IDs
    final categoriesFromDb = await db.query(
      DBHelper.tableCategories,
      columns: [DBHelper.colCategoryId, DBHelper.colCategoryName],
    );

    final categoryIdMap = {
      for (final cat in categoriesFromDb)
        cat[DBHelper.colCategoryName] as String: cat[DBHelper.colCategoryId] as int
    };

    // Insert all seed subcategories
    for (final subcategory in SeedData.subcategories) {
      final categoryName = subcategory['category_name'] as String;
      final categoryId = categoryIdMap[categoryName];

      if (categoryId != null) {
        await db.insert(
          DBHelper.tableSubcategories,
          {
            DBHelper.colSubcategoryCategoryId: categoryId,
            DBHelper.colSubcategoryName: subcategory['name'] as String,
            DBHelper.colSubcategoryIsArchived: 0,
            DBHelper.colSubcategoryCreatedAt: now,
          },
          conflictAlgorithm: ConflictAlgorithm.ignore,
        );
      }
    }
  }
}
