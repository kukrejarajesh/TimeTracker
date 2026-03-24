import 'package:sqflite/sqflite.dart';
import '../models/category.dart';
import 'db_helper.dart';

class CategoryRepository {
  final DBHelper _dbHelper = DBHelper();

  /// Create a new category
  /// Throws if a category with the same name already exists
  Future<int> createCategory({
    required String name,
    required String color,
  }) async {
    final db = await _dbHelper.getDatabase();
    final now = DateTime.now().toIso8601String();

    return await db.insert(
      DBHelper.tableCategories,
      {
        DBHelper.colCategoryName: name,
        DBHelper.colCategoryColor: color,
        DBHelper.colCategoryCreatedAt: now,
      },
    );
  }

  /// Get all categories ordered by name
  Future<List<Category>> getAllCategories() async {
    final db = await _dbHelper.getDatabase();

    final result = await db.query(
      DBHelper.tableCategories,
      orderBy: '${DBHelper.colCategoryName} ASC',
    );

    return result.map((map) => Category.fromMap(map)).toList();
  }

  /// Get category by id
  Future<Category?> getCategoryById(int id) async {
    final db = await _dbHelper.getDatabase();

    final result = await db.query(
      DBHelper.tableCategories,
      where: '${DBHelper.colCategoryId} = ?',
      whereArgs: [id],
    );

    if (result.isEmpty) return null;
    return Category.fromMap(result.first);
  }

  /// Get category by name
  Future<Category?> getCategoryByName(String name) async {
    final db = await _dbHelper.getDatabase();

    final result = await db.query(
      DBHelper.tableCategories,
      where: '${DBHelper.colCategoryName} = ?',
      whereArgs: [name],
    );

    if (result.isEmpty) return null;
    return Category.fromMap(result.first);
  }

  /// Update a category
  Future<int> updateCategory({
    required int id,
    required String name,
    required String color,
  }) async {
    final db = await _dbHelper.getDatabase();

    return await db.update(
      DBHelper.tableCategories,
      {
        DBHelper.colCategoryName: name,
        DBHelper.colCategoryColor: color,
      },
      where: '${DBHelper.colCategoryId} = ?',
      whereArgs: [id],
    );
  }

  /// Delete a category
  /// Throws if the category has any subcategories
  /// Returns true if deletion was successful, false if protected
  Future<bool> deleteCategory(int id) async {
    final db = await _dbHelper.getDatabase();

    // Check if category has any subcategories
    final subcategoryCount = Sqflite.firstIntValue(
      await db.rawQuery(
        'SELECT COUNT(*) FROM ${DBHelper.tableSubcategories} '
        'WHERE ${DBHelper.colSubcategoryCategoryId} = ?',
        [id],
      ),
    );

    if (subcategoryCount != null && subcategoryCount > 0) {
      // Category has subcategories, cannot delete
      return false;
    }

    // Safe to delete
    final deletedRows = await db.delete(
      DBHelper.tableCategories,
      where: '${DBHelper.colCategoryId} = ?',
      whereArgs: [id],
    );

    return deletedRows > 0;
  }

  /// Check if category can be deleted (has no subcategories)
  Future<bool> canDeleteCategory(int id) async {
    final db = await _dbHelper.getDatabase();

    final subcategoryCount = Sqflite.firstIntValue(
      await db.rawQuery(
        'SELECT COUNT(*) FROM ${DBHelper.tableSubcategories} '
        'WHERE ${DBHelper.colSubcategoryCategoryId} = ?',
        [id],
      ),
    );

    return subcategoryCount == null || subcategoryCount == 0;
  }
}
