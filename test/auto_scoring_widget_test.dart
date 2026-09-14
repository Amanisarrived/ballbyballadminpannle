// Pumps the Auto Scoring widgets with synthetic state, so a build or layout
// failure shows up here instead of as a blank grey box in the release build.
import 'package:cricket_admin/screens/dashboard/auto_scoring_screen.dart';
import 'package:cricket_admin/services/auto_scoring_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _host(Widget child) => MaterialApp(
      home: Scaffold(body: SizedBox(width: 900, height: 700, child: child)),
    );

void main() {
  Future<void> _pump(WidgetTester tester, AutoScoringState state) async {
    await tester.pumpWidget(
        _host(AutoScoringScreen(source: Stream.value(state))));
    await tester.pump();          // resolve the stream
    expect(tester.takeException(), isNull);
  }

  testWidgets('builds with no worker state at all', (tester) async {
    await _pump(tester, const AutoScoringState());
  });

  testWidgets('builds while idle with a match selected', (tester) async {
    await _pump(tester, const AutoScoringState(cbzMatchId: '170103'));
  });

  testWidgets('builds while running with matches listed', (tester) async {
    await _pump(tester, const AutoScoringState(
      enabled: true,
      cbzMatchId: '170103',
      status: 'running',
      lastEvent: 'In Progress | scores,liveMatch',
      matches: [
        CbzMatch(matchId: '170103', title: 'AFG vs IND', desc: '1st T20I',
            format: 'T20', series: 'x', state: 'In Progress', status: 'live',
            venue: 'Delhi', startDate: 0),
      ],
    ));
  });

  testWidgets('builds in the error state', (tester) async {
    await _pump(tester, const AutoScoringState(
      enabled: true, cbzMatchId: '170103',
      lastError: 'matchHeader missing', consecutiveErrors: 6));
  });

  testWidgets('shows WAITING for a match Cricbuzz has not opened yet',
      (tester) async {
    await _pump(tester, AutoScoringState(
      enabled: true,
      cbzMatchId: '152731',
      status: 'waiting',
      lastEvent: "Cricbuzz hasn't opened this match yet",
      lastSync: DateTime.now().millisecondsSinceEpoch - 200 * 1000,
    ));
    expect(find.text('WAITING'), findsOneWidget);
    expect(find.text('NO SIGNAL'), findsNothing);
  });

  testWidgets('fixtures switch reflects state', (tester) async {
    await _pump(tester, const AutoScoringState(fixturesEnabled: true));
    // Below the fold: ListView only builds what is scrolled into view.
    await tester.scrollUntilVisible(
        find.text('Auto-fill international fixtures'), 200,
        scrollable: find.byType(Scrollable).first);
    expect(find.text('Auto-fill international fixtures'), findsOneWidget);
    expect(find.textContaining('checked every 30 minutes'), findsOneWidget);
  });

  test('fixturesEnabled parses from RTDB', () {
    expect(AutoScoringState.fromSnapshot(<Object?, Object?>{'fixturesEnabled': true})
        .fixturesEnabled, isTrue);
    expect(const AutoScoringState().fixturesEnabled, isFalse);
  });

  testWidgets('builds when paused and locked', (tester) async {
    await _pump(tester, const AutoScoringState(
      enabled: true, paused: true, cbzMatchId: '170103',
      locks: {'scores': true, 'meta': true}));
  });

  test('state parses an empty / missing control block', () {
    final state = AutoScoringState.fromSnapshot(null);
    expect(state.enabled, isFalse);
    expect(state.hasMatch, isFalse);
    expect(state.matches, isEmpty);
  });

  test('state parses what RTDB actually returns', () {
    // RTDB hands back Map<Object?, Object?>, and lists for dense int keys.
    final raw = <Object?, Object?>{
      'enabled': true,
      'cbzMatchId': '170103',
      'locks': <Object?, Object?>{'scores': true},
      'consecutiveErrors': 2,
      'lastSync': 1789283485000,
      'matches': <Object?>[
        <Object?, Object?>{
          'matchId': '170103',
          'title': 'AFG vs IND',
          'desc': '1st T20I',
          'state': 'In Progress',
          'status': 'live',
          'format': 'T20',
          'startDate': 1789308000000,
        },
        null, // RTDB sparse arrays contain nulls
      ],
    };
    final state = AutoScoringState.fromSnapshot(raw);
    expect(state.enabled, isTrue);
    expect(state.cbzMatchId, '170103');
    expect(state.isLocked('scores'), isTrue);
    expect(state.isLocked('liveMatch'), isFalse);
    expect(state.matches.length, 1);
    expect(state.matches.first.isLive, isTrue);
  });

  test('numeric fields survive arriving as strings', () {
    // Cricbuzz quotes startDate on most fixtures and not others; a hard
    // `as num?` cast here took the entire screen down with a TypeError.
    final state = AutoScoringState.fromSnapshot(<Object?, Object?>{
      'lastSync': '1789284094529',
      'consecutiveErrors': '3',
      'matches': <Object?>[
        <Object?, Object?>{'matchId': '171561', 'title': 'UGA vs KEN',
            'startDate': '1789198200000'},
        <Object?, Object?>{'matchId': '170020', 'title': 'NAM vs RSA',
            'startDate': 1789284600000},
      ],
    });
    expect(state.lastSync, 1789284094529);
    expect(state.consecutiveErrors, 3);
    expect(state.matches[0].startDate, 1789198200000);
    expect(state.matches[1].startDate, 1789284600000);
  });

  test('unparseable numbers fall back to zero rather than throwing', () {
    final state = AutoScoringState.fromSnapshot(<Object?, Object?>{
      'lastSync': 'not-a-number',
      'matches': <Object?>[
        <Object?, Object?>{'matchId': '1', 'startDate': <Object?>[]},
      ],
    });
    expect(state.lastSync, 0);
    expect(state.matches.first.startDate, 0);
  });

  testWidgets('renders a fixture list with string startDates', (tester) async {
    await tester.pumpWidget(_host(AutoScoringScreen(
      source: Stream.value(AutoScoringState.fromSnapshot(<Object?, Object?>{
        'enabled': true,
        'cbzMatchId': '170020',
        'matches': <Object?>[
          <Object?, Object?>{'matchId': '170020', 'title': 'NAM vs RSA',
              'desc': '3rd ODI', 'state': 'In Progress',
              'status': 'Namibia opt to bat', 'startDate': '1789284600000'},
        ],
      })),
    )));
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(find.textContaining('NAM vs RSA'), findsOneWidget);
  });

  test('matches may arrive as a keyed map instead of a list', () {
    final state = AutoScoringState.fromSnapshot(<Object?, Object?>{
      'matches': <Object?, Object?>{
        '0': <Object?, Object?>{'matchId': '1', 'title': 'A vs B',
            'state': 'Stumps'},
      },
    });
    expect(state.matches.length, 1);
    expect(state.matches.first.isLive, isTrue); // stumps counts as ongoing
  });
}
