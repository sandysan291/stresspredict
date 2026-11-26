class MoodEntry {
  MoodEntry(
    this.day,
    this.score,
    this.label, {
    this.feelings = const [],
    this.note = '',
    this.recordedAt,
  });

  final String day;
  final int score;
  final String label;
  final List<String> feelings;
  final String note;
  final DateTime? recordedAt;

  factory MoodEntry.fromRow(Map<String, dynamic> row) {
    final recordedAt = DateTime.parse(row['recorded_at'] as String).toLocal();
    final score = row['mood_score'] as int;
    final feelings = (row['feelings'] as List<dynamic>? ?? const [])
        .cast<String>();

    return MoodEntry(
      _weekdayInitial(recordedAt),
      score,
      _labelForScore(score),
      feelings: feelings,
      note: row['note'] as String? ?? '',
      recordedAt: recordedAt,
    );
  }

  Map<String, dynamic> toInsertRow(String userId) => {
    'user_id': userId,
    'mood_score': score,
    'feelings': feelings,
    'note': note,
    'recorded_at': (recordedAt ?? DateTime.now()).toUtc().toIso8601String(),
  };

  static String _weekdayInitial(DateTime date) =>
      const ['M', 'T', 'W', 'T', 'F', 'S', 'S'][date.weekday - 1];

  static String _labelForScore(int score) => switch (score) {
    1 => 'Low',
    2 => 'A little off',
    3 => 'Okay',
    4 => 'Good',
    _ => 'Great',
  };
}
