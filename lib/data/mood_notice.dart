class MoodNotice {
  const MoodNotice({
    this.id,
    required this.title,
    required this.message,
    required this.createdAt,
  });

  final String? id;
  final String title;
  final String message;
  final DateTime createdAt;

  factory MoodNotice.fromRow(Map<String, dynamic> row) => MoodNotice(
    id: row['id'] as String,
    title: row['title'] as String,
    message: row['message'] as String,
    createdAt: DateTime.parse(row['created_at'] as String).toLocal(),
  );

  String get relativeDate {
    final today = DateTime.now();
    final date = createdAt;
    if (date.year == today.year &&
        date.month == today.month &&
        date.day == today.day) {
      return 'Today';
    }
    final yesterday = today.subtract(const Duration(days: 1));
    if (date.year == yesterday.year &&
        date.month == yesterday.month &&
        date.day == yesterday.day) {
      return 'Yesterday';
    }
    return const [
      'Mon',
      'Tue',
      'Wed',
      'Thu',
      'Fri',
      'Sat',
      'Sun',
    ][date.weekday - 1];
  }
}
