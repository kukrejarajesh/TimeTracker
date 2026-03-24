// Model: Subcategory
// Represents a row in the `subcategories` table.

class Subcategory {
  final int id;
  final int categoryId;
  final String name;
  final bool isArchived;
  final DateTime createdAt;

  Subcategory({
    required this.id,
    required this.categoryId,
    required this.name,
    required this.isArchived,
    required this.createdAt,
  });

  /// Create a Subcategory from database row
  factory Subcategory.fromMap(Map<String, dynamic> map) {
    return Subcategory(
      id: map['id'] as int,
      categoryId: map['category_id'] as int,
      name: map['name'] as String,
      isArchived: (map['is_archived'] as int) == 1,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }

  /// Convert Subcategory to database row
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'category_id': categoryId,
      'name': name,
      'is_archived': isArchived ? 1 : 0,
      'created_at': createdAt.toIso8601String(),
    };
  }

  @override
  String toString() =>
      'Subcategory(id: $id, categoryId: $categoryId, name: $name, archived: $isArchived)';
}
