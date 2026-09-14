import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_database/firebase_database.dart';

class FeaturedMatchService {
  static final _db = FirebaseFirestore.instance;
  static const _collection = 'featured_match';
  static const _document = 'admin_current';

  static DocumentReference get _doc =>
      _db.collection(_collection).doc(_document);

  static DatabaseReference get _rtdb =>
      FirebaseDatabase.instance.ref('$_collection/$_document');

  static DatabaseReference get _rtdbScores => _rtdb.child('scores');
  static DatabaseReference get _rtdbPlayerStats => _rtdb.child('playerStats');
  static DatabaseReference get _rtdbCurrentOver => _rtdb.child('currentOver');
  static DatabaseReference get _rtdbLiveMatch => _rtdb.child('liveMatch');

  // ════════════════════════════════════════════════════════
  //  MATCH META — Firestore only (static data)
  // ════════════════════════════════════════════════════════

  static Future<void> saveMatchMeta({
    required String matchId,
    required String title,
    required String format,
    required String venue,
    required String matchDate,
    required String matchTime,
    required String status,
    required String series,
    required String pitchType,
    required String pitchNote,
  }) async {
    await _doc.set({
      'matchId': matchId,
      'meta': {
        'title': title,
        'format': format,
        'venue': venue,
        'matchDate': matchDate,
        'matchTime': matchTime,
        'status': status,
        'series': series,
        'pitchType': pitchType,
        'pitchNote': pitchNote,
        if (format.toLowerCase() == 'test') ...{
          'day': 1,
          'superOver': false,
        },
      },
    }, SetOptions(merge: true));
  }

  static Future<void> updateStatus(String status) async =>
      _doc.update({'meta.status': status});

  // ════════════════════════════════════════════════════════
  //  TEST MATCH — DAY MANAGEMENT — Firestore only
  // ════════════════════════════════════════════════════════

  static Future<void> advanceDay() async {
    final snap = await _doc.get();
    if (!snap.exists) return;
    final meta = (snap.data()! as Map<String, dynamic>)['meta'] as Map? ?? {};
    final currentDay = (meta['day'] as int?) ?? 1;
    if (currentDay >= 5) return;
    await _doc.update({'meta.day': currentDay + 1});
  }

  static Future<void> setDay(int day) async => _doc.update({'meta.day': day});

  // ════════════════════════════════════════════════════════
  //  TEST MATCH — INNINGS — RTDB only for live fields
  // ════════════════════════════════════════════════════════

  static Future<void> switchTestInnings({
    required String newStriker,
    required String newNonStriker,
    required String newBowler,
    required int nextInnings,
    required String nextBattingTeam,
    required String nextBowlingTeam,
  }) async {
    final scoreKey = _testScoreKey(nextBattingTeam, nextInnings);
    final emptyScore = _emptyScore();

    await Future.wait([
      _rtdbCurrentOver.set([]),
      _rtdbScores.child(scoreKey).set(emptyScore),
      _rtdbLiveMatch.set({
        'striker': newStriker,
        'nonStriker': newNonStriker,
        'currentBowler': newBowler,
        'battingTeam': nextBattingTeam,
        'bowlingTeam': nextBowlingTeam,
        'innings': nextInnings,
        'target': null,
      }),
    ]);
  }

  static Future<void> switchToFinalTestInnings({
    required String newStriker,
    required String newNonStriker,
    required String newBowler,
    required String chasingTeam,
    required String bowlingTeam,
    required int targetRuns,
  }) async {
    final scoreKey = _testScoreKey(chasingTeam, 4);
    final targetMap = {
      'runs': targetRuns,
      'totalBalls': 0,
      'ballsUsed': 0,
      'runsNeeded': targetRuns,
      'ballsRemaining': 0,
    };

    await Future.wait([
      _rtdbCurrentOver.set([]),
      _rtdbScores.child(scoreKey).set(_emptyScore()),
      _rtdbLiveMatch.set({
        'striker': newStriker,
        'nonStriker': newNonStriker,
        'currentBowler': newBowler,
        'battingTeam': chasingTeam,
        'bowlingTeam': bowlingTeam,
        'innings': 4,
        'target': targetMap,
      }),
    ]);
  }

  static Future<void> enforceFollowOn({
    required String newStriker,
    required String newNonStriker,
    required String newBowler,
    required String followOnTeam,
    required String bowlingTeam,
  }) async {
    final scoreKey = _testScoreKey(followOnTeam, 3);

    await Future.wait([
      _rtdbCurrentOver.set([]),
      _rtdbScores.child(scoreKey).set(_emptyScore()),
      _rtdbLiveMatch.set({
        'striker': newStriker,
        'nonStriker': newNonStriker,
        'currentBowler': newBowler,
        'battingTeam': followOnTeam,
        'bowlingTeam': bowlingTeam,
        'innings': 3,
        'target': null,
      }),
    ]);

    // Only meta update in Firestore
    await _doc.update({
      'meta.followOn': true,
      'meta.followOnTeam': followOnTeam,
    });
  }

  static Future<void> declareBattingInnings({
    required String declaringTeam,
    required int currentInnings,
    required String newStriker,
    required String newNonStriker,
    required String newBowler,
    required String nextBattingTeam,
    required String nextBowlingTeam,
    required int nextInnings,
    int? targetRuns,
  }) async {
    final scoreKey = _testScoreKey(nextBattingTeam, nextInnings);
    final targetMap = targetRuns != null
        ? {
            'runs': targetRuns,
            'totalBalls': 0,
            'ballsUsed': 0,
            'runsNeeded': targetRuns,
            'ballsRemaining': 0,
          }
        : null;

    await Future.wait([
      _rtdbCurrentOver.set([]),
      _rtdbScores.child(scoreKey).set(_emptyScore()),
      _rtdbLiveMatch.set({
        'striker': newStriker,
        'nonStriker': newNonStriker,
        'currentBowler': newBowler,
        'battingTeam': nextBattingTeam,
        'bowlingTeam': nextBowlingTeam,
        'innings': nextInnings,
        'target': targetMap,
      }),
    ]);
  }

  static Future<void> callStumps() async =>
      _doc.update({'meta.status': 'stumps'});

  static Future<void> resumeFromStumps() async =>
      _doc.update({'meta.status': 'live'});

  static Future<void> endTestMatchDraw() async =>
      _doc.update({'meta.status': 'completed', 'meta.result': 'draw'});

  static Future<void> endTestMatchWin({
    required String winnerTeamKey,
    required String resultText,
  }) async =>
      _doc.update({
        'meta.status': 'completed',
        'meta.result': 'win',
        'meta.winner': winnerTeamKey,
        'meta.resultText': resultText,
      });

  static TestLeadInfo calculateLead({
    required Map<String, dynamic> scores,
    required int innings,
    required String battingTeamKey,
    required String bowlingTeamKey,
    required String battingTeamName,
    required String bowlingTeamName,
  }) {
    final inn1A = scores['teamA_inn1'] as Map? ?? scores['teamA'] as Map? ?? {};
    final inn2A = scores['teamA_inn2'] as Map? ?? {};
    final inn1B = scores['teamB_inn1'] as Map? ?? scores['teamB'] as Map? ?? {};
    final inn2B = scores['teamB_inn2'] as Map? ?? {};

    final teamARuns =
        ((inn1A['runs'] as int?) ?? 0) + ((inn2A['runs'] as int?) ?? 0);
    final teamBRuns =
        ((inn1B['runs'] as int?) ?? 0) + ((inn2B['runs'] as int?) ?? 0);
    final diff = teamARuns - teamBRuns;
    final absDiff = diff.abs();

    if (diff == 0)
      return TestLeadInfo(
          text: 'Scores level', isLead: false, runs: 0, leadTeam: '');
    if (diff > 0)
      return TestLeadInfo(
          text: '$battingTeamName leads by $absDiff',
          isLead: battingTeamKey == 'teamA',
          runs: absDiff,
          leadTeam: 'teamA');
    return TestLeadInfo(
        text: '$bowlingTeamName leads by $absDiff',
        isLead: battingTeamKey == 'teamB',
        runs: absDiff,
        leadTeam: 'teamB');
  }

  static int followOnThreshold(String format) {
    switch (format.toLowerCase()) {
      case 'test':
        return 200;
      case 'test3':
        return 150;
      case 'test2':
        return 100;
      case 'test1':
        return 75;
      default:
        return 200;
    }
  }

  static String _testScoreKey(String teamKey, int innings) {
    final innNum = innings <= 2
        ? (teamKey == 'teamA' ? (innings == 1 ? 1 : 2) : (innings == 2 ? 1 : 2))
        : (teamKey == 'teamA'
            ? (innings == 3 ? 2 : 1)
            : (innings == 4 ? 2 : 1));
    return '${teamKey}_inn$innNum';
  }

  static String currentTestScoreKey(String battingTeamKey, int innings) =>
      _testScoreKey(battingTeamKey, innings);

  // ════════════════════════════════════════════════════════
  //  TEAMS — Firestore only
  // ════════════════════════════════════════════════════════

  static Future<void> saveTeam({
    required String teamKey,
    required String teamId,
    required String name,
    required String logo,
    required List<Map<String, dynamic>> players,
  }) async {
    final snap = await _doc.get();
    final existingTeams = snap.exists
        ? Map<String, dynamic>.from(
            (snap.data()! as Map<String, dynamic>)['teams'] ?? {})
        : <String, dynamic>{};

    existingTeams[teamKey] = {
      'teamId': teamId,
      'name': name,
      'logo': logo,
      'players': players,
    };
    await _doc.set({'teams': existingTeams}, SetOptions(merge: true));
  }

  /// Set the logo of a team already on the featured match.
  ///
  /// Touches only `teams.<key>.logo`, so players and teamId (which the
  /// auto-scoring worker relies on) are left alone. The URL is also remembered
  /// under `teamLogos.<teamId>`, so the worker re-applies it the next time the
  /// same team is featured instead of showing a blank logo.
  static Future<void> setTeamLogo({
    required String teamKey,
    required String teamId,
    required String logo,
  }) =>
      _doc.update({
        'teams.$teamKey.logo': logo,
        if (teamId.isNotEmpty) 'teamLogos.$teamId': logo,
      });

  // ════════════════════════════════════════════════════════
  //  PLAYER CAREER STATS — Firestore only
  // ════════════════════════════════════════════════════════

  static Map<String, dynamic> buildPlayerWithStats({
    required String id,
    required String name,
    required String role,
    double? battingAvg,
    double? strikeRate,
    List<int>? recentForm,
    double? bowlingAvg,
    double? economy,
    List<int>? recentWickets,
    double? venueAvg,
  }) =>
      {
        'id': id,
        'name': name,
        'role': role,
        if (battingAvg != null) 'batting_avg': battingAvg,
        if (strikeRate != null) 'strike_rate': strikeRate,
        if (recentForm != null) 'recent_form': recentForm,
        if (bowlingAvg != null) 'bowling_avg': bowlingAvg,
        if (economy != null) 'economy': economy,
        if (recentWickets != null) 'recent_wickets': recentWickets,
        if (venueAvg != null) 'venue_avg': venueAvg,
      };

  static Future<void> updatePlayerCareerStats({
    required String teamKey,
    required String playerId,
    required Map<String, dynamic> stats,
  }) async {
    final snap = await _doc.get();
    if (!snap.exists) return;
    final data = snap.data()! as Map<String, dynamic>;
    final teams = Map<String, dynamic>.from(data['teams'] ?? {});
    final team = Map<String, dynamic>.from(teams[teamKey] ?? {});
    final players = List<dynamic>.from(team['players'] ?? []);
    final idx = players.indexWhere((p) => p['id'] == playerId);
    if (idx == -1) return;
    final updated = Map<String, dynamic>.from(players[idx] as Map)
      ..addAll(stats);
    players[idx] = updated;
    team['players'] = players;
    teams[teamKey] = team;
    await _doc.set({'teams': teams}, SetOptions(merge: true));
  }

  // ════════════════════════════════════════════════════════
  //  AI PREDICTION — Firestore only
  // ════════════════════════════════════════════════════════

  static Future<void> saveAiPrediction(Map<String, dynamic> prediction) async {
    await _doc.set({
      'ai_prediction': {
        ...prediction,
        'generatedAt': FieldValue.serverTimestamp(),
        'generated': true,
      },
    }, SetOptions(merge: true));
  }

  static Future<void> clearAiPrediction() async =>
      _doc.update({'ai_prediction': {}});

  // ════════════════════════════════════════════════════════
  //  PLAYER STATS — RTDB only
  // ════════════════════════════════════════════════════════

  static Future<void> initPlayerStats() async {
    final snap = await _doc.get();
    if (!snap.exists) return;
    final data = snap.data()! as Map<String, dynamic>;
    final teams = data['teams'] as Map<String, dynamic>? ?? {};
    final stats = <String, dynamic>{};
    for (final teamKey in ['teamA', 'teamB']) {
      final team = teams[teamKey] as Map<String, dynamic>?;
      final players = team?['players'] as List<dynamic>? ?? [];
      for (final p in players) {
        final id = p['id'] as String? ?? '';
        if (id.isNotEmpty) stats[id] = _emptyStats();
      }
    }
    await _rtdbPlayerStats.set(stats);
  }

  static Map<String, dynamic> _emptyStats() => {
        'runs': 0,
        'balls': 0,
        'fours': 0,
        'sixes': 0,
        'isOut': false,
        'dismissal': '',
        'overs': 0,
        'ballsBowled': 0,
        'maidens': 0,
        'wickets': 0,
        'runsConceded': 0,
        'wides': 0,
        'noBalls': 0,
      };

  static Future<void> incrementPlayerStats(
      String playerId, Map<String, int> fields) async {
    await Future.wait(fields.entries.map((e) => _rtdbPlayerStats
        .child(playerId)
        .child(e.key)
        .set(ServerValue.increment(e.value))));
  }

  static Future<void> incrementPlayerStat(
      String playerId, String field, int by) async {
    await _rtdbPlayerStats
        .child(playerId)
        .child(field)
        .set(ServerValue.increment(by));
  }

  static Future<void> updatePlayerStat(
      String playerId, Map<String, dynamic> fields) async {
    await Future.wait(fields.entries.map(
        (e) => _rtdbPlayerStats.child(playerId).child(e.key).set(e.value)));
  }

  static Future<void> completeOver(String bowlerId) async {
    await Future.wait([
      _rtdbPlayerStats
          .child(bowlerId)
          .child('overs')
          .set(ServerValue.increment(1)),
      _rtdbPlayerStats.child(bowlerId).child('ballsBowled').set(0),
    ]);
  }

  static Future<void> resetPlayerStats(String playerId) async =>
      _rtdbPlayerStats.child(playerId).set(_emptyStats());

  static Future<Map<String, dynamic>?> getPlayerStats(String playerId) async {
    final snap = await _rtdbPlayerStats.child(playerId).get();
    if (snap.exists && snap.value != null) {
      return Map<String, dynamic>.from(snap.value as Map);
    }
    return null;
  }

  // ════════════════════════════════════════════════════════
  //  LIVE MATCH STATE — RTDB only
  // ════════════════════════════════════════════════════════

  static Future<void> setLiveMatchState({
    required String striker,
    required String nonStriker,
    required String currentBowler,
    required String battingTeam,
    required String bowlingTeam,
    required int innings,
  }) async {
    await _rtdbLiveMatch.set({
      'striker': striker,
      'nonStriker': nonStriker,
      'currentBowler': currentBowler,
      'battingTeam': battingTeam,
      'bowlingTeam': bowlingTeam,
      'innings': innings,
      'target': null,
    });
  }

  static Future<void> rotateStrike() async {
    final snap = await _rtdbLiveMatch.get();
    if (!snap.exists || snap.value == null) return;
    final live = Map<String, dynamic>.from(snap.value as Map);
    final striker = live['striker'] as String? ?? '';
    final nonStriker = live['nonStriker'] as String? ?? '';
    await Future.wait([
      _rtdbLiveMatch.child('striker').set(nonStriker),
      _rtdbLiveMatch.child('nonStriker').set(striker),
    ]);
  }

  static Future<void> setStriker(String playerId) async =>
      _rtdbLiveMatch.child('striker').set(playerId);

  static Future<void> setNonStriker(String playerId) async =>
      _rtdbLiveMatch.child('nonStriker').set(playerId);

  static Future<void> setCurrentBowler(String playerId) async =>
      _rtdbLiveMatch.child('currentBowler').set(playerId);

  static Future<void> switchInnings({
    required String newStriker,
    required String newNonStriker,
    required String newBowler,
    required int targetRuns,
    required int totalBalls,
  }) async {
    final snap = await _rtdbLiveMatch.get();
    if (!snap.exists || snap.value == null) return;
    final live = Map<String, dynamic>.from(snap.value as Map);
    final prevBatting = live['battingTeam'] as String? ?? 'teamA';
    final prevBowling = live['bowlingTeam'] as String? ?? 'teamB';
    final targetMap = {
      'runs': targetRuns,
      'totalBalls': totalBalls,
      'ballsUsed': 0,
      'runsNeeded': targetRuns,
      'ballsRemaining': totalBalls,
    };

    await Future.wait([
      _rtdbScores.child(prevBowling).set(_emptyScore()),
      _rtdbCurrentOver.set([]),
      _rtdbLiveMatch.set({
        'striker': newStriker,
        'nonStriker': newNonStriker,
        'currentBowler': newBowler,
        'battingTeam': prevBowling,
        'bowlingTeam': prevBatting,
        'innings': 2,
        'target': targetMap,
      }),
    ]);
  }

  // ── Super Over ────────────────────────────────────────

  static Future<void> startSuperOver({
    required String newStriker,
    required String newNonStriker,
    required String newBowler,
    required String battingTeamKey,
    required String bowlingTeamKey,
  }) async {
    await Future.wait([
      _rtdbScores.child(battingTeamKey).set(_emptyScore()),
      _rtdbScores.child(bowlingTeamKey).set(_emptyScore()),
      _rtdbCurrentOver.set([]),
      _rtdbLiveMatch.set({
        'striker': newStriker,
        'nonStriker': newNonStriker,
        'currentBowler': newBowler,
        'battingTeam': battingTeamKey,
        'bowlingTeam': bowlingTeamKey,
        'innings': 1,
        'target': null,
      }),
    ]);
    // Only meta in Firestore
    await _doc.update({
      'meta.status': 'super_over',
      'meta.superOver': true,
    });
  }

  static Future<void> endSuperOver() async =>
      _doc.update({'meta.status': 'completed'});

  static Future<void> switchSuperOverInnings({
    required String newStriker,
    required String newNonStriker,
    required String newBowler,
    required int targetRuns,
  }) async {
    final snap = await _rtdbLiveMatch.get();
    if (!snap.exists || snap.value == null) return;
    final live = Map<String, dynamic>.from(snap.value as Map);
    final prevBatting = live['battingTeam'] as String? ?? 'teamA';
    final prevBowling = live['bowlingTeam'] as String? ?? 'teamB';
    final targetMap = {
      'runs': targetRuns,
      'totalBalls': 6,
      'ballsUsed': 0,
      'runsNeeded': targetRuns,
      'ballsRemaining': 6,
    };

    await Future.wait([
      _rtdbScores.child(prevBowling).set(_emptyScore()),
      _rtdbCurrentOver.set([]),
      _rtdbLiveMatch.set({
        'striker': newStriker,
        'nonStriker': newNonStriker,
        'currentBowler': newBowler,
        'battingTeam': prevBowling,
        'bowlingTeam': prevBatting,
        'innings': 2,
        'target': targetMap,
      }),
    ]);
  }

  // ════════════════════════════════════════════════════════
  //  STREAM / FETCH
  // ════════════════════════════════════════════════════════

  static Stream<DocumentSnapshot> stream() => _doc.snapshots();
  static Future<DocumentSnapshot> get() => _doc.get();
  static Stream<DatabaseEvent> scoresStream() => _rtdbScores.onValue;
  static Stream<DatabaseEvent> playerStatsStream() => _rtdbPlayerStats.onValue;
  static Stream<DatabaseEvent> currentOverStream() => _rtdbCurrentOver.onValue;
  static Stream<DatabaseEvent> liveMatchStream() => _rtdbLiveMatch.onValue;

  // ════════════════════════════════════════════════════════
  //  SCORES — RTDB only
  // ════════════════════════════════════════════════════════

  static Future<void> initScores() async {
    final scores = {
      'teamA': _emptyScore(),
      'teamB': _emptyScore(),
      'teamA_inn1': _emptyScore(),
      'teamA_inn2': _emptyScore(),
      'teamB_inn1': _emptyScore(),
      'teamB_inn2': _emptyScore(),
    };
    await _rtdbScores.set(scores);
  }

  static Map<String, dynamic> _emptyScore() => {
        'runs': 0,
        'wickets': 0,
        'overs': 0,
        'balls': 0,
        'extras': {'wides': 0, 'noBalls': 0, 'byes': 0, 'legByes': 0},
      };

  static Future<void> addExtra(
      String teamKey, String extraType, int runs) async {
    await Future.wait([
      _rtdbScores.child(teamKey).child('runs').set(ServerValue.increment(runs)),
      _rtdbScores
          .child(teamKey)
          .child('extras')
          .child(extraType)
          .set(ServerValue.increment(runs)),
      if (extraType == 'byes' || extraType == 'legByes')
        _rtdbScores.child(teamKey).child('balls').set(ServerValue.increment(1)),
    ]);
  }

  static Future<void> completeOverScore(String teamKey) async {
    await Future.wait([
      _rtdbScores.child(teamKey).child('overs').set(ServerValue.increment(1)),
      _rtdbScores.child(teamKey).child('balls').set(0),
    ]);
  }

  // ════════════════════════════════════════════════════════
  //  TOSS — Firestore only (set once, rarely changes)
  // ════════════════════════════════════════════════════════

  static Future<void> saveToss({
    required String wonBy,
    required String decision,
  }) async {
    final battingFirst =
        (decision == 'bat') ? wonBy : (wonBy == 'teamA' ? 'teamB' : 'teamA');
    final bowlingFirst = (battingFirst == 'teamA') ? 'teamB' : 'teamA';
    await _doc.set({
      'toss': {
        'wonBy': wonBy,
        'decision': decision,
        'battingFirst': battingFirst,
        'bowlingFirst': bowlingFirst,
      },
    }, SetOptions(merge: true));
  }

  static Future<void> clearToss() async {
    final emptyLive = {
      'battingTeam': '',
      'bowlingTeam': '',
      'currentBowler': '',
      'innings': 1,
      'nonStriker': '',
      'striker': '',
      'target': null,
    };
    await Future.wait([
      _rtdbLiveMatch.set(emptyLive),
      _doc.update({
        'toss': {
          'battingFirst': '',
          'bowlingFirst': '',
          'decision': '',
          'wonBy': '',
        },
      }),
    ]);
  }

  // ════════════════════════════════════════════════════════
  //  RESET — RTDB + Firestore meta only
  // ════════════════════════════════════════════════════════

  static Future<void> resetMatch() async {
    final emptyScores = {
      'teamA': _emptyScore(),
      'teamB': _emptyScore(),
      'teamA_inn1': _emptyScore(),
      'teamA_inn2': _emptyScore(),
      'teamB_inn1': _emptyScore(),
      'teamB_inn2': _emptyScore(),
    };
    final emptyLive = {
      'battingTeam': '',
      'bowlingTeam': '',
      'currentBowler': '',
      'innings': 1,
      'nonStriker': '',
      'striker': '',
      'target': null,
    };

    await Future.wait([
      _rtdbScores.set(emptyScores),
      _rtdbPlayerStats.set({}),
      _rtdbCurrentOver.set([]),
      _rtdbLiveMatch.set(emptyLive),
    ]);

    // Only meta fields in Firestore
    await _doc.update({
      'ai_prediction': {},
      'meta.status': 'upcoming',
      'meta.superOver': false,
      'meta.day': 1,
      'meta.followOn': false,
      'meta.followOnTeam': '',
      'meta.result': '',
      'meta.winner': '',
      'meta.resultText': '',
    });
  }

  // ════════════════════════════════════════════════════════
  //  BALL SCORING — RTDB only
  // ════════════════════════════════════════════════════════

  static Future<void> recordRun({
    required String battingTeamKey,
    required String strikerId,
    required String bowlerId,
    required int runs,
    required List<Map<String, dynamic>> currentOver,
    int? runsNeeded,
    int? ballsRemaining,
    Map<String, dynamic>? targetMap,
  }) async {
    final newOver = List<Map<String, dynamic>>.from(currentOver)
      ..add({'type': 'run', 'value': runs});

    final futures = <Future>[
      _rtdbScores
          .child(battingTeamKey)
          .child('runs')
          .set(ServerValue.increment(runs)),
      _rtdbScores
          .child(battingTeamKey)
          .child('balls')
          .set(ServerValue.increment(1)),
      _rtdbPlayerStats
          .child(strikerId)
          .child('balls')
          .set(ServerValue.increment(1)),
      _rtdbPlayerStats
          .child(bowlerId)
          .child('runsConceded')
          .set(ServerValue.increment(runs)),
      _rtdbPlayerStats
          .child(bowlerId)
          .child('ballsBowled')
          .set(ServerValue.increment(1)),
      _rtdbCurrentOver.set(newOver),
    ];
    if (runs > 0)
      futures.add(_rtdbPlayerStats
          .child(strikerId)
          .child('runs')
          .set(ServerValue.increment(runs)));
    if (runs == 4)
      futures.add(_rtdbPlayerStats
          .child(strikerId)
          .child('fours')
          .set(ServerValue.increment(1)));
    if (runs == 6)
      futures.add(_rtdbPlayerStats
          .child(strikerId)
          .child('sixes')
          .set(ServerValue.increment(1)));
    if (targetMap != null && runsNeeded != null && ballsRemaining != null) {
      final updatedTarget = {
        'runs': targetMap['runs'],
        'totalBalls': targetMap['totalBalls'],
        'ballsUsed': ((targetMap['ballsUsed'] as int?) ?? 0) + 1,
        'runsNeeded': runsNeeded,
        'ballsRemaining': ballsRemaining,
      };
      futures.add(_rtdbLiveMatch.child('target').set(updatedTarget));
    }
    await Future.wait(futures);
  }

  static Future<void> recordWide({
    required String battingTeamKey,
    required String bowlerId,
    required int totalRuns,
    required List<Map<String, dynamic>> currentOver,
  }) async {
    final newOver = List<Map<String, dynamic>>.from(currentOver)
      ..add({'type': 'wides', 'value': totalRuns});

    await Future.wait([
      _rtdbScores
          .child(battingTeamKey)
          .child('runs')
          .set(ServerValue.increment(totalRuns)),
      _rtdbScores
          .child(battingTeamKey)
          .child('extras')
          .child('wides')
          .set(ServerValue.increment(totalRuns)),
      _rtdbPlayerStats
          .child(bowlerId)
          .child('wides')
          .set(ServerValue.increment(1)),
      _rtdbPlayerStats
          .child(bowlerId)
          .child('runsConceded')
          .set(ServerValue.increment(totalRuns)),
      _rtdbCurrentOver.set(newOver),
    ]);
  }

  static Future<void> recordNoBall({
    required String battingTeamKey,
    required String bowlerId,
    required String strikerId,
    required int totalRuns,
    required int extraRuns,
    required List<Map<String, dynamic>> currentOver,
  }) async {
    final newOver = List<Map<String, dynamic>>.from(currentOver)
      ..add({'type': 'noBalls', 'value': totalRuns});

    final futures = <Future>[
      _rtdbScores
          .child(battingTeamKey)
          .child('runs')
          .set(ServerValue.increment(totalRuns)),
      _rtdbScores
          .child(battingTeamKey)
          .child('extras')
          .child('noBalls')
          .set(ServerValue.increment(totalRuns)),
      _rtdbPlayerStats
          .child(bowlerId)
          .child('noBalls')
          .set(ServerValue.increment(1)),
      _rtdbPlayerStats
          .child(bowlerId)
          .child('runsConceded')
          .set(ServerValue.increment(totalRuns)),
      _rtdbCurrentOver.set(newOver),
    ];
    if (extraRuns > 0)
      futures.add(_rtdbPlayerStats
          .child(strikerId)
          .child('runs')
          .set(ServerValue.increment(extraRuns)));
    await Future.wait(futures);
  }

  static Future<void> recordLegBye({
    required String battingTeamKey,
    required String bowlerId,
    required int runs,
    required List<Map<String, dynamic>> currentOver,
    int? runsNeeded,
    int? ballsRemaining,
    Map<String, dynamic>? targetMap,
  }) async {
    final newOver = List<Map<String, dynamic>>.from(currentOver)
      ..add({'type': 'legBye', 'value': runs});

    final futures = <Future>[
      _rtdbScores
          .child(battingTeamKey)
          .child('runs')
          .set(ServerValue.increment(runs)),
      _rtdbScores
          .child(battingTeamKey)
          .child('extras')
          .child('legByes')
          .set(ServerValue.increment(runs)),
      _rtdbScores
          .child(battingTeamKey)
          .child('balls')
          .set(ServerValue.increment(1)),
      _rtdbPlayerStats
          .child(bowlerId)
          .child('ballsBowled')
          .set(ServerValue.increment(1)),
      _rtdbCurrentOver.set(newOver),
    ];
    if (targetMap != null && runsNeeded != null && ballsRemaining != null) {
      final updatedTarget = {
        'runs': targetMap['runs'],
        'totalBalls': targetMap['totalBalls'],
        'ballsUsed': ((targetMap['ballsUsed'] as int?) ?? 0) + 1,
        'runsNeeded': runsNeeded,
        'ballsRemaining': ballsRemaining,
      };
      futures.add(_rtdbLiveMatch.child('target').set(updatedTarget));
    }
    await Future.wait(futures);
  }

  static Future<void> recordWicket({
    required String battingTeamKey,
    required String strikerId,
    required String bowlerId,
    required String newBatsmanId,
    required String dismissal,
    required int runsOnBall,
    required List<Map<String, dynamic>> currentOver,
    int? runsNeeded,
    int? ballsRemaining,
    Map<String, dynamic>? targetMap,
  }) async {
    final newOver = List<Map<String, dynamic>>.from(currentOver)
      ..add({'type': 'wicket', 'value': runsOnBall, 'dismissal': dismissal});

    final futures = <Future>[
      _rtdbScores
          .child(battingTeamKey)
          .child('wickets')
          .set(ServerValue.increment(1)),
      _rtdbScores
          .child(battingTeamKey)
          .child('balls')
          .set(ServerValue.increment(1)),
      _rtdbPlayerStats
          .child(strikerId)
          .child('balls')
          .set(ServerValue.increment(1)),
      _rtdbPlayerStats.child(strikerId).child('isOut').set(true),
      _rtdbPlayerStats.child(strikerId).child('dismissal').set(dismissal),
      _rtdbPlayerStats
          .child(bowlerId)
          .child('wickets')
          .set(ServerValue.increment(1)),
      _rtdbPlayerStats
          .child(bowlerId)
          .child('ballsBowled')
          .set(ServerValue.increment(1)),
      _rtdbCurrentOver.set(newOver),
      _rtdbLiveMatch.child('striker').set(newBatsmanId),
    ];
    if (runsOnBall > 0) {
      futures.addAll([
        _rtdbScores
            .child(battingTeamKey)
            .child('runs')
            .set(ServerValue.increment(runsOnBall)),
        _rtdbPlayerStats
            .child(bowlerId)
            .child('runsConceded')
            .set(ServerValue.increment(runsOnBall)),
      ]);
    }
    if (targetMap != null && runsNeeded != null && ballsRemaining != null) {
      final updatedTarget = {
        'runs': targetMap['runs'],
        'totalBalls': targetMap['totalBalls'],
        'ballsUsed': ((targetMap['ballsUsed'] as int?) ?? 0) + 1,
        'runsNeeded': runsNeeded,
        'ballsRemaining': ballsRemaining,
      };
      futures.add(_rtdbLiveMatch.child('target').set(updatedTarget));
    }
    await Future.wait(futures);
  }

  static Future<void> recordOverComplete({
    required String battingTeamKey,
    required String bowlerId,
  }) async {
    await Future.wait([
      _rtdbScores
          .child(battingTeamKey)
          .child('overs')
          .set(ServerValue.increment(1)),
      _rtdbScores.child(battingTeamKey).child('balls').set(0),
      _rtdbPlayerStats
          .child(bowlerId)
          .child('overs')
          .set(ServerValue.increment(1)),
      _rtdbPlayerStats.child(bowlerId).child('ballsBowled').set(0),
      _rtdbCurrentOver.set([]),
    ]);
  }

  static Future<void> clearCurrentOver() async => _rtdbCurrentOver.set([]);

  static Future<void> addRuns(String teamKey, int runs) async {
    await Future.wait([
      _rtdbScores.child(teamKey).child('runs').set(ServerValue.increment(runs)),
      _rtdbScores.child(teamKey).child('balls').set(ServerValue.increment(1)),
    ]);
  }

  static Future<void> addWicketWithRuns(String teamKey, int runs) async {
    final futures = <Future>[
      _rtdbScores.child(teamKey).child('wickets').set(ServerValue.increment(1)),
      _rtdbScores.child(teamKey).child('balls').set(ServerValue.increment(1)),
    ];
    if (runs > 0)
      futures.add(_rtdbScores
          .child(teamKey)
          .child('runs')
          .set(ServerValue.increment(runs)));
    await Future.wait(futures);
  }

  static Future<void> incrementTargetBalls({
    required int runsNeeded,
    required int ballsRemaining,
  }) async {
    final snap = await _rtdbLiveMatch.child('target').get();
    if (!snap.exists || snap.value == null) return;
    final target = Map<String, dynamic>.from(snap.value as Map);
    final currentBallsUsed = (target['ballsUsed'] as int?) ?? 0;
    final updatedTarget = {
      'runs': target['runs'],
      'totalBalls': target['totalBalls'],
      'ballsUsed': currentBallsUsed + 1,
      'runsNeeded': runsNeeded,
      'ballsRemaining': ballsRemaining,
    };
    await _rtdbLiveMatch.child('target').set(updatedTarget);
  }
}

class TestLeadInfo {
  final String text;
  final bool isLead;
  final int runs;
  final String leadTeam;

  const TestLeadInfo({
    required this.text,
    required this.isLead,
    required this.runs,
    required this.leadTeam,
  });
}
