import 'package:supabase_flutter/supabase_flutter.dart';

class MoodCareBackend {
  MoodCareBackend._();

  static const projectUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://midbconiifjjqphjgcuj.supabase.co',
  );
  static const _publishableKey = String.fromEnvironment(
    'SUPABASE_PUBLISHABLE_KEY',
    defaultValue: String.fromEnvironment('SUPABASE_ANON_KEY'),
  );
  static bool _initialized = false;

  static bool get configured => _initialized;

  static Future<void> initialize() async {
    if (_publishableKey.isEmpty) return;
    await Supabase.initialize(url: projectUrl, publishableKey: _publishableKey);
    _initialized = true;
  }

  static SupabaseClient get client {
    if (!_initialized) {
      throw StateError('Supabase has not been configured.');
    }
    return Supabase.instance.client;
  }
}
