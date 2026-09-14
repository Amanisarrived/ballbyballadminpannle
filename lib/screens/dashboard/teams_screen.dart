import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cricket_admin/services/featured_match_service.dart';
import 'package:flutter/material.dart';

const _bg = Color(0xFF0D0D0D);
const _surface = Color(0xFF141414);
const _surface2 = Color(0xFF1A1A1A);
const _border = Color(0xFF232323);
const _textPrimary = Color(0xFFE8E8E8);
const _textSecondary = Color(0xFF666666);
const _textMuted = Color(0xFF444444);

class TeamsScreen extends StatefulWidget {
  const TeamsScreen({super.key});
  @override
  State<TeamsScreen> createState() => _TeamsScreenState();
}

class _TeamsScreenState extends State<TeamsScreen> {
  bool _showAddForm = false;

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
                    Text('Teams',
                        style: TextStyle(
                            color: _textPrimary,
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.4)),
                    SizedBox(height: 3),
                    Text('Manage cricket teams and assign to featured match',
                        style: TextStyle(color: _textSecondary, fontSize: 13)),
                  ],
                ),
                const Spacer(),
                _AddTeamButton(
                  isOpen: _showAddForm,
                  onTap: () => setState(() => _showAddForm = !_showAddForm),
                ),
              ],
            ),
            const SizedBox(height: 24),
            AnimatedSize(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOut,
              child: _showAddForm
                  ? _AddTeamForm(
                      onSaved: () => setState(() => _showAddForm = false),
                      onCancel: () => setState(() => _showAddForm = false),
                    )
                  : const SizedBox.shrink(),
            ),
            const _FeaturedAssignmentPanel(),
            const SizedBox(height: 20),
            const Row(
              children: [
                Text('ALL TEAMS',
                    style: TextStyle(
                        color: _textMuted,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.2)),
                SizedBox(width: 12),
                Expanded(child: Divider(color: Color(0xFF1E1E1E))),
              ],
            ),
            const SizedBox(height: 12),
            Expanded(child: _TeamList()),
          ],
        ),
      ),
    );
  }
}

// ── Featured assignment panel ──────────────────────────────
class _FeaturedAssignmentPanel extends StatelessWidget {
  const _FeaturedAssignmentPanel();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FeaturedMatchService.stream(),
      builder: (context, snap) {
        final data = snap.hasData && snap.data!.exists
            ? snap.data!.data() as Map<String, dynamic>
            : <String, dynamic>{};

        final teams = data['teams'] as Map<String, dynamic>? ?? {};
        final tA = teams['teamA'] as Map<String, dynamic>?;
        final tB = teams['teamB'] as Map<String, dynamic>?;
        final meta = data['meta'] as Map<String, dynamic>? ?? {};
        final matchTitle = meta['title'] as String? ?? '';

        return Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: _surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.redAccent.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(5),
                      border:
                          Border.all(color: Colors.redAccent.withOpacity(0.2)),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.star_rounded,
                            color: Colors.redAccent, size: 10),
                        SizedBox(width: 4),
                        Text('FEATURED MATCH',
                            style: TextStyle(
                                color: Colors.redAccent,
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.5)),
                      ],
                    ),
                  ),
                  if (matchTitle.isNotEmpty) ...[
                    const SizedBox(width: 10),
                    Text(matchTitle,
                        style: const TextStyle(
                            color: _textSecondary, fontSize: 12)),
                  ],
                  const Spacer(),
                  Text(
                    snap.connectionState == ConnectionState.waiting
                        ? 'Loading...'
                        : 'featured_match / admin_current',
                    style: const TextStyle(
                        color: _textMuted,
                        fontSize: 10,
                        fontFamily: 'monospace'),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                      child: _TeamSlot(
                          teamKey: 'teamA', label: 'Team A', teamData: tA)),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: _surface2,
                        shape: BoxShape.circle,
                        border: Border.all(color: _border),
                      ),
                      child: const Center(
                        child: Text('VS',
                            style: TextStyle(
                                color: _textMuted,
                                fontSize: 9,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.5)),
                      ),
                    ),
                  ),
                  Expanded(
                      child: _TeamSlot(
                          teamKey: 'teamB', label: 'Team B', teamData: tB)),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _TeamSlot extends StatelessWidget {
  final String teamKey, label;
  final Map<String, dynamic>? teamData;

  const _TeamSlot({
    required this.teamKey,
    required this.label,
    required this.teamData,
  });

  @override
  Widget build(BuildContext context) {
    final isEmpty = teamData == null;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _surface2,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isEmpty ? _border : Colors.redAccent.withOpacity(0.2),
        ),
      ),
      child: isEmpty
          ? _EmptySlot(label: label)
          : _FilledSlot(label: label, teamData: teamData!, teamKey: teamKey),
    );
  }
}

class _EmptySlot extends StatelessWidget {
  final String label;
  const _EmptySlot({required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: _surface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: _border),
          ),
          child: const Icon(Icons.shield_outlined, color: _textMuted, size: 16),
        ),
        const SizedBox(width: 10),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: const TextStyle(
                    color: _textMuted,
                    fontSize: 9,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5)),
            const Text('Not assigned',
                style: TextStyle(color: _textSecondary, fontSize: 12)),
          ],
        ),
      ],
    );
  }
}

class _FilledSlot extends StatefulWidget {
  final String label, teamKey;
  final Map<String, dynamic> teamData;

  const _FilledSlot({
    required this.label,
    required this.teamData,
    required this.teamKey,
  });

  @override
  State<_FilledSlot> createState() => _FilledSlotState();
}

class _FilledSlotState extends State<_FilledSlot> {
  bool _removing = false;

  Future<void> _remove() async {
    setState(() => _removing = true);
    try {
      final docRef = FirebaseFirestore.instance
          .collection('featured_match')
          .doc('admin_current');
      final snap = await docRef.get();
      if (!snap.exists) return;

      final existing = Map<String, dynamic>.from((snap.data()!)['teams'] ?? {});
      existing.remove(widget.teamKey);
      // Use set with merge so only teams field is updated, meta/matchId untouched
      await docRef.set({'teams': existing}, SetOptions(merge: true));
    } finally {
      if (mounted) setState(() => _removing = false);
    }
  }

  Future<void> _editLogo() async {
    final td = widget.teamData;
    final url = await showDialog<String>(
      context: context,
      builder: (_) => _LogoDialog(
        teamName: (td['name'] ?? '').toString(),
        initial: (td['logo'] ?? '').toString(),
      ),
    );
    if (url == null || !mounted) return;

    try {
      await FeaturedMatchService.setTeamLogo(
        teamKey: widget.teamKey,
        teamId: (td['teamId'] ?? '').toString(),
        logo: url,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        backgroundColor: const Color(0xFF1A1A1A),
        behavior: SnackBarBehavior.floating,
        content: Text(url.isEmpty ? 'Logo removed' : 'Logo updated',
            style: const TextStyle(color: _textPrimary)),
      ));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        backgroundColor: const Color(0xFF1A1A1A),
        behavior: SnackBarBehavior.floating,
        content: Text('Error: $e',
            style: const TextStyle(color: Colors.redAccent)),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final td = widget.teamData;
    final teamId = td['teamId'] ?? '';
    final name = td['name'] ?? '—';
    final logo = td['logo'] ?? '';
    final players = (td['players'] as List?)?.length ?? 0;

    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: Colors.redAccent.withOpacity(0.06),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.redAccent.withOpacity(0.2)),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(7),
            child: logo.isNotEmpty
                ? Image.network(logo,
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => _FallbackLogo(teamId: teamId))
                : _FallbackLogo(teamId: teamId),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(widget.label,
                  style: const TextStyle(
                      color: _textMuted,
                      fontSize: 9,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5)),
              Text(name,
                  style: const TextStyle(
                      color: _textPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w700),
                  overflow: TextOverflow.ellipsis),
              Text('$players players · $teamId',
                  style: const TextStyle(color: _textSecondary, fontSize: 10)),
            ],
          ),
        ),
        if (_removing)
          const SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(
                color: Colors.redAccent, strokeWidth: 1.5),
          )
        else ...[
          _SmallIconButton(icon: Icons.image_outlined, onTap: _editLogo),
          const SizedBox(width: 4),
          _SmallIconButton(icon: Icons.close_rounded, onTap: _remove),
        ],
      ],
    );
  }
}

class _LogoDialog extends StatefulWidget {
  final String teamName;
  final String initial;
  const _LogoDialog({required this.teamName, required this.initial});

  @override
  State<_LogoDialog> createState() => _LogoDialogState();
}

class _LogoDialogState extends State<_LogoDialog> {
  late final TextEditingController _ctrl =
      TextEditingController(text: widget.initial);
  bool _previewError = false;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final url = _ctrl.text.trim();
    return AlertDialog(
      backgroundColor: _surface,
      title: Text('Logo — ${widget.teamName}',
          style: const TextStyle(color: _textPrimary, fontSize: 15)),
      content: SizedBox(
        width: 360,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: _surface2,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _border),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(11),
                child: url.isNotEmpty && !_previewError
                    ? Image.network(url,
                        fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) {
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            if (mounted && !_previewError) {
                              setState(() => _previewError = true);
                            }
                          });
                          return const SizedBox.shrink();
                        })
                    : const Icon(Icons.image_not_supported_outlined,
                        color: _textMuted),
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _ctrl,
              autofocus: true,
              style: const TextStyle(color: _textPrimary, fontSize: 13),
              onChanged: (_) => setState(() => _previewError = false),
              decoration: InputDecoration(
                hintText: 'https://example.com/logo.png',
                hintStyle: const TextStyle(color: _textMuted, fontSize: 12),
                filled: true,
                fillColor: _surface2,
                isDense: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: _border),
                ),
              ),
            ),
            if (_previewError) ...[
              const SizedBox(height: 8),
              const Text('Could not load this image — check the URL.',
                  style: TextStyle(color: Colors.redAccent, fontSize: 11)),
            ],
            const SizedBox(height: 8),
            const Text(
              'Saved for this team, so it reappears the next time they are featured.',
              style: TextStyle(color: _textSecondary, fontSize: 11),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel', style: TextStyle(color: _textSecondary)),
        ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
          onPressed: () => Navigator.pop(context, url),
          child: const Text('Save'),
        ),
      ],
    );
  }
}

class _SmallIconButton extends StatefulWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _SmallIconButton({required this.icon, required this.onTap});

  @override
  State<_SmallIconButton> createState() => _SmallIconButtonState();
}

class _SmallIconButtonState extends State<_SmallIconButton> {
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
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: _hovered
                ? Colors.redAccent.withOpacity(0.1)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Icon(widget.icon,
              color: _hovered ? Colors.redAccent : _textMuted, size: 14),
        ),
      ),
    );
  }
}

// ── Team list ──────────────────────────────────────────────
class _TeamList extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('teams')
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(
              child: CircularProgressIndicator(
                  color: Colors.redAccent, strokeWidth: 2));
        }
        if (!snap.hasData || snap.data!.docs.isEmpty) return _EmptyState();

        final docs = snap.data!.docs;
        return ListView.separated(
          itemCount: docs.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (context, i) {
            final data = docs[i].data() as Map<String, dynamic>;
            return _TeamCard(
              docId: docs[i].id,
              teamId: data['teamId'] ?? '—',
              name: data['name'] ?? '—',
              logo: data['logo'] ?? '',
              playerCount: (data['players'] as List<dynamic>?)?.length ?? 0,
              players: List<Map<String, dynamic>>.from(
                (data['players'] as List<dynamic>? ?? [])
                    .map((p) => Map<String, dynamic>.from(p as Map)),
              ),
            );
          },
        );
      },
    );
  }
}

// ── Team card ──────────────────────────────────────────────
class _TeamCard extends StatefulWidget {
  final String docId, teamId, name, logo;
  final int playerCount;
  final List<Map<String, dynamic>> players;

  const _TeamCard({
    required this.docId,
    required this.teamId,
    required this.name,
    required this.logo,
    required this.playerCount,
    required this.players,
  });

  @override
  State<_TeamCard> createState() => _TeamCardState();
}

class _TeamCardState extends State<_TeamCard> {
  bool _hovered = false;
  bool _logoError = false;
  bool _assigning = false;

  Future<void> _assignToFeatured(String teamKey) async {
    setState(() => _assigning = true);
    try {
      final cleanPlayers = widget.players
          .map((p) => {
                'id': p['id'] ?? '',
                'name': p['name'] ?? '',
                'role': p['role'] ?? ''
              })
          .toList();

      await FeaturedMatchService.saveTeam(
        teamKey: teamKey,
        teamId: widget.teamId,
        name: widget.name,
        logo: widget.logo,
        players: cleanPlayers,
      );

      if (!mounted) return;
      _showSnackbar(context, '${widget.name} set as $teamKey', isError: false);
    } catch (e) {
      if (!mounted) return;
      _showSnackbar(context, 'Error: $e', isError: true);
    } finally {
      if (mounted) setState(() => _assigning = false);
    }
  }

  void _showSnackbar(BuildContext context, String message,
      {required bool isError}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      backgroundColor: const Color(0xFF1A1A1A),
      behavior: SnackBarBehavior.floating,
      margin: const EdgeInsets.all(20),
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: BorderSide(color: Colors.redAccent.withOpacity(0.3))),
      content: Row(
        children: [
          Icon(
            isError
                ? Icons.error_outline_rounded
                : Icons.check_circle_outline_rounded,
            color: isError ? const Color(0xFFFF8A80) : Colors.redAccent,
            size: 16,
          ),
          const SizedBox(width: 10),
          Text(message,
              style: TextStyle(
                  color: isError ? const Color(0xFFFF8A80) : _textPrimary,
                  fontSize: 13)),
        ],
      ),
      duration: Duration(seconds: isError ? 3 : 2),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        decoration: BoxDecoration(
          color: _hovered ? _surface2 : _surface,
          borderRadius: BorderRadius.circular(12),
          border:
              Border.all(color: _hovered ? const Color(0xFF2E2E2E) : _border),
        ),
        child: Row(
          children: [
            // Logo
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: _surface2,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: _border),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(9),
                child: widget.logo.isNotEmpty && !_logoError
                    ? Image.network(widget.logo, fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) {
                        WidgetsBinding.instance.addPostFrameCallback(
                            (_) => setState(() => _logoError = true));
                        return _FallbackLogo(teamId: widget.teamId);
                      })
                    : _FallbackLogo(teamId: widget.teamId),
              ),
            ),
            const SizedBox(width: 14),

            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(widget.name,
                          style: const TextStyle(
                              color: _textPrimary,
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              letterSpacing: -0.2)),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.redAccent.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                              color: Colors.redAccent.withOpacity(0.2)),
                        ),
                        child: Text(widget.teamId,
                            style: const TextStyle(
                                color: Colors.redAccent,
                                fontSize: 9,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.5)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.people_outline_rounded,
                          color: _textMuted, size: 12),
                      const SizedBox(width: 4),
                      Text(
                        '${widget.playerCount} player${widget.playerCount == 1 ? '' : 's'}',
                        style: const TextStyle(
                            color: _textSecondary, fontSize: 11),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Assign buttons (hover only)
            AnimatedOpacity(
              duration: const Duration(milliseconds: 150),
              opacity: _hovered ? 1.0 : 0.0,
              child: _assigning
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          color: Colors.redAccent, strokeWidth: 2),
                    )
                  : Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _AssignButton(
                            label: 'Set A',
                            onTap: () => _assignToFeatured('teamA')),
                        const SizedBox(width: 6),
                        _AssignButton(
                            label: 'Set B',
                            onTap: () => _assignToFeatured('teamB')),
                        const SizedBox(width: 8),
                      ],
                    ),
            ),

            // ✅ FIX: pass teamId so delete can check featured_match
            _DeleteButton(
              docId: widget.docId,
              teamId: widget.teamId, // ← NEW: needed to unassign from featured
              name: widget.name,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Assign button ──────────────────────────────────────────
class _AssignButton extends StatefulWidget {
  final String label;
  final VoidCallback onTap;
  const _AssignButton({required this.label, required this.onTap});

  @override
  State<_AssignButton> createState() => _AssignButtonState();
}

class _AssignButtonState extends State<_AssignButton> {
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
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: _hovered
                ? Colors.redAccent.withOpacity(0.15)
                : Colors.redAccent.withOpacity(0.08),
            borderRadius: BorderRadius.circular(7),
            border: Border.all(
              color: _hovered
                  ? Colors.redAccent.withOpacity(0.5)
                  : Colors.redAccent.withOpacity(0.2),
            ),
          ),
          child: Text(widget.label,
              style: TextStyle(
                  color: _hovered
                      ? Colors.redAccent
                      : Colors.redAccent.withOpacity(0.7),
                  fontSize: 11,
                  fontWeight: FontWeight.w600)),
        ),
      ),
    );
  }
}

// ── Fallback logo ──────────────────────────────────────────
class _FallbackLogo extends StatelessWidget {
  final String teamId;
  const _FallbackLogo({required this.teamId});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.redAccent.withOpacity(0.08),
      child: Center(
        child: Text(
          teamId.length > 3 ? teamId.substring(0, 3) : teamId,
          style: const TextStyle(
              color: Colors.redAccent,
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.5),
        ),
      ),
    );
  }
}

// ── Add team button ────────────────────────────────────────
class _AddTeamButton extends StatefulWidget {
  final bool isOpen;
  final VoidCallback onTap;
  const _AddTeamButton({required this.isOpen, required this.onTap});

  @override
  State<_AddTeamButton> createState() => _AddTeamButtonState();
}

class _AddTeamButtonState extends State<_AddTeamButton> {
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
                widget.isOpen ? 'Cancel' : 'Add Team',
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

// ── Add team form ──────────────────────────────────────────
class _AddTeamForm extends StatefulWidget {
  final VoidCallback onSaved, onCancel;
  const _AddTeamForm({required this.onSaved, required this.onCancel});

  @override
  State<_AddTeamForm> createState() => _AddTeamFormState();
}

class _AddTeamFormState extends State<_AddTeamForm> {
  final _teamIdController = TextEditingController();
  final _nameController = TextEditingController();
  final _logoUrlController = TextEditingController();
  bool _saving = false;
  String? _error;
  bool _logoPreviewError = false;

  @override
  void dispose() {
    _teamIdController.dispose();
    _nameController.dispose();
    _logoUrlController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final teamId = _teamIdController.text.trim().toUpperCase();
    final name = _nameController.text.trim();
    final logo = _logoUrlController.text.trim();

    if (teamId.isEmpty || name.isEmpty) {
      setState(() => _error = 'Team ID and name are required.');
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      await FirebaseFirestore.instance.collection('teams').doc(teamId).set({
        'teamId': teamId,
        'name': name,
        'logo': logo,
        'players': [],
        'createdAt': FieldValue.serverTimestamp(),
      });
      widget.onSaved();
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final logoUrl = _logoUrlController.text.trim();

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(22),
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
              Icon(Icons.group_add_rounded, color: Colors.redAccent, size: 15),
              SizedBox(width: 8),
              Text('New Team',
                  style: TextStyle(
                      color: _textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                children: [
                  const Text('Preview',
                      style: TextStyle(
                          color: _textSecondary,
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.3)),
                  const SizedBox(height: 6),
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: _surface2,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: _border),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(11),
                      child: logoUrl.isNotEmpty && !_logoPreviewError
                          ? Image.network(logoUrl, fit: BoxFit.contain,
                              errorBuilder: (_, __, ___) {
                              WidgetsBinding.instance.addPostFrameCallback(
                                  (_) =>
                                      setState(() => _logoPreviewError = true));
                              return const Icon(Icons.broken_image_rounded,
                                  color: _textMuted, size: 24);
                            })
                          : const Icon(Icons.shield_rounded,
                              color: _textMuted, size: 24),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 18),
              Expanded(
                child: Column(
                  children: [
                    Row(
                      children: [
                        SizedBox(
                          width: 110,
                          child: _FormField(
                            label: 'Team ID',
                            hint: 'e.g. IND',
                            controller: _teamIdController,
                            icon: Icons.tag_rounded,
                            uppercase: true,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: _FormField(
                            label: 'Team Name',
                            hint: 'e.g. India',
                            controller: _nameController,
                            icon: Icons.groups_rounded,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _FormField(
                      label: 'Logo URL',
                      hint: 'https://example.com/logo.png',
                      controller: _logoUrlController,
                      icon: Icons.image_outlined,
                      onChanged: (_) =>
                          setState(() => _logoPreviewError = false),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            _ErrorBanner(message: _error!),
          ],
          const SizedBox(height: 18),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              _GhostButton(label: 'Cancel', onTap: widget.onCancel),
              const SizedBox(width: 10),
              _SaveButton(label: 'Save Team', saving: _saving, onTap: _save),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Delete button ──────────────────────────────────────────
// ✅ FIX: now accepts teamId to check & clean up featured_match
class _DeleteButton extends StatefulWidget {
  final String docId, teamId, name; // teamId added
  const _DeleteButton({
    required this.docId,
    required this.teamId,
    required this.name,
  });

  @override
  State<_DeleteButton> createState() => _DeleteButtonState();
}

class _DeleteButtonState extends State<_DeleteButton> {
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
      builder: (_) => _DeleteDialog(name: widget.name),
    );
    if (confirm != true) return;

    // ── Step 1: Delete from teams collection ──
    await FirebaseFirestore.instance
        .collection('teams')
        .doc(widget.docId)
        .delete();

    // ── Step 2: Check if this team is assigned in featured_match ──
    // If teamA or teamB has the same teamId, remove it from the map
    // featured_match/admin_current stays intact — only that slot is cleared
    final featuredRef = FirebaseFirestore.instance
        .collection('featured_match')
        .doc('admin_current');

    final snap = await featuredRef.get();
    if (!snap.exists) return;

    final data = snap.data()!;
    final teams = Map<String, dynamic>.from(data['teams'] ?? {});

    bool changed = false;

    // Compare using teamId (e.g. "IND"), not docId
    if ((teams['teamA'] as Map<String, dynamic>?)?['teamId'] == widget.teamId) {
      teams.remove('teamA');
      changed = true;
    }
    if ((teams['teamB'] as Map<String, dynamic>?)?['teamId'] == widget.teamId) {
      teams.remove('teamB');
      changed = true;
    }

    // Only write back if something actually changed
    // Use set+merge so matchId/meta are never touched
    if (changed) {
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
              child: const Icon(Icons.delete_outline_rounded,
                  color: Colors.redAccent, size: 20),
            ),
            const SizedBox(height: 16),
            const Text('Delete team?',
                style: TextStyle(
                    color: _textPrimary,
                    fontSize: 17,
                    fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            Text('"$name" will be permanently deleted.',
                style: const TextStyle(
                    color: _textSecondary, fontSize: 13, height: 1.5)),
            const SizedBox(height: 4),
            const Text(
                'If assigned to a featured match, it will be unassigned.',
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
                    child: const Text('Delete',
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
            child:
                const Icon(Icons.groups_rounded, color: _textMuted, size: 28),
          ),
          const SizedBox(height: 16),
          const Text('No teams yet',
              style: TextStyle(
                  color: _textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          const Text('Click "Add Team" to create your first team.',
              style: TextStyle(color: _textSecondary, fontSize: 13)),
        ],
      ),
    );
  }
}

// ── Reusable form widgets ──────────────────────────────────
class _FormField extends StatefulWidget {
  final String label, hint;
  final TextEditingController controller;
  final IconData icon;
  final bool uppercase;
  final ValueChanged<String>? onChanged;

  const _FormField({
    required this.label,
    required this.hint,
    required this.controller,
    required this.icon,
    this.uppercase = false,
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
        const SizedBox(height: 6),
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
            textCapitalization: widget.uppercase
                ? TextCapitalization.characters
                : TextCapitalization.words,
            onChanged: widget.onChanged,
            style: TextStyle(
              color: _textPrimary,
              fontSize: 13,
              fontWeight:
                  widget.uppercase ? FontWeight.w700 : FontWeight.normal,
              letterSpacing: widget.uppercase ? 1.5 : 0,
            ),
            decoration: InputDecoration(
              hintText: widget.hint,
              hintStyle: const TextStyle(color: _textMuted, fontSize: 13),
              prefixIcon: Icon(widget.icon,
                  color: _focused ? Colors.redAccent : _textMuted, size: 15),
              border: InputBorder.none,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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
