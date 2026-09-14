import 'package:cloud_firestore/cloud_firestore.dart';

// ─────────────────────────────────────────────────────────────
//  FANTASY SERVICE
//  Admin + App dono use karenge
// ─────────────────────────────────────────────────────────────

class FantasyService {
  FantasyService._();

  static final _db = FirebaseFirestore.instance;

  static CollectionReference get _matches => _db.collection('fantasy_matches');

  static CollectionReference get _teams => _db.collection('fantasy_teams');

  static DocumentReference get _featuredMatch =>
      _db.collection('featured_match').doc('admin_current');

  // ════════════════════════════════════════════════════════
  //  MODELS
  // ════════════════════════════════════════════════════════

  // ── Fantasy Match ────────────────────────────────────────
  static FantasyMatch _matchFromDoc(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return FantasyMatch(
      id: doc.id,
      featuredMatchRef: d['featuredMatchRef'] as String? ?? 'admin_current',
      status: d['status'] as String? ?? 'upcoming',
      predictionDeadline: (d['predictionDeadline'] as Timestamp?)?.toDate(),
      pointsCalculated: d['pointsCalculated'] as bool? ?? false,
      totalParticipants: d['totalParticipants'] as int? ?? 0,
      playerCredits: Map<String, double>.from((d['playerCredits'] as Map? ?? {})
          .map((k, v) => MapEntry(k.toString(), (v as num).toDouble()))),
      playerStats: _parsePlayerStats(d['playerStats']),
    );
  }

  static Map<String, FantasyPlayerStat> _parsePlayerStats(dynamic raw) {
    if (raw == null || raw is! Map) return {};
    return raw.map((k, v) {
      final m = v as Map<String, dynamic>? ?? {};
      return MapEntry(
          k.toString(),
          FantasyPlayerStat(
            runs: (m['runs'] as int?) ?? 0,
            fours: (m['fours'] as int?) ?? 0,
            sixes: (m['sixes'] as int?) ?? 0,
            isOut: (m['isOut'] as bool?) ?? false,
            wickets: (m['wickets'] as int?) ?? 0,
            maidens: (m['maidens'] as int?) ?? 0,
            catches: (m['catches'] as int?) ?? 0,
            stumpings: (m['stumpings'] as int?) ?? 0,
            runOuts: (m['runOuts'] as int?) ?? 0,
          ));
    });
  }

  // ── Fantasy Team ─────────────────────────────────────────
  static FantasyTeam _teamFromDoc(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return FantasyTeam(
      id: doc.id,
      userId: d['userId'] as String? ?? '',
      matchId: d['matchId'] as String? ?? '',
      userName: d['userName'] as String? ?? '',
      userPhoto: d['userPhoto'] as String? ?? '',
      players: List<String>.from(d['players'] ?? []),
      captain: d['captain'] as String? ?? '',
      viceCaptain: d['viceCaptain'] as String? ?? '',
      totalPoints: (d['totalPoints'] as num?)?.toDouble() ?? 0,
      rank: d['rank'] as int? ?? 0,
      createdAt: (d['createdAt'] as Timestamp?)?.toDate(),
    );
  }

  // ════════════════════════════════════════════════════════
  //  STREAMS
  // ════════════════════════════════════════════════════════

  static Stream<List<FantasyMatch>> matchesStream() {
    return _matches
        .orderBy('predictionDeadline', descending: true)
        .snapshots()
        .map((s) => s.docs.map(_matchFromDoc).toList());
  }

  static Stream<FantasyMatch?> activeMatchStream() {
    return _matches
        .where('status', whereIn: ['upcoming', 'live'])
        .limit(1)
        .snapshots()
        .map((s) => s.docs.isEmpty ? null : _matchFromDoc(s.docs.first));
  }

  static Stream<List<FantasyTeam>> leaderboardStream(String matchId) {
    return _teams
        .where('matchId', isEqualTo: matchId)
        .orderBy('totalPoints', descending: true)
        .limit(50)
        .snapshots()
        .map((s) => s.docs.map(_teamFromDoc).toList());
  }

  // ════════════════════════════════════════════════════════
  //  ADMIN — MATCH MANAGEMENT
  // ════════════════════════════════════════════════════════

  /// Match create/update karo
  static Future<String> saveFantasyMatch({
    String? existingId,
    required DateTime predictionDeadline,
    required Map<String, double> playerCredits,
  }) async {
    final data = {
      'featuredMatchRef': 'admin_current',
      'status': 'upcoming',
      'predictionDeadline': Timestamp.fromDate(predictionDeadline),
      'pointsCalculated': false,
      'totalParticipants': 0,
      'playerCredits': playerCredits,
      'updatedAt': FieldValue.serverTimestamp(),
    };

    if (existingId != null) {
      await _matches.doc(existingId).set(data, SetOptions(merge: true));
      return existingId;
    } else {
      final ref = await _matches.add({
        ...data,
        'createdAt': FieldValue.serverTimestamp(),
      });
      return ref.id;
    }
  }

  /// Status update — upcoming → live → completed
  static Future<void> updateMatchStatus(String matchId, String status) async {
    await _matches.doc(matchId).update({'status': status});
  }

  /// Match delete karo
  static Future<void> deleteMatch(String matchId) async {
    await _matches.doc(matchId).delete();
  }

  // ════════════════════════════════════════════════════════
  //  ADMIN — STATS ENTRY
  // ════════════════════════════════════════════════════════

  /// Ek player ki stats save karo
  static Future<void> savePlayerStat({
    required String matchId,
    required String playerId,
    required FantasyPlayerStat stat,
  }) async {
    await _matches.doc(matchId).update({
      'playerStats.$playerId': stat.toMap(),
    });
  }

  /// Saare players ki stats ek saath save karo
  static Future<void> saveAllPlayerStats({
    required String matchId,
    required Map<String, FantasyPlayerStat> stats,
  }) async {
    final update = <String, dynamic>{};
    stats.forEach((id, stat) {
      update['playerStats.$id'] = stat.toMap();
    });
    await _matches.doc(matchId).update(update);
  }

  // ════════════════════════════════════════════════════════
  //  ADMIN — POINTS CALCULATION
  // ════════════════════════════════════════════════════════

  /// Match ke baad points calculate karo aur leaderboard banao
  static Future<void> calculatePoints(String matchId) async {
    // 1. Match data fetch karo
    final matchDoc = await _matches.doc(matchId).get();
    final match = _matchFromDoc(matchDoc);

    if (match.pointsCalculated) return; // already done

    // 2. Saari teams fetch karo
    final teamsSnap = await _teams.where('matchId', isEqualTo: matchId).get();

    if (teamsSnap.docs.isEmpty) {
      await _matches.doc(matchId).update({
        'pointsCalculated': true,
        'status': 'completed',
      });
      return;
    }

    // 3. Har player ke base points calculate karo
    final basePoints = <String, double>{};
    match.playerStats.forEach((playerId, stat) {
      basePoints[playerId] = _calcPlayerPoints(stat);
    });

    // 4. Har team ke points calculate karo
    final batch = _db.batch();
    int rank = 1;
    final teamPoints = <String, double>{};

    for (final doc in teamsSnap.docs) {
      final team = _teamFromDoc(doc);
      double total = 0;

      for (final pid in team.players) {
        final pts = basePoints[pid] ?? 0;
        if (pid == team.captain)
          total += pts * 2.0; // 2x
        else if (pid == team.viceCaptain)
          total += pts * 1.5; // 1.5x
        else
          total += pts;
      }

      teamPoints[doc.id] = total;
    }

    // 5. Sort by points → assign rank
    final sorted = teamPoints.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    for (int i = 0; i < sorted.length; i++) {
      final docId = sorted[i].key;
      final pts = sorted[i].value;
      // Same points = same rank
      if (i > 0 && sorted[i].value == sorted[i - 1].value) {
        rank = i; // same rank
      } else {
        rank = i + 1;
      }
      batch.update(_teams.doc(docId), {
        'totalPoints': pts,
        'rank': rank,
      });
    }

    // 6. Match mark as completed
    batch.update(_matches.doc(matchId), {
      'pointsCalculated': true,
      'status': 'completed',
      'totalParticipants': teamsSnap.docs.length,
    });

    await batch.commit();
  }

  // ════════════════════════════════════════════════════════
  //  APP — USER TEAM
  // ════════════════════════════════════════════════════════

  /// User ki team submit karo
  static Future<void> submitTeam({
    required String matchId,
    required String userId,
    required String userName,
    required String userPhoto,
    required List<String> players,
    required String captain,
    required String viceCaptain,
  }) async {
    final docId = '${userId}_$matchId';
    await _teams.doc(docId).set({
      'userId': userId,
      'matchId': matchId,
      'userName': userName,
      'userPhoto': userPhoto,
      'players': players,
      'captain': captain,
      'viceCaptain': viceCaptain,
      'totalPoints': 0,
      'rank': 0,
      'createdAt': FieldValue.serverTimestamp(),
    });

    // Participant count increment
    await _matches.doc(matchId).update({
      'totalParticipants': FieldValue.increment(1),
    });
  }

  /// User ki team fetch karo
  static Future<FantasyTeam?> getMyTeam(String userId, String matchId) async {
    final doc = await _teams.doc('${userId}_$matchId').get();
    if (!doc.exists) return null;
    return _teamFromDoc(doc);
  }

  /// User ki team stream
  static Stream<FantasyTeam?> myTeamStream(String userId, String matchId) {
    return _teams
        .doc('${userId}_$matchId')
        .snapshots()
        .map((doc) => doc.exists ? _teamFromDoc(doc) : null);
  }

  // ════════════════════════════════════════════════════════
  //  POINTS FORMULA
  // ════════════════════════════════════════════════════════

  static double _calcPlayerPoints(FantasyPlayerStat s) {
    double pts = 0;

    // ── Batting ────────────────────────────────────────────
    pts += s.runs * 1; // 1 pt per run
    pts += s.fours * 1; // 1 pt per 4
    pts += s.sixes * 2; // 2 pts per 6
    if (s.runs >= 100)
      pts += 16; // century bonus
    else if (s.runs >= 50)
      pts += 8; // fifty bonus
    else if (s.runs >= 25) pts += 2; // 25 bonus
    if (s.isOut && s.runs == 0) pts -= 2; // duck penalty

    // Strike rate bonus (needs balls faced — skip for now)

    // ── Bowling ────────────────────────────────────────────
    pts += s.wickets * 25; // 25 pts per wicket
    pts += s.maidens * 8; // 8 pts per maiden
    if (s.wickets >= 5)
      pts += 8; // 5-wicket haul bonus
    else if (s.wickets >= 3) pts += 4; // 3-wicket bonus

    // ── Fielding ───────────────────────────────────────────
    pts += s.catches * 8; // 8 pts per catch
    pts += s.stumpings * 12; // 12 pts per stumping
    pts += s.runOuts * 6; // 6 pts per run out

    return pts;
  }

  // ════════════════════════════════════════════════════════
  //  HELPER — featured_match se players fetch karo
  // ════════════════════════════════════════════════════════

  static Future<List<FantasyPlayer>> getPlayersFromFeaturedMatch() async {
    final doc = await _featuredMatch.get();
    if (!doc.exists) return [];
    final data = doc.data() as Map<String, dynamic>;
    final teams = data['teams'] as Map<String, dynamic>? ?? {};
    final list = <FantasyPlayer>[];

    for (final teamKey in ['teamA', 'teamB']) {
      final team = teams[teamKey] as Map<String, dynamic>? ?? {};
      final teamName = team['name'] as String? ?? teamKey;
      final players = team['players'] as List<dynamic>? ?? [];
      for (final p in players) {
        final pm = p as Map<String, dynamic>;
        list.add(FantasyPlayer(
          id: pm['id'] as String? ?? '',
          name: pm['name'] as String? ?? '',
          role: pm['role'] as String? ?? '',
          teamKey: teamKey,
          teamName: teamName,
        ));
      }
    }
    return list;
  }
}

// ─────────────────────────────────────────────────────────────
//  MODELS
// ─────────────────────────────────────────────────────────────

class FantasyMatch {
  final String id;
  final String featuredMatchRef;
  final String status;
  final DateTime? predictionDeadline;
  final bool pointsCalculated;
  final int totalParticipants;
  final Map<String, double> playerCredits;
  final Map<String, FantasyPlayerStat> playerStats;

  bool get isUpcoming => status == 'upcoming';
  bool get isLive => status == 'live';
  bool get isCompleted => status == 'completed';

  bool get isPredictionOpen {
    if (!isUpcoming) return false;
    if (predictionDeadline == null) return true;
    return DateTime.now().isBefore(predictionDeadline!);
  }

  const FantasyMatch({
    required this.id,
    required this.featuredMatchRef,
    required this.status,
    required this.predictionDeadline,
    required this.pointsCalculated,
    required this.totalParticipants,
    required this.playerCredits,
    required this.playerStats,
  });
}

class FantasyPlayerStat {
  final int runs, fours, sixes;
  final bool isOut;
  final int wickets, maidens, catches, stumpings, runOuts;

  const FantasyPlayerStat({
    this.runs = 0,
    this.fours = 0,
    this.sixes = 0,
    this.isOut = false,
    this.wickets = 0,
    this.maidens = 0,
    this.catches = 0,
    this.stumpings = 0,
    this.runOuts = 0,
  });

  Map<String, dynamic> toMap() => {
        'runs': runs,
        'fours': fours,
        'sixes': sixes,
        'isOut': isOut,
        'wickets': wickets,
        'maidens': maidens,
        'catches': catches,
        'stumpings': stumpings,
        'runOuts': runOuts,
      };

  factory FantasyPlayerStat.fromMap(Map<String, dynamic> m) =>
      FantasyPlayerStat(
        runs: (m['runs'] as int?) ?? 0,
        fours: (m['fours'] as int?) ?? 0,
        sixes: (m['sixes'] as int?) ?? 0,
        isOut: (m['isOut'] as bool?) ?? false,
        wickets: (m['wickets'] as int?) ?? 0,
        maidens: (m['maidens'] as int?) ?? 0,
        catches: (m['catches'] as int?) ?? 0,
        stumpings: (m['stumpings'] as int?) ?? 0,
        runOuts: (m['runOuts'] as int?) ?? 0,
      );
}

class FantasyTeam {
  final String id;
  final String userId;
  final String matchId;
  final String userName;
  final String userPhoto;
  final List<String> players;
  final String captain;
  final String viceCaptain;
  final double totalPoints;
  final int rank;
  final DateTime? createdAt;

  const FantasyTeam({
    required this.id,
    required this.userId,
    required this.matchId,
    required this.userName,
    required this.userPhoto,
    required this.players,
    required this.captain,
    required this.viceCaptain,
    required this.totalPoints,
    required this.rank,
    required this.createdAt,
  });
}

class FantasyPlayer {
  final String id;
  final String name;
  final String role;
  final String teamKey;
  final String teamName;

  const FantasyPlayer({
    required this.id,
    required this.name,
    required this.role,
    required this.teamKey,
    required this.teamName,
  });
}
