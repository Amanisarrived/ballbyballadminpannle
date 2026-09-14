import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cricket_admin/services/featured_match_service.dart';
import 'package:cricket_admin/services/winiing_probablity_service.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';

const _bg = Color(0xFF0D0D0D);
const _surface = Color(0xFF141414);
const _surface2 = Color(0xFF1A1A1A);
const _surface3 = Color(0xFF202020);
const _border = Color(0xFF232323);
const _border2 = Color(0xFF2A2A2A);
const _textPrimary = Color(0xFFE8E8E8);
const _textSecondary = Color(0xFF666666);
const _textMuted = Color(0xFF3A3A3A);

class _RtdbData {
  final Map<String, dynamic> scores;
  final Map<String, dynamic> playerStats;
  final Map<String, dynamic> live; // liveMatch from RTDB
  final List<Map<String, dynamic>> currentOver;

  const _RtdbData({
    required this.scores,
    required this.playerStats,
    required this.live,
    required this.currentOver,
  });

  static const empty =
      _RtdbData(scores: {}, playerStats: {}, live: {}, currentOver: []);
}

class ScoringPanel extends StatefulWidget {
  const ScoringPanel({super.key});
  @override
  State<ScoringPanel> createState() => _ScoringPanelState();
}

class _ScoringPanelState extends State<ScoringPanel> {
  bool _processing = false;
  final List<Map<String, dynamic>> _ballLog = [];
  Map<String, dynamic>? _undoSnapshot;
  Map<String, dynamic> _cachedBowlTeam = {};
  _RtdbData _rtdb = _RtdbData.empty;

  @override
  void initState() {
    super.initState();
    _subscribeRtdb();
  }

  // ── FIX 1: Single root RTDB listener ─────────────────────
  void _subscribeRtdb() {
    FirebaseDatabase.instance
        .ref('featured_match/admin_current')
        .onValue
        .listen((event) {
      if (!mounted) return;
      final raw = event.snapshot.value;
      if (raw == null || raw is! Map) return;

      final root = _deepMap(raw);

      final scoresRaw = root['scores'];
      final scores =
          scoresRaw is Map ? _deepMap(scoresRaw) : <String, dynamic>{};

      final statsRaw = root['playerStats'];
      final stats = statsRaw is Map ? _deepMap(statsRaw) : <String, dynamic>{};

      final overRaw = root['currentOver'];
      List<Map<String, dynamic>> over = [];
      if (overRaw is List) {
        over = overRaw.whereType<Map>().map((e) => _deepMap(e)).toList();
      } else if (overRaw is Map) {
        final sorted = (overRaw as Map<dynamic, dynamic>).entries.toList()
          ..sort((a, b) => int.parse(a.key.toString())
              .compareTo(int.parse(b.key.toString())));
        over = sorted.map((e) => _deepMap(e.value as Map)).toList();
      }

      // liveMatch from RTDB
      final liveRaw = root['liveMatch'];
      final live = liveRaw is Map ? _deepMap(liveRaw) : <String, dynamic>{};

      setState(() => _rtdb = _RtdbData(
            scores: scores,
            playerStats: stats,
            live: live,
            currentOver: over,
          ));
    });
  }

  static Map<String, dynamic> _deepMap(Map raw) {
    return raw.map((k, v) {
      final key = k.toString();
      final value = v is Map ? _deepMap(v) : v;
      return MapEntry(key, value);
    });
  }

  String _activeBatScoreKey(String battingTeamKey, int innings, bool isTest) {
    if (!isTest) return battingTeamKey;
    return FeaturedMatchService.currentTestScoreKey(battingTeamKey, innings);
  }

  Map<String, dynamic>? _targetMapFromData(Map<String, dynamic> data) {
    // liveMatch RTDB se lo — Firestore mein nahi hai
    final target = _rtdb.live['target'];
    if (target == null || target is! Map) return null;
    return Map<String, dynamic>.from(target);
  }

  Future<void> _updateWinProbability({
    required String format,
    required int innings,
    required String battingTeamKey,
    required int runs,
    required int wickets,
    required int overs,
    required int balls,
    int? targetRuns,
    int? totalBalls,
  }) async {
    final prob = WinProbability.calculate(
      format: format,
      innings: innings,
      battingTeamKey: battingTeamKey,
      runs: runs,
      wickets: wickets,
      overs: overs,
      balls: balls,
      targetRuns: targetRuns,
      totalBalls: totalBalls,
    );

    await FirebaseFirestore.instance
        .collection('featured_match')
        .doc('admin_current')
        .update({
      'winProbability': {
        'teamA': prob['teamA'] ?? 50,
        'teamB': prob['teamB'] ?? 50,
        'lastUpdatedOver': overs + 1,
      },
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: StreamBuilder<DocumentSnapshot>(
        stream: FeaturedMatchService.stream(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(
                  color: Colors.redAccent, strokeWidth: 2),
            );
          }
          if (!snap.hasData || !snap.data!.exists) return _NotStartedState();

          final data = snap.data!.data() as Map<String, dynamic>;
          final meta = data['meta'] as Map<String, dynamic>? ?? {};
          final teams = data['teams'] as Map<String, dynamic>? ?? {};

          final scores = _rtdb.scores;
          final pStats = _rtdb.playerStats;
          // liveMatch comes from RTDB, not Firestore
          final live = _rtdb.live;

          if (live.isEmpty) return _NotStartedState();

          final status = meta['status'] as String? ?? '';
          final format = meta['format'] as String? ?? 't20';
          final isTest = format.toLowerCase() == 'test';
          final isSuperOver = meta['superOver'] == true;
          final day = (meta['day'] as int?) ?? 1;
          final innings = (live['innings'] as int?) ?? 1;
          final battingTeamKey = live['battingTeam'] as String? ?? 'teamA';
          final bowlingTeamKey = live['bowlingTeam'] as String? ?? 'teamB';
          final strikerId = live['striker'] as String? ?? '';
          final nonStrikerId = live['nonStriker'] as String? ?? '';
          final bowlerId = live['currentBowler'] as String? ?? '';

          final batTeam = teams[battingTeamKey] as Map<String, dynamic>? ?? {};
          final bowlTeam = teams[bowlingTeamKey] as Map<String, dynamic>? ?? {};

          final activeScoreKey =
              _activeBatScoreKey(battingTeamKey, innings, isTest);
          final batScore =
              scores[activeScoreKey] as Map<String, dynamic>? ?? {};

          if (scores.isEmpty) {
            return const Center(
              child: CircularProgressIndicator(
                  color: Colors.redAccent, strokeWidth: 2),
            );
          }

          _cachedBowlTeam = bowlTeam;

          final allPlayers = [
            ...(batTeam['players'] as List<dynamic>? ?? []),
            ...(bowlTeam['players'] as List<dynamic>? ?? []),
          ].map((p) => Map<String, dynamic>.from(p as Map)).toList();

          Map<String, dynamic>? findPlayer(String id) {
            try {
              return allPlayers.firstWhere((p) => p['id'] == id);
            } catch (_) {
              return null;
            }
          }

          Map<String, dynamic> statOf(String id) =>
              Map<String, dynamic>.from(pStats[id] as Map? ?? {});

          final striker = findPlayer(strikerId);
          final nonStriker = findPlayer(nonStrikerId);
          final bowler = findPlayer(bowlerId);
          final strikerStat = statOf(strikerId);
          final nonStrikerStat = statOf(nonStrikerId);
          final bowlerStat = statOf(bowlerId);

          final runs = (batScore['runs'] as int?) ?? 0;
          final wickets = (batScore['wickets'] as int?) ?? 0;
          final overs = (batScore['overs'] as int?) ?? 0;
          final balls = (batScore['balls'] as int?) ?? 0;

          final targetData = live['target'];
          final hasTarget = targetData != null && targetData is Map;
          final targetRuns = hasTarget ? (targetData['runs'] as int?) : null;
          final targetBallsUsed =
              hasTarget ? (targetData['ballsUsed'] as int?) ?? 0 : 0;
          final targetTotalBalls =
              hasTarget ? (targetData['totalBalls'] as int?) ?? 0 : 0;
          final ballsRemaining = targetTotalBalls - targetBallsUsed;
          final runsNeeded =
              hasTarget && targetRuns != null ? targetRuns - runs : null;

          TestLeadInfo? leadInfo;
          if (isTest && innings > 1) {
            leadInfo = FeaturedMatchService.calculateLead(
              scores: scores,
              innings: innings,
              battingTeamKey: battingTeamKey,
              bowlingTeamKey: bowlingTeamKey,
              battingTeamName: batTeam['name'] as String? ?? battingTeamKey,
              bowlingTeamName: bowlTeam['name'] as String? ?? bowlingTeamKey,
            );
          }

          bool canFollowOn = false;
          if (isTest && innings == 2) {
            final inn1A = scores['teamA_inn1'] as Map? ?? {};
            final inn1B = scores['teamB_inn1'] as Map? ?? {};
            final teamARuns = (inn1A['runs'] as int?) ?? 0;
            final teamBRuns = (inn1B['runs'] as int?) ?? 0;
            final deficit = (teamARuns - teamBRuns).abs();
            final threshold = FeaturedMatchService.followOnThreshold(format);
            canFollowOn = deficit >= threshold;
          }

          final teamAScore = scores['teamA'] as Map<String, dynamic>? ?? {};
          final teamBScore = scores['teamB'] as Map<String, dynamic>? ?? {};
          final teamARuns = (teamAScore['runs'] as int?) ?? 0;
          final teamBRuns = (teamBScore['runs'] as int?) ?? 0;
          final isTie = innings == 2 && !isSuperOver && teamARuns == teamBRuns;
          final isSuperOverTie =
              isSuperOver && innings == 2 && teamARuns == teamBRuns;

          final canSwitchInnings =
              isTest ? innings < 4 : innings == 1 && !isSuperOver;
          final canEndMatch = isTest ? innings >= 2 : innings == 2;

          return LayoutBuilder(
            builder: (context, constraints) {
              final isMobile = constraints.maxWidth < 650;
              return Column(
                children: [
                  _Scoreboard(
                    batTeamName: batTeam['name'] as String? ?? battingTeamKey,
                    batTeamLogo: batTeam['logo'] as String? ?? '',
                    batTeamId: batTeam['teamId'] as String? ?? battingTeamKey,
                    bowlTeamName: bowlTeam['name'] as String? ?? bowlingTeamKey,
                    bowlTeamLogo: bowlTeam['logo'] as String? ?? '',
                    runs: runs,
                    wickets: wickets,
                    overs: overs,
                    balls: balls,
                    innings: innings,
                    status: status,
                    isSuperOver: isSuperOver,
                    isTest: isTest,
                    day: day,
                    target: targetRuns,
                    ballsRemaining: ballsRemaining,
                    leadInfo: leadInfo,
                    onReset: () => _showResetDialog(context),
                    onDayChange:
                        isTest ? () => _showDayDialog(context, day) : null,
                  ),
                  Expanded(
                    child: isMobile
                        ? _MobileBody(
                            // Players Panel props
                            striker: striker, nonStriker: nonStriker,
                            bowler: bowler,
                            strikerStat: strikerStat,
                            nonStrikerStat: nonStrikerStat,
                            bowlerStat: bowlerStat,
                            strikerId: strikerId,
                            batTeam: batTeam, bowlTeam: bowlTeam,
                            battingTeamKey: battingTeamKey,
                            bowlingTeamKey: bowlingTeamKey,
                            allPlayers: allPlayers, processing: _processing,
                            onStrikerChange: _setStriker,
                            onNonStrikerChange: _setNonStriker,
                            onBowlerChange: _changeBowler,
                            onRotateStrike: () => _rotateStrike(),
                            // Ball Input props
                            canUndo: _undoSnapshot != null,
                            ballLog: _ballLog,
                            overs: overs, balls: balls,
                            isSuperOver: isSuperOver, isTest: isTest,
                            currentOver: _rtdb.currentOver,
                            bowlerName: bowler?['name'] as String? ?? '—',
                            onRun: (r) => _addRun(
                              runs: r,
                              strikerId: strikerId,
                              bowlerId: bowlerId,
                              battingTeamKey: activeScoreKey,
                              overs: overs,
                              balls: balls,
                              innings: innings,
                              hasTarget: hasTarget,
                              runsNeeded: runsNeeded ?? 0,
                              ballsRemaining: ballsRemaining,
                              fullData: data,
                            ),
                            onWide: () => _addWide(
                                bowlerId: bowlerId,
                                battingTeamKey: activeScoreKey,
                                fullData: data),
                            onNoBall: () => _addNoBall(
                                bowlerId: bowlerId,
                                battingTeamKey: activeScoreKey,
                                strikerId: strikerId,
                                fullData: data),
                            onLegBye: () => _addLegBye(
                              bowlerId: bowlerId,
                              battingTeamKey: activeScoreKey,
                              overs: overs,
                              balls: balls,
                              innings: innings,
                              hasTarget: hasTarget,
                              runsNeeded: runsNeeded ?? 0,
                              ballsRemaining: ballsRemaining,
                              fullData: data,
                            ),
                            onWicket: () => _showWicketDialog(
                              context: context,
                              strikerId: strikerId,
                              nonStrikerId: nonStrikerId,
                              bowlerId: bowlerId,
                              battingTeamKey: activeScoreKey,
                              batTeam: batTeam,
                              bowlTeam: bowlTeam,
                              overs: overs,
                              balls: balls,
                              innings: innings,
                              hasTarget: hasTarget,
                              runsNeeded: runsNeeded ?? 0,
                              ballsRemaining: ballsRemaining,
                              fullData: data,
                            ),
                            onUndo: () => _undo(fullData: data),
                            onEndOver: () => _endOver(
                                bowlerId: bowlerId,
                                battingTeamKey: activeScoreKey,
                                bowlTeam: bowlTeam,
                                context: context),
                            onSwitchInnings: canSwitchInnings
                                ? isTest
                                    ? () => _showTestInningsSwitchDialog(
                                        context: context,
                                        teams: teams,
                                        battingTeamKey: battingTeamKey,
                                        bowlingTeamKey: bowlingTeamKey,
                                        innings: innings,
                                        scores: scores,
                                        format: format,
                                        canFollowOn: canFollowOn)
                                    : isSuperOver
                                        ? () => _showSuperOverSwitchDialog(
                                            context: context,
                                            teams: teams,
                                            battingTeamKey: battingTeamKey,
                                            bowlingTeamKey: bowlingTeamKey,
                                            runs: runs)
                                        : () => _showSwitchInningsDialog(
                                            context: context,
                                            teams: teams,
                                            battingTeamKey: battingTeamKey,
                                            bowlingTeamKey: bowlingTeamKey,
                                            format: format,
                                            fullData: data)
                                : null,
                            onEndMatch: canEndMatch
                                ? isTest
                                    ? () => _showTestEndMatchDialog(
                                        context: context, innings: innings)
                                    : (isTie || isSuperOverTie)
                                        ? () => _showSuperOverSetupDialog(
                                            context: context,
                                            teams: teams,
                                            battingTeamKey: battingTeamKey,
                                            bowlingTeamKey: bowlingTeamKey)
                                        : () => _endMatch()
                                : null,
                            onEndMatchLabel: isTest
                                ? 'End / Stumps / Draw'
                                : innings == 2
                                    ? (isTie || isSuperOverTie)
                                        ? '🏏 Start Super Over'
                                        : 'End Match'
                                    : null,
                            onSwitchInningsLabel:
                                isTest ? 'Inn \${innings + 1} / Declare' : null,
                          )
                        : Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SizedBox(
                                width: 300,
                                child: _PlayersPanel(
                                  striker: striker,
                                  nonStriker: nonStriker,
                                  bowler: bowler,
                                  strikerStat: strikerStat,
                                  nonStrikerStat: nonStrikerStat,
                                  bowlerStat: bowlerStat,
                                  strikerId: strikerId,
                                  batTeam: batTeam,
                                  bowlTeam: bowlTeam,
                                  battingTeamKey: battingTeamKey,
                                  bowlingTeamKey: bowlingTeamKey,
                                  allPlayers: allPlayers,
                                  processing: _processing,
                                  onStrikerChange: _setStriker,
                                  onNonStrikerChange: _setNonStriker,
                                  onBowlerChange: _changeBowler,
                                  onRotateStrike: () => _rotateStrike(),
                                ),
                              ),
                              Expanded(
                                child: _BallInput(
                                  processing: _processing,
                                  canUndo: _undoSnapshot != null,
                                  ballLog: _ballLog,
                                  overs: overs,
                                  balls: balls,
                                  isSuperOver: isSuperOver,
                                  isTest: isTest,
                                  onRun: (r) => _addRun(
                                    runs: r,
                                    strikerId: strikerId,
                                    bowlerId: bowlerId,
                                    battingTeamKey: activeScoreKey,
                                    overs: overs,
                                    balls: balls,
                                    innings: innings,
                                    hasTarget: hasTarget,
                                    runsNeeded: runsNeeded ?? 0,
                                    ballsRemaining: ballsRemaining,
                                    fullData: data,
                                  ),
                                  onWide: () => _addWide(
                                      bowlerId: bowlerId,
                                      battingTeamKey: activeScoreKey,
                                      fullData: data),
                                  onNoBall: () => _addNoBall(
                                      bowlerId: bowlerId,
                                      battingTeamKey: activeScoreKey,
                                      strikerId: strikerId,
                                      fullData: data),
                                  onLegBye: () => _addLegBye(
                                    bowlerId: bowlerId,
                                    battingTeamKey: activeScoreKey,
                                    overs: overs,
                                    balls: balls,
                                    innings: innings,
                                    hasTarget: hasTarget,
                                    runsNeeded: runsNeeded ?? 0,
                                    ballsRemaining: ballsRemaining,
                                    fullData: data,
                                  ),
                                  onWicket: () => _showWicketDialog(
                                    context: context,
                                    strikerId: strikerId,
                                    nonStrikerId: nonStrikerId,
                                    bowlerId: bowlerId,
                                    battingTeamKey: activeScoreKey,
                                    batTeam: batTeam,
                                    bowlTeam: bowlTeam,
                                    overs: overs,
                                    balls: balls,
                                    innings: innings,
                                    hasTarget: hasTarget,
                                    runsNeeded: runsNeeded ?? 0,
                                    ballsRemaining: ballsRemaining,
                                    fullData: data,
                                  ),
                                  onUndo: () => _undo(fullData: data),
                                  onEndOver: () => _endOver(
                                      bowlerId: bowlerId,
                                      battingTeamKey: activeScoreKey,
                                      bowlTeam: bowlTeam,
                                      context: context),
                                  onSwitchInnings: canSwitchInnings
                                      ? isTest
                                          ? () => _showTestInningsSwitchDialog(
                                              context: context,
                                              teams: teams,
                                              battingTeamKey: battingTeamKey,
                                              bowlingTeamKey: bowlingTeamKey,
                                              innings: innings,
                                              scores: scores,
                                              format: format,
                                              canFollowOn: canFollowOn)
                                          : isSuperOver
                                              ? () =>
                                                  _showSuperOverSwitchDialog(
                                                      context: context,
                                                      teams: teams,
                                                      battingTeamKey:
                                                          battingTeamKey,
                                                      bowlingTeamKey:
                                                          bowlingTeamKey,
                                                      runs: runs)
                                              : () => _showSwitchInningsDialog(
                                                  context: context,
                                                  teams: teams,
                                                  battingTeamKey:
                                                      battingTeamKey,
                                                  bowlingTeamKey:
                                                      bowlingTeamKey,
                                                  format: format,
                                                  fullData: data)
                                      : null,
                                  onEndMatch: canEndMatch
                                      ? isTest
                                          ? () => _showTestEndMatchDialog(
                                              context: context,
                                              innings: innings)
                                          : (isTie || isSuperOverTie)
                                              ? () => _showSuperOverSetupDialog(
                                                  context: context,
                                                  teams: teams,
                                                  battingTeamKey:
                                                      battingTeamKey,
                                                  bowlingTeamKey:
                                                      bowlingTeamKey)
                                              : () => _endMatch()
                                      : null,
                                  onEndMatchLabel: isTest
                                      ? 'End / Stumps / Draw'
                                      : innings == 2
                                          ? (isTie || isSuperOverTie)
                                              ? '🏏 Start Super Over'
                                              : 'End Match'
                                          : null,
                                  onSwitchInningsLabel: isTest
                                      ? 'Inn ${innings + 1} / Declare'
                                      : null,
                                ),
                              ),
                              SizedBox(
                                width: 220,
                                child: _OverPanel(
                                  ballLog: _rtdb.currentOver,
                                  overs: overs,
                                  balls: balls,
                                  bowlerName: bowler?['name'] as String? ?? '—',
                                ),
                              ),
                            ],
                          ), // Row
                  ), // isMobile ternary
                ],
              );
            }, // LayoutBuilder
          );
        },
      ),
    );
  }

  // ════════════════════════════════════════════════════════
  //  SCORING ACTIONS
  // ════════════════════════════════════════════════════════

  Future<void> _addRun({
    required int runs,
    required String strikerId,
    required String bowlerId,
    required String battingTeamKey,
    required int overs,
    required int balls,
    required int innings,
    required bool hasTarget,
    required int runsNeeded,
    required int ballsRemaining,
    required Map<String, dynamic> fullData,
  }) async {
    if (_processing) return;
    final snapshotWithRtdb = {
      ...fullData,
      'scores': Map<String, dynamic>.from(_rtdb.scores),
      'playerStats': Map<String, dynamic>.from(_rtdb.playerStats),
      'liveMatch': Map<String, dynamic>.from(_rtdb.live),
      'currentOver': List<Map<String, dynamic>>.from(_rtdb.currentOver),
    };
    setState(() {
      _processing = true;
      _undoSnapshot = snapshotWithRtdb;
    });
    try {
      final currentOver = _rtdb.currentOver;
      final targetMap = _targetMapFromData(fullData);
      await FeaturedMatchService.recordRun(
        battingTeamKey: battingTeamKey,
        strikerId: strikerId,
        bowlerId: bowlerId,
        runs: runs,
        currentOver: currentOver,
        runsNeeded: hasTarget ? runsNeeded - runs : null,
        ballsRemaining: hasTarget ? ballsRemaining - 1 : null,
        targetMap: hasTarget ? targetMap : null,
      );
      final newBalls = balls + 1;
      if (newBalls >= 6) {
        await _completeOver(bowlerId: bowlerId, battingTeamKey: battingTeamKey);
        if (runs % 2 == 0) await FeaturedMatchService.rotateStrike();
        setState(() => _ballLog.clear());
        if (mounted)
          await _showChangeBowlerDialog(
              context: context,
              bowlTeam: _cachedBowlTeam,
              currentBowlerId: bowlerId);
      } else {
        if (runs % 2 != 0) await FeaturedMatchService.rotateStrike();
        setState(() => _ballLog.insert(0, {'type': 'run', 'value': runs}));
      }
    } finally {
      if (mounted) setState(() => _processing = false);
    }
  }

  Future<void> _addWide({
    required String bowlerId,
    required String battingTeamKey,
    required Map<String, dynamic> fullData,
  }) async {
    final extraRuns = await showDialog<int>(
      context: context,
      builder: (_) => const _ExtraRunsDialog(
        title: 'Wide',
        icon: Icons.arrow_outward_rounded,
        color: Colors.blueAccent,
        allowZero: true,
        hint: '0 = wide only (1 run)  ·  1+ = extra runs scored',
      ),
    );
    if (extraRuns == null) return;
    if (_processing) return;
    setState(() => _processing = true);
    try {
      final totalRuns = 1 + extraRuns;
      final currentOver = _rtdb.currentOver;
      await FeaturedMatchService.recordWide(
        battingTeamKey: battingTeamKey,
        bowlerId: bowlerId,
        totalRuns: totalRuns,
        currentOver: currentOver,
      );
      if (extraRuns % 2 != 0) await FeaturedMatchService.rotateStrike();
      setState(() => _ballLog.insert(0, {'type': 'wides', 'value': totalRuns}));
    } finally {
      if (mounted) setState(() => _processing = false);
    }
  }

  Future<void> _addNoBall({
    required String bowlerId,
    required String battingTeamKey,
    required String strikerId,
    required Map<String, dynamic> fullData,
  }) async {
    final extraRuns = await showDialog<int>(
      context: context,
      builder: (_) => const _ExtraRunsDialog(
        title: 'No Ball',
        icon: Icons.cancel_outlined,
        color: Colors.orangeAccent,
        allowZero: true,
        hint: '0 = no ball only (1 run)  ·  1+ = runs scored off bat',
      ),
    );
    if (extraRuns == null) return;
    if (_processing) return;
    setState(() => _processing = true);
    try {
      final totalRuns = 1 + extraRuns;
      final currentOver = _rtdb.currentOver;
      await FeaturedMatchService.recordNoBall(
        battingTeamKey: battingTeamKey,
        bowlerId: bowlerId,
        strikerId: strikerId,
        totalRuns: totalRuns,
        extraRuns: extraRuns,
        currentOver: currentOver,
      );
      if (extraRuns % 2 != 0) await FeaturedMatchService.rotateStrike();
      setState(
          () => _ballLog.insert(0, {'type': 'noBalls', 'value': totalRuns}));
    } finally {
      if (mounted) setState(() => _processing = false);
    }
  }

  Future<void> _addLegBye({
    required String bowlerId,
    required String battingTeamKey,
    required int overs,
    required int balls,
    required int innings,
    required bool hasTarget,
    required int runsNeeded,
    required int ballsRemaining,
    required Map<String, dynamic> fullData,
  }) async {
    final lbRuns = await showDialog<int>(
      context: context,
      builder: (_) => const _ExtraRunsDialog(
        title: 'Leg Bye',
        icon: Icons.directions_run_rounded,
        color: Colors.purpleAccent,
        allowZero: false,
        hint: 'Runs go to extras — not credited to batsman or bowler',
      ),
    );
    if (lbRuns == null || lbRuns == 0) return;
    if (_processing) return;
    setState(() => _processing = true);
    try {
      final currentOver = _rtdb.currentOver;
      final targetMap = _targetMapFromData(fullData);
      await FeaturedMatchService.recordLegBye(
        battingTeamKey: battingTeamKey,
        bowlerId: bowlerId,
        runs: lbRuns,
        currentOver: currentOver,
        runsNeeded: hasTarget ? runsNeeded - lbRuns : null,
        ballsRemaining: hasTarget ? ballsRemaining - 1 : null,
        targetMap: hasTarget ? targetMap : null,
      );
      final newBalls = balls + 1;
      if (newBalls >= 6) {
        await _completeOver(bowlerId: bowlerId, battingTeamKey: battingTeamKey);
        if (lbRuns % 2 == 0) await FeaturedMatchService.rotateStrike();
        setState(() => _ballLog.clear());
        if (mounted)
          await _showChangeBowlerDialog(
              context: context,
              bowlTeam: _cachedBowlTeam,
              currentBowlerId: bowlerId);
      } else {
        if (lbRuns % 2 != 0) await FeaturedMatchService.rotateStrike();
        setState(() => _ballLog.insert(0, {'type': 'legBye', 'value': lbRuns}));
      }
    } finally {
      if (mounted) setState(() => _processing = false);
    }
  }

  Future<void> _completeOver({
    required String bowlerId,
    required String battingTeamKey,
  }) async {
    await FeaturedMatchService.recordOverComplete(
        battingTeamKey: battingTeamKey, bowlerId: bowlerId);
    try {
      // meta from Firestore (format field), liveMatch from RTDB
      final doc = await FirebaseFirestore.instance
          .collection('featured_match')
          .doc('admin_current')
          .get();
      if (doc.exists) {
        final data = doc.data()!;
        final meta = data['meta'] as Map<String, dynamic>? ?? {};
        final format = meta['format'] as String? ?? 't20';
        final isTest = format.toLowerCase() == 'test';

        // liveMatch → RTDB
        final live = _rtdb.live;
        final innings = (live['innings'] as int?) ?? 1;
        final batKey = live['battingTeam'] as String? ?? 'teamA';

        final activeKey = isTest
            ? FeaturedMatchService.currentTestScoreKey(batKey, innings)
            : batKey;
        final batScore = _rtdb.scores[activeKey] as Map<String, dynamic>? ?? {};

        // target → RTDB
        final target = live['target'] as Map<String, dynamic>?;

        await _updateWinProbability(
          format: format,
          innings: innings,
          battingTeamKey: batKey,
          runs: (batScore['runs'] as int?) ?? 0,
          wickets: (batScore['wickets'] as int?) ?? 0,
          overs: (batScore['overs'] as int?) ?? 0,
          balls: 0,
          targetRuns: target?['runs'] as int?,
          totalBalls: target?['totalBalls'] as int?,
        );
      }
    } catch (e) {
      debugPrint('❌ Win probability error: $e');
    }
  }

  Future<void> _rotateStrike() async {
    if (_processing) return;
    setState(() => _processing = true);
    try {
      await FeaturedMatchService.rotateStrike();
    } finally {
      if (mounted) setState(() => _processing = false);
    }
  }

  Future<void> _setStriker(String id) async =>
      FeaturedMatchService.setStriker(id);
  Future<void> _setNonStriker(String id) async =>
      FeaturedMatchService.setNonStriker(id);
  Future<void> _changeBowler(String id) async =>
      FeaturedMatchService.setCurrentBowler(id);

  Future<void> _endOver({
    required String bowlerId,
    required String battingTeamKey,
    required Map<String, dynamic> bowlTeam,
    required BuildContext context,
  }) async {
    if (_processing) return;
    setState(() => _processing = true);
    try {
      await _completeOver(bowlerId: bowlerId, battingTeamKey: battingTeamKey);
      await FeaturedMatchService.rotateStrike();
      setState(() => _ballLog.clear());
      if (context.mounted)
        await _showChangeBowlerDialog(
            context: context, bowlTeam: bowlTeam, currentBowlerId: bowlerId);
    } finally {
      if (mounted) setState(() => _processing = false);
    }
  }

  // ── FIX 2: Undo — RTDB only for live data ────────────────
  Future<void> _undo({required Map<String, dynamic> fullData}) async {
    if (_undoSnapshot == null || _processing) return;
    setState(() => _processing = true);
    try {
      final snap = _undoSnapshot!;

      // Restore RTDB live fields
      final snapScores = snap['scores'];
      final snapPlayerStats = snap['playerStats'];
      final snapCurrentOver = snap['currentOver'] ?? [];
      final snapLiveMatch = snap['liveMatch'];

      await Future.wait([
        if (snapScores != null)
          FirebaseDatabase.instance
              .ref('featured_match/admin_current/scores')
              .set(snapScores),
        if (snapPlayerStats != null)
          FirebaseDatabase.instance
              .ref('featured_match/admin_current/playerStats')
              .set(snapPlayerStats),
        FirebaseDatabase.instance
            .ref('featured_match/admin_current/currentOver')
            .set(snapCurrentOver),
        if (snapLiveMatch != null)
          FirebaseDatabase.instance
              .ref('featured_match/admin_current/liveMatch')
              .set(snapLiveMatch),
      ]);

      // Restore only static Firestore fields
      final firestoreSnap = <String, dynamic>{};
      if (snap['meta'] != null) firestoreSnap['meta'] = snap['meta'];
      if (snap['toss'] != null) firestoreSnap['toss'] = snap['toss'];
      if (snap['teams'] != null) firestoreSnap['teams'] = snap['teams'];
      if (snap['ai_prediction'] != null)
        firestoreSnap['ai_prediction'] = snap['ai_prediction'];
      if (snap['winProbability'] != null)
        firestoreSnap['winProbability'] = snap['winProbability'];

      if (firestoreSnap.isNotEmpty) {
        await FirebaseFirestore.instance
            .collection('featured_match')
            .doc('admin_current')
            .set(firestoreSnap, SetOptions(merge: true));
      }

      setState(() {
        _undoSnapshot = null;
        if (_ballLog.isNotEmpty) _ballLog.removeAt(0);
      });
    } finally {
      if (mounted) setState(() => _processing = false);
    }
  }

  Future<void> _endMatch() async =>
      FeaturedMatchService.updateStatus('completed');

  // ════════════════════════════════════════════════════════
  //  TEST DIALOGS
  // ════════════════════════════════════════════════════════

  Future<void> _showDayDialog(BuildContext context, int currentDay) async {
    final newDay = await showDialog<int>(
      context: context,
      builder: (_) => _DayPickerDialog(currentDay: currentDay),
    );
    if (newDay != null) await FeaturedMatchService.setDay(newDay);
  }

  Future<void> _showTestInningsSwitchDialog({
    required BuildContext context,
    required Map<String, dynamic> teams,
    required String battingTeamKey,
    required String bowlingTeamKey,
    required int innings,
    required Map<String, dynamic> scores,
    required String format,
    required bool canFollowOn,
  }) async {
    final nextInnings = innings + 1;
    final normalNextBat = innings % 2 == 0 ? 'teamA' : 'teamB';
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _TestInningsSwitchDialog(
        teams: teams,
        currentInnings: innings,
        normalNextBatTeamKey: normalNextBat,
        canFollowOn: canFollowOn,
        followOnTeamKey: bowlingTeamKey,
        scores: scores,
      ),
    );
    if (result == null) return;
    setState(() => _processing = true);
    try {
      final action = result['action'] as String;
      final striker = result['striker'] as String;
      final nonStriker = result['nonStriker'] as String;
      final bowler = result['bowler'] as String;
      if (action == 'declare') {
        final nextBatTeam = normalNextBat;
        final nextBowlTeam = nextBatTeam == 'teamA' ? 'teamB' : 'teamA';
        int? targetRuns;
        if (nextInnings == 4)
          targetRuns = _calculateTestTarget(scores, battingTeamKey);
        await FeaturedMatchService.declareBattingInnings(
          declaringTeam: battingTeamKey,
          currentInnings: innings,
          newStriker: striker,
          newNonStriker: nonStriker,
          newBowler: bowler,
          nextBattingTeam: nextBatTeam,
          nextBowlingTeam: nextBowlTeam,
          nextInnings: nextInnings,
          targetRuns: targetRuns,
        );
      } else if (action == 'follow_on') {
        await FeaturedMatchService.enforceFollowOn(
          newStriker: striker,
          newNonStriker: nonStriker,
          newBowler: bowler,
          followOnTeam: bowlingTeamKey,
          bowlingTeam: battingTeamKey,
        );
      } else if (action == 'normal' && nextInnings == 4) {
        final target = _calculateTestTarget(scores, battingTeamKey);
        await FeaturedMatchService.switchToFinalTestInnings(
          newStriker: striker,
          newNonStriker: nonStriker,
          newBowler: bowler,
          chasingTeam: normalNextBat,
          bowlingTeam: normalNextBat == 'teamA' ? 'teamB' : 'teamA',
          targetRuns: target,
        );
      } else {
        await FeaturedMatchService.switchTestInnings(
          newStriker: striker,
          newNonStriker: nonStriker,
          newBowler: bowler,
          nextInnings: nextInnings,
          nextBattingTeam: normalNextBat,
          nextBowlingTeam: normalNextBat == 'teamA' ? 'teamB' : 'teamA',
        );
      }
      setState(() => _ballLog.clear());
    } finally {
      if (mounted) setState(() => _processing = false);
    }
  }

  int _calculateTestTarget(
      Map<String, dynamic> scores, String currentBattingTeam) {
    final oppTeam = currentBattingTeam == 'teamA' ? 'teamB' : 'teamA';
    final inn1 = scores['${oppTeam}_inn1'] as Map? ?? {};
    final inn2 = scores['${oppTeam}_inn2'] as Map? ?? {};
    final oppTotal =
        ((inn1['runs'] as int?) ?? 0) + ((inn2['runs'] as int?) ?? 0);
    final myInn1 = scores['${currentBattingTeam}_inn1'] as Map? ?? {};
    final myRuns = (myInn1['runs'] as int?) ?? 0;
    return oppTotal - myRuns + 1;
  }

  Future<void> _showTestEndMatchDialog(
      {required BuildContext context, required int innings}) async {
    final result = await showDialog<String>(
        context: context, builder: (_) => const _TestEndMatchDialog());
    if (result == null) return;
    switch (result) {
      case 'stumps':
        await FeaturedMatchService.callStumps();
        break;
      case 'resume':
        await FeaturedMatchService.resumeFromStumps();
        break;
      case 'draw':
        await FeaturedMatchService.endTestMatchDraw();
        break;
      case 'win':
        await FeaturedMatchService.updateStatus('completed');
        break;
    }
  }

  // ════════════════════════════════════════════════════════
  //  STANDARD DIALOGS
  // ════════════════════════════════════════════════════════

  Future<void> _showResetDialog(BuildContext context) async {
    final confirm = await showDialog<bool>(
        context: context, builder: (_) => const _ResetDialog());
    if (confirm == true) {
      await FeaturedMatchService.resetMatch();
      if (mounted) setState(() => _ballLog.clear());
    }
  }

  Future<void> _showWicketDialog({
    required BuildContext context,
    required String strikerId,
    required String nonStrikerId,
    required String bowlerId,
    required String battingTeamKey,
    required Map<String, dynamic> batTeam,
    required Map<String, dynamic> bowlTeam,
    required int overs,
    required int balls,
    required int innings,
    required bool hasTarget,
    required int runsNeeded,
    required int ballsRemaining,
    required Map<String, dynamic> fullData,
  }) async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => _WicketDialog(
          batTeam: batTeam, strikerId: strikerId, nonStrikerId: nonStrikerId),
    );
    if (result == null) return;
    final snapshotWithRtdb2 = {
      ...fullData,
      'scores': Map<String, dynamic>.from(_rtdb.scores),
      'playerStats': Map<String, dynamic>.from(_rtdb.playerStats),
      'liveMatch': Map<String, dynamic>.from(_rtdb.live),
      'currentOver': List<Map<String, dynamic>>.from(_rtdb.currentOver),
    };
    setState(() {
      _processing = true;
      _undoSnapshot = snapshotWithRtdb2;
    });
    try {
      final dismissal = result['dismissal'] as String;
      final newBatsman = result['newBatsman'] as String;
      final runsOnBall = (result['runs'] as int?) ?? 0;
      final dismissedBatsmanId =
          result['dismissedBatsmanId'] as String? ?? strikerId;
      final strikerFacesNext = result['strikerFacesNext'] as bool?;
      final currentOver = _rtdb.currentOver;
      final targetMap = _targetMapFromData(fullData);

      await FeaturedMatchService.recordWicket(
        battingTeamKey: battingTeamKey,
        strikerId: dismissedBatsmanId,
        bowlerId: bowlerId,
        newBatsmanId: newBatsman,
        dismissal: dismissal,
        runsOnBall: runsOnBall,
        currentOver: currentOver,
        runsNeeded: hasTarget ? runsNeeded - runsOnBall : null,
        ballsRemaining: hasTarget ? ballsRemaining - 1 : null,
        targetMap: hasTarget ? targetMap : null,
      );

      final newBalls = balls + 1;
      if (newBalls >= 6) {
        await _completeOver(bowlerId: bowlerId, battingTeamKey: battingTeamKey);
        if (dismissal == 'run out' && strikerFacesNext != null) {
          final needsRotation = (dismissedBatsmanId == strikerId)
              ? !strikerFacesNext
              : strikerFacesNext;
          if (needsRotation) await FeaturedMatchService.rotateStrike();
        } else {
          if (runsOnBall % 2 == 0) await FeaturedMatchService.rotateStrike();
        }
        setState(() => _ballLog.clear());
        if (context.mounted)
          await _showChangeBowlerDialog(
              context: context, bowlTeam: bowlTeam, currentBowlerId: bowlerId);
      } else {
        if (dismissal == 'run out' && strikerFacesNext != null) {
          final needsRotation = (dismissedBatsmanId == strikerId)
              ? !strikerFacesNext
              : strikerFacesNext;
          if (needsRotation) await FeaturedMatchService.rotateStrike();
        } else {
          if (runsOnBall % 2 != 0) await FeaturedMatchService.rotateStrike();
        }
        setState(() => _ballLog.insert(0,
            {'type': 'wicket', 'value': runsOnBall, 'dismissal': dismissal}));
      }
    } finally {
      if (mounted) setState(() => _processing = false);
    }
  }

  Future<void> _showChangeBowlerDialog({
    required BuildContext context,
    required Map<String, dynamic> bowlTeam,
    required String currentBowlerId,
  }) async {
    final newBowlerId = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _ChangeBowlerDialog(
          bowlTeam: bowlTeam, currentBowlerId: currentBowlerId),
    );
    if (newBowlerId != null)
      await FeaturedMatchService.setCurrentBowler(newBowlerId);
  }

  Future<void> _showSwitchInningsDialog({
    required BuildContext context,
    required Map<String, dynamic> teams,
    required String battingTeamKey,
    required String bowlingTeamKey,
    required String format,
    required Map<String, dynamic> fullData,
  }) async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      barrierDismissible: false,
      builder: (_) =>
          _SwitchInningsDialog(teams: teams, newBattingTeamKey: bowlingTeamKey),
    );
    if (result == null) return;
    setState(() => _processing = true);
    try {
      final scores = _rtdb.scores;
      final firstInningsScore =
          scores[battingTeamKey] as Map<String, dynamic>? ?? {};
      final firstInningsRuns = (firstInningsScore['runs'] as int?) ?? 0;
      final totalBalls = _totalBallsForFormat(format);
      await FeaturedMatchService.switchInnings(
        newStriker: result['striker'] as String,
        newNonStriker: result['nonStriker'] as String,
        newBowler: result['bowler'] as String,
        targetRuns: firstInningsRuns + 1,
        totalBalls: totalBalls,
      );
      await Future.delayed(const Duration(seconds: 10));
      await FeaturedMatchService.clearCurrentOver();
      setState(() => _ballLog.clear());
    } finally {
      if (mounted) setState(() => _processing = false);
    }
  }

  Future<void> _showSuperOverSwitchDialog({
    required BuildContext context,
    required Map<String, dynamic> teams,
    required String battingTeamKey,
    required String bowlingTeamKey,
    required int runs,
  }) async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _SwitchInningsDialog(
          teams: teams,
          newBattingTeamKey: bowlingTeamKey,
          title: 'Super Over — 2nd Innings'),
    );
    if (result == null) return;
    setState(() => _processing = true);
    try {
      await FeaturedMatchService.switchSuperOverInnings(
        newStriker: result['striker'] as String,
        newNonStriker: result['nonStriker'] as String,
        newBowler: result['bowler'] as String,
        targetRuns: runs + 1,
      );
      await Future.delayed(const Duration(seconds: 10));
      await FeaturedMatchService.clearCurrentOver();
      setState(() => _ballLog.clear());
    } finally {
      if (mounted) setState(() => _processing = false);
    }
  }

  Future<void> _showSuperOverSetupDialog({
    required BuildContext context,
    required Map<String, dynamic> teams,
    required String battingTeamKey,
    required String bowlingTeamKey,
  }) async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _SwitchInningsDialog(
          teams: teams,
          newBattingTeamKey: bowlingTeamKey,
          title: 'Super Over Setup'),
    );
    if (result == null) return;
    setState(() => _processing = true);
    try {
      await FeaturedMatchService.startSuperOver(
        newStriker: result['striker'] as String,
        newNonStriker: result['nonStriker'] as String,
        newBowler: result['bowler'] as String,
        battingTeamKey: bowlingTeamKey,
        bowlingTeamKey: battingTeamKey,
      );
      await Future.delayed(const Duration(seconds: 10));
      await FeaturedMatchService.clearCurrentOver();
      setState(() => _ballLog.clear());
    } finally {
      if (mounted) setState(() => _processing = false);
    }
  }

  int _totalBallsForFormat(String format) {
    switch (format.toLowerCase()) {
      case 'odi':
        return 300;
      case 'test':
        return 0;
      case 't10':
        return 60;
      default:
        return 120;
    }
  }
}

// ════════════════════════════════════════════════════════════
//  ALL WIDGETS — unchanged from original
// ════════════════════════════════════════════════════════════

class _Scoreboard extends StatelessWidget {
  final String batTeamName,
      batTeamLogo,
      batTeamId,
      bowlTeamName,
      bowlTeamLogo,
      status;
  final int runs, wickets, overs, balls, innings, ballsRemaining;
  final bool isSuperOver, isTest;
  final int day;
  final int? target;
  final TestLeadInfo? leadInfo;
  final VoidCallback onReset;
  final VoidCallback? onDayChange;

  const _Scoreboard({
    required this.batTeamName,
    required this.batTeamLogo,
    required this.batTeamId,
    required this.bowlTeamName,
    required this.bowlTeamLogo,
    required this.runs,
    required this.wickets,
    required this.overs,
    required this.balls,
    required this.innings,
    required this.status,
    required this.isSuperOver,
    required this.isTest,
    required this.day,
    required this.target,
    required this.ballsRemaining,
    required this.leadInfo,
    required this.onReset,
    this.onDayChange,
  });

  @override
  Widget build(BuildContext context) {
    final need = target != null ? target! - runs : null;
    final remOv = ballsRemaining ~/ 6;
    final remBalls = ballsRemaining % 6;
    return Container(
      height: isTest ? 100 : 90,
      decoration: const BoxDecoration(
          color: _surface, border: Border(bottom: BorderSide(color: _border))),
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Row(children: [
        _TeamTag(name: batTeamName, logo: batTeamLogo, teamId: batTeamId),
        const SizedBox(width: 20),
        Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text('$runs',
                  style: const TextStyle(
                      color: _textPrimary,
                      fontSize: 38,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -2,
                      height: 1)),
              Padding(
                padding: const EdgeInsets.only(bottom: 5),
                child: Text('/$wickets',
                    style: const TextStyle(
                        color: _textSecondary,
                        fontSize: 22,
                        fontWeight: FontWeight.w400,
                        letterSpacing: -1)),
              ),
              const SizedBox(width: 14),
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text('($overs.$balls ov)',
                    style:
                        const TextStyle(color: _textSecondary, fontSize: 14)),
              ),
            ]),
            if (isTest && leadInfo != null)
              _LeadTrailChip(leadInfo: leadInfo!)
            else if (isSuperOver)
              Container(
                margin: const EdgeInsets.only(top: 2),
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                    color: Colors.amber.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: Colors.amber.withOpacity(0.3))),
                child: const Text('⚡ SUPER OVER',
                    style: TextStyle(
                        color: Colors.amber,
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1)),
              )
            else if (target != null && need != null)
              Text('Need $need from $remOv.$remBalls ov',
                  style: const TextStyle(
                      color: Colors.amber,
                      fontSize: 11,
                      fontWeight: FontWeight.w600)),
          ],
        ),
        const Spacer(),
        _ResetButton(onReset: onReset),
        const SizedBox(width: 16),
        Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            _StatusBadge(status: status),
            const SizedBox(height: 6),
            if (isTest)
              GestureDetector(
                onTap: onDayChange,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                      color: Colors.amber.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(5),
                      border:
                          Border.all(color: Colors.amber.withOpacity(0.25))),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Text('DAY $day',
                        style: const TextStyle(
                            color: Colors.amber,
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1)),
                    const SizedBox(width: 4),
                    const Icon(Icons.edit_rounded,
                        color: Colors.amber, size: 9),
                  ]),
                ),
              )
            else
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                    color: _surface2,
                    borderRadius: BorderRadius.circular(5),
                    border: Border.all(color: _border)),
                child: Text(
                    isSuperOver
                        ? 'SUPER OVER · INN $innings'
                        : 'INNINGS $innings',
                    style: const TextStyle(
                        color: _textSecondary,
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1)),
              ),
            const SizedBox(height: 4),
            if (isTest)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                    color: _surface2,
                    borderRadius: BorderRadius.circular(5),
                    border: Border.all(color: _border)),
                child: Text('INN $innings / 4',
                    style: const TextStyle(
                        color: _textSecondary,
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1)),
              ),
          ],
        ),
        const SizedBox(width: 20),
        _TeamTag(
            name: bowlTeamName, logo: bowlTeamLogo, teamId: '', muted: true),
      ]),
    );
  }
}

class _LeadTrailChip extends StatelessWidget {
  final TestLeadInfo leadInfo;
  const _LeadTrailChip({required this.leadInfo});
  @override
  Widget build(BuildContext context) {
    final bool isLeading = leadInfo.runs > 0 && leadInfo.leadTeam.isNotEmpty;
    final color = leadInfo.runs == 0
        ? _textSecondary
        : isLeading
            ? const Color(0xFF4CAF50)
            : Colors.redAccent;
    return Container(
      margin: const EdgeInsets.only(top: 4),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(5),
          border: Border.all(color: color.withOpacity(0.3))),
      child: Text(leadInfo.text,
          style: TextStyle(
              color: color,
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.3)),
    );
  }
}

class _BallInput extends StatelessWidget {
  final bool processing, canUndo, isSuperOver, isTest;
  final List<Map<String, dynamic>> ballLog;
  final int overs, balls;
  final ValueChanged<int> onRun;
  final VoidCallback onWide, onNoBall, onLegBye, onWicket, onUndo, onEndOver;
  final VoidCallback? onSwitchInnings, onEndMatch;
  final String? onEndMatchLabel, onSwitchInningsLabel;

  const _BallInput({
    required this.processing,
    required this.canUndo,
    required this.ballLog,
    required this.overs,
    required this.balls,
    required this.isSuperOver,
    required this.isTest,
    required this.onRun,
    required this.onWide,
    required this.onNoBall,
    required this.onLegBye,
    required this.onWicket,
    required this.onUndo,
    required this.onEndOver,
    required this.onSwitchInnings,
    required this.onEndMatch,
    this.onEndMatchLabel,
    this.onSwitchInningsLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _OverProgress(overs: overs, balls: balls, isSuperOver: isSuperOver),
          const SizedBox(height: 28),
          const Text('RUNS',
              style: TextStyle(
                  color: _textMuted,
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2)),
          const SizedBox(height: 12),
          Row(
              children: [0, 1, 2, 3, 4, 6]
                  .map((r) => Expanded(
                        child: Padding(
                          padding: EdgeInsets.only(right: r == 6 ? 0 : 8),
                          child: _RunButton(
                              runs: r,
                              processing: processing,
                              onTap: () => onRun(r)),
                        ),
                      ))
                  .toList()),
          const SizedBox(height: 20),
          const Text('EXTRAS & EVENTS',
              style: TextStyle(
                  color: _textMuted,
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2)),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(
                child: _EventButton(
                    label: 'Wide',
                    icon: Icons.arrow_outward_rounded,
                    color: Colors.blueAccent,
                    processing: processing,
                    onTap: onWide)),
            const SizedBox(width: 8),
            Expanded(
                child: _EventButton(
                    label: 'No Ball',
                    icon: Icons.cancel_outlined,
                    color: Colors.orangeAccent,
                    processing: processing,
                    onTap: onNoBall)),
            const SizedBox(width: 8),
            Expanded(
                child: _EventButton(
                    label: 'Leg Bye',
                    icon: Icons.directions_run_rounded,
                    color: Colors.purpleAccent,
                    processing: processing,
                    onTap: onLegBye)),
          ]),
          const SizedBox(height: 8),
          _EventButton(
              label: 'WICKET',
              icon: Icons.close_rounded,
              color: Colors.redAccent,
              processing: processing,
              onTap: onWicket,
              large: true,
              fullWidth: true),
          const Spacer(),
          const Text('OVER MANAGEMENT',
              style: TextStyle(
                  color: _textMuted,
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2)),
          const SizedBox(height: 12),
          Row(children: [
            _ManagementButton(
                label: 'Undo',
                icon: Icons.undo_rounded,
                enabled: canUndo && !processing,
                onTap: onUndo),
            const SizedBox(width: 10),
            Expanded(
                child: _ManagementButton(
                    label: 'End Over',
                    icon: Icons.skip_next_rounded,
                    enabled: !processing,
                    onTap: onEndOver,
                    primary: true)),
          ]),
          if (onSwitchInnings != null || onEndMatch != null) ...[
            const SizedBox(height: 10),
            if (onSwitchInnings != null)
              _ManagementButton(
                  label: onSwitchInningsLabel ??
                      (isSuperOver
                          ? '⚡ Super Over — 2nd Innings'
                          : '2nd Innings — Switch'),
                  icon: Icons.swap_vert_rounded,
                  enabled: !processing,
                  onTap: onSwitchInnings!,
                  full: true,
                  accent: Colors.amber),
            if (onEndMatch != null) ...[
              const SizedBox(height: 8),
              _ManagementButton(
                  label: onEndMatchLabel ?? 'End Match',
                  icon: isTest
                      ? Icons.flag_rounded
                      : (onEndMatchLabel != null &&
                              onEndMatchLabel!.contains('Super'))
                          ? Icons.bolt_rounded
                          : Icons.flag_rounded,
                  enabled: !processing,
                  onTap: onEndMatch!,
                  full: true,
                  accent: isTest
                      ? _textSecondary
                      : (onEndMatchLabel != null &&
                              onEndMatchLabel!.contains('Super'))
                          ? Colors.amber
                          : _textSecondary),
            ],
          ],
        ],
      ),
    );
  }
}

class _OverProgress extends StatelessWidget {
  final int overs, balls;
  final bool isSuperOver;
  const _OverProgress(
      {required this.overs, required this.balls, required this.isSuperOver});
  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Text(isSuperOver ? 'SUPER OVER' : 'THIS OVER',
            style: TextStyle(
                color: isSuperOver ? Colors.amber : _textMuted,
                fontSize: 9,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.2)),
        const Spacer(),
        Text(
            isSuperOver
                ? '$balls/6 balls'
                : 'Over ${overs + 1}  ·  $balls/6 balls',
            style: const TextStyle(color: _textSecondary, fontSize: 11)),
      ]),
      const SizedBox(height: 10),
      Row(
          children: List.generate(
              6,
              (i) => Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(right: i < 5 ? 6 : 0),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        height: 6,
                        decoration: BoxDecoration(
                          color: i < balls
                              ? (isSuperOver ? Colors.amber : Colors.redAccent)
                              : _surface3,
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                    ),
                  ))),
    ]);
  }
}

class _RunButton extends StatefulWidget {
  final int runs;
  final bool processing;
  final VoidCallback onTap;
  const _RunButton(
      {required this.runs, required this.processing, required this.onTap});
  @override
  State<_RunButton> createState() => _RunButtonState();
}

class _RunButtonState extends State<_RunButton> {
  bool _pressed = false, _hovered = false;
  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: widget.processing
          ? SystemMouseCursors.wait
          : SystemMouseCursors.click,
      child: GestureDetector(
        onTapDown: (_) => setState(() => _pressed = true),
        onTapUp: (_) => setState(() => _pressed = false),
        onTapCancel: () => setState(() => _pressed = false),
        onTap: widget.processing ? null : widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 80),
          height: 72,
          transform:
              _pressed ? (Matrix4.identity()..scale(0.94)) : Matrix4.identity(),
          decoration: BoxDecoration(
            color: _pressed
                ? _surface3
                : _hovered
                    ? _surface2
                    : _surface,
            borderRadius: BorderRadius.circular(14),
            border:
                Border.all(color: _hovered && !_pressed ? _border2 : _border),
          ),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Text(
              widget.runs == 0 ? '·' : '${widget.runs}',
              style: TextStyle(
                color: widget.runs == 4
                    ? const Color(0xFF4FC3F7)
                    : widget.runs == 6
                        ? const Color(0xFF81C784)
                        : widget.runs == 0
                            ? _textMuted
                            : _textPrimary,
                fontSize: widget.runs == 0 ? 28 : 26,
                fontWeight: FontWeight.w800,
                height: 1,
              ),
            ),
            if (widget.runs == 4 || widget.runs == 6)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(widget.runs == 4 ? 'FOUR' : 'SIX',
                    style: TextStyle(
                        color: (widget.runs == 4
                                ? const Color(0xFF4FC3F7)
                                : const Color(0xFF81C784))
                            .withOpacity(0.7),
                        fontSize: 8,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.8)),
              ),
          ]),
        ),
      ),
    );
  }
}

class _EventButton extends StatefulWidget {
  final String label;
  final IconData icon;
  final Color color;
  final bool processing, large, fullWidth;
  final VoidCallback onTap;
  const _EventButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.processing,
    required this.onTap,
    this.large = false,
    this.fullWidth = false,
  });
  @override
  State<_EventButton> createState() => _EventButtonState();
}

class _EventButtonState extends State<_EventButton> {
  bool _hovered = false, _pressed = false;
  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: widget.processing
          ? SystemMouseCursors.wait
          : SystemMouseCursors.click,
      child: GestureDetector(
        onTapDown: (_) => setState(() => _pressed = true),
        onTapUp: (_) => setState(() => _pressed = false),
        onTapCancel: () => setState(() => _pressed = false),
        onTap: widget.processing ? null : widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 80),
          height: 56,
          width: widget.fullWidth ? double.infinity : null,
          transform:
              _pressed ? (Matrix4.identity()..scale(0.95)) : Matrix4.identity(),
          decoration: BoxDecoration(
            color:
                _pressed || _hovered ? widget.color.withOpacity(0.1) : _surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
                color: _hovered
                    ? widget.color.withOpacity(0.4)
                    : widget.color.withOpacity(0.2)),
          ),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(widget.icon, color: widget.color, size: 16),
            const SizedBox(width: 7),
            Text(widget.label,
                style: TextStyle(
                    color: widget.color,
                    fontSize: widget.large ? 14 : 12,
                    fontWeight: FontWeight.w700)),
          ]),
        ),
      ),
    );
  }
}

class _ManagementButton extends StatefulWidget {
  final String label;
  final IconData icon;
  final bool enabled, primary, full;
  final Color? accent;
  final VoidCallback onTap;
  const _ManagementButton({
    required this.label,
    required this.icon,
    required this.enabled,
    required this.onTap,
    this.primary = false,
    this.full = false,
    this.accent,
  });
  @override
  State<_ManagementButton> createState() => _ManagementButtonState();
}

class _ManagementButtonState extends State<_ManagementButton> {
  bool _hovered = false;
  @override
  Widget build(BuildContext context) {
    final color =
        widget.accent ?? (widget.primary ? Colors.redAccent : _textSecondary);
    return MouseRegion(
      onEnter: (_) => widget.enabled ? setState(() => _hovered = true) : null,
      onExit: (_) => setState(() => _hovered = false),
      cursor: widget.enabled
          ? SystemMouseCursors.click
          : SystemMouseCursors.forbidden,
      child: GestureDetector(
        onTap: widget.enabled ? widget.onTap : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 130),
          width: widget.full ? double.infinity : null,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: widget.primary && _hovered
                ? color.withOpacity(0.12)
                : _hovered
                    ? _surface2
                    : _surface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
                color: _hovered
                    ? (widget.primary ? color.withOpacity(0.4) : _border2)
                    : _border),
          ),
          child: Row(
            mainAxisSize: widget.full ? MainAxisSize.max : MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(widget.icon,
                  color: widget.enabled ? color : _textMuted, size: 15),
              const SizedBox(width: 8),
              Text(widget.label,
                  style: TextStyle(
                      color: widget.enabled ? color : _textMuted,
                      fontSize: 12,
                      fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ),
    );
  }
}

class _PlayersPanel extends StatelessWidget {
  final Map<String, dynamic>? striker, nonStriker, bowler;
  final Map<String, dynamic> strikerStat, nonStrikerStat, bowlerStat;
  final String strikerId;
  final Map<String, dynamic> batTeam, bowlTeam;
  final String battingTeamKey, bowlingTeamKey;
  final List<Map<String, dynamic>> allPlayers;
  final bool processing;
  final ValueChanged<String> onStrikerChange,
      onNonStrikerChange,
      onBowlerChange;
  final VoidCallback onRotateStrike;

  const _PlayersPanel({
    required this.striker,
    required this.nonStriker,
    required this.bowler,
    required this.strikerStat,
    required this.nonStrikerStat,
    required this.bowlerStat,
    required this.strikerId,
    required this.batTeam,
    required this.bowlTeam,
    required this.battingTeamKey,
    required this.bowlingTeamKey,
    required this.allPlayers,
    required this.processing,
    required this.onStrikerChange,
    required this.onNonStrikerChange,
    required this.onBowlerChange,
    required this.onRotateStrike,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
          border: Border(right: BorderSide(color: _border))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _PanelHeader(
            icon: Icons.sports_cricket_rounded,
            label: 'AT THE CREASE',
            trailing:
                _RotateButton(onTap: processing ? () {} : onRotateStrike)),
        _BatsmanTile(
            label: 'STRIKER  ★',
            labelColor: Colors.amber,
            player: striker,
            stat: strikerStat,
            isStriker: true),
        const _Divider(),
        _BatsmanTile(
            label: 'NON-STRIKER',
            player: nonStriker,
            stat: nonStrikerStat,
            isStriker: false),
        const _Divider(thick: true),
        _PanelHeader(icon: Icons.trip_origin_rounded, label: 'BOWLING'),
        _BowlerTile(player: bowler, stat: bowlerStat),
        const Spacer(),
        _QuickChangeBar(
            batTeam: batTeam,
            bowlTeam: bowlTeam,
            onStrikerChange: onStrikerChange,
            onNonStrikerChange: onNonStrikerChange,
            onBowlerChange: onBowlerChange),
      ]),
    );
  }
}

class _PanelHeader extends StatelessWidget {
  final IconData icon;
  final String label;
  final Widget? trailing;
  const _PanelHeader({required this.icon, required this.label, this.trailing});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: _border))),
      child: Row(children: [
        Icon(icon, color: _textMuted, size: 11),
        const SizedBox(width: 6),
        Text(label,
            style: const TextStyle(
                color: _textSecondary,
                fontSize: 9,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.2)),
        if (trailing != null) ...[const Spacer(), trailing!],
      ]),
    );
  }
}

class _BatsmanTile extends StatelessWidget {
  final String label;
  final Color? labelColor;
  final Map<String, dynamic>? player;
  final Map<String, dynamic> stat;
  final bool isStriker;
  const _BatsmanTile(
      {required this.label,
      required this.player,
      required this.stat,
      required this.isStriker,
      this.labelColor});
  @override
  Widget build(BuildContext context) {
    final name = player?['name'] as String? ?? '—';
    final runs = (stat['runs'] as int?) ?? 0;
    final balls = (stat['balls'] as int?) ?? 0;
    final fours = (stat['fours'] as int?) ?? 0;
    final sixes = (stat['sixes'] as int?) ?? 0;
    final sr = balls > 0 ? (runs / balls * 100).toStringAsFixed(1) : '0.0';
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color:
              isStriker ? Colors.amber.withOpacity(0.03) : Colors.transparent),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label,
            style: TextStyle(
                color: labelColor ?? _textMuted,
                fontSize: 8,
                fontWeight: FontWeight.w700,
                letterSpacing: 1)),
        const SizedBox(height: 6),
        Row(children: [
          Expanded(
              child: Text(name,
                  style: const TextStyle(
                      color: _textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w700),
                  overflow: TextOverflow.ellipsis)),
          Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text('$runs',
                style: const TextStyle(
                    color: _textPrimary,
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -1,
                    height: 1)),
            Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: Text(' ($balls)',
                    style:
                        const TextStyle(color: _textSecondary, fontSize: 12))),
          ]),
        ]),
        const SizedBox(height: 8),
        Row(children: [
          _MiniStat(label: '4s', value: '$fours'),
          const SizedBox(width: 12),
          _MiniStat(label: '6s', value: '$sixes'),
          const SizedBox(width: 12),
          _MiniStat(label: 'SR', value: sr),
        ]),
      ]),
    );
  }
}

class _BowlerTile extends StatelessWidget {
  final Map<String, dynamic>? player;
  final Map<String, dynamic> stat;
  const _BowlerTile({required this.player, required this.stat});
  @override
  Widget build(BuildContext context) {
    final name = player?['name'] as String? ?? '—';
    final overs = (stat['overs'] as int?) ?? 0;
    final ballsBowled = (stat['ballsBowled'] as int?) ?? 0;
    final wickets = (stat['wickets'] as int?) ?? 0;
    final runsConceded = (stat['runsConceded'] as int?) ?? 0;
    final wides = (stat['wides'] as int?) ?? 0;
    final noBalls = (stat['noBalls'] as int?) ?? 0;
    final totalBalls = overs * 6 + ballsBowled;
    final econ = totalBalls > 0
        ? (runsConceded / totalBalls * 6).toStringAsFixed(2)
        : '0.00';
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('CURRENT',
            style: TextStyle(
                color: _textMuted,
                fontSize: 8,
                fontWeight: FontWeight.w700,
                letterSpacing: 1)),
        const SizedBox(height: 6),
        Row(children: [
          Expanded(
              child: Text(name,
                  style: const TextStyle(
                      color: _textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w700),
                  overflow: TextOverflow.ellipsis)),
          Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text('$wickets',
                style: const TextStyle(
                    color: _textPrimary,
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    height: 1)),
            Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: Text('-$runsConceded',
                    style:
                        const TextStyle(color: _textSecondary, fontSize: 14))),
          ]),
        ]),
        const SizedBox(height: 8),
        Row(children: [
          _MiniStat(label: 'OV', value: '$overs.$ballsBowled'),
          const SizedBox(width: 12),
          _MiniStat(label: 'ECON', value: econ),
          const SizedBox(width: 12),
          _MiniStat(label: 'WD', value: '$wides'),
          const SizedBox(width: 12),
          _MiniStat(label: 'NB', value: '$noBalls'),
        ]),
      ]),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final String label, value;
  const _MiniStat({required this.label, required this.value});
  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label,
          style: const TextStyle(
              color: _textMuted,
              fontSize: 8,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5)),
      Text(value,
          style: const TextStyle(
              color: _textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w600)),
    ]);
  }
}

class _RotateButton extends StatefulWidget {
  final VoidCallback onTap;
  const _RotateButton({required this.onTap});
  @override
  State<_RotateButton> createState() => _RotateButtonState();
}

class _RotateButtonState extends State<_RotateButton> {
  bool _hovered = false;
  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 130),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: _hovered ? _surface3 : Colors.transparent,
            borderRadius: BorderRadius.circular(5),
            border: Border.all(color: _hovered ? _border2 : Colors.transparent),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.swap_horiz_rounded,
                color: _hovered ? _textSecondary : _textMuted, size: 12),
            const SizedBox(width: 4),
            Text('Rotate',
                style: TextStyle(
                    color: _hovered ? _textSecondary : _textMuted,
                    fontSize: 10)),
          ]),
        ),
      ),
    );
  }
}

class _QuickChangeBar extends StatelessWidget {
  final Map<String, dynamic> batTeam, bowlTeam;
  final ValueChanged<String> onStrikerChange,
      onNonStrikerChange,
      onBowlerChange;
  const _QuickChangeBar(
      {required this.batTeam,
      required this.bowlTeam,
      required this.onStrikerChange,
      required this.onNonStrikerChange,
      required this.onBowlerChange});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: _border)), color: _surface),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('QUICK CHANGE',
            style: TextStyle(
                color: _textMuted,
                fontSize: 8,
                fontWeight: FontWeight.w700,
                letterSpacing: 1)),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(
              child: _QuickBtn(
                  label: 'New Striker',
                  icon: Icons.sports_cricket_rounded,
                  onTap: () => _showPicker(
                      context, 'New Striker', batTeam, onStrikerChange))),
          const SizedBox(width: 6),
          Expanded(
              child: _QuickBtn(
                  label: 'New Bowler',
                  icon: Icons.trip_origin_rounded,
                  onTap: () => _showPicker(
                      context, 'New Bowler', bowlTeam, onBowlerChange))),
        ]),
      ]),
    );
  }

  void _showPicker(BuildContext context, String title,
      Map<String, dynamic> team, ValueChanged<String> onSelect) {
    showDialog(
        context: context,
        builder: (_) =>
            _PlayerPickerDialog(title: title, team: team, onSelect: onSelect));
  }
}

class _QuickBtn extends StatefulWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  const _QuickBtn(
      {required this.label, required this.icon, required this.onTap});
  @override
  State<_QuickBtn> createState() => _QuickBtnState();
}

class _QuickBtnState extends State<_QuickBtn> {
  bool _hovered = false;
  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 130),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: _hovered ? _surface3 : _surface2,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: _hovered ? _border2 : _border),
          ),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(widget.icon, color: _textMuted, size: 12),
            const SizedBox(width: 6),
            Text(widget.label,
                style: const TextStyle(
                    color: _textSecondary,
                    fontSize: 11,
                    fontWeight: FontWeight.w500)),
          ]),
        ),
      ),
    );
  }
}

class _OverPanel extends StatelessWidget {
  final List<Map<String, dynamic>> ballLog;
  final int overs, balls;
  final String bowlerName;
  const _OverPanel(
      {required this.ballLog,
      required this.overs,
      required this.balls,
      required this.bowlerName});
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration:
          const BoxDecoration(border: Border(left: BorderSide(color: _border))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _PanelHeader(icon: Icons.history_rounded, label: 'BALL LOG'),
        Padding(
          padding: const EdgeInsets.all(14),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Over ${overs + 1}  ·  $bowlerName',
                style: const TextStyle(
                    color: _textSecondary,
                    fontSize: 11,
                    fontWeight: FontWeight.w600),
                overflow: TextOverflow.ellipsis),
            const SizedBox(height: 10),
            Wrap(
                spacing: 6,
                runSpacing: 6,
                children: ballLog
                    .take(balls.clamp(0, 6))
                    .map((b) => _BallDot(ball: b))
                    .toList()),
          ]),
        ),
        const _Divider(),
        Expanded(
          child: ballLog.isEmpty
              ? const Center(
                  child: Text('No balls yet',
                      style: TextStyle(color: _textMuted, fontSize: 12)))
              : ListView.separated(
                  padding: const EdgeInsets.all(12),
                  itemCount: ballLog.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 6),
                  itemBuilder: (_, i) =>
                      _BallLogRow(ball: ballLog[i], index: i),
                ),
        ),
      ]),
    );
  }
}

class _BallDot extends StatelessWidget {
  final Map<String, dynamic> ball;
  const _BallDot({required this.ball});
  @override
  Widget build(BuildContext context) {
    final type = ball['type'] as String;
    final value = (ball['value'] as int?) ?? 0;
    Color bg, border, textColor;
    String label;
    switch (type) {
      case 'wicket':
        bg = Colors.redAccent.withOpacity(0.15);
        border = Colors.redAccent.withOpacity(0.5);
        textColor = Colors.redAccent;
        label = 'W';
        break;
      case 'wides':
        bg = Colors.blueAccent.withOpacity(0.12);
        border = Colors.blueAccent.withOpacity(0.4);
        textColor = Colors.blueAccent;
        label = 'Wd';
        break;
      case 'noBalls':
        bg = Colors.orangeAccent.withOpacity(0.12);
        border = Colors.orangeAccent.withOpacity(0.4);
        textColor = Colors.orangeAccent;
        label = 'Nb';
        break;
      case 'legBye':
        bg = Colors.purpleAccent.withOpacity(0.12);
        border = Colors.purpleAccent.withOpacity(0.4);
        textColor = Colors.purpleAccent;
        label = 'Lb';
        break;
      case 'bye':
        bg = Colors.tealAccent.withOpacity(0.12);
        border = Colors.tealAccent.withOpacity(0.4);
        textColor = Colors.tealAccent;
        label = 'B';
        break;
      default:
        if (value == 4) {
          bg = const Color(0xFF4FC3F7).withOpacity(0.12);
          border = const Color(0xFF4FC3F7).withOpacity(0.4);
          textColor = const Color(0xFF4FC3F7);
        } else if (value == 6) {
          bg = const Color(0xFF81C784).withOpacity(0.12);
          border = const Color(0xFF81C784).withOpacity(0.4);
          textColor = const Color(0xFF81C784);
        } else {
          bg = _surface2;
          border = _border;
          textColor = _textSecondary;
        }
        label = value == 0 ? '·' : '$value';
    }
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
          color: bg, shape: BoxShape.circle, border: Border.all(color: border)),
      child: Center(
          child: Text(label,
              style: TextStyle(
                  color: textColor,
                  fontSize: 10,
                  fontWeight: FontWeight.w800))),
    );
  }
}

class _BallLogRow extends StatelessWidget {
  final Map<String, dynamic> ball;
  final int index;
  const _BallLogRow({required this.ball, required this.index});
  @override
  Widget build(BuildContext context) {
    final type = ball['type'] as String;
    final value = (ball['value'] as int?) ?? 0;
    final dismissal = ball['dismissal'] as String?;
    String label;
    Color color;
    IconData icon;
    switch (type) {
      case 'wicket':
        label = dismissal != null ? 'W — $dismissal' : 'Wicket';
        color = Colors.redAccent;
        icon = Icons.close_rounded;
        break;
      case 'wides':
        label = 'Wide +$value';
        color = Colors.blueAccent;
        icon = Icons.arrow_outward_rounded;
        break;
      case 'noBalls':
        label = 'No Ball +$value';
        color = Colors.orangeAccent;
        icon = Icons.cancel_outlined;
        break;
      case 'legBye':
        label = 'Leg Bye +$value';
        color = Colors.purpleAccent;
        icon = Icons.directions_run_rounded;
        break;
      case 'bye':
        label = 'Bye +$value';
        color = Colors.tealAccent;
        icon = Icons.directions_walk_rounded;
        break;
      default:
        label = value == 0 ? 'Dot ball' : '$value run${value == 1 ? '' : 's'}';
        color = value == 4
            ? const Color(0xFF4FC3F7)
            : value == 6
                ? const Color(0xFF81C784)
                : _textSecondary;
        icon = value == 0
            ? Icons.circle_outlined
            : value >= 4
                ? Icons.bolt_rounded
                : Icons.radio_button_unchecked_rounded;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
          color: _surface2,
          borderRadius: BorderRadius.circular(7),
          border: Border.all(color: _border)),
      child: Row(children: [
        Icon(icon, color: color, size: 12),
        const SizedBox(width: 8),
        Expanded(
            child: Text(label,
                style: TextStyle(
                    color: color, fontSize: 11, fontWeight: FontWeight.w500))),
        Text('#${index + 1}',
            style: const TextStyle(color: _textMuted, fontSize: 9)),
      ]),
    );
  }
}

class _ExtraRunsDialog extends StatefulWidget {
  final String title;
  final IconData icon;
  final Color color;
  final bool allowZero;
  final String hint;
  const _ExtraRunsDialog(
      {required this.title,
      required this.icon,
      required this.color,
      required this.allowZero,
      required this.hint});
  @override
  State<_ExtraRunsDialog> createState() => _ExtraRunsDialogState();
}

class _ExtraRunsDialogState extends State<_ExtraRunsDialog> {
  int? _selected;
  @override
  Widget build(BuildContext context) {
    final options = widget.allowZero ? [0, 1, 2, 3, 4] : [1, 2, 3, 4];
    return _BaseDialog(
      title: widget.title,
      icon: widget.icon,
      iconColor: widget.color,
      child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const _DialogLabel('Extra runs'),
            const SizedBox(height: 4),
            Text(widget.hint,
                style: const TextStyle(
                    color: _textMuted, fontSize: 10, height: 1.4)),
            const SizedBox(height: 14),
            Wrap(
                spacing: 8,
                runSpacing: 8,
                children: options
                    .map((r) => _DialogChip(
                          label: r == 0 ? 'None' : '+$r',
                          selected: _selected == r,
                          onTap: () => setState(() => _selected = r),
                        ))
                    .toList()),
            const SizedBox(height: 24),
            Row(children: [
              Expanded(
                  child: _DialogCancelBtn(onTap: () => Navigator.pop(context))),
              const SizedBox(width: 12),
              Expanded(
                  child: _DialogConfirmBtn(
                      label: 'Confirm',
                      color: widget.color,
                      enabled: _selected != null,
                      onTap: () => Navigator.pop(context, _selected))),
            ]),
          ]),
    );
  }
}

class _ResetDialog extends StatelessWidget {
  const _ResetDialog();
  @override
  Widget build(BuildContext context) {
    return _BaseDialog(
      title: 'Reset for Next Match',
      icon: Icons.refresh_rounded,
      iconColor: _textSecondary,
      child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
                'This will clear all match data including scores, player stats, and ball logs. The teams will be preserved.',
                style: TextStyle(
                    color: _textSecondary, fontSize: 13, height: 1.6)),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                  color: Colors.redAccent.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.redAccent.withOpacity(0.2))),
              child: const Row(children: [
                Icon(Icons.warning_amber_rounded,
                    color: Colors.redAccent, size: 14),
                SizedBox(width: 8),
                Expanded(
                    child: Text('This action cannot be undone.',
                        style: TextStyle(
                            color: Colors.redAccent,
                            fontSize: 11,
                            fontWeight: FontWeight.w600))),
              ]),
            ),
            const SizedBox(height: 24),
            Row(children: [
              Expanded(
                  child: _DialogCancelBtn(
                      onTap: () => Navigator.pop(context, false))),
              const SizedBox(width: 12),
              Expanded(
                  child: _DialogConfirmBtn(
                      label: 'Reset Match',
                      color: Colors.redAccent,
                      enabled: true,
                      onTap: () => Navigator.pop(context, true))),
            ]),
          ]),
    );
  }
}

class _WicketDialog extends StatefulWidget {
  final Map<String, dynamic> batTeam;
  final String strikerId, nonStrikerId;
  const _WicketDialog(
      {required this.batTeam,
      required this.strikerId,
      required this.nonStrikerId});
  @override
  State<_WicketDialog> createState() => _WicketDialogState();
}

class _WicketDialogState extends State<_WicketDialog> {
  String _dismissal = 'bowled';
  String? _newBatsman;
  int _runsOnWicket = 0;
  String? _runOutBatsmanId;
  bool _strikerFacesNext = true;
  static const _dismissals = [
    'bowled',
    'caught',
    'lbw',
    'run out',
    'stumped',
    'hit wicket',
    'retired'
  ];
  bool get _isRunOut => _dismissal == 'run out';
  String get _dismissedBatsmanId => (_isRunOut && _runOutBatsmanId != null)
      ? _runOutBatsmanId!
      : widget.strikerId;
  List<Map<String, dynamic>> get _allBatPlayers =>
      (widget.batTeam['players'] as List<dynamic>? ?? [])
          .map((p) => Map<String, dynamic>.from(p as Map))
          .toList();
  List<Map<String, dynamic>> get _availableBatsmen =>
      _allBatPlayers.where((p) => p['id'] != _dismissedBatsmanId).toList();
  Map<String, dynamic>? _findPlayer(String id) {
    try {
      return _allBatPlayers.firstWhere((p) => p['id'] == id);
    } catch (_) {
      return null;
    }
  }

  bool get _canConfirm => _isRunOut
      ? _runOutBatsmanId != null && _newBatsman != null
      : _newBatsman != null;

  @override
  Widget build(BuildContext context) {
    final strikerName =
        _findPlayer(widget.strikerId)?['name'] as String? ?? 'Striker';
    final nonStrikerName =
        _findPlayer(widget.nonStrikerId)?['name'] as String? ?? 'Non-Striker';
    return _BaseDialog(
      title: 'Wicket',
      icon: Icons.close_rounded,
      iconColor: Colors.redAccent,
      child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const _DialogLabel('Dismissal type'),
            const SizedBox(height: 8),
            Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _dismissals
                    .map((d) => _DialogChip(
                          label: d,
                          selected: _dismissal == d,
                          onTap: () => setState(() {
                            _dismissal = d;
                            _runOutBatsmanId = null;
                            _newBatsman = null;
                            _strikerFacesNext = true;
                          }),
                        ))
                    .toList()),
            if (_isRunOut) ...[
              const SizedBox(height: 20),
              Row(children: [
                Container(
                    width: 3,
                    height: 14,
                    decoration: BoxDecoration(
                        color: Colors.orangeAccent,
                        borderRadius: BorderRadius.circular(2))),
                const SizedBox(width: 8),
                const _DialogLabel('Who was run out?'),
              ]),
              const SizedBox(height: 10),
              Row(children: [
                Expanded(
                    child: _RunOutPlayerChip(
                        name: strikerName,
                        badge: 'STRIKER ★',
                        badgeColor: Colors.amber,
                        selected: _runOutBatsmanId == widget.strikerId,
                        onTap: () => setState(() {
                              _runOutBatsmanId = widget.strikerId;
                              _newBatsman = null;
                            }))),
                const SizedBox(width: 8),
                Expanded(
                    child: _RunOutPlayerChip(
                        name: nonStrikerName,
                        badge: 'NON-STRIKER',
                        badgeColor: _textMuted,
                        selected: _runOutBatsmanId == widget.nonStrikerId,
                        onTap: () => setState(() {
                              _runOutBatsmanId = widget.nonStrikerId;
                              _newBatsman = null;
                            }))),
              ]),
            ],
            const SizedBox(height: 20),
            const _DialogLabel('Runs taken on this ball'),
            const SizedBox(height: 8),
            Row(
                children: [0, 1, 2, 3]
                    .map((r) => Padding(
                          padding: EdgeInsets.only(right: r < 3 ? 8 : 0),
                          child: _DialogChip(
                              label: '$r',
                              selected: _runsOnWicket == r,
                              onTap: () => setState(() => _runsOnWicket = r)),
                        ))
                    .toList()),
            if (_isRunOut && _runOutBatsmanId != null) ...[
              const SizedBox(height: 20),
              Row(children: [
                Container(
                    width: 3,
                    height: 14,
                    decoration: BoxDecoration(
                        color: Colors.blueAccent,
                        borderRadius: BorderRadius.circular(2))),
                const SizedBox(width: 8),
                const _DialogLabel('Who faces next ball?'),
              ]),
              const SizedBox(height: 10),
              Row(children: [
                Expanded(
                    child: _StrikeFacingChip(
                        label: '★ Striker faces',
                        selected: _strikerFacesNext,
                        color: Colors.amber,
                        onTap: () => setState(() => _strikerFacesNext = true))),
                const SizedBox(width: 8),
                Expanded(
                    child: _StrikeFacingChip(
                        label: 'New bat faces',
                        selected: !_strikerFacesNext,
                        color: Colors.blueAccent,
                        onTap: () =>
                            setState(() => _strikerFacesNext = false))),
              ]),
            ],
            if (!_isRunOut || _runOutBatsmanId != null) ...[
              const SizedBox(height: 20),
              const _DialogLabel('Incoming batsman'),
              const SizedBox(height: 8),
              if (_availableBatsmen.isEmpty)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                      color: _surface2,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: _border)),
                  child: const Text('No available batsmen',
                      style: TextStyle(color: _textMuted, fontSize: 12)),
                )
              else
                ..._availableBatsmen.map((p) {
                  final id = p['id'] as String? ?? '';
                  return _PlayerDialogRow(
                      name: p['name'] as String? ?? '—',
                      role: p['role'] as String? ?? '',
                      selected: _newBatsman == id,
                      onTap: () => setState(() => _newBatsman = id));
                }),
            ],
            const SizedBox(height: 24),
            Row(children: [
              Expanded(
                  child: _DialogCancelBtn(onTap: () => Navigator.pop(context))),
              const SizedBox(width: 12),
              Expanded(
                  child: _DialogConfirmBtn(
                      label: 'Record Wicket',
                      color: Colors.redAccent,
                      enabled: _canConfirm,
                      onTap: () => Navigator.pop(context, {
                            'dismissal': _dismissal,
                            'newBatsman': _newBatsman,
                            'runs': _runsOnWicket,
                            'dismissedBatsmanId': _dismissedBatsmanId,
                            'strikerFacesNext':
                                _isRunOut ? _strikerFacesNext : null,
                          }))),
            ]),
          ]),
    );
  }
}

class _RunOutPlayerChip extends StatefulWidget {
  final String name, badge;
  final Color badgeColor;
  final bool selected;
  final VoidCallback onTap;
  const _RunOutPlayerChip(
      {required this.name,
      required this.badge,
      required this.badgeColor,
      required this.selected,
      required this.onTap});
  @override
  State<_RunOutPlayerChip> createState() => _RunOutPlayerChipState();
}

class _RunOutPlayerChipState extends State<_RunOutPlayerChip> {
  bool _hovered = false;
  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: widget.selected
                ? Colors.orangeAccent.withOpacity(0.08)
                : _hovered
                    ? _surface2
                    : _surface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
                color: widget.selected
                    ? Colors.orangeAccent.withOpacity(0.4)
                    : _hovered
                        ? _border2
                        : _border),
          ),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
              decoration: BoxDecoration(
                  color: widget.badgeColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(4)),
              child: Text(widget.badge,
                  style: TextStyle(
                      color: widget.badgeColor,
                      fontSize: 8,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5)),
            ),
            const SizedBox(height: 5),
            Text(widget.name,
                style: TextStyle(
                    color: widget.selected ? Colors.orangeAccent : _textPrimary,
                    fontSize: 12,
                    fontWeight:
                        widget.selected ? FontWeight.w700 : FontWeight.w500),
                overflow: TextOverflow.ellipsis),
          ]),
        ),
      ),
    );
  }
}

class _StrikeFacingChip extends StatefulWidget {
  final String label;
  final bool selected;
  final Color color;
  final VoidCallback onTap;
  const _StrikeFacingChip(
      {required this.label,
      required this.selected,
      required this.color,
      required this.onTap});
  @override
  State<_StrikeFacingChip> createState() => _StrikeFacingChipState();
}

class _StrikeFacingChipState extends State<_StrikeFacingChip> {
  bool _hovered = false;
  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: widget.selected
                ? widget.color.withOpacity(0.1)
                : _hovered
                    ? _surface2
                    : _surface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
                color: widget.selected
                    ? widget.color.withOpacity(0.4)
                    : _hovered
                        ? _border2
                        : _border),
          ),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(
                widget.selected
                    ? Icons.radio_button_checked_rounded
                    : Icons.radio_button_unchecked_rounded,
                color: widget.selected ? widget.color : _textMuted,
                size: 14),
            const SizedBox(width: 6),
            Text(widget.label,
                style: TextStyle(
                    color: widget.selected ? widget.color : _textSecondary,
                    fontSize: 11,
                    fontWeight:
                        widget.selected ? FontWeight.w700 : FontWeight.w400)),
          ]),
        ),
      ),
    );
  }
}

class _ChangeBowlerDialog extends StatefulWidget {
  final Map<String, dynamic> bowlTeam;
  final String currentBowlerId;
  const _ChangeBowlerDialog(
      {required this.bowlTeam, required this.currentBowlerId});
  @override
  State<_ChangeBowlerDialog> createState() => _ChangeBowlerDialogState();
}

class _ChangeBowlerDialogState extends State<_ChangeBowlerDialog> {
  String? _selectedId;
  @override
  Widget build(BuildContext context) {
    final players = (widget.bowlTeam['players'] as List<dynamic>? ?? [])
        .map((p) => Map<String, dynamic>.from(p as Map))
        .toList();
    return _BaseDialog(
      title: 'New Bowler',
      icon: Icons.trip_origin_rounded,
      iconColor: Colors.blueAccent,
      child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Over complete. Select the bowler for the next over.',
                style: TextStyle(
                    color: _textSecondary, fontSize: 13, height: 1.5)),
            const SizedBox(height: 16),
            ...players.map((p) {
              final id = p['id'] as String? ?? '';
              final isCurrent = id == widget.currentBowlerId;
              return _PlayerDialogRow(
                  name: p['name'] as String? ?? '—',
                  role: p['role'] as String? ?? '',
                  selected: _selectedId == id,
                  disabled: isCurrent,
                  disabledLabel: 'prev over',
                  onTap: isCurrent
                      ? null
                      : () => setState(() => _selectedId = id));
            }),
            const SizedBox(height: 24),
            _DialogConfirmBtn(
                label: 'Confirm Bowler',
                color: Colors.blueAccent,
                enabled: _selectedId != null,
                onTap: () => Navigator.pop(context, _selectedId)),
          ]),
    );
  }
}

class _SwitchInningsDialog extends StatefulWidget {
  final Map<String, dynamic> teams;
  final String newBattingTeamKey;
  final String? title;
  const _SwitchInningsDialog(
      {required this.teams, required this.newBattingTeamKey, this.title});
  @override
  State<_SwitchInningsDialog> createState() => _SwitchInningsDialogState();
}

class _SwitchInningsDialogState extends State<_SwitchInningsDialog> {
  String? _striker, _nonStriker, _bowler;
  @override
  Widget build(BuildContext context) {
    final newBatTeam =
        widget.teams[widget.newBattingTeamKey] as Map<String, dynamic>? ?? {};
    final newBowlKey = widget.newBattingTeamKey == 'teamA' ? 'teamB' : 'teamA';
    final newBowlTeam = widget.teams[newBowlKey] as Map<String, dynamic>? ?? {};
    final batPlayers = (newBatTeam['players'] as List<dynamic>? ?? [])
        .map((p) => Map<String, dynamic>.from(p as Map))
        .toList();
    final bowlPlayers = (newBowlTeam['players'] as List<dynamic>? ?? [])
        .map((p) => Map<String, dynamic>.from(p as Map))
        .toList();
    return _BaseDialog(
      title: widget.title ?? '2nd Innings',
      icon: Icons.swap_vert_rounded,
      iconColor: Colors.amber,
      child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const _DialogLabel('Striker'),
            const SizedBox(height: 8),
            ...batPlayers.map((p) {
              final id = p['id'] as String? ?? '';
              return _PlayerDialogRow(
                  name: p['name'] as String? ?? '—',
                  role: p['role'] as String? ?? '',
                  selected: _striker == id,
                  disabled: _nonStriker == id,
                  onTap: _nonStriker == id
                      ? null
                      : () => setState(() => _striker = id));
            }),
            const SizedBox(height: 14),
            const _DialogLabel('Non-Striker'),
            const SizedBox(height: 8),
            ...batPlayers.map((p) {
              final id = p['id'] as String? ?? '';
              return _PlayerDialogRow(
                  name: p['name'] as String? ?? '—',
                  role: p['role'] as String? ?? '',
                  selected: _nonStriker == id,
                  disabled: _striker == id,
                  onTap: _striker == id
                      ? null
                      : () => setState(() => _nonStriker = id));
            }),
            const SizedBox(height: 14),
            const _DialogLabel('Opening Bowler'),
            const SizedBox(height: 8),
            ...bowlPlayers.map((p) {
              final id = p['id'] as String? ?? '';
              return _PlayerDialogRow(
                  name: p['name'] as String? ?? '—',
                  role: p['role'] as String? ?? '',
                  selected: _bowler == id,
                  onTap: () => setState(() => _bowler = id));
            }),
            const SizedBox(height: 24),
            Row(children: [
              Expanded(
                  child: _DialogCancelBtn(onTap: () => Navigator.pop(context))),
              const SizedBox(width: 12),
              Expanded(
                  child: _DialogConfirmBtn(
                      label: 'Confirm',
                      color: Colors.amber,
                      enabled: _striker != null &&
                          _nonStriker != null &&
                          _bowler != null &&
                          _striker != _nonStriker,
                      onTap: () => Navigator.pop(context, {
                            'striker': _striker,
                            'nonStriker': _nonStriker,
                            'bowler': _bowler
                          }))),
            ]),
          ]),
    );
  }
}

class _TestInningsSwitchDialog extends StatefulWidget {
  final Map<String, dynamic> teams;
  final int currentInnings;
  final String normalNextBatTeamKey;
  final bool canFollowOn;
  final String followOnTeamKey;
  final Map<String, dynamic> scores;
  const _TestInningsSwitchDialog(
      {required this.teams,
      required this.currentInnings,
      required this.normalNextBatTeamKey,
      required this.canFollowOn,
      required this.followOnTeamKey,
      required this.scores});
  @override
  State<_TestInningsSwitchDialog> createState() =>
      _TestInningsSwitchDialogState();
}

class _TestInningsSwitchDialogState extends State<_TestInningsSwitchDialog> {
  String _action = 'normal';
  String? _striker, _nonStriker, _bowler;
  String get _nextBatTeamKey => _action == 'follow_on'
      ? widget.followOnTeamKey
      : widget.normalNextBatTeamKey;
  String get _nextBowlTeamKey => _nextBatTeamKey == 'teamA' ? 'teamB' : 'teamA';
  bool get _canConfirm =>
      _striker != null &&
      _nonStriker != null &&
      _bowler != null &&
      _striker != _nonStriker;
  String _teamName(String key) {
    final t = widget.teams[key] as Map? ?? {};
    return t['name'] as String? ?? key;
  }

  List<Map<String, dynamic>> _teamPlayers(String key) =>
      ((widget.teams[key] as Map?)?['players'] as List<dynamic>? ?? [])
          .map((p) => Map<String, dynamic>.from(p as Map))
          .toList();

  @override
  Widget build(BuildContext context) {
    final nextBatPlayers = _teamPlayers(_nextBatTeamKey);
    final nextBowlPlayers = _teamPlayers(_nextBowlTeamKey);
    final innNum = widget.currentInnings + 1;
    return _BaseDialog(
      title: 'Innings $innNum',
      icon: Icons.swap_vert_rounded,
      iconColor: Colors.amber,
      child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const _DialogLabel('Action'),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(
                  child: _DialogChip(
                      label: 'Normal End',
                      selected: _action == 'normal',
                      onTap: () => setState(() {
                            _action = 'normal';
                            _striker = null;
                            _nonStriker = null;
                            _bowler = null;
                          }))),
              const SizedBox(width: 8),
              if (widget.currentInnings == 1 || widget.currentInnings == 3)
                Expanded(
                    child: _DialogChip(
                        label: 'Declare',
                        selected: _action == 'declare',
                        onTap: () => setState(() {
                              _action = 'declare';
                              _striker = null;
                              _nonStriker = null;
                              _bowler = null;
                            }))),
              if (widget.canFollowOn && widget.currentInnings == 2) ...[
                const SizedBox(width: 8),
                Expanded(
                    child: _FollowOnChip(
                        selected: _action == 'follow_on',
                        onTap: () => setState(() {
                              _action = 'follow_on';
                              _striker = null;
                              _nonStriker = null;
                              _bowler = null;
                            }))),
              ],
            ]),
            if (_action == 'follow_on') ...[
              const SizedBox(height: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                    color: Colors.orangeAccent.withOpacity(0.06),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                        color: Colors.orangeAccent.withOpacity(0.2))),
                child: Row(children: [
                  const Icon(Icons.info_outline_rounded,
                      color: Colors.orangeAccent, size: 13),
                  const SizedBox(width: 8),
                  Expanded(
                      child: Text(
                          '${_teamName(widget.followOnTeamKey)} will bat again (Follow-on enforced)',
                          style: const TextStyle(
                              color: Colors.orangeAccent,
                              fontSize: 11,
                              height: 1.4))),
                ]),
              ),
            ],
            const SizedBox(height: 20),
            Text('Batting: ${_teamName(_nextBatTeamKey)}',
                style: const TextStyle(
                    color: _textSecondary,
                    fontSize: 11,
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            const _DialogLabel('Striker'),
            const SizedBox(height: 8),
            ...nextBatPlayers.map((p) {
              final id = p['id'] as String? ?? '';
              return _PlayerDialogRow(
                  name: p['name'] as String? ?? '—',
                  role: p['role'] as String? ?? '',
                  selected: _striker == id,
                  disabled: _nonStriker == id,
                  onTap: _nonStriker == id
                      ? null
                      : () => setState(() => _striker = id));
            }),
            const SizedBox(height: 14),
            const _DialogLabel('Non-Striker'),
            const SizedBox(height: 8),
            ...nextBatPlayers.map((p) {
              final id = p['id'] as String? ?? '';
              return _PlayerDialogRow(
                  name: p['name'] as String? ?? '—',
                  role: p['role'] as String? ?? '',
                  selected: _nonStriker == id,
                  disabled: _striker == id,
                  onTap: _striker == id
                      ? null
                      : () => setState(() => _nonStriker = id));
            }),
            const SizedBox(height: 14),
            Text('Opening Bowler: ${_teamName(_nextBowlTeamKey)}',
                style: const TextStyle(
                    color: _textSecondary,
                    fontSize: 11,
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            ...nextBowlPlayers.map((p) {
              final id = p['id'] as String? ?? '';
              return _PlayerDialogRow(
                  name: p['name'] as String? ?? '—',
                  role: p['role'] as String? ?? '',
                  selected: _bowler == id,
                  onTap: () => setState(() => _bowler = id));
            }),
            const SizedBox(height: 24),
            Row(children: [
              Expanded(
                  child: _DialogCancelBtn(onTap: () => Navigator.pop(context))),
              const SizedBox(width: 12),
              Expanded(
                  child: _DialogConfirmBtn(
                label: _action == 'declare'
                    ? 'Declare & Switch'
                    : _action == 'follow_on'
                        ? 'Enforce Follow-on'
                        : 'Start Inn $innNum',
                color:
                    _action == 'follow_on' ? Colors.orangeAccent : Colors.amber,
                enabled: _canConfirm,
                onTap: () => Navigator.pop(context, {
                  'action': _action,
                  'striker': _striker,
                  'nonStriker': _nonStriker,
                  'bowler': _bowler,
                }),
              )),
            ]),
          ]),
    );
  }
}

class _FollowOnChip extends StatefulWidget {
  final bool selected;
  final VoidCallback onTap;
  const _FollowOnChip({required this.selected, required this.onTap});
  @override
  State<_FollowOnChip> createState() => _FollowOnChipState();
}

class _FollowOnChipState extends State<_FollowOnChip> {
  bool _hovered = false;
  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: widget.selected
                ? Colors.orangeAccent.withOpacity(0.12)
                : _hovered
                    ? _surface2
                    : _surface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
                color: widget.selected
                    ? Colors.orangeAccent.withOpacity(0.4)
                    : _border),
          ),
          child: Text('Follow-on',
              style: TextStyle(
                  color: widget.selected ? Colors.orangeAccent : _textSecondary,
                  fontSize: 12,
                  fontWeight:
                      widget.selected ? FontWeight.w600 : FontWeight.w400)),
        ),
      ),
    );
  }
}

class _TestEndMatchDialog extends StatelessWidget {
  const _TestEndMatchDialog();
  @override
  Widget build(BuildContext context) {
    return _BaseDialog(
      title: 'End / Stumps / Draw',
      icon: Icons.flag_rounded,
      iconColor: _textSecondary,
      child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Choose how to close or pause this Test match.',
                style: TextStyle(
                    color: _textSecondary, fontSize: 13, height: 1.6)),
            const SizedBox(height: 20),
            _TestEndOption(
                icon: Icons.nightlight_round,
                color: Colors.blueAccent,
                label: 'Call Stumps',
                subtitle: 'Pause play — match continues next day',
                onTap: () => Navigator.pop(context, 'stumps')),
            const SizedBox(height: 8),
            _TestEndOption(
                icon: Icons.wb_sunny_rounded,
                color: Colors.amber,
                label: 'Resume Play',
                subtitle: 'Come back from stumps / lunch / tea',
                onTap: () => Navigator.pop(context, 'resume')),
            const SizedBox(height: 8),
            _TestEndOption(
                icon: Icons.handshake_rounded,
                color: const Color(0xFF4CAF50),
                label: 'Match Drawn',
                subtitle: 'End match as a draw',
                onTap: () => Navigator.pop(context, 'draw')),
            const SizedBox(height: 8),
            _TestEndOption(
                icon: Icons.emoji_events_rounded,
                color: Colors.redAccent,
                label: 'Team Won',
                subtitle: 'Record win for batting / bowling team',
                onTap: () => Navigator.pop(context, 'win')),
            const SizedBox(height: 20),
            _DialogCancelBtn(onTap: () => Navigator.pop(context)),
          ]),
    );
  }
}

class _TestEndOption extends StatefulWidget {
  final IconData icon;
  final Color color;
  final String label, subtitle;
  final VoidCallback onTap;
  const _TestEndOption(
      {required this.icon,
      required this.color,
      required this.label,
      required this.subtitle,
      required this.onTap});
  @override
  State<_TestEndOption> createState() => _TestEndOptionState();
}

class _TestEndOptionState extends State<_TestEndOption> {
  bool _hovered = false;
  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: _hovered ? widget.color.withOpacity(0.08) : _surface2,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
                color: _hovered ? widget.color.withOpacity(0.3) : _border),
          ),
          child: Row(children: [
            Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                    color: widget.color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8)),
                child: Icon(widget.icon, color: widget.color, size: 16)),
            const SizedBox(width: 12),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(widget.label,
                      style: TextStyle(
                          color: _hovered ? widget.color : _textPrimary,
                          fontSize: 13,
                          fontWeight: FontWeight.w600)),
                  Text(widget.subtitle,
                      style: const TextStyle(
                          color: _textMuted, fontSize: 10, height: 1.3)),
                ])),
            Icon(Icons.chevron_right_rounded,
                color: _hovered ? widget.color : _textMuted, size: 16),
          ]),
        ),
      ),
    );
  }
}

class _DayPickerDialog extends StatefulWidget {
  final int currentDay;
  const _DayPickerDialog({required this.currentDay});
  @override
  State<_DayPickerDialog> createState() => _DayPickerDialogState();
}

class _DayPickerDialogState extends State<_DayPickerDialog> {
  late int _selected;
  @override
  void initState() {
    super.initState();
    _selected = widget.currentDay;
  }

  @override
  Widget build(BuildContext context) {
    return _BaseDialog(
      title: 'Set Day',
      icon: Icons.calendar_today_rounded,
      iconColor: Colors.amber,
      child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _DialogLabel('Current day of the Test'),
            const SizedBox(height: 12),
            Row(
                children: List.generate(5, (i) {
              final day = i + 1;
              return Expanded(
                  child: Padding(
                padding: EdgeInsets.only(right: day < 5 ? 8 : 0),
                child: _DialogChip(
                    label: 'Day $day',
                    selected: _selected == day,
                    onTap: () => setState(() => _selected = day)),
              ));
            })),
            const SizedBox(height: 24),
            Row(children: [
              Expanded(
                  child: _DialogCancelBtn(onTap: () => Navigator.pop(context))),
              const SizedBox(width: 12),
              Expanded(
                  child: _DialogConfirmBtn(
                      label: 'Set Day $_selected',
                      color: Colors.amber,
                      enabled: true,
                      onTap: () => Navigator.pop(context, _selected))),
            ]),
          ]),
    );
  }
}

class _PlayerPickerDialog extends StatelessWidget {
  final String title;
  final Map<String, dynamic> team;
  final ValueChanged<String> onSelect;
  const _PlayerPickerDialog(
      {required this.title, required this.team, required this.onSelect});
  @override
  Widget build(BuildContext context) {
    final players = (team['players'] as List<dynamic>? ?? [])
        .map((p) => Map<String, dynamic>.from(p as Map))
        .toList();
    return _BaseDialog(
      title: title,
      icon: Icons.person_rounded,
      iconColor: Colors.redAccent,
      child: Column(
          mainAxisSize: MainAxisSize.min,
          children: players.map((p) {
            final id = p['id'] as String? ?? '';
            return _PlayerDialogRow(
                name: p['name'] as String? ?? '—',
                role: p['role'] as String? ?? '',
                selected: false,
                onTap: () {
                  onSelect(id);
                  Navigator.pop(context);
                });
          }).toList()),
    );
  }
}

class _ResetButton extends StatefulWidget {
  final VoidCallback onReset;
  const _ResetButton({required this.onReset});
  @override
  State<_ResetButton> createState() => _ResetButtonState();
}

class _ResetButtonState extends State<_ResetButton> {
  bool _hovered = false;
  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onReset,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 130),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: _hovered ? _surface3 : _surface2,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: _hovered ? _border2 : _border),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.refresh_rounded,
                size: 14, color: _hovered ? _textSecondary : _textMuted),
            const SizedBox(width: 6),
            Text('Reset for Next Match',
                style: TextStyle(
                    color: _hovered ? _textSecondary : _textMuted,
                    fontSize: 11,
                    fontWeight: FontWeight.w500)),
          ]),
        ),
      ),
    );
  }
}

class _TeamTag extends StatelessWidget {
  final String name, logo, teamId;
  final bool muted;
  const _TeamTag(
      {required this.name,
      required this.logo,
      required this.teamId,
      this.muted = false});
  @override
  Widget build(BuildContext context) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: muted ? _surface2 : Colors.redAccent.withOpacity(0.08),
          borderRadius: BorderRadius.circular(9),
          border: Border.all(
              color: muted ? _border : Colors.redAccent.withOpacity(0.2)),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: logo.isNotEmpty
              ? Image.network(logo,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) =>
                      _FallbackLogo(teamId: name.substring(0, 2)))
              : _FallbackLogo(
                  teamId: name.length > 2 ? name.substring(0, 2) : name),
        ),
      ),
      const SizedBox(width: 10),
      Text(name,
          style: TextStyle(
              color: muted ? _textSecondary : _textPrimary,
              fontSize: 13,
              fontWeight: muted ? FontWeight.w400 : FontWeight.w700)),
    ]);
  }
}

class _StatusBadge extends StatelessWidget {
  final String status;
  const _StatusBadge({required this.status});
  @override
  Widget build(BuildContext context) {
    Color color;
    String label;
    switch (status) {
      case 'live':
        color = Colors.greenAccent;
        label = '● LIVE';
        break;
      case 'stumps':
        color = Colors.blueAccent;
        label = '🌙 STUMPS';
        break;
      case 'super_over':
        color = Colors.amber;
        label = '⚡ SUPER OVER';
        break;
      case 'completed':
        color = _textSecondary;
        label = 'COMPLETED';
        break;
      default:
        color = Colors.amber;
        label = 'UPCOMING';
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(5),
          border: Border.all(color: color.withOpacity(0.25))),
      child: Text(label,
          style: TextStyle(
              color: color,
              fontSize: 9,
              fontWeight: FontWeight.w800,
              letterSpacing: 1)),
    );
  }
}

class _BaseDialog extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color iconColor;
  final Widget child;
  const _BaseDialog(
      {required this.title,
      required this.icon,
      required this.iconColor,
      required this.child});
  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF141414),
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: _border)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420, maxHeight: 600),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(26),
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(children: [
                  Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                          color: iconColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(9)),
                      child: Icon(icon, color: iconColor, size: 18)),
                  const SizedBox(width: 12),
                  Text(title,
                      style: const TextStyle(
                          color: _textPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.w700)),
                ]),
                const SizedBox(height: 20),
                child,
              ]),
        ),
      ),
    );
  }
}

class _DialogLabel extends StatelessWidget {
  final String text;
  const _DialogLabel(this.text);
  @override
  Widget build(BuildContext context) => Text(text,
      style: const TextStyle(
          color: _textSecondary,
          fontSize: 11,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.3));
}

class _DialogChip extends StatefulWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _DialogChip(
      {required this.label, required this.selected, required this.onTap});
  @override
  State<_DialogChip> createState() => _DialogChipState();
}

class _DialogChipState extends State<_DialogChip> {
  bool _hovered = false;
  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: widget.selected
                ? Colors.redAccent.withOpacity(0.12)
                : _hovered
                    ? _surface2
                    : _surface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
                color: widget.selected
                    ? Colors.redAccent.withOpacity(0.4)
                    : _border),
          ),
          child: Text(widget.label,
              style: TextStyle(
                  color: widget.selected ? Colors.redAccent : _textSecondary,
                  fontSize: 12,
                  fontWeight:
                      widget.selected ? FontWeight.w600 : FontWeight.w400)),
        ),
      ),
    );
  }
}

class _PlayerDialogRow extends StatefulWidget {
  final String name, role;
  final bool selected, disabled;
  final String? disabledLabel;
  final VoidCallback? onTap;
  const _PlayerDialogRow(
      {required this.name,
      required this.role,
      required this.selected,
      this.disabled = false,
      this.disabledLabel,
      this.onTap});
  @override
  State<_PlayerDialogRow> createState() => _PlayerDialogRowState();
}

class _PlayerDialogRowState extends State<_PlayerDialogRow> {
  bool _hovered = false;
  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => !widget.disabled ? setState(() => _hovered = true) : null,
      onExit: (_) => setState(() => _hovered = false),
      cursor: widget.disabled || widget.onTap == null
          ? SystemMouseCursors.forbidden
          : SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 110),
          margin: const EdgeInsets.only(bottom: 6),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: widget.selected
                ? Colors.redAccent.withOpacity(0.08)
                : _hovered
                    ? _surface2
                    : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
                color: widget.selected
                    ? Colors.redAccent.withOpacity(0.25)
                    : Colors.transparent),
          ),
          child: Row(children: [
            Expanded(
                child: Text(widget.name,
                    style: TextStyle(
                        color: widget.disabled ? _textMuted : _textPrimary,
                        fontSize: 13,
                        fontWeight: widget.selected
                            ? FontWeight.w600
                            : FontWeight.w400))),
            if (widget.disabled && widget.disabledLabel != null)
              Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                      color: _surface3, borderRadius: BorderRadius.circular(4)),
                  child: Text(widget.disabledLabel!,
                      style: const TextStyle(color: _textMuted, fontSize: 9)))
            else
              Text(widget.role,
                  style: const TextStyle(
                      color: _textMuted, fontSize: 10, letterSpacing: 0.3)),
            const SizedBox(width: 8),
            AnimatedOpacity(
                duration: const Duration(milliseconds: 110),
                opacity: widget.selected ? 1 : 0,
                child: const Icon(Icons.check_rounded,
                    color: Colors.redAccent, size: 14)),
          ]),
        ),
      ),
    );
  }
}

class _DialogCancelBtn extends StatefulWidget {
  final VoidCallback onTap;
  const _DialogCancelBtn({required this.onTap});
  @override
  State<_DialogCancelBtn> createState() => _DialogCancelBtnState();
}

class _DialogCancelBtnState extends State<_DialogCancelBtn> {
  bool _hovered = false;
  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 130),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: _hovered ? _surface2 : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: _hovered ? _border2 : _border),
          ),
          child: const Center(
              child: Text('Cancel',
                  style: TextStyle(
                      color: _textSecondary,
                      fontSize: 13,
                      fontWeight: FontWeight.w500))),
        ),
      ),
    );
  }
}

class _DialogConfirmBtn extends StatefulWidget {
  final String label;
  final Color color;
  final bool enabled;
  final VoidCallback onTap;
  const _DialogConfirmBtn(
      {required this.label,
      required this.color,
      required this.enabled,
      required this.onTap});
  @override
  State<_DialogConfirmBtn> createState() => _DialogConfirmBtnState();
}

class _DialogConfirmBtnState extends State<_DialogConfirmBtn> {
  bool _hovered = false;
  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => widget.enabled ? setState(() => _hovered = true) : null,
      onExit: (_) => setState(() => _hovered = false),
      cursor: widget.enabled
          ? SystemMouseCursors.click
          : SystemMouseCursors.forbidden,
      child: GestureDetector(
        onTap: widget.enabled ? widget.onTap : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 130),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: widget.enabled
                ? _hovered
                    ? widget.color.withOpacity(0.85)
                    : widget.color
                : _surface2,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Center(
              child: Text(widget.label,
                  style: TextStyle(
                      color: widget.enabled ? Colors.white : _textMuted,
                      fontSize: 13,
                      fontWeight: FontWeight.w700))),
        ),
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  final bool thick;
  const _Divider({this.thick = false});
  @override
  Widget build(BuildContext context) =>
      Container(height: thick ? 8 : 1, color: thick ? _bg : _border);
}

class _FallbackLogo extends StatelessWidget {
  final String teamId;
  const _FallbackLogo({required this.teamId});
  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.redAccent.withOpacity(0.08),
      child: Center(
          child: Text(teamId.length > 2 ? teamId.substring(0, 2) : teamId,
              style: const TextStyle(
                  color: Colors.redAccent,
                  fontSize: 9,
                  fontWeight: FontWeight.w800))),
    );
  }
}

class _NotStartedState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
                color: _surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: _border)),
            child: const Icon(Icons.sports_cricket_rounded,
                color: _textMuted, size: 32)),
        const SizedBox(height: 20),
        const Text('Match not started',
            style: TextStyle(
                color: _textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        const Text(
            'Complete the Toss & Openers setup\nbefore scoring can begin.',
            style: TextStyle(color: _textSecondary, fontSize: 13, height: 1.6),
            textAlign: TextAlign.center),
      ]),
    );
  }
}

// ════════════════════════════════════════════════════════════
//  MOBILE BODY — Single column scrollable layout
// ════════════════════════════════════════════════════════════

class _MobileBody extends StatelessWidget {
  // Players panel props
  final Map<String, dynamic>? striker, nonStriker, bowler;
  final Map<String, dynamic> strikerStat, nonStrikerStat, bowlerStat;
  final String strikerId;
  final Map<String, dynamic> batTeam, bowlTeam;
  final String battingTeamKey, bowlingTeamKey;
  final List<Map<String, dynamic>> allPlayers;
  final bool processing;
  final ValueChanged<String> onStrikerChange,
      onNonStrikerChange,
      onBowlerChange;
  final VoidCallback onRotateStrike;

  // Ball input props
  final bool canUndo, isSuperOver, isTest;
  final List<Map<String, dynamic>> ballLog;
  final List<Map<String, dynamic>> currentOver;
  final int overs, balls;
  final String bowlerName;
  final ValueChanged<int> onRun;
  final VoidCallback onWide, onNoBall, onLegBye, onWicket, onUndo, onEndOver;
  final VoidCallback? onSwitchInnings, onEndMatch;
  final String? onEndMatchLabel, onSwitchInningsLabel;

  static const _bg = Color(0xFF0D0D0D);
  static const _surface = Color(0xFF141414);
  static const _surface2 = Color(0xFF1A1A1A);
  static const _surface3 = Color(0xFF202020);
  static const _border = Color(0xFF232323);
  static const _border2 = Color(0xFF2A2A2A);
  static const _textPrimary = Color(0xFFE8E8E8);
  static const _textSecondary = Color(0xFF666666);
  static const _textMuted = Color(0xFF3A3A3A);

  const _MobileBody({
    required this.striker,
    required this.nonStriker,
    required this.bowler,
    required this.strikerStat,
    required this.nonStrikerStat,
    required this.bowlerStat,
    required this.strikerId,
    required this.batTeam,
    required this.bowlTeam,
    required this.battingTeamKey,
    required this.bowlingTeamKey,
    required this.allPlayers,
    required this.processing,
    required this.onStrikerChange,
    required this.onNonStrikerChange,
    required this.onBowlerChange,
    required this.onRotateStrike,
    required this.canUndo,
    required this.isSuperOver,
    required this.isTest,
    required this.ballLog,
    required this.currentOver,
    required this.overs,
    required this.balls,
    required this.bowlerName,
    required this.onRun,
    required this.onWide,
    required this.onNoBall,
    required this.onLegBye,
    required this.onWicket,
    required this.onUndo,
    required this.onEndOver,
    required this.onSwitchInnings,
    required this.onEndMatch,
    required this.onEndMatchLabel,
    required this.onSwitchInningsLabel,
  });

  String _statStr(Map<String, dynamic> s) {
    final r = (s['runs'] as int?) ?? 0;
    final b = (s['balls'] as int?) ?? 0;
    return '$r($b)';
  }

  String _bowlerStr(Map<String, dynamic> s) {
    final ov = (s['overs'] as int?) ?? 0;
    final bl = (s['ballsBowled'] as int?) ?? 0;
    final wk = (s['wickets'] as int?) ?? 0;
    final rc = (s['runsConceded'] as int?) ?? 0;
    return '$wk-$rc ($ov.$bl)';
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── 1. BATSMEN + BOWLER STRIP ─────────────────────
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _border),
            ),
            child: Column(children: [
              // Striker
              _MobilePlayerRow(
                label: '★',
                labelColor: Colors.amber,
                name: striker?['name'] as String? ?? '—',
                stat: _statStr(strikerStat),
                isStriker: true,
              ),
              const SizedBox(height: 6),
              // Non Striker
              _MobilePlayerRow(
                label: '•',
                labelColor: _textSecondary,
                name: nonStriker?['name'] as String? ?? '—',
                stat: _statStr(nonStrikerStat),
                isStriker: false,
              ),
              Divider(height: 16, color: _border),
              // Bowler
              _MobilePlayerRow(
                label: '🎳',
                labelColor: _textSecondary,
                name: bowler?['name'] as String? ?? '—',
                stat: _bowlerStr(bowlerStat),
                isStriker: false,
              ),
            ]),
          ),

          const SizedBox(height: 8),

          Row(children: [
            Expanded(
                child: _MobileQuickBtn(
              label: 'New Striker',
              onTap: () =>
                  _showPicker(context, 'New Striker', batTeam, onStrikerChange),
            )),
            const SizedBox(width: 8),
            Expanded(
                child: _MobileQuickBtn(
              label: 'Rotate Strike',
              onTap: onRotateStrike,
            )),
            const SizedBox(width: 8),
            Expanded(
                child: _MobileQuickBtn(
              label: 'New Bowler',
              onTap: () =>
                  _showPicker(context, 'New Bowler', bowlTeam, onBowlerChange),
            )),
          ]),

          const SizedBox(height: 12),

          _OverProgress(overs: overs, balls: balls, isSuperOver: isSuperOver),

          const SizedBox(height: 8),

          // Current over balls
          if (currentOver.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Wrap(
                spacing: 6,
                runSpacing: 6,
                children: currentOver.map((b) => _BallDot(ball: b)).toList(),
              ),
            ),

          const SizedBox(height: 4),

          GridView.count(
            crossAxisCount: 3,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
            childAspectRatio: 1.6,
            children: [0, 1, 2, 3, 4, 6]
                .map(
                  (r) => _RunButton(
                      runs: r, processing: processing, onTap: () => onRun(r)),
                )
                .toList(),
          ),

          const SizedBox(height: 10),

          Row(children: [
            Expanded(
                child: _EventButton(
                    label: 'Wide',
                    icon: Icons.arrow_outward_rounded,
                    color: Colors.blueAccent,
                    processing: processing,
                    onTap: onWide)),
            const SizedBox(width: 8),
            Expanded(
                child: _EventButton(
                    label: 'No Ball',
                    icon: Icons.cancel_outlined,
                    color: Colors.orangeAccent,
                    processing: processing,
                    onTap: onNoBall)),
            const SizedBox(width: 8),
            Expanded(
                child: _EventButton(
                    label: 'Leg Bye',
                    icon: Icons.directions_run_rounded,
                    color: Colors.purpleAccent,
                    processing: processing,
                    onTap: onLegBye)),
          ]),

          const SizedBox(height: 8),

          _EventButton(
              label: 'WICKET',
              icon: Icons.close_rounded,
              color: Colors.redAccent,
              processing: processing,
              onTap: onWicket,
              large: true,
              fullWidth: true),

          const SizedBox(height: 12),

          Row(children: [
            _ManagementButton(
                label: 'Undo',
                icon: Icons.undo_rounded,
                enabled: canUndo && !processing,
                onTap: onUndo),
            const SizedBox(width: 8),
            Expanded(
                child: _ManagementButton(
                    label: 'End Over',
                    icon: Icons.skip_next_rounded,
                    enabled: !processing,
                    onTap: onEndOver,
                    primary: true)),
          ]),

          if (onSwitchInnings != null || onEndMatch != null) ...[
            const SizedBox(height: 8),
            if (onSwitchInnings != null)
              _ManagementButton(
                  label: onSwitchInningsLabel ??
                      (isSuperOver
                          ? '⚡ Super Over — 2nd Innings'
                          : '2nd Innings — Switch'),
                  icon: Icons.swap_vert_rounded,
                  enabled: !processing,
                  onTap: onSwitchInnings!,
                  full: true,
                  accent: Colors.amber),
            if (onEndMatch != null) ...[
              const SizedBox(height: 8),
              _ManagementButton(
                  label: onEndMatchLabel ?? 'End Match',
                  icon: Icons.flag_rounded,
                  enabled: !processing,
                  onTap: onEndMatch!,
                  full: true,
                  accent: _textSecondary),
            ],
          ],

          const SizedBox(height: 24),
        ],
      ),
    );
  }

  void _showPicker(BuildContext context, String title,
      Map<String, dynamic> team, ValueChanged<String> onSelect) {
    showDialog(
        context: context,
        builder: (_) =>
            _PlayerPickerDialog(title: title, team: team, onSelect: onSelect));
  }
}

class _MobilePlayerRow extends StatelessWidget {
  final String label, name, stat;
  final Color labelColor;
  final bool isStriker;

  static const _surface2 = Color(0xFF1A1A1A);
  static const _textPrimary = Color(0xFFE8E8E8);
  static const _textSecondary = Color(0xFF666666);

  const _MobilePlayerRow({
    required this.label,
    required this.name,
    required this.stat,
    required this.labelColor,
    required this.isStriker,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: isStriker ? Colors.amber.withAlpha(8) : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(children: [
        Text(label,
            style: TextStyle(
                color: labelColor, fontSize: 14, fontWeight: FontWeight.w800)),
        const SizedBox(width: 10),
        Expanded(
            child: Text(name,
                style: const TextStyle(
                    color: _textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w600),
                overflow: TextOverflow.ellipsis)),
        Text(stat, style: const TextStyle(color: _textSecondary, fontSize: 12)),
      ]),
    );
  }
}

class _MobileQuickBtn extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  static const _surface = Color(0xFF141414);
  static const _border = Color(0xFF232323);
  static const _textSecondary = Color(0xFF666666);

  const _MobileQuickBtn({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: _surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: _border),
        ),
        child: Text(label,
            textAlign: TextAlign.center,
            style: const TextStyle(
                color: _textSecondary,
                fontSize: 11,
                fontWeight: FontWeight.w500)),
      ),
    );
  }
}
