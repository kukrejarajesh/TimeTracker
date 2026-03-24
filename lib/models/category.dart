// Model: Category
// Represents a row in the `categories` table.

class Category {
  final int id;
  final String name;
  final String color; // hex color string, e.g. #1D9E75
  final DateTime createdAt;

  Category({
    required this.id,
    required this.name,
    required this.color,
    required this.createdAt,
  });

  /// Create a Category from database row
  factory Category.fromMap(Map<String, dynamic> map) {
    return Category(
      id: map['id'] as int,
      name: map['name'] as String,
      color: map['color'] as String,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }

  /// Convert Category to database row
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'color': color,
      'created_at': createdAt.toIso8601String(),
    };
  }

  @override
  String toString() => 'Category(id: $id, name: $name, color: $color)';
}
