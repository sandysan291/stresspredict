import 'package:flutter_test/flutter_test.dart';
import 'package:stresspredict/main.dart';

void main() {
  testWidgets('onboarding opens the MoodCare home screen', (tester) async {
    await tester.pumpWidget(const MoodCareApp());

    expect(find.text('A little more\nroom to feel.'), findsOneWidget);
    await tester.ensureVisible(find.text('Get started'));
    await tester.tap(find.text('Get started'));
    await tester.pumpAndSettle();

    expect(find.text('Good morning, Alex'), findsOneWidget);
    expect(find.text('How are you feeling today?'), findsOneWidget);
  });

  testWidgets('sign-up screen offers a personalized demo profile', (
    tester,
  ) async {
    await tester.pumpWidget(const MoodCareApp());
    await tester.ensureVisible(find.text('Create an account'));
    await tester.tap(find.text('Create an account'));
    await tester.pumpAndSettle();

    expect(find.text('Make this space yours'), findsOneWidget);
    await tester.ensureVisible(find.text('Continue with demo profile'));
    await tester.tap(find.text('Continue with demo profile'));
    await tester.pumpAndSettle();

    expect(find.text('Good morning, Alex'), findsOneWidget);
  });

  testWidgets('daily check-in can be saved to the mood tracker', (
    tester,
  ) async {
    await tester.pumpWidget(const MoodCareApp());
    await tester.ensureVisible(find.text('Get started'));
    await tester.tap(find.text('Get started'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Good'));
    await tester.pumpAndSettle();
    expect(find.text('Checking in is an act of care.'), findsOneWidget);

    await tester.tap(find.text('Good'));
    await tester.pump();
    await tester.ensureVisible(find.text('Save check-in'));
    await tester.tap(find.text('Save check-in'));
    await tester.pumpAndSettle();

    expect(find.text('Mood tracker'), findsOneWidget);
    expect(find.text('Recent check-ins'), findsOneWidget);
    expect(find.text('Your check-in has been saved.'), findsOneWidget);

    await tester.tap(find.text('Home'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Notifications'));
    await tester.pumpAndSettle();
    expect(find.text('Check-in saved'), findsOneWidget);
  });

  testWidgets('wellbeing assessment advances only after an answer', (
    tester,
  ) async {
    await tester.pumpWidget(const MoodCareApp());
    await tester.ensureVisible(find.text('Get started'));
    await tester.tap(find.text('Get started'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Wellbeing check'));
    await tester.tap(find.text('Wellbeing check'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Little interest or pleasure'), findsOneWidget);
    await tester.ensureVisible(find.text('Continue'));
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Little interest or pleasure'), findsOneWidget);

    await tester.ensureVisible(find.text('Not at all'));
    await tester.tap(find.text('Not at all'));
    await tester.pump();
    await tester.ensureVisible(find.text('Continue'));
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Feeling down, depressed'), findsOneWidget);
  });
}
