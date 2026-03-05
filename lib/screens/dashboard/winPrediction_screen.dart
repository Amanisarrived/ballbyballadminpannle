import 'package:cricket_admin/services/winpredictor_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// ── Theme (matches admin panel) ───────────────────────────
const _bg = Color(0xFF0D0D0D);
const _surface = Color(0xFF141414);
const _surface2 = Color(0xFF1A1A1A);
const _surface3 = Color(0xFF202020);
const _border = Color(0xFF232323);
const _border2 = Color(0xFF2A2A2A);
const _textPrimary = Color(0xFFE8E8E8);
const _textSecondary = Color(0xFF666666);
const _textMuted = Color(0xFF3A3A3A);

// ════════════════════════════════════════════════════════════
//  WIN PREDICTOR SCREEN
// ════════════════════════════════════════════════════════════
class WinPredictorScreen extends StatefulWidget {
  const WinPredictorScreen({super.key});
  @override
  State<WinPredictorScreen> createState() => _WinPredictorScreenState();
}

class _WinPredictorScreenState extends State<WinPredictorScreen> {
  // ── Form controllers ──────────────────────────────────────
  final _team1Ctrl = TextEditingController();
  final _team1LogoCtrl = TextEditingController();
  final _team1ColorCtrl = TextEditingController(text: '#CC0000');
  final _team2Ctrl = TextEditingController();
  final _team2LogoCtrl = TextEditingController();
  final _team2ColorCtrl = TextEditingController(text: '#1A73E8');

  bool _showPoll = false;
  bool _showVotes = false;
  bool _saving = false;
  bool _resetting = false;
  bool _loaded = false; // guard so we only pre-fill once
  String _status = ''; // 'success' | 'error' | ''

  @override
  void dispose() {
    for (final c in [
      _team1Ctrl,
      _team1LogoCtrl,
      _team1ColorCtrl,
      _team2Ctrl,
      _team2LogoCtrl,
      _team2ColorCtrl,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  // ── Load current poll into form (safe — post frame) ───────
  void _loadPoll(AdminPoll poll) {
    if (_loaded) return; // already pre-filled
    _loaded = true;
    // Defer setState so it never runs during build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() {
        _team1Ctrl.text = poll.team1;
        _team1LogoCtrl.text = poll.team1Logo;
        _team1ColorCtrl.text = poll.team1Color;
        _team2Ctrl.text = poll.team2;
        _team2LogoCtrl.text = poll.team2Logo;
        _team2ColorCtrl.text = poll.team2Color;
        _showPoll = poll.showPoll;
        _showVotes = poll.showVotes;
      });
    });
  }

  // ── Save ──────────────────────────────────────────────────
  Future<void> _save() async {
    if (_saving) return;
    if (_team1Ctrl.text.trim().isEmpty || _team2Ctrl.text.trim().isEmpty) {
      _showStatus('error');
      return;
    }
    setState(() => _saving = true);
    try {
      await AdminWinPredictorService.savePoll(
        pollId: AdminWinPredictorService.generatePollId(),
        showPoll: _showPoll,
        showVotes: _showVotes,
        team1: _team1Ctrl.text.trim(),
        team1Color: _team1ColorCtrl.text.trim(),
        team1Logo: _team1LogoCtrl.text.trim(),
        team2: _team2Ctrl.text.trim(),
        team2Color: _team2ColorCtrl.text.trim(),
        team2Logo: _team2LogoCtrl.text.trim(),
      );
      _showStatus('success');
    } catch (_) {
      _showStatus('error');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  // ── Reset votes ───────────────────────────────────────────
  Future<void> _resetVotes() async {
    final confirm = await _showConfirmDialog();
    if (!confirm) return;
    setState(() => _resetting = true);
    try {
      await AdminWinPredictorService.resetVotes();
      _showStatus('success');
    } catch (_) {
      _showStatus('error');
    } finally {
      if (mounted) setState(() => _resetting = false);
    }
  }

  Future<bool> _showConfirmDialog() async {
    return await showDialog<bool>(
          context: context,
          builder: (_) => _ConfirmResetDialog(),
        ) ??
        false;
  }

  void _showStatus(String type) {
    setState(() => _status = type);
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) setState(() => _status = '');
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: StreamBuilder(
        stream: AdminWinPredictorService.pollStream(),
        builder: (context, snap) {
          if (snap.hasData && snap.data?.data() != null) {
            final poll = AdminPoll.fromDoc(snap.data!);
            _loadPoll(poll);

            return Column(
              children: [
                // ── Header ──────────────────────────────
                _Header(
                  showPoll: _showPoll,
                  saving: _saving,
                  onToggle: (v) async {
                    setState(() => _showPoll = v);
                    await AdminWinPredictorService.setShowPoll(v);
                  },
                  onSave: _save,
                ),

                // ── Status banner ────────────────────────
                if (_status.isNotEmpty) _StatusBanner(type: _status),

                // ── Body ────────────────────────────────
                Expanded(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Left — form
                      SizedBox(
                        width: 440,
                        child: _FormPanel(
                          team1Ctrl: _team1Ctrl,
                          team1LogoCtrl: _team1LogoCtrl,
                          team1ColorCtrl: _team1ColorCtrl,
                          team2Ctrl: _team2Ctrl,
                          team2LogoCtrl: _team2LogoCtrl,
                          team2ColorCtrl: _team2ColorCtrl,
                          showVotes: _showVotes,
                          onShowVotesChanged: (v) async {
                            setState(() => _showVotes = v);
                            await AdminWinPredictorService.setShowVotes(v);
                          },
                          onResetVotes: _resetVotes,
                          resetting: _resetting,
                        ),
                      ),

                      // Divider
                      Container(width: 1, color: _border),

                      // Right — live stats + preview
                      Expanded(
                        child: _StatsPanel(
                          poll: poll,
                          team1Color:
                              _hexColor(_team1ColorCtrl.text, Colors.redAccent),
                          team2Color: _hexColor(
                              _team2ColorCtrl.text, Colors.blueAccent),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          }

          // Loading
          return const Center(
            child: CircularProgressIndicator(
                color: Colors.redAccent, strokeWidth: 2),
          );
        },
      ),
    );
  }

  Color _hexColor(String hex, Color fallback) {
    try {
      return Color(int.parse('FF${hex.replaceAll('#', '')}', radix: 16));
    } catch (_) {
      return fallback;
    }
  }
}

// ════════════════════════════════════════════════════════════
//  HEADER
// ════════════════════════════════════════════════════════════
class _Header extends StatelessWidget {
  final bool showPoll, saving;
  final ValueChanged<bool> onToggle;
  final VoidCallback onSave;

  const _Header({
    required this.showPoll,
    required this.saving,
    required this.onToggle,
    required this.onSave,
  });

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
          const Icon(Icons.how_to_vote_rounded,
              color: _textSecondary, size: 18),
          const SizedBox(width: 12),
          const Text('Win Predictor',
              style: TextStyle(
                  color: _textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w700)),
          const SizedBox(width: 20),

          // Live / Hidden pill
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color:
                  showPoll ? Colors.greenAccent.withOpacity(0.08) : _surface2,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: showPoll ? Colors.greenAccent.withOpacity(0.3) : _border,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 5,
                  height: 5,
                  decoration: BoxDecoration(
                    color: showPoll ? Colors.greenAccent : _textMuted,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  showPoll ? 'Live' : 'Hidden',
                  style: TextStyle(
                      color: showPoll ? Colors.greenAccent : _textSecondary,
                      fontSize: 11,
                      fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),

          const Spacer(),

          // Quick toggle
          _QuickToggle(
            label: showPoll ? 'Hide Poll' : 'Show Poll',
            active: showPoll,
            onTap: () => onToggle(!showPoll),
          ),
          const SizedBox(width: 10),

          // Save button
          _SaveBtn(saving: saving, onTap: onSave),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════
//  FORM PANEL
// ════════════════════════════════════════════════════════════
class _FormPanel extends StatelessWidget {
  final TextEditingController team1Ctrl, team1LogoCtrl, team1ColorCtrl;
  final TextEditingController team2Ctrl, team2LogoCtrl, team2ColorCtrl;
  final bool showVotes, resetting;
  final ValueChanged<bool> onShowVotesChanged;
  final VoidCallback onResetVotes;

  const _FormPanel({
    required this.team1Ctrl,
    required this.team1LogoCtrl,
    required this.team1ColorCtrl,
    required this.team2Ctrl,
    required this.team2LogoCtrl,
    required this.team2ColorCtrl,
    required this.showVotes,
    required this.onShowVotesChanged,
    required this.onResetVotes,
    required this.resetting,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Team 1 ──────────────────────────────────────
          _SectionLabel('TEAM 1'),
          const SizedBox(height: 10),
          _Field(ctrl: team1Ctrl, hint: 'Team name  e.g. India'),
          const SizedBox(height: 8),
          _Field(
              ctrl: team1LogoCtrl,
              hint: 'Logo URL (optional)',
              icon: Icons.image_rounded),
          const SizedBox(height: 8),
          _ColorField(ctrl: team1ColorCtrl, label: 'Team color'),
          const SizedBox(height: 24),

          // ── Team 2 ──────────────────────────────────────
          _SectionLabel('TEAM 2'),
          const SizedBox(height: 10),
          _Field(ctrl: team2Ctrl, hint: 'Team name  e.g. Australia'),
          const SizedBox(height: 8),
          _Field(
              ctrl: team2LogoCtrl,
              hint: 'Logo URL (optional)',
              icon: Icons.image_rounded),
          const SizedBox(height: 8),
          _ColorField(ctrl: team2ColorCtrl, label: 'Team color'),
          const SizedBox(height: 28),

          // ── Settings ─────────────────────────────────────
          _SectionLabel('SETTINGS'),
          const SizedBox(height: 12),

          // Show votes toggle
          _ToggleRow(
            label: 'Show vote %',
            sublabel: 'Show live percentages to users before they vote',
            value: showVotes,
            onChanged: onShowVotesChanged,
          ),
          const SizedBox(height: 28),

          // ── Danger zone ──────────────────────────────────
          _SectionLabel('DANGER ZONE'),
          const SizedBox(height: 10),
          _ResetBtn(resetting: resetting, onTap: onResetVotes),
          const SizedBox(height: 6),
          Text(
            'Resets all votes to 0. Cannot be undone.',
            style: TextStyle(color: _textMuted, fontSize: 11),
          ),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════
//  STATS PANEL (right side)
// ════════════════════════════════════════════════════════════
class _StatsPanel extends StatelessWidget {
  final AdminPoll poll;
  final Color team1Color, team2Color;

  const _StatsPanel({
    required this.poll,
    required this.team1Color,
    required this.team2Color,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Live vote counts ─────────────────────────────
          _SectionLabel('LIVE RESULTS'),
          const SizedBox(height: 16),

          // Vote bars
          _VoteBar(
            team: poll.team1,
            votes: poll.team1Votes,
            total: poll.totalVotes,
            color: team1Color,
            logo: poll.team1Logo,
          ),
          const SizedBox(height: 12),
          _VoteBar(
            team: poll.team2,
            votes: poll.team2Votes,
            total: poll.totalVotes,
            color: team2Color,
            logo: poll.team2Logo,
          ),

          const SizedBox(height: 20),

          // Total votes
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: _surface,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: _border),
            ),
            child: Row(
              children: [
                const Icon(Icons.people_rounded,
                    color: _textSecondary, size: 16),
                const SizedBox(width: 10),
                const Text('Total votes',
                    style: TextStyle(color: _textSecondary, fontSize: 13)),
                const Spacer(),
                Text(
                  '${poll.totalVotes}',
                  style: const TextStyle(
                      color: _textPrimary,
                      fontSize: 20,
                      fontWeight: FontWeight.w800),
                ),
              ],
            ),
          ),

          const SizedBox(height: 28),

          // ── Preview card ─────────────────────────────────
          _SectionLabel('APP PREVIEW'),
          const SizedBox(height: 16),
          _PreviewCard(
            poll: poll,
            t1Color: team1Color,
            t2Color: team2Color,
          ),

          // Poll status info
          const SizedBox(height: 20),
          _InfoRow(
              label: 'Poll visible to users',
              value: poll.showPoll ? 'Yes' : 'No',
              valueColor: poll.showPoll ? Colors.greenAccent : _textSecondary),
          const SizedBox(height: 8),
          _InfoRow(
              label: 'Vote % visible before voting',
              value: poll.showVotes ? 'Yes' : 'No',
              valueColor: poll.showVotes ? Colors.greenAccent : _textSecondary),
          const SizedBox(height: 8),
          _InfoRow(
              label: 'Poll ID',
              value: poll.pollId.isEmpty ? '—' : poll.pollId,
              valueColor: _textMuted),
        ],
      ),
    );
  }
}

// ── Vote bar ──────────────────────────────────────────────
class _VoteBar extends StatelessWidget {
  final String team, logo;
  final int votes, total;
  final Color color;

  const _VoteBar({
    required this.team,
    required this.votes,
    required this.total,
    required this.color,
    required this.logo,
  });

  @override
  Widget build(BuildContext context) {
    final pct = total == 0 ? 0.0 : votes / total;
    final pctLabel = '${(pct * 100).toStringAsFixed(1)}%';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Logo
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _surface2,
                  border: Border.all(color: _border2),
                ),
                child: ClipOval(
                  child: logo.isNotEmpty
                      ? Image.network(logo,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => _LogoFb(name: team))
                      : _LogoFb(name: team),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(team.isEmpty ? 'Team' : team,
                    style: const TextStyle(
                        color: _textPrimary,
                        fontSize: 13,
                        fontWeight: FontWeight.w600)),
              ),
              Text(pctLabel,
                  style: TextStyle(
                      color: color, fontSize: 15, fontWeight: FontWeight.w800)),
              const SizedBox(width: 10),
              Text('$votes votes',
                  style: const TextStyle(color: _textSecondary, fontSize: 11)),
            ],
          ),
          const SizedBox(height: 10),
          // Progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: pct,
              backgroundColor: _surface2,
              valueColor: AlwaysStoppedAnimation(color),
              minHeight: 5,
            ),
          ),
        ],
      ),
    );
  }
}

// ── App preview card ──────────────────────────────────────
class _PreviewCard extends StatelessWidget {
  final AdminPoll poll;
  final Color t1Color, t2Color;

  const _PreviewCard({
    required this.poll,
    required this.t1Color,
    required this.t2Color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0F0F0F),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: Column(
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: Row(
              children: [
                Container(
                    width: 3,
                    height: 14,
                    margin: const EdgeInsets.only(right: 10),
                    decoration: BoxDecoration(
                        color: Colors.redAccent,
                        borderRadius: BorderRadius.circular(2))),
                const Text('Who will win?',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w800)),
                const Spacer(),
                if (poll.showVotes && poll.totalVotes > 0)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.06),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text('${poll.totalVotes} votes',
                        style: TextStyle(
                            color: Colors.white.withOpacity(0.4),
                            fontSize: 10)),
                  ),
              ],
            ),
          ),

          // Teams
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
            child: Row(
              children: [
                Expanded(
                    child: _PreviewTeam(
                  name: poll.team1.isEmpty ? 'Team 1' : poll.team1,
                  logo: poll.team1Logo,
                  color: t1Color,
                )),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.04),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white.withOpacity(0.08)),
                    ),
                    child: const Center(
                      child: Text('VS',
                          style: TextStyle(
                              color: Colors.white24,
                              fontSize: 7,
                              fontWeight: FontWeight.w900)),
                    ),
                  ),
                ),
                Expanded(
                    child: _PreviewTeam(
                  name: poll.team2.isEmpty ? 'Team 2' : poll.team2,
                  logo: poll.team2Logo,
                  color: t2Color,
                )),
              ],
            ),
          ),

          // Bar (always shown in preview)
          if (poll.team1.isNotEmpty || poll.team2.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 4),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${poll.team1Percent.toStringAsFixed(0)}%',
                        style: TextStyle(
                            color: t1Color,
                            fontSize: 13,
                            fontWeight: FontWeight.w800),
                      ),
                      Text(
                        '${poll.team2Percent.toStringAsFixed(0)}%',
                        style: TextStyle(
                            color: t2Color,
                            fontSize: 13,
                            fontWeight: FontWeight.w800),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: SizedBox(
                      height: 5,
                      child: Row(
                        children: [
                          Flexible(
                            flex: poll.team1Percent.round().clamp(1, 99),
                            child: Container(color: t1Color),
                          ),
                          Container(width: 2, color: const Color(0xFF050505)),
                          Flexible(
                            flex: poll.team2Percent.round().clamp(1, 99),
                            child: Container(color: t2Color),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _PreviewTeam extends StatelessWidget {
  final String name, logo;
  final Color color;
  const _PreviewTeam(
      {required this.name, required this.logo, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white.withOpacity(0.06),
            border: Border.all(color: color.withOpacity(0.3)),
          ),
          child: ClipOval(
            child: logo.isNotEmpty
                ? Image.network(logo,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => _LogoFb(name: name))
                : _LogoFb(name: name),
          ),
        ),
        const SizedBox(height: 8),
        Text(name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(
                color: color, fontSize: 11, fontWeight: FontWeight.w700)),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: color.withOpacity(0.25)),
          ),
          child: Text('Tap to vote',
              style: TextStyle(
                  color: color.withOpacity(0.7),
                  fontSize: 8,
                  fontWeight: FontWeight.w700)),
        ),
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label, value;
  final Color valueColor;
  const _InfoRow({
    required this.label,
    required this.value,
    required this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(label,
            style: const TextStyle(color: _textSecondary, fontSize: 12)),
        const Spacer(),
        Text(value,
            style: TextStyle(
                color: valueColor, fontSize: 12, fontWeight: FontWeight.w600)),
      ],
    );
  }
}

// ════════════════════════════════════════════════════════════
//  CONFIRM DIALOG
// ════════════════════════════════════════════════════════════
class _ConfirmResetDialog extends StatelessWidget {
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
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: Colors.redAccent.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: const Icon(Icons.refresh_rounded,
                      color: Colors.redAccent, size: 18),
                ),
                const SizedBox(width: 12),
                const Text('Reset Votes',
                    style: TextStyle(
                        color: _textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w700)),
              ],
            ),
            const SizedBox(height: 16),
            const Text(
              'This will reset all votes to 0. Users who already voted will be able to vote again. This cannot be undone.',
              style:
                  TextStyle(color: _textSecondary, fontSize: 13, height: 1.6),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: _OutlineBtn(
                    label: 'Cancel',
                    onTap: () => Navigator.pop(context, false),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _RedBtn(
                    label: 'Reset',
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

// ════════════════════════════════════════════════════════════
//  SHARED FORM WIDGETS
// ════════════════════════════════════════════════════════════
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

class _Field extends StatelessWidget {
  final TextEditingController ctrl;
  final String hint;
  final IconData? icon;
  const _Field({required this.ctrl, required this.hint, this.icon});

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: ctrl,
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

class _ColorField extends StatelessWidget {
  final TextEditingController ctrl;
  final String label;
  const _ColorField({required this.ctrl, required this.label});

  Color get _preview {
    try {
      return Color(int.parse('FF${ctrl.text.replaceAll('#', '')}', radix: 16));
    } catch (_) {
      return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return StatefulBuilder(
      builder: (_, refresh) {
        ctrl.addListener(() => refresh(() {}));
        return TextField(
          controller: ctrl,
          style: const TextStyle(color: _textPrimary, fontSize: 13),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[#0-9a-fA-F]')),
            LengthLimitingTextInputFormatter(7),
          ],
          decoration: InputDecoration(
            hintText: 'Hex color  e.g. #CC0000',
            hintStyle: const TextStyle(color: _textMuted, fontSize: 13),
            prefixIcon: Padding(
              padding: const EdgeInsets.all(10),
              child: Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  color: _preview,
                  borderRadius: BorderRadius.circular(5),
                  border: Border.all(color: Colors.white.withOpacity(0.1)),
                ),
              ),
            ),
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
      },
    );
  }
}

class _ToggleRow extends StatelessWidget {
  final String label, sublabel;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _ToggleRow({
    required this.label,
    required this.sublabel,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _border),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: const TextStyle(
                        color: _textPrimary,
                        fontSize: 13,
                        fontWeight: FontWeight.w600)),
                const SizedBox(height: 3),
                Text(sublabel,
                    style:
                        const TextStyle(color: _textSecondary, fontSize: 11)),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: Colors.redAccent,
            trackColor: MaterialStateProperty.resolveWith((s) =>
                s.contains(MaterialState.selected)
                    ? Colors.redAccent.withOpacity(0.3)
                    : _surface2),
          ),
        ],
      ),
    );
  }
}

class _StatusBanner extends StatelessWidget {
  final String type;
  const _StatusBanner({required this.type});

  @override
  Widget build(BuildContext context) {
    final isSuccess = type == 'success';
    final color = isSuccess ? Colors.greenAccent : Colors.redAccent;
    final msg = isSuccess ? 'Saved successfully ✓' : 'Error — check all fields';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
      color: color.withOpacity(0.08),
      child: Text(msg,
          style: TextStyle(
              color: color, fontSize: 12, fontWeight: FontWeight.w600)),
    );
  }
}

// ── Buttons ───────────────────────────────────────────────
class _QuickToggle extends StatefulWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;
  const _QuickToggle(
      {required this.label, required this.active, required this.onTap});
  @override
  State<_QuickToggle> createState() => _QuickToggleState();
}

class _QuickToggleState extends State<_QuickToggle> {
  bool _h = false;
  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _h = true),
      onExit: (_) => setState(() => _h = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 130),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: _h ? _surface3 : _surface2,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: _h ? _border2 : _border),
          ),
          child: Text(widget.label,
              style: const TextStyle(
                  color: _textPrimary,
                  fontSize: 12,
                  fontWeight: FontWeight.w600)),
        ),
      ),
    );
  }
}

class _SaveBtn extends StatefulWidget {
  final bool saving;
  final VoidCallback onTap;
  const _SaveBtn({required this.saving, required this.onTap});
  @override
  State<_SaveBtn> createState() => _SaveBtnState();
}

class _SaveBtnState extends State<_SaveBtn> {
  bool _h = false;
  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _h = true),
      onExit: (_) => setState(() => _h = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.saving ? null : widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 130),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
          decoration: BoxDecoration(
            color: _h ? Colors.redAccent.withOpacity(0.85) : Colors.redAccent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.saving)
                const SizedBox(
                  width: 12,
                  height: 12,
                  child: CircularProgressIndicator(
                      color: Colors.white, strokeWidth: 1.5),
                )
              else
                const Icon(Icons.save_rounded, color: Colors.white, size: 15),
              const SizedBox(width: 7),
              Text(widget.saving ? 'Saving…' : 'Save & Publish',
                  style: const TextStyle(
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

class _ResetBtn extends StatefulWidget {
  final bool resetting;
  final VoidCallback onTap;
  const _ResetBtn({required this.resetting, required this.onTap});
  @override
  State<_ResetBtn> createState() => _ResetBtnState();
}

class _ResetBtnState extends State<_ResetBtn> {
  bool _h = false;
  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _h = true),
      onExit: (_) => setState(() => _h = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.resetting ? null : widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 130),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: _h ? Colors.redAccent.withOpacity(0.1) : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: _h ? Colors.redAccent.withOpacity(0.4) : _border,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.refresh_rounded,
                  color: Colors.redAccent, size: 15),
              const SizedBox(width: 8),
              Text(widget.resetting ? 'Resetting…' : 'Reset All Votes',
                  style: const TextStyle(
                      color: Colors.redAccent,
                      fontSize: 13,
                      fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ),
    );
  }
}

class _OutlineBtn extends StatefulWidget {
  final String label;
  final VoidCallback onTap;
  const _OutlineBtn({required this.label, required this.onTap});
  @override
  State<_OutlineBtn> createState() => _OutlineBtnState();
}

class _OutlineBtnState extends State<_OutlineBtn> {
  bool _h = false;
  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _h = true),
      onExit: (_) => setState(() => _h = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 130),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: _h ? _surface2 : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: _h ? _border2 : _border),
          ),
          child: Center(
            child: Text(widget.label,
                style: const TextStyle(
                    color: _textSecondary,
                    fontSize: 13,
                    fontWeight: FontWeight.w500)),
          ),
        ),
      ),
    );
  }
}

class _RedBtn extends StatefulWidget {
  final String label;
  final VoidCallback onTap;
  const _RedBtn({required this.label, required this.onTap});
  @override
  State<_RedBtn> createState() => _RedBtnState();
}

class _RedBtnState extends State<_RedBtn> {
  bool _h = false;
  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _h = true),
      onExit: (_) => setState(() => _h = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 130),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: _h ? Colors.redAccent.withOpacity(0.82) : Colors.redAccent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Center(
            child: Text(widget.label,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w700)),
          ),
        ),
      ),
    );
  }
}

class _LogoFb extends StatelessWidget {
  final String name;
  const _LogoFb({required this.name});
  @override
  Widget build(BuildContext context) => Container(
        color: Colors.white.withOpacity(0.05),
        child: Center(
          child: Text(
            name.isNotEmpty ? name[0].toUpperCase() : '?',
            style: const TextStyle(
                color: Colors.white38,
                fontSize: 10,
                fontWeight: FontWeight.w800),
          ),
        ),
      );
}
