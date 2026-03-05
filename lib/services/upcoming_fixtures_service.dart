import 'package:cloud_firestore/cloud_firestore.dart';

class UpcomingFixturesService {
  static final _col =
      FirebaseFirestore.instance.collection('upcoming_fixtures');

  // ── Stream all fixtures ordered by time ──────────────────
  static Stream<QuerySnapshot> stream() =>
      _col.orderBy('time', descending: false).snapshots();

  // ── Add a new fixture ────────────────────────────────────
  static Future<void> addFixture({
    required String team1,
    required String team1Logo,
    required String team2,
    required String team2Logo,
    required DateTime time,
    required String tournament,
    required String venue,
    String winningTeam = '',
    // ── Match result fields ──
    String team1Score = '',
    String team2Score = '',
    String playerOfMatch = '',
    String playerOfMatchPhoto = '',
    String resultSummary = '',
  }) async {
    await _col.add({
      'team1': team1,
      'team1Logo': team1Logo,
      'team2': team2,
      'team2Logo': team2Logo,
      'time': Timestamp.fromDate(time),
      'tournament': tournament,
      'venue': venue,
      'winningTeam': winningTeam,
      // ── Match result fields ──
      'team1Score': team1Score,
      'team2Score': team2Score,
      'playerOfMatch': playerOfMatch,
      'playerOfMatchPhoto': playerOfMatchPhoto,
      'resultSummary': resultSummary,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  // ── Update an existing fixture ───────────────────────────
  static Future<void> updateFixture(
    String docId, {
    required String team1,
    required String team1Logo,
    required String team2,
    required String team2Logo,
    required DateTime time,
    required String tournament,
    required String venue,
    required String winningTeam,
    // ── Match result fields ──
    String team1Score = '',
    String team2Score = '',
    String playerOfMatch = '',
    String playerOfMatchPhoto = '',
    String resultSummary = '',
  }) async {
    await _col.doc(docId).update({
      'team1': team1,
      'team1Logo': team1Logo,
      'team2': team2,
      'team2Logo': team2Logo,
      'time': Timestamp.fromDate(time),
      'tournament': tournament,
      'venue': venue,
      'winningTeam': winningTeam,
      // ── Match result fields ──
      'team1Score': team1Score,
      'team2Score': team2Score,
      'playerOfMatch': playerOfMatch,
      'playerOfMatchPhoto': playerOfMatchPhoto,
      'resultSummary': resultSummary,
    });
  }

  // ── Set winning team only ────────────────────────────────
  static Future<void> setWinner(String docId, String winningTeam) async {
    await _col.doc(docId).update({'winningTeam': winningTeam});
  }

  // ── Update match result only (after match ends) ──────────
  static Future<void> updateMatchResult(
    String docId, {
    required String winningTeam,
    required String team1Score,
    required String team2Score,
    required String playerOfMatch,
    required String playerOfMatchPhoto,
    required String resultSummary,
  }) async {
    await _col.doc(docId).update({
      'winningTeam': winningTeam,
      'team1Score': team1Score,
      'team2Score': team2Score,
      'playerOfMatch': playerOfMatch,
      'playerOfMatchPhoto': playerOfMatchPhoto,
      'resultSummary': resultSummary,
    });
  }

  // ── Delete a fixture ─────────────────────────────────────
  static Future<void> deleteFixture(String docId) async {
    await _col.doc(docId).delete();
  }

  // ── Helpers ──────────────────────────────────────────────
  static Map<String, dynamic> fromDoc(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return {
      'id': doc.id,
      'team1': d['team1'] as String? ?? '',
      'team1Logo': d['team1Logo'] as String? ?? '',
      'team2': d['team2'] as String? ?? '',
      'team2Logo': d['team2Logo'] as String? ?? '',
      'time': (d['time'] as Timestamp?)?.toDate() ?? DateTime.now(),
      'tournament': d['tournament'] as String? ?? '',
      'venue': d['venue'] as String? ?? '',
      'winningTeam': d['winningTeam'] as String? ?? '',
      // ── Match result fields ──
      'team1Score': d['team1Score'] as String? ?? '',
      'team2Score': d['team2Score'] as String? ?? '',
      'playerOfMatch': d['playerOfMatch'] as String? ?? '',
      'playerOfMatchPhoto': d['playerOfMatchPhoto'] as String? ?? '',
      'resultSummary': d['resultSummary'] as String? ?? '',
    };
  }

  // ── Check if match has result data ───────────────────────
  static bool hasResult(Map<String, dynamic> fixture) {
    return (fixture['winningTeam'] as String).isNotEmpty ||
        (fixture['resultSummary'] as String).isNotEmpty;
  }

  // ── Check if match is upcoming ───────────────────────────
  static bool isUpcoming(Map<String, dynamic> fixture) {
    final time = fixture['time'] as DateTime;
    return time.isAfter(DateTime.now());
  }

  // ── Check if match is live (within 8 hours of start) ─────
  static bool isLive(Map<String, dynamic> fixture) {
    final time = fixture['time'] as DateTime;
    final now = DateTime.now();
    return now.isAfter(time) &&
        now.isBefore(time.add(const Duration(hours: 8))) &&
        !(fixture['winningTeam'] as String).isNotEmpty;
  }
}
