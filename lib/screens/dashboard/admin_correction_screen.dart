import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class AdminCorrectionScreen extends StatefulWidget {
  const AdminCorrectionScreen({super.key});
  @override
  State<AdminCorrectionScreen> createState() => _AdminCorrectionScreenState();
}

class _AdminCorrectionScreenState extends State<AdminCorrectionScreen> {
  static const _collection = 'featured_match';
  static const _docId = 'admin_current';

  final _doc = FirebaseFirestore.instance.collection(_collection).doc(_docId);
  final _rtdb = FirebaseDatabase.instance.ref('$_collection/$_docId');

  // ── Firestore — static data (meta, teams, toss) ──────────
  Map<String, dynamic>? _fsData;
  StreamSubscription? _fsSub;

  // ── RTDB — live data (scores, liveMatch, playerStats) ────
  Map<String, dynamic> _scores = {};
  Map<String, dynamic> _live = {};
  Map<String, dynamic> _playerStats = {};
  StreamSubscription? _rtdbSub;

  List<_Player> _allPlayers = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();

    // Firestore — team names, meta (rarely changes)
    _fsSub = _doc.snapshots().listen((snap) {
      if (!snap.exists || !mounted) return;
      final d = snap.data()!;
      setState(() {
        _fsData = d;
        _buildPlayerList(d);
        if (_rtdbSub != null) _loading = false;
      });
    });

    // RTDB — single root listener for all live fields
    _rtdbSub = _rtdb.onValue.listen((event) {
      if (!mounted) return;
      final raw = event.snapshot.value;
      if (raw == null || raw is! Map) return;
      final root = _deepMap(raw);
      setState(() {
        _scores = root['scores'] is Map ? _deepMap(root['scores']) : {};
        _live = root['liveMatch'] is Map ? _deepMap(root['liveMatch']) : {};
        _playerStats =
            root['playerStats'] is Map ? _deepMap(root['playerStats']) : {};
        if (_fsData != null) _loading = false;
      });
    });
  }

  void _buildPlayerList(Map<String, dynamic> d) {
    final teams = d['teams'] as Map<String, dynamic>? ?? {};
    final list = <_Player>[];
    for (final tk in ['teamA', 'teamB']) {
      final team = teams[tk] as Map<String, dynamic>? ?? {};
      final name = team['name'] as String? ?? tk;
      final players = team['players'] as List<dynamic>? ?? [];
      for (final p in players) {
        final pm = p as Map<String, dynamic>;
        list.add(_Player(
          id: pm['id'] as String? ?? '',
          name: pm['name'] as String? ?? '',
          teamKey: tk,
          teamName: name,
        ));
      }
    }
    _allPlayers = list;
  }

  static Map<String, dynamic> _deepMap(Map raw) =>
      raw.map((k, v) => MapEntry(k.toString(), v is Map ? _deepMap(v) : v));

  @override
  void dispose() {
    _fsSub?.cancel();
    _rtdbSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: Color(0xFF0A0A0A),
        body:
            Center(child: CircularProgressIndicator(color: Color(0xFFCC0000))),
      );
    }

    final teamAName =
        (_fsData!['teams']?['teamA']?['name'] as String?) ?? 'Team A';
    final teamBName =
        (_fsData!['teams']?['teamB']?['name'] as String?) ?? 'Team B';

    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF111111),
        elevation: 0,
        title: const Text('Live Data Correction',
            style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w700)),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Row(children: [
              Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                      color: Color(0xFF4CAF50), shape: BoxShape.circle)),
              const SizedBox(width: 6),
              const Text('Live',
                  style: TextStyle(color: Color(0xFF4CAF50), fontSize: 12)),
            ]),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── SCORE FIX ─────────────────────────────────────
          _Section(
            title: '📊 Score Fix',
            child: Column(children: [
              _ScoreFixCard(
                teamKey: 'teamA',
                teamName: teamAName,
                scores: _scores,
                rtdb: _rtdb,
              ),
              const SizedBox(height: 12),
              _ScoreFixCard(
                teamKey: 'teamB',
                teamName: teamBName,
                scores: _scores,
                rtdb: _rtdb,
              ),
            ]),
          ),
          const SizedBox(height: 16),

          // ── BATSMEN FIX ───────────────────────────────────
          _Section(
            title: '🏏 Current Batsmen',
            child:
                _BatsmenFixCard(live: _live, players: _allPlayers, rtdb: _rtdb),
          ),
          const SizedBox(height: 16),

          // ── BOWLER FIX ────────────────────────────────────
          _Section(
            title: '🎳 Current Bowler',
            child:
                _BowlerFixCard(live: _live, players: _allPlayers, rtdb: _rtdb),
          ),
          const SizedBox(height: 16),

          // ── PLAYER STATS FIX ──────────────────────────────
          _Section(
            title: '📈 Player Stats Fix',
            child: _PlayerStatsFixCard(
                players: _allPlayers, stats: _playerStats, rtdb: _rtdb),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  SCORE FIX — RTDB only
// ─────────────────────────────────────────────────────────────

class _ScoreFixCard extends StatefulWidget {
  final String teamKey, teamName;
  final Map<String, dynamic> scores;
  final DatabaseReference rtdb;
  const _ScoreFixCard(
      {required this.teamKey,
      required this.teamName,
      required this.scores,
      required this.rtdb});
  @override
  State<_ScoreFixCard> createState() => _ScoreFixCardState();
}

class _ScoreFixCardState extends State<_ScoreFixCard> {
  late TextEditingController _runs, _wickets, _overs, _balls;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _populate();
  }

  @override
  void didUpdateWidget(_ScoreFixCard old) {
    super.didUpdateWidget(old);
    // Refresh fields when RTDB data updates
    if (old.scores != widget.scores) _populate();
  }

  void _populate() {
    final s = widget.scores[widget.teamKey] as Map<String, dynamic>? ?? {};
    _runs = TextEditingController(text: '${s['runs'] ?? 0}');
    _wickets = TextEditingController(text: '${s['wickets'] ?? 0}');
    _overs = TextEditingController(text: '${s['overs'] ?? 0}');
    _balls = TextEditingController(text: '${s['balls'] ?? 0}');
  }

  @override
  void dispose() {
    _runs.dispose();
    _wickets.dispose();
    _overs.dispose();
    _balls.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final runs = int.tryParse(_runs.text.trim()) ?? 0;
    final wickets = int.tryParse(_wickets.text.trim()) ?? 0;
    final overs = int.tryParse(_overs.text.trim()) ?? 0;
    final balls = int.tryParse(_balls.text.trim()) ?? 0;

    setState(() => _saving = true);
    try {
      // RTDB only — scores ab Firestore mein nahi hain
      await widget.rtdb.child('scores/${widget.teamKey}').update({
        'runs': runs,
        'wickets': wickets,
        'overs': overs,
        'balls': balls,
      });
      if (mounted) _showSuccess('${widget.teamName} score updated ✓');
    } catch (e) {
      if (mounted) _showError('Failed: $e');
    }
    if (mounted) setState(() => _saving = false);
  }

  @override
  Widget build(BuildContext context) {
    return _Card(
        child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(widget.teamName,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w700)),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: _Field(ctrl: _runs, label: 'Runs')),
          const SizedBox(width: 8),
          Expanded(child: _Field(ctrl: _wickets, label: 'Wickets')),
          const SizedBox(width: 8),
          Expanded(child: _Field(ctrl: _overs, label: 'Overs')),
          const SizedBox(width: 8),
          Expanded(child: _Field(ctrl: _balls, label: 'Balls')),
        ]),
        const SizedBox(height: 12),
        _SaveBtn(saving: _saving, onTap: _save),
      ],
    ));
  }
}

// ─────────────────────────────────────────────────────────────
//  BATSMEN FIX — RTDB only
// ─────────────────────────────────────────────────────────────

class _BatsmenFixCard extends StatefulWidget {
  final Map<String, dynamic> live;
  final List<_Player> players;
  final DatabaseReference rtdb;
  const _BatsmenFixCard(
      {required this.live, required this.players, required this.rtdb});
  @override
  State<_BatsmenFixCard> createState() => _BatsmenFixCardState();
}

class _BatsmenFixCardState extends State<_BatsmenFixCard> {
  String? _striker, _nonStriker;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _striker = widget.live['striker'] as String?;
    _nonStriker = widget.live['nonStriker'] as String?;
  }

  @override
  void didUpdateWidget(_BatsmenFixCard old) {
    super.didUpdateWidget(old);
    if (old.live != widget.live) {
      _striker = widget.live['striker'] as String?;
      _nonStriker = widget.live['nonStriker'] as String?;
    }
  }

  Future<void> _save() async {
    if (_striker == null || _nonStriker == null) return;
    if (_striker == _nonStriker) {
      _showError('Striker and non-striker cannot be the same');
      return;
    }
    setState(() => _saving = true);
    try {
      // RTDB only — liveMatch ab Firestore mein nahi hai
      await widget.rtdb.child('liveMatch').update({
        'striker': _striker,
        'nonStriker': _nonStriker,
      });
      if (mounted) _showSuccess('Batsmen updated ✓');
    } catch (e) {
      if (mounted) _showError('Failed: $e');
    }
    if (mounted) setState(() => _saving = false);
  }

  @override
  Widget build(BuildContext context) {
    final battingTeam = widget.live['battingTeam'] as String? ?? 'teamA';
    final batters =
        widget.players.where((p) => p.teamKey == battingTeam).toList();
    return _Card(
        child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Expanded(
              child: _PlayerDropdown(
                  label: '🟢 Striker',
                  value: _striker,
                  players: batters,
                  onChanged: (v) => setState(() => _striker = v))),
          const SizedBox(width: 12),
          Expanded(
              child: _PlayerDropdown(
                  label: '⚪ Non-Striker',
                  value: _nonStriker,
                  players: batters,
                  onChanged: (v) => setState(() => _nonStriker = v))),
        ]),
        const SizedBox(height: 12),
        _SaveBtn(saving: _saving, onTap: _save),
      ],
    ));
  }
}

// ─────────────────────────────────────────────────────────────
//  BOWLER FIX — RTDB only
// ─────────────────────────────────────────────────────────────

class _BowlerFixCard extends StatefulWidget {
  final Map<String, dynamic> live;
  final List<_Player> players;
  final DatabaseReference rtdb;
  const _BowlerFixCard(
      {required this.live, required this.players, required this.rtdb});
  @override
  State<_BowlerFixCard> createState() => _BowlerFixCardState();
}

class _BowlerFixCardState extends State<_BowlerFixCard> {
  String? _bowler;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _bowler = widget.live['currentBowler'] as String?;
  }

  @override
  void didUpdateWidget(_BowlerFixCard old) {
    super.didUpdateWidget(old);
    if (old.live != widget.live) {
      _bowler = widget.live['currentBowler'] as String?;
    }
  }

  Future<void> _save() async {
    if (_bowler == null) return;
    setState(() => _saving = true);
    try {
      // RTDB only
      await widget.rtdb.child('liveMatch/currentBowler').set(_bowler);
      if (mounted) _showSuccess('Bowler updated ✓');
    } catch (e) {
      if (mounted) _showError('Failed: $e');
    }
    if (mounted) setState(() => _saving = false);
  }

  @override
  Widget build(BuildContext context) {
    final bowlingTeam = widget.live['bowlingTeam'] as String? ?? 'teamB';
    final bowlers =
        widget.players.where((p) => p.teamKey == bowlingTeam).toList();
    return _Card(
        child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _PlayerDropdown(
            label: '🎳 Current Bowler',
            value: _bowler,
            players: bowlers,
            onChanged: (v) => setState(() => _bowler = v)),
        const SizedBox(height: 12),
        _SaveBtn(saving: _saving, onTap: _save),
      ],
    ));
  }
}

// ─────────────────────────────────────────────────────────────
//  PLAYER STATS FIX — RTDB only
// ─────────────────────────────────────────────────────────────

class _PlayerStatsFixCard extends StatefulWidget {
  final List<_Player> players;
  final Map<String, dynamic> stats;
  final DatabaseReference rtdb;
  const _PlayerStatsFixCard(
      {required this.players, required this.stats, required this.rtdb});
  @override
  State<_PlayerStatsFixCard> createState() => _PlayerStatsFixCardState();
}

class _PlayerStatsFixCardState extends State<_PlayerStatsFixCard> {
  _Player? _selected;
  bool _saving = false;

  late TextEditingController _runs, _balls, _fours, _sixes;
  late TextEditingController _overs,
      _ballsBowled,
      _wickets,
      _runsConceded,
      _wides,
      _noBalls;

  @override
  void initState() {
    super.initState();
    _runs = TextEditingController();
    _balls = TextEditingController();
    _fours = TextEditingController();
    _sixes = TextEditingController();
    _overs = TextEditingController();
    _ballsBowled = TextEditingController();
    _wickets = TextEditingController();
    _runsConceded = TextEditingController();
    _wides = TextEditingController();
    _noBalls = TextEditingController();
  }

  @override
  void dispose() {
    for (final c in [
      _runs,
      _balls,
      _fours,
      _sixes,
      _overs,
      _ballsBowled,
      _wickets,
      _runsConceded,
      _wides,
      _noBalls
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  void _onPlayerSelected(_Player p) {
    setState(() => _selected = p);
    // Read from RTDB stats (passed as widget.stats)
    final s = widget.stats[p.id] as Map<String, dynamic>? ?? {};
    _runs.text = '${s['runs'] ?? 0}';
    _balls.text = '${s['balls'] ?? 0}';
    _fours.text = '${s['fours'] ?? 0}';
    _sixes.text = '${s['sixes'] ?? 0}';
    _overs.text = '${s['overs'] ?? 0}';
    _ballsBowled.text = '${s['ballsBowled'] ?? 0}';
    _wickets.text = '${s['wickets'] ?? 0}';
    _runsConceded.text = '${s['runsConceded'] ?? 0}';
    _wides.text = '${s['wides'] ?? 0}';
    _noBalls.text = '${s['noBalls'] ?? 0}';
  }

  Future<void> _save() async {
    final p = _selected;
    if (p == null) return;
    setState(() => _saving = true);

    final updated = {
      'runs': int.tryParse(_runs.text) ?? 0,
      'balls': int.tryParse(_balls.text) ?? 0,
      'fours': int.tryParse(_fours.text) ?? 0,
      'sixes': int.tryParse(_sixes.text) ?? 0,
      'overs': int.tryParse(_overs.text) ?? 0,
      'ballsBowled': int.tryParse(_ballsBowled.text) ?? 0,
      'wickets': int.tryParse(_wickets.text) ?? 0,
      'runsConceded': int.tryParse(_runsConceded.text) ?? 0,
      'wides': int.tryParse(_wides.text) ?? 0,
      'noBalls': int.tryParse(_noBalls.text) ?? 0,
    };

    try {
      // RTDB only — playerStats ab Firestore mein nahi hai
      await widget.rtdb.child('playerStats/${p.id}').update(updated);
      if (mounted) _showSuccess('${p.name} stats updated ✓');
    } catch (e) {
      if (mounted) _showError('Failed: $e');
    }
    if (mounted) setState(() => _saving = false);
  }

  @override
  Widget build(BuildContext context) {
    return _Card(
        child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _PlayerDropdown(
          label: 'Select Player',
          value: _selected?.id,
          players: widget.players,
          onChanged: (id) {
            final p = widget.players.firstWhere((p) => p.id == id);
            _onPlayerSelected(p);
          },
        ),
        if (_selected != null) ...[
          const SizedBox(height: 16),
          _StatsSectionLabel('Batting'),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(child: _Field(ctrl: _runs, label: 'Runs')),
            const SizedBox(width: 8),
            Expanded(child: _Field(ctrl: _balls, label: 'Balls')),
            const SizedBox(width: 8),
            Expanded(child: _Field(ctrl: _fours, label: '4s')),
            const SizedBox(width: 8),
            Expanded(child: _Field(ctrl: _sixes, label: '6s')),
          ]),
          const SizedBox(height: 14),
          _StatsSectionLabel('Bowling'),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(child: _Field(ctrl: _overs, label: 'Overs')),
            const SizedBox(width: 8),
            Expanded(child: _Field(ctrl: _ballsBowled, label: 'Balls')),
            const SizedBox(width: 8),
            Expanded(child: _Field(ctrl: _wickets, label: 'Wkts')),
          ]),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(child: _Field(ctrl: _runsConceded, label: 'Runs Given')),
            const SizedBox(width: 8),
            Expanded(child: _Field(ctrl: _wides, label: 'Wides')),
            const SizedBox(width: 8),
            Expanded(child: _Field(ctrl: _noBalls, label: 'No Balls')),
          ]),
          const SizedBox(height: 14),
          _SaveBtn(saving: _saving, onTap: _save),
        ],
      ],
    ));
  }
}

// ─────────────────────────────────────────────────────────────
//  SHARED WIDGETS
// ─────────────────────────────────────────────────────────────

class _Section extends StatelessWidget {
  final String title;
  final Widget child;
  const _Section({required this.title, required this.child});
  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w800)),
          const SizedBox(height: 10),
          child,
        ],
      );
}

class _Card extends StatelessWidget {
  final Widget child;
  const _Card({required this.child});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFF161616),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withAlpha(15)),
        ),
        child: child,
      );
}

class _Field extends StatelessWidget {
  final TextEditingController ctrl;
  final String label;
  const _Field({required this.ctrl, required this.label});
  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: TextStyle(
                  color: Colors.white.withAlpha(120),
                  fontSize: 10,
                  fontWeight: FontWeight.w500)),
          const SizedBox(height: 4),
          SizedBox(
            height: 38,
            child: TextField(
              controller: ctrl,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              style: const TextStyle(color: Colors.white, fontSize: 14),
              textAlign: TextAlign.center,
              decoration: InputDecoration(
                filled: true,
                fillColor: Colors.white.withAlpha(10),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: Colors.white.withAlpha(20))),
                enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: Colors.white.withAlpha(20))),
                focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Color(0xFFCC0000))),
                contentPadding: const EdgeInsets.symmetric(horizontal: 8),
              ),
            ),
          ),
        ],
      );
}

class _PlayerDropdown extends StatelessWidget {
  final String label;
  final String? value;
  final List<_Player> players;
  final void Function(String) onChanged;
  const _PlayerDropdown(
      {required this.label,
      required this.value,
      required this.players,
      required this.onChanged});
  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: TextStyle(
                  color: Colors.white.withAlpha(120),
                  fontSize: 10,
                  fontWeight: FontWeight.w500)),
          const SizedBox(height: 4),
          Container(
            height: 42,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              color: Colors.white.withAlpha(10),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.white.withAlpha(20)),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: players.any((p) => p.id == value) ? value : null,
                isExpanded: true,
                dropdownColor: const Color(0xFF1A1A1A),
                hint: Text('Select player',
                    style: TextStyle(
                        color: Colors.white.withAlpha(60), fontSize: 12)),
                items: players
                    .map((p) => DropdownMenuItem(
                          value: p.id,
                          child: Text('${p.name} (${p.teamName})',
                              style: const TextStyle(
                                  color: Colors.white, fontSize: 12),
                              overflow: TextOverflow.ellipsis),
                        ))
                    .toList(),
                onChanged: (v) {
                  if (v != null) onChanged(v);
                },
              ),
            ),
          ),
        ],
      );
}

class _SaveBtn extends StatelessWidget {
  final bool _saving;
  final VoidCallback _onTap;
  const _SaveBtn({required bool saving, required VoidCallback onTap})
      : _saving = saving,
        _onTap = onTap;
  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: _saving ? null : _onTap,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 11),
          decoration: BoxDecoration(
            color:
                _saving ? Colors.white.withAlpha(15) : const Color(0xFFCC0000),
            borderRadius: BorderRadius.circular(8),
          ),
          child: _saving
              ? const Center(
                  child: SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white)))
              : const Text('Save to Firebase',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w700)),
        ),
      );
}

class _StatsSectionLabel extends StatelessWidget {
  final String label;
  const _StatsSectionLabel(this.label);
  @override
  Widget build(BuildContext context) => Row(children: [
        Container(
            width: 3,
            height: 12,
            decoration: BoxDecoration(
                color: const Color(0xFFCC0000),
                borderRadius: BorderRadius.circular(2))),
        const SizedBox(width: 6),
        Text(label,
            style: TextStyle(
                color: Colors.white.withAlpha(160),
                fontSize: 11,
                fontWeight: FontWeight.w600)),
      ]);
}

class _Player {
  final String id, name, teamKey, teamName;
  const _Player(
      {required this.id,
      required this.name,
      required this.teamKey,
      required this.teamName});
}

extension _SnackExt on State {
  void _showSuccess(String msg) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(
        content: Text(msg, style: const TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF2E7D32),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ));
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(
        content: Text(msg, style: const TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFFB71C1C),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ));
  }
}
