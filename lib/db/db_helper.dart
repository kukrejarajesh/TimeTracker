import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../constants/seed_data.dart';

class DBHelper {
  static final DBHelper _instance = DBHelper._internal();
  static Database? _database;

  static const String dbName = 'timetracker.db';
  static const int dbVersion = 1;

  // Table names
  static const String tableCategories = 'categories';
  static const String tableSubcategories = 'subcategories';
  static const String tableTimeEntries = 'time_entries';

  // Column names - categories
  static const String colCategoryId = 'id';
  static const String colCategoryName = 'name';
  static const String colCategoryColor = 'color';
  static const String colCategoryCreatedAt = 'created_at';

  // Column names - subcategories
  static const String colSubcategoryId = 'id';
  static const String colSubcategoryName = 'name';
  static const String colSubcategoryCategoryId = 'category_id';
  static const String colSubcategoryIsArchived = 'is_archived';
  static const String colSubcategoryCreatedAt = 'created_at';

  // Column names - time_entries
  static const String colTimeEntryId = 'id';
  static const String colTimeEntrySubcategoryId = 'subcategory_id';
  static const String colTimeEntryDate = 'date';
  static const String colTimeEntryStartTime = 'start_time';
  static const String colTimeEntryEndTime = 'end_time';
  static const String colTimeEntryDurationMin = 'duration_min';
  static const String colTimeEntryNotes = 'notes';
  static const String colTimeEntryCreatedAt = 'created_at';

  factory DBHelper() {
    return _instance;
  }

  DBHelper._internal();

  /// Get the database instance, creating it if necessary
  Future<Database> getDatabase() async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  /// Initialize the database and create tables
  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, dbName);

    return await openDatabase(
      path,
      version: dbVersion,
      onCreate: (db, version) async {
        // Enable foreign key constraints
        await db.execute('PRAGMA foreign_keys = ON');

        // Create all tables
        await db.execute(_createCategoriesTable());
        await db.execute(_createSubcategoriesTable());
        await db.execute(_createTimeEntriesTable());

        // Seed with default data
        await _seedDatabase(db);
      },
      onOpen: (db) async {
        // Ensure foreign keys are enabled on every open
        await db.execute('PRAGMA foreign_keys = ON');
      },
    );
  }

  String _createCategoriesTable() {
    return '''
    CREATE TABLE IF NOT EXISTS $tableCategories (
      $colCategoryId INTEGER PRIMARY KEY AUTOINCREMENT,
      $colCategoryName TEXT UNIQUE NOT NULL,
      $colCategoryColor TEXT NOT NULL,
      $colCategoryCreatedAt TEXT NOT NULL
    )
    ''';
  }

  String _createSubcategoriesTable() {
    return '''
    CREATE TABLE IF NOT EXISTS $tableSubcategories (
      $colSubcategoryId INTEGER PRIMARY KEY AUTOINCREMENT,
      $colSubcategoryCategoryId INTEGER NOT NULL,
      $colSubcategoryName TEXT NOT NULL,
      $colSubcategoryIsArchived INTEGER NOT NULL DEFAULT 0,
      $colSubcategoryCreatedAt TEXT NOT NULL,
      FOREIGN KEY ($colSubcategoryCategoryId) 
        REFERENCES $tableCategories ($colCategoryId) 
        ON DELETE RESTRICT
    )
    ''';
  }

  String _createTimeEntriesTable() {
    return '''
    CREATE TABLE IF NOT EXISTS $tableTimeEntries (
      $colTimeEntryId INTEGER PRIMARY KEY AUTOINCREMENT,
      $colTimeEntrySubcategoryId INTEGER NOT NULL,
      $colTimeEntryDate TEXT NOT NULL,
      $colTimeEntryStartTime TEXT NOT NULL,
      $colTimeEntryEndTime TEXT NOT NULL,
      $colTimeEntryDurationMin INTEGER NOT NULL,
      $colTimeEntryNotes TEXT,
      $colTimeEntryCreatedAt TEXT NOT NULL,
      FOREIGN KEY ($colTimeEntrySubcategoryId) 
        REFERENCES $tableSubcategories ($colSubcategoryId) 
        ON DELETE RESTRICT
    )
    ''';
  }

  /// Seed the database with default categories and subcategories
  Future<void> _seedDatabase(Database db) async {
    final now = DateTime.now().toIso8601String();

    // Insert categories
    for (final category in SeedData.categories) {
      await db.insert(
        tableCategories,
        {
          colCategoryName: category['name'] as String,
          colCategoryColor: category['color'] as String,
          colCategoryCreatedAt: now,
        },
      );
    }

    // Insert subcategories
    // First, fetch all inserted categories to get their IDs
    final categoriesFromDb = await db.query(
      tableCategories,
      columns: [colCategoryId, colCategoryName],
    );

    final categoryIdMap = {
      for (final cat in categoriesFromDb)
        cat[colCategoryName] as String: cat[colCategoryId] as int
    };

    for (final subcategory in SeedData.subcategories) {
      final categoryName = subcategory['category_name'] as String;
      final categoryId = categoryIdMap[categoryName];

      if (categoryId != null) {
        await db.insert(
          tableSubcategories,
          {
            colSubcategoryCategoryId: categoryId,
            colSubcategoryName: subcategory['name'] as String,
            colSubcategoryIsArchived: 0,
            colSubcategoryCreatedAt: now,
          },
        );
      }
    }
  }

  /// Close the database connection
  Future<void> closeDatabase() async {
    if (_database != null) {
      await _database!.close();
      _database = null;
    }
  }
}
