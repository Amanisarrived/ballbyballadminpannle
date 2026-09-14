import 'package:cricket_admin/screens/dashboard/match_alerts_screen.dart';
import 'package:cricket_admin/services/match_alerts_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<List<Map<String, dynamic>>> _pump(
  WidgetTester tester, {
  MatchAlertSettings settings = const MatchAlertSettings(),
  List<MatchAlertLog> log = const [],
}) async {
  tester.view.physicalSize = const Size(900, 2600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  final writes = <Map<String, dynamic>>[];
  await tester.pumpWidget(MaterialApp(
    home: MatchAlertsScreen(
      settingsSource: Stream.value(settings),
      logSource: Stream.value(log),
      onUpdate: (fields) async => writes.add(fields),
    ),
  ));
  await tester.pumpAndSettle();
  return writes;
}

void main() {
  testWidgets('defaults match functions/alerts.js', (tester) async {
    await _pump(tester);
    expect(find.text('Automatic match alerts'), findsOneWidget);
    expect(find.byKey(const Key('alert-cap')), findsOneWidget);
    expect(find.text('12'), findsOneWidget);
    expect(find.text('No alerts sent yet. They start on their own once the '
        'featured match goes live.'), findsOneWidget);
  });

  testWidgets('master switch writes enabled', (tester) async {
    final writes = await _pump(tester);
    await tester.tap(find.text('Automatic match alerts'));
    await tester.pump();
    expect(writes, [
      {'enabled': false}
    ]);
  });

  testWidgets('wicket mode and cap write their fields', (tester) async {
    final writes = await _pump(tester);
    await tester.tap(find.text('All'));
    await tester.pump();
    await tester.tap(find.byIcon(Icons.add_rounded));
    await tester.pump();
    expect(writes, [
      {'wickets': 'all'},
      {'maxPerMatch': 13},
    ]);
  });

  testWidgets('type switches are locked while alerts are off', (tester) async {
    final writes = await _pump(tester,
        settings: const MatchAlertSettings(enabled: false));
    await tester.tap(find.text('Powerplay'), warnIfMissed: false);
    await tester.pump();
    expect(writes, isEmpty);
  });

  testWidgets('log shows kind, status and error', (tester) async {
    await _pump(tester, log: [
      MatchAlertLog(
        id: '1',
        kind: 'wicket',
        title: 'BIG WICKET! Virat Kohli out for 45 💥',
        body: 'Virat Kohli c Rashid b Naveen 45(30) · IND 120/3 (15.2)',
        matchTitle: 'India vs Afghanistan, 1st T20I',
        status: 'sent',
        createdAt: DateTime.now().subtract(const Duration(minutes: 5)),
      ),
      const MatchAlertLog(
        id: '2',
        kind: 'result',
        title: 'INDIA WIN! 🏆',
        body: 'India won by 7 wkts',
        matchTitle: '',
        status: 'failed',
        error: 'Requested entity was not found.',
      ),
    ]);
    expect(find.text('WICKET'), findsOneWidget);
    expect(find.text('SENT'), findsOneWidget);
    expect(find.text('5m ago'), findsOneWidget);
    expect(find.text('FAILED'), findsOneWidget);
    expect(find.text('Requested entity was not found.'), findsOneWidget);
  });

  test('settings parse leniently', () {
    final s = MatchAlertSettings.fromMap(
        {'wickets': 'bogus', 'maxPerMatch': 99, 'toss': 'yes', 'chase': false});
    expect(s.wickets, 'key');
    expect(s.maxPerMatch, 40);
    expect(s.toss, true);
    expect(s.chase, false);
  });

  testWidgets('settings error is shown, not a grey box', (tester) async {
    tester.view.physicalSize = const Size(900, 2000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      home: MatchAlertsScreen(
        settingsSource: Stream.error('permission-denied'),
        logSource: const Stream.empty(),
        onUpdate: (_) async {},
      ),
    ));
    await tester.pump();
    expect(find.textContaining('permission-denied'), findsOneWidget);
  });
}
