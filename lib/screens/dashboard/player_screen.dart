import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

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
      body: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
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
                        style: TextStyle(color: _textSecondary, fontSize: 13)),
                  ],
                ),
                const Spacer(),
                _AddPlayerButton(
                  isOpen: _showAddForm,
                  onTap: () => setState(() => _showAddForm = !_showAddForm),
                ),
              ],
            ),
            const SizedBox(height: 20),
            AnimatedSize(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOut,
              child: _showAddForm
                  ? _AddPlayerForm(
                      onSaved: () => setState(() => _showAddForm = false),
                      onCancel: () => setState(() => _showAddForm = false),
                    )
                  : const SizedBox.shrink(),
            ),
            _TeamFilterBar(
              selectedTeamId: _filterTeamId,
              onChanged: (id) => setState(() => _filterTeamId = id),
            ),
            const SizedBox(height: 16),
            Expanded(child: _PlayerList(filterTeamId: _filterTeamId)),
          ],
        ),
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

// ── Add player form ────────────────────────────────────────
class _AddPlayerForm extends StatefulWidget {
  final VoidCallback onSaved, onCancel;
  const _AddPlayerForm({required this.onSaved, required this.onCancel});

  @override
  State<_AddPlayerForm> createState() => _AddPlayerFormState();
}

class _AddPlayerFormState extends State<_AddPlayerForm> {
  final _nameController = TextEditingController();
  String? _selectedTeamId;
  String? _selectedTeamDocId;
  String _role = 'batsman';
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();

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

      final playerData = {
        'id': playerId,
        'name': name,
        'role': _role,
        'teamId': _selectedTeamId,
      };

      // ── Step 1: Save to teams collection ──────────────────
      await FirebaseFirestore.instance
          .collection('teams')
          .doc(_selectedTeamDocId)
          .update({
        'players': FieldValue.arrayUnion([playerData])
      });

      // ── Step 2: Sync into featured_match if this team is assigned ──
      // Read full updated team doc (now includes the new player)
      final teamSnap = await FirebaseFirestore.instance
          .collection('teams')
          .doc(_selectedTeamDocId)
          .get();

      final allPlayers = List<dynamic>.from(teamSnap.data()?['players'] ?? []);

      // Clean structure for featured_match — only id/name/role
      final cleanPlayers = allPlayers
          .map((p) => {
                'id': p['id'] ?? '',
                'name': p['name'] ?? '',
                'role': p['role'] ?? '',
              })
          .toList();

      // Check if this team is teamA or teamB in featured_match
      final featuredRef = FirebaseFirestore.instance
          .collection('featured_match')
          .doc('admin_current');

      final featuredSnap = await featuredRef.get();
      if (featuredSnap.exists) {
        final featuredData = featuredSnap.data()!;
        final teams = Map<String, dynamic>.from(featuredData['teams'] ?? {});

        // Find which slot this team occupies (teamA or teamB)
        String? matchedKey;
        if ((teams['teamA'] as Map<String, dynamic>?)?['teamId'] ==
            _selectedTeamId) {
          matchedKey = 'teamA';
        } else if ((teams['teamB'] as Map<String, dynamic>?)?['teamId'] ==
            _selectedTeamId) {
          matchedKey = 'teamB';
        }

        // If assigned → update only the players list in that slot
        if (matchedKey != null) {
          final updatedSlot = Map<String, dynamic>.from(
              teams[matchedKey] as Map<String, dynamic>);
          updatedSlot['players'] = cleanPlayers;
          teams[matchedKey] = updatedSlot;

          // merge:true → meta/matchId/other team untouched
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.person_add_rounded, color: Colors.redAccent, size: 16),
              SizedBox(width: 8),
              Text('New Player',
                  style: TextStyle(
                      color: _textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 3,
                child: _FormField(
                  label: 'Player Name',
                  hint: 'e.g. Virat Kohli',
                  controller: _nameController,
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
          if (_error != null) ...[
            const SizedBox(height: 14),
            _ErrorBanner(message: _error!),
          ],
          const SizedBox(height: 20),
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
    );
  }
}

// ── Team dropdown ──────────────────────────────────────────
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
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        teamId.length > 2 ? teamId.substring(0, 2) : teamId,
        style: const TextStyle(
            color: Colors.redAccent, fontSize: 7, fontWeight: FontWeight.w800),
      ),
    );
  }
}

// ── Role selector ──────────────────────────────────────────
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
            final teamId = entry.key;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _TeamGroupHeader(
                    teamId: teamId,
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

  @override
  Widget build(BuildContext context) {
    final name = widget.player['name'] ?? '—';
    final role = widget.player['role'] ?? 'batsman';
    final id = widget.player['id'] ?? '—';
    final color = _roleColor(role);

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        decoration: BoxDecoration(
          color: _hovered ? _surface2 : _surface,
          borderRadius: BorderRadius.circular(10),
          border:
              Border.all(color: _hovered ? const Color(0xFF2E2E2E) : _border),
        ),
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
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
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
            const SizedBox(width: 10),
            _DeletePlayerButton(
              playerData: widget.player,
              teamDocId: widget.teamDocId,
              playerName: name,
            ),
          ],
        ),
      ),
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

    // ── Step 1: Remove from teams collection ──────────────────
    final teamRef =
        FirebaseFirestore.instance.collection('teams').doc(widget.teamDocId);

    final teamSnap = await teamRef.get();
    if (teamSnap.data() == null) return;

    final players = List<dynamic>.from(teamSnap.data()!['players'] ?? []);
    players.removeWhere((p) => p['id'] == widget.playerData['id']);
    await teamRef.update({'players': players});

    // ── Step 2: Sync deletion into featured_match if assigned ──
    final teamId = widget.playerData['teamId'] as String?;
    if (teamId == null) return;

    // Clean players (without deleted one) for featured_match
    final cleanPlayers = players
        .map((p) => {
              'id': p['id'] ?? '',
              'name': p['name'] ?? '',
              'role': p['role'] ?? '',
            })
        .toList();

    final featuredRef = FirebaseFirestore.instance
        .collection('featured_match')
        .doc('admin_current');

    final featuredSnap = await featuredRef.get();
    if (!featuredSnap.exists) return;

    final featuredData = featuredSnap.data()!;
    final teams = Map<String, dynamic>.from(featuredData['teams'] ?? {});

    String? matchedKey;
    if ((teams['teamA'] as Map<String, dynamic>?)?['teamId'] == teamId) {
      matchedKey = 'teamA';
    } else if ((teams['teamB'] as Map<String, dynamic>?)?['teamId'] == teamId) {
      matchedKey = 'teamB';
    }

    if (matchedKey != null) {
      final updatedSlot =
          Map<String, dynamic>.from(teams[matchedKey] as Map<String, dynamic>);
      updatedSlot['players'] = cleanPlayers;
      teams[matchedKey] = updatedSlot;

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
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: _surface,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: _border),
            ),
            child: const Icon(Icons.person_off_rounded,
                color: _textMuted, size: 26),
          ),
          const SizedBox(height: 16),
          Text(
            isFiltered ? 'No players in this team' : 'No players yet',
            style: const TextStyle(
                color: _textPrimary, fontSize: 16, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 6),
          Text(
            isFiltered
                ? 'Add players using the form above.'
                : 'Click "Add Player" to add your first player.',
            style: const TextStyle(color: _textSecondary, fontSize: 13),
          ),
        ],
      ),
    );
  }
}

// ── Reusable widgets ───────────────────────────────────────
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
    // ignore: unused_element_parameter
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
