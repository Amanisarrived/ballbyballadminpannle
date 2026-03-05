import 'package:cloud_firestore/cloud_firestore.dart';

class FeaturedMatchService {
  static final _db = FirebaseFirestore.instance;
  static const _collection = 'featured_match';
  static const _document = 'admin_current';

  static DocumentReference get _doc =>
      _db.collection(_collection).doc(_document);

  // ════════════════════════════════════════════════════════
  //  MATCH META
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
      },
    }, SetOptions(merge: true));
  }

  static Future<void> updateStatus(String status) async {
    await _doc.update({'meta.status': status});
  }

  // ════════════════════════════════════════════════════════
  //  TEAMS
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

  // ════════════════════════════════════════════════════════
  //  PLAYER STATS
  // ════════════════════════════════════════════════════════

  static Future<void> initPlayerStats() async {
    final snap = await _doc.get();
    if (!snap.exists) return;

    final data = snap.data()! as Map<String, dynamic>;
    final teams = data['teams'] as Map<String, dynamic>? ?? {};
    final stats = <String, dynamic>{};

    for (final teamKey in ['teamA', 'teamB']) {
      final team = teams[teamKey] as Map<String, dynamic>?;
      if (team == null) continue;
      final players = team['players'] as List<dynamic>? ?? [];
      for (final p in players) {
        final id = p['id'] as String? ?? '';
        if (id.isEmpty) continue;
        stats[id] = _emptyStats();
      }
    }

    await _doc.set({'playerStats': stats}, SetOptions(merge: true));
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

  static Future<void> updatePlayerStat(
    String playerId,
    Map<String, dynamic> fields,
  ) async {
    final update = <String, dynamic>{};
    fields.forEach((key, value) {
      update['playerStats.$playerId.$key'] = value;
    });
    await _doc.update(update);
  }

  static Future<void> incrementPlayerStats(
    String playerId,
    Map<String, int> fields,
  ) async {
    final update = <String, dynamic>{};
    fields.forEach((key, value) {
      update['playerStats.$playerId.$key'] = FieldValue.increment(value);
    });
    await _doc.update(update);
  }

  static Future<void> incrementPlayerStat(
    String playerId,
    String field,
    int by,
  ) async {
    await _doc.update({
      'playerStats.$playerId.$field': FieldValue.increment(by),
    });
  }

  static Future<void> completeOver(String bowlerId) async {
    await _doc.update({
      'playerStats.$bowlerId.overs': FieldValue.increment(1),
      'playerStats.$bowlerId.ballsBowled': 0,
    });
  }

  static Future<void> resetPlayerStats(String playerId) async {
    final update = <String, dynamic>{};
    _emptyStats().forEach((key, value) {
      update['playerStats.$playerId.$key'] = value;
    });
    await _doc.update(update);
  }

  static Future<Map<String, dynamic>?> getPlayerStats(String playerId) async {
    final snap = await _doc.get();
    if (!snap.exists) return null;
    final stats = (snap.data()! as Map<String, dynamic>)['playerStats'] as Map?;
    return stats?[playerId] as Map<String, dynamic>?;
  }

  // ════════════════════════════════════════════════════════
  //  LIVE MATCH STATE
  // ════════════════════════════════════════════════════════

  static Future<void> setLiveMatchState({
    required String striker,
    required String nonStriker,
    required String currentBowler,
    required String battingTeam,
    required String bowlingTeam,
    required int innings,
  }) async {
    await _doc.set({
      'liveMatch': {
        'striker': striker,
        'nonStriker': nonStriker,
        'currentBowler': currentBowler,
        'battingTeam': battingTeam,
        'bowlingTeam': bowlingTeam,
        'innings': innings,
        'target': null,
      },
    }, SetOptions(merge: true));
  }

  static Future<void> rotateStrike() async {
    final snap = await _doc.get();
    if (!snap.exists) return;
    final data = snap.data()! as Map<String, dynamic>;
    final live = data['liveMatch'] as Map<String, dynamic>? ?? {};
    final striker = live['striker'] as String? ?? '';
    final nonStriker = live['nonStriker'] as String? ?? '';
    await _doc.update({
      'liveMatch.striker': nonStriker,
      'liveMatch.nonStriker': striker,
    });
  }

  static Future<void> setStriker(String playerId) async {
    await _doc.update({'liveMatch.striker': playerId});
  }

  static Future<void> setNonStriker(String playerId) async {
    await _doc.update({'liveMatch.nonStriker': playerId});
  }

  static Future<void> setCurrentBowler(String playerId) async {
    await _doc.update({'liveMatch.currentBowler': playerId});
  }

  static Future<void> switchInnings({
    required String newStriker,
    required String newNonStriker,
    required String newBowler,
    required int targetRuns,
    required int totalBalls,
  }) async {
    final snap = await _doc.get();
    if (!snap.exists) return;
    final data = snap.data()! as Map<String, dynamic>;
    final live = data['liveMatch'] as Map<String, dynamic>? ?? {};
    final prevBatting = live['battingTeam'] as String? ?? 'teamA';
    final prevBowling = live['bowlingTeam'] as String? ?? 'teamB';

    await _doc.update({
      'liveMatch.striker': newStriker,
      'liveMatch.nonStriker': newNonStriker,
      'liveMatch.currentBowler': newBowler,
      'liveMatch.battingTeam': prevBowling,
      'liveMatch.bowlingTeam': prevBatting,
      'liveMatch.innings': 2,
      'liveMatch.target': {
        'runs': targetRuns,
        'totalBalls': totalBalls,
        'ballsUsed': 0,
        'runsNeeded': targetRuns,
        'ballsRemaining': totalBalls,
      },
      'scores.$prevBowling.runs': 0,
      'scores.$prevBowling.wickets': 0,
      'scores.$prevBowling.overs': 0,
      'scores.$prevBowling.balls': 0,
      'scores.$prevBowling.extras.wides': 0,
      'scores.$prevBowling.extras.noBalls': 0,
      'scores.$prevBowling.extras.byes': 0,
      'scores.$prevBowling.extras.legByes': 0,
    });
  }

  static Future<void> incrementTargetBalls({
    required int runsNeeded,
    required int ballsRemaining,
  }) async {
    await FirebaseFirestore.instance.runTransaction((tx) async {
      final snap = await tx.get(_doc);
      if (!snap.exists) return;

      final data = snap.data()! as Map<String, dynamic>;
      final live = data['liveMatch'] as Map<String, dynamic>?;
      if (live == null) return;

      final target = live['target'];
      if (target == null || target is! Map) return;

      final currentBallsUsed = (target['ballsUsed'] as int?) ?? 0;
      final totalBalls = (target['totalBalls'] as int?) ?? 0;
      final runs = (target['runs'] as int?) ?? 0;

      tx.update(_doc, {
        'liveMatch.target': {
          'runs': runs,
          'totalBalls': totalBalls,
          'ballsUsed': currentBallsUsed + 1,
          'runsNeeded': runsNeeded,
          'ballsRemaining': ballsRemaining,
        },
      });
    });
  }

  // ════════════════════════════════════════════════════════
  //  STREAM / FETCH
  // ════════════════════════════════════════════════════════

  static Stream<DocumentSnapshot> stream() => _doc.snapshots();
  static Future<DocumentSnapshot> get() => _doc.get();

  // ════════════════════════════════════════════════════════
  //  SCORES
  // ════════════════════════════════════════════════════════

  static Future<void> initScores() async {
    await _doc.set({
      'scores': {
        'teamA': _emptyScore(),
        'teamB': _emptyScore(),
      },
    }, SetOptions(merge: true));
  }

  static Map<String, dynamic> _emptyScore() => {
        'runs': 0,
        'wickets': 0,
        'overs': 0,
        'balls': 0,
        'extras': {
          'wides': 0,
          'noBalls': 0,
          'byes': 0,
          'legByes': 0,
        },
      };

  static Future<void> addExtra(
      String teamKey, String extraType, int runs) async {
    await _doc.update({
      'scores.$teamKey.runs': FieldValue.increment(runs),
      'scores.$teamKey.extras.$extraType': FieldValue.increment(runs),
      if (extraType == 'byes' || extraType == 'legByes')
        'scores.$teamKey.balls': FieldValue.increment(1),
    });
  }

  static Future<void> completeOverScore(String teamKey) async {
    await _doc.update({
      'scores.$teamKey.overs': FieldValue.increment(1),
      'scores.$teamKey.balls': 0,
    });
  }

  // ════════════════════════════════════════════════════════
  //  TOSS
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
    await _doc.update({
      'liveMatch': {
        'battingTeam': '',
        'bowlingTeam': '',
        'currentBowler': '',
        'innings': 1,
        'nonStriker': '',
        'striker': '',
        'target': null,
      },
      'toss': {
        'battingFirst': '',
        'bowlingFirst': '',
        'decision': '',
        'wonBy': '',
      },
    });
  }

  // ════════════════════════════════════════════════════════
  //  RESET
  // ════════════════════════════════════════════════════════

  static Future<void> resetMatch() async {
    await _doc.update({
      'playerStats': {},
      'scores': {},
      'liveMatch': {
        'battingTeam': '',
        'bowlingTeam': '',
        'currentBowler': '',
        'innings': 1,
        'nonStriker': '',
        'striker': '',
        'target': null,
      },
      'meta.status': 'upcoming',
    });
  }

  // ════════════════════════════════════════════════════════
  //  BALL SCORING — SINGLE BATCH WRITES
  //  FIX: Previously 4-5 separate writes per ball = 4-5 stream
  //  events on the app. Now everything is ONE batch write =
  //  ONE stream event = instant UI update.
  // ════════════════════════════════════════════════════════

  /// Normal run (0,1,2,3,4,6) — single batch write
  static Future<void> recordRun({
    required String battingTeamKey,
    required String strikerId,
    required String bowlerId,
    required int runs,
    required List<Map<String, dynamic>> currentOver,
    // 2nd innings target fields (null in 1st innings)
    int? runsNeeded,
    int? ballsRemaining,
    Map<String, dynamic>? targetMap, // full target map for atomic update
  }) async {
    final update = <String, dynamic>{};

    // Score
    update['scores.$battingTeamKey.runs'] = FieldValue.increment(runs);
    update['scores.$battingTeamKey.balls'] = FieldValue.increment(1);

    // Batsman
    update['playerStats.$strikerId.balls'] = FieldValue.increment(1);
    if (runs > 0)
      update['playerStats.$strikerId.runs'] = FieldValue.increment(runs);
    if (runs == 4)
      update['playerStats.$strikerId.fours'] = FieldValue.increment(1);
    if (runs == 6)
      update['playerStats.$strikerId.sixes'] = FieldValue.increment(1);

    // Bowler
    update['playerStats.$bowlerId.runsConceded'] = FieldValue.increment(runs);
    update['playerStats.$bowlerId.ballsBowled'] = FieldValue.increment(1);

    // Current over — append ball
    final newOver = List<Map<String, dynamic>>.from(currentOver)
      ..add({'type': 'run', 'value': runs});
    update['currentOver'] = newOver;
    update['currentOverUpdatedAt'] = FieldValue.serverTimestamp();

    // Target (2nd innings only)
    if (targetMap != null && runsNeeded != null && ballsRemaining != null) {
      final currentBallsUsed = (targetMap['ballsUsed'] as int?) ?? 0;
      update['liveMatch.target'] = {
        'runs': targetMap['runs'],
        'totalBalls': targetMap['totalBalls'],
        'ballsUsed': currentBallsUsed + 1,
        'runsNeeded': runsNeeded,
        'ballsRemaining': ballsRemaining,
      };
    }

    await _doc.update(update);
  }

  /// Wide — single batch write
  static Future<void> recordWide({
    required String battingTeamKey,
    required String bowlerId,
    required int totalRuns, // 1 + extra runs
    required List<Map<String, dynamic>> currentOver,
  }) async {
    final newOver = List<Map<String, dynamic>>.from(currentOver)
      ..add({'type': 'wides', 'value': totalRuns});

    await _doc.update({
      'scores.$battingTeamKey.runs': FieldValue.increment(totalRuns),
      'scores.$battingTeamKey.extras.wides': FieldValue.increment(totalRuns),
      'playerStats.$bowlerId.wides': FieldValue.increment(1),
      'playerStats.$bowlerId.runsConceded': FieldValue.increment(totalRuns),
      'currentOver': newOver,
      'currentOverUpdatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// No ball — single batch write
  static Future<void> recordNoBall({
    required String battingTeamKey,
    required String bowlerId,
    required String strikerId,
    required int totalRuns, // 1 + extra runs
    required int extraRuns, // runs off bat
    required List<Map<String, dynamic>> currentOver,
  }) async {
    final update = <String, dynamic>{};
    final newOver = List<Map<String, dynamic>>.from(currentOver)
      ..add({'type': 'noBalls', 'value': totalRuns});

    update['scores.$battingTeamKey.runs'] = FieldValue.increment(totalRuns);
    update['scores.$battingTeamKey.extras.noBalls'] =
        FieldValue.increment(totalRuns);
    update['playerStats.$bowlerId.noBalls'] = FieldValue.increment(1);
    update['playerStats.$bowlerId.runsConceded'] =
        FieldValue.increment(totalRuns);
    if (extraRuns > 0) {
      update['playerStats.$strikerId.runs'] = FieldValue.increment(extraRuns);
    }
    update['currentOver'] = newOver;
    update['currentOverUpdatedAt'] = FieldValue.serverTimestamp();

    await _doc.update(update);
  }

  /// Leg bye — single batch write
  static Future<void> recordLegBye({
    required String battingTeamKey,
    required String bowlerId,
    required int runs,
    required List<Map<String, dynamic>> currentOver,
    int? runsNeeded,
    int? ballsRemaining,
    Map<String, dynamic>? targetMap,
  }) async {
    final update = <String, dynamic>{};
    final newOver = List<Map<String, dynamic>>.from(currentOver)
      ..add({'type': 'legBye', 'value': runs});

    update['scores.$battingTeamKey.runs'] = FieldValue.increment(runs);
    update['scores.$battingTeamKey.extras.legByes'] =
        FieldValue.increment(runs);
    update['scores.$battingTeamKey.balls'] = FieldValue.increment(1);
    update['playerStats.$bowlerId.ballsBowled'] = FieldValue.increment(1);
    update['currentOver'] = newOver;
    update['currentOverUpdatedAt'] = FieldValue.serverTimestamp();

    if (targetMap != null && runsNeeded != null && ballsRemaining != null) {
      final currentBallsUsed = (targetMap['ballsUsed'] as int?) ?? 0;
      update['liveMatch.target'] = {
        'runs': targetMap['runs'],
        'totalBalls': targetMap['totalBalls'],
        'ballsUsed': currentBallsUsed + 1,
        'runsNeeded': runsNeeded,
        'ballsRemaining': ballsRemaining,
      };
    }

    await _doc.update(update);
  }

  /// Wicket — single batch write
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
    final update = <String, dynamic>{};
    final newOver = List<Map<String, dynamic>>.from(currentOver)
      ..add({'type': 'wicket', 'value': runsOnBall, 'dismissal': dismissal});

    // Score
    update['scores.$battingTeamKey.wickets'] = FieldValue.increment(1);
    update['scores.$battingTeamKey.balls'] = FieldValue.increment(1);
    if (runsOnBall > 0) {
      update['scores.$battingTeamKey.runs'] = FieldValue.increment(runsOnBall);
    }

    // Batsman
    update['playerStats.$strikerId.balls'] = FieldValue.increment(1);
    update['playerStats.$strikerId.isOut'] = true;
    update['playerStats.$strikerId.dismissal'] = dismissal;

    // Bowler
    update['playerStats.$bowlerId.wickets'] = FieldValue.increment(1);
    update['playerStats.$bowlerId.ballsBowled'] = FieldValue.increment(1);
    if (runsOnBall > 0) {
      update['playerStats.$bowlerId.runsConceded'] =
          FieldValue.increment(runsOnBall);
    }

    // New batsman at striker
    update['liveMatch.striker'] = newBatsmanId;

    // Current over
    update['currentOver'] = newOver;
    update['currentOverUpdatedAt'] = FieldValue.serverTimestamp();

    // Target
    if (targetMap != null && runsNeeded != null && ballsRemaining != null) {
      final currentBallsUsed = (targetMap['ballsUsed'] as int?) ?? 0;
      update['liveMatch.target'] = {
        'runs': targetMap['runs'],
        'totalBalls': targetMap['totalBalls'],
        'ballsUsed': currentBallsUsed + 1,
        'runsNeeded': runsNeeded,
        'ballsRemaining': ballsRemaining,
      };
    }

    await _doc.update(update);
  }

  /// Complete over — single batch write
  static Future<void> recordOverComplete({
    required String battingTeamKey,
    required String bowlerId,
  }) async {
    await _doc.update({
      'scores.$battingTeamKey.overs': FieldValue.increment(1),
      'scores.$battingTeamKey.balls': 0,
      'playerStats.$bowlerId.overs': FieldValue.increment(1),
      'playerStats.$bowlerId.ballsBowled': 0,
      'currentOver': [],
      'currentOverUpdatedAt': FieldValue.serverTimestamp(),
    });
  }

  // Keep these for backward compat with other parts of the app
  static Future<void> addBallToOver(Map<String, dynamic> ball) async {
    final snap = await _doc.get();
    final data = snap.data() as Map<String, dynamic>? ?? {};
    final current = List<Map<String, dynamic>>.from(
      (data['currentOver'] as List<dynamic>? ?? [])
          .map((e) => Map<String, dynamic>.from(e as Map)),
    );
    current.add(ball);
    await _doc.update({
      'currentOver': current,
      'currentOverUpdatedAt': FieldValue.serverTimestamp(),
    });
  }

  static Future<void> clearCurrentOver() {
    return _doc.update({
      'currentOver': [],
      'currentOverUpdatedAt': FieldValue.serverTimestamp(),
    });
  }

  static Future<void> addRuns(String teamKey, int runs) async {
    await _doc.update({
      'scores.$teamKey.runs': FieldValue.increment(runs),
      'scores.$teamKey.balls': FieldValue.increment(1),
    });
  }

  static Future<void> addWicketWithRuns(String teamKey, int runs) async {
    await _doc.update({
      'scores.$teamKey.wickets': FieldValue.increment(1),
      'scores.$teamKey.balls': FieldValue.increment(1),
      if (runs > 0) 'scores.$teamKey.runs': FieldValue.increment(runs),
    });
  }
}
