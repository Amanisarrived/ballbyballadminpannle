import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cricket_admin/services/upcoming_fixtures_service.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

// ── Theme ─────────────────────────────────────────────────
const _bg = Color(0xFF0D0D0D);
const _surface = Color(0xFF141414);
const _surface2 = Color(0xFF1A1A1A);
const _surface3 = Color(0xFF202020);
const _border = Color(0xFF232323);
const _border2 = Color(0xFF2A2A2A);
const _textPrimary = Color(0xFFE8E8E8);
const _textSecondary = Color(0xFF666666);
const _textMuted = Color(0xFF3A3A3A);

// ══════════════════════════════════════════════════════════
//  SCREEN
// ══════════════════════════════════════════════════════════
class UpcomingFixturesScreen extends StatelessWidget {
  const UpcomingFixturesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: Column(
        children: [
          _ScreenHeader(
            onAdd: () => _showFixtureDialog(context, fixture: null),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: UpcomingFixturesService.stream(),
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(
                        color: Colors.redAccent, strokeWidth: 2),
                  );
                }
                final docs = snap.data?.docs ?? [];
                if (docs.isEmpty) return const _EmptyState();
                final fixtures =
                    docs.map(UpcomingFixturesService.fromDoc).toList();
                return ListView.separated(
                  padding: const EdgeInsets.all(24),
                  itemCount: fixtures.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (_, i) => _FixtureCard(
                    fixture: fixtures[i],
                    onEdit: () =>
                        _showFixtureDialog(context, fixture: fixtures[i]),
                    onDelete: () =>
                        _showDeleteDialog(context, fixtures[i]['id'] as String),
                    onSetResult: () => _showResultDialog(context, fixtures[i]),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  static Future<void> _showFixtureDialog(
    BuildContext context, {
    required Map<String, dynamic>? fixture,
  }) =>
      showDialog(
        context: context,
        builder: (_) => _FixtureFormDialog(fixture: fixture),
      );

  static Future<void> _showDeleteDialog(
      BuildContext context, String docId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => _DeleteDialog(),
    );
    if (confirm == true) await UpcomingFixturesService.deleteFixture(docId);
  }

  static Future<void> _showResultDialog(
          BuildContext context, Map<String, dynamic> fixture) =>
      showDialog(
        context: context,
        builder: (_) => _MatchResultDialog(fixture: fixture),
      );
}

// ══════════════════════════════════════════════════════════
//  HEADER
// ══════════════════════════════════════════════════════════
class _ScreenHeader extends StatelessWidget {
  final VoidCallback onAdd;
  const _ScreenHeader({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 72,
      padding: const EdgeInsets.symmetric(horizontal: 28),
      decoration: const BoxDecoration(
        color: _surface,
        border: Border(bottom: BorderSide(color: _border)),
      ),
      child: Row(
        children: [
          const Icon(Icons.calendar_month_rounded,
              color: _textSecondary, size: 18),
          const SizedBox(width: 12),
          const Text('Upcoming Fixtures',
              style: TextStyle(
                  color: _textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w700)),
          const Spacer(),
          _AddButton(onTap: onAdd),
        ],
      ),
    );
  }
}

class _AddButton extends StatefulWidget {
  final VoidCallback onTap;
  const _AddButton({required this.onTap});
  @override
  State<_AddButton> createState() => _AddButtonState();
}

class _AddButtonState extends State<_AddButton> {
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
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
          decoration: BoxDecoration(
            color: _hovered
                ? Colors.redAccent.withOpacity(0.85)
                : Colors.redAccent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.add_rounded, color: Colors.white, size: 16),
              SizedBox(width: 7),
              Text('Add Fixture',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w700)),
            ],
          ),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════
//  FIXTURE CARD
// ══════════════════════════════════════════════════════════
class _FixtureCard extends StatefulWidget {
  final Map<String, dynamic> fixture;
  final VoidCallback onEdit, onDelete, onSetResult;
  const _FixtureCard({
    required this.fixture,
    required this.onEdit,
    required this.onDelete,
    required this.onSetResult,
  });
  @override
  State<_FixtureCard> createState() => _FixtureCardState();
}

class _FixtureCardState extends State<_FixtureCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final f = widget.fixture;
    final time = f['time'] as DateTime;
    final winner = f['winningTeam'] as String;
    final t1Score = f['team1Score'] as String;
    final t2Score = f['team2Score'] as String;
    final potm = f['playerOfMatch'] as String;
    final potmPhoto = f['playerOfMatchPhoto'] as String;
    final result = f['resultSummary'] as String;
    final hasResult = UpcomingFixturesService.hasResult(f);
    final isUpcoming = UpcomingFixturesService.isUpcoming(f);
    final isLive = UpcomingFixturesService.isLive(f);

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 130),
        decoration: BoxDecoration(
          color: _hovered ? _surface2 : _surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: hasResult
                ? Colors.greenAccent.withOpacity(0.15)
                : isLive
                    ? Colors.redAccent.withOpacity(0.2)
                    : _hovered
                        ? _border2
                        : _border,
          ),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                // ── Status pill ──────────────────────────
                _StatusPill(
                  hasResult: hasResult,
                  isLive: isLive,
                  isUpcoming: isUpcoming,
                ),
                const SizedBox(width: 10),
                // ── Tournament ───────────────────────────
                Icon(Icons.emoji_events_rounded,
                    size: 11, color: Colors.amber.withOpacity(0.7)),
                const SizedBox(width: 4),
                Text(f['tournament'] as String,
                    style: const TextStyle(
                        color: _textSecondary,
                        fontSize: 11,
                        fontWeight: FontWeight.w500)),
                const SizedBox(width: 10),
                // ── Venue ────────────────────────────────
                const Icon(Icons.location_on_rounded,
                    size: 11, color: _textSecondary),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(f['venue'] as String,
                      overflow: TextOverflow.ellipsis,
                      style:
                          const TextStyle(color: _textSecondary, fontSize: 11)),
                ),
                // ── Time ─────────────────────────────────
                Text(DateFormat('d MMM  ·  HH:mm').format(time),
                    style:
                        const TextStyle(color: _textSecondary, fontSize: 11)),
                // ── Actions on hover ─────────────────────
                if (_hovered) ...[
                  const SizedBox(width: 12),
                  _ActionBtn(
                    icon: Icons.scoreboard_rounded,
                    tooltip: 'Set Match Result',
                    color: Colors.greenAccent,
                    onTap: widget.onSetResult,
                  ),
                  const SizedBox(width: 6),
                  _ActionBtn(
                    icon: Icons.edit_rounded,
                    tooltip: 'Edit',
                    color: _textSecondary,
                    onTap: widget.onEdit,
                  ),
                  const SizedBox(width: 6),
                  _ActionBtn(
                    icon: Icons.delete_rounded,
                    tooltip: 'Delete',
                    color: Colors.redAccent,
                    onTap: widget.onDelete,
                  ),
                ],
              ],
            ),

            const SizedBox(height: 16),

            // ── Teams row ────────────────────────────────
            Row(
              children: [
                // Team 1
                Expanded(
                  child: _TeamSide(
                    name: f['team1'] as String,
                    logo: f['team1Logo'] as String,
                    score: t1Score,
                    isWinner: winner == f['team1'] && winner.isNotEmpty,
                    align: CrossAxisAlignment.start,
                  ),
                ),

                // VS / Score divider
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    children: [
                      Text('vs',
                          style: TextStyle(
                              color: _textMuted,
                              fontSize: 13,
                              fontWeight: FontWeight.w700)),
                    ],
                  ),
                ),

                // Team 2
                Expanded(
                  child: _TeamSide(
                    name: f['team2'] as String,
                    logo: f['team2Logo'] as String,
                    score: t2Score,
                    isWinner: winner == f['team2'] && winner.isNotEmpty,
                    align: CrossAxisAlignment.end,
                  ),
                ),
              ],
            ),

            // ── Result section (only if hasResult) ───────
            if (hasResult) ...[
              const SizedBox(height: 14),
              Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.greenAccent.withOpacity(0.04),
                  borderRadius: BorderRadius.circular(10),
                  border:
                      Border.all(color: Colors.greenAccent.withOpacity(0.12)),
                ),
                child: Row(
                  children: [
                    // Player of the match
                    if (potm.isNotEmpty) ...[
                      if (potmPhoto.isNotEmpty)
                        Container(
                          width: 32,
                          height: 32,
                          margin: const EdgeInsets.only(right: 10),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                                color: Colors.greenAccent.withOpacity(0.3)),
                          ),
                          child: ClipOval(
                            child: Image.network(potmPhoto,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => const Icon(
                                    Icons.person_rounded,
                                    color: _textMuted,
                                    size: 16)),
                          ),
                        ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Player of the Match',
                              style: TextStyle(
                                  color: Colors.greenAccent.withOpacity(0.6),
                                  fontSize: 9,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.5)),
                          Text(potm,
                              style: const TextStyle(
                                  color: Colors.greenAccent,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700)),
                        ],
                      ),
                      const SizedBox(width: 16),
                      Container(
                          width: 1,
                          height: 28,
                          color: Colors.greenAccent.withOpacity(0.15)),
                      const SizedBox(width: 16),
                    ],
                    // Result summary
                    if (result.isNotEmpty)
                      Expanded(
                        child: Text(result,
                            style: const TextStyle(
                                color: _textSecondary,
                                fontSize: 12,
                                fontWeight: FontWeight.w500)),
                      ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ── Team side widget ──────────────────────────────────────
class _TeamSide extends StatelessWidget {
  final String name, logo, score;
  final bool isWinner;
  final CrossAxisAlignment align;

  const _TeamSide({
    required this.name,
    required this.logo,
    required this.score,
    required this.isWinner,
    required this.align,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: align,
      children: [
        Row(
          mainAxisAlignment: align == CrossAxisAlignment.start
              ? MainAxisAlignment.start
              : MainAxisAlignment.end,
          children: [
            if (align == CrossAxisAlignment.end && isWinner) ...[
              const Icon(Icons.military_tech_rounded,
                  color: Colors.greenAccent, size: 14),
              const SizedBox(width: 4),
            ],
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color:
                    isWinner ? Colors.greenAccent.withOpacity(0.08) : _surface3,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color:
                      isWinner ? Colors.greenAccent.withOpacity(0.3) : _border,
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(7),
                child: logo.isNotEmpty
                    ? Image.network(logo,
                        fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) => _LogoFallback(name: name))
                    : _LogoFallback(name: name),
              ),
            ),
            const SizedBox(width: 8),
            Text(name,
                style: TextStyle(
                    color: isWinner ? Colors.greenAccent : _textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w700)),
            if (align == CrossAxisAlignment.start && isWinner) ...[
              const SizedBox(width: 4),
              const Icon(Icons.military_tech_rounded,
                  color: Colors.greenAccent, size: 14),
            ],
          ],
        ),
        if (score.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(score,
              style: TextStyle(
                  color: isWinner ? Colors.greenAccent : _textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  fontFeatures: const [FontFeature.tabularFigures()])),
        ],
      ],
    );
  }
}

// ── Status pill ───────────────────────────────────────────
class _StatusPill extends StatelessWidget {
  final bool hasResult, isLive, isUpcoming;
  const _StatusPill({
    required this.hasResult,
    required this.isLive,
    required this.isUpcoming,
  });

  @override
  Widget build(BuildContext context) {
    Color color;
    String label;
    if (hasResult) {
      color = Colors.greenAccent;
      label = 'ENDED';
    } else if (isLive) {
      color = Colors.redAccent;
      label = 'LIVE';
    } else {
      color = Colors.blueAccent;
      label = 'UPCOMING';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isLive)
            Container(
              width: 5,
              height: 5,
              margin: const EdgeInsets.only(right: 4),
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
          Text(label,
              style: TextStyle(
                  color: color,
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.5)),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════
//  FIXTURE FORM DIALOG  (Add / Edit)
// ══════════════════════════════════════════════════════════
class _FixtureFormDialog extends StatefulWidget {
  final Map<String, dynamic>? fixture;
  const _FixtureFormDialog({this.fixture});
  @override
  State<_FixtureFormDialog> createState() => _FixtureFormDialogState();
}

class _FixtureFormDialogState extends State<_FixtureFormDialog> {
  final _team1Ctrl = TextEditingController();
  final _team1LogoCtrl = TextEditingController();
  final _team2Ctrl = TextEditingController();
  final _team2LogoCtrl = TextEditingController();
  final _tournamentCtrl = TextEditingController();
  final _venueCtrl = TextEditingController();

  DateTime _selectedDate = DateTime.now().add(const Duration(days: 1));
  TimeOfDay _selectedTime = const TimeOfDay(hour: 14, minute: 0);
  bool _saving = false;

  bool get _isEdit => widget.fixture != null;

  @override
  void initState() {
    super.initState();
    if (_isEdit) {
      final f = widget.fixture!;
      _team1Ctrl.text = f['team1'] as String;
      _team1LogoCtrl.text = f['team1Logo'] as String;
      _team2Ctrl.text = f['team2'] as String;
      _team2LogoCtrl.text = f['team2Logo'] as String;
      _tournamentCtrl.text = f['tournament'] as String;
      _venueCtrl.text = f['venue'] as String;
      final dt = f['time'] as DateTime;
      _selectedDate = dt;
      _selectedTime = TimeOfDay(hour: dt.hour, minute: dt.minute);
    }
  }

  @override
  void dispose() {
    for (final c in [
      _team1Ctrl,
      _team1LogoCtrl,
      _team2Ctrl,
      _team2LogoCtrl,
      _tournamentCtrl,
      _venueCtrl
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  bool get _valid =>
      _team1Ctrl.text.trim().isNotEmpty &&
      _team2Ctrl.text.trim().isNotEmpty &&
      _tournamentCtrl.text.trim().isNotEmpty &&
      _venueCtrl.text.trim().isNotEmpty;

  DateTime get _combinedDateTime => DateTime(
        _selectedDate.year,
        _selectedDate.month,
        _selectedDate.day,
        _selectedTime.hour,
        _selectedTime.minute,
      );

  Future<void> _pickDate() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      builder: (ctx, child) => Theme(
        data: ThemeData.dark().copyWith(
          colorScheme: const ColorScheme.dark(
              primary: Colors.redAccent, surface: Color(0xFF1A1A1A)),
          dialogBackgroundColor: const Color(0xFF141414),
        ),
        child: child!,
      ),
    );
    if (d != null) setState(() => _selectedDate = d);
  }

  Future<void> _pickTime() async {
    final t = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
      builder: (ctx, child) => Theme(
        data: ThemeData.dark().copyWith(
          colorScheme: const ColorScheme.dark(
              primary: Colors.redAccent, surface: Color(0xFF1A1A1A)),
          dialogBackgroundColor: const Color(0xFF141414),
        ),
        child: child!,
      ),
    );
    if (t != null) setState(() => _selectedTime = t);
  }

  Future<void> _save() async {
    if (!_valid || _saving) return;
    setState(() => _saving = true);
    try {
      if (_isEdit) {
        await UpcomingFixturesService.updateFixture(
          widget.fixture!['id'] as String,
          team1: _team1Ctrl.text.trim(),
          team1Logo: _team1LogoCtrl.text.trim(),
          team2: _team2Ctrl.text.trim(),
          team2Logo: _team2LogoCtrl.text.trim(),
          time: _combinedDateTime,
          tournament: _tournamentCtrl.text.trim(),
          venue: _venueCtrl.text.trim(),
          winningTeam: widget.fixture!['winningTeam'] as String,
          team1Score: widget.fixture!['team1Score'] as String,
          team2Score: widget.fixture!['team2Score'] as String,
          playerOfMatch: widget.fixture!['playerOfMatch'] as String,
          playerOfMatchPhoto: widget.fixture!['playerOfMatchPhoto'] as String,
          resultSummary: widget.fixture!['resultSummary'] as String,
        );
      } else {
        await UpcomingFixturesService.addFixture(
          team1: _team1Ctrl.text.trim(),
          team1Logo: _team1LogoCtrl.text.trim(),
          team2: _team2Ctrl.text.trim(),
          team2Logo: _team2LogoCtrl.text.trim(),
          time: _combinedDateTime,
          tournament: _tournamentCtrl.text.trim(),
          venue: _venueCtrl.text.trim(),
        );
      }
      if (mounted) Navigator.pop(context);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: _surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: _border),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520, maxHeight: 700),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Title
              _DialogTitle(
                icon: Icons.calendar_month_rounded,
                label: _isEdit ? 'Edit Fixture' : 'Add Fixture',
              ),
              const SizedBox(height: 24),

              // Team 1
              const _SectionLabel('TEAM 1'),
              const SizedBox(height: 8),
              _FormField(controller: _team1Ctrl, hint: 'e.g. India'),
              const SizedBox(height: 8),
              _FormField(
                  controller: _team1LogoCtrl,
                  hint: 'Logo URL (optional)',
                  icon: Icons.image_rounded),
              const SizedBox(height: 20),

              // Team 2
              const _SectionLabel('TEAM 2'),
              const SizedBox(height: 8),
              _FormField(controller: _team2Ctrl, hint: 'e.g. Australia'),
              const SizedBox(height: 8),
              _FormField(
                  controller: _team2LogoCtrl,
                  hint: 'Logo URL (optional)',
                  icon: Icons.image_rounded),
              const SizedBox(height: 20),

              // Tournament & Venue
              const _SectionLabel('DETAILS'),
              const SizedBox(height: 8),
              _FormField(
                  controller: _tournamentCtrl,
                  hint: 'Tournament  e.g. IPL 2025',
                  icon: Icons.emoji_events_rounded),
              const SizedBox(height: 8),
              _FormField(
                  controller: _venueCtrl,
                  hint: 'Venue  e.g. Wankhede Stadium, Mumbai',
                  icon: Icons.location_on_rounded),
              const SizedBox(height: 20),

              // Date & Time
              const _SectionLabel('MATCH DATE & TIME'),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: _DateTimePickerBtn(
                      icon: Icons.calendar_today_rounded,
                      label: DateFormat('EEE, d MMM y').format(_selectedDate),
                      onTap: _pickDate,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _DateTimePickerBtn(
                      icon: Icons.schedule_rounded,
                      label: _selectedTime.format(context),
                      onTap: _pickTime,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 28),

              Row(
                children: [
                  Expanded(
                      child: _CancelBtn(onTap: () => Navigator.pop(context))),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _ConfirmBtn(
                      label: _saving
                          ? 'Saving…'
                          : _isEdit
                              ? 'Save Changes'
                              : 'Add Fixture',
                      enabled: _valid && !_saving,
                      onTap: _save,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════
//  MATCH RESULT DIALOG  ← NEW
// ══════════════════════════════════════════════════════════
class _MatchResultDialog extends StatefulWidget {
  final Map<String, dynamic> fixture;
  const _MatchResultDialog({required this.fixture});
  @override
  State<_MatchResultDialog> createState() => _MatchResultDialogState();
}

class _MatchResultDialogState extends State<_MatchResultDialog> {
  final _team1ScoreCtrl = TextEditingController();
  final _team2ScoreCtrl = TextEditingController();
  final _potmCtrl = TextEditingController();
  final _potmPhotoCtrl = TextEditingController();
  final _resultCtrl = TextEditingController();

  String _selectedWinner = '';
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final f = widget.fixture;
    _team1ScoreCtrl.text = f['team1Score'] as String? ?? '';
    _team2ScoreCtrl.text = f['team2Score'] as String? ?? '';
    _potmCtrl.text = f['playerOfMatch'] as String? ?? '';
    _potmPhotoCtrl.text = f['playerOfMatchPhoto'] as String? ?? '';
    _resultCtrl.text = f['resultSummary'] as String? ?? '';
    _selectedWinner = f['winningTeam'] as String? ?? '';
  }

  @override
  void dispose() {
    for (final c in [
      _team1ScoreCtrl,
      _team2ScoreCtrl,
      _potmCtrl,
      _potmPhotoCtrl,
      _resultCtrl
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  void _pickWinner(String team) {
    setState(() {
      _selectedWinner = team;
      if (_resultCtrl.text.isEmpty) {
        _resultCtrl.text = '$team won by ';
        _resultCtrl.selection = TextSelection.fromPosition(
            TextPosition(offset: _resultCtrl.text.length));
      }
    });
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      await UpcomingFixturesService.updateMatchResult(
        widget.fixture['id'] as String,
        winningTeam: _selectedWinner,
        team1Score: _team1ScoreCtrl.text.trim(),
        team2Score: _team2ScoreCtrl.text.trim(),
        playerOfMatch: _potmCtrl.text.trim(),
        playerOfMatchPhoto: _potmPhotoCtrl.text.trim(),
        resultSummary: _resultCtrl.text.trim(),
      );
      if (mounted) Navigator.pop(context);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _clear() async {
    setState(() => _saving = true);
    try {
      await UpcomingFixturesService.updateMatchResult(
        widget.fixture['id'] as String,
        winningTeam: '',
        team1Score: '',
        team2Score: '',
        playerOfMatch: '',
        playerOfMatchPhoto: '',
        resultSummary: '',
      );
      if (mounted) Navigator.pop(context);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final team1 = widget.fixture['team1'] as String;
    final team2 = widget.fixture['team2'] as String;
    final t1Logo = widget.fixture['team1Logo'] as String;
    final t2Logo = widget.fixture['team2Logo'] as String;

    return Dialog(
      backgroundColor: _surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: _border),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560, maxHeight: 780),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Title
              const _DialogTitle(
                icon: Icons.scoreboard_rounded,
                label: 'Match Result',
                color: Colors.greenAccent,
              ),
              const SizedBox(height: 24),

              // ── Winner ──────────────────────────────────
              const _SectionLabel('WINNER'),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: _TeamPickBtn(
                      name: team1,
                      logo: t1Logo,
                      selected: _selectedWinner == team1,
                      onTap: () => _pickWinner(team1),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _TeamPickBtn(
                      name: team2,
                      logo: t2Logo,
                      selected: _selectedWinner == team2,
                      onTap: () => _pickWinner(team2),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // ── Scores ──────────────────────────────────
              const _SectionLabel('SCORES'),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: _FormField(
                      controller: _team1ScoreCtrl,
                      hint: '$team1 score  e.g. 245/6 (50 ov)',
                      icon: Icons.sports_cricket_rounded,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _FormField(
                      controller: _team2ScoreCtrl,
                      hint: '$team2 score  e.g. 243/8 (50 ov)',
                      icon: Icons.sports_cricket_rounded,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // ── Result summary ───────────────────────────
              const _SectionLabel('RESULT SUMMARY'),
              const SizedBox(height: 8),
              _FormField(
                controller: _resultCtrl,
                hint: 'e.g. India won by 2 runs',
                icon: Icons.military_tech_rounded,
              ),
              const SizedBox(height: 4),
              const Text('Tap a team above to auto-fill',
                  style: TextStyle(color: _textMuted, fontSize: 11)),
              const SizedBox(height: 20),

              // ── Player of the match ──────────────────────
              const _SectionLabel('PLAYER OF THE MATCH'),
              const SizedBox(height: 8),
              _FormField(
                controller: _potmCtrl,
                hint: 'Player name  e.g. Virat Kohli',
                icon: Icons.person_rounded,
              ),
              const SizedBox(height: 8),
              _FormField(
                controller: _potmPhotoCtrl,
                hint: 'Player photo URL (optional)',
                icon: Icons.image_rounded,
              ),
              const SizedBox(height: 28),

              // ── Actions ─────────────────────────────────
              Row(
                children: [
                  // Clear result
                  Tooltip(
                    message: 'Clear all result data',
                    child: _ActionBtn(
                      icon: Icons.refresh_rounded,
                      tooltip: 'Clear',
                      color: _textSecondary,
                      onTap: _clear,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                      child: _CancelBtn(onTap: () => Navigator.pop(context))),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _ConfirmBtn(
                      label: _saving ? 'Saving…' : 'Save Result',
                      enabled: !_saving,
                      onTap: _save,
                      color: Colors.greenAccent,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════
//  SHARED WIDGETS
// ══════════════════════════════════════════════════════════
class _DialogTitle extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  const _DialogTitle({
    required this.icon,
    required this.label,
    this.color = Colors.redAccent,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(9),
          ),
          child: Icon(icon, color: color, size: 18),
        ),
        const SizedBox(width: 12),
        Text(label,
            style: const TextStyle(
                color: _textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w700)),
      ],
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);
  @override
  Widget build(BuildContext context) => Text(text,
      style: const TextStyle(
          color: _textSecondary,
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.5));
}

class _FormField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final IconData? icon;
  const _FormField({required this.controller, required this.hint, this.icon});

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      style: const TextStyle(color: _textPrimary, fontSize: 13),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: _textMuted, fontSize: 13),
        prefixIcon:
            icon != null ? Icon(icon, color: _textMuted, size: 16) : null,
        filled: true,
        fillColor: _surface2,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: _border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: _border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.redAccent.withOpacity(0.5)),
        ),
      ),
    );
  }
}

class _TeamPickBtn extends StatefulWidget {
  final String name, logo;
  final bool selected;
  final VoidCallback onTap;
  const _TeamPickBtn({
    required this.name,
    required this.logo,
    required this.selected,
    required this.onTap,
  });
  @override
  State<_TeamPickBtn> createState() => _TeamPickBtnState();
}

class _TeamPickBtnState extends State<_TeamPickBtn> {
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
          duration: const Duration(milliseconds: 110),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: widget.selected
                ? Colors.greenAccent.withOpacity(0.08)
                : _hovered
                    ? _surface2
                    : _surface3,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: widget.selected
                  ? Colors.greenAccent.withOpacity(0.4)
                  : _border,
            ),
          ),
          child: Row(
            children: [
              if (widget.logo.isNotEmpty)
                Container(
                  width: 24,
                  height: 24,
                  margin: const EdgeInsets.only(right: 8),
                  decoration: BoxDecoration(
                    color: _surface,
                    borderRadius: BorderRadius.circular(5),
                    border: Border.all(color: _border),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: Image.network(widget.logo,
                        fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) =>
                            _LogoFallback(name: widget.name)),
                  ),
                ),
              Expanded(
                child: Text(widget.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        color:
                            widget.selected ? Colors.greenAccent : _textPrimary,
                        fontSize: 12,
                        fontWeight: widget.selected
                            ? FontWeight.w700
                            : FontWeight.w500)),
              ),
              if (widget.selected)
                const Icon(Icons.check_circle_rounded,
                    color: Colors.greenAccent, size: 14),
            ],
          ),
        ),
      ),
    );
  }
}

class _DateTimePickerBtn extends StatefulWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _DateTimePickerBtn(
      {required this.icon, required this.label, required this.onTap});
  @override
  State<_DateTimePickerBtn> createState() => _DateTimePickerBtnState();
}

class _DateTimePickerBtnState extends State<_DateTimePickerBtn> {
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
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: _hovered ? _surface3 : _surface2,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: _hovered ? _border2 : _border),
          ),
          child: Row(
            children: [
              Icon(widget.icon, color: _textSecondary, size: 15),
              const SizedBox(width: 8),
              Expanded(
                child: Text(widget.label,
                    style: const TextStyle(
                        color: _textPrimary,
                        fontSize: 12,
                        fontWeight: FontWeight.w500)),
              ),
              const Icon(Icons.expand_more_rounded,
                  color: _textMuted, size: 14),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActionBtn extends StatefulWidget {
  final IconData icon;
  final String tooltip;
  final Color color;
  final VoidCallback onTap;
  const _ActionBtn({
    required this.icon,
    required this.tooltip,
    required this.color,
    required this.onTap,
  });
  @override
  State<_ActionBtn> createState() => _ActionBtnState();
}

class _ActionBtnState extends State<_ActionBtn> {
  bool _hovered = false;
  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: widget.tooltip,
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: _hovered ? widget.color.withOpacity(0.1) : _surface3,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: _hovered ? widget.color.withOpacity(0.35) : _border,
              ),
            ),
            child: Icon(widget.icon,
                color: _hovered ? widget.color : _textMuted, size: 15),
          ),
        ),
      ),
    );
  }
}

class _CancelBtn extends StatefulWidget {
  final VoidCallback onTap;
  const _CancelBtn({required this.onTap});
  @override
  State<_CancelBtn> createState() => _CancelBtnState();
}

class _CancelBtnState extends State<_CancelBtn> {
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
                    fontWeight: FontWeight.w500)),
          ),
        ),
      ),
    );
  }
}

class _ConfirmBtn extends StatefulWidget {
  final String label;
  final bool enabled;
  final VoidCallback onTap;
  final Color color;
  const _ConfirmBtn({
    required this.label,
    required this.enabled,
    required this.onTap,
    this.color = Colors.redAccent,
  });
  @override
  State<_ConfirmBtn> createState() => _ConfirmBtnState();
}

class _ConfirmBtnState extends State<_ConfirmBtn> {
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
                    ? widget.color.withOpacity(0.82)
                    : widget.color
                : _surface2,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Center(
            child: Text(widget.label,
                style: TextStyle(
                    color: widget.enabled ? Colors.white : _textMuted,
                    fontSize: 13,
                    fontWeight: FontWeight.w700)),
          ),
        ),
      ),
    );
  }
}

class _DeleteDialog extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: _surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: _border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _DialogTitle(
                icon: Icons.delete_rounded, label: 'Delete Fixture'),
            const SizedBox(height: 16),
            const Text(
              'This fixture will be permanently deleted. This cannot be undone.',
              style:
                  TextStyle(color: _textSecondary, fontSize: 13, height: 1.6),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                    child:
                        _CancelBtn(onTap: () => Navigator.pop(context, false))),
                const SizedBox(width: 12),
                Expanded(
                  child: _ConfirmBtn(
                    label: 'Delete',
                    enabled: true,
                    onTap: () => Navigator.pop(context, true),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _LogoFallback extends StatelessWidget {
  final String name;
  const _LogoFallback({required this.name});
  @override
  Widget build(BuildContext context) {
    final initials = name.length >= 2 ? name.substring(0, 2) : name;
    return Container(
      color: Colors.redAccent.withOpacity(0.08),
      child: Center(
        child: Text(initials,
            style: const TextStyle(
                color: Colors.redAccent,
                fontSize: 8,
                fontWeight: FontWeight.w800)),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: _surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: _border),
            ),
            child: const Icon(Icons.calendar_month_rounded,
                color: _textMuted, size: 32),
          ),
          const SizedBox(height: 20),
          const Text('No fixtures yet',
              style: TextStyle(
                  color: _textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          const Text(
            'Click "Add Fixture" to schedule your first match.',
            style: TextStyle(color: _textSecondary, fontSize: 13, height: 1.6),
          ),
        ],
      ),
    );
  }
}
