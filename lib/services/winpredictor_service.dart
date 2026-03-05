import 'package:cloud_firestore/cloud_firestore.dart';

// ── Model ─────────────────────────────────────────────────
class AdminPoll {
  final String pollId;
  final bool showPoll;
  final bool showVotes;
  final String team1;
  final String team1Color;
  final String team1Logo;
  final int team1Votes;
  final String team2;
  final String team2Color;
  final String team2Logo;
  final int team2Votes;

  const AdminPoll({
    required this.pollId,
    required this.showPoll,
    required this.showVotes,
    required this.team1,
    required this.team1Color,
    required this.team1Logo,
    required this.team1Votes,
    required this.team2,
    required this.team2Color,
    required this.team2Logo,
    required this.team2Votes,
  });

  factory AdminPoll.fromDoc(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return AdminPoll(
      pollId: d['pollId'] as String? ?? '',
      showPoll: d['showPoll'] as bool? ?? false,
      showVotes: d['showVotes'] as bool? ?? false,
      team1: d['team1'] as String? ?? '',
      team1Color: d['team1Color'] as String? ?? '#CC0000',
      team1Logo: d['team1Logo'] as String? ?? '',
      team1Votes: (d['team1Votes'] as num?)?.toInt() ?? 0,
      team2: d['team2'] as String? ?? '',
      team2Color: d['team2Color'] as String? ?? '#1A73E8',
      team2Logo: d['team2Logo'] as String? ?? '',
      team2Votes: (d['team2Votes'] as num?)?.toInt() ?? 0,
    );
  }

  int get totalVotes => team1Votes + team2Votes;

  double get team1Percent =>
      totalVotes == 0 ? 50.0 : team1Votes / totalVotes * 100;

  double get team2Percent =>
      totalVotes == 0 ? 50.0 : team2Votes / totalVotes * 100;
}

// ── Service ───────────────────────────────────────────────
class AdminWinPredictorService {
  static final _doc =
      FirebaseFirestore.instance.collection('app_data').doc('current_poll');

  // ── Stream ───────────────────────────────────────────────
  static Stream<DocumentSnapshot> pollStream() => _doc.snapshots();

  // ── Fetch once ───────────────────────────────────────────
  static Future<DocumentSnapshot> fetchPoll() => _doc.get();

  // ── Save full poll (create or overwrite) ─────────────────
  static Future<void> savePoll({
    required String pollId,
    required bool showPoll,
    required bool showVotes,
    required String team1,
    required String team1Color,
    required String team1Logo,
    required String team2,
    required String team2Color,
    required String team2Logo,
  }) async {
    await _doc.set({
      'pollId': pollId,
      'showPoll': showPoll,
      'showVotes': showVotes,
      'team1': team1,
      'team1Color': team1Color,
      'team1Logo': team1Logo,
      'team1Votes': 0, // reset votes on new poll
      'team2': team2,
      'team2Color': team2Color,
      'team2Logo': team2Logo,
      'team2Votes': 0, // reset votes on new poll
    });
  }

  // ── Toggle showPoll only ──────────────────────────────────
  static Future<void> setShowPoll(bool value) =>
      _doc.update({'showPoll': value});

  // ── Toggle showVotes only ─────────────────────────────────
  static Future<void> setShowVotes(bool value) =>
      _doc.update({'showVotes': value});

  // ── Reset votes only (keep same poll) ────────────────────
  static Future<void> resetVotes() =>
      _doc.update({'team1Votes': 0, 'team2Votes': 0});

  // ── Generate a new unique pollId ──────────────────────────
  static String generatePollId() =>
      'poll_${DateTime.now().millisecondsSinceEpoch}';
}
