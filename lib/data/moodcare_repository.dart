import 'package:supabase_flutter/supabase_flutter.dart';

import 'mood_entry.dart';
import 'mood_notice.dart';
import 'moodcare_backend.dart';

class MoodCareRepository {
  const MoodCareRepository();

  bool get isSignedIn =>
      MoodCareBackend.configured &&
      MoodCareBackend.client.auth.currentUser != null;

  String get _userId {
    final userId = MoodCareBackend.client.auth.currentUser?.id;
    if (userId == null) {
      throw StateError('Sign in before saving personal wellbeing data.');
    }
    return userId;
  }

  Future<List<MoodEntry>> loadMoodEntries() async {
    final rows = await MoodCareBackend.client
        .from('mood_checkins')
        .select()
        .eq('user_id', _userId)
        .order('recorded_at')
        .limit(90);
    return rows.map(MoodEntry.fromRow).toList();
  }

  Future<void> saveMoodEntry(MoodEntry entry) async {
    await MoodCareBackend.client
        .from('mood_checkins')
        .insert(entry.toInsertRow(_userId));
  }

  Future<List<String>> loadJournalEntries() async {
    final rows = await MoodCareBackend.client
        .from('journal_entries')
        .select('content')
        .eq('user_id', _userId)
        .order('created_at', ascending: false)
        .limit(100);
    return rows.map((row) => row['content'] as String).toList();
  }

  Future<void> saveJournalEntry(String content) async {
    await MoodCareBackend.client.from('journal_entries').insert({
      'user_id': _userId,
      'content': content,
    });
  }

  Future<List<MoodNotice>> loadNotices() async {
    final rows = await MoodCareBackend.client
        .from('in_app_notices')
        .select()
        .eq('user_id', _userId)
        .order('created_at', ascending: false)
        .limit(50);
    return rows.map(MoodNotice.fromRow).toList();
  }

  Future<void> saveNotice({
    required String title,
    required String message,
  }) async {
    await MoodCareBackend.client.from('in_app_notices').insert({
      'user_id': _userId,
      'title': title,
      'message': message,
    });
  }

  Future<void> saveAssessment({
    required int score,
    required Map<int, int> responses,
  }) async {
    await MoodCareBackend.client.from('phq9_assessments').insert({
      'user_id': _userId,
      'total_score': score,
      'responses': List<int>.generate(9, (index) => responses[index] ?? 0),
    });
  }

  Future<Set<String>> loadTodayGoals() async {
    final rows = await MoodCareBackend.client
        .from('goal_completions')
        .select('goal_id')
        .eq('user_id', _userId)
        .eq('completed_on', _today);
    return rows.map((row) => row['goal_id'] as String).toSet();
  }

  Future<void> setGoalCompleted({
    required String goalId,
    required bool completed,
  }) async {
    final query = MoodCareBackend.client.from('goal_completions');
    if (completed) {
      await query.upsert({
        'user_id': _userId,
        'goal_id': goalId,
        'completed_on': _today,
      });
    } else {
      await query
          .delete()
          .eq('user_id', _userId)
          .eq('goal_id', goalId)
          .eq('completed_on', _today);
    }
  }

  Future<Map<String, dynamic>?> loadPreferences() async {
    return MoodCareBackend.client
        .from('notification_preferences')
        .select()
        .eq('user_id', _userId)
        .maybeSingle();
  }

  Future<void> savePreferences({
    required bool notificationsEnabled,
    required bool dailyReminderEnabled,
    required String reminderTime,
  }) async {
    await MoodCareBackend.client.from('notification_preferences').upsert({
      'user_id': _userId,
      'notifications_enabled': notificationsEnabled,
      'daily_reminder_enabled': dailyReminderEnabled,
      'reminder_time': reminderTime,
    });
  }

  Future<void> saveProfileName(String name) async {
    await MoodCareBackend.client.from('profiles').upsert({
      'id': _userId,
      'display_name': name,
    });
    await MoodCareBackend.client.auth.updateUser(
      UserAttributes(data: {'display_name': name}),
    );
  }

  String get _today => DateTime.now().toIso8601String().substring(0, 10);
}
