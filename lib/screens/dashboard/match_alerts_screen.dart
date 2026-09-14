import 'package:cricket_admin/services/match_alerts_service.dart';
import 'package:flutter/material.dart';

// ─────────────────────────────────────────────────────────────
//  MATCH ALERTS — automatic push notifications for the featured
//  match (toss, wickets, fifties, target, close finish, result).
//  Works the same for auto scoring and manual scoring.
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

class MatchAlertsScreen extends StatefulWidget {
  /// Injectable for widget tests.
  final Stream<MatchAlertSettings>? settingsSource;
  final Stream<List<MatchAlertLog>>? logSource;
  final Future<void> Function(Map<String, dynamic> fields)? onUpdate;

  const MatchAlertsScreen({
    super.key,
    this.settingsSource,
    this.logSource,
    this.onUpdate,
  });

  @override
  State<MatchAlertsScreen> createState() => _MatchAlertsScreenState();
}

class _MatchAlertsScreenState extends State<MatchAlertsScreen> {
  late final Stream<MatchAlertSettings> _settings =
      widget.settingsSource ?? MatchAlertsService.settings();
  late final Stream<List<MatchAlertLog>> _log =
      widget.logSource ?? MatchAlertsService.log();

  Future<void> _set(Map<String, dynamic> fields) async {
    try {
      await (widget.onUpdate ?? MatchAlertsService.update)(fields);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Failed: $e'),
        backgroundColor: _red,
        behavior: SnackBarBehavior.floating,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          StreamBuilder<MatchAlertSettings>(
            stream: _settings,
            builder: (context, snap) {
              if (snap.hasError) {
                return _Hint('Could not load alert settings: ${snap.error}');
              }
              final s = snap.data ?? const MatchAlertSettings();
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _MasterCard(
                      settings: s, onToggle: (v) => _set({'enabled': v})),
                  const SizedBox(height: 14),
                  Opacity(
                    opacity: s.enabled ? 1 : 0.45,
                    child: IgnorePointer(
                      ignoring: !s.enabled,
                      child: _TypesCard(settings: s, onSet: _set),
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 22),
          const Text('RECENT ALERTS',
              style: TextStyle(
                  color: _textSecondary,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.2)),
          const SizedBox(height: 10),
          StreamBuilder<List<MatchAlertLog>>(
            stream: _log,
            builder: (context, snap) {
              if (snap.hasError) {
                return _Hint('Could not load alerts: ${snap.error}');
              }
              if (snap.connectionState == ConnectionState.waiting) {
                return const Padding(
                  padding: EdgeInsets.all(30),
                  child: Center(
                      child: CircularProgressIndicator(
                          color: _red, strokeWidth: 2)),
                );
              }
              final items = snap.data ?? const <MatchAlertLog>[];
              if (items.isEmpty) {
                return const _Hint(
                    'No alerts sent yet. They start on their own once the '
                    'featured match goes live.');
              }
              return Column(
                  children: [for (final item in items) _LogRow(item: item)]);
            },
          ),
        ],
      ),
    );
  }
}

class _MasterCard extends StatelessWidget {
  final MatchAlertSettings settings;
  final ValueChanged<bool> onToggle;
  const _MasterCard({required this.settings, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    final on = settings.enabled;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: on ? _green.withOpacity(0.35) : _border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            dense: true,
            value: on,
            activeColor: _green,
            inactiveThumbColor: _textMuted,
            onChanged: onToggle,
            title: const Text('Automatic match alerts',
                style: TextStyle(
                    color: _textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w800)),
            subtitle: Text(
              on
                  ? 'On. Sent to every app user as the match happens'
                  : 'Off. No match notifications are sent',
              style: TextStyle(color: on ? _green : _textMuted, fontSize: 11.5),
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Each alert goes out once per match. Re-saving scores, undoing a '
            'ball or switching matches never sends it again.',
            style: TextStyle(color: _textMuted, fontSize: 11, height: 1.4),
          ),
        ],
      ),
    );
  }
}

class _TypesCard extends StatelessWidget {
  final MatchAlertSettings settings;
  final Future<void> Function(Map<String, dynamic>) onSet;
  const _TypesCard({required this.settings, required this.onSet});

  @override
  Widget build(BuildContext context) {
    final s = settings;
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 10, 18, 18),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _TypeRow(
            label: 'Toss',
            example: 'TOSS: India will BAT first 🪙',
            value: s.toss,
            onChanged: (v) => onSet({'toss': v}),
          ),
          _WicketRow(value: s.wickets, onChanged: (v) => onSet({'wickets': v})),
          _TypeRow(
            label: 'Milestones',
            example: 'Abhishek Sharma SMASHES a 20-ball fifty 🔥',
            detail: 'Batter 50 / 100, bowler 4-5 wickets, team 200 in T20s',
            value: s.milestones,
            onChanged: (v) => onSet({'milestones': v}),
          ),
          _TypeRow(
            label: 'Innings break',
            example: 'India need 157 to win 🎯',
            value: s.inningsBreak,
            onChanged: (v) => onSet({'inningsBreak': v}),
          ),
          _TypeRow(
            label: 'Close finish',
            example: 'LAST OVER DRAMA! 9 needed off 6 😱',
            detail: 'At most two per match: a tense chase, then the last over',
            value: s.chase,
            onChanged: (v) => onSet({'chase': v}),
          ),
          _TypeRow(
            label: 'Result',
            example: 'WHAT A FINISH! India win it 🤯',
            detail: 'Also super over and end of day in Tests',
            value: s.result,
            onChanged: (v) => onSet({'result': v}),
          ),
          _TypeRow(
            label: 'Powerplay',
            example: 'POWERPLAY DONE ⚡ IND 62/1',
            value: s.powerplay,
            onChanged: (v) => onSet({'powerplay': v}),
          ),
          const Divider(color: _border, height: 22),
          Row(
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Limit per match',
                        style: TextStyle(
                            color: _textPrimary,
                            fontSize: 13,
                            fontWeight: FontWeight.w700)),
                    SizedBox(height: 2),
                    Text('Per day in Tests. Toss, innings break and result '
                        'always go out.',
                        style: TextStyle(color: _textMuted, fontSize: 11)),
                  ],
                ),
              ),
              _StepButton(
                icon: Icons.remove_rounded,
                onTap: s.maxPerMatch > 1
                    ? () => onSet({'maxPerMatch': s.maxPerMatch - 1})
                    : null,
              ),
              SizedBox(
                width: 40,
                child: Text('${s.maxPerMatch}',
                    key: const Key('alert-cap'),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        color: _textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w800)),
              ),
              _StepButton(
                icon: Icons.add_rounded,
                onTap: s.maxPerMatch < 40
                    ? () => onSet({'maxPerMatch': s.maxPerMatch + 1})
                    : null,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TypeRow extends StatelessWidget {
  final String label;
  final String example;
  final String? detail;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _TypeRow({
    required this.label,
    required this.example,
    required this.value,
    required this.onChanged,
    this.detail,
  });

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      contentPadding: EdgeInsets.zero,
      dense: true,
      value: value,
      activeColor: _green,
      inactiveThumbColor: _textMuted,
      onChanged: onChanged,
      title: Text(label,
          style: const TextStyle(
              color: _textPrimary, fontSize: 13, fontWeight: FontWeight.w700)),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(example,
              style: const TextStyle(
                  color: _textSecondary,
                  fontSize: 11.5,
                  fontStyle: FontStyle.italic)),
          if (detail != null)
            Text(detail!,
                style: const TextStyle(color: _textMuted, fontSize: 10.5)),
        ],
      ),
    );
  }
}

class _WicketRow extends StatelessWidget {
  final String value;
  final ValueChanged<String> onChanged;
  const _WicketRow({required this.value, required this.onChanged});

  static const _hints = {
    'all': 'Every wicket',
    'key': 'Set batters (30+), ducks, collapses and wickets in a tight chase',
    'off': 'No wicket alerts',
  };

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Wickets',
              style: TextStyle(
                  color: _textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w700)),
          const Text('BIG WICKET! Virat Kohli out for 45 💥',
              style: TextStyle(
                  color: _textSecondary,
                  fontSize: 11.5,
                  fontStyle: FontStyle.italic)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              for (final entry in const {
                'key': 'Key wickets',
                'all': 'All',
                'off': 'Off',
              }.entries)
                ChoiceChip(
                  label: Text(entry.value),
                  selected: value == entry.key,
                  onSelected: (_) => onChanged(entry.key),
                  selectedColor: _red.withOpacity(0.18),
                  backgroundColor: _card2,
                  side: BorderSide(color: value == entry.key ? _red : _border),
                  labelStyle: TextStyle(
                      color: value == entry.key ? _red : _textSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w700),
                  showCheckmark: false,
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text(_hints[value] ?? '',
              style: const TextStyle(color: _textMuted, fontSize: 10.5)),
        ],
      ),
    );
  }
}

class _StepButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  const _StepButton({required this.icon, this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: _card2,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: _border),
        ),
        child: Icon(icon,
            size: 18, color: onTap == null ? _textMuted : _textPrimary),
      ),
    );
  }
}

class _LogRow extends StatelessWidget {
  final MatchAlertLog item;
  const _LogRow({required this.item});

  static const _kindLabels = {
    'toss': 'TOSS',
    'wicket': 'WICKET',
    'milestone': 'MILESTONE',
    'innings_break': 'INNINGS BREAK',
    'chase': 'CLOSE FINISH',
    'result': 'RESULT',
    'super_over': 'SUPER OVER',
    'stumps': 'STUMPS',
    'powerplay': 'POWERPLAY',
  };

  String _ago(DateTime? t) {
    if (t == null) return 'just now';
    final d = DateTime.now().difference(t);
    if (d.inMinutes < 1) return 'just now';
    if (d.inMinutes < 60) return '${d.inMinutes}m ago';
    if (d.inHours < 24) return '${d.inHours}h ago';
    return '${d.inDays}d ago';
  }

  @override
  Widget build(BuildContext context) {
    final statusColor = switch (item.status) {
      'sent' => _green,
      'failed' => _red,
      _ => _amber,
    };
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _card2,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 6,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _Tag(_kindLabels[item.kind] ?? item.kind.toUpperCase(),
                  _textSecondary),
              _Tag(item.status.toUpperCase(), statusColor),
              Text(_ago(item.createdAt),
                  style: const TextStyle(color: _textMuted, fontSize: 10.5)),
            ],
          ),
          const SizedBox(height: 6),
          Text(item.title,
              style: const TextStyle(
                  color: _textPrimary,
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700)),
          if (item.body.isNotEmpty) ...[
            const SizedBox(height: 3),
            Text(item.body,
                style: const TextStyle(
                    color: _textSecondary, fontSize: 12, height: 1.35)),
          ],
          if (item.matchTitle.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(item.matchTitle,
                style: const TextStyle(color: _textMuted, fontSize: 10.5)),
          ],
          if (item.error.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(item.error,
                style: const TextStyle(color: _red, fontSize: 10.5)),
          ],
        ],
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  final String text;
  final Color color;
  const _Tag(this.text, this.color);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.35)),
      ),
      child: Text(text,
          style: TextStyle(
              color: color, fontSize: 10, fontWeight: FontWeight.w700)),
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
          style: const TextStyle(color: _textMuted, fontSize: 12, height: 1.45)),
    );
  }
}
