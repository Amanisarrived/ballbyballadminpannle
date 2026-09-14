import 'package:cricket_admin/services/news_admin_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// ─────────────────────────────────────────────────────────────
//  NEWS — Cricbuzz stories the worker pulls into Firestore.
//  Turn auto-fetch on, then hide anything unwanted or pin a big story.
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

class NewsAdminScreen extends StatefulWidget {
  /// Injectable for widget tests.
  final Stream<List<NewsItem>>? source;
  final Stream<bool>? enabledSource;

  const NewsAdminScreen({super.key, this.source, this.enabledSource});

  @override
  State<NewsAdminScreen> createState() => _NewsAdminScreenState();
}

class _NewsAdminScreenState extends State<NewsAdminScreen> {
  late final Stream<List<NewsItem>> _news =
      widget.source ?? NewsAdminService.stream();
  late final Stream<bool> _enabled =
      widget.enabledSource ?? NewsAdminService.enabledStream();
  String _filter = 'all';

  Future<void> _run(Future<void> Function() action, String done) async {
    try {
      await action();
      if (mounted) _toast(done, _green);
    } catch (e) {
      if (mounted) _toast('Failed: $e', _red);
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

  Future<void> _confirmNotify(NewsItem item) async {
    final again = item.notifiedAt != null
        ? 'This story was already sent once.\n\n'
        : '';
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _card,
        title: const Text('Send to all users?',
            style: TextStyle(color: _textPrimary, fontSize: 16)),
        content: Text(
          '$again"${item.title}"\n\nEvery CricView user gets this push. '
          'Tapping it opens the story.',
          style: const TextStyle(color: _textSecondary, fontSize: 13, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: _textSecondary)),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: _red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Send'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await _run(() => NewsAdminService.sendNotification(item), 'Notification queued');
    }
  }

  List<NewsItem> _apply(List<NewsItem> all) {
    final list = switch (_filter) {
      'visible' => all.where((n) => !n.hidden).toList(),
      'hidden' => all.where((n) => n.hidden).toList(),
      'pinned' => all.where((n) => n.pinned).toList(),
      _ => List<NewsItem>.of(all),
    };
    // Pinned first, then newest — the order the app will show.
    list.sort((a, b) {
      if (a.pinned != b.pinned) return a.pinned ? -1 : 1;
      final at = a.publishedAt ?? DateTime(0);
      final bt = b.publishedAt ?? DateTime(0);
      return bt.compareTo(at);
    });
    return list;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: StreamBuilder<List<NewsItem>>(
        stream: _news,
        builder: (context, snap) {
          final all = snap.data ?? const <NewsItem>[];
          final shown = _apply(all);

          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              StreamBuilder<bool>(
                stream: _enabled,
                builder: (context, en) => _SourceCard(
                  enabled: en.data ?? false,
                  total: all.length,
                  hidden: all.where((n) => n.hidden).length,
                  onToggle: (v) => _run(() => NewsAdminService.setEnabled(v),
                      v ? 'Auto-fetching Cricbuzz news' : 'News auto-fetch off'),
                ),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final f in const ['all', 'visible', 'pinned', 'hidden'])
                    _Chip(
                      label: f[0].toUpperCase() + f.substring(1),
                      active: _filter == f,
                      onTap: () => setState(() => _filter = f),
                    ),
                ],
              ),
              const SizedBox(height: 14),
              if (snap.hasError)
                _Hint('Could not load news: ${snap.error}')
              else if (snap.connectionState == ConnectionState.waiting)
                const Padding(
                  padding: EdgeInsets.all(40),
                  child: Center(
                      child: CircularProgressIndicator(color: _red, strokeWidth: 2)),
                )
              else if (all.isEmpty)
                const _Hint(
                    'No news yet. Turn on auto-fetch above — new Cricbuzz stories '
                    'appear here within 15 minutes.')
              else if (shown.isEmpty)
                _Hint('Nothing under "$_filter".')
              else
                ...shown.map((n) => _NewsRow(
                      item: n,
                      onNotify: () => _confirmNotify(n),
                      onHide: () => _run(
                          () => NewsAdminService.setHidden(n.id, !n.hidden),
                          n.hidden ? 'Story visible again' : 'Story hidden from the app'),
                      onPin: () => _run(
                          () => NewsAdminService.setPinned(n.id, !n.pinned),
                          n.pinned ? 'Unpinned' : 'Pinned to the top'),
                    )),
            ],
          );
        },
      ),
    );
  }
}

class _SourceCard extends StatelessWidget {
  final bool enabled;
  final int total;
  final int hidden;
  final ValueChanged<bool> onToggle;

  const _SourceCard({
    required this.enabled,
    required this.total,
    required this.hidden,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: enabled ? _green.withOpacity(0.35) : _border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            dense: true,
            value: enabled,
            activeColor: _green,
            inactiveThumbColor: _textMuted,
            onChanged: onToggle,
            title: const Text('Auto-fetch Cricbuzz news',
                style: TextStyle(
                    color: _textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w800)),
            subtitle: Text(
              enabled
                  ? 'On — checked every 15 minutes'
                  : 'Off — nothing new is fetched',
              style: TextStyle(color: enabled ? _green : _textMuted, fontSize: 11.5),
            ),
          ),
          const SizedBox(height: 4),
          Text('$total stories · $hidden hidden · kept for 30 days unless pinned',
              style: const TextStyle(color: _textSecondary, fontSize: 11.5)),
          const SizedBox(height: 4),
          const Text(
            'Headline, short summary and a link to the full story. No photos '
            'are copied — the app draws each card from the teams involved.',
            style: TextStyle(color: _textMuted, fontSize: 11, height: 1.4),
          ),
        ],
      ),
    );
  }
}

class _NewsRow extends StatelessWidget {
  final NewsItem item;
  final VoidCallback onHide;
  final VoidCallback onPin;
  final VoidCallback onNotify;

  const _NewsRow({
    required this.item,
    required this.onHide,
    required this.onPin,
    required this.onNotify,
  });

  String _ago(DateTime? t) {
    if (t == null) return '';
    final d = DateTime.now().difference(t);
    if (d.inMinutes < 60) return '${d.inMinutes.clamp(0, 59)}m ago';
    if (d.inHours < 24) return '${d.inHours}h ago';
    return '${d.inDays}d ago';
  }

  @override
  Widget build(BuildContext context) {
    final muted = item.hidden;
    return Opacity(
      opacity: muted ? 0.45 : 1,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: _card2,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: item.pinned ? _amber.withOpacity(0.6) : _border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 6,
              runSpacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                if (item.pinned) const _Tag('PINNED', _amber),
                if (item.notifiedAt != null) const _Tag('SENT', _green),
                if (item.hidden) const _Tag('HIDDEN', _red),
                if (item.type.isNotEmpty) _Tag(item.type.toUpperCase(), _textSecondary),
                if (item.context.isNotEmpty) _Tag(item.context, _textSecondary),
                for (final t in item.teams) _Tag(t, _green),
                Text(_ago(item.publishedAt),
                    style: const TextStyle(color: _textMuted, fontSize: 10.5)),
              ],
            ),
            const SizedBox(height: 8),
            Text(item.title,
                style: const TextStyle(
                    color: _textPrimary, fontSize: 14, fontWeight: FontWeight.w700)),
            if (item.description.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(item.description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: _textSecondary, fontSize: 12, height: 1.35)),
            ],
            if (item.teams.isEmpty) ...[
              const SizedBox(height: 6),
              const Text('No team detected — the app shows a category card',
                  style: TextStyle(color: _textMuted, fontSize: 10.5)),
            ],
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _Action(
                    icon: item.pinned ? Icons.push_pin : Icons.push_pin_outlined,
                    label: item.pinned ? 'Unpin' : 'Pin',
                    onTap: onPin),
                _Action(
                    icon: item.hidden
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                    label: item.hidden ? 'Unhide' : 'Hide',
                    onTap: onHide),
                if (!item.hidden)
                  _Action(
                      icon: Icons.notifications_active_outlined,
                      label: item.notifiedAt != null ? 'Send again' : 'Notify',
                      onTap: onNotify),
                _Action(
                  icon: Icons.link_rounded,
                  label: 'Copy link',
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: item.url));
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                      content: Text('Link copied'),
                      behavior: SnackBarBehavior.floating,
                      duration: Duration(seconds: 1),
                    ));
                  },
                ),
              ],
            ),
          ],
        ),
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
          style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w700)),
    );
  }
}

class _Action extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _Action({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: _card,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: _border),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 14, color: _textSecondary),
          const SizedBox(width: 5),
          Text(label,
              style: const TextStyle(
                  color: _textPrimary, fontSize: 11.5, fontWeight: FontWeight.w600)),
        ]),
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
