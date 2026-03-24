// Model: TimeEntry
// Represents a row in the `time_entries` table.

class TimeEntry {
  final int id;
  final int subcategoryId;
  final String date; // YYYY-MM-DD
  final String startTime; // HH:mm
  final String endTime; // HH:mm
  final int durationMin;
  final String? notes;
  final DateTime createdAt;

  TimeEntry({
    required this.id,
    required this.subcategoryId,
    required this.date,
    required this.startTime,
    required this.endTime,
    required this.durationMin,
    this.notes,
    required this.createdAt,
  });

  factory TimeEntry.fromMap(Map<String, dynamic> map) {
    return TimeEntry(
      id: map['id'] as int,
      subcategoryId: map['subcategory_id'] as int,
      date: map['date'] as String,
      startTime: map['start_time'] as String,
      endTime: map['end_time'] as String,
      durationMin: map['duration_min'] as int,
      notes: map['notes'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'subcategory_id': subcategoryId,
      'date': date,
      'start_time': startTime,
      'end_time': endTime,
      'duration_min': durationMin,
      'notes': notes,
      'created_at': createdAt.toIso8601String(),
    };
  }

  @override
  String toString() {
    return 'TimeEntry(id: $id, subcategoryId: $subcategoryId, date: $date, durationMin: $durationMin)';
  }
}
