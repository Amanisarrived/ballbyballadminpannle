import 'package:cricket_admin/services/fantasy_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

// ─────────────────────────────────────────────────────────────
//  FANTASY SETUP SCREEN
//  Match create + deadline + player credits assign
// ─────────────────────────────────────────────────────────────

class FantasySetupScreen extends StatefulWidget {
  final FantasyMatch? existingMatch;
  const FantasySetupScreen({super.key, this.existingMatch});

  @override
  State<FantasySetupScreen> createState() => _FantasySetupScreenState();
}

class _FantasySetupScreenState extends State<FantasySetupScreen> {
  static const _bg = Color(0xFF0D0D0D);
  static const _surface = Color(0xFF141414);
  static const _surface2 = Color(0xFF1A1A1A);
  static const _border = Color(0xFF232323);
  static const _red = Color(0xFFCC0000);

  DateTime? _deadline;
  List<FantasyPlayer> _players = [];
  Map<String, TextEditingController> _creditCtrls = {};
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _loadPlayers();
    if (widget.existingMatch != null) {
      _deadline = widget.existingMatch!.predictionDeadline;
    }
  }

  Future<void> _loadPlayers() async {
    final players = await FantasyService.getPlayersFromFeaturedMatch();
    final existing = widget.existingMatch?.playerCredits ?? {};

    setState(() {
      _players = players;
      _creditCtrls = {
        for (final p in players)
          p.id: TextEditingController(
            text: (existing[p.id] ?? _defaultCredit(p.role)).toString(),
          ),
      };
      _loading = false;
    });
  }

  double _defaultCredit(String role) => switch (role.toUpperCase()) {
        'WK' => 9.0,
        'BAT' => 8.5,
        'AR' => 9.0,
        'BOWL' => 8.5,
        _ => 8.0,
      };

  @override
  void dispose() {
    for (final c in _creditCtrls.values) c.dispose();
    super.dispose();
  }

  Future<void> _pickDeadline() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _deadline ?? DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 30)),
      builder: (ctx, child) => Theme(
        data: ThemeData.dark().copyWith(
          colorScheme: const ColorScheme.dark(primary: _red),
        ),
        child: child!,
      ),
    );
    if (date == null || !mounted) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_deadline ?? DateTime.now()),
      builder: (ctx, child) => Theme(
        data: ThemeData.dark().copyWith(
          colorScheme: const ColorScheme.dark(primary: _red),
        ),
        child: child!,
      ),
    );
    if (time == null || !mounted) return;

    setState(() {
      _deadline =
          DateTime(date.year, date.month, date.day, time.hour, time.minute);
    });
  }

  Future<void> _save() async {
    if (_deadline == null) {
      _showSnack('Please set prediction deadline', isError: true);
      return;
    }
    if (_players.isEmpty) {
      _showSnack('No players found in featured match', isError: true);
      return;
    }

    setState(() => _saving = true);
    try {
      final credits = <String, double>{};
      for (final p in _players) {
        final val =
            double.tryParse(_creditCtrls[p.id]?.text.trim() ?? '') ?? 8.0;
        credits[p.id] = val.clamp(5.0, 15.0);
      }

      await FantasyService.saveFantasyMatch(
        existingId: widget.existingMatch?.id,
        predictionDeadline: _deadline!,
        playerCredits: credits,
      );

      if (mounted) {
        _showSnack('Fantasy match saved ✓');
        await Future.delayed(const Duration(milliseconds: 800));
        if (mounted) Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) _showSnack('Failed: $e', isError: true);
    }
    if (mounted) setState(() => _saving = false);
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
        title: Text(
          widget.existingMatch != null
              ? 'Edit Fantasy Match'
              : 'New Fantasy Match',
          style: const TextStyle(
              color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: _border),
        ),
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: _red, strokeWidth: 1.5))
          : Column(children: [
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    // ── Deadline picker ───────────────────
                    _SectionLabel('Prediction Deadline'),
                    const SizedBox(height: 8),
                    GestureDetector(
                      onTap: _pickDeadline,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 14),
                        decoration: BoxDecoration(
                          color: _surface,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                              color: _deadline != null
                                  ? _red.withAlpha(80)
                                  : _border),
                        ),
                        child: Row(children: [
                          Icon(Icons.schedule_rounded,
                              color: _deadline != null ? _red : Colors.white38,
                              size: 18),
                          const SizedBox(width: 12),
                          Text(
                            _deadline != null
                                ? DateFormat('dd MMM yyyy • hh:mm a')
                                    .format(_deadline!)
                                : 'Tap to set deadline',
                            style: TextStyle(
                              color: _deadline != null
                                  ? Colors.white
                                  : Colors.white38,
                              fontSize: 14,
                              fontWeight: _deadline != null
                                  ? FontWeight.w600
                                  : FontWeight.w400,
                            ),
                          ),
                          const Spacer(),
                          const Icon(Icons.chevron_right_rounded,
                              color: Colors.white24, size: 18),
                        ]),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // ── Players + Credits ─────────────────
                    _SectionLabel(
                        'Player Credits  (${_players.length} players)'),
                    const SizedBox(height: 4),
                    Text('Assign credits 5.0 — 15.0 per player',
                        style: TextStyle(
                            color: Colors.white.withAlpha(60), fontSize: 11)),
                    const SizedBox(height: 12),

                    if (_players.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: _surface,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: _border),
                        ),
                        child: const Text(
                          'No players found.\nPlease setup teams in Featured Match first.',
                          style: TextStyle(
                              color: Colors.white38, fontSize: 13, height: 1.5),
                          textAlign: TextAlign.center,
                        ),
                      )
                    else ...[
                      // Team A
                      _TeamSection(
                        teamName: _players
                            .firstWhere((p) => p.teamKey == 'teamA',
                                orElse: () => _players.first)
                            .teamName,
                        players: _players
                            .where((p) => p.teamKey == 'teamA')
                            .toList(),
                        creditCtrls: _creditCtrls,
                      ),
                      const SizedBox(height: 16),

                      // Team B
                      _TeamSection(
                        teamName: _players
                            .firstWhere((p) => p.teamKey == 'teamB',
                                orElse: () => _players.first)
                            .teamName,
                        players: _players
                            .where((p) => p.teamKey == 'teamB')
                            .toList(),
                        creditCtrls: _creditCtrls,
                      ),
                    ],

                    const SizedBox(height: 32),
                  ],
                ),
              ),

              // ── Save button ───────────────────────────
              Container(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                decoration: BoxDecoration(
                  color: _surface,
                  border: Border(top: BorderSide(color: _border)),
                ),
                child: GestureDetector(
                  onTap: _saving ? null : _save,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      color: _saving ? _red.withAlpha(100) : _red,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                            color: _red.withAlpha(60),
                            blurRadius: 16,
                            offset: const Offset(0, 4)),
                      ],
                    ),
                    child: _saving
                        ? const Center(
                            child: SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white)))
                        : Text(
                            widget.existingMatch != null
                                ? 'Update Match'
                                : 'Create Fantasy Match',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 15,
                                fontWeight: FontWeight.w700)),
                  ),
                ),
              ),
            ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  TEAM SECTION
// ─────────────────────────────────────────────────────────────

class _TeamSection extends StatelessWidget {
  final String teamName;
  final List<FantasyPlayer> players;
  final Map<String, TextEditingController> creditCtrls;

  const _TeamSection({
    required this.teamName,
    required this.players,
    required this.creditCtrls,
  });

  static const _surface = Color(0xFF141414);
  static const _border = Color(0xFF232323);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _border),
      ),
      child: Column(children: [
        // Team header
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white.withAlpha(6),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(11)),
          ),
          child: Text(teamName,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w700)),
        ),

        // Players
        ...players.asMap().entries.map((e) {
          final idx = e.key;
          final player = e.value;
          return Column(children: [
            if (idx > 0) Divider(height: 1, color: _border),
            _PlayerCreditRow(player: player, ctrl: creditCtrls[player.id]!),
          ]);
        }),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  PLAYER CREDIT ROW
// ─────────────────────────────────────────────────────────────

class _PlayerCreditRow extends StatelessWidget {
  final FantasyPlayer player;
  final TextEditingController ctrl;

  const _PlayerCreditRow({required this.player, required this.ctrl});

  Color get _roleColor => switch (player.role.toUpperCase()) {
        'WK' => const Color(0xFF9C27B0),
        'BAT' => const Color(0xFF2196F3),
        'AR' => const Color(0xFF4CAF50),
        'BOWL' => const Color(0xFFFF9800),
        _ => Colors.white38,
      };

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(children: [
        // Role badge
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: _roleColor.withAlpha(20),
            shape: BoxShape.circle,
            border: Border.all(color: _roleColor.withAlpha(60)),
          ),
          child: Center(
              child: Text(
            player.role.length > 2
                ? player.role.substring(0, 2).toUpperCase()
                : player.role.toUpperCase(),
            style: TextStyle(
                color: _roleColor, fontSize: 9, fontWeight: FontWeight.w800),
          )),
        ),
        const SizedBox(width: 12),

        // Name
        Expanded(
            child: Text(player.name,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w500),
                overflow: TextOverflow.ellipsis)),

        // Credits input
        SizedBox(
          width: 64,
          height: 36,
          child: TextField(
            controller: ctrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,1}')),
            ],
            textAlign: TextAlign.center,
            style: const TextStyle(
                color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
            decoration: InputDecoration(
              filled: true,
              fillColor: Colors.white.withAlpha(10),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none),
              enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Colors.white.withAlpha(20))),
              focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Color(0xFFCC0000))),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            ),
          ),
        ),

        const SizedBox(width: 6),
        Text('cr',
            style: TextStyle(color: Colors.white.withAlpha(60), fontSize: 11)),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  SECTION LABEL
// ─────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel(this.label);

  @override
  Widget build(BuildContext context) => Row(children: [
        Container(
            width: 3,
            height: 14,
            decoration: BoxDecoration(
                color: const Color(0xFFCC0000),
                borderRadius: BorderRadius.circular(2))),
        const SizedBox(width: 8),
        Text(label,
            style: TextStyle(
                color: Colors.white.withAlpha(200),
                fontSize: 13,
                fontWeight: FontWeight.w700)),
      ]);
}
