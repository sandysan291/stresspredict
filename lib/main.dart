import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'data/mood_entry.dart';
import 'data/mood_notice.dart';
import 'data/moodcare_backend.dart';
import 'data/moodcare_repository.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await MoodCareBackend.initialize();
  runApp(const MoodCareApp());
}

const _ink = Color(0xFF28233C);
const _muted = Color(0xFF817D91);
const _purple = Color(0xFF7962C5);
const _lavender = Color(0xFFF0ECFA);
const _canvas = Color(0xFFF8F7FB);
const _line = Color(0xFFECE9F2);
const _green = Color(0xFF6D9A83);
const _peach = Color(0xFFFFEFE5);

enum AppPage {
  welcome,
  login,
  signup,
  home,
  checkIn,
  assessment,
  assessmentResult,
  plan,
  mindfulness,
  tracker,
  progress,
  learn,
  profile,
  settings,
  notifications,
  notificationHistory,
  goals,
  journal,
  activation,
  thoughts,
  sleep,
  support,
}

final _moodCareTheme = ThemeData(
  useMaterial3: true,
  scaffoldBackgroundColor: _canvas,
  colorScheme: ColorScheme.fromSeed(
    seedColor: _purple,
    primary: _purple,
    surface: Colors.white,
  ),
  fontFamily: 'Roboto',
  textTheme: const TextTheme(
    headlineMedium: TextStyle(
      color: _ink,
      fontWeight: FontWeight.w700,
      letterSpacing: -0.8,
    ),
    headlineSmall: TextStyle(
      color: _ink,
      fontWeight: FontWeight.w700,
      letterSpacing: -0.5,
    ),
    titleLarge: TextStyle(color: _ink, fontWeight: FontWeight.w700),
    titleMedium: TextStyle(color: _ink, fontWeight: FontWeight.w600),
    bodyLarge: TextStyle(color: _ink, height: 1.5),
    bodyMedium: TextStyle(color: _muted, height: 1.5),
  ),
  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    fillColor: Colors.white,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.all(Radius.circular(16)),
      borderSide: BorderSide(color: _line),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.all(Radius.circular(16)),
      borderSide: BorderSide(color: _line),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.all(Radius.circular(16)),
      borderSide: BorderSide(color: _purple, width: 1.5),
    ),
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
  ),
);

class MoodCareApp extends StatelessWidget {
  const MoodCareApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MoodCare',
      debugShowCheckedModeBanner: false,
      theme: _moodCareTheme,
      home: const MoodCareShell(),
    );
  }
}

class MoodCareShell extends StatefulWidget {
  const MoodCareShell({super.key});

  @override
  State<MoodCareShell> createState() => _MoodCareShellState();
}

class _MoodCareShellState extends State<MoodCareShell> {
  AppPage _page = AppPage.welcome;
  final MoodCareRepository _repository = const MoodCareRepository();
  int _assessmentIndex = 0;
  int _assessmentScore = 0;
  int? _selectedMood;
  int _selectedAnswer = -1;
  final Map<int, int> _answers = {};
  final Set<String> _selectedFeelings = {};
  final Set<int> _completedGoals = {};
  final List<String> _journalEntries = [];
  final List<MoodNotice> _noticeEntries = [];
  final TextEditingController _checkInNoteController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _journalController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _thoughtController = TextEditingController();
  final TextEditingController _nameController = TextEditingController(
    text: 'Alex',
  );
  final List<MoodEntry> _moodEntries = [
    MoodEntry('M', 3, 'Okay'),
    MoodEntry('T', 4, 'Good'),
    MoodEntry('W', 2, 'Low'),
    MoodEntry('T', 3, 'Okay'),
    MoodEntry('F', 4, 'Good'),
    MoodEntry('S', 3, 'Okay'),
    MoodEntry('S', 4, 'Good'),
  ];
  bool _notificationsEnabled = true;
  bool _gentleReminder = true;
  int _mindfulnessSeconds = 60;
  bool _isBreathing = false;
  bool _isSubmittingAuth = false;
  bool _cloudSyncing = false;
  Timer? _breathingTimer;
  TimeOfDay _reminderTime = const TimeOfDay(hour: 9, minute: 0);

  static const _questions = [
    'Little interest or pleasure in doing things',
    'Feeling down, depressed, or hopeless',
    'Trouble falling or staying asleep, or sleeping too much',
    'Feeling tired or having little energy',
    'Poor appetite or overeating',
    'Feeling bad about yourself — or that you are a failure',
    'Trouble concentrating on things, such as reading or watching TV',
    'Moving or speaking so slowly that others could have noticed, or being unusually restless',
    'Thoughts that you would be better off dead, or of hurting yourself',
  ];

  static const _answerOptions = [
    'Not at all',
    'Several days',
    'More than half the days',
    'Nearly every day',
  ];

  @override
  void initState() {
    super.initState();
    if (_repository.isSignedIn) {
      _page = AppPage.home;
      unawaited(_loadAccountData());
    }
  }

  @override
  void dispose() {
    _breathingTimer?.cancel();
    _checkInNoteController.dispose();
    _emailController.dispose();
    _journalController.dispose();
    _passwordController.dispose();
    _thoughtController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  void _go(AppPage page) {
    setState(() {
      _page = page;
    });
  }

  void _back() {
    setState(() {
      if (_page == AppPage.assessmentResult) {
        _page = AppPage.home;
      } else if (_page == AppPage.assessment) {
        _page = AppPage.home;
      } else {
        _page = _page == AppPage.login || _page == AppPage.signup
            ? AppPage.welcome
            : AppPage.home;
      }
    });
  }

  Future<void> _signIn() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    if (email.isEmpty || password.isEmpty) {
      _showMessage('Enter your email and password to continue.');
      return;
    }
    if (!MoodCareBackend.configured) {
      _showMessage(
        'Supabase is not configured. You can continue in demo mode.',
      );
      return;
    }

    setState(() => _isSubmittingAuth = true);
    try {
      await MoodCareBackend.client.auth.signInWithPassword(
        email: email,
        password: password,
      );
      _passwordController.clear();
      await _loadAccountData();
      if (mounted) _go(AppPage.home);
    } on AuthException catch (error) {
      _showMessage(error.message);
    } catch (error) {
      _showMessage('Could not sign in: $error');
    } finally {
      if (mounted) setState(() => _isSubmittingAuth = false);
    }
  }

  void _continueInDemo() {
    _passwordController.clear();
    _go(AppPage.home);
    _showMessage('Demo mode: your data stays in memory on this device.');
  }

  Future<void> _createAccount() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    final name = _nameController.text.trim();
    if (name.isEmpty || email.isEmpty || password.length < 8) {
      _showMessage(
        'Add your name, email, and a password of at least 8 characters.',
      );
      return;
    }
    if (!MoodCareBackend.configured) {
      _showMessage(
        'Supabase is not configured. You can continue in demo mode.',
      );
      return;
    }

    setState(() => _isSubmittingAuth = true);
    try {
      final response = await MoodCareBackend.client.auth.signUp(
        email: email,
        password: password,
        data: {'display_name': name},
      );
      _passwordController.clear();
      if (response.session == null) {
        _showMessage('Check your email to confirm your account, then sign in.');
        return;
      }
      await _loadAccountData();
      if (mounted) _go(AppPage.home);
    } on AuthException catch (error) {
      _showMessage(error.message);
    } catch (error) {
      _showMessage('Could not create your account: $error');
    } finally {
      if (mounted) setState(() => _isSubmittingAuth = false);
    }
  }

  Future<void> _loadAccountData() async {
    if (!_repository.isSignedIn) return;
    setState(() => _cloudSyncing = true);
    try {
      final moods = await _repository.loadMoodEntries();
      final journal = await _repository.loadJournalEntries();
      final notices = await _repository.loadNotices();
      final goals = await _repository.loadTodayGoals();
      final preferences = await _repository.loadPreferences();
      final userId = MoodCareBackend.client.auth.currentUser!.id;
      final profile = await MoodCareBackend.client
          .from('profiles')
          .select('display_name')
          .eq('id', userId)
          .maybeSingle();

      if (!mounted) return;
      setState(() {
        _moodEntries
          ..clear()
          ..addAll(moods);
        _journalEntries
          ..clear()
          ..addAll(journal);
        _noticeEntries
          ..clear()
          ..addAll(notices);
        _completedGoals
          ..clear()
          ..addAll(goals.map(_goalIndex).whereType<int>());
        final displayName = profile?['display_name'] as String?;
        if (displayName != null && displayName.isNotEmpty) {
          _nameController.text = displayName;
        }
        if (preferences != null) {
          _notificationsEnabled =
              preferences['notifications_enabled'] as bool? ?? true;
          _gentleReminder =
              preferences['daily_reminder_enabled'] as bool? ?? true;
          _reminderTime = _parseStoredTime(
            preferences['reminder_time'] as String?,
          );
        }
      });
    } catch (error) {
      _showMessage(
        'Your account is signed in, but data could not sync: $error',
      );
    } finally {
      if (mounted) setState(() => _cloudSyncing = false);
    }
  }

  int? _goalIndex(String goalId) {
    final parts = goalId.split('_');
    if (parts.length != 2) return null;
    final index = int.tryParse(parts[1]);
    if (index == null) return null;
    return switch (parts[0]) {
      'activation' => index,
      'daily' => index + 10,
      _ => null,
    };
  }

  String _goalId(int index) =>
      index >= 10 ? 'daily_${index - 10}' : 'activation_$index';

  TimeOfDay _parseStoredTime(String? value) {
    if (value == null) return _reminderTime;
    final parts = value.split(':');
    if (parts.length != 2) return _reminderTime;
    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null ||
        minute == null ||
        hour < 0 ||
        hour > 23 ||
        minute < 0 ||
        minute > 59) {
      return _reminderTime;
    }
    return TimeOfDay(hour: hour, minute: minute);
  }

  String _storedTime(TimeOfDay time) =>
      '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';

  Future<void> _savePreferences() async {
    if (!_repository.isSignedIn) return;
    try {
      await _repository.savePreferences(
        notificationsEnabled: _notificationsEnabled,
        dailyReminderEnabled: _gentleReminder,
        reminderTime: _storedTime(_reminderTime),
      );
    } catch (error) {
      _showMessage('Could not save your reminder preferences: $error');
    }
  }

  Future<void> _saveGoalCompletion(int index, bool completed) async {
    if (completed) {
      unawaited(
        _recordNotice(
          title: 'A small step taken',
          message: 'You made space for a meaningful activity.',
        ),
      );
    }
    if (!_repository.isSignedIn) return;
    try {
      await _repository.setGoalCompleted(
        goalId: _goalId(index),
        completed: completed,
      );
    } catch (error) {
      _showMessage('Could not save this goal: $error');
    }
  }

  Future<void> _saveMoodEntry(MoodEntry entry) async {
    if (!_repository.isSignedIn) return;
    try {
      await _repository.saveMoodEntry(entry);
    } catch (error) {
      _showMessage('Your check-in could not sync: $error');
    }
  }

  Future<void> _saveJournalEntry(String content) async {
    unawaited(
      _recordNotice(
        title: 'A reflection saved',
        message: 'You made a little space for your thoughts.',
      ),
    );
    if (!_repository.isSignedIn) return;
    try {
      await _repository.saveJournalEntry(content);
    } catch (error) {
      _showMessage('Your note could not sync: $error');
    }
  }

  Future<void> _saveProfileName(String name) async {
    if (!_repository.isSignedIn) return;
    try {
      await _repository.saveProfileName(name);
    } catch (error) {
      _showMessage('Your profile name could not sync: $error');
    }
  }

  Future<void> _recordNotice({
    required String title,
    required String message,
  }) async {
    final notice = MoodNotice(
      title: title,
      message: message,
      createdAt: DateTime.now(),
    );
    if (mounted) setState(() => _noticeEntries.insert(0, notice));
    if (!_repository.isSignedIn) return;
    try {
      await _repository.saveNotice(title: title, message: message);
    } catch (error) {
      _showMessage('This update could not sync: $error');
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  void _selectTab(int index) {
    const destinations = [
      AppPage.home,
      AppPage.tracker,
      AppPage.learn,
      AppPage.profile,
    ];
    _go(destinations[index]);
  }

  int get _tabIndex {
    switch (_page) {
      case AppPage.tracker:
      case AppPage.progress:
        return 1;
      case AppPage.learn:
      case AppPage.plan:
      case AppPage.mindfulness:
      case AppPage.activation:
      case AppPage.thoughts:
      case AppPage.sleep:
        return 2;
      case AppPage.profile:
      case AppPage.settings:
      case AppPage.notifications:
      case AppPage.notificationHistory:
      case AppPage.goals:
      case AppPage.journal:
      case AppPage.support:
        return 3;
      default:
        return 0;
    }
  }

  bool get _hasBottomNavigation => {
    AppPage.home,
    AppPage.tracker,
    AppPage.learn,
    AppPage.profile,
  }.contains(_page);

  String get _pageTitle {
    switch (_page) {
      case AppPage.login:
        return 'Welcome back';
      case AppPage.signup:
        return 'Create account';
      case AppPage.home:
        return 'MoodCare';
      case AppPage.checkIn:
        return 'Daily check-in';
      case AppPage.assessment:
        return 'Wellbeing check';
      case AppPage.assessmentResult:
        return 'Your check-in';
      case AppPage.plan:
        return 'Your care plan';
      case AppPage.mindfulness:
        return 'Mindful moment';
      case AppPage.tracker:
        return 'Mood tracker';
      case AppPage.progress:
        return 'Your progress';
      case AppPage.learn:
        return 'Explore tools';
      case AppPage.profile:
        return 'Your profile';
      case AppPage.settings:
        return 'Settings';
      case AppPage.notifications:
        return 'Reminders';
      case AppPage.notificationHistory:
        return 'Notifications';
      case AppPage.goals:
        return 'Your goals';
      case AppPage.journal:
        return 'Journal';
      case AppPage.activation:
        return 'Small steps';
      case AppPage.thoughts:
        return 'Thought check';
      case AppPage.sleep:
        return 'Rest & recharge';
      case AppPage.support:
        return 'Support';
      case AppPage.welcome:
        return 'MoodCare';
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 320),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      transitionBuilder: _pageTransition,
      child: _page == AppPage.welcome
          ? KeyedSubtree(
              key: const ValueKey('welcome'),
              child: _welcomeScreen(),
            )
          : KeyedSubtree(
              key: const ValueKey('application-shell'),
              child: _applicationShell(),
            ),
    );
  }

  Widget _applicationShell() {
    final wide = MediaQuery.sizeOf(context).width >= 900;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: _canvas,
        surfaceTintColor: _canvas,
        leading: _page == AppPage.home
            ? null
            : IconButton(
                tooltip: 'Go back',
                onPressed: _back,
                icon: const Icon(Icons.arrow_back_rounded),
              ),
        title: Text(
          _pageTitle,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: _ink,
          ),
        ),
        centerTitle: false,
        actions: [
          if (_page == AppPage.home)
            IconButton(
              tooltip: 'Notifications',
              onPressed: () => _go(AppPage.notificationHistory),
              icon: const Icon(Icons.notifications_none_rounded, color: _ink),
            ),
          if (_page == AppPage.home && _repository.isSignedIn)
            IconButton(
              tooltip: 'Refresh synced data',
              onPressed: _cloudSyncing
                  ? null
                  : () => unawaited(_loadAccountData()),
              icon: AnimatedSwitcher(
                duration: const Duration(milliseconds: 180),
                child: _cloudSyncing
                    ? const SizedBox(
                        key: ValueKey('syncing'),
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(
                        Icons.sync_rounded,
                        key: ValueKey('sync'),
                        color: _ink,
                      ),
              ),
            ),
          if (_page == AppPage.home)
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: InkWell(
                onTap: () => _go(AppPage.profile),
                customBorder: const CircleBorder(),
                child: const CircleAvatar(
                  radius: 17,
                  backgroundColor: _lavender,
                  child: Icon(Icons.person_rounded, color: _purple, size: 19),
                ),
              ),
            ),
        ],
      ),
      body: Row(
        children: [
          if (wide && _hasBottomNavigation)
            NavigationRail(
              selectedIndex: _tabIndex,
              onDestinationSelected: _selectTab,
              labelType: NavigationRailLabelType.all,
              backgroundColor: _canvas,
              indicatorColor: _lavender,
              destinations: const [
                NavigationRailDestination(
                  icon: Icon(Icons.home_outlined),
                  selectedIcon: Icon(Icons.home_rounded),
                  label: Text('Home'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.show_chart_rounded),
                  label: Text('Track'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.spa_outlined),
                  selectedIcon: Icon(Icons.spa_rounded),
                  label: Text('Tools'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.person_outline_rounded),
                  selectedIcon: Icon(Icons.person_rounded),
                  label: Text('Profile'),
                ),
              ],
            ),
          Expanded(
            child: Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1050),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 260),
                  switchInCurve: Curves.easeOutCubic,
                  switchOutCurve: Curves.easeInCubic,
                  transitionBuilder: _pageTransition,
                  child: KeyedSubtree(key: ValueKey(_page), child: _pageBody()),
                ),
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: !wide && _hasBottomNavigation
          ? NavigationBar(
              selectedIndex: _tabIndex,
              onDestinationSelected: _selectTab,
              backgroundColor: Colors.white,
              indicatorColor: _lavender,
              destinations: const [
                NavigationDestination(
                  icon: Icon(Icons.home_outlined),
                  selectedIcon: Icon(Icons.home_rounded),
                  label: 'Home',
                ),
                NavigationDestination(
                  icon: Icon(Icons.show_chart_rounded),
                  label: 'Track',
                ),
                NavigationDestination(
                  icon: Icon(Icons.spa_outlined),
                  selectedIcon: Icon(Icons.spa_rounded),
                  label: 'Tools',
                ),
                NavigationDestination(
                  icon: Icon(Icons.person_outline_rounded),
                  selectedIcon: Icon(Icons.person_rounded),
                  label: 'Profile',
                ),
              ],
            )
          : null,
    );
  }

  Widget _pageBody() {
    switch (_page) {
      case AppPage.login:
        return _loginPage();
      case AppPage.signup:
        return _signupPage();
      case AppPage.home:
        return _homePage();
      case AppPage.checkIn:
        return _checkInPage();
      case AppPage.assessment:
        return _assessmentPage();
      case AppPage.assessmentResult:
        return _assessmentResultPage();
      case AppPage.plan:
        return _planPage();
      case AppPage.mindfulness:
        return _mindfulnessPage();
      case AppPage.tracker:
        return _trackerPage();
      case AppPage.progress:
        return _progressPage();
      case AppPage.learn:
        return _learnPage();
      case AppPage.profile:
        return _profilePage();
      case AppPage.settings:
        return _settingsPage();
      case AppPage.notifications:
        return _remindersPage();
      case AppPage.notificationHistory:
        return _notificationHistoryPage();
      case AppPage.goals:
        return _goalsPage();
      case AppPage.journal:
        return _journalPage();
      case AppPage.activation:
        return _activationPage();
      case AppPage.thoughts:
        return _thoughtsPage();
      case AppPage.sleep:
        return _sleepPage();
      case AppPage.support:
        return _supportPage();
      case AppPage.welcome:
        return const SizedBox.shrink();
    }
  }

  Widget _pageTransition(Widget child, Animation<double> animation) {
    if (MediaQuery.disableAnimationsOf(context)) return child;
    final curved = CurvedAnimation(
      parent: animation,
      curve: Curves.easeOutCubic,
    );
    return FadeTransition(
      opacity: curved,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0.015, 0.02),
          end: Offset.zero,
        ).animate(curved),
        child: child,
      ),
    );
  }

  Widget _welcomeScreen() {
    return Scaffold(
      backgroundColor: _canvas,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 470),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: _lavender,
                      borderRadius: BorderRadius.circular(22),
                    ),
                    child: const Icon(
                      Icons.spa_rounded,
                      color: _purple,
                      size: 32,
                    ),
                  ),
                  const SizedBox(height: 32),
                  Text(
                    'A little more\nroom to feel.',
                    style: Theme.of(context).textTheme.headlineMedium
                        ?.copyWith(fontSize: 38, height: 1.12),
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'Gentle check-ins and thoughtful tools to help you care for your mental wellbeing, one day at a time.',
                    style: TextStyle(color: _muted, fontSize: 16, height: 1.6),
                  ),
                  const SizedBox(height: 28),
                  _welcomeIllustration(),
                  const SizedBox(height: 28),
                  _primaryButton(
                    label: 'Get started',
                    onPressed: () => _go(AppPage.home),
                  ),
                  const SizedBox(height: 12),
                  Center(
                    child: TextButton(
                      onPressed: () => _go(AppPage.login),
                      child: const Text('I already have an account'),
                    ),
                  ),
                  Center(
                    child: TextButton(
                      onPressed: () => _go(AppPage.signup),
                      child: const Text('Create an account'),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Center(
                    child: Text(
                      'Your journey is yours. Explore at your own pace.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: _muted, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _welcomeIllustration() {
    return Container(
      height: 190,
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFFECE7F8),
        borderRadius: BorderRadius.circular(28),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned(
            left: 36,
            top: 28,
            child: _bubble(Icons.cloud_outlined, 0xFFD8D0EE),
          ),
          Positioned(
            right: 42,
            top: 46,
            child: _bubble(Icons.auto_awesome_rounded, 0xFFFFF2DB),
          ),
          Positioned(
            bottom: 20,
            left: 66,
            child: _bubble(Icons.favorite_outline_rounded, 0xFFF9DDD9),
          ),
          Container(
            width: 122,
            height: 122,
            decoration: BoxDecoration(
              color: const Color(0xFFD7CDEF),
              borderRadius: BorderRadius.circular(44),
            ),
            child: const Icon(Icons.spa_rounded, color: _purple, size: 56),
          ),
        ],
      ),
    );
  }

  Widget _bubble(IconData icon, int color) {
    return Container(
      width: 46,
      height: 46,
      decoration: BoxDecoration(
        color: Color(color),
        borderRadius: BorderRadius.circular(17),
      ),
      child: Icon(icon, size: 22, color: _purple),
    );
  }

  Widget _loginPage() {
    return _scrollPage([
      const SizedBox(height: 16),
      const Text(
        'Sign in to your space',
        style: TextStyle(
          fontSize: 26,
          fontWeight: FontWeight.w700,
          color: _ink,
        ),
      ),
      const SizedBox(height: 8),
      Text(
        MoodCareBackend.configured
            ? 'Sign in to sync your private wellbeing data.'
            : 'Supabase is not configured. You can still explore in demo mode.',
        style: const TextStyle(color: _muted),
      ),
      if (MoodCareBackend.configured) ...[
        const SizedBox(height: 26),
        TextField(
          controller: _emailController,
          keyboardType: TextInputType.emailAddress,
          decoration: const InputDecoration(
            labelText: 'Email address',
            prefixIcon: Icon(Icons.mail_outline_rounded),
          ),
        ),
        const SizedBox(height: 14),
        TextField(
          controller: _passwordController,
          obscureText: true,
          decoration: const InputDecoration(
            labelText: 'Password',
            prefixIcon: Icon(Icons.lock_outline_rounded),
          ),
        ),
      ],
      const SizedBox(height: 22),
      _primaryButton(
        label: MoodCareBackend.configured
            ? _isSubmittingAuth
                  ? 'Signing in...'
                  : 'Sign in'
            : 'Continue in demo mode',
        onPressed: _isSubmittingAuth
            ? null
            : MoodCareBackend.configured
            ? _signIn
            : _continueInDemo,
      ),
      if (MoodCareBackend.configured) ...[
        const SizedBox(height: 14),
        const Center(
          child: Text(
            'You can also explore without an account from the welcome screen.',
            textAlign: TextAlign.center,
            style: TextStyle(color: _muted, fontSize: 12),
          ),
        ),
      ],
      const SizedBox(height: 12),
      Center(
        child: TextButton(
          onPressed: () => _go(AppPage.signup),
          child: const Text('New to MoodCare? Create an account'),
        ),
      ),
    ]);
  }

  Widget _signupPage() {
    return _scrollPage([
      const SizedBox(height: 16),
      const Text(
        'Make this space yours',
        style: TextStyle(
          fontSize: 26,
          fontWeight: FontWeight.w700,
          color: _ink,
        ),
      ),
      const SizedBox(height: 8),
      const Text(
        'Create a secure account to keep your check-ins and reflections in sync.',
        style: TextStyle(color: _muted),
      ),
      const SizedBox(height: 24),
      TextField(
        controller: _nameController,
        textCapitalization: TextCapitalization.words,
        decoration: const InputDecoration(
          labelText: 'Your name',
          prefixIcon: Icon(Icons.person_outline_rounded),
        ),
      ),
      if (MoodCareBackend.configured) ...[
        const SizedBox(height: 14),
        TextField(
          controller: _emailController,
          keyboardType: TextInputType.emailAddress,
          decoration: const InputDecoration(
            labelText: 'Email address',
            prefixIcon: Icon(Icons.mail_outline_rounded),
          ),
        ),
        const SizedBox(height: 14),
        TextField(
          controller: _passwordController,
          obscureText: true,
          decoration: const InputDecoration(
            labelText: 'Password',
            prefixIcon: Icon(Icons.lock_outline_rounded),
          ),
        ),
      ],
      const SizedBox(height: 22),
      _primaryButton(
        label: MoodCareBackend.configured
            ? _isSubmittingAuth
                  ? 'Creating account...'
                  : 'Create my profile'
            : 'Continue with demo profile',
        onPressed: _isSubmittingAuth
            ? null
            : MoodCareBackend.configured
            ? _createAccount
            : _continueInDemo,
      ),
      const SizedBox(height: 12),
      Center(
        child: Text(
          MoodCareBackend.configured
              ? 'Your account is protected by Supabase authentication.'
              : 'Supabase is not configured; this profile will be temporary.',
          textAlign: TextAlign.center,
          style: TextStyle(color: _muted, fontSize: 12),
        ),
      ),
    ]);
  }

  Widget _homePage() {
    final name = _nameController.text.trim().isEmpty
        ? 'friend'
        : _nameController.text.trim();
    return _scrollPage([
      const SizedBox(height: 4),
      Text(
        'Good morning, $name',
        style: const TextStyle(
          color: _ink,
          fontWeight: FontWeight.w700,
          fontSize: 25,
          letterSpacing: -0.5,
        ),
      ),
      const SizedBox(height: 4),
      const Text(
        'Take today one moment at a time.',
        style: TextStyle(color: _muted, fontSize: 14),
      ),
      const SizedBox(height: 12),
      _accountSyncStatus(),
      const SizedBox(height: 20),
      _dailyCheckinCard(),
      const SizedBox(height: 20),
      _sectionHeading(
        'Your week',
        trailing: 'See progress',
        onTap: () => _go(AppPage.progress),
      ),
      const SizedBox(height: 10),
      _weeklySummaryCard(),
      const SizedBox(height: 20),
      _sectionHeading('A gentle next step'),
      const SizedBox(height: 10),
      _planPreviewCard(),
      const SizedBox(height: 20),
      _sectionHeading(
        'Explore your tools',
        trailing: 'See all',
        onTap: () => _go(AppPage.learn),
      ),
      const SizedBox(height: 10),
      _toolCards(),
      const SizedBox(height: 20),
      _crisisBanner(),
      const SizedBox(height: 18),
    ]);
  }

  Widget _accountSyncStatus() {
    final signedIn = _repository.isSignedIn;
    final message = _cloudSyncing
        ? 'Syncing your private account...'
        : signedIn
        ? 'Your wellbeing data is synced to your account'
        : MoodCareBackend.configured
        ? 'Demo mode · sign in to sync your data'
        : 'Demo mode · data is temporary for this session';
    return _card(
      onTap: !signedIn && MoodCareBackend.configured
          ? () => _go(AppPage.login)
          : null,
      color: const Color(0xFFF0F4F1),
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
      child: Row(
        children: [
          Icon(
            _cloudSyncing
                ? Icons.sync_rounded
                : signedIn
                ? Icons.cloud_done_outlined
                : Icons.cloud_off_outlined,
            size: 18,
            color: _green,
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(color: _ink, fontSize: 11),
            ),
          ),
          if (!signedIn && MoodCareBackend.configured)
            const Icon(Icons.chevron_right_rounded, color: _muted, size: 18),
        ],
      ),
    );
  }

  Widget _dailyCheckinCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF7E69C8), Color(0xFF9A87D7)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.wb_sunny_outlined, color: Colors.white, size: 19),
              SizedBox(width: 8),
              Text(
                'YOUR DAILY MOMENT',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Text(
            'How are you feeling today?',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 5),
          const Text(
            'There is no right or wrong answer.',
            style: TextStyle(color: Color(0xFFEDE9FA), fontSize: 13),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _moodChoice(0, '😞', 'Low'),
              _moodChoice(1, '😕', 'Meh'),
              _moodChoice(2, '😐', 'Okay'),
              _moodChoice(3, '🙂', 'Good'),
              _moodChoice(4, '😄', 'Great'),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () => _go(AppPage.checkIn),
              style: FilledButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: _purple,
              ),
              child: const Text('Check in with yourself'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _moodChoice(int score, String emoji, String label) {
    return InkWell(
      onTap: () {
        setState(() => _selectedMood = score);
        _go(AppPage.checkIn);
      },
      borderRadius: BorderRadius.circular(14),
      child: AnimatedScale(
        scale: _selectedMood == score ? 1.12 : 1,
        duration: MediaQuery.disableAnimationsOf(context)
            ? Duration.zero
            : const Duration(milliseconds: 180),
        curve: Curves.easeOutBack,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          child: Column(
            children: [
              Text(emoji, style: const TextStyle(fontSize: 24)),
              const SizedBox(height: 4),
              Text(
                label,
                style: const TextStyle(color: Color(0xFFF1EDFC), fontSize: 10),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _weeklySummaryCard() {
    final average = _moodEntries.isEmpty
        ? 0.0
        : _moodEntries.map((entry) => entry.score).reduce((a, b) => a + b) /
              _moodEntries.length;
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'A little reflection adds up',
                  style: TextStyle(fontWeight: FontWeight.w700, color: _ink),
                ),
              ),
              Text(
                '${_moodEntries.length} days',
                style: const TextStyle(color: _muted, fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _moodChart(height: 92),
          const SizedBox(height: 12),
          if (_moodEntries.isEmpty)
            const Text(
              'Your first check-in is welcome whenever you are ready.',
              style: TextStyle(color: _muted, fontSize: 12),
            )
          else
            Row(
              children: [
                const Icon(Icons.favorite_rounded, color: _purple, size: 16),
                const SizedBox(width: 7),
                Text(
                  'Your average mood: ${average.toStringAsFixed(1)} / 5',
                  style: const TextStyle(
                    color: _muted,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _planPreviewCard() {
    return _card(
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: _lavender,
              borderRadius: BorderRadius.circular(17),
            ),
            child: const Icon(Icons.spa_rounded, color: _purple, size: 25),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Make space to pause',
                  style: TextStyle(fontWeight: FontWeight.w700, color: _ink),
                ),
                SizedBox(height: 4),
                Text(
                  'A 2-minute breathing practice',
                  style: TextStyle(color: _muted, fontSize: 12),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Open breathing practice',
            onPressed: () => _go(AppPage.mindfulness),
            icon: const Icon(Icons.arrow_forward_rounded, color: _purple),
          ),
        ],
      ),
    );
  }

  Widget _toolCards() {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        _smallTool(
          'Mindfulness',
          Icons.self_improvement_rounded,
          const Color(0xFFECE7F8),
          () => _go(AppPage.mindfulness),
        ),
        _smallTool(
          'Daily goals',
          Icons.flag_outlined,
          const Color(0xFFE7F1EC),
          () => _go(AppPage.goals),
        ),
        _smallTool(
          'Journal',
          Icons.edit_note_rounded,
          const Color(0xFFFFEFE5),
          () => _go(AppPage.journal),
        ),
        _smallTool(
          'Wellbeing check',
          Icons.favorite_border_rounded,
          const Color(0xFFFCE9EC),
          () => _startAssessment(),
        ),
      ],
    );
  }

  Widget _smallTool(
    String label,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return SizedBox(
      width: (MediaQuery.sizeOf(context).width - 58) / 2,
      child: _card(
        onTap: onTap,
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(13),
              ),
              child: Icon(icon, color: _purple, size: 20),
            ),
            const SizedBox(width: 10),
            Flexible(
              child: Text(
                label,
                style: const TextStyle(
                  color: _ink,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _checkInPage() {
    const moods = [
      ['😞', 'Low'],
      ['😕', 'A little off'],
      ['😐', 'Okay'],
      ['🙂', 'Good'],
      ['😄', 'Great'],
    ];
    const feelings = [
      'Calm',
      'Hopeful',
      'Anxious',
      'Tired',
      'Connected',
      'Overwhelmed',
      'Grateful',
      'Lonely',
    ];
    return _scrollPage([
      const SizedBox(height: 8),
      const Text(
        'Checking in is an act of care.',
        style: TextStyle(
          fontSize: 20,
          color: _ink,
          fontWeight: FontWeight.w700,
        ),
      ),
      const SizedBox(height: 5),
      const Text(
        'How has today been for you so far?',
        style: TextStyle(color: _muted),
      ),
      const SizedBox(height: 20),
      _card(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Choose what feels closest',
              style: TextStyle(color: _ink, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 14),
            ...List.generate(moods.length, (index) {
              final selected = _selectedMood == index;
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: InkWell(
                  onTap: () => setState(() => _selectedMood = index),
                  borderRadius: BorderRadius.circular(15),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 13,
                      vertical: 11,
                    ),
                    decoration: BoxDecoration(
                      color: selected ? _lavender : Colors.white,
                      borderRadius: BorderRadius.circular(15),
                      border: Border.all(color: selected ? _purple : _line),
                    ),
                    child: Row(
                      children: [
                        Text(
                          moods[index][0],
                          style: const TextStyle(fontSize: 22),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            moods[index][1],
                            style: const TextStyle(
                              color: _ink,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        if (selected)
                          const Icon(
                            Icons.check_circle,
                            color: _purple,
                            size: 20,
                          ),
                      ],
                    ),
                  ),
                ),
              );
            }),
            const SizedBox(height: 8),
            const Text(
              'Anything else you notice?',
              style: TextStyle(color: _ink, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            const Text(
              'Pick a few words, or leave this blank.',
              style: TextStyle(color: _muted, fontSize: 12),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: feelings.map((feeling) {
                final selected = _selectedFeelings.contains(feeling);
                return FilterChip(
                  label: Text(feeling),
                  selected: selected,
                  onSelected: (value) => setState(() {
                    if (value) {
                      _selectedFeelings.add(feeling);
                    } else {
                      _selectedFeelings.remove(feeling);
                    }
                  }),
                );
              }).toList(),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _checkInNoteController,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: 'Add a note for yourself (optional)',
                alignLabelWithHint: true,
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 16),
      _primaryButton(
        label: 'Save check-in',
        onPressed: _selectedMood == null
            ? null
            : () {
                final score = _selectedMood! + 1;
                final note = _checkInNoteController.text.trim();
                final entry = MoodEntry(
                  ['M', 'T', 'W', 'T', 'F', 'S', 'S'][DateTime.now().weekday -
                      1],
                  score,
                  moods[_selectedMood!][1],
                  feelings: _selectedFeelings.toList(),
                  note: note,
                  recordedAt: DateTime.now(),
                );
                setState(() {
                  _moodEntries.add(entry);
                  if (note.isNotEmpty) _journalEntries.insert(0, note);
                  _checkInNoteController.clear();
                  _selectedMood = null;
                  _selectedFeelings.clear();
                });
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Your check-in has been saved.'),
                  ),
                );
                unawaited(_saveMoodEntry(entry));
                if (note.isNotEmpty) unawaited(_saveJournalEntry(note));
                unawaited(
                  _recordNotice(
                    title: 'Check-in saved',
                    message: 'You took a moment to notice how you feel.',
                  ),
                );
                _go(AppPage.tracker);
              },
      ),
      const SizedBox(height: 12),
      Center(
        child: TextButton(
          onPressed: () => _startAssessment(),
          child: const Text('Want a more detailed check-in?'),
        ),
      ),
    ]);
  }

  void _startAssessment() {
    setState(() {
      _assessmentIndex = 0;
      _assessmentScore = 0;
      _selectedAnswer = -1;
      _answers.clear();
      _page = AppPage.assessment;
    });
  }

  Widget _assessmentPage() {
    final question = _questions[_assessmentIndex];
    return _scrollPage([
      const SizedBox(height: 8),
      _card(
        color: _lavender,
        child: const Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.info_outline_rounded, color: _purple),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'A gentle wellbeing screen, not a diagnosis. Your responses stay in this session.',
                style: TextStyle(color: _ink, fontSize: 13),
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 22),
      Row(
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: (_assessmentIndex + 1) / _questions.length,
                minHeight: 8,
                backgroundColor: _line,
                color: _purple,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            '${_assessmentIndex + 1} of ${_questions.length}',
            style: const TextStyle(color: _muted, fontSize: 12),
          ),
        ],
      ),
      const SizedBox(height: 24),
      const Text(
        'Over the last 2 weeks, how often have you been bothered by:',
        style: TextStyle(color: _muted, fontSize: 14),
      ),
      const SizedBox(height: 10),
      Text(
        question,
        style: const TextStyle(
          color: _ink,
          fontSize: 21,
          height: 1.35,
          fontWeight: FontWeight.w700,
        ),
      ),
      const SizedBox(height: 20),
      ...List.generate(_answerOptions.length, (index) {
        final selected = _selectedAnswer == index;
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: _card(
            onTap: () => setState(() => _selectedAnswer = index),
            color: selected ? _lavender : Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
            child: Row(
              children: [
                Icon(
                  selected
                      ? Icons.radio_button_checked_rounded
                      : Icons.radio_button_unchecked_rounded,
                  color: selected ? _purple : _muted,
                ),
                const SizedBox(width: 12),
                Text(
                  _answerOptions[index],
                  style: const TextStyle(
                    color: _ink,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        );
      }),
      const SizedBox(height: 12),
      _primaryButton(
        label: _assessmentIndex == _questions.length - 1
            ? 'See my reflection'
            : 'Continue',
        onPressed: _selectedAnswer < 0
            ? null
            : () async {
                setState(() {
                  _answers[_assessmentIndex] = _selectedAnswer;
                  _assessmentScore = _answers.values.fold(0, (a, b) => a + b);
                  if (_assessmentIndex < _questions.length - 1) {
                    _assessmentIndex++;
                    _selectedAnswer = _answers[_assessmentIndex] ?? -1;
                  } else {
                    _page = AppPage.assessmentResult;
                  }
                });
                if (_assessmentIndex == _questions.length - 1 &&
                    _repository.isSignedIn) {
                  try {
                    await _repository.saveAssessment(
                      score: _assessmentScore,
                      responses: _answers,
                    );
                  } catch (error) {
                    _showMessage(
                      'Your screening result could not sync: $error',
                    );
                  }
                }
                if (_assessmentIndex == _questions.length - 1) {
                  unawaited(
                    _recordNotice(
                      title: 'Wellbeing check complete',
                      message: 'You made space to reflect on how the past two weeks have felt.',
                    ),
                  );
                }
              },
      ),
      if (_assessmentIndex > 0)
        Center(
          child: TextButton(
            onPressed: () => setState(() {
              _assessmentIndex--;
              _selectedAnswer = _answers[_assessmentIndex] ?? -1;
            }),
            child: const Text('Previous question'),
          ),
        ),
      const SizedBox(height: 12),
      const Text(
        'You can stop at any time. Your answers are private to this session.',
        textAlign: TextAlign.center,
        style: TextStyle(color: _muted, fontSize: 12),
      ),
    ]);
  }

  Widget _assessmentResultPage() {
    final score = _assessmentScore;
    final label = score < 5
        ? 'Low range'
        : score < 10
        ? 'Mild range'
        : score < 15
        ? 'Moderate range'
        : score < 20
        ? 'Moderately high range'
        : 'High range';
    final needsSupport = score >= 10;
    final responseToSafetyQuestion = (_answers[8] ?? 0) > 0;
    return _scrollPage([
      const SizedBox(height: 8),
      _card(
        color: _lavender,
        child: Column(
          children: [
            const Icon(Icons.favorite_rounded, color: _purple, size: 35),
            const SizedBox(height: 10),
            Text(
              '$score / 27',
              style: const TextStyle(
                color: _ink,
                fontSize: 31,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              label,
              style: const TextStyle(
                color: _purple,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'This questionnaire is a screening tool, not a diagnosis. Only a qualified professional can assess your mental health.',
              textAlign: TextAlign.center,
              style: TextStyle(color: _muted, fontSize: 12, height: 1.5),
            ),
          ],
        ),
      ),
      const SizedBox(height: 18),
      Text(
        needsSupport
            ? 'Thank you for checking in with yourself.'
            : 'Thank you for making space to check in.',
        style: const TextStyle(
          color: _ink,
          fontSize: 19,
          fontWeight: FontWeight.w700,
        ),
      ),
      const SizedBox(height: 8),
      Text(
        needsSupport
            ? 'Your answers suggest you may be going through a harder time. You deserve support, and talking with a trusted person or health professional could be a helpful next step.'
            : 'Your answers point to fewer concerns right now. Keep noticing how you feel, and reach out for support whenever you need it.',
        style: const TextStyle(color: _muted, height: 1.6),
      ),
      if (responseToSafetyQuestion) ...[
        const SizedBox(height: 16),
        _crisisBanner(
          title: 'You deserve immediate support',
          description: 'If you might hurt yourself or are in immediate danger, contact your local emergency service now. In the U.S. or Canada, call or text 988.',
        ),
      ],
      const SizedBox(height: 18),
      _primaryButton(
        label: 'See my support plan',
        onPressed: () => _go(AppPage.plan),
      ),
      const SizedBox(height: 8),
      Center(
        child: TextButton(
          onPressed: () => _go(AppPage.home),
          child: const Text('Back to home'),
        ),
      ),
      const SizedBox(height: 6),
      _crisisBanner(),
    ]);
  }

  Widget _planPage() {
    return _scrollPage([
      const SizedBox(height: 6),
      const Text(
        'A plan that starts small.',
        style: TextStyle(
          color: _ink,
          fontSize: 22,
          fontWeight: FontWeight.w700,
        ),
      ),
      const SizedBox(height: 5),
      const Text(
        'Choose what feels manageable today. You can change your mind at any time.',
        style: TextStyle(color: _muted),
      ),
      const SizedBox(height: 18),
      _planAction(
        '01',
        'Pause and breathe',
        'Try a short grounding exercise.',
        Icons.air_rounded,
        () => _go(AppPage.mindfulness),
      ),
      const SizedBox(height: 10),
      _planAction(
        '02',
        'Do one small thing',
        'Pick an activity that matters to you.',
        Icons.directions_walk_rounded,
        () => _go(AppPage.activation),
      ),
      const SizedBox(height: 10),
      _planAction(
        '03',
        'Notice your thoughts',
        'Explore a kinder perspective.',
        Icons.lightbulb_outline_rounded,
        () => _go(AppPage.thoughts),
      ),
      const SizedBox(height: 18),
      _crisisBanner(),
    ]);
  }

  Widget _planAction(
    String number,
    String title,
    String subtitle,
    IconData icon,
    VoidCallback onTap,
  ) {
    return _card(
      onTap: onTap,
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: _lavender,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, color: _purple),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$number  ·  $title',
                  style: const TextStyle(
                    color: _ink,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: const TextStyle(color: _muted, fontSize: 12),
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded, color: _muted),
        ],
      ),
    );
  }

  Widget _mindfulnessPage() {
    return _scrollPage([
      const SizedBox(height: 8),
      _card(
        color: const Color(0xFFECE7F8),
        child: Column(
          children: [
            const SizedBox(height: 12),
            _BreathingOrb(
              isActive: _isBreathing,
              child: Container(
                width: 180,
                height: 180,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.7),
                  border: Border.all(color: const Color(0xFFD8D0EE), width: 8),
                ),
                alignment: Alignment.center,
                child: Text(
                  _isBreathing
                      ? '$_mindfulnessSeconds\nseconds'
                      : _mindfulnessSeconds == 0
                      ? 'You made\nspace'
                      : 'A little\npause',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: _purple,
                    fontSize: 23,
                    height: 1.25,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              'A moment just for you',
              style: TextStyle(
                color: _ink,
                fontSize: 21,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 7),
            const Text(
              'Breathe in slowly for four counts, then breathe out gently for six.',
              textAlign: TextAlign.center,
              style: TextStyle(color: _muted),
            ),
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: _isBreathing ? null : _startBreathing,
              icon: const Icon(Icons.play_arrow_rounded),
              label: Text(
                _isBreathing
                    ? 'Practice in progress'
                    : _mindfulnessSeconds == 0
                    ? 'Begin again'
                    : 'Begin 1-minute practice',
              ),
              style: FilledButton.styleFrom(backgroundColor: _purple),
            ),
          ],
        ),
      ),
      const SizedBox(height: 16),
      _card(
        child: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Try this grounding pause',
              style: TextStyle(color: _ink, fontWeight: FontWeight.w700),
            ),
            SizedBox(height: 8),
            Text(
              'Notice 5 things you see, 4 things you feel, 3 things you hear, 2 things you smell, and 1 thing you taste.',
              style: TextStyle(color: _muted),
            ),
          ],
        ),
      ),
    ]);
  }

  void _startBreathing() {
    _breathingTimer?.cancel();
    setState(() {
      _mindfulnessSeconds = 60;
      _isBreathing = true;
    });
    _breathingTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted || _mindfulnessSeconds <= 1) {
        timer.cancel();
        if (mounted) {
          setState(() {
            _mindfulnessSeconds = 0;
            _isBreathing = false;
          });
        }
      } else {
        setState(() => _mindfulnessSeconds--);
      }
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Your breathing practice has started.')),
    );
  }

  Widget _trackerPage() {
    return _scrollPage([
      const SizedBox(height: 8),
      const Text(
        'Your feelings can change, and that is okay.',
        style: TextStyle(
          color: _ink,
          fontSize: 20,
          fontWeight: FontWeight.w700,
        ),
      ),
      const SizedBox(height: 5),
      const Text(
        'A kind look back at the past week.',
        style: TextStyle(color: _muted),
      ),
      const SizedBox(height: 16),
      _card(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'This week',
              style: TextStyle(color: _ink, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 18),
            if (_moodEntries.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 40),
                child: Text(
                  'Your mood history will appear here after your first check-in.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: _muted, fontSize: 13),
                ),
              )
            else
              _moodChart(height: 170, showLabels: true),
            const SizedBox(height: 14),
            const Text(
              'Patterns can offer clues, not conclusions. There is no “good” or “bad” mood.',
              style: TextStyle(color: _muted, fontSize: 12),
            ),
          ],
        ),
      ),
      const SizedBox(height: 16),
      _sectionHeading('Recent check-ins'),
      const SizedBox(height: 10),
      if (_moodEntries.isEmpty)
        _card(
          child: const Text(
            'No check-ins yet. You can add one whenever you feel ready.',
            style: TextStyle(color: _muted),
          ),
        )
      else
        ..._moodEntries.reversed
            .take(7)
            .map(
              (entry) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _card(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 15,
                    vertical: 12,
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 18,
                        backgroundColor: _lavender,
                        child: Text(
                          entry.score >= 4
                              ? '🙂'
                              : entry.score == 3
                              ? '😐'
                              : '😕',
                          style: const TextStyle(fontSize: 17),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              entry.label,
                              style: const TextStyle(
                                color: _ink,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            if (entry.feelings.isNotEmpty)
                              Text(
                                entry.feelings.join(' · '),
                                style: const TextStyle(
                                  color: _muted,
                                  fontSize: 11,
                                ),
                              ),
                            if (entry.note.isNotEmpty)
                              Text(
                                entry.note,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: _muted,
                                  fontSize: 11,
                                ),
                              ),
                          ],
                        ),
                      ),
                      Text(
                        entry.day,
                        style: const TextStyle(color: _muted, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ),
            ),
      const SizedBox(height: 12),
      _secondaryButton('Add a check-in', () => _go(AppPage.checkIn)),
      const SizedBox(height: 14),
    ]);
  }

  Widget _moodChart({required double height, bool showLabels = false}) {
    final entries = _moodEntries.length <= 7
        ? _moodEntries
        : _moodEntries.sublist(_moodEntries.length - 7);
    return SizedBox(
      height: height,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: entries.map((entry) {
          final barHeight = (entry.score / 5) * (height - 28);
          return Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (showLabels)
                  Text(
                    entry.score >= 4
                        ? '🙂'
                        : entry.score == 3
                        ? '😐'
                        : '😕',
                    style: const TextStyle(fontSize: 14),
                  ),
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: barHeight),
                  duration: MediaQuery.disableAnimationsOf(context)
                      ? Duration.zero
                      : const Duration(milliseconds: 560),
                  curve: Curves.easeOutCubic,
                  builder: (context, animatedHeight, child) => Container(
                    margin: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 5,
                    ),
                    height: animatedHeight,
                    decoration: BoxDecoration(
                      color: entry.score >= 4
                          ? const Color(0xFFA8C6B3)
                          : const Color(0xFFC9BDE8),
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                Text(
                  entry.day,
                  style: const TextStyle(color: _muted, fontSize: 11),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _progressPage() {
    return _scrollPage([
      const SizedBox(height: 8),
      const Text(
        'Progress is personal.',
        style: TextStyle(
          color: _ink,
          fontSize: 21,
          fontWeight: FontWeight.w700,
        ),
      ),
      const SizedBox(height: 5),
      const Text(
        'Notice the small things you are doing for yourself.',
        style: TextStyle(color: _muted),
      ),
      const SizedBox(height: 16),
      _weeklySummaryCard(),
      const SizedBox(height: 12),
      Row(
        children: [
          Expanded(
            child: _statCard(
              '${_moodEntries.length}',
              'check-ins',
              Icons.favorite_border_rounded,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _statCard(
              '${_completedGoals.length}',
              'goals tried',
              Icons.flag_outlined,
            ),
          ),
        ],
      ),
      const SizedBox(height: 18),
      _sectionHeading('Your reflections'),
      const SizedBox(height: 10),
      _linkCard(
        'Mood history',
        'See your recent check-ins',
        Icons.calendar_month_rounded,
        () => _go(AppPage.tracker),
      ),
      const SizedBox(height: 9),
      _linkCard(
        'Journal entries',
        '${_journalEntries.length} moments saved',
        Icons.menu_book_rounded,
        () => _go(AppPage.journal),
      ),
      const SizedBox(height: 9),
      _linkCard(
        'Daily goals',
        'Celebrate what you have tried',
        Icons.flag_outlined,
        () => _go(AppPage.goals),
      ),
    ]);
  }

  Widget _statCard(String value, String label, IconData icon) {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: _purple, size: 20),
          const SizedBox(height: 10),
          Text(
            value,
            style: const TextStyle(
              color: _ink,
              fontSize: 24,
              fontWeight: FontWeight.w700,
            ),
          ),
          Text(label, style: const TextStyle(color: _muted, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _learnPage() {
    final tools = [
      (
        'Mindfulness',
        'Find a little space to pause.',
        Icons.self_improvement_rounded,
        AppPage.mindfulness,
      ),
      (
        'Behavioral activation',
        'Make room for small meaningful activities.',
        Icons.directions_walk_rounded,
        AppPage.activation,
      ),
      (
        'Thought check',
        'Look at a difficult thought with curiosity.',
        Icons.lightbulb_outline_rounded,
        AppPage.thoughts,
      ),
      (
        'Sleep & energy',
        'Gentle ideas for rest and fatigue.',
        Icons.nightlight_outlined,
        AppPage.sleep,
      ),
      (
        'Personal plan',
        'Choose a few supportive next steps.',
        Icons.checklist_rounded,
        AppPage.plan,
      ),
      (
        'Wellbeing check',
        'A brief, non-diagnostic reflection.',
        Icons.favorite_border_rounded,
        AppPage.assessment,
      ),
    ];
    return _scrollPage([
      const SizedBox(height: 8),
      const Text(
        'Support, at your own pace.',
        style: TextStyle(
          color: _ink,
          fontSize: 21,
          fontWeight: FontWeight.w700,
        ),
      ),
      const SizedBox(height: 5),
      const Text(
        'Choose a tool that feels right for this moment.',
        style: TextStyle(color: _muted),
      ),
      const SizedBox(height: 16),
      ...tools.map(
        (tool) => Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: _linkCard(tool.$1, tool.$2, tool.$3, () {
            if (tool.$4 == AppPage.assessment) {
              _startAssessment();
            } else {
              _go(tool.$4);
            }
          }),
        ),
      ),
      const SizedBox(height: 8),
      _crisisBanner(),
    ]);
  }

  Widget _activationPage() {
    final activities = [
      ('Step outside for five minutes', Icons.nature_people_outlined),
      ('Send a kind message to someone', Icons.chat_bubble_outline_rounded),
      ('Make a drink and enjoy it slowly', Icons.local_cafe_outlined),
      (
        'Stretch or move in a way that feels okay',
        Icons.accessibility_new_rounded,
      ),
      (
        'Do one small thing you have been putting off',
        Icons.check_circle_outline_rounded,
      ),
    ];
    return _scrollPage([
      const SizedBox(height: 8),
      const Text(
        'Small steps count.',
        style: TextStyle(
          color: _ink,
          fontSize: 22,
          fontWeight: FontWeight.w700,
        ),
      ),
      const SizedBox(height: 6),
      const Text(
        'When energy is low, a tiny meaningful action can be a gentle place to begin. Choose only what feels doable.',
        style: TextStyle(color: _muted),
      ),
      const SizedBox(height: 16),
      ...activities.asMap().entries.map((item) {
        final done = _completedGoals.contains(item.key);
        return Padding(
          padding: const EdgeInsets.only(bottom: 9),
          child: _card(
            onTap: () {
              final completed = !done;
              setState(() {
                if (completed) {
                  _completedGoals.add(item.key);
                } else {
                  _completedGoals.remove(item.key);
                }
              });
              unawaited(_saveGoalCompletion(item.key, completed));
            },
            color: done ? const Color(0xFFE9F2ED) : Colors.white,
            child: Row(
              children: [
                Icon(item.value.$2, color: _purple),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    item.value.$1,
                    style: const TextStyle(color: _ink),
                  ),
                ),
                Icon(
                  done ? Icons.check_circle : Icons.circle_outlined,
                  color: done ? _green : _muted,
                ),
              ],
            ),
          ),
        );
      }),
      const SizedBox(height: 8),
      const Text(
        'You do not need to complete everything. Rest is a valid choice too.',
        textAlign: TextAlign.center,
        style: TextStyle(color: _muted, fontSize: 12),
      ),
    ]);
  }

  Widget _thoughtsPage() {
    return _scrollPage([
      const SizedBox(height: 8),
      const Text(
        'Meet a thought with curiosity.',
        style: TextStyle(
          color: _ink,
          fontSize: 21,
          fontWeight: FontWeight.w700,
        ),
      ),
      const SizedBox(height: 6),
      const Text(
        'This is not about forcing positivity. It is a chance to make room for another perspective.',
        style: TextStyle(color: _muted),
      ),
      const SizedBox(height: 16),
      _promptCard('1. What is the thought?', 'Write it down as it showed up.'),
      const SizedBox(height: 10),
      _promptCard(
        '2. What supports this thought?',
        'Notice the evidence without judging yourself.',
      ),
      const SizedBox(height: 10),
      _promptCard(
        '3. What might you say to a friend?',
        'Try a balanced, kinder perspective.',
      ),
      const SizedBox(height: 16),
      TextField(
        controller: _thoughtController,
        maxLines: 6,
        decoration: InputDecoration(
          hintText: 'Your reflections are for you...',
          alignLabelWithHint: true,
        ),
      ),
      const SizedBox(height: 14),
      _primaryButton(
        label: 'Save reflection',
        onPressed: () {
          final reflection = _thoughtController.text.trim();
          if (reflection.isEmpty) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Write a reflection before saving.'),
              ),
            );
            return;
          }
          setState(() {
            _journalEntries.insert(0, reflection);
            _thoughtController.clear();
          });
          unawaited(_saveJournalEntry(reflection));
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Your reflection has been saved.')),
          );
        },
      ),
    ]);
  }

  Widget _promptCard(String title, String subtitle) {
    return _card(
      child: Row(
        children: [
          const Icon(Icons.circle_outlined, color: _purple),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: _ink,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: const TextStyle(color: _muted, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _sleepPage() {
    return _scrollPage([
      const SizedBox(height: 8),
      const Text(
        'Rest looks different for everyone.',
        style: TextStyle(
          color: _ink,
          fontSize: 21,
          fontWeight: FontWeight.w700,
        ),
      ),
      const SizedBox(height: 6),
      const Text(
        'If sleep or energy has been difficult, you are not alone. Try one gentle idea, not a perfect routine.',
        style: TextStyle(color: _muted),
      ),
      const SizedBox(height: 16),
      _planAction(
        '01',
        'Create a wind-down cue',
        'Dim the lights or choose a calming sound.',
        Icons.light_mode_outlined,
        () => _showTip(
          'Choose one small signal that tells your body the day is slowing down.',
        ),
      ),
      const SizedBox(height: 10),
      _planAction(
        '02',
        'Let your mind unload',
        'Write down what you want to remember tomorrow.',
        Icons.edit_note_rounded,
        () => _go(AppPage.journal),
      ),
      const SizedBox(height: 10),
      _planAction(
        '03',
        'Make room for rest',
        'A quiet moment counts, even if sleep takes time.',
        Icons.nightlight_outlined,
        () => _go(AppPage.mindfulness),
      ),
      const SizedBox(height: 18),
      _card(
        color: _peach,
        child: const Text(
          'If sleep problems or exhaustion persist or affect daily life, consider talking with a healthcare professional.',
          style: TextStyle(color: _ink, fontSize: 13),
        ),
      ),
    ]);
  }

  void _showTip(String tip) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('A gentle idea'),
        content: Text(tip),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }

  Widget _profilePage() {
    return _scrollPage([
      const SizedBox(height: 8),
      _card(
        child: Row(
          children: [
            const CircleAvatar(
              radius: 29,
              backgroundColor: _lavender,
              child: Icon(Icons.person_rounded, size: 30, color: _purple),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _nameController.text.isEmpty
                        ? 'Your profile'
                        : _nameController.text,
                    style: const TextStyle(
                      color: _ink,
                      fontWeight: FontWeight.w700,
                      fontSize: 17,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    _repository.isSignedIn
                        ? Supabase.instance.client.auth.currentUser?.email ??
                              'Your private account'
                        : 'A space for your wellbeing',
                    style: const TextStyle(color: _muted, fontSize: 12),
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: 'Edit name',
              onPressed: _editName,
              icon: const Icon(Icons.edit_outlined, color: _purple),
            ),
          ],
        ),
      ),
      const SizedBox(height: 16),
      _linkCard(
        'Your progress',
        'Check-ins, goals, and reflections',
        Icons.insights_rounded,
        () => _go(AppPage.progress),
      ),
      const SizedBox(height: 9),
      _linkCard(
        'Daily goals',
        'Choose a few small steps',
        Icons.flag_outlined,
        () => _go(AppPage.goals),
      ),
      const SizedBox(height: 9),
      _linkCard(
        'Journal',
        'Private space for your thoughts',
        Icons.menu_book_rounded,
        () => _go(AppPage.journal),
      ),
      const SizedBox(height: 9),
      _linkCard(
        'Reminders',
        'Set a gentle nudge',
        Icons.notifications_none_rounded,
        () => _go(AppPage.notifications),
      ),
      const SizedBox(height: 9),
      _linkCard(
        'Settings',
        'Preferences and privacy',
        Icons.settings_outlined,
        () => _go(AppPage.settings),
      ),
      const SizedBox(height: 9),
      _linkCard(
        'Support & help',
        'Find resources and answers',
        Icons.help_outline_rounded,
        () => _go(AppPage.support),
      ),
      if (_repository.isSignedIn) ...[
        const SizedBox(height: 9),
        _linkCard(
          'Sign out',
          'Keep your data private on this device',
          Icons.logout_rounded,
          _signOut,
        ),
      ],
      const SizedBox(height: 18),
      const Center(
        child: Text(
          'MoodCare is a wellbeing companion, not a substitute for professional care.',
          textAlign: TextAlign.center,
          style: TextStyle(color: _muted, fontSize: 11, height: 1.5),
        ),
      ),
    ]);
  }

  Future<void> _signOut() async {
    try {
      await MoodCareBackend.client.auth.signOut();
      if (!mounted) return;
      setState(() {
        _page = AppPage.welcome;
        _moodEntries.clear();
        _journalEntries.clear();
        _noticeEntries.clear();
        _completedGoals.clear();
        _nameController.text = 'Alex';
        _notificationsEnabled = true;
        _gentleReminder = true;
        _reminderTime = const TimeOfDay(hour: 9, minute: 0);
      });
    } catch (error) {
      _showMessage('Could not sign out: $error');
    }
  }

  void _editName() {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('What should we call you?'),
        content: TextField(
          controller: _nameController,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Name'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              setState(() {});
              Navigator.pop(context);
              unawaited(_saveProfileName(_nameController.text.trim()));
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Widget _settingsPage() {
    return _scrollPage([
      const SizedBox(height: 8),
      _card(
        child: Column(
          children: [
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Notifications', style: TextStyle(color: _ink)),
              subtitle: const Text('Allow gentle wellbeing reminders'),
              value: _notificationsEnabled,
              onChanged: (value) {
                setState(() => _notificationsEnabled = value);
                unawaited(_savePreferences());
              },
            ),
            const Divider(color: _line),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text(
                'Reminder preferences',
                style: TextStyle(color: _ink),
              ),
              subtitle: const Text('Choose a time that works for you'),
              trailing: const Icon(Icons.chevron_right_rounded, color: _muted),
              onTap: () => _go(AppPage.notifications),
            ),
            const Divider(color: _line),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text(
                'Notification history',
                style: TextStyle(color: _ink),
              ),
              trailing: const Icon(Icons.chevron_right_rounded, color: _muted),
              onTap: () => _go(AppPage.notificationHistory),
            ),
          ],
        ),
      ),
      const SizedBox(height: 12),
      _card(
        color: _lavender,
        child: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Your privacy matters',
              style: TextStyle(color: _ink, fontWeight: FontWeight.w700),
            ),
            SizedBox(height: 7),
            Text(
              'This prototype stores information only in memory. It is cleared when you close the app.',
              style: TextStyle(color: _muted, fontSize: 13),
            ),
          ],
        ),
      ),
    ]);
  }

  Widget _remindersPage() {
    return _scrollPage([
      const SizedBox(height: 8),
      _card(
        child: Column(
          children: [
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text(
                'Daily check-in',
                style: TextStyle(color: _ink),
              ),
              subtitle: const Text('A soft reminder to pause and notice'),
              value: _gentleReminder,
              onChanged: (value) {
                setState(() => _gentleReminder = value);
                unawaited(_savePreferences());
              },
            ),
            const Divider(color: _line),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Reminder time', style: TextStyle(color: _ink)),
              subtitle: const Text('Choose a time that feels right'),
              trailing: Text(
                _reminderTime.format(context),
                style: const TextStyle(
                  color: _purple,
                  fontWeight: FontWeight.w600,
                ),
              ),
              onTap: () async {
                final time = await showTimePicker(
                  context: context,
                  initialTime: _reminderTime,
                );
                if (time != null && mounted) {
                  setState(() => _reminderTime = time);
                  unawaited(_savePreferences());
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Reminder time set to ${time.format(context)}.',
                      ),
                    ),
                  );
                }
              },
            ),
          ],
        ),
      ),
      const SizedBox(height: 14),
      const Text(
        'Reminders are saved in this app session only. Device notifications are not configured.',
        textAlign: TextAlign.center,
        style: TextStyle(color: _muted, fontSize: 12),
      ),
    ]);
  }

  Widget _notificationHistoryPage() {
    return _scrollPage([
      const SizedBox(height: 8),
      if (_noticeEntries.isEmpty)
        _card(
          child: const Column(
            children: [
              Icon(Icons.notifications_none_rounded, color: _purple, size: 30),
              SizedBox(height: 8),
              Text(
                'Your updates will appear here',
                style: TextStyle(color: _ink, fontWeight: FontWeight.w700),
              ),
              SizedBox(height: 4),
              Text(
                'Check-ins, reflections, and completed goals will show up in this list.',
                textAlign: TextAlign.center,
                style: TextStyle(color: _muted, fontSize: 12),
              ),
            ],
          ),
        )
      else
        ..._noticeEntries.map(
          (notice) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _card(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const CircleAvatar(
                    radius: 19,
                    backgroundColor: _lavender,
                    child: Icon(Icons.spa_rounded, color: _purple, size: 19),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          notice.title,
                          style: const TextStyle(
                            color: _ink,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          notice.message,
                          style: const TextStyle(color: _muted, fontSize: 13),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          notice.relativeDate,
                          style: const TextStyle(color: _purple, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      const SizedBox(height: 12),
      _secondaryButton(
        'Reminder preferences',
        () => _go(AppPage.notifications),
      ),
    ]);
  }

  Widget _goalsPage() {
    const goals = [
      (
        'Take a mindful pause',
        'Give yourself one quiet minute.',
        Icons.self_improvement_rounded,
      ),
      (
        'Get a little fresh air',
        'Step outside if it feels comfortable.',
        Icons.park_outlined,
      ),
      (
        'Connect with someone',
        'A small message is enough.',
        Icons.favorite_border_rounded,
      ),
      (
        'Write one journal note',
        'Notice what is on your mind.',
        Icons.edit_note_rounded,
      ),
    ];
    return _scrollPage([
      const SizedBox(height: 8),
      const Text(
        'Pick what feels kind, not demanding.',
        style: TextStyle(
          color: _ink,
          fontSize: 20,
          fontWeight: FontWeight.w700,
        ),
      ),
      const SizedBox(height: 5),
      const Text(
        'You can set a small intention for today.',
        style: TextStyle(color: _muted),
      ),
      const SizedBox(height: 16),
      ...goals.asMap().entries.map((item) {
        final checked = _completedGoals.contains(item.key + 10);
        return Padding(
          padding: const EdgeInsets.only(bottom: 9),
          child: _card(
            onTap: () {
              final index = item.key + 10;
              final completed = !checked;
              setState(() {
                if (completed) {
                  _completedGoals.add(index);
                } else {
                  _completedGoals.remove(index);
                }
              });
              unawaited(_saveGoalCompletion(index, completed));
            },
            color: checked ? const Color(0xFFE9F2ED) : Colors.white,
            child: Row(
              children: [
                Icon(item.value.$3, color: _purple),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.value.$1,
                        style: const TextStyle(
                          color: _ink,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        item.value.$2,
                        style: const TextStyle(color: _muted, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                Icon(
                  checked
                      ? Icons.check_circle_rounded
                      : Icons.add_circle_outline_rounded,
                  color: checked ? _green : _purple,
                ),
              ],
            ),
          ),
        );
      }),
      const SizedBox(height: 10),
      const Center(
        child: Text(
          'There is no streak to keep and no goal to fail.',
          style: TextStyle(color: _muted, fontSize: 12),
        ),
      ),
    ]);
  }

  Widget _journalPage() {
    return _scrollPage([
      const SizedBox(height: 8),
      const Text(
        'A quiet place for your thoughts.',
        style: TextStyle(
          color: _ink,
          fontSize: 20,
          fontWeight: FontWeight.w700,
        ),
      ),
      const SizedBox(height: 5),
      const Text(
        'Write as much or as little as you like. Entries stay in memory for this session.',
        style: TextStyle(color: _muted),
      ),
      const SizedBox(height: 15),
      TextField(
        controller: _journalController,
        maxLines: 5,
        decoration: const InputDecoration(
          hintText: 'What would you like to remember about today?',
          alignLabelWithHint: true,
        ),
      ),
      const SizedBox(height: 12),
      _primaryButton(
        label: 'Save a note',
        onPressed: () {
          final note = _journalController.text.trim();
          if (note.isEmpty) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Write a note before saving.')),
            );
            return;
          }
          setState(() {
            _journalEntries.insert(0, note);
            _journalController.clear();
          });
          unawaited(_saveJournalEntry(note));
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Your note has been saved.')),
          );
        },
      ),
      const SizedBox(height: 20),
      _sectionHeading('Your notes'),
      const SizedBox(height: 10),
      if (_journalEntries.isEmpty)
        _card(
          child: const Text(
            'Your journal is waiting for its first note.',
            style: TextStyle(color: _muted),
          ),
        )
      else
        ..._journalEntries.map(
          (entry) => Padding(
            padding: const EdgeInsets.only(bottom: 9),
            child: _card(
              child: Text(entry, style: const TextStyle(color: _ink)),
            ),
          ),
        ),
    ]);
  }

  Widget _supportPage() {
    return _scrollPage([
      const SizedBox(height: 8),
      _crisisBanner(
        title: 'Need urgent help?',
        description: 'If you are in immediate danger or might hurt yourself, call your local emergency number now. In the U.S. or Canada, call or text 988 for the Suicide & Crisis Lifeline.',
      ),
      const SizedBox(height: 14),
      _card(
        child: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'You do not have to do this alone.',
              style: TextStyle(
                color: _ink,
                fontWeight: FontWeight.w700,
                fontSize: 17,
              ),
            ),
            SizedBox(height: 7),
            Text(
              'Consider reaching out to someone you trust or a qualified mental health professional. If you are outside the U.S. or Canada, find a local crisis line through your health service or Befrienders Worldwide.',
              style: TextStyle(color: _muted),
            ),
          ],
        ),
      ),
      const SizedBox(height: 12),
      _linkCard(
        'Mindfulness tools',
        'Try a grounding or breathing exercise',
        Icons.self_improvement_rounded,
        () => _go(AppPage.mindfulness),
      ),
      const SizedBox(height: 9),
      _linkCard(
        'Wellbeing check',
        'Reflect on how the past two weeks have felt',
        Icons.favorite_border_rounded,
        _startAssessment,
      ),
      const SizedBox(height: 16),
      const Text(
        'MoodCare is not a crisis service and does not provide medical advice, diagnosis, or treatment.',
        textAlign: TextAlign.center,
        style: TextStyle(color: _muted, fontSize: 12, height: 1.5),
      ),
    ]);
  }

  Widget _crisisBanner({
    String title = 'You deserve support.',
    String description = 'If you are in immediate danger, contact your local emergency services. In the U.S. or Canada, call or text 988.',
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF1EB),
        borderRadius: BorderRadius.circular(19),
        border: Border.all(color: const Color(0xFFF6DED4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.support_outlined, color: Color(0xFFAB6453)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: _ink,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: const TextStyle(
                    color: _muted,
                    fontSize: 12,
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 5),
                TextButton(
                  onPressed: () {
                    if (_page != AppPage.support) _go(AppPage.support);
                  },
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.zero,
                    minimumSize: const Size(10, 30),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Text('View support options'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _scrollPage(List<Widget> children) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      ),
    );
  }

  Widget _card({
    required Widget child,
    VoidCallback? onTap,
    Color color = Colors.white,
    EdgeInsetsGeometry padding = const EdgeInsets.all(16),
  }) {
    return _AnimatedPress(
      enabled: onTap != null,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOutCubic,
            padding: padding,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: color == Colors.white ? _line : Colors.transparent,
              ),
            ),
            child: child,
          ),
        ),
      ),
    );
  }

  Widget _sectionHeading(
    String title, {
    String? trailing,
    VoidCallback? onTap,
  }) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              color: _ink,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        if (trailing != null)
          TextButton(
            onPressed: onTap,
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              minimumSize: const Size(10, 32),
            ),
            child: Text(trailing, style: const TextStyle(fontSize: 12)),
          ),
      ],
    );
  }

  Widget _linkCard(
    String title,
    String subtitle,
    IconData icon,
    VoidCallback onTap,
  ) {
    return _card(
      onTap: onTap,
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: _lavender,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: _purple, size: 21),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: _ink,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: const TextStyle(color: _muted, fontSize: 12),
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded, color: _muted),
        ],
      ),
    );
  }

  Widget _primaryButton({
    required String label,
    required VoidCallback? onPressed,
  }) {
    return _AnimatedPress(
      enabled: onPressed != null,
      child: SizedBox(
        width: double.infinity,
        height: 52,
        child: FilledButton(
          onPressed: onPressed,
          style: FilledButton.styleFrom(
            backgroundColor: _purple,
            foregroundColor: Colors.white,
            disabledBackgroundColor: const Color(0xFFD8D3E5),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          child: Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
      ),
    );
  }

  Widget _secondaryButton(String label, VoidCallback onPressed) {
    return _AnimatedPress(
      child: SizedBox(
        width: double.infinity,
        height: 48,
        child: OutlinedButton(
          onPressed: onPressed,
          style: OutlinedButton.styleFrom(
            foregroundColor: _purple,
            side: const BorderSide(color: _purple),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(15),
            ),
          ),
          child: Text(label),
        ),
      ),
    );
  }
}

class _AnimatedPress extends StatefulWidget {
  const _AnimatedPress({required this.child, this.enabled = true});

  final Widget child;
  final bool enabled;

  @override
  State<_AnimatedPress> createState() => _AnimatedPressState();
}

class _AnimatedPressState extends State<_AnimatedPress> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (_pressed != value) setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: widget.enabled ? (_) => _setPressed(true) : null,
      onPointerUp: widget.enabled ? (_) => _setPressed(false) : null,
      onPointerCancel: widget.enabled ? (_) => _setPressed(false) : null,
      child: AnimatedScale(
        scale: _pressed ? 0.975 : 1,
        duration: MediaQuery.disableAnimationsOf(context)
            ? Duration.zero
            : const Duration(milliseconds: 115),
        curve: Curves.easeOutCubic,
        child: widget.child,
      ),
    );
  }
}

class _BreathingOrb extends StatefulWidget {
  const _BreathingOrb({required this.isActive, required this.child});

  final bool isActive;
  final Widget child;

  @override
  State<_BreathingOrb> createState() => _BreathingOrbState();
}

class _BreathingOrbState extends State<_BreathingOrb>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 4),
    reverseDuration: const Duration(seconds: 6),
  );

  @override
  void initState() {
    super.initState();
    if (widget.isActive) _controller.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(covariant _BreathingOrb oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive && !oldWidget.isActive) {
      _controller.repeat(reverse: true);
    } else if (!widget.isActive && oldWidget.isActive) {
      _controller.stop();
      _controller.value = 0;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    return TickerMode(
      enabled: !reduceMotion,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) => Transform.scale(
          scale: widget.isActive && !reduceMotion
              ? 1 + (_controller.value * 0.08)
              : 1,
          child: child,
        ),
        child: widget.child,
      ),
    );
  }
}
