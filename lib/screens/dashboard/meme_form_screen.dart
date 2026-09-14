import 'package:cricket_admin/services/meme_admin_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// ─────────────────────────────────────────────────────────────
//  MEME FORM SCREEN — Add / Edit
// ─────────────────────────────────────────────────────────────

class MemeFormScreen extends StatefulWidget {
  final MemeModel? meme;
  const MemeFormScreen({super.key, this.meme});

  @override
  State<MemeFormScreen> createState() => _MemeFormScreenState();
}

class _MemeFormScreenState extends State<MemeFormScreen> {
  static const _bg = Color(0xFF0D0D0D);
  static const _surface = Color(0xFF141414);
  static const _border = Color(0xFF232323);
  static const _red = Color(0xFFCC0000);

  bool get _isEdit => widget.meme != null;
  bool _saving = false;

  late final TextEditingController _mediaUrl;
  late final TextEditingController _thumbnailUrl;
  late final TextEditingController _caption;
  late final TextEditingController _tagInput;
  late final TextEditingController _order;

  String _mediaType = 'image';
  bool _isActive = true;
  bool _isPinned = false;
  List<String> _tags = [];

  static const _popularTags = [
    'IPL',
    'RCB',
    'CSK',
    'MI',
    'GT',
    'KKR',
    'Funny',
    'Rohit',
    'Virat',
    'Dhoni',
    'Cricket',
  ];

  @override
  void initState() {
    super.initState();
    final m = widget.meme;
    _mediaUrl = TextEditingController(text: m?.mediaUrl ?? '');
    _thumbnailUrl = TextEditingController(text: m?.thumbnailUrl ?? '');
    _caption = TextEditingController(text: m?.caption ?? '');
    _tagInput = TextEditingController();
    _order = TextEditingController(text: m != null ? m.order.toString() : '0');

    if (m != null) {
      _mediaType = m.mediaType;
      _isActive = m.isActive;
      _isPinned = m.isPinned;
      _tags = List.from(m.tags);
    }
  }

  @override
  void dispose() {
    _mediaUrl.dispose();
    _thumbnailUrl.dispose();
    _caption.dispose();
    _tagInput.dispose();
    _order.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_mediaUrl.text.trim().isEmpty) {
      _showSnack('Media URL required', isError: true);
      return;
    }
    setState(() => _saving = true);
    try {
      await MemeAdminService.saveMeme(
        existingId: _isEdit ? widget.meme!.id : null,
        mediaUrl: _mediaUrl.text.trim(),
        mediaType: _mediaType,
        thumbnailUrl: _thumbnailUrl.text.trim(),
        caption: _caption.text.trim(),
        tags: _tags,
        isActive: _isActive,
        isPinned: _isPinned,
        order: int.tryParse(_order.text.trim()) ?? 0,
      );
      if (mounted) {
        _showSnack(_isEdit ? 'Meme updated ✓' : 'Meme added ✓');
        await Future.delayed(const Duration(milliseconds: 600));
        if (mounted) Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) _showSnack('Failed: $e', isError: true);
    }
    if (mounted) setState(() => _saving = false);
  }

  void _showSnack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(
        content: Text(msg, style: const TextStyle(color: Colors.white)),
        backgroundColor:
            isError ? const Color(0xFFB71C1C) : const Color(0xFF2E7D32),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        duration: const Duration(seconds: 2),
      ));
  }

  void _addTag(String tag) {
    final t = tag.trim().replaceAll('#', '');
    if (t.isEmpty || _tags.contains(t)) return;
    setState(() {
      _tags.add(t);
      _tagInput.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _surface,
        elevation: 0,
        title: Text(_isEdit ? 'Edit Meme' : 'Add Meme',
            style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w700)),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: _border),
        ),
      ),
      body: Column(children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // ── Media Type ────────────────────────────
              _SectionLabel('Media Type'),
              const SizedBox(height: 10),
              Row(children: [
                Expanded(
                    child: _TypeBtn(
                  label: '🖼️ Image',
                  selected: _mediaType == 'image',
                  onTap: () => setState(() => _mediaType = 'image'),
                )),
                const SizedBox(width: 10),
                Expanded(
                    child: _TypeBtn(
                  label: '🎬 Video',
                  selected: _mediaType == 'video',
                  onTap: () => setState(() => _mediaType = 'video'),
                )),
              ]),

              const SizedBox(height: 20),

              // ── Media URLs ────────────────────────────
              _SectionLabel('Media URLs'),
              const SizedBox(height: 10),
              _Field(
                ctrl: _mediaUrl,
                label: _mediaType == 'video' ? 'Video URL *' : 'Image URL *',
                hint: 'https://...',
              ),
              if (_mediaType == 'video')
                _Field(
                  ctrl: _thumbnailUrl,
                  label: 'Thumbnail URL',
                  hint: 'https://... (optional)',
                  required: false,
                ),

              // Preview
              if (_mediaUrl.text.isNotEmpty && _mediaType == 'image') ...[
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.network(
                    _mediaUrl.text,
                    height: 180,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      height: 80,
                      decoration: BoxDecoration(
                        color: const Color(0xFF1A1A1A),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Center(
                          child: Text('Invalid URL',
                              style: TextStyle(
                                  color: Colors.white.withAlpha(60)))),
                    ),
                  ),
                ),
              ],

              const SizedBox(height: 20),

              // ── Caption ───────────────────────────────
              _SectionLabel('Caption'),
              const SizedBox(height: 10),
              _Field(
                ctrl: _caption,
                label: 'Caption',
                hint: 'Jab RCB hare phir bhi... 😂',
                required: false,
                maxLines: 3,
              ),

              const SizedBox(height: 20),

              // ── Tags ──────────────────────────────────
              _SectionLabel('Tags'),
              const SizedBox(height: 10),

              // Popular tags
              Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _popularTags.map((t) {
                    final sel = _tags.contains(t);
                    return GestureDetector(
                      onTap: () {
                        HapticFeedback.selectionClick();
                        setState(() => sel ? _tags.remove(t) : _tags.add(t));
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: sel
                              ? _red.withAlpha(20)
                              : const Color(0xFF1A1A1A),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                              color: sel
                                  ? _red.withAlpha(80)
                                  : const Color(0xFF2A2A2A)),
                        ),
                        child: Text('#$t',
                            style: TextStyle(
                                color: sel ? _red : Colors.white38,
                                fontSize: 11,
                                fontWeight:
                                    sel ? FontWeight.w700 : FontWeight.w400)),
                      ),
                    );
                  }).toList()),

              const SizedBox(height: 10),

              // Custom tag input
              Row(children: [
                Expanded(
                    child: TextField(
                  controller: _tagInput,
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                  decoration: InputDecoration(
                    hintText: 'Custom tag...',
                    hintStyle: TextStyle(
                        color: Colors.white.withAlpha(40), fontSize: 13),
                    filled: true,
                    fillColor: _surface,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: _border)),
                    enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: _border)),
                    focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: _red)),
                  ),
                  onSubmitted: _addTag,
                )),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () => _addTag(_tagInput.text),
                  child: Container(
                    height: 42,
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    decoration: BoxDecoration(
                      color: _red,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Center(
                        child: Text('Add',
                            style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700))),
                  ),
                ),
              ]),

              // Selected tags
              if (_tags.isNotEmpty) ...[
                const SizedBox(height: 10),
                Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: _tags
                        .map((t) => GestureDetector(
                              onTap: () => setState(() => _tags.remove(t)),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 5),
                                decoration: BoxDecoration(
                                  color: _red.withAlpha(20),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(color: _red.withAlpha(60)),
                                ),
                                child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text('#$t',
                                          style: const TextStyle(
                                              color: _red,
                                              fontSize: 11,
                                              fontWeight: FontWeight.w600)),
                                      const SizedBox(width: 5),
                                      const Icon(Icons.close_rounded,
                                          size: 12, color: _red),
                                    ]),
                              ),
                            ))
                        .toList()),
              ],

              const SizedBox(height: 20),

              // ── Settings ──────────────────────────────
              _SectionLabel('Settings'),
              const SizedBox(height: 10),

              _Toggle(
                label: 'Active',
                subtitle: 'Show in app',
                value: _isActive,
                onChanged: (v) => setState(() => _isActive = v),
              ),
              const SizedBox(height: 8),
              _Toggle(
                label: 'Pinned',
                subtitle: 'Show at top always',
                value: _isPinned,
                onChanged: (v) => setState(() => _isPinned = v),
              ),
              const SizedBox(height: 10),
              _Field(
                ctrl: _order,
                label: 'Order (lower = first)',
                hint: '0',
                required: false,
                keyboardType: TextInputType.number,
              ),

              const SizedBox(height: 32),
            ],
          ),
        ),

        // ── Save button ───────────────────────────────
        Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          decoration: BoxDecoration(
            color: _surface,
            border: Border(top: BorderSide(color: _border)),
          ),
          child: GestureDetector(
            onTap: _saving ? null : _save,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                color: _saving ? _red.withAlpha(100) : _red,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                      color: _red.withAlpha(60),
                      blurRadius: 16,
                      offset: const Offset(0, 4))
                ],
              ),
              child: _saving
                  ? const Center(
                      child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white)))
                  : Text(_isEdit ? 'Update Meme' : 'Add Meme',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w700)),
            ),
          ),
        ),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  SHARED WIDGETS
// ─────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel(this.label);
  @override
  Widget build(BuildContext context) => Row(children: [
        Container(
            width: 3,
            height: 14,
            decoration: BoxDecoration(
                color: const Color(0xFFCC0000),
                borderRadius: BorderRadius.circular(2))),
        const SizedBox(width: 8),
        Text(label,
            style: TextStyle(
                color: Colors.white.withAlpha(200),
                fontSize: 13,
                fontWeight: FontWeight.w700)),
      ]);
}

class _Field extends StatelessWidget {
  final TextEditingController ctrl;
  final String label, hint;
  final bool required;
  final int maxLines;
  final TextInputType keyboardType;

  const _Field({
    required this.ctrl,
    required this.label,
    required this.hint,
    this.required = true,
    this.maxLines = 1,
    this.keyboardType = TextInputType.text,
  });

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label,
              style: TextStyle(
                  color: Colors.white.withAlpha(140),
                  fontSize: 11,
                  fontWeight: FontWeight.w500)),
          const SizedBox(height: 5),
          TextFormField(
            controller: ctrl,
            keyboardType: keyboardType,
            maxLines: maxLines,
            style: const TextStyle(color: Colors.white, fontSize: 13),
            validator: required
                ? (v) => (v == null || v.trim().isEmpty) ? 'Required' : null
                : null,
            onChanged: (_) {},
            decoration: InputDecoration(
              hintText: hint,
              hintStyle:
                  TextStyle(color: Colors.white.withAlpha(40), fontSize: 13),
              filled: true,
              fillColor: const Color(0xFF141414),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Color(0xFF232323))),
              enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Color(0xFF232323))),
              focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Color(0xFFCC0000))),
            ),
          ),
        ]),
      );
}

class _TypeBtn extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _TypeBtn(
      {required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: selected
                ? const Color(0xFFCC0000).withAlpha(20)
                : const Color(0xFF141414),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: selected
                  ? const Color(0xFFCC0000).withAlpha(80)
                  : const Color(0xFF232323),
            ),
          ),
          child: Center(
              child: Text(label,
                  style: TextStyle(
                      color:
                          selected ? const Color(0xFFCC0000) : Colors.white38,
                      fontSize: 13,
                      fontWeight:
                          selected ? FontWeight.w700 : FontWeight.w400))),
        ),
      );
}

class _Toggle extends StatelessWidget {
  final String label, subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;
  const _Toggle(
      {required this.label,
      required this.subtitle,
      required this.value,
      required this.onChanged});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFF141414),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFF232323)),
        ),
        child: Row(children: [
          Expanded(
              child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w600)),
              Text(subtitle,
                  style: TextStyle(
                      color: Colors.white.withAlpha(80), fontSize: 11)),
            ],
          )),
          Switch(
              value: value,
              onChanged: onChanged,
              activeColor: const Color(0xFFCC0000)),
        ]),
      );
}
