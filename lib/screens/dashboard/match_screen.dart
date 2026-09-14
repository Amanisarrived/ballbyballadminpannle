import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cricket_admin/services/featured_match_service.dart';
import 'package:flutter/material.dart';

// ── Theme constants ────────────────────────────────────────
const _bg = Color(0xFF0D0D0D);
const _surface = Color(0xFF141414);
const _surface2 = Color(0xFF1A1A1A);
const _border = Color(0xFF232323);
const _textPrimary = Color(0xFFE8E8E8);
const _textSecondary = Color(0xFF666666);
const _textMuted = Color(0xFF444444);

// ── Pitch type config ──────────────────────────────────────
const _pitchTypes = ['batting', 'bowling', 'spin', 'balanced'];

Color _pitchColor(String type) {
  switch (type) {
    case 'batting':
      return Color(0xFF4FC3F7);
    case 'bowling':
      return Color(0xFFFF8A65);
    case 'spin':
      return Color(0xFFFFD54F);
    case 'balanced':
      return Color(0xFF81C784);
    default:
      return Color(0xFF666666);
  }
}

IconData _pitchIcon(String type) {
  switch (type) {
    case 'batting':
      return Icons.sports_cricket_rounded;
    case 'bowling':
      return Icons.trip_origin_rounded;
    case 'spin':
      return Icons.rotate_right_rounded;
    case 'balanced':
      return Icons.balance_rounded;
    default:
      return Icons.grass_rounded;
  }
}

String _pitchLabel(String type) => type[0].toUpperCase() + type.substring(1);

// ─────────────────────────────────────────────────────────────
//  MatchScreen
// ─────────────────────────────────────────────────────────────
class MatchScreen extends StatefulWidget {
  const MatchScreen({super.key});

  @override
  State<MatchScreen> createState() => _MatchScreenState();
}

class _MatchScreenState extends State<MatchScreen> {
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
                    Text(
                      'Matches',
                      style: TextStyle(
                        color: _textPrimary,
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.4,
                      ),
                    ),
                    SizedBox(height: 3),
                    Text(
                      'Manage and schedule cricket matches',
                      style: TextStyle(color: _textSecondary, fontSize: 13),
                    ),
                  ],
                ),
                const Spacer(),
                _AddMatchButton(
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
                  ? _AddMatchForm(
                      onSaved: () => setState(() => _showAddForm = false),
                      onCancel: () => setState(() => _showAddForm = false),
                    )
                  : const SizedBox.shrink(),
            ),
            Expanded(child: _MatchList()),
          ],
        ),
      ),
    );
  }
}

// ── Add match button ───────────────────────────────────────
class _AddMatchButton extends StatefulWidget {
  final bool isOpen;
  final VoidCallback onTap;
  const _AddMatchButton({required this.isOpen, required this.onTap});

  @override
  State<_AddMatchButton> createState() => _AddMatchButtonState();
}

class _AddMatchButtonState extends State<_AddMatchButton> {
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
                child: Icon(
                  Icons.add_rounded,
                  color: widget.isOpen ? _textSecondary : Colors.white,
                  size: 18,
                ),
              ),
              const SizedBox(width: 7),
              Text(
                widget.isOpen ? 'Cancel' : 'Add Match',
                style: TextStyle(
                  color: widget.isOpen ? _textSecondary : Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  Add Match Form
// ─────────────────────────────────────────────────────────────
class _AddMatchForm extends StatefulWidget {
  final VoidCallback onSaved;
  final VoidCallback onCancel;
  const _AddMatchForm({required this.onSaved, required this.onCancel});

  @override
  State<_AddMatchForm> createState() => _AddMatchFormState();
}

class _AddMatchFormState extends State<_AddMatchForm> {
  final _titleCtrl = TextEditingController();
  final _venueCtrl = TextEditingController();
  final _seriesCtrl = TextEditingController();
  final _pitchNoteCtrl = TextEditingController(); // NEW

  String _format = 't20';
  String _status = 'upcoming';
  String _pitchType = 'batting'; // NEW
  DateTime _matchDate = DateTime.now();
  TimeOfDay _matchTime = TimeOfDay.now();
  bool _saving = false;
  String? _error;

  final _formats = ['t20', 'odi', 'test', 't10'];
  final _statuses = ['upcoming', 'live', 'completed'];

  @override
  void dispose() {
    _titleCtrl.dispose();
    _venueCtrl.dispose();
    _seriesCtrl.dispose();
    _pitchNoteCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _matchDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      builder: (ctx, child) => Theme(
        data: ThemeData.dark().copyWith(
          colorScheme: const ColorScheme.dark(
            primary: Colors.redAccent,
            surface: Color(0xFF1A1A1A),
          ),
          dialogBackgroundColor: const Color(0xFF141414),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _matchDate = picked);
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _matchTime,
      builder: (ctx, child) => Theme(
        data: ThemeData.dark().copyWith(
          colorScheme: const ColorScheme.dark(
            primary: Colors.redAccent,
            surface: Color(0xFF1A1A1A),
            onSurface: Color(0xFFE8E8E8),
          ),
          dialogBackgroundColor: const Color(0xFF141414),
          timePickerTheme: const TimePickerThemeData(
            backgroundColor: Color(0xFF141414),
            hourMinuteColor: Color(0xFF1A1A1A),
            hourMinuteTextColor: Color(0xFFE8E8E8),
            dayPeriodColor: Color(0xFF1A1A1A),
            dayPeriodTextColor: Color(0xFFE8E8E8),
            dialBackgroundColor: Color(0xFF1A1A1A),
            dialHandColor: Colors.redAccent,
            dialTextColor: Color(0xFFE8E8E8),
            entryModeIconColor: Color(0xFF666666),
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _matchTime = picked);
  }

  String get _formattedTime {
    final h = _matchTime.hour.toString().padLeft(2, '0');
    final m = _matchTime.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  Future<void> _save() async {
    if (_titleCtrl.text.trim().isEmpty || _venueCtrl.text.trim().isEmpty) {
      setState(() => _error = 'Title and venue are required.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      final dateStr =
          '${_matchDate.year}-${_matchDate.month.toString().padLeft(2, '0')}-${_matchDate.day.toString().padLeft(2, '0')}';

      await FeaturedMatchService.saveMatchMeta(
        title: _titleCtrl.text.trim(),
        format: _format,
        venue: _venueCtrl.text.trim(),
        series: _seriesCtrl.text.trim(),
        matchDate: dateStr,
        matchTime: _formattedTime,
        status: _status,
        matchId: '',
        pitchType: _pitchType, // NEW
        pitchNote: _pitchNoteCtrl.text.trim(), // NEW
      );

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
          color: _error != null ? Colors.redAccent.withOpacity(0.4) : _border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.add_circle_outline_rounded,
                  color: Colors.redAccent, size: 16),
              SizedBox(width: 8),
              Text(
                'New Match',
                style: TextStyle(
                  color: _textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // ── Row 1: Title + Venue + Series ──────────────
          Row(
            children: [
              Expanded(
                child: _FormField(
                  label: 'Match Title',
                  hint: 'e.g. IND vs AUS',
                  controller: _titleCtrl,
                  icon: Icons.title_rounded,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _FormField(
                  label: 'Venue',
                  hint: 'e.g. Wankhede Stadium',
                  controller: _venueCtrl,
                  icon: Icons.stadium_rounded,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _FormField(
                  label: 'Series',
                  hint: 'e.g. Asia Cup 2025',
                  controller: _seriesCtrl,
                  icon: Icons.emoji_events_rounded,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // ── Row 2: Format + Status + Date + Time ───────
          Row(
            children: [
              Expanded(
                child: _DropdownField(
                  label: 'Format',
                  value: _format,
                  items: _formats,
                  icon: Icons.format_list_bulleted_rounded,
                  onChanged: (v) => setState(() => _format = v!),
                  displayBuilder: (v) => v.toUpperCase(),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _DropdownField(
                  label: 'Status',
                  value: _status,
                  items: _statuses,
                  icon: Icons.info_outline_rounded,
                  onChanged: (v) => setState(() => _status = v!),
                  displayBuilder: (v) => _statusLabel(v),
                  colorBuilder: (v) => _statusColor(v),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _DateField(
                  label: 'Match Date',
                  date: _matchDate,
                  onTap: _pickDate,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _TimeField(
                  label: 'Match Time',
                  time: _matchTime,
                  onTap: _pickTime,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // ── Row 3: Pitch Type + Pitch Note ─────────────
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Pitch type selector
              Expanded(
                flex: 2,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Pitch Type',
                      style: TextStyle(
                        color: _textSecondary,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.3,
                      ),
                    ),
                    const SizedBox(height: 7),
                    Row(
                      children: _pitchTypes.map((type) {
                        final sel = _pitchType == type;
                        final color = _pitchColor(type);
                        return Expanded(
                          child: Padding(
                            padding: EdgeInsets.only(
                                right: type == _pitchTypes.last ? 0 : 8),
                            child: _PitchTypeChip(
                              type: type,
                              color: color,
                              isSelected: sel,
                              onTap: () => setState(() => _pitchType = type),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),

              // Pitch note
              Expanded(
                child: _FormField(
                  label: 'Pitch Note',
                  hint: 'e.g. Flat surface, high scoring expected, dew likely',
                  controller: _pitchNoteCtrl,
                  icon: Icons.grass_rounded,
                ),
              ),
            ],
          ),

          if (_error != null) ...[
            const SizedBox(height: 14),
            Container(
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
                  Text(
                    _error!,
                    style:
                        const TextStyle(color: Color(0xFFFF8A80), fontSize: 12),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              _GhostButton(label: 'Cancel', onTap: widget.onCancel),
              const SizedBox(width: 12),
              _SaveButton(saving: _saving, onTap: _save),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Pitch type chip ────────────────────────────────────────
class _PitchTypeChip extends StatefulWidget {
  final String type;
  final Color color;
  final bool isSelected;
  final VoidCallback onTap;
  const _PitchTypeChip({
    required this.type,
    required this.color,
    required this.isSelected,
    required this.onTap,
  });

  @override
  State<_PitchTypeChip> createState() => _PitchTypeChipState();
}

class _PitchTypeChipState extends State<_PitchTypeChip> {
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
                  widget.isSelected ? widget.color.withOpacity(0.45) : _border,
              width: 1.5,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                _pitchIcon(widget.type),
                size: 15,
                color: widget.isSelected
                    ? widget.color
                    : _hovered
                        ? _textSecondary
                        : _textMuted,
              ),
              const SizedBox(height: 4),
              Text(
                _pitchLabel(widget.type),
                style: TextStyle(
                  color: widget.isSelected
                      ? widget.color
                      : _hovered
                          ? _textSecondary
                          : _textMuted,
                  fontSize: 9,
                  fontWeight:
                      widget.isSelected ? FontWeight.w600 : FontWeight.w400,
                ),
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Match list ─────────────────────────────────────────────
class _MatchList extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('matches')
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(
                color: Colors.redAccent, strokeWidth: 2),
          );
        }
        if (!snap.hasData || snap.data!.docs.isEmpty) {
          return _EmptyState();
        }
        final docs = snap.data!.docs;
        return ListView.separated(
          itemCount: docs.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (context, i) {
            final data = docs[i].data() as Map<String, dynamic>;
            final meta = data['meta'] as Map<String, dynamic>? ?? {};
            return _MatchCard(
              docId: docs[i].id,
              title: meta['title'] ?? '—',
              format: meta['format'] ?? '—',
              venue: meta['venue'] ?? '—',
              series: meta['series'] ?? '',
              matchDate: meta['matchDate'] ?? '—',
              matchTime: meta['matchTime'] ?? '',
              status: meta['status'] ?? 'upcoming',
              pitchType: meta['pitchType'] ?? '', // NEW
              pitchNote: meta['pitchNote'] ?? '', // NEW
            );
          },
        );
      },
    );
  }
}

// ── Match card ─────────────────────────────────────────────
class _MatchCard extends StatefulWidget {
  final String docId,
      title,
      format,
      venue,
      series,
      matchDate,
      matchTime,
      status,
      pitchType,
      pitchNote;

  const _MatchCard({
    required this.docId,
    required this.title,
    required this.format,
    required this.venue,
    required this.series,
    required this.matchDate,
    required this.matchTime,
    required this.status,
    required this.pitchType, // NEW
    required this.pitchNote, // NEW
  });

  @override
  State<_MatchCard> createState() => _MatchCardState();
}

class _MatchCardState extends State<_MatchCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final statusColor = _statusColor(widget.status);
    final statusLabel = _statusLabel(widget.status);

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          color: _hovered ? _surface2 : _surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: _hovered ? const Color(0xFF2E2E2E) : _border,
          ),
        ),
        child: Row(
          children: [
            // Format badge
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: Colors.redAccent.withOpacity(0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.redAccent.withOpacity(0.15)),
              ),
              child: Center(
                child: Text(
                  widget.format.toUpperCase(),
                  style: const TextStyle(
                    color: Colors.redAccent,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 16),

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.title,
                    style: const TextStyle(
                      color: _textPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.2,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 12,
                    runSpacing: 4,
                    children: [
                      if (widget.series.isNotEmpty)
                        _MetaChip(
                          icon: Icons.emoji_events_rounded,
                          label: widget.series,
                          highlight: true,
                        ),
                      _MetaChip(
                        icon: Icons.stadium_rounded,
                        label: widget.venue,
                      ),
                      _MetaChip(
                        icon: Icons.calendar_today_rounded,
                        label: widget.matchDate,
                      ),
                      if (widget.matchTime.isNotEmpty)
                        _MetaChip(
                          icon: Icons.access_time_rounded,
                          label: widget.matchTime,
                        ),
                      // NEW — pitch type chip
                      if (widget.pitchType.isNotEmpty)
                        _MetaChip(
                          icon: _pitchIcon(widget.pitchType),
                          label: _pitchLabel(widget.pitchType),
                          color: _pitchColor(widget.pitchType),
                        ),
                    ],
                  ),
                  // NEW — pitch note if present
                  if (widget.pitchNote.isNotEmpty) ...[
                    const SizedBox(height: 5),
                    Row(
                      children: [
                        const Icon(Icons.grass_rounded,
                            color: _textMuted, size: 11),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            widget.pitchNote,
                            style: const TextStyle(
                                color: _textMuted,
                                fontSize: 11,
                                fontStyle: FontStyle.italic),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),

            // Status badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: statusColor.withOpacity(0.25)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (widget.status == 'live')
                    Container(
                      width: 6,
                      height: 6,
                      margin: const EdgeInsets.only(right: 5),
                      decoration: BoxDecoration(
                        color: statusColor,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                              color: statusColor.withOpacity(0.6),
                              blurRadius: 4)
                        ],
                      ),
                    ),
                  Text(
                    statusLabel,
                    style: TextStyle(
                      color: statusColor,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.3,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            _DeleteButton(docId: widget.docId, title: widget.title),
          ],
        ),
      ),
    );
  }
}

// ── Meta chip ──────────────────────────────────────────────
class _MetaChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool highlight;
  final Color? color;

  const _MetaChip({
    required this.icon,
    required this.label,
    this.highlight = false,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final c = color ?? (highlight ? Colors.redAccent : null);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon,
            color: c != null ? c.withOpacity(0.7) : _textMuted, size: 12),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            color: c != null ? c.withOpacity(0.85) : _textSecondary,
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}

// ── Delete button ──────────────────────────────────────────
class _DeleteButton extends StatefulWidget {
  final String docId, title;
  const _DeleteButton({required this.docId, required this.title});

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
          child: Icon(
            Icons.delete_outline_rounded,
            color: _hovered ? Colors.redAccent : _textMuted,
            size: 17,
          ),
        ),
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => _DeleteDialog(title: widget.title),
    );
    if (confirm == true) {
      await FirebaseFirestore.instance
          .collection('matches')
          .doc(widget.docId)
          .delete();
    }
  }
}

// ── Delete dialog ──────────────────────────────────────────
class _DeleteDialog extends StatelessWidget {
  final String title;
  const _DeleteDialog({required this.title});

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
            const Text(
              'Delete match?',
              style: TextStyle(
                color: _textPrimary,
                fontSize: 17,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '"$title" will be permanently deleted.',
              style: const TextStyle(
                  color: _textSecondary, fontSize: 13, height: 1.5),
            ),
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
    return LayoutBuilder(
      builder: (context, constraints) {
        final tight = constraints.maxHeight < 140;
        return Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                if (!tight) ...[
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: _surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: _border),
                    ),
                    child: const Icon(Icons.calendar_today_rounded,
                        color: _textMuted, size: 20),
                  ),
                  const SizedBox(height: 10),
                ],
                const Text(
                  'No matches yet',
                  style: TextStyle(
                      color: _textPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w600),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 4),
                const Text(
                  'Click "Add Match" to get started.',
                  style: TextStyle(color: _textSecondary, fontSize: 12),
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

// ── Reusable form widgets ──────────────────────────────────
class _FormField extends StatefulWidget {
  final String label, hint;
  final TextEditingController controller;
  final IconData icon;

  const _FormField({
    required this.label,
    required this.hint,
    required this.controller,
    required this.icon,
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

class _DropdownField extends StatelessWidget {
  final String label, value;
  final List<String> items;
  final IconData icon;
  final ValueChanged<String?> onChanged;
  final String Function(String) displayBuilder;
  final Color Function(String)? colorBuilder;

  const _DropdownField({
    required this.label,
    required this.value,
    required this.items,
    required this.icon,
    required this.onChanged,
    required this.displayBuilder,
    this.colorBuilder,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
                color: _textSecondary,
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.3)),
        const SizedBox(height: 7),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: _surface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: _border, width: 1.5),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: value,
              isExpanded: true,
              dropdownColor: const Color(0xFF1E1E1E),
              icon: const Icon(Icons.keyboard_arrow_down_rounded,
                  color: _textMuted, size: 18),
              style: TextStyle(
                color:
                    colorBuilder != null ? colorBuilder!(value) : _textPrimary,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
              items: items
                  .map((item) => DropdownMenuItem(
                        value: item,
                        child: Text(
                          displayBuilder(item),
                          style: TextStyle(
                            color: colorBuilder != null
                                ? colorBuilder!(item)
                                : _textPrimary,
                            fontSize: 13,
                          ),
                        ),
                      ))
                  .toList(),
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }
}

class _DateField extends StatefulWidget {
  final String label;
  final DateTime date;
  final VoidCallback onTap;
  const _DateField(
      {required this.label, required this.date, required this.onTap});

  @override
  State<_DateField> createState() => _DateFieldState();
}

class _DateFieldState extends State<_DateField> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final formatted =
        '${widget.date.year}-${widget.date.month.toString().padLeft(2, '0')}-${widget.date.day.toString().padLeft(2, '0')}';
    return _PickerField(
      label: widget.label,
      value: formatted,
      icon: Icons.calendar_today_rounded,
      hovered: _hovered,
      onEnter: () => setState(() => _hovered = true),
      onExit: () => setState(() => _hovered = false),
      onTap: widget.onTap,
    );
  }
}

class _TimeField extends StatefulWidget {
  final String label;
  final TimeOfDay time;
  final VoidCallback onTap;
  const _TimeField(
      {required this.label, required this.time, required this.onTap});

  @override
  State<_TimeField> createState() => _TimeFieldState();
}

class _TimeFieldState extends State<_TimeField> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final h = widget.time.hour.toString().padLeft(2, '0');
    final m = widget.time.minute.toString().padLeft(2, '0');
    return _PickerField(
      label: widget.label,
      value: '$h:$m',
      icon: Icons.access_time_rounded,
      hovered: _hovered,
      onEnter: () => setState(() => _hovered = true),
      onExit: () => setState(() => _hovered = false),
      onTap: widget.onTap,
    );
  }
}

class _PickerField extends StatelessWidget {
  final String label, value;
  final IconData icon;
  final bool hovered;
  final VoidCallback onEnter, onExit, onTap;

  const _PickerField({
    required this.label,
    required this.value,
    required this.icon,
    required this.hovered,
    required this.onEnter,
    required this.onExit,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
                color: _textSecondary,
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.3)),
        const SizedBox(height: 7),
        MouseRegion(
          onEnter: (_) => onEnter(),
          onExit: (_) => onExit(),
          cursor: SystemMouseCursors.click,
          child: GestureDetector(
            onTap: onTap,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
              decoration: BoxDecoration(
                color: hovered ? _surface2 : _surface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: hovered ? Colors.redAccent.withOpacity(0.4) : _border,
                  width: 1.5,
                ),
              ),
              child: Row(
                children: [
                  Icon(icon,
                      color: hovered ? Colors.redAccent : _textMuted, size: 15),
                  const SizedBox(width: 10),
                  Text(value,
                      style:
                          const TextStyle(color: _textPrimary, fontSize: 13)),
                ],
              ),
            ),
          ),
        ),
      ],
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
  final bool saving;
  final VoidCallback onTap;
  const _SaveButton({required this.saving, required this.onTap});

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
                      color: Colors.white, strokeWidth: 2),
                )
              : const Text(
                  'Save Match',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
        ),
      ),
    );
  }
}

// ── Helpers ────────────────────────────────────────────────
Color _statusColor(String status) {
  switch (status) {
    case 'live':
      return const Color(0xFF4CAF50);
    case 'completed':
      return const Color(0xFF888888);
    default:
      return const Color(0xFFFFB300);
  }
}

String _statusLabel(String status) {
  switch (status) {
    case 'live':
      return 'Live';
    case 'completed':
      return 'Completed';
    default:
      return 'Upcoming';
  }
}
