import 'package:firebase_database/firebase_database.dart';

/// Control surface for the Cricbuzz auto-scoring worker.
///
/// The worker polls Cricbuzz and writes into the same RTDB paths the manual
/// scoring panel uses. Everything here is just the control block it reads:
/// `auto_score` (kept outside the match node, which every app user downloads).
class AutoScoringService {
  static const controlPath = 'auto_score';

  static DatabaseReference get _ref => FirebaseDatabase.instance.ref(controlPath);

  /// Sections the worker writes. Locking one hands it back to manual control.
  static const sections = <String>[
    'scores',
    'liveMatch',
    'playerStats',
    'currentOver',
    'meta',
  ];

  static Stream<DatabaseEvent> stream() => _ref.onValue;

  /// Parsed control state. Screens take this so they can be tested with a
  /// synthetic stream instead of a live database.
  static Stream<AutoScoringState> states() =>
      stream().map((event) => AutoScoringState.fromSnapshot(event.snapshot.value));

  static Future<AutoScoringState> get() async =>
      AutoScoringState.fromSnapshot((await _ref.get()).value);

  // ── controls ────────────────────────────────────────────────

  /// Point the worker at a match. Clears stale state from the previous one.
  static Future<void> selectMatch(String cbzMatchId) => _ref.update({
        'cbzMatchId': cbzMatchId,
        'teamMap': null,
        'lastError': '',
        'consecutiveErrors': 0,
      });

  static Future<void> setEnabled(bool enabled) =>
      _ref.update({'enabled': enabled});

  static Future<void> setPaused(bool paused) => _ref.update({'paused': paused});

  /// Let the worker keep BallByBall's Upcoming Fixtures filled from Cricbuzz.
  static Future<void> setFixturesEnabled(bool enabled) =>
      _ref.update({'fixturesEnabled': enabled});

  static Future<void> setLock(String section, bool locked) =>
      _ref.child('locks').update({section: locked});

  /// Ask the worker to import both playing XIs now (it also does this on its
  /// own after the toss). Existing player stats are kept.
  /// The flag clears itself once the import completes.
  static Future<void> requestSquadImport() =>
      _ref.update({'importSquads': true});

  /// Stop auto-scoring and detach from the match entirely.
  static Future<void> reset() => _ref.update({
        'enabled': false,
        'paused': false,
        'cbzMatchId': '',
        'teamMap': null,
        'importSquads': false,
        'lastError': '',
        'consecutiveErrors': 0,
      });
}

// ─────────────────────────────────────────────────────────────
//  MODELS
// ─────────────────────────────────────────────────────────────

/// Numbers from RTDB are not reliably numbers — Cricbuzz quotes some values
/// and not others, so a hard `as num?` cast blows up the whole screen.
int _asInt(Object? value) {
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value) ?? 0;
  return 0;
}

class AutoScoringState {
  final bool enabled;
  final bool paused;
  final String cbzMatchId;
  final bool importSquads;
  final bool fixturesEnabled;
  final Map<String, bool> locks;
  final String status;
  final String lastError;
  final String lastEvent;
  final int consecutiveErrors;
  final int lastSync;
  final List<CbzMatch> matches;

  const AutoScoringState({
    this.enabled = false,
    this.paused = false,
    this.cbzMatchId = '',
    this.importSquads = false,
    this.fixturesEnabled = false,
    this.locks = const {},
    this.status = 'idle',
    this.lastError = '',
    this.lastEvent = '',
    this.consecutiveErrors = 0,
    this.lastSync = 0,
    this.matches = const [],
  });

  factory AutoScoringState.fromSnapshot(Object? raw) {
    if (raw is! Map) return const AutoScoringState();
    final map = Map<String, dynamic>.from(raw);

    final locks = <String, bool>{};
    final rawLocks = map['locks'];
    if (rawLocks is Map) {
      rawLocks.forEach((k, v) => locks[k.toString()] = v == true);
    }

    // RTDB hands back a List for dense integer keys and a Map otherwise.
    final rawMatches = map['matches'];
    final matches = <CbzMatch>[];
    if (rawMatches is List) {
      for (final m in rawMatches) {
        if (m is Map) matches.add(CbzMatch.fromMap(m));
      }
    } else if (rawMatches is Map) {
      for (final m in rawMatches.values) {
        if (m is Map) matches.add(CbzMatch.fromMap(m));
      }
    }

    return AutoScoringState(
      enabled: map['enabled'] == true,
      paused: map['paused'] == true,
      cbzMatchId: (map['cbzMatchId'] ?? '').toString(),
      importSquads: map['importSquads'] == true,
      fixturesEnabled: map['fixturesEnabled'] == true,
      locks: locks,
      status: (map['status'] ?? 'idle').toString(),
      lastError: (map['lastError'] ?? '').toString(),
      lastEvent: (map['lastEvent'] ?? '').toString(),
      consecutiveErrors: _asInt(map['consecutiveErrors']),
      lastSync: _asInt(map['lastSync']),
      matches: matches,
    );
  }

  bool isLocked(String section) => locks[section] == true;

  bool get hasMatch => cbzMatchId.isNotEmpty;

  bool get isRunning => enabled && !paused && status == 'running';

  bool get isStale {
    if (lastSync == 0) return enabled;
    final age = DateTime.now().millisecondsSinceEpoch - lastSync;
    // Worker reports every 15-60s, but only every 5 min while waiting for a
    // match page to appear -- don't flag that as a lost worker.
    final limitSeconds = status == 'waiting' ? 420 : 90;
    return age > limitSeconds * 1000;
  }

  /// null when the worker has never reported in.
  Duration? get sinceSync => lastSync == 0
      ? null
      : Duration(
          milliseconds: DateTime.now().millisecondsSinceEpoch - lastSync);
}

class CbzMatch {
  final String matchId;
  final String title;
  final String desc;
  final String format;
  final String series;
  final String state;
  final String status;
  final String venue;
  final int startDate;

  const CbzMatch({
    required this.matchId,
    required this.title,
    required this.desc,
    required this.format,
    required this.series,
    required this.state,
    required this.status,
    required this.venue,
    required this.startDate,
  });

  factory CbzMatch.fromMap(Map raw) {
    final m = Map<String, dynamic>.from(raw);
    return CbzMatch(
      matchId: (m['matchId'] ?? '').toString(),
      title: (m['title'] ?? '').toString(),
      desc: (m['desc'] ?? '').toString(),
      format: (m['format'] ?? '').toString(),
      series: (m['series'] ?? '').toString(),
      state: (m['state'] ?? '').toString(),
      status: (m['status'] ?? '').toString(),
      venue: (m['venue'] ?? '').toString(),
      startDate: _asInt(m['startDate']),
    );
  }

  /// States worth attaching to now. Includes the breaks — a Test at stumps or
  /// a match in a rain delay is still ongoing and still the one you'd pick.
  bool get isLive => const {
        'In Progress',
        'Innings Break',
        'Toss',
        'Rain',
        'Drinks',
        'Lunch',
        'Tea',
        'Stumps',
        'Wet Outfield',
      }.contains(state);

  /// True only while the ball is actually in play.
  bool get isInPlay => state == 'In Progress';

  bool get isUpcoming =>
      state == 'Preview' || state == 'Upcoming' || state == 'Scheduled';

  bool get isDone =>
      state == 'Complete' || state == 'Abandon' || state == 'Cancelled';
}
