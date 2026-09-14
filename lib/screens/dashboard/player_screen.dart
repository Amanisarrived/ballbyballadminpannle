import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cricket_admin/services/featured_match_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

const _bg = Color(0xFF0D0D0D);
const _surface = Color(0xFF141414);
const _surface2 = Color(0xFF1A1A1A);
const _border = Color(0xFF232323);
const _textPrimary = Color(0xFFE8E8E8);
const _textSecondary = Color(0xFF666666);
const _textMuted = Color(0xFF444444);
const _roles = ['batsman', 'bowler', 'allrounder', 'wicketkeeper'];

Color _roleColor(String role) {
  switch (role) {
    case 'batsman':
      return const Color(0xFF4FC3F7);
    case 'bowler':
      return const Color(0xFFFF8A65);
    case 'allrounder':
      return const Color(0xFF81C784);
    case 'wicketkeeper':
      return const Color(0xFFFFD54F);
    default:
      return const Color(0xFF666666);
  }
}

IconData _roleIcon(String role) {
  switch (role) {
    case 'batsman':
      return Icons.sports_cricket_rounded;
    case 'bowler':
      return Icons.trip_origin_rounded;
    case 'allrounder':
      return Icons.swap_horiz_rounded;
    case 'wicketkeeper':
      return Icons.back_hand_rounded;
    default:
      return Icons.person_rounded;
  }
}

String _roleLabel(String role) {
  switch (role) {
    case 'wicketkeeper':
      return 'W. Keeper';
    case 'allrounder':
      return 'All-rounder';
    default:
      return role[0].toUpperCase() + role.substring(1);
  }
}

bool _hasBatting(String role) =>
    role == 'batsman' || role == 'allrounder' || role == 'wicketkeeper';
bool _hasBowling(String role) => role == 'bowler' || role == 'allrounder';

// ─────────────────────────────────────────────────────────────
//  PlayerScreen
// ─────────────────────────────────────────────────────────────
class PlayerScreen extends StatefulWidget {
  const PlayerScreen({super.key});
  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> {
  bool _showAddForm = false;
  String? _filterTeamId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: CustomScrollView(
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(28, 28, 28, 0),
            sliver: SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Header ──────────────────────────────
                  Row(
                    children: [
                      const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Players',
                              style: TextStyle(
                                  color: _textPrimary,
                                  fontSize: 22,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: -0.4)),
                          SizedBox(height: 3),
                          Text('Add players and assign them to teams',
                              style: TextStyle(
                                  color: _textSecondary, fontSize: 13)),
                        ],
                      ),
                      const Spacer(),
                      _AddPlayerButton(
                        isOpen: _showAddForm,
                        onTap: () =>
                            setState(() => _showAddForm = !_showAddForm),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // ── Add form ─────────────────────────────
                  AnimatedSize(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeOut,
                    child: _showAddForm
                        ? _AddPlayerForm(
                            onSaved: () => setState(() => _showAddForm = false),
                            onCancel: () =>
                                setState(() => _showAddForm = false),
                          )
                        : const SizedBox.shrink(),
                  ),

                  // ── Filter bar ───────────────────────────
                  _TeamFilterBar(
                    selectedTeamId: _filterTeamId,
                    onChanged: (id) => setState(() => _filterTeamId = id),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),

          // ── Player list as sliver ────────────────────────
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(28, 0, 28, 28),
            sliver: _PlayerListSliver(filterTeamId: _filterTeamId),
          ),
        ],
      ),
    );
  }
}

// ── Add player button ──────────────────────────────────────
class _AddPlayerButton extends StatefulWidget {
  final bool isOpen;
  final VoidCallback onTap;
  const _AddPlayerButton({required this.isOpen, required this.onTap});
  @override
  State<_AddPlayerButton> createState() => _AddPlayerButtonState();
}

class _AddPlayerButtonState extends State<_AddPlayerButton> {
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
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: widget.isOpen
                ? _surface2
                : _hovered
                    ? Colors.redAccent.shade700
                    : Colors.redAccent,
            borderRadius: BorderRadius.circular(10),
            border: widget.isOpen
                ? Border.all(color: _border)
                : Border.all(color: Colors.transparent),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedRotation(
                duration: const Duration(milliseconds: 200),
                turns: widget.isOpen ? 0.125 : 0,
                child: Icon(Icons.add_rounded,
                    color: widget.isOpen ? _textSecondary : Colors.white,
                    size: 18),
              ),
              const SizedBox(width: 7),
              Text(
                widget.isOpen ? 'Cancel' : 'Add Player',
                style: TextStyle(
                    color: widget.isOpen ? _textSecondary : Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Team filter bar ────────────────────────────────────────
class _TeamFilterBar extends StatelessWidget {
  final String? selectedTeamId;
  final ValueChanged<String?> onChanged;
  const _TeamFilterBar({required this.selectedTeamId, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('teams').snapshots(),
      builder: (context, snap) {
        final teams = snap.data?.docs ?? [];
        return SizedBox(
          height: 36,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              _FilterChip(
                label: 'All Players',
                selected: selectedTeamId == null,
                onTap: () => onChanged(null),
              ),
              const SizedBox(width: 8),
              ...teams.map((doc) {
                final data = doc.data() as Map<String, dynamic>;
                final teamId = data['teamId'] ?? doc.id;
                final name = data['name'] ?? teamId;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: _FilterChip(
                    label: name,
                    teamId: teamId,
                    selected: selectedTeamId == teamId,
                    onTap: () => onChanged(teamId),
                  ),
                );
              }),
            ],
          ),
        );
      },
    );
  }
}

class _FilterChip extends StatefulWidget {
  final String label;
  final String? teamId;
  final bool selected;
  final VoidCallback onTap;
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.teamId,
  });
  @override
  State<_FilterChip> createState() => _FilterChipState();
}

class _FilterChipState extends State<_FilterChip> {
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
          duration: const Duration(milliseconds: 150),
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
                  ? Colors.redAccent.withOpacity(0.35)
                  : _border,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.teamId != null) ...[
                Text(widget.teamId!,
                    style: TextStyle(
                        color: widget.selected ? Colors.redAccent : _textMuted,
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5)),
                const SizedBox(width: 6),
              ],
              Text(widget.label,
                  style: TextStyle(
                      color: widget.selected
                          ? Colors.redAccent
                          : _hovered
                              ? _textPrimary
                              : _textSecondary,
                      fontSize: 12,
                      fontWeight:
                          widget.selected ? FontWeight.w600 : FontWeight.w400)),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  Add Player Form
// ─────────────────────────────────────────────────────────────
class _AddPlayerForm extends StatefulWidget {
  final VoidCallback onSaved, onCancel;
  const _AddPlayerForm({required this.onSaved, required this.onCancel});
  @override
  State<_AddPlayerForm> createState() => _AddPlayerFormState();
}

class _AddPlayerFormState extends State<_AddPlayerForm> {
  final _nameCtrl = TextEditingController();
  String? _selectedTeamId;
  String? _selectedTeamDocId;
  String _role = 'batsman';

  final _battingAvgCtrl = TextEditingController();
  final _strikeRateCtrl = TextEditingController();
  final _recentFormCtrl = TextEditingController();
  final _venueAvgCtrl = TextEditingController();
  final _bowlingAvgCtrl = TextEditingController();
  final _economyCtrl = TextEditingController();
  final _recentWktsCtrl = TextEditingController();

  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    for (final c in [
      _nameCtrl,
      _battingAvgCtrl,
      _strikeRateCtrl,
      _recentFormCtrl,
      _venueAvgCtrl,
      _bowlingAvgCtrl,
      _economyCtrl,
      _recentWktsCtrl,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  List<int> _parseList(String raw) => raw
      .split(',')
      .map((s) => int.tryParse(s.trim()) ?? 0)
      .where((v) => v >= 0)
      .toList();

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Player name is required.');
      return;
    }
    if (_selectedTeamId == null || _selectedTeamDocId == null) {
      setState(() => _error = 'Please select a team.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      final playerId =
          '${_selectedTeamId!.toLowerCase()}_${DateTime.now().millisecondsSinceEpoch}';

      final playerData = FeaturedMatchService.buildPlayerWithStats(
        id: playerId,
        name: name,
        role: _role,
        battingAvg: _hasBatting(_role) && _battingAvgCtrl.text.isNotEmpty
            ? double.tryParse(_battingAvgCtrl.text.trim())
            : null,
        strikeRate: _hasBatting(_role) && _strikeRateCtrl.text.isNotEmpty
            ? double.tryParse(_strikeRateCtrl.text.trim())
            : null,
        recentForm: _hasBatting(_role) && _recentFormCtrl.text.isNotEmpty
            ? _parseList(_recentFormCtrl.text)
            : null,
        venueAvg: _venueAvgCtrl.text.isNotEmpty
            ? double.tryParse(_venueAvgCtrl.text.trim())
            : null,
        bowlingAvg: _hasBowling(_role) && _bowlingAvgCtrl.text.isNotEmpty
            ? double.tryParse(_bowlingAvgCtrl.text.trim())
            : null,
        economy: _hasBowling(_role) && _economyCtrl.text.isNotEmpty
            ? double.tryParse(_economyCtrl.text.trim())
            : null,
        recentWickets: _hasBowling(_role) && _recentWktsCtrl.text.isNotEmpty
            ? _parseList(_recentWktsCtrl.text)
            : null,
      );

      final fullPlayerData = {...playerData, 'teamId': _selectedTeamId};

      await FirebaseFirestore.instance
          .collection('teams')
          .doc(_selectedTeamDocId)
          .update({
        'players': FieldValue.arrayUnion([fullPlayerData])
      });

      final teamSnap = await FirebaseFirestore.instance
          .collection('teams')
          .doc(_selectedTeamDocId)
          .get();
      final allPlayers = List<dynamic>.from(teamSnap.data()?['players'] ?? []);

      final cleanPlayers = allPlayers.map((p) {
        final pm = Map<String, dynamic>.from(p as Map);
        return FeaturedMatchService.buildPlayerWithStats(
          id: pm['id'] ?? '',
          name: pm['name'] ?? '',
          role: pm['role'] ?? '',
          battingAvg: (pm['batting_avg'] as num?)?.toDouble(),
          strikeRate: (pm['strike_rate'] as num?)?.toDouble(),
          recentForm: pm['recent_form'] != null
              ? List<int>.from(pm['recent_form'])
              : null,
          venueAvg: (pm['venue_avg'] as num?)?.toDouble(),
          bowlingAvg: (pm['bowling_avg'] as num?)?.toDouble(),
          economy: (pm['economy'] as num?)?.toDouble(),
          recentWickets: pm['recent_wickets'] != null
              ? List<int>.from(pm['recent_wickets'])
              : null,
        );
      }).toList();

      final featuredRef = FirebaseFirestore.instance
          .collection('featured_match')
          .doc('admin_current');
      final featuredSnap = await featuredRef.get();
      if (featuredSnap.exists) {
        final teams =
            Map<String, dynamic>.from(featuredSnap.data()!['teams'] ?? {});
        String? matchedKey;
        if ((teams['teamA'] as Map<String, dynamic>?)?['teamId'] ==
            _selectedTeamId)
          matchedKey = 'teamA';
        else if ((teams['teamB'] as Map<String, dynamic>?)?['teamId'] ==
            _selectedTeamId) matchedKey = 'teamB';
        if (matchedKey != null) {
          final slot = Map<String, dynamic>.from(teams[matchedKey] as Map);
          slot['players'] = cleanPlayers;
          teams[matchedKey] = slot;
          await featuredRef.set({'teams': teams}, SetOptions(merge: true));
        }
      }
      widget.onSaved();
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color:
                _error != null ? Colors.redAccent.withOpacity(0.4) : _border),
      ),
      // ── FIX: SingleChildScrollView prevents allrounder overflow ──
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.person_add_rounded,
                    color: Colors.redAccent, size: 16),
                SizedBox(width: 8),
                Text('New Player',
                    style: TextStyle(
                        color: _textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w700)),
              ],
            ),
            const SizedBox(height: 20),

            // ── Name + Team + Role ─────────────────────────
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 3,
                  child: _FormField(
                    label: 'Player Name',
                    hint: 'e.g. Virat Kohli',
                    controller: _nameCtrl,
                    icon: Icons.person_rounded,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  flex: 2,
                  child: _TeamDropdown(
                    selectedDocId: _selectedTeamDocId,
                    onChanged: (docId, teamId) => setState(() {
                      _selectedTeamDocId = docId;
                      _selectedTeamId = teamId;
                    }),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  flex: 3,
                  child: _RoleSelector(
                    selected: _role,
                    onChanged: (r) => setState(() => _role = r),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),

            // ── Stats header ───────────────────────────────
            Row(
              children: [
                Container(
                  width: 3,
                  height: 14,
                  decoration: BoxDecoration(
                    color: Colors.redAccent,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 8),
                const Text('Career Stats',
                    style: TextStyle(
                        color: _textPrimary,
                        fontSize: 13,
                        fontWeight: FontWeight.w700)),
                const SizedBox(width: 8),
                const Text('(for AI prediction)',
                    style: TextStyle(color: _textMuted, fontSize: 11)),
              ],
            ),
            const SizedBox(height: 14),

            // ── Batting stats ──────────────────────────────
            if (_hasBatting(_role)) ...[
              _StatsRowLabel(label: 'Batting', color: const Color(0xFF4FC3F7)),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _StatsField(
                      label: 'Batting Avg',
                      hint: 'e.g. 52.3',
                      controller: _battingAvgCtrl,
                      isDecimal: true,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _StatsField(
                      label: 'Strike Rate',
                      hint: 'e.g. 138.4',
                      controller: _strikeRateCtrl,
                      isDecimal: true,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _StatsField(
                      label: 'Recent Form',
                      hint: '45, 0, 82, 23, 67',
                      controller: _recentFormCtrl,
                      isDecimal: false,
                      tooltip: 'Last 5 scores, comma separated',
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _StatsField(
                      label: 'Venue Avg',
                      hint: 'e.g. 61.0',
                      controller: _venueAvgCtrl,
                      isDecimal: true,
                      tooltip: 'Average at this venue (optional)',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
            ],

            // ── Bowling stats ──────────────────────────────
            if (_hasBowling(_role)) ...[
              _StatsRowLabel(label: 'Bowling', color: const Color(0xFFFF8A65)),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _StatsField(
                      label: 'Bowling Avg',
                      hint: 'e.g. 20.1',
                      controller: _bowlingAvgCtrl,
                      isDecimal: true,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _StatsField(
                      label: 'Economy',
                      hint: 'e.g. 6.2',
                      controller: _economyCtrl,
                      isDecimal: true,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _StatsField(
                      label: 'Recent Wickets',
                      hint: '2, 1, 3, 0, 2',
                      controller: _recentWktsCtrl,
                      isDecimal: false,
                      tooltip: 'Last 5 matches, comma separated',
                    ),
                  ),
                  const Expanded(child: SizedBox()),
                ],
              ),
              const SizedBox(height: 16),
            ],

            // ── Venue avg for bowler only ──────────────────
            if (_role == 'bowler') ...[
              Row(
                children: [
                  SizedBox(
                    width: 200,
                    child: _StatsField(
                      label: 'Venue Avg',
                      hint: 'e.g. 22.5',
                      controller: _venueAvgCtrl,
                      isDecimal: true,
                      tooltip: 'Bowling avg at this venue (optional)',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
            ],

            if (_error != null) ...[
              _ErrorBanner(message: _error!),
              const SizedBox(height: 14),
            ],

            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                _GhostButton(label: 'Cancel', onTap: widget.onCancel),
                const SizedBox(width: 12),
                _SaveButton(label: 'Add Player', saving: _saving, onTap: _save),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── Stats row label ────────────────────────────────────────
class _StatsRowLabel extends StatelessWidget {
  final String label;
  final Color color;
  const _StatsRowLabel({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(Icons.bar_chart_rounded, color: color, size: 13),
        const SizedBox(width: 6),
        Text(label,
            style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.3)),
      ],
    );
  }
}

// ── Stats field ────────────────────────────────────────────
class _StatsField extends StatefulWidget {
  final String label, hint;
  final TextEditingController controller;
  final bool isDecimal;
  final String? tooltip;
  const _StatsField({
    required this.label,
    required this.hint,
    required this.controller,
    required this.isDecimal,
    this.tooltip,
  });
  @override
  State<_StatsField> createState() => _StatsFieldState();
}

class _StatsFieldState extends State<_StatsField> {
  final _focus = FocusNode();
  bool _focused = false;

  @override
  void initState() {
    super.initState();
    _focus.addListener(() => setState(() => _focused = _focus.hasFocus));
  }

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(widget.label,
                style: const TextStyle(
                    color: _textSecondary,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.3)),
            if (widget.tooltip != null) ...[
              const SizedBox(width: 4),
              Tooltip(
                message: widget.tooltip!,
                child: const Icon(Icons.info_outline_rounded,
                    size: 11, color: _textMuted),
              ),
            ],
          ],
        ),
        const SizedBox(height: 7),
        AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          decoration: BoxDecoration(
            color: _focused ? _surface2 : _surface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: _focused ? Colors.redAccent.withOpacity(0.4) : _border,
              width: 1.5,
            ),
          ),
          child: TextField(
            controller: widget.controller,
            focusNode: _focus,
            keyboardType: widget.isDecimal
                ? const TextInputType.numberWithOptions(decimal: true)
                : TextInputType.text,
            inputFormatters: widget.isDecimal
                ? [FilteringTextInputFormatter.allow(RegExp(r'[\d.]'))]
                : [],
            style: const TextStyle(color: _textPrimary, fontSize: 13),
            decoration: InputDecoration(
              hintText: widget.hint,
              hintStyle: const TextStyle(color: _textMuted, fontSize: 12),
              border: InputBorder.none,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
            ),
          ),
        ),
      ],
    );
  }
}

// ── Player list as sliver ──────────────────────────────────
class _PlayerListSliver extends StatelessWidget {
  final String? filterTeamId;
  const _PlayerListSliver({required this.filterTeamId});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('teams').snapshots(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const SliverToBoxAdapter(
            child: Center(
              child: Padding(
                padding: EdgeInsets.all(40),
                child: CircularProgressIndicator(
                    color: Colors.redAccent, strokeWidth: 2),
              ),
            ),
          );
        }

        final teams = snap.data?.docs ?? [];
        final allPlayers = <Map<String, dynamic>>[];

        for (final teamDoc in teams) {
          final data = teamDoc.data() as Map<String, dynamic>;
          final teamId = data['teamId'] ?? teamDoc.id;
          final teamName = data['name'] ?? teamId;
          final teamLogo = data['logo'] ?? '';
          final players = (data['players'] as List<dynamic>?) ?? [];
          for (final p in players) {
            final player = Map<String, dynamic>.from(p as Map);
            player['_teamDocId'] = teamDoc.id;
            player['_teamName'] = teamName;
            player['_teamLogo'] = teamLogo;
            player['_teamId'] = teamId;
            allPlayers.add(player);
          }
        }

        final filtered = filterTeamId == null
            ? allPlayers
            : allPlayers.where((p) => p['_teamId'] == filterTeamId).toList();

        if (filtered.isEmpty) {
          return SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.only(top: 60),
              child: _EmptyState(isFiltered: filterTeamId != null),
            ),
          );
        }

        final grouped = <String, List<Map<String, dynamic>>>{};
        for (final p in filtered) {
          grouped.putIfAbsent(p['_teamId'] as String, () => []).add(p);
        }

        // Build flat list of items
        final items = <Widget>[];
        for (final entry in grouped.entries) {
          final teamPlayers = entry.value;
          final teamName = teamPlayers.first['_teamName'] as String;
          final teamLogo = teamPlayers.first['_teamLogo'] as String;
          final teamDocId = teamPlayers.first['_teamDocId'] as String;

          items.add(_TeamGroupHeader(
            teamId: entry.key,
            teamName: teamName,
            teamLogo: teamLogo,
            count: teamPlayers.length,
          ));
          items.add(const SizedBox(height: 8));

          for (final p in teamPlayers) {
            items.add(_PlayerCard(player: p, teamDocId: teamDocId));
            items.add(const SizedBox(height: 8));
          }
          items.add(const SizedBox(height: 8));
        }

        return SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, index) => items[index],
            childCount: items.length,
          ),
        );
      },
    );
  }
}

// ── Player list ────────────────────────────────────────────
class _PlayerList extends StatelessWidget {
  final String? filterTeamId;
  const _PlayerList({required this.filterTeamId});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('teams').snapshots(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(
              child: CircularProgressIndicator(
                  color: Colors.redAccent, strokeWidth: 2));
        }

        final teams = snap.data?.docs ?? [];
        final allPlayers = <Map<String, dynamic>>[];

        for (final teamDoc in teams) {
          final data = teamDoc.data() as Map<String, dynamic>;
          final teamId = data['teamId'] ?? teamDoc.id;
          final teamName = data['name'] ?? teamId;
          final teamLogo = data['logo'] ?? '';
          final players = (data['players'] as List<dynamic>?) ?? [];

          for (final p in players) {
            final player = Map<String, dynamic>.from(p as Map);
            player['_teamDocId'] = teamDoc.id;
            player['_teamName'] = teamName;
            player['_teamLogo'] = teamLogo;
            player['_teamId'] = teamId;
            allPlayers.add(player);
          }
        }

        final filtered = filterTeamId == null
            ? allPlayers
            : allPlayers.where((p) => p['_teamId'] == filterTeamId).toList();

        if (filtered.isEmpty) {
          return _EmptyState(isFiltered: filterTeamId != null);
        }

        final grouped = <String, List<Map<String, dynamic>>>{};
        for (final p in filtered) {
          grouped.putIfAbsent(p['_teamId'] as String, () => []).add(p);
        }

        return ListView(
          children: grouped.entries.map((entry) {
            final teamPlayers = entry.value;
            final teamName = teamPlayers.first['_teamName'] as String;
            final teamLogo = teamPlayers.first['_teamLogo'] as String;
            final teamDocId = teamPlayers.first['_teamDocId'] as String;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _TeamGroupHeader(
                    teamId: entry.key,
                    teamName: teamName,
                    teamLogo: teamLogo,
                    count: teamPlayers.length),
                const SizedBox(height: 8),
                ...teamPlayers.map((p) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _PlayerCard(player: p, teamDocId: teamDocId),
                    )),
                const SizedBox(height: 16),
              ],
            );
          }).toList(),
        );
      },
    );
  }
}

// ── Team group header ──────────────────────────────────────
class _TeamGroupHeader extends StatelessWidget {
  final String teamId, teamName, teamLogo;
  final int count;
  const _TeamGroupHeader({
    required this.teamId,
    required this.teamName,
    required this.teamLogo,
    required this.count,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 26,
          height: 26,
          decoration: BoxDecoration(
            color: Colors.redAccent.withOpacity(0.08),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: Colors.redAccent.withOpacity(0.2)),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(5),
            child: teamLogo.isNotEmpty
                ? Image.network(teamLogo,
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => _MiniTeamId(teamId: teamId))
                : _MiniTeamId(teamId: teamId),
          ),
        ),
        const SizedBox(width: 10),
        Text(teamName,
            style: const TextStyle(
                color: _textPrimary,
                fontSize: 13,
                fontWeight: FontWeight.w700)),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
          decoration: BoxDecoration(
            color: _surface2,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: _border),
          ),
          child: Text('$count',
              style: const TextStyle(
                  color: _textSecondary,
                  fontSize: 10,
                  fontWeight: FontWeight.w600)),
        ),
        const SizedBox(width: 12),
        Expanded(child: Divider(color: _border, height: 1)),
      ],
    );
  }
}

// ── Player card ────────────────────────────────────────────
class _PlayerCard extends StatefulWidget {
  final Map<String, dynamic> player;
  final String teamDocId;
  const _PlayerCard({required this.player, required this.teamDocId});
  @override
  State<_PlayerCard> createState() => _PlayerCardState();
}

class _PlayerCardState extends State<_PlayerCard> {
  bool _hovered = false;
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final name = widget.player['name'] as String? ?? '—';
    final role = widget.player['role'] as String? ?? 'batsman';
    final id = widget.player['id'] as String? ?? '—';
    final color = _roleColor(role);

    final battingAvg = widget.player['batting_avg'];
    final strikeRate = widget.player['strike_rate'];
    final recentForm = widget.player['recent_form'];
    final venueAvg = widget.player['venue_avg'];
    final bowlingAvg = widget.player['bowling_avg'];
    final economy = widget.player['economy'];
    final recentWickets = widget.player['recent_wickets'];

    final hasStats = battingAvg != null ||
        strikeRate != null ||
        bowlingAvg != null ||
        economy != null;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        decoration: BoxDecoration(
          color: _hovered ? _surface2 : _surface,
          borderRadius: BorderRadius.circular(10),
          border:
              Border.all(color: _hovered ? const Color(0xFF2E2E2E) : _border),
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
              child: Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.08),
                      shape: BoxShape.circle,
                      border: Border.all(color: color.withOpacity(0.2)),
                    ),
                    child: Icon(_roleIcon(role), color: color, size: 16),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(name,
                            style: const TextStyle(
                                color: _textPrimary,
                                fontSize: 14,
                                fontWeight: FontWeight.w600)),
                        const SizedBox(height: 3),
                        Text(id,
                            style: const TextStyle(
                                color: _textMuted,
                                fontSize: 11,
                                fontFamily: 'monospace')),
                      ],
                    ),
                  ),
                  if (battingAvg != null)
                    _QuickStat(label: 'Avg', value: '$battingAvg'),
                  if (strikeRate != null && battingAvg == null)
                    _QuickStat(label: 'SR', value: '$strikeRate'),
                  if (economy != null && battingAvg == null)
                    _QuickStat(label: 'Eco', value: '$economy'),
                  const SizedBox(width: 8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: color.withOpacity(0.2)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(_roleIcon(role), color: color, size: 11),
                        const SizedBox(width: 5),
                        Text(_roleLabel(role),
                            style: TextStyle(
                                color: color,
                                fontSize: 11,
                                fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (hasStats)
                    MouseRegion(
                      cursor: SystemMouseCursors.click,
                      child: GestureDetector(
                        onTap: () => setState(() => _expanded = !_expanded),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            color: _expanded
                                ? Colors.redAccent.withOpacity(0.1)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(7),
                          ),
                          child: Icon(
                            _expanded
                                ? Icons.keyboard_arrow_up_rounded
                                : Icons.keyboard_arrow_down_rounded,
                            color: _expanded ? Colors.redAccent : _textMuted,
                            size: 16,
                          ),
                        ),
                      ),
                    ),
                  const SizedBox(width: 4),
                  _DeletePlayerButton(
                    playerData: widget.player,
                    teamDocId: widget.teamDocId,
                    playerName: name,
                  ),
                ],
              ),
            ),
            if (_expanded && hasStats)
              Container(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: _bg,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: _border),
                  ),
                  child: Wrap(
                    spacing: 24,
                    runSpacing: 10,
                    children: [
                      if (battingAvg != null)
                        _StatItem(
                            label: 'Batting Avg',
                            value: '$battingAvg',
                            color: const Color(0xFF4FC3F7)),
                      if (strikeRate != null)
                        _StatItem(
                            label: 'Strike Rate',
                            value: '$strikeRate',
                            color: const Color(0xFF4FC3F7)),
                      if (venueAvg != null)
                        _StatItem(
                            label: 'Venue Avg',
                            value: '$venueAvg',
                            color: const Color(0xFF4FC3F7)),
                      if (recentForm != null)
                        _StatItem(
                            label: 'Recent Form',
                            value: (recentForm as List).join(', '),
                            color: const Color(0xFF4FC3F7)),
                      if (bowlingAvg != null)
                        _StatItem(
                            label: 'Bowling Avg',
                            value: '$bowlingAvg',
                            color: const Color(0xFFFF8A65)),
                      if (economy != null)
                        _StatItem(
                            label: 'Economy',
                            value: '$economy',
                            color: const Color(0xFFFF8A65)),
                      if (recentWickets != null)
                        _StatItem(
                            label: 'Recent Wkts',
                            value: (recentWickets as List).join(', '),
                            color: const Color(0xFFFF8A65)),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _QuickStat extends StatelessWidget {
  final String label, value;
  const _QuickStat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: _surface2,
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: _border),
      ),
      child: Column(
        children: [
          Text(value,
              style: const TextStyle(
                  color: _textPrimary,
                  fontSize: 11,
                  fontWeight: FontWeight.w700)),
          Text(label, style: const TextStyle(color: _textMuted, fontSize: 9)),
        ],
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final String label, value;
  final Color color;
  const _StatItem(
      {required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: _textMuted, fontSize: 10)),
        const SizedBox(height: 2),
        Text(value,
            style: TextStyle(
                color: color, fontSize: 13, fontWeight: FontWeight.w600)),
      ],
    );
  }
}

// ── Delete player button ───────────────────────────────────
class _DeletePlayerButton extends StatefulWidget {
  final Map<String, dynamic> playerData;
  final String teamDocId, playerName;
  const _DeletePlayerButton({
    required this.playerData,
    required this.teamDocId,
    required this.playerName,
  });
  @override
  State<_DeletePlayerButton> createState() => _DeletePlayerButtonState();
}

class _DeletePlayerButtonState extends State<_DeletePlayerButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () => _confirmDelete(context),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: _hovered
                ? Colors.redAccent.withOpacity(0.1)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(Icons.delete_outline_rounded,
              color: _hovered ? Colors.redAccent : _textMuted, size: 16),
        ),
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => _DeleteDialog(name: widget.playerName),
    );
    if (confirm != true) return;

    final teamRef =
        FirebaseFirestore.instance.collection('teams').doc(widget.teamDocId);
    final teamSnap = await teamRef.get();
    if (teamSnap.data() == null) return;

    final players = List<dynamic>.from(teamSnap.data()!['players'] ?? []);
    players.removeWhere((p) => p['id'] == widget.playerData['id']);
    await teamRef.update({'players': players});

    final teamId = widget.playerData['teamId'] as String?;
    if (teamId == null) return;

    final cleanPlayers = players.map((p) {
      final pm = Map<String, dynamic>.from(p as Map);
      return FeaturedMatchService.buildPlayerWithStats(
        id: pm['id'] ?? '',
        name: pm['name'] ?? '',
        role: pm['role'] ?? '',
        battingAvg: (pm['batting_avg'] as num?)?.toDouble(),
        strikeRate: (pm['strike_rate'] as num?)?.toDouble(),
        recentForm: pm['recent_form'] != null
            ? List<int>.from(pm['recent_form'])
            : null,
        venueAvg: (pm['venue_avg'] as num?)?.toDouble(),
        bowlingAvg: (pm['bowling_avg'] as num?)?.toDouble(),
        economy: (pm['economy'] as num?)?.toDouble(),
        recentWickets: pm['recent_wickets'] != null
            ? List<int>.from(pm['recent_wickets'])
            : null,
      );
    }).toList();

    final featuredRef = FirebaseFirestore.instance
        .collection('featured_match')
        .doc('admin_current');
    final featuredSnap = await featuredRef.get();
    if (!featuredSnap.exists) return;

    final teams =
        Map<String, dynamic>.from(featuredSnap.data()!['teams'] ?? {});
    String? matchedKey;
    if ((teams['teamA'] as Map<String, dynamic>?)?['teamId'] == teamId)
      matchedKey = 'teamA';
    else if ((teams['teamB'] as Map<String, dynamic>?)?['teamId'] == teamId)
      matchedKey = 'teamB';

    if (matchedKey != null) {
      final slot =
          Map<String, dynamic>.from(teams[matchedKey] as Map<String, dynamic>);
      slot['players'] = cleanPlayers;
      teams[matchedKey] = slot;
      await featuredRef.set({'teams': teams}, SetOptions(merge: true));
    }
  }
}

// ── Delete dialog ──────────────────────────────────────────
class _DeleteDialog extends StatelessWidget {
  final String name;
  const _DeleteDialog({required this.name});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF141414),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: _border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.redAccent.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.person_remove_rounded,
                  color: Colors.redAccent, size: 20),
            ),
            const SizedBox(height: 16),
            const Text('Remove player?',
                style: TextStyle(
                    color: _textPrimary,
                    fontSize: 17,
                    fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            Text('"$name" will be removed from the team.',
                style: const TextStyle(
                    color: _textSecondary, fontSize: 13, height: 1.5)),
            const SizedBox(height: 4),
            const Text(
                'If their team is in a featured match, the roster will update.',
                style: TextStyle(color: _textMuted, fontSize: 12, height: 1.5)),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context, false),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _textSecondary,
                      side: const BorderSide(color: _border),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(vertical: 13),
                    ),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context, true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.redAccent,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(vertical: 13),
                    ),
                    child: const Text('Remove',
                        style: TextStyle(fontWeight: FontWeight.w600)),
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

// ── Empty state ────────────────────────────────────────────
class _EmptyState extends StatelessWidget {
  final bool isFiltered;
  const _EmptyState({required this.isFiltered});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final tight = constraints.maxHeight < 120;
        return Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                if (!tight) ...[
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: _surface,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: _border),
                    ),
                    child: const Icon(Icons.person_off_rounded,
                        color: _textMuted, size: 18),
                  ),
                  const SizedBox(height: 8),
                ],
                Text(
                  isFiltered ? 'No players in this team' : 'No players yet',
                  style: const TextStyle(
                      color: _textPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w600),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 3),
                Text(
                  isFiltered
                      ? 'Add players above.'
                      : 'Click "Add Player" to start.',
                  style: const TextStyle(color: _textSecondary, fontSize: 11),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ── Shared widgets ─────────────────────────────────────────
class _TeamDropdown extends StatelessWidget {
  final String? selectedDocId;
  final void Function(String docId, String teamId) onChanged;
  const _TeamDropdown({required this.selectedDocId, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Team',
            style: TextStyle(
                color: _textSecondary,
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.3)),
        const SizedBox(height: 7),
        StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance.collection('teams').snapshots(),
          builder: (context, snap) {
            final teams = snap.data?.docs ?? [];
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: _surface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: _border, width: 1.5),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: selectedDocId,
                  isExpanded: true,
                  hint: const Text('Select team',
                      style: TextStyle(color: _textMuted, fontSize: 13)),
                  dropdownColor: const Color(0xFF1E1E1E),
                  icon: const Icon(Icons.keyboard_arrow_down_rounded,
                      color: _textMuted, size: 18),
                  items: teams.map((doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    final teamId = data['teamId'] ?? doc.id;
                    final name = data['name'] ?? teamId;
                    final logo = data['logo'] ?? '';
                    return DropdownMenuItem<String>(
                      value: doc.id,
                      child: Row(
                        children: [
                          Container(
                            width: 24,
                            height: 24,
                            decoration: BoxDecoration(
                              color: Colors.redAccent.withOpacity(0.08),
                              borderRadius: BorderRadius.circular(5),
                              border: Border.all(
                                  color: Colors.redAccent.withOpacity(0.2)),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: logo.isNotEmpty
                                  ? Image.network(logo,
                                      fit: BoxFit.contain,
                                      errorBuilder: (_, __, ___) =>
                                          _MiniTeamId(teamId: teamId))
                                  : _MiniTeamId(teamId: teamId),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Text(name,
                              style: const TextStyle(
                                  color: _textPrimary, fontSize: 13)),
                          const SizedBox(width: 6),
                          Text(teamId,
                              style: const TextStyle(
                                  color: _textMuted,
                                  fontSize: 10,
                                  letterSpacing: 0.5)),
                        ],
                      ),
                    );
                  }).toList(),
                  onChanged: (docId) {
                    if (docId == null) return;
                    final doc = teams.firstWhere((d) => d.id == docId);
                    final data = doc.data() as Map<String, dynamic>;
                    onChanged(docId, data['teamId'] ?? docId);
                  },
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}

class _MiniTeamId extends StatelessWidget {
  final String teamId;
  const _MiniTeamId({required this.teamId});

  @override
  Widget build(BuildContext context) => Center(
        child: Text(
          teamId.length > 2 ? teamId.substring(0, 2) : teamId,
          style: const TextStyle(
              color: Colors.redAccent,
              fontSize: 7,
              fontWeight: FontWeight.w800),
        ),
      );
}

class _RoleSelector extends StatelessWidget {
  final String selected;
  final ValueChanged<String> onChanged;
  const _RoleSelector({required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Role',
            style: TextStyle(
                color: _textSecondary,
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.3)),
        const SizedBox(height: 7),
        Row(
          children: _roles.map((role) {
            final isSelected = selected == role;
            final color = _roleColor(role);
            return Expanded(
              child: Padding(
                padding: EdgeInsets.only(right: role == _roles.last ? 0 : 6),
                child: _RoleChip(
                  role: role,
                  color: color,
                  isSelected: isSelected,
                  onTap: () => onChanged(role),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}

class _RoleChip extends StatefulWidget {
  final String role;
  final Color color;
  final bool isSelected;
  final VoidCallback onTap;
  const _RoleChip({
    required this.role,
    required this.color,
    required this.isSelected,
    required this.onTap,
  });
  @override
  State<_RoleChip> createState() => _RoleChipState();
}

class _RoleChipState extends State<_RoleChip> {
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
          duration: const Duration(milliseconds: 140),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: widget.isSelected
                ? widget.color.withOpacity(0.12)
                : _hovered
                    ? _surface2
                    : _surface,
            borderRadius: BorderRadius.circular(9),
            border: Border.all(
              color:
                  widget.isSelected ? widget.color.withOpacity(0.4) : _border,
              width: 1.5,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(_roleIcon(widget.role),
                  size: 15,
                  color: widget.isSelected
                      ? widget.color
                      : _hovered
                          ? _textSecondary
                          : _textMuted),
              const SizedBox(height: 4),
              Text(_roleLabel(widget.role),
                  style: TextStyle(
                      color: widget.isSelected
                          ? widget.color
                          : _hovered
                              ? _textSecondary
                              : _textMuted,
                      fontSize: 10,
                      fontWeight: widget.isSelected
                          ? FontWeight.w600
                          : FontWeight.w400),
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis),
            ],
          ),
        ),
      ),
    );
  }
}

class _FormField extends StatefulWidget {
  final String label, hint;
  final TextEditingController controller;
  final IconData icon;
  final ValueChanged<String>? onChanged;
  const _FormField({
    required this.label,
    required this.hint,
    required this.controller,
    required this.icon,
    this.onChanged,
  });
  @override
  State<_FormField> createState() => _FormFieldState();
}

class _FormFieldState extends State<_FormField> {
  final _focus = FocusNode();
  bool _focused = false;

  @override
  void initState() {
    super.initState();
    _focus.addListener(() => setState(() => _focused = _focus.hasFocus));
  }

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(widget.label,
            style: const TextStyle(
                color: _textSecondary,
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.3)),
        const SizedBox(height: 7),
        AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          decoration: BoxDecoration(
            color: _focused ? _surface2 : _surface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: _focused ? Colors.redAccent.withOpacity(0.5) : _border,
              width: 1.5,
            ),
          ),
          child: TextField(
            controller: widget.controller,
            focusNode: _focus,
            onChanged: widget.onChanged,
            style: const TextStyle(color: _textPrimary, fontSize: 13),
            decoration: InputDecoration(
              hintText: widget.hint,
              hintStyle: const TextStyle(color: _textMuted, fontSize: 13),
              prefixIcon: Icon(widget.icon,
                  color: _focused ? Colors.redAccent : _textMuted, size: 16),
              border: InputBorder.none,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
            ),
          ),
        ),
      ],
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  final String message;
  const _ErrorBanner({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.redAccent.withOpacity(0.07),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.redAccent.withOpacity(0.25)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded,
              color: Colors.redAccent, size: 15),
          const SizedBox(width: 8),
          Expanded(
            child: Text(message,
                style: const TextStyle(color: Color(0xFFFF8A80), fontSize: 12)),
          ),
        ],
      ),
    );
  }
}

class _GhostButton extends StatefulWidget {
  final String label;
  final VoidCallback onTap;
  const _GhostButton({required this.label, required this.onTap});
  @override
  State<_GhostButton> createState() => _GhostButtonState();
}

class _GhostButtonState extends State<_GhostButton> {
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
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: _hovered ? _surface2 : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: _hovered ? _border : Colors.transparent),
          ),
          child: Text(widget.label,
              style: const TextStyle(
                  color: _textSecondary,
                  fontSize: 13,
                  fontWeight: FontWeight.w500)),
        ),
      ),
    );
  }
}

class _SaveButton extends StatefulWidget {
  final String label;
  final bool saving;
  final VoidCallback onTap;
  const _SaveButton(
      {required this.label, required this.saving, required this.onTap});
  @override
  State<_SaveButton> createState() => _SaveButtonState();
}

class _SaveButtonState extends State<_SaveButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.saving ? null : widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          decoration: BoxDecoration(
            color: widget.saving
                ? Colors.redAccent.withOpacity(0.5)
                : _hovered
                    ? Colors.redAccent.shade700
                    : Colors.redAccent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: widget.saving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                      color: Colors.white, strokeWidth: 2))
              : Text(widget.label,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w600)),
        ),
      ),
    );
  }
}
