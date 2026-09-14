import 'package:cricket_admin/services/auto_scoring_service.dart';
import 'package:flutter/material.dart';

// ─────────────────────────────────────────────────────────────
//  AUTO SCORING — drive the Cricbuzz worker
//  Pick a match, import squads, turn it on. The worker writes the
//  same RTDB paths the manual panel does, so everything downstream
//  (app, notifications) keeps working untouched.
// ─────────────────────────────────────────────────────────────

const _red = Color(0xFFCC0000);
const _bg = Color(0xFF0A0A0A);
const _card = Color(0xFF111111);
const _card2 = Color(0xFF161616);
const _border = Color(0xFF222222);
const _textPrimary = Color(0xFFE8E8E8);
const _textSecondary = Color(0xFF888888);
const _textMuted = Color(0xFF555555);
const _green = Color(0xFF4CAF50);
const _amber = Color(0xFFFFB300);

class AutoScoringScreen extends StatefulWidget {
  /// Injectable so widget tests can drive the screen without a live database.
  final Stream<AutoScoringState>? source;

  const AutoScoringScreen({super.key, this.source});

  @override
  State<AutoScoringScreen> createState() => _AutoScoringScreenState();
}

class _AutoScoringScreenState extends State<AutoScoringScreen> {
  final _manualIdCtrl = TextEditingController();
  String _filter = 'live';
  bool _busy = false;

  /// Built once: creating the stream inside build() would resubscribe to RTDB
  /// on every setState.
  Stream<AutoScoringState>? _source;
  String? _initError;

  @override
  void initState() {
    super.initState();
    // Attaching to RTDB can throw (Firebase not ready, no database URL). Catch
    // it here so the screen reports the reason instead of failing its build.
    try {
      _source = widget.source ?? AutoScoringService.states();
    } catch (e) {
      _initError = '$e';
    }
  }

  @override
  void dispose() {
    _manualIdCtrl.dispose();
    super.dispose();
  }

  // ── actions ───────────────────────────────────────────────

  Future<void> _run(Future<void> Function() action, String done) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
      if (mounted) _toast(done, _green);
    } catch (e) {
      if (mounted) _toast('Failed: $e', _red);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _toast(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: const TextStyle(fontWeight: FontWeight.w600)),
      backgroundColor: color,
      behavior: SnackBarBehavior.floating,
      duration: const Duration(seconds: 2),
    ));
  }

  /// Accepts a bare id or a pasted Cricbuzz URL.
  String? _parseMatchId(String input) {
    final text = input.trim();
    if (text.isEmpty) return null;
    if (RegExp(r'^\d{4,}$').hasMatch(text)) return text;
    final match = RegExp(r'/(?:live-cricket-scores|cricket-match-squads|'
            r'live-cricket-scorecard)/(\d{4,})')
        .firstMatch(text);
    return match?.group(1);
  }

  Future<void> _confirmAndEnable(AutoScoringState state) async {
    if (!state.hasMatch) {
      _toast('Pick a match first', _amber);
      return;
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _card,
        title: const Text('Start auto scoring?',
            style: TextStyle(color: _textPrimary, fontSize: 16)),
        content: const Text(
          'The worker will take over the live score, striker, bowler and '
          'player stats for this match.\n\n'
          'Anything you have locked below stays under your control.',
          style: TextStyle(color: _textSecondary, fontSize: 13, height: 1.5),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel',
                  style: TextStyle(color: _textSecondary))),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: _red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Start'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await _run(() => AutoScoringService.setEnabled(true), 'Auto scoring on');
    }
  }

  // ── build ─────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    // Scaffold, not a bare Container: InkWell and SwitchListTile below need a
    // Material ancestor, and without one the whole screen renders as an error.
    if (_initError != null) {
      return Scaffold(
        backgroundColor: _bg,
        body: _ErrorState(message: _initError!),
      );
    }

    return Scaffold(
      backgroundColor: _bg,
      body: StreamBuilder<AutoScoringState>(
        stream: _source,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(
                child: CircularProgressIndicator(color: _red, strokeWidth: 2));
          }
          if (snap.hasError) {
            return _ErrorState(message: '${snap.error}');
          }
          final state = snap.data ?? const AutoScoringState();

          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              _StatusCard(state: state),
              const SizedBox(height: 16),
              _MatchPicker(
                state: state,
                filter: _filter,
                manualCtrl: _manualIdCtrl,
                busy: _busy,
                onFilter: (f) => setState(() => _filter = f),
                onSelect: (id) => _run(() => AutoScoringService.selectMatch(id),
                    'Match set to $id'),
                onManualSubmit: () {
                  final id = _parseMatchId(_manualIdCtrl.text);
                  if (id == null) {
                    _toast('Enter a Cricbuzz match id or URL', _amber);
                    return;
                  }
                  _manualIdCtrl.clear();
                  _run(() => AutoScoringService.selectMatch(id),
                      'Match set to $id');
                },
              ),
              const SizedBox(height: 16),
              _ControlsCard(
                state: state,
                busy: _busy,
                onEnable: () => _confirmAndEnable(state),
                onDisable: () => _run(
                    () => AutoScoringService.setEnabled(false),
                    'Auto scoring off'),
                onPause: (p) => _run(() => AutoScoringService.setPaused(p),
                    p ? 'Paused' : 'Resumed'),
                onImport: () => _run(AutoScoringService.requestSquadImport,
                    'Squad import queued'),
                onReset: () =>
                    _run(AutoScoringService.reset, 'Detached from match'),
              ),
              const SizedBox(height: 16),
              _FixturesCard(
                enabled: state.fixturesEnabled,
                busy: _busy,
                onToggle: (v) => _run(
                  () => AutoScoringService.setFixturesEnabled(v),
                  v ? 'Upcoming fixtures on auto' : 'Upcoming fixtures back to manual',
                ),
              ),
              const SizedBox(height: 16),
              _LocksCard(
                state: state,
                busy: _busy,
                onToggle: (section, locked) => _run(
                  () => AutoScoringService.setLock(section, locked),
                  locked ? '$section is now manual' : '$section is now auto',
                ),
              ),
              const SizedBox(height: 24),
            ],
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  STATUS
// ─────────────────────────────────────────────────────────────

class _StatusCard extends StatelessWidget {
  final AutoScoringState state;
  const _StatusCard({required this.state});

  @override
  Widget build(BuildContext context) {
    late final Color color;
    late final String label;
    late final String detail;

    if (!state.enabled) {
      color = _textMuted;
      label = 'OFF';
      detail = 'Scoring is manual.';
    } else if (state.lastError.isNotEmpty) {
      color = _red;
      label = 'ERROR';
      detail = state.lastError;
    } else if (state.paused) {
      color = _amber;
      label = 'PAUSED';
      detail = 'Worker is running but not writing.';
    } else if (state.isStale) {
      color = _amber;
      label = 'NO SIGNAL';
      detail = 'No update from the worker recently — is it deployed?';
    } else if (state.status == 'waiting') {
      color = _amber;
      label = 'WAITING';
      detail = state.lastEvent.isEmpty
          ? 'Waiting for Cricbuzz to open this match.'
          : state.lastEvent;
    } else {
      color = _green;
      label = 'LIVE';
      detail = state.lastEvent.isEmpty ? 'Syncing.' : state.lastEvent;
    }

    final since = state.sinceSync;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              const SizedBox(width: 10),
              Text(label,
                  style: TextStyle(
                      color: color,
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.2)),
              const Spacer(),
              if (since != null)
                Text(
                  since.inSeconds < 60
                      ? '${since.inSeconds}s ago'
                      : '${since.inMinutes}m ago',
                  style: const TextStyle(color: _textMuted, fontSize: 11),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Text(detail,
              style: const TextStyle(
                  color: _textSecondary, fontSize: 12.5, height: 1.4)),
          if (state.hasMatch) ...[
            const SizedBox(height: 12),
            Row(children: [
              const Icon(Icons.link_rounded, size: 13, color: _textMuted),
              const SizedBox(width: 6),
              Text('Cricbuzz match ${state.cbzMatchId}',
                  style: const TextStyle(color: _textMuted, fontSize: 11.5)),
            ]),
          ],
          if (state.consecutiveErrors > 2) ...[
            const SizedBox(height: 10),
            Text('${state.consecutiveErrors} failures in a row — '
                'Cricbuzz may have changed their page.',
                style: const TextStyle(color: _red, fontSize: 11.5)),
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  MATCH PICKER
// ─────────────────────────────────────────────────────────────

class _MatchPicker extends StatelessWidget {
  final AutoScoringState state;
  final String filter;
  final TextEditingController manualCtrl;
  final bool busy;
  final ValueChanged<String> onFilter;
  final ValueChanged<String> onSelect;
  final VoidCallback onManualSubmit;

  const _MatchPicker({
    required this.state,
    required this.filter,
    required this.manualCtrl,
    required this.busy,
    required this.onFilter,
    required this.onSelect,
    required this.onManualSubmit,
  });

  @override
  Widget build(BuildContext context) {
    final all = state.matches;
    final shown = switch (filter) {
      'live' => all.where((m) => m.isLive).toList(),
      'upcoming' => all.where((m) => m.isUpcoming).toList(),
      _ => all,
    };

    return _Card(
      title: 'Match',
      subtitle: 'Pick the Cricbuzz match to mirror',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _Chip(
                  label: 'Live',
                  active: filter == 'live',
                  onTap: () => onFilter('live')),
              const SizedBox(width: 8),
              _Chip(
                  label: 'Upcoming',
                  active: filter == 'upcoming',
                  onTap: () => onFilter('upcoming')),
              const SizedBox(width: 8),
              _Chip(
                  label: 'All',
                  active: filter == 'all',
                  onTap: () => onFilter('all')),
            ],
          ),
          const SizedBox(height: 14),
          if (all.isEmpty)
            const _Hint(
                'No fixture list yet. The worker publishes it once it is '
                'running — you can still paste a match id below.')
          else if (shown.isEmpty)
            _Hint('No ${filter == 'live' ? 'live' : filter} matches right now.')
          else
            ...shown.map((m) => _MatchRow(
                  match: m,
                  selected: m.matchId == state.cbzMatchId,
                  onTap: busy ? null : () => onSelect(m.matchId),
                )),
          const SizedBox(height: 14),
          const Divider(color: _border, height: 1),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: TextField(
                  controller: manualCtrl,
                  style: const TextStyle(color: _textPrimary, fontSize: 13),
                  onSubmitted: (_) => onManualSubmit(),
                  decoration: InputDecoration(
                    isDense: true,
                    hintText: 'Match id or Cricbuzz URL',
                    hintStyle:
                        const TextStyle(color: _textMuted, fontSize: 12.5),
                    filled: true,
                    fillColor: _card2,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 12),
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
                      borderSide: const BorderSide(color: _red),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              SizedBox(
                height: 43,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: _card2,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                        side: const BorderSide(color: _border)),
                  ),
                  onPressed: busy ? null : onManualSubmit,
                  child: const Text('Set',
                      style: TextStyle(color: _textPrimary, fontSize: 13)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MatchRow extends StatelessWidget {
  final CbzMatch match;
  final bool selected;
  final VoidCallback? onTap;

  const _MatchRow({required this.match, required this.selected, this.onTap});

  @override
  Widget build(BuildContext context) {
    final stateColor = match.isLive
        ? _green
        : match.isDone
            ? _textMuted
            : _amber;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: selected ? _red.withOpacity(0.10) : _card2,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: selected ? _red : _border),
        ),
        child: Row(
          children: [
            Container(
              width: 7,
              height: 7,
              decoration:
                  BoxDecoration(color: stateColor, shape: BoxShape.circle),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text('${match.title}  ·  ${match.desc}',
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                color: _textPrimary,
                                fontSize: 13,
                                fontWeight: FontWeight.w700)),
                      ),
                      const SizedBox(width: 8),
                      Text(match.format,
                          style: const TextStyle(
                              color: _textMuted,
                              fontSize: 10,
                              fontWeight: FontWeight.w700)),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(match.status,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: stateColor, fontSize: 11)),
                ],
              ),
            ),
            if (selected)
              const Icon(Icons.check_circle_rounded, color: _red, size: 18),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  CONTROLS
// ─────────────────────────────────────────────────────────────

class _ControlsCard extends StatelessWidget {
  final AutoScoringState state;
  final bool busy;
  final VoidCallback onEnable;
  final VoidCallback onDisable;
  final ValueChanged<bool> onPause;
  final VoidCallback onImport;
  final VoidCallback onReset;

  const _ControlsCard({
    required this.state,
    required this.busy,
    required this.onEnable,
    required this.onDisable,
    required this.onPause,
    required this.onImport,
    required this.onReset,
  });

  @override
  Widget build(BuildContext context) {
    return _Card(
      title: 'Controls',
      subtitle: 'Import the squads once, then start scoring',
      child: Column(
        children: [
          _ActionRow(
            icon: Icons.groups_rounded,
            label: 'Import playing XI',
            detail: state.importSquads
                ? 'Queued — the worker will pick this up.'
                : 'Happens automatically after the toss. Tap only to retry.',
            buttonLabel: state.importSquads ? 'Queued' : 'Import',
            enabled: !busy && state.hasMatch && !state.importSquads,
            onPressed: onImport,
          ),
          const SizedBox(height: 12),
          _ActionRow(
            icon: state.enabled
                ? Icons.stop_circle_outlined
                : Icons.play_circle_outline_rounded,
            label: state.enabled ? 'Stop auto scoring' : 'Start auto scoring',
            detail: state.enabled
                ? 'Hands scoring back to the manual panel.'
                : 'The worker takes over this match.',
            buttonLabel: state.enabled ? 'Stop' : 'Start',
            danger: state.enabled,
            enabled: !busy && state.hasMatch,
            onPressed: state.enabled ? onDisable : onEnable,
          ),
          if (state.enabled) ...[
            const SizedBox(height: 12),
            _ActionRow(
              icon: state.paused
                  ? Icons.play_arrow_rounded
                  : Icons.pause_rounded,
              label: state.paused ? 'Resume writing' : 'Pause writing',
              detail: state.paused
                  ? 'Worker is idle; nothing is being written.'
                  : 'Freeze everything without stopping the worker.',
              buttonLabel: state.paused ? 'Resume' : 'Pause',
              enabled: !busy,
              onPressed: () => onPause(!state.paused),
            ),
          ],
          const SizedBox(height: 12),
          _ActionRow(
            icon: Icons.link_off_rounded,
            label: 'Detach from match',
            detail: 'Stops scoring and clears the selected match.',
            buttonLabel: 'Detach',
            danger: true,
            enabled: !busy && state.hasMatch,
            onPressed: onReset,
          ),
        ],
      ),
    );
  }
}

class _ActionRow extends StatelessWidget {
  final IconData icon;
  final String label, detail, buttonLabel;
  final bool enabled, danger;
  final VoidCallback onPressed;

  const _ActionRow({
    required this.icon,
    required this.label,
    required this.detail,
    required this.buttonLabel,
    required this.enabled,
    required this.onPressed,
    this.danger = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _card2,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _border),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: enabled ? _textSecondary : _textMuted),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: TextStyle(
                        color: enabled ? _textPrimary : _textMuted,
                        fontSize: 13,
                        fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text(detail,
                    style: const TextStyle(color: _textMuted, fontSize: 11.5)),
              ],
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            height: 34,
            child: FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: danger ? _red : _card,
                disabledBackgroundColor: _card,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                    side: BorderSide(color: danger ? _red : _border)),
              ),
              onPressed: enabled ? onPressed : null,
              child: Text(buttonLabel,
                  style: TextStyle(
                      color: enabled ? _textPrimary : _textMuted,
                      fontSize: 12,
                      fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  UPCOMING FIXTURES
// ─────────────────────────────────────────────────────────────

class _FixturesCard extends StatelessWidget {
  final bool enabled;
  final bool busy;
  final ValueChanged<bool> onToggle;

  const _FixturesCard(
      {required this.enabled, required this.busy, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    return _Card(
      title: 'Upcoming fixtures',
      subtitle: "Fill the app's Upcoming section from Cricbuzz",
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            dense: true,
            value: enabled,
            activeColor: _green,
            inactiveThumbColor: _textMuted,
            onChanged: busy ? null : onToggle,
            title: const Text('Auto-fill international fixtures',
                style: TextStyle(
                    color: _textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600)),
            subtitle: Text(
                enabled ? 'On — checked every 30 minutes' : 'Off — add fixtures by hand',
                style: TextStyle(
                    color: enabled ? _green : _textMuted, fontSize: 11)),
          ),
          const SizedBox(height: 6),
          const _Hint(
            'Next 7 days of matches between Test-playing nations (plus IPL). '
            'Fixtures you added yourself are never changed or duplicated — '
            'only their result is filled in after the match. '
            'Results and player of the match are added automatically.'),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  LOCKS
// ─────────────────────────────────────────────────────────────

class _LocksCard extends StatelessWidget {
  final AutoScoringState state;
  final bool busy;
  final void Function(String section, bool locked) onToggle;

  const _LocksCard(
      {required this.state, required this.busy, required this.onToggle});

  static const _labels = {
    'scores': 'Score',
    'liveMatch': 'Striker / bowler',
    'playerStats': 'Player stats',
    'currentOver': 'Current over',
    'meta': 'Match info',
  };

  @override
  Widget build(BuildContext context) {
    return _Card(
      title: 'Manual override',
      subtitle: 'Lock anything you want to control yourself',
      child: Column(
        children: AutoScoringService.sections.map((section) {
          final locked = state.isLocked(section);
          return Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: SwitchListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              value: locked,
              activeColor: _amber,
              inactiveThumbColor: _textMuted,
              onChanged: busy ? null : (v) => onToggle(section, v),
              title: Text(_labels[section] ?? section,
                  style: const TextStyle(
                      color: _textPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w600)),
              subtitle: Text(locked ? 'Manual — worker will not touch it' : 'Auto',
                  style: TextStyle(
                      color: locked ? _amber : _textMuted, fontSize: 11)),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  SHARED BITS
// ─────────────────────────────────────────────────────────────

class _Card extends StatelessWidget {
  final String title, subtitle;
  final Widget child;
  const _Card(
      {required this.title, required this.subtitle, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: const TextStyle(
                  color: _textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w800)),
          const SizedBox(height: 3),
          Text(subtitle,
              style: const TextStyle(color: _textMuted, fontSize: 11.5)),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;
  const _Chip({required this.label, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: active ? _red.withOpacity(0.14) : _card2,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: active ? _red : _border),
        ),
        child: Text(label,
            style: TextStyle(
                color: active ? _red : _textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w700)),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  const _ErrorState({required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_rounded, color: _red, size: 32),
            const SizedBox(height: 14),
            const Text('Could not read auto-scoring state',
                style: TextStyle(
                    color: _textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Text(message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: _textMuted, fontSize: 11.5, height: 1.45)),
          ],
        ),
      ),
    );
  }
}

class _Hint extends StatelessWidget {
  final String text;
  const _Hint(this.text);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _card2,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _border),
      ),
      child: Text(text,
          style: const TextStyle(
              color: _textMuted, fontSize: 12, height: 1.45)),
    );
  }
}
