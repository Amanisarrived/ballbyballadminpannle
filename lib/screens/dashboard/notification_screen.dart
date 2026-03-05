// ignore_for_file: unused_element_parameter

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

const _bg = Color(0xFF0D0D0D);
const _surface = Color(0xFF141414);
const _surface2 = Color(0xFF1A1A1A);
const _surface3 = Color(0xFF202020);
const _border = Color(0xFF232323);
const _border2 = Color(0xFF2A2A2A);
const _textPrimary = Color(0xFFE8E8E8);
const _textSecondary = Color(0xFF666666);
const _textMuted = Color(0xFF3A3A3A);

const _notifTypes = [
  {
    'id': 'match_starting',
    'label': 'Match Starting Soon',
    'icon': Icons.sports_cricket_rounded,
    'color': Color(0xFF4CAF50)
  },
  {
    'id': 'score_update',
    'label': 'Score Update',
    'icon': Icons.scoreboard_rounded,
    'color': Color(0xFF2196F3)
  },
  {
    'id': 'match_result',
    'label': 'Match Result',
    'icon': Icons.emoji_events_rounded,
    'color': Color(0xFFFF9800)
  },
  {
    'id': 'custom',
    'label': 'Custom Message',
    'icon': Icons.campaign_rounded,
    'color': Color(0xFFE53935)
  },
];

const _templates = {
  'match_starting': [
    {
      'title': '🏏 Match Starting Soon!',
      'body': 'The match is about to begin. Don\'t miss it!'
    },
    {
      'title': '⏰ 10 Minutes to Go!',
      'body': 'Get ready! Match starts in 10 minutes.'
    },
  ],
  'score_update': [
    {'title': '📊 Score Update', 'body': 'Check the latest score update now!'},
    {
      'title': '🔥 Wicket Down!',
      'body': 'A wicket has fallen! See the latest score.'
    },
  ],
  'match_result': [
    {
      'title': '🏆 Match Result',
      'body': 'The match has ended. Check the final result!'
    },
    {'title': '🎉 What a Match!', 'body': 'An incredible game! See who won.'},
  ],
  'custom': [
    {'title': '🏏 Cricket Update', 'body': 'Something exciting is happening!'},
    {
      'title': '📢 Announcement',
      'body': 'We have an important announcement for you.'
    },
  ],
};

// ══════════════════════════════════════════════════════════════════════════════
//  NOTIFICATION SCREEN
// ══════════════════════════════════════════════════════════════════════════════
class NotificationScreen extends StatefulWidget {
  const NotificationScreen({super.key});

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 3,
            child: Column(
              children: [
                _ScreenHeader(onSend: () => _showSendDialog(context)),
                const Expanded(child: _ComposePanel()),
              ],
            ),
          ),
          const VerticalDivider(color: _border, width: 1),
          const Expanded(flex: 2, child: _HistoryPanel()),
        ],
      ),
    );
  }

  static Future<void> _showSendDialog(BuildContext context) =>
      showDialog(context: context, builder: (_) => const _ConfirmSendDialog());
}

// ══════════════════════════════════════════════════════════════════════════════
//  HEADER
// ══════════════════════════════════════════════════════════════════════════════
class _ScreenHeader extends StatelessWidget {
  final VoidCallback onSend;
  const _ScreenHeader({required this.onSend});

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
          const Icon(Icons.notifications_rounded,
              color: _textSecondary, size: 18),
          const SizedBox(width: 12),
          const Text('Push Notifications',
              style: TextStyle(
                  color: _textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w700)),
          const Spacer(),
          _SendButton(onTap: onSend),
        ],
      ),
    );
  }
}

class _SendButton extends StatefulWidget {
  final VoidCallback onTap;
  const _SendButton({required this.onTap});

  @override
  State<_SendButton> createState() => _SendButtonState();
}

class _SendButtonState extends State<_SendButton> {
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
              Icon(Icons.send_rounded, color: Colors.white, size: 15),
              SizedBox(width: 7),
              Text('Send Notification',
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

// ══════════════════════════════════════════════════════════════════════════════
//  COMPOSE PANEL
// ══════════════════════════════════════════════════════════════════════════════
class _ComposePanel extends StatefulWidget {
  const _ComposePanel();

  @override
  State<_ComposePanel> createState() => _ComposePanelState();
}

class _ComposePanelState extends State<_ComposePanel> {
  final _titleCtrl = TextEditingController();
  final _bodyCtrl = TextEditingController();
  final _imageCtrl = TextEditingController(); // ← NEW
  String _selectedType = 'match_starting';
  String _selectedTopic = 'cricket_notification';
  bool _sending = false;
  String? _successMsg;

  @override
  void dispose() {
    _titleCtrl.dispose();
    _bodyCtrl.dispose();
    _imageCtrl.dispose(); // ← NEW
    super.dispose();
  }

  Map<String, dynamic> get _currentType =>
      _notifTypes.firstWhere((t) => t['id'] == _selectedType);

  bool get _valid =>
      _titleCtrl.text.trim().isNotEmpty && _bodyCtrl.text.trim().isNotEmpty;

  void _applyTemplate(Map<String, String> t) {
    setState(() {
      _titleCtrl.text = t['title']!;
      _bodyCtrl.text = t['body']!;
    });
  }

  Future<void> _send() async {
    if (!_valid || _sending) return;
    setState(() {
      _sending = true;
      _successMsg = null;
    });
    try {
      await FirebaseFirestore.instance
          .collection('notifications')
          .doc('queue')
          .collection('pending')
          .add({
        'title': _titleCtrl.text.trim(),
        'body': _bodyCtrl.text.trim(),
        'imageUrl': _imageCtrl.text.trim().isEmpty
            ? null
            : _imageCtrl.text.trim(), // ← NEW
        'type': _selectedType,
        'topic': _selectedTopic,
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
      });
      setState(() {
        _successMsg = 'Notification queued successfully!';
        _titleCtrl.clear();
        _bodyCtrl.clear();
        _imageCtrl.clear(); // ← NEW
      });
    } catch (e) {
      setState(() => _successMsg = 'Error: $e');
    } finally {
      setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final templates = _templates[_selectedType] ?? [];
    final imageUrl = _imageCtrl.text.trim();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Type ──
          const _SectionLabel('Notification Type'),
          const SizedBox(height: 12),
          _TypeSelector(
            selected: _selectedType,
            onChanged: (t) => setState(() {
              _selectedType = t;
              _successMsg = null;
            }),
          ),
          const SizedBox(height: 24),

          // ── Audience ──
          const _SectionLabel('Send To'),
          const SizedBox(height: 12),
          _AudienceSelector(
            selected: _selectedTopic,
            onChanged: (t) => setState(() => _selectedTopic = t),
          ),
          const SizedBox(height: 24),

          // ── Templates ──
          const _SectionLabel('Quick Templates'),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: templates
                .map((t) => _TemplateChip(
                      label: t['title'] as String,
                      onTap: () => _applyTemplate(Map<String, String>.from(t)),
                    ))
                .toList(),
          ),
          const SizedBox(height: 24),

          // ── Title ──
          const _SectionLabel('Notification Title *'),
          const SizedBox(height: 8),
          _FormField(
            controller: _titleCtrl,
            hint: 'e.g. Match Starting Soon!',
            icon: Icons.title_rounded,
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 16),

          // ── Body ──
          const _SectionLabel('Message Body *'),
          const SizedBox(height: 8),
          _FormField(
            controller: _bodyCtrl,
            hint: 'Write your notification message here...',
            maxLines: 3,
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 16),

          // ── Image URL (NEW) ───────────────────────────────────────────────
          const _SectionLabel('Image URL (Optional)'),
          const SizedBox(height: 4),
          const Text(
              'Paste a direct image link — shown as big picture on Android',
              style: TextStyle(color: _textMuted, fontSize: 10)),
          const SizedBox(height: 8),
          _FormField(
            controller: _imageCtrl,
            hint: 'https://example.com/match-banner.jpg',
            icon: Icons.image_rounded,
            onChanged: (_) => setState(() {}),
          ),
          // Live image preview
          if (imageUrl.isNotEmpty) ...[
            const SizedBox(height: 10),
            _ImagePreviewTile(url: imageUrl),
          ],
          const SizedBox(height: 20),

          // ── Notification Preview ──
          if (_titleCtrl.text.isNotEmpty || _bodyCtrl.text.isNotEmpty) ...[
            const _SectionLabel('Preview'),
            const SizedBox(height: 12),
            _NotifPreview(
              title: _titleCtrl.text,
              body: _bodyCtrl.text,
              imageUrl: imageUrl.isEmpty ? null : imageUrl,
              typeData: _currentType,
            ),
            const SizedBox(height: 20),
          ],

          // ── Status ──
          if (_successMsg != null) ...[
            _StatusBanner(message: _successMsg!),
            const SizedBox(height: 16),
          ],

          // ── Send ──
          _ConfirmBtn(
            label: _sending ? 'Sending…' : 'Send Notification',
            enabled: _valid && !_sending,
            onTap: _send,
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  IMAGE PREVIEW TILE (NEW)
// ══════════════════════════════════════════════════════════════════════════════
class _ImagePreviewTile extends StatelessWidget {
  final String url;
  const _ImagePreviewTile({required this.url});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: Image.network(
        url,
        height: 120,
        width: double.infinity,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => Container(
          height: 60,
          decoration: BoxDecoration(
            color: _surface2,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: _border2),
          ),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.broken_image_rounded, color: _textMuted, size: 18),
              SizedBox(width: 8),
              Text('Invalid image URL',
                  style: TextStyle(color: _textMuted, fontSize: 11)),
            ],
          ),
        ),
        loadingBuilder: (_, child, progress) {
          if (progress == null) return child;
          return Container(
            height: 60,
            decoration: BoxDecoration(
                color: _surface2, borderRadius: BorderRadius.circular(10)),
            child: const Center(
                child: CircularProgressIndicator(
                    color: Colors.redAccent, strokeWidth: 2)),
          );
        },
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  TYPE SELECTOR
// ══════════════════════════════════════════════════════════════════════════════
class _TypeSelector extends StatelessWidget {
  final String selected;
  final ValueChanged<String> onChanged;
  const _TypeSelector({required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: _notifTypes.map((t) {
        final isSelected = selected == t['id'];
        final color = t['color'] as Color;
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.only(right: 8),
            child: _TypeCard(
              icon: t['icon'] as IconData,
              label: t['label'] as String,
              color: color,
              isSelected: isSelected,
              onTap: () => onChanged(t['id'] as String),
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _TypeCard extends StatefulWidget {
  final IconData icon;
  final String label;
  final Color color;
  final bool isSelected;
  final VoidCallback onTap;
  const _TypeCard(
      {required this.icon,
      required this.label,
      required this.color,
      required this.isSelected,
      required this.onTap});

  @override
  State<_TypeCard> createState() => _TypeCardState();
}

class _TypeCardState extends State<_TypeCard> {
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
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          decoration: BoxDecoration(
            color: widget.isSelected
                ? widget.color.withOpacity(0.08)
                : _hovered
                    ? _surface2
                    : _surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: widget.isSelected
                  ? widget.color.withOpacity(0.4)
                  : _hovered
                      ? _border2
                      : _border,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(widget.icon,
                  size: 20,
                  color: widget.isSelected ? widget.color : _textSecondary),
              const SizedBox(height: 8),
              Text(
                widget.label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight:
                      widget.isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: widget.isSelected ? widget.color : _textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  AUDIENCE SELECTOR
// ══════════════════════════════════════════════════════════════════════════════
class _AudienceSelector extends StatelessWidget {
  final String selected;
  final ValueChanged<String> onChanged;
  const _AudienceSelector({required this.selected, required this.onChanged});

  static const _topics = [
    {
      'id': 'cricket_notification',
      'label': 'All Users',
      'sub': 'Everyone subscribed',
      'icon': Icons.people_rounded
    },
    {
      'id': 'match_live',
      'label': 'Live Watchers',
      'sub': 'Users watching live',
      'icon': Icons.live_tv_rounded
    },
    {
      'id': 'score_alerts',
      'label': 'Score Alerts',
      'sub': 'Score subscribers',
      'icon': Icons.scoreboard_rounded
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Row(
      children: _topics.map((t) {
        final isSelected = selected == t['id'];
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.only(right: 8),
            child: _AudienceChip(
              icon: t['icon'] as IconData,
              label: t['label'] as String,
              sub: t['sub'] as String,
              isSelected: isSelected,
              onTap: () => onChanged(t['id'] as String),
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _AudienceChip extends StatefulWidget {
  final IconData icon;
  final String label, sub;
  final bool isSelected;
  final VoidCallback onTap;
  const _AudienceChip(
      {required this.icon,
      required this.label,
      required this.sub,
      required this.isSelected,
      required this.onTap});

  @override
  State<_AudienceChip> createState() => _AudienceChipState();
}

class _AudienceChipState extends State<_AudienceChip> {
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
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: widget.isSelected
                ? Colors.redAccent.withOpacity(0.08)
                : _hovered
                    ? _surface2
                    : _surface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: widget.isSelected
                  ? Colors.redAccent.withOpacity(0.4)
                  : _hovered
                      ? _border2
                      : _border,
            ),
          ),
          child: Row(
            children: [
              Icon(widget.icon,
                  size: 16,
                  color: widget.isSelected ? Colors.redAccent : _textSecondary),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(widget.label,
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: widget.isSelected
                                ? Colors.redAccent
                                : _textPrimary)),
                    Text(widget.sub,
                        style: const TextStyle(
                            fontSize: 10, color: _textSecondary)),
                  ],
                ),
              ),
              if (widget.isSelected)
                Container(
                  width: 16,
                  height: 16,
                  decoration: const BoxDecoration(
                      color: Colors.redAccent, shape: BoxShape.circle),
                  child: const Icon(Icons.check_rounded,
                      color: Colors.white, size: 10),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  NOTIFICATION PREVIEW (updated with image)
// ══════════════════════════════════════════════════════════════════════════════
class _NotifPreview extends StatelessWidget {
  final String title, body;
  final String? imageUrl;
  final Map<String, dynamic> typeData;
  const _NotifPreview(
      {required this.title,
      required this.body,
      this.imageUrl,
      required this.typeData});

  @override
  Widget build(BuildContext context) {
    final color = typeData['color'] as Color;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _surface2,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(
                width: 8,
                height: 8,
                decoration:
                    BoxDecoration(color: color, shape: BoxShape.circle)),
            const SizedBox(width: 8),
            const Text('Preview — Phone Notification',
                style: TextStyle(
                    color: _textSecondary,
                    fontSize: 10,
                    fontWeight: FontWeight.w600)),
          ]),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: _surface3,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: _border2),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: Icon(typeData['icon'] as IconData,
                        color: color, size: 18),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title.isEmpty ? 'Notification Title' : title,
                          style: TextStyle(
                            color: title.isEmpty ? _textMuted : _textPrimary,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          body.isEmpty
                              ? 'Your message will appear here...'
                              : body,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: body.isEmpty ? _textMuted : _textSecondary,
                            fontSize: 11,
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ]),
                // ── Big picture preview (NEW) ──────────────────────────────
                if (imageUrl != null && imageUrl!.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      imageUrl!,
                      height: 100,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        height: 60,
                        decoration: BoxDecoration(
                            color: _surface2,
                            borderRadius: BorderRadius.circular(8)),
                        child: const Center(
                            child: Icon(Icons.broken_image_rounded,
                                color: _textMuted, size: 20)),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  HISTORY PANEL
// ══════════════════════════════════════════════════════════════════════════════
class _HistoryPanel extends StatelessWidget {
  const _HistoryPanel();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          height: 72,
          padding: const EdgeInsets.symmetric(horizontal: 24),
          decoration: const BoxDecoration(
            color: _surface,
            border: Border(bottom: BorderSide(color: _border)),
          ),
          child: const Row(children: [
            Icon(Icons.history_rounded, color: _textSecondary, size: 16),
            SizedBox(width: 10),
            Text('Sent History',
                style: TextStyle(
                    color: _textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w700)),
          ]),
        ),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('notifications')
                .doc('queue')
                .collection('pending')
                .orderBy('createdAt', descending: true)
                .limit(50)
                .snapshots(),
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Center(
                    child: CircularProgressIndicator(
                        color: Colors.redAccent, strokeWidth: 2));
              }
              final docs = snap.data?.docs ?? [];
              if (docs.isEmpty) return const _EmptyHistory();
              return ListView.separated(
                padding: const EdgeInsets.all(20),
                itemCount: docs.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (_, i) => _HistoryCard(doc: docs[i]),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _HistoryCard extends StatefulWidget {
  final QueryDocumentSnapshot doc;
  const _HistoryCard({required this.doc});

  @override
  State<_HistoryCard> createState() => _HistoryCardState();
}

class _HistoryCardState extends State<_HistoryCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final data = widget.doc.data() as Map<String, dynamic>;
    final status = data['status'] as String? ?? 'pending';
    final type = data['type'] as String? ?? 'custom';
    final imageUrl = data['imageUrl'] as String?;
    final typeData = _notifTypes.firstWhere((t) => t['id'] == type,
        orElse: () => _notifTypes.last);
    final color = typeData['color'] as Color;
    final ts = data['createdAt'] as Timestamp?;
    final timeStr = ts != null ? _formatTime(ts.toDate()) : '—';

    Color statusColor;
    IconData statusIcon;
    switch (status) {
      case 'sent':
        statusColor = const Color(0xFF4CAF50);
        statusIcon = Icons.check_circle_rounded;
        break;
      case 'failed':
        statusColor = Colors.redAccent;
        statusIcon = Icons.error_rounded;
        break;
      default:
        statusColor = Colors.orange;
        statusIcon = Icons.schedule_rounded;
    }

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 130),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: _hovered ? _surface2 : _surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _hovered ? _border2 : _border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(typeData['icon'] as IconData,
                      color: color, size: 16),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(data['title'] as String? ?? '',
                          style: const TextStyle(
                              color: _textPrimary,
                              fontSize: 12,
                              fontWeight: FontWeight.w700)),
                      const SizedBox(height: 3),
                      Text(data['body'] as String? ?? '',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              color: _textSecondary, fontSize: 11)),
                      const SizedBox(height: 6),
                      Row(children: [
                        Icon(Icons.access_time_rounded,
                            size: 10, color: _textMuted),
                        const SizedBox(width: 4),
                        Text(timeStr,
                            style: const TextStyle(
                                color: _textMuted, fontSize: 10)),
                        const SizedBox(width: 10),
                        Icon(Icons.people_rounded, size: 10, color: _textMuted),
                        const SizedBox(width: 4),
                        Text(data['topic'] as String? ?? 'cricket_notification',
                            style: const TextStyle(
                                color: _textMuted, fontSize: 10)),
                        if (imageUrl != null && imageUrl.isNotEmpty) ...[
                          const SizedBox(width: 10),
                          Icon(Icons.image_rounded,
                              size: 10,
                              color: Colors.blueAccent.withOpacity(0.6)),
                          const SizedBox(width: 3),
                          Text('Image',
                              style: TextStyle(
                                  color: Colors.blueAccent.withOpacity(0.6),
                                  fontSize: 10)),
                        ],
                      ]),
                    ],
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(6),
                        border:
                            Border.all(color: statusColor.withOpacity(0.25)),
                      ),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(statusIcon, size: 10, color: statusColor),
                        const SizedBox(width: 4),
                        Text(status[0].toUpperCase() + status.substring(1),
                            style: TextStyle(
                                color: statusColor,
                                fontSize: 9,
                                fontWeight: FontWeight.w700)),
                      ]),
                    ),
                    // ── Delete button ──────────────────────────────────────
                    if (_hovered) ...[
                      const SizedBox(width: 6),
                      _DeleteBtn(onTap: () => _deleteDoc()),
                    ],
                  ],
                ),
              ],
            ),
            // ── Thumbnail in history (NEW) ─────────────────────────────────
            if (imageUrl != null && imageUrl.isNotEmpty) ...[
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  imageUrl,
                  height: 70,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _deleteDoc() async {
    await widget.doc.reference.delete();
  }

  String _formatTime(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  CONFIRM SEND DIALOG
// ══════════════════════════════════════════════════════════════════════════════
class _ConfirmSendDialog extends StatelessWidget {
  const _ConfirmSendDialog();

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
            Row(children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: Colors.redAccent.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: const Icon(Icons.send_rounded,
                    color: Colors.redAccent, size: 18),
              ),
              const SizedBox(width: 12),
              const Text('Send Notification',
                  style: TextStyle(
                      color: _textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w700)),
            ]),
            const SizedBox(height: 16),
            const Text(
              'This notification will be sent to all subscribed users immediately. Are you sure?',
              style:
                  TextStyle(color: _textSecondary, fontSize: 13, height: 1.6),
            ),
            const SizedBox(height: 24),
            Row(children: [
              Expanded(child: _CancelBtn(onTap: () => Navigator.pop(context))),
              const SizedBox(width: 12),
              Expanded(
                  child: _ConfirmBtn(
                      label: 'Yes, Send',
                      enabled: true,
                      onTap: () => Navigator.pop(context, true))),
            ]),
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  SHARED WIDGETS
// ══════════════════════════════════════════════════════════════════════════════
class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) => Text(text,
      style: const TextStyle(
          color: _textSecondary,
          fontSize: 11,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.3));
}

class _TemplateChip extends StatefulWidget {
  final String label;
  final VoidCallback onTap;
  const _TemplateChip({required this.label, required this.onTap});

  @override
  State<_TemplateChip> createState() => _TemplateChipState();
}

class _TemplateChipState extends State<_TemplateChip> {
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
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: _hovered ? Colors.redAccent.withOpacity(0.08) : _surface2,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
                color: _hovered ? Colors.redAccent.withOpacity(0.3) : _border),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.flash_on_rounded,
                size: 11, color: Colors.orangeAccent),
            const SizedBox(width: 5),
            Text(widget.label,
                style: const TextStyle(
                    color: _textSecondary,
                    fontSize: 11,
                    fontWeight: FontWeight.w500)),
          ]),
        ),
      ),
    );
  }
}

class _StatusBanner extends StatelessWidget {
  final String message;
  const _StatusBanner({required this.message});

  @override
  Widget build(BuildContext context) {
    final isError = message.startsWith('Error');
    final color = isError ? Colors.redAccent : const Color(0xFF4CAF50);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Row(children: [
        Icon(isError ? Icons.error_rounded : Icons.check_circle_rounded,
            color: color, size: 16),
        const SizedBox(width: 10),
        Expanded(
            child: Text(message,
                style: TextStyle(
                    color: color, fontSize: 12, fontWeight: FontWeight.w600))),
      ]),
    );
  }
}

class _FormField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final IconData? icon;
  final int maxLines;
  final TextInputType? keyboardType;
  final ValueChanged<String>? onChanged;

  const _FormField({
    required this.controller,
    required this.hint,
    this.icon,
    this.maxLines = 1,
    this.keyboardType,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      onChanged: onChanged,
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
  const _ConfirmBtn(
      {required this.label, required this.enabled, required this.onTap});

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
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 13),
          decoration: BoxDecoration(
            color: widget.enabled
                ? _hovered
                    ? Colors.redAccent.withOpacity(0.82)
                    : Colors.redAccent
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

// ══════════════════════════════════════════════════════════════════════════════
//  DELETE BUTTON
// ══════════════════════════════════════════════════════════════════════════════
class _DeleteBtn extends StatefulWidget {
  final VoidCallback onTap;
  const _DeleteBtn({required this.onTap});

  @override
  State<_DeleteBtn> createState() => _DeleteBtnState();
}

class _DeleteBtnState extends State<_DeleteBtn> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Delete',
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: _hovered ? Colors.redAccent.withOpacity(0.12) : _surface3,
              borderRadius: BorderRadius.circular(7),
              border: Border.all(
                color: _hovered ? Colors.redAccent.withOpacity(0.35) : _border,
              ),
            ),
            child: Icon(Icons.delete_rounded,
                size: 13, color: _hovered ? Colors.redAccent : _textMuted),
          ),
        ),
      ),
    );
  }
}

class _EmptyHistory extends StatelessWidget {
  const _EmptyHistory();

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
            child: const Icon(Icons.notifications_off_rounded,
                color: _textMuted, size: 28),
          ),
          const SizedBox(height: 16),
          const Text('No notifications sent yet',
              style: TextStyle(
                  color: _textPrimary,
                  fontSize: 15,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          const Text('Sent notifications will appear here.',
              style: TextStyle(color: _textSecondary, fontSize: 12)),
        ],
      ),
    );
  }
}
