import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cricket_admin/services/featured_match_service.dart';
import 'package:flutter/material.dart';

// ── Theme constants ────────────────────────────────────────
const _bg = Color(0xFF0D0D0D);
const _surface = Color(0xFF141414);
const _surface2 = Color(0xFF1A1A1A);
const _surface3 = Color(0xFF202020);
const _border = Color(0xFF232323);
const _textPrimary = Color(0xFFE8E8E8);
const _textSecondary = Color(0xFF666666);
const _textMuted = Color(0xFF444444);

class TossScreen extends StatefulWidget {
  const TossScreen({super.key});

  @override
  State<TossScreen> createState() => _TossScreenState();
}

class _TossScreenState extends State<TossScreen> {
  int _step = 0;

  String? _tossWinner;
  String? _decision;
  String? _striker;
  String? _nonStriker;
  String? _openingBowler;

  bool _saving = false;
  String? _error;

  String? get _battingTeam {
    if (_tossWinner == null || _decision == null) return null;
    return _decision == 'bat'
        ? _tossWinner
        : (_tossWinner == 'teamA' ? 'teamB' : 'teamA');
  }

  String? get _bowlingTeam {
    final bt = _battingTeam;
    if (bt == null) return null;
    return bt == 'teamA' ? 'teamB' : 'teamA';
  }

  // ── Reset: clears local state AND wipes toss from Firestore ──
  Future<void> _handleReset() async {
    await FeaturedMatchService.clearToss();

    if (!mounted) return;
    setState(() {
      _step = 0;
      _tossWinner = null;
      _decision = null;
      _striker = null;
      _nonStriker = null;
      _openingBowler = null;
      _error = null;
    });
  }

  // ── Save toss ONLY when "Next: Pick Openers" is tapped ───
  Future<void> _saveTossAndProceed(
    Map<String, dynamic> teamA,
    Map<String, dynamic> teamB,
  ) async {
    if (_saving) return;
    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      await FeaturedMatchService.saveToss(
        wonBy: _tossWinner!,
        decision: _decision!,
      );
      if (mounted) setState(() => _step = 1);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  // ── Final confirm: init scores + go live ─────────────────
  Future<void> _confirmToss(
    Map<String, dynamic> teamA,
    Map<String, dynamic> teamB,
  ) async {
    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      await FeaturedMatchService.initScores();
      await FeaturedMatchService.initPlayerStats();
      await FeaturedMatchService.setLiveMatchState(
        striker: _striker!,
        nonStriker: _nonStriker!,
        currentBowler: _openingBowler!,
        battingTeam: _battingTeam!,
        bowlingTeam: _bowlingTeam!,
        innings: 1,
      );
      await FeaturedMatchService.updateStatus('live');

      if (!mounted) return;
      setState(() => _step = 3);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
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

          final data = snap.hasData && snap.data!.exists
              ? snap.data!.data() as Map<String, dynamic>
              : <String, dynamic>{};

          final teams = data['teams'] as Map<String, dynamic>? ?? {};
          final tA = teams['teamA'] as Map<String, dynamic>?;
          final tB = teams['teamB'] as Map<String, dynamic>?;
          final meta = data['meta'] as Map<String, dynamic>? ?? {};
          final existingToss = data['toss'] as Map<String, dynamic>?;
          final existingLive = data['liveMatch'] as Map<String, dynamic>?;

          final bool teamsReady = tA != null && tB != null;

          // ── FIX: show reset banner whenever toss exists,
          //         regardless of whether liveMatch exists too ──
          final bool tossExists = existingToss != null;
          final bool alreadySetup =
              existingToss != null && existingLive != null;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _Header(
                  matchTitle: meta['title'] as String? ?? '',
                  alreadySetup: alreadySetup,
                ),
                const SizedBox(height: 28),

                // Show banner (with Reset button) as soon as toss data exists
                if (tossExists) ...[
                  _AlreadySetupBanner(
                    toss: existingToss,
                    live: existingLive,
                    teamA: tA,
                    teamB: tB,
                    alreadySetup: alreadySetup,
                    onReset: _handleReset,
                  ),
                  const SizedBox(height: 24),
                ],

                if (!teamsReady) ...[
                  _NoTeamsBanner(),
                ] else ...[
                  _StepIndicator(currentStep: _step),
                  const SizedBox(height: 28),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 280),
                    transitionBuilder: (child, anim) => FadeTransition(
                      opacity: anim,
                      child: SlideTransition(
                        position: Tween<Offset>(
                          begin: const Offset(0.04, 0),
                          end: Offset.zero,
                        ).animate(anim),
                        child: child,
                      ),
                    ),
                    child: _step == 0
                        ? _TossStep(
                            key: const ValueKey(0),
                            teamA: tA,
                            teamB: tB,
                            tossWinner: _tossWinner,
                            decision: _decision,
                            onWinnerChanged: (v) =>
                                setState(() => _tossWinner = v),
                            onDecisionChanged: (v) =>
                                setState(() => _decision = v),
                            saving: _saving,
                            onNext: (_tossWinner != null && _decision != null)
                                ? () => _saveTossAndProceed(tA, tB)
                                : null,
                          )
                        : _step == 1
                            ? _OpenersStep(
                                key: const ValueKey(1),
                                teamA: tA,
                                teamB: tB,
                                battingTeam: _battingTeam!,
                                bowlingTeam: _bowlingTeam!,
                                striker: _striker,
                                nonStriker: _nonStriker,
                                openingBowler: _openingBowler,
                                onStrikerChanged: (v) =>
                                    setState(() => _striker = v),
                                onNonStrikerChanged: (v) =>
                                    setState(() => _nonStriker = v),
                                onBowlerChanged: (v) =>
                                    setState(() => _openingBowler = v),
                                onBack: () => setState(() => _step = 0),
                                onNext: (_striker != null &&
                                        _nonStriker != null &&
                                        _openingBowler != null &&
                                        _striker != _nonStriker)
                                    ? () => setState(() => _step = 2)
                                    : null,
                              )
                            : _ConfirmStep(
                                key: const ValueKey(2),
                                teamA: tA,
                                teamB: tB,
                                tossWinner: _tossWinner!,
                                decision: _decision!,
                                battingTeam: _battingTeam!,
                                bowlingTeam: _bowlingTeam!,
                                striker: _striker!,
                                nonStriker: _nonStriker!,
                                openingBowler: _openingBowler!,
                                saving: _saving,
                                error: _error,
                                onBack: () => setState(() => _step = 1),
                                onConfirm: () => _confirmToss(tA, tB),
                              ),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

// ── Header ─────────────────────────────────────────────────
class _Header extends StatelessWidget {
  final String matchTitle;
  final bool alreadySetup;
  const _Header({required this.matchTitle, required this.alreadySetup});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Toss & Openers',
                style: TextStyle(
                    color: _textPrimary,
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.4)),
            const SizedBox(height: 3),
            Text(
              matchTitle.isNotEmpty
                  ? matchTitle
                  : 'Set up toss and opening players',
              style: const TextStyle(color: _textSecondary, fontSize: 13),
            ),
          ],
        ),
        const Spacer(),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: alreadySetup
                ? Colors.greenAccent.withOpacity(0.1)
                : Colors.redAccent.withOpacity(0.08),
            borderRadius: BorderRadius.circular(7),
            border: Border.all(
              color: alreadySetup
                  ? Colors.greenAccent.withOpacity(0.25)
                  : Colors.redAccent.withOpacity(0.2),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  color: alreadySetup ? Colors.greenAccent : Colors.redAccent,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                alreadySetup ? 'Match Live' : 'Not Started',
                style: TextStyle(
                    color: alreadySetup ? Colors.greenAccent : Colors.redAccent,
                    fontSize: 11,
                    fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Already setup banner ───────────────────────────────────
class _AlreadySetupBanner extends StatelessWidget {
  final Map<String, dynamic> toss;
  final Map<String, dynamic>? live;
  final Map<String, dynamic>? teamA;
  final Map<String, dynamic>? teamB;
  final bool alreadySetup;
  final VoidCallback onReset;

  const _AlreadySetupBanner({
    required this.toss,
    required this.live,
    required this.teamA,
    required this.teamB,
    required this.alreadySetup,
    required this.onReset,
  });

  @override
  Widget build(BuildContext context) {
    final wonBy = toss['wonBy'] as String? ?? '';
    final decision = toss['decision'] as String? ?? '';

    final wonTeam = wonBy == 'teamA' ? teamA : teamB;
    final wonName = wonTeam?['name'] as String? ?? wonBy;

    final battingFirst =
        decision == 'bat' ? wonBy : (wonBy == 'teamA' ? 'teamB' : 'teamA');
    final batTeam = battingFirst == 'teamA' ? teamA : teamB;
    final batName = batTeam?['name'] as String? ?? battingFirst;

    // Choose color/icon based on whether match is fully live or just toss saved
    final Color bannerColor = alreadySetup ? Colors.greenAccent : Colors.amber;
    final IconData bannerIcon =
        alreadySetup ? Icons.check_circle_rounded : Icons.pending_rounded;
    final String statusLine = alreadySetup
        ? '$batName batting first · Match is Live'
        : '$batName batting first · Openers not yet set';

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: bannerColor.withOpacity(0.04),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: bannerColor.withOpacity(0.18)),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: bannerColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(bannerIcon, color: bannerColor, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$wonName won the toss and elected to $decision',
                  style: const TextStyle(
                      color: _textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 3),
                Text(
                  statusLine,
                  style: const TextStyle(color: _textSecondary, fontSize: 12),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          _ResetButton(onTap: onReset),
        ],
      ),
    );
  }
}

// ── Reset button ───────────────────────────────────────────
class _ResetButton extends StatefulWidget {
  final VoidCallback onTap;
  const _ResetButton({required this.onTap});

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
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: _hovered ? _surface3 : _surface2,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: _border),
          ),
          child: const Text('Reset Toss',
              style: TextStyle(
                  color: _textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w500)),
        ),
      ),
    );
  }
}

// ── No teams banner ────────────────────────────────────────
class _NoTeamsBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _border),
      ),
      child: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: Colors.redAccent.withOpacity(0.08),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.warning_amber_rounded,
                color: Colors.redAccent, size: 26),
          ),
          const SizedBox(height: 16),
          const Text('Teams not assigned',
              style: TextStyle(
                  color: _textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          const Text(
            'Go to the Teams screen and assign both Team A and Team B\nbefore setting up the toss.',
            style: TextStyle(color: _textSecondary, fontSize: 13, height: 1.6),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

// ── Step indicator ─────────────────────────────────────────
class _StepIndicator extends StatelessWidget {
  final int currentStep;
  const _StepIndicator({required this.currentStep});

  @override
  Widget build(BuildContext context) {
    final steps = ['Toss', 'Openers', 'Confirm'];
    return Row(
      children: List.generate(steps.length * 2 - 1, (i) {
        if (i.isOdd) {
          final stepIndex = i ~/ 2;
          final isDone = currentStep > stepIndex;
          return Expanded(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              height: 1,
              color: isDone
                  ? Colors.redAccent.withOpacity(0.5)
                  : const Color(0xFF1E1E1E),
            ),
          );
        }

        final stepIndex = i ~/ 2;
        final isDone = currentStep > stepIndex;
        final isActive = currentStep == stepIndex;

        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: isDone
                    ? Colors.redAccent
                    : isActive
                        ? Colors.redAccent.withOpacity(0.15)
                        : _surface2,
                shape: BoxShape.circle,
                border: Border.all(
                  color: isDone || isActive ? Colors.redAccent : _border,
                  width: 1.5,
                ),
              ),
              child: Center(
                child: isDone
                    ? const Icon(Icons.check_rounded,
                        color: Colors.white, size: 13)
                    : Text(
                        '${stepIndex + 1}',
                        style: TextStyle(
                          color: isActive ? Colors.redAccent : _textMuted,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              steps[stepIndex],
              style: TextStyle(
                color: isActive
                    ? _textPrimary
                    : isDone
                        ? _textSecondary
                        : _textMuted,
                fontSize: 12,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ],
        );
      }),
    );
  }
}

// ════════════════════════════════════════════════════════════
//  STEP 0 — TOSS
// ════════════════════════════════════════════════════════════
class _TossStep extends StatelessWidget {
  final Map<String, dynamic> teamA, teamB;
  final String? tossWinner, decision;
  final ValueChanged<String> onWinnerChanged, onDecisionChanged;
  final VoidCallback? onNext;
  final bool saving;

  const _TossStep({
    super.key,
    required this.teamA,
    required this.teamB,
    required this.tossWinner,
    required this.decision,
    required this.onWinnerChanged,
    required this.onDecisionChanged,
    required this.onNext,
    required this.saving,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionLabel(
          icon: Icons.monetization_on_rounded,
          label: 'Who won the toss?',
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: _TeamSelectCard(
                team: teamA,
                teamKey: 'teamA',
                isSelected: tossWinner == 'teamA',
                onTap: () => onWinnerChanged('teamA'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _TeamSelectCard(
                team: teamB,
                teamKey: 'teamB',
                isSelected: tossWinner == 'teamB',
                onTap: () => onWinnerChanged('teamB'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 28),
        _SectionLabel(
          icon: Icons.sports_cricket_rounded,
          label: 'Elected to...',
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: _DecisionCard(
                label: 'Bat',
                icon: Icons.sports_cricket_rounded,
                description: 'Chose to bat first',
                isSelected: decision == 'bat',
                onTap: () => onDecisionChanged('bat'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _DecisionCard(
                label: 'Bowl',
                icon: Icons.trip_origin_rounded,
                description: 'Chose to field first',
                isSelected: decision == 'bowl',
                onTap: () => onDecisionChanged('bowl'),
              ),
            ),
          ],
        ),
        if (tossWinner != null && decision != null) ...[
          const SizedBox(height: 20),
          _TossSummaryBadge(
            teamA: teamA,
            teamB: teamB,
            tossWinner: tossWinner!,
            decision: decision!,
          ),
        ],
        const SizedBox(height: 28),
        _NextButton(
          label: saving ? 'Saving Toss...' : 'Next: Pick Openers',
          enabled: onNext != null && !saving,
          loading: saving,
          onTap: onNext ?? () {},
        ),
      ],
    );
  }
}

// ── Toss summary badge ─────────────────────────────────────
class _TossSummaryBadge extends StatelessWidget {
  final Map<String, dynamic> teamA, teamB;
  final String tossWinner, decision;

  const _TossSummaryBadge({
    required this.teamA,
    required this.teamB,
    required this.tossWinner,
    required this.decision,
  });

  @override
  Widget build(BuildContext context) {
    final wonTeam = tossWinner == 'teamA' ? teamA : teamB;
    final wonName = wonTeam['name'] as String? ?? tossWinner;

    final battingFirst = decision == 'bat'
        ? tossWinner
        : (tossWinner == 'teamA' ? 'teamB' : 'teamA');
    final batTeam = battingFirst == 'teamA' ? teamA : teamB;
    final batName = batTeam['name'] as String? ?? battingFirst;
    final bowlTeam = battingFirst == 'teamA' ? teamB : teamA;
    final bowlName = bowlTeam['name'] as String? ?? '';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.redAccent.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.redAccent.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline_rounded,
              color: Colors.redAccent, size: 15),
          const SizedBox(width: 10),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: const TextStyle(
                    color: _textSecondary, fontSize: 13, height: 1.5),
                children: [
                  TextSpan(
                      text: wonName,
                      style: const TextStyle(
                          color: _textPrimary, fontWeight: FontWeight.w600)),
                  const TextSpan(text: ' won the toss · '),
                  TextSpan(
                      text: batName,
                      style: const TextStyle(
                          color: _textPrimary, fontWeight: FontWeight.w600)),
                  const TextSpan(text: ' bats first · '),
                  TextSpan(
                      text: bowlName,
                      style: const TextStyle(
                          color: _textPrimary, fontWeight: FontWeight.w600)),
                  const TextSpan(text: ' fields'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════
//  STEP 1 — OPENERS
// ════════════════════════════════════════════════════════════
class _OpenersStep extends StatelessWidget {
  final Map<String, dynamic> teamA, teamB;
  final String battingTeam, bowlingTeam;
  final String? striker, nonStriker, openingBowler;
  final ValueChanged<String> onStrikerChanged;
  final ValueChanged<String> onNonStrikerChanged;
  final ValueChanged<String> onBowlerChanged;
  final VoidCallback onBack;
  final VoidCallback? onNext;

  const _OpenersStep({
    super.key,
    required this.teamA,
    required this.teamB,
    required this.battingTeam,
    required this.bowlingTeam,
    required this.striker,
    required this.nonStriker,
    required this.openingBowler,
    required this.onStrikerChanged,
    required this.onNonStrikerChanged,
    required this.onBowlerChanged,
    required this.onBack,
    required this.onNext,
  });

  List<Map<String, dynamic>> _playersOf(String teamKey) {
    final team = teamKey == 'teamA' ? teamA : teamB;
    return List<Map<String, dynamic>>.from(
      (team['players'] as List<dynamic>? ?? [])
          .map((p) => Map<String, dynamic>.from(p as Map)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final batTeam = battingTeam == 'teamA' ? teamA : teamB;
    final bowlTeam = bowlingTeam == 'teamA' ? teamA : teamB;
    final batPlayers = _playersOf(battingTeam);
    final bowlPlayers = _playersOf(bowlingTeam);
    final batName = batTeam['name'] as String? ?? battingTeam;
    final bowlName = bowlTeam['name'] as String? ?? bowlingTeam;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _TeamMiniTag(team: batTeam, teamKey: battingTeam),
            const SizedBox(width: 10),
            Text('$batName — Opening Batsmen',
                style: const TextStyle(
                    color: _textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w700)),
          ],
        ),
        const SizedBox(height: 14),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _PlayerPickerCard(
                label: 'Striker',
                sublabel: 'Faces the first ball',
                icon: Icons.sports_cricket_rounded,
                players: batPlayers,
                selectedId: striker,
                disabledId: nonStriker,
                onChanged: onStrikerChanged,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _PlayerPickerCard(
                label: 'Non-Striker',
                sublabel: 'At the other end',
                icon: Icons.person_rounded,
                players: batPlayers,
                selectedId: nonStriker,
                disabledId: striker,
                onChanged: onNonStrikerChanged,
              ),
            ),
          ],
        ),
        const SizedBox(height: 28),
        Row(
          children: [
            _TeamMiniTag(team: bowlTeam, teamKey: bowlingTeam),
            const SizedBox(width: 10),
            Text('$bowlName — Opening Bowler',
                style: const TextStyle(
                    color: _textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w700)),
          ],
        ),
        const SizedBox(height: 14),
        SizedBox(
          width: double.infinity,
          child: _PlayerPickerCard(
            label: 'Opening Bowler',
            sublabel: 'Bowls the first over',
            icon: Icons.trip_origin_rounded,
            players: bowlPlayers,
            selectedId: openingBowler,
            onChanged: onBowlerChanged,
          ),
        ),
        if (striker != null && nonStriker != null && striker == nonStriker) ...[
          const SizedBox(height: 14),
          _ErrorBanner(
              message: 'Striker and non-striker must be different players.'),
        ],
        const SizedBox(height: 28),
        Row(
          children: [
            _BackButton(onTap: onBack),
            const SizedBox(width: 12),
            Expanded(
              child: _NextButton(
                label: 'Next: Confirm Setup',
                enabled: onNext != null,
                onTap: onNext ?? () {},
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// ════════════════════════════════════════════════════════════
//  STEP 2 — CONFIRM
// ════════════════════════════════════════════════════════════
class _ConfirmStep extends StatelessWidget {
  final Map<String, dynamic> teamA, teamB;
  final String tossWinner, decision, battingTeam, bowlingTeam;
  final String striker, nonStriker, openingBowler;
  final bool saving;
  final String? error;
  final VoidCallback onBack;
  final VoidCallback onConfirm;

  const _ConfirmStep({
    super.key,
    required this.teamA,
    required this.teamB,
    required this.tossWinner,
    required this.decision,
    required this.battingTeam,
    required this.bowlingTeam,
    required this.striker,
    required this.nonStriker,
    required this.openingBowler,
    required this.saving,
    required this.error,
    required this.onBack,
    required this.onConfirm,
  });

  Map<String, dynamic>? _findPlayer(
      Map<String, dynamic> team, String playerId) {
    final players = team['players'] as List<dynamic>? ?? [];
    try {
      return Map<String, dynamic>.from(
          players.firstWhere((p) => p['id'] == playerId) as Map);
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final batTeam = battingTeam == 'teamA' ? teamA : teamB;
    final bowlTeam = bowlingTeam == 'teamA' ? teamA : teamB;
    final wonTeam = tossWinner == 'teamA' ? teamA : teamB;

    final strikerPlayer = _findPlayer(batTeam, striker);
    final nonStrikerPlayer = _findPlayer(batTeam, nonStriker);
    final bowlerPlayer = _findPlayer(bowlTeam, openingBowler);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: _surface,
            borderRadius: BorderRadius.circular(16),
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
                        Icon(Icons.checklist_rounded,
                            color: Colors.redAccent, size: 10),
                        SizedBox(width: 4),
                        Text('MATCH SUMMARY',
                            style: TextStyle(
                                color: Colors.redAccent,
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.5)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              _ConfirmRow(
                icon: Icons.monetization_on_rounded,
                label: 'Toss',
                value: '${wonTeam['name']} won · elected to $decision',
              ),
              const SizedBox(height: 14),
              Divider(color: _border, height: 1),
              const SizedBox(height: 14),
              _ConfirmRow(
                icon: Icons.shield_rounded,
                label: 'Batting First',
                value: batTeam['name'] as String? ?? battingTeam,
              ),
              const SizedBox(height: 10),
              _ConfirmRow(
                icon: Icons.trip_origin_rounded,
                label: 'Bowling First',
                value: bowlTeam['name'] as String? ?? bowlingTeam,
              ),
              const SizedBox(height: 14),
              Divider(color: _border, height: 1),
              const SizedBox(height: 14),
              _ConfirmRow(
                icon: Icons.sports_cricket_rounded,
                label: 'Striker',
                value: strikerPlayer?['name'] ?? striker,
                chip: strikerPlayer?['role'] as String?,
              ),
              const SizedBox(height: 10),
              _ConfirmRow(
                icon: Icons.person_rounded,
                label: 'Non-Striker',
                value: nonStrikerPlayer?['name'] ?? nonStriker,
                chip: nonStrikerPlayer?['role'] as String?,
              ),
              const SizedBox(height: 10),
              _ConfirmRow(
                icon: Icons.trip_origin_rounded,
                label: 'Opening Bowler',
                value: bowlerPlayer?['name'] ?? openingBowler,
                chip: bowlerPlayer?['role'] as String?,
              ),
            ],
          ),
        ),
        if (error != null) ...[
          const SizedBox(height: 16),
          _ErrorBanner(message: error!),
        ],
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.amber.withOpacity(0.05),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.amber.withOpacity(0.2)),
          ),
          child: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.amber, size: 14),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'This will reset all player stats and scores to zero and set the match status to Live.',
                  style:
                      TextStyle(color: Colors.amber, fontSize: 12, height: 1.5),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        Row(
          children: [
            _BackButton(onTap: saving ? () {} : onBack),
            const SizedBox(width: 12),
            Expanded(
              child: _GoLiveButton(saving: saving, onTap: onConfirm),
            ),
          ],
        ),
      ],
    );
  }
}

// ── Confirm row ────────────────────────────────────────────
class _ConfirmRow extends StatelessWidget {
  final IconData icon;
  final String label, value;
  final String? chip;

  const _ConfirmRow({
    required this.icon,
    required this.label,
    required this.value,
    this.chip,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: _textMuted, size: 14),
        const SizedBox(width: 10),
        SizedBox(
          width: 110,
          child: Text(label,
              style: const TextStyle(color: _textSecondary, fontSize: 12)),
        ),
        Expanded(
          child: Text(value,
              style: const TextStyle(
                  color: _textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w600)),
        ),
        if (chip != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
            decoration: BoxDecoration(
              color: _surface2,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: _border),
            ),
            child: Text(chip!,
                style: const TextStyle(
                    color: _textSecondary,
                    fontSize: 10,
                    fontWeight: FontWeight.w500)),
          ),
      ],
    );
  }
}

// ════════════════════════════════════════════════════════════
//  REUSABLE COMPONENTS
// ════════════════════════════════════════════════════════════

class _TeamSelectCard extends StatefulWidget {
  final Map<String, dynamic> team;
  final String teamKey;
  final bool isSelected;
  final VoidCallback onTap;

  const _TeamSelectCard({
    required this.team,
    required this.teamKey,
    required this.isSelected,
    required this.onTap,
  });

  @override
  State<_TeamSelectCard> createState() => _TeamSelectCardState();
}

class _TeamSelectCardState extends State<_TeamSelectCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final name = widget.team['name'] as String? ?? widget.teamKey;
    final teamId = widget.team['teamId'] as String? ?? widget.teamKey;
    final logo = widget.team['logo'] as String? ?? '';
    final playerCount = (widget.team['players'] as List?)?.length ?? 0;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: widget.isSelected
                ? Colors.redAccent.withOpacity(0.07)
                : _hovered
                    ? _surface2
                    : _surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: widget.isSelected
                  ? Colors.redAccent.withOpacity(0.4)
                  : _hovered
                      ? const Color(0xFF2E2E2E)
                      : _border,
              width: widget.isSelected ? 1.5 : 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: widget.isSelected
                      ? Colors.redAccent.withOpacity(0.1)
                      : _surface2,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: widget.isSelected
                        ? Colors.redAccent.withOpacity(0.3)
                        : _border,
                  ),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(9),
                  child: logo.isNotEmpty
                      ? Image.network(logo,
                          fit: BoxFit.contain,
                          errorBuilder: (_, __, ___) =>
                              _FallbackLogo(teamId: teamId))
                      : _FallbackLogo(teamId: teamId),
                ),
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
                            fontWeight: FontWeight.w700)),
                    const SizedBox(height: 3),
                    Text('$playerCount players',
                        style: const TextStyle(
                            color: _textSecondary, fontSize: 11)),
                  ],
                ),
              ),
              AnimatedOpacity(
                duration: const Duration(milliseconds: 150),
                opacity: widget.isSelected ? 1.0 : 0.0,
                child: Container(
                  width: 20,
                  height: 20,
                  decoration: const BoxDecoration(
                    color: Colors.redAccent,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.check_rounded,
                      color: Colors.white, size: 12),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DecisionCard extends StatefulWidget {
  final String label, description;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _DecisionCard({
    required this.label,
    required this.description,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  State<_DecisionCard> createState() => _DecisionCardState();
}

class _DecisionCardState extends State<_DecisionCard> {
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
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: widget.isSelected
                ? Colors.redAccent.withOpacity(0.07)
                : _hovered
                    ? _surface2
                    : _surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: widget.isSelected
                  ? Colors.redAccent.withOpacity(0.4)
                  : _hovered
                      ? const Color(0xFF2E2E2E)
                      : _border,
              width: widget.isSelected ? 1.5 : 1,
            ),
          ),
          child: Column(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: widget.isSelected
                      ? Colors.redAccent.withOpacity(0.12)
                      : _surface2,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: widget.isSelected
                        ? Colors.redAccent.withOpacity(0.3)
                        : _border,
                  ),
                ),
                child: Icon(widget.icon,
                    color: widget.isSelected ? Colors.redAccent : _textMuted,
                    size: 20),
              ),
              const SizedBox(height: 12),
              Text(widget.label,
                  style: TextStyle(
                      color: widget.isSelected ? _textPrimary : _textSecondary,
                      fontSize: 15,
                      fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              Text(widget.description,
                  style: const TextStyle(color: _textMuted, fontSize: 11),
                  textAlign: TextAlign.center),
            ],
          ),
        ),
      ),
    );
  }
}

class _PlayerPickerCard extends StatelessWidget {
  final String label, sublabel;
  final IconData icon;
  final List<Map<String, dynamic>> players;
  final String? selectedId, disabledId;
  final ValueChanged<String> onChanged;

  const _PlayerPickerCard({
    required this.label,
    required this.sublabel,
    required this.icon,
    required this.players,
    required this.selectedId,
    required this.onChanged,
    this.disabledId,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color:
              selectedId != null ? Colors.redAccent.withOpacity(0.25) : _border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: Colors.redAccent, size: 13),
              const SizedBox(width: 7),
              Text(label,
                  style: const TextStyle(
                      color: _textPrimary,
                      fontSize: 12,
                      fontWeight: FontWeight.w700)),
              const Spacer(),
              Text(sublabel,
                  style: const TextStyle(color: _textMuted, fontSize: 10)),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(color: Color(0xFF1E1E1E), height: 1),
          const SizedBox(height: 10),
          ...players.map((p) {
            final id = p['id'] as String? ?? '';
            final name = p['name'] as String? ?? '—';
            final role = p['role'] as String? ?? '';
            final isSelected = id == selectedId;
            final isDisabled = id == disabledId;
            return _PlayerPickerRow(
              id: id,
              name: name,
              role: role,
              isSelected: isSelected,
              isDisabled: isDisabled,
              onTap: isDisabled ? null : () => onChanged(id),
            );
          }),
        ],
      ),
    );
  }
}

class _PlayerPickerRow extends StatefulWidget {
  final String id, name, role;
  final bool isSelected, isDisabled;
  final VoidCallback? onTap;

  const _PlayerPickerRow({
    required this.id,
    required this.name,
    required this.role,
    required this.isSelected,
    required this.isDisabled,
    required this.onTap,
  });

  @override
  State<_PlayerPickerRow> createState() => _PlayerPickerRowState();
}

class _PlayerPickerRowState extends State<_PlayerPickerRow> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) =>
          !widget.isDisabled ? setState(() => _hovered = true) : null,
      onExit: (_) => setState(() => _hovered = false),
      cursor: widget.isDisabled
          ? SystemMouseCursors.forbidden
          : SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 130),
          margin: const EdgeInsets.only(bottom: 6),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: widget.isSelected
                ? Colors.redAccent.withOpacity(0.1)
                : _hovered
                    ? _surface2
                    : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: widget.isSelected
                  ? Colors.redAccent.withOpacity(0.3)
                  : Colors.transparent,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  color: widget.isDisabled
                      ? _textMuted
                      : widget.isSelected
                          ? Colors.redAccent
                          : _textMuted,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(widget.name,
                    style: TextStyle(
                        color: widget.isDisabled
                            ? _textMuted
                            : widget.isSelected
                                ? _textPrimary
                                : _textSecondary,
                        fontSize: 13,
                        fontWeight: widget.isSelected
                            ? FontWeight.w600
                            : FontWeight.w400)),
              ),
              if (!widget.isDisabled)
                Text(widget.role,
                    style: const TextStyle(
                        color: _textMuted, fontSize: 10, letterSpacing: 0.3)),
              if (widget.isDisabled)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: _surface3,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text('selected',
                      style: TextStyle(color: _textMuted, fontSize: 9)),
                ),
              const SizedBox(width: 8),
              AnimatedOpacity(
                duration: const Duration(milliseconds: 120),
                opacity: widget.isSelected ? 1 : 0,
                child: const Icon(Icons.check_rounded,
                    color: Colors.redAccent, size: 14),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final IconData icon;
  final String label;
  const _SectionLabel({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: Colors.redAccent, size: 14),
        const SizedBox(width: 8),
        Text(label,
            style: const TextStyle(
                color: _textPrimary,
                fontSize: 14,
                fontWeight: FontWeight.w700)),
      ],
    );
  }
}

class _TeamMiniTag extends StatelessWidget {
  final Map<String, dynamic> team;
  final String teamKey;
  const _TeamMiniTag({required this.team, required this.teamKey});

  @override
  Widget build(BuildContext context) {
    final teamId = team['teamId'] as String? ?? teamKey;
    final logo = team['logo'] as String? ?? '';

    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        color: Colors.redAccent.withOpacity(0.08),
        borderRadius: BorderRadius.circular(7),
        border: Border.all(color: Colors.redAccent.withOpacity(0.2)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: logo.isNotEmpty
            ? Image.network(logo,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => _FallbackLogo(teamId: teamId))
            : _FallbackLogo(teamId: teamId),
      ),
    );
  }
}

class _FallbackLogo extends StatelessWidget {
  final String teamId;
  const _FallbackLogo({required this.teamId});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.redAccent.withOpacity(0.08),
      child: Center(
        child: Text(
          teamId.length > 2 ? teamId.substring(0, 2) : teamId,
          style: const TextStyle(
              color: Colors.redAccent,
              fontSize: 9,
              fontWeight: FontWeight.w800),
        ),
      ),
    );
  }
}

class _NextButton extends StatefulWidget {
  final String label;
  final bool enabled;
  final bool loading;
  final VoidCallback onTap;
  const _NextButton({
    required this.label,
    required this.enabled,
    required this.onTap,
    this.loading = false,
  });

  @override
  State<_NextButton> createState() => _NextButtonState();
}

class _NextButtonState extends State<_NextButton> {
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
          duration: const Duration(milliseconds: 150),
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: widget.enabled
                ? _hovered
                    ? Colors.redAccent.shade700
                    : Colors.redAccent
                : _surface2,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: widget.enabled ? Colors.transparent : _border,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (widget.loading) ...[
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                      color: Colors.white, strokeWidth: 2),
                ),
                const SizedBox(width: 10),
              ],
              Text(widget.label,
                  style: TextStyle(
                      color: widget.enabled ? Colors.white : _textMuted,
                      fontSize: 14,
                      fontWeight: FontWeight.w600)),
              if (!widget.loading) ...[
                const SizedBox(width: 8),
                Icon(Icons.arrow_forward_rounded,
                    color: widget.enabled ? Colors.white : _textMuted,
                    size: 16),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _BackButton extends StatefulWidget {
  final VoidCallback onTap;
  const _BackButton({required this.onTap});

  @override
  State<_BackButton> createState() => _BackButtonState();
}

class _BackButtonState extends State<_BackButton> {
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
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          decoration: BoxDecoration(
            color: _hovered ? _surface2 : _surface,
            borderRadius: BorderRadius.circular(12),
            border:
                Border.all(color: _hovered ? const Color(0xFF2E2E2E) : _border),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.arrow_back_rounded, color: _textSecondary, size: 16),
              SizedBox(width: 6),
              Text('Back',
                  style: TextStyle(
                      color: _textSecondary,
                      fontSize: 14,
                      fontWeight: FontWeight.w500)),
            ],
          ),
        ),
      ),
    );
  }
}

class _GoLiveButton extends StatefulWidget {
  final bool saving;
  final VoidCallback onTap;
  const _GoLiveButton({required this.saving, required this.onTap});

  @override
  State<_GoLiveButton> createState() => _GoLiveButtonState();
}

class _GoLiveButtonState extends State<_GoLiveButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => !widget.saving ? setState(() => _hovered = true) : null,
      onExit: (_) => setState(() => _hovered = false),
      cursor:
          widget.saving ? SystemMouseCursors.wait : SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.saving ? null : widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: widget.saving
                ? Colors.redAccent.withOpacity(0.5)
                : _hovered
                    ? Colors.redAccent.shade700
                    : Colors.redAccent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (widget.saving)
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                      color: Colors.white, strokeWidth: 2),
                )
              else
                const Icon(Icons.bolt_rounded, color: Colors.white, size: 18),
              const SizedBox(width: 8),
              Text(
                widget.saving ? 'Starting Match...' : 'Start Match — Go Live',
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  final String message;
  const _ErrorBanner({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.redAccent.withOpacity(0.07),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.redAccent.withOpacity(0.25)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded,
              color: Colors.redAccent, size: 15),
          const SizedBox(width: 10),
          Expanded(
            child: Text(message,
                style: const TextStyle(color: Color(0xFFFF8A80), fontSize: 12)),
          ),
        ],
      ),
    );
  }
}
