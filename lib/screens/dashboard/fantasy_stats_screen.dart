import 'package:cricket_admin/services/fantasy_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// ─────────────────────────────────────────────────────────────
//  FANTASY STATS SCREEN
//  Match ke baad har player ki stats enter karo
//  Then "Calculate Points" se leaderboard generate hoga
// ─────────────────────────────────────────────────────────────

class FantasyStatsScreen extends StatefulWidget {
  final FantasyMatch match;
  const FantasyStatsScreen({super.key, required this.match});

  @override
  State<FantasyStatsScreen> createState() => _FantasyStatsScreenState();
}

class _FantasyStatsScreenState extends State<FantasyStatsScreen> {
  static const _bg = Color(0xFF0D0D0D);
  static const _surface = Color(0xFF141414);
  static const _border = Color(0xFF232323);
  static const _red = Color(0xFFCC0000);

  List<FantasyPlayer> _players = [];
  // Controllers per player per stat
  final Map<String, Map<String, TextEditingController>> _ctrls = {};
  final Map<String, bool> _isOut = {};

  bool _loading = true;
  bool _saving = false;
  bool _calculating = false;

  @override
  void initState() {
    super.initState();
    _loadPlayers();
  }

  Future<void> _loadPlayers() async {
    final players = await FantasyService.getPlayersFromFeaturedMatch();
    setState(() {
      _players = players;
      for (final p in players) {
        final existing = widget.match.playerStats[p.id];
        _ctrls[p.id] = {
          'runs': TextEditingController(text: '${existing?.runs ?? 0}'),
          'fours': TextEditingController(text: '${existing?.fours ?? 0}'),
          'sixes': TextEditingController(text: '${existing?.sixes ?? 0}'),
          'wickets': TextEditingController(text: '${existing?.wickets ?? 0}'),
          'maidens': TextEditingController(text: '${existing?.maidens ?? 0}'),
          'catches': TextEditingController(text: '${existing?.catches ?? 0}'),
          'stumpings':
              TextEditingController(text: '${existing?.stumpings ?? 0}'),
          'runOuts': TextEditingController(text: '${existing?.runOuts ?? 0}'),
        };
        _isOut[p.id] = existing?.isOut ?? false;
      }
      _loading = false;
    });
  }

  @override
  void dispose() {
    for (final map in _ctrls.values) {
      for (final c in map.values) c.dispose();
    }
    super.dispose();
  }

  // ── Save all stats ────────────────────────────────────────
  Future<void> _saveStats() async {
    setState(() => _saving = true);
    try {
      final stats = <String, FantasyPlayerStat>{};
      for (final p in _players) {
        final c = _ctrls[p.id]!;
        stats[p.id] = FantasyPlayerStat(
          runs: int.tryParse(c['runs']!.text) ?? 0,
          fours: int.tryParse(c['fours']!.text) ?? 0,
          sixes: int.tryParse(c['sixes']!.text) ?? 0,
          isOut: _isOut[p.id] ?? false,
          wickets: int.tryParse(c['wickets']!.text) ?? 0,
          maidens: int.tryParse(c['maidens']!.text) ?? 0,
          catches: int.tryParse(c['catches']!.text) ?? 0,
          stumpings: int.tryParse(c['stumpings']!.text) ?? 0,
          runOuts: int.tryParse(c['runOuts']!.text) ?? 0,
        );
      }
      await FantasyService.saveAllPlayerStats(
          matchId: widget.match.id, stats: stats);
      if (mounted) _showSnack('Stats saved ✓');
    } catch (e) {
      if (mounted) _showSnack('Failed: $e', isError: true);
    }
    if (mounted) setState(() => _saving = false);
  }

  // ── Calculate points ──────────────────────────────────────
  Future<void> _calculatePoints() async {
    // Confirm dialog
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Text('Calculate Points?',
            style: TextStyle(color: Colors.white, fontSize: 16)),
        content: const Text(
            'This will calculate points for all users and generate the leaderboard. Save stats first before calculating.',
            style: TextStyle(color: Colors.white54, fontSize: 13, height: 1.5)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child:
                const Text('Cancel', style: TextStyle(color: Colors.white38)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Calculate',
                style: TextStyle(color: _red, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    setState(() => _calculating = true);
    try {
      // Save stats first then calculate
      await _saveStats();
      await FantasyService.calculatePoints(widget.match.id);
      if (mounted) {
        _showSnack('Points calculated! Leaderboard is live 🏆');
        await Future.delayed(const Duration(milliseconds: 800));
        if (mounted) Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) _showSnack('Failed: $e', isError: true);
    }
    if (mounted) setState(() => _calculating = false);
  }

  void _showSnack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(
        content: Text(msg, style: const TextStyle(color: Colors.white)),
        backgroundColor:
            isError ? const Color(0xFFB71C1C) : const Color(0xFF2E7D32),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        duration: const Duration(seconds: 2),
      ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _surface,
        elevation: 0,
        title: const Text('Enter Match Stats',
            style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w700)),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: _border),
        ),
        actions: [
          // Save button in appbar
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: TextButton(
              onPressed: _saving ? null : _saveStats,
              child: _saving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: _red))
                  : const Text('Save',
                      style: TextStyle(
                          color: _red,
                          fontSize: 13,
                          fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: _red, strokeWidth: 1.5))
          : Column(children: [
              // ── Points formula reference ──────────────
              _PointsLegend(),

              // ── Players list ──────────────────────────
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    // Team A
                    _teamSection('teamA'),
                    const SizedBox(height: 16),
                    // Team B
                    _teamSection('teamB'),
                    const SizedBox(height: 100),
                  ],
                ),
              ),

              // ── Bottom buttons ────────────────────────
              Container(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                decoration: BoxDecoration(
                  color: _surface,
                  border: Border(top: BorderSide(color: _border)),
                ),
                child: Row(children: [
                  // Save stats
                  Expanded(
                      child: GestureDetector(
                    onTap: _saving ? null : _saveStats,
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      decoration: BoxDecoration(
                        color: Colors.white.withAlpha(10),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.white.withAlpha(20)),
                      ),
                      child: _saving
                          ? const Center(
                              child: SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2, color: Colors.white)))
                          : const Text('Save Stats',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600)),
                    ),
                  )),

                  const SizedBox(width: 12),

                  // Calculate points
                  Expanded(
                    flex: 2,
                    child: GestureDetector(
                      onTap: (_calculating || widget.match.pointsCalculated)
                          ? null
                          : _calculatePoints,
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        decoration: BoxDecoration(
                          color: widget.match.pointsCalculated
                              ? Colors.white.withAlpha(10)
                              : _calculating
                                  ? _red.withAlpha(100)
                                  : _red,
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: widget.match.pointsCalculated
                              ? []
                              : [
                                  BoxShadow(
                                      color: _red.withAlpha(60),
                                      blurRadius: 12,
                                      offset: const Offset(0, 4))
                                ],
                        ),
                        child: _calculating
                            ? const Center(
                                child: SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2, color: Colors.white)))
                            : Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                      widget.match.pointsCalculated
                                          ? Icons.check_circle_rounded
                                          : Icons.leaderboard_rounded,
                                      color: Colors.white,
                                      size: 16),
                                  const SizedBox(width: 8),
                                  Text(
                                      widget.match.pointsCalculated
                                          ? 'Points Calculated ✓'
                                          : 'Calculate Points',
                                      style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 14,
                                          fontWeight: FontWeight.w700)),
                                ],
                              ),
                      ),
                    ),
                  ),
                ]),
              ),
            ]),
    );
  }

  Widget _teamSection(String teamKey) {
    final teamPlayers = _players.where((p) => p.teamKey == teamKey).toList();
    if (teamPlayers.isEmpty) return const SizedBox.shrink();

    final teamName = teamPlayers.first.teamName;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Team label
        Row(children: [
          Container(
              width: 3,
              height: 14,
              decoration: BoxDecoration(
                  color: _red, borderRadius: BorderRadius.circular(2))),
          const SizedBox(width: 8),
          Text(teamName,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w700)),
        ]),
        const SizedBox(height: 10),

        // Player cards
        ...teamPlayers.map((p) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _PlayerStatCard(
                player: p,
                ctrls: _ctrls[p.id]!,
                isOut: _isOut[p.id] ?? false,
                onIsOutChanged: (val) => setState(() => _isOut[p.id] = val),
              ),
            )),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  PLAYER STAT CARD
// ─────────────────────────────────────────────────────────────

class _PlayerStatCard extends StatelessWidget {
  final FantasyPlayer player;
  final Map<String, TextEditingController> ctrls;
  final bool isOut;
  final ValueChanged<bool> onIsOutChanged;

  const _PlayerStatCard({
    required this.player,
    required this.ctrls,
    required this.isOut,
    required this.onIsOutChanged,
  });

  static const _surface = Color(0xFF141414);
  static const _surface2 = Color(0xFF1A1A1A);
  static const _border = Color(0xFF232323);

  Color get _roleColor => switch (player.role.toUpperCase()) {
        'WK' => const Color(0xFF9C27B0),
        'BAT' => const Color(0xFF2196F3),
        'AR' => const Color(0xFF4CAF50),
        'BOWL' => const Color(0xFFFF9800),
        _ => Colors.white38,
      };

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _border),
      ),
      child: Column(children: [
        // ── Player header ─────────────────────────────
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: _surface2,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(11)),
          ),
          child: Row(children: [
            // Role badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
              decoration: BoxDecoration(
                color: _roleColor.withAlpha(20),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: _roleColor.withAlpha(60)),
              ),
              child: Text(player.role.toUpperCase(),
                  style: TextStyle(
                      color: _roleColor,
                      fontSize: 9,
                      fontWeight: FontWeight.w800)),
            ),
            const SizedBox(width: 10),
            Expanded(
                child: Text(player.name,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w600),
                    overflow: TextOverflow.ellipsis)),

            // Is Out toggle
            Row(children: [
              Text('Out',
                  style: TextStyle(
                      color: isOut ? const Color(0xFFCC0000) : Colors.white38,
                      fontSize: 11)),
              const SizedBox(width: 6),
              GestureDetector(
                onTap: () => onIsOutChanged(!isOut),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  width: 36,
                  height: 20,
                  decoration: BoxDecoration(
                    color: isOut
                        ? const Color(0xFFCC0000).withAlpha(80)
                        : Colors.white.withAlpha(15),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                        color: isOut
                            ? const Color(0xFFCC0000)
                            : Colors.white.withAlpha(30)),
                  ),
                  child: AnimatedAlign(
                    duration: const Duration(milliseconds: 150),
                    alignment:
                        isOut ? Alignment.centerRight : Alignment.centerLeft,
                    child: Container(
                      margin: const EdgeInsets.all(2),
                      width: 16,
                      height: 16,
                      decoration: const BoxDecoration(
                          color: Colors.white, shape: BoxShape.circle),
                    ),
                  ),
                ),
              ),
            ]),
          ]),
        ),

        // ── Batting stats ─────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _statLabel('Batting'),
              const SizedBox(height: 8),
              Row(children: [
                _StatField(ctrl: ctrls['runs']!, label: 'Runs'),
                const SizedBox(width: 8),
                _StatField(ctrl: ctrls['fours']!, label: '4s'),
                const SizedBox(width: 8),
                _StatField(ctrl: ctrls['sixes']!, label: '6s'),
              ]),
            ],
          ),
        ),

        // ── Bowling stats ─────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _statLabel('Bowling'),
              const SizedBox(height: 8),
              Row(children: [
                _StatField(ctrl: ctrls['wickets']!, label: 'Wkts'),
                const SizedBox(width: 8),
                _StatField(ctrl: ctrls['maidens']!, label: 'Maidens'),
              ]),
            ],
          ),
        ),

        // ── Fielding stats ────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _statLabel('Fielding'),
              const SizedBox(height: 8),
              Row(children: [
                _StatField(ctrl: ctrls['catches']!, label: 'Catches'),
                const SizedBox(width: 8),
                _StatField(ctrl: ctrls['stumpings']!, label: 'Stump'),
                const SizedBox(width: 8),
                _StatField(ctrl: ctrls['runOuts']!, label: 'Run Out'),
              ]),
            ],
          ),
        ),
      ]),
    );
  }

  Widget _statLabel(String label) => Text(label,
      style: TextStyle(
          color: Colors.white.withAlpha(100),
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5));
}

// ─────────────────────────────────────────────────────────────
//  STAT FIELD
// ─────────────────────────────────────────────────────────────

class _StatField extends StatelessWidget {
  final TextEditingController ctrl;
  final String label;
  const _StatField({required this.ctrl, required this.label});

  @override
  Widget build(BuildContext context) {
    return Expanded(
        child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: TextStyle(
                color: Colors.white.withAlpha(80),
                fontSize: 10,
                fontWeight: FontWeight.w500)),
        const SizedBox(height: 4),
        SizedBox(
          height: 36,
          child: TextField(
            controller: ctrl,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            textAlign: TextAlign.center,
            style: const TextStyle(
                color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
            decoration: InputDecoration(
              filled: true,
              fillColor: Colors.white.withAlpha(8),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none),
              enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Colors.white.withAlpha(15))),
              focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Color(0xFFCC0000))),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
            ),
          ),
        ),
      ],
    ));
  }
}

// ─────────────────────────────────────────────────────────────
//  POINTS LEGEND — collapsible reference
// ─────────────────────────────────────────────────────────────

class _PointsLegend extends StatefulWidget {
  @override
  State<_PointsLegend> createState() => _PointsLegendState();
}

class _PointsLegendState extends State<_PointsLegend> {
  bool _expanded = false;

  static const _surface = Color(0xFF141414);
  static const _border = Color(0xFF232323);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _border),
      ),
      child: Column(children: [
        // Header — tap to expand
        GestureDetector(
          onTap: () => setState(() => _expanded = !_expanded),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(children: [
              const Icon(Icons.info_outline_rounded,
                  color: Colors.white38, size: 14),
              const SizedBox(width: 8),
              const Text('Points Formula',
                  style: TextStyle(
                      color: Colors.white60,
                      fontSize: 12,
                      fontWeight: FontWeight.w600)),
              const Spacer(),
              Icon(
                  _expanded
                      ? Icons.keyboard_arrow_up_rounded
                      : Icons.keyboard_arrow_down_rounded,
                  color: Colors.white38,
                  size: 16),
            ]),
          ),
        ),

        if (_expanded)
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Divider(height: 1, color: _border),
                const SizedBox(height: 10),
                _legendRow('Batting', [
                  'Run = 1pt',
                  '4 = +1pt',
                  '6 = +2pt',
                  '25 runs = +2pt',
                  '50 runs = +8pt',
                  '100 runs = +16pt',
                  'Duck = -2pt',
                ]),
                const SizedBox(height: 8),
                _legendRow('Bowling', [
                  'Wicket = 25pt',
                  'Maiden = 8pt',
                  '3 wkt = +4pt',
                  '5 wkt = +8pt',
                ]),
                const SizedBox(height: 8),
                _legendRow('Fielding', [
                  'Catch = 8pt',
                  'Stumping = 12pt',
                  'Run Out = 6pt',
                ]),
                const SizedBox(height: 8),
                _legendRow('Multipliers', [
                  'Captain = 2x',
                  'V.Captain = 1.5x',
                ]),
              ],
            ),
          ),
      ]),
    );
  }

  Widget _legendRow(String title, List<String> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title,
            style: TextStyle(
                color: Colors.white.withAlpha(120),
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5)),
        const SizedBox(height: 4),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: items
              .map((item) => Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.white.withAlpha(8),
                      borderRadius: BorderRadius.circular(5),
                      border: Border.all(color: Colors.white.withAlpha(15)),
                    ),
                    child: Text(item,
                        style: TextStyle(
                            color: Colors.white.withAlpha(160), fontSize: 10)),
                  ))
              .toList(),
        ),
      ],
    );
  }
}
