import 'package:cricket_admin/services/shop_banner_service.dart';
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

// ── Preset festival themes ────────────────────────────────
const _presets = [
  _Preset('Diwali 🪔', '#FF9900', 'Diwali Sale 🪔',
      'Light up your cricket game', 'Up to 40% off'),
  _Preset('IPL Season 🏏', '#4B8BF5', 'IPL Season 🏏',
      'Gear up like your favourite team', 'Shop the IPL edit'),
  _Preset('Holi 🎨', '#E1306C', 'Holi Offers 🎨',
      'Colorful deals on cricket gear', 'Up to 30% off'),
  _Preset('Independence Day 🇮🇳', '#FF9900', 'Independence Day 🇮🇳',
      'Proudly Indian. Play like one.', 'Special offers inside'),
  _Preset('Year-End Sale 🎄', '#10B981', 'Year-End Sale 🎄',
      'Best deals of the year', 'Up to 35% off'),
  _Preset('Default 🏏', '#CC0000', 'Cricket Store', 'Gear up for the game', ''),
];

class _Preset {
  final String label, hex, title, subtitle, badge;
  const _Preset(this.label, this.hex, this.title, this.subtitle, this.badge);
}

// ══════════════════════════════════════════════════════════
//  SCREEN
// ══════════════════════════════════════════════════════════
class ShopBannerScreen extends StatefulWidget {
  const ShopBannerScreen({super.key});

  @override
  State<ShopBannerScreen> createState() => _ShopBannerScreenState();
}

class _ShopBannerScreenState extends State<ShopBannerScreen> {
  // Controllers
  final _titleCtrl = TextEditingController();
  final _subtitleCtrl = TextEditingController();
  final _badgeCtrl = TextEditingController();
  final _imageCtrl = TextEditingController();
  final _colorCtrl = TextEditingController(text: '#CC0000');

  bool _isActive = false;
  bool _loading = true;
  bool _saving = false;
  bool _toggling = false;
  String? _error;
  String? _successMsg;

  @override
  void initState() {
    super.initState();
    _load();
    // Rebuild preview on any field change
    for (final c in [
      _titleCtrl,
      _subtitleCtrl,
      _badgeCtrl,
      _imageCtrl,
      _colorCtrl
    ]) {
      c.addListener(() => setState(() {}));
    }
  }

  @override
  void dispose() {
    for (final c in [
      _titleCtrl,
      _subtitleCtrl,
      _badgeCtrl,
      _imageCtrl,
      _colorCtrl
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final banner = await AdminShopBannerService.fetchBanner();
    if (!mounted) return;
    if (banner != null) {
      _titleCtrl.text = banner.title;
      _subtitleCtrl.text = banner.subtitle;
      _badgeCtrl.text = banner.badgeText;
      _imageCtrl.text = banner.imageUrl;
      _colorCtrl.text = banner.accentColorHex;
      _isActive = banner.isActive;
    }
    setState(() => _loading = false);
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() {
      _saving = true;
      _error = null;
      _successMsg = null;
    });

    final banner = AdminShopBanner(
      imageUrl: _imageCtrl.text.trim(),
      title: _titleCtrl.text.trim(),
      subtitle: _subtitleCtrl.text.trim(),
      badgeText: _badgeCtrl.text.trim(),
      accentColorHex: _colorCtrl.text.trim(),
      isActive: _isActive,
    );

    final ok = await AdminShopBannerService.saveBanner(banner);
    if (!mounted) return;
    setState(() {
      _saving = false;
      if (ok) {
        _successMsg = 'Banner saved successfully!';
      } else {
        _error = 'Failed to save. Check Firestore rules.';
      }
    });

    // Auto-clear message
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted)
        setState(() {
          _successMsg = null;
          _error = null;
        });
    });
  }

  Future<void> _toggleActive(bool value) async {
    setState(() => _toggling = true);
    final ok = await AdminShopBannerService.setActive(value);
    if (!mounted) return;
    if (ok) setState(() => _isActive = value);
    setState(() => _toggling = false);
  }

  void _applyPreset(_Preset p) {
    setState(() {
      _titleCtrl.text = p.title;
      _subtitleCtrl.text = p.subtitle;
      _badgeCtrl.text = p.badge;
      _colorCtrl.text = p.hex;
    });
  }

  Color get _accentColor {
    try {
      final c = _colorCtrl.text.replaceAll('#', '');
      if (c.length == 6) return Color(int.parse('FF$c', radix: 16));
    } catch (_) {}
    return const Color(0xFFCC0000);
  }

  bool get _valid => _titleCtrl.text.trim().isNotEmpty;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: Column(
        children: [
          // ── Header ────────────────────────────────────────
          _Header(
            isActive: _isActive,
            toggling: _toggling,
            onToggle: _toggleActive,
            onSave: _valid && !_saving ? _save : null,
            saving: _saving,
          ),

          if (_loading)
            const Expanded(
              child: Center(
                  child: CircularProgressIndicator(
                      color: Colors.redAccent, strokeWidth: 2)),
            )
          else
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Left: form ────────────────────────────
                  SizedBox(
                    width: 420,
                    child: _FormPanel(
                      titleCtrl: _titleCtrl,
                      subtitleCtrl: _subtitleCtrl,
                      badgeCtrl: _badgeCtrl,
                      imageCtrl: _imageCtrl,
                      colorCtrl: _colorCtrl,
                      isActive: _isActive,
                      onActiveChanged: (v) => setState(() => _isActive = v),
                      presets: _presets,
                      onPreset: _applyPreset,
                      error: _error,
                      successMsg: _successMsg,
                    ),
                  ),

                  // ── Divider ───────────────────────────────
                  Container(width: 1, color: _border),

                  // ── Right: live preview ───────────────────
                  Expanded(
                    child: _PreviewPanel(
                      title: _titleCtrl.text,
                      subtitle: _subtitleCtrl.text,
                      badge: _badgeCtrl.text,
                      imageUrl: _imageCtrl.text,
                      accentColor: _accentColor,
                      isActive: _isActive,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════
//  HEADER
// ══════════════════════════════════════════════════════════
class _Header extends StatelessWidget {
  final bool isActive, toggling, saving;
  final ValueChanged<bool> onToggle;
  final VoidCallback? onSave;

  const _Header({
    required this.isActive,
    required this.toggling,
    required this.onToggle,
    required this.onSave,
    required this.saving,
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
          const Icon(Icons.campaign_rounded, color: _textSecondary, size: 18),
          const SizedBox(width: 12),
          const Text('Shop Banner',
              style: TextStyle(
                  color: _textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w700)),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: isActive ? Colors.greenAccent.withOpacity(0.1) : _surface3,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                  color:
                      isActive ? Colors.greenAccent.withOpacity(0.3) : _border),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: isActive ? Colors.greenAccent : _textMuted,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 5),
                Text(isActive ? 'Live' : 'Hidden',
                    style: TextStyle(
                        color: isActive ? Colors.greenAccent : _textSecondary,
                        fontSize: 10,
                        fontWeight: FontWeight.w700)),
              ],
            ),
          ),
          const Spacer(),

          // Quick toggle
          _QuickToggle(
            isActive: isActive,
            toggling: toggling,
            onToggle: onToggle,
          ),
          const SizedBox(width: 12),

          // Save button
          _SaveButton(onTap: onSave, saving: saving),
        ],
      ),
    );
  }
}

class _QuickToggle extends StatefulWidget {
  final bool isActive, toggling;
  final ValueChanged<bool> onToggle;
  const _QuickToggle(
      {required this.isActive, required this.toggling, required this.onToggle});

  @override
  State<_QuickToggle> createState() => _QuickToggleState();
}

class _QuickToggleState extends State<_QuickToggle> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.toggling ? null : () => widget.onToggle(!widget.isActive),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 130),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          decoration: BoxDecoration(
            color: widget.isActive
                ? Colors.greenAccent.withOpacity(_hovered ? 0.15 : 0.1)
                : _hovered
                    ? _surface2
                    : _surface3,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: widget.isActive
                  ? Colors.greenAccent.withOpacity(0.3)
                  : _border2,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.toggling)
                const SizedBox(
                  width: 12,
                  height: 12,
                  child: CircularProgressIndicator(
                      color: Colors.greenAccent, strokeWidth: 1.5),
                )
              else
                Icon(
                  widget.isActive
                      ? Icons.visibility_rounded
                      : Icons.visibility_off_rounded,
                  size: 14,
                  color: widget.isActive ? Colors.greenAccent : _textSecondary,
                ),
              const SizedBox(width: 7),
              Text(
                widget.isActive ? 'Hide Banner' : 'Show Banner',
                style: TextStyle(
                  color: widget.isActive ? Colors.greenAccent : _textSecondary,
                  fontSize: 12,
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

class _SaveButton extends StatefulWidget {
  final VoidCallback? onTap;
  final bool saving;
  const _SaveButton({required this.onTap, required this.saving});

  @override
  State<_SaveButton> createState() => _SaveButtonState();
}

class _SaveButtonState extends State<_SaveButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null;
    return MouseRegion(
      onEnter: (_) => enabled ? setState(() => _hovered = true) : null,
      onExit: (_) => setState(() => _hovered = false),
      cursor: enabled ? SystemMouseCursors.click : SystemMouseCursors.forbidden,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 130),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
          decoration: BoxDecoration(
            color: enabled
                ? _hovered
                    ? Colors.redAccent.withOpacity(0.85)
                    : Colors.redAccent
                : _surface2,
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
                Icon(Icons.save_rounded,
                    size: 14, color: enabled ? Colors.white : _textMuted),
              const SizedBox(width: 7),
              Text(
                widget.saving ? 'Saving…' : 'Save Banner',
                style: TextStyle(
                  color: enabled ? Colors.white : _textMuted,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════
//  FORM PANEL (left)
// ══════════════════════════════════════════════════════════
class _FormPanel extends StatelessWidget {
  final TextEditingController titleCtrl,
      subtitleCtrl,
      badgeCtrl,
      imageCtrl,
      colorCtrl;
  final bool isActive;
  final ValueChanged<bool> onActiveChanged;
  final List<_Preset> presets;
  final ValueChanged<_Preset> onPreset;
  final String? error, successMsg;

  const _FormPanel({
    required this.titleCtrl,
    required this.subtitleCtrl,
    required this.badgeCtrl,
    required this.imageCtrl,
    required this.colorCtrl,
    required this.isActive,
    required this.onActiveChanged,
    required this.presets,
    required this.onPreset,
    required this.error,
    required this.successMsg,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Status message ──────────────────────────────
          if (successMsg != null)
            _StatusBanner(msg: successMsg!, isError: false),
          if (error != null) _StatusBanner(msg: error!, isError: true),
          if (successMsg != null || error != null) const SizedBox(height: 16),

          // ── Festival presets ────────────────────────────
          const _SectionLabel('QUICK PRESETS'),
          const SizedBox(height: 10),
          Wrap(
            spacing: 7,
            runSpacing: 7,
            children: presets
                .map((p) => _PresetChip(
                      preset: p,
                      onTap: () => onPreset(p),
                    ))
                .toList(),
          ),
          const SizedBox(height: 24),
          Container(height: 1, color: _border),
          const SizedBox(height: 24),

          // ── Title ───────────────────────────────────────
          const _SectionLabel('CONTENT'),
          const SizedBox(height: 14),
          _AdminFormLabel('Title *'),
          const SizedBox(height: 7),
          _AdminTextField(
            controller: titleCtrl,
            hint: 'e.g. Diwali Sale 🪔',
            icon: Icons.title_rounded,
          ),
          const SizedBox(height: 14),

          // ── Subtitle ────────────────────────────────────
          _AdminFormLabel('Subtitle'),
          const SizedBox(height: 7),
          _AdminTextField(
            controller: subtitleCtrl,
            hint: 'e.g. Light up your cricket game',
            icon: Icons.subtitles_rounded,
          ),
          const SizedBox(height: 14),

          // ── Badge ───────────────────────────────────────
          _AdminFormLabel('Badge Text'),
          const SizedBox(height: 7),
          _AdminTextField(
            controller: badgeCtrl,
            hint: 'e.g. Up to 40% off  (leave empty to hide)',
            icon: Icons.local_offer_rounded,
          ),
          const SizedBox(height: 24),
          Container(height: 1, color: _border),
          const SizedBox(height: 24),

          // ── Design ──────────────────────────────────────
          const _SectionLabel('DESIGN'),
          const SizedBox(height: 14),
          _AdminFormLabel('Accent Colour (hex)'),
          const SizedBox(height: 7),
          _ColorField(controller: colorCtrl),
          const SizedBox(height: 14),

          _AdminFormLabel('Background Image URL'),
          const SizedBox(height: 7),
          _AdminTextField(
            controller: imageCtrl,
            hint: 'https://... (leave empty for gradient)',
            icon: Icons.image_rounded,
          ),
          const SizedBox(height: 24),
          Container(height: 1, color: _border),
          const SizedBox(height: 24),

          // ── Visibility ──────────────────────────────────
          const _SectionLabel('VISIBILITY'),
          const SizedBox(height: 14),
          _VisibilityToggle(
            value: isActive,
            onChanged: onActiveChanged,
          ),

          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════
//  LIVE PREVIEW PANEL (right)
// ══════════════════════════════════════════════════════════
class _PreviewPanel extends StatelessWidget {
  final String title, subtitle, badge, imageUrl;
  final Color accentColor;
  final bool isActive;

  const _PreviewPanel({
    required this.title,
    required this.subtitle,
    required this.badge,
    required this.imageUrl,
    required this.accentColor,
    required this.isActive,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: _bg,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Preview header
          Container(
            padding: const EdgeInsets.fromLTRB(28, 20, 28, 16),
            child: Row(
              children: [
                const Text('LIVE PREVIEW',
                    style: TextStyle(
                        color: _textSecondary,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.5)),
                const Spacer(),
                // Phone frame indicator
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: _surface2,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: _border),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.phone_android_rounded,
                          size: 11, color: _textSecondary),
                      SizedBox(width: 5),
                      Text('App view',
                          style: TextStyle(
                              color: _textSecondary,
                              fontSize: 10,
                              fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Phone frame with banner preview
          Expanded(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(40, 0, 40, 40),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Simulated phone shell
                    Container(
                      width: 340,
                      decoration: BoxDecoration(
                        color: const Color(0xFF060606),
                        borderRadius: BorderRadius.circular(36),
                        border: Border.all(
                            color: const Color(0xFF222222), width: 2),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.5),
                            blurRadius: 40,
                            offset: const Offset(0, 20),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(34),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Status bar
                            Container(
                              height: 28,
                              color: const Color(0xFF060606),
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 20),
                              child: Row(
                                children: [
                                  const Text('9:41',
                                      style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 10,
                                          fontWeight: FontWeight.w700)),
                                  const Spacer(),
                                  const Icon(Icons.signal_cellular_alt,
                                      size: 10, color: Colors.white),
                                  const SizedBox(width: 4),
                                  const Icon(Icons.wifi_rounded,
                                      size: 10, color: Colors.white),
                                  const SizedBox(width: 4),
                                  const Icon(Icons.battery_full_rounded,
                                      size: 10, color: Colors.white),
                                ],
                              ),
                            ),

                            // App header
                            Padding(
                              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('CRICKET STORE',
                                      style: TextStyle(
                                          color: Color(0xFFCC0000),
                                          fontSize: 8,
                                          fontWeight: FontWeight.w700,
                                          letterSpacing: 1.5)),
                                  const SizedBox(height: 2),
                                  const Text('Shop',
                                      style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 20,
                                          fontWeight: FontWeight.w800,
                                          letterSpacing: -0.5)),
                                ],
                              ),
                            ),

                            // ── THE BANNER ─────────────────
                            if (!isActive)
                              Container(
                                margin:
                                    const EdgeInsets.fromLTRB(12, 0, 12, 12),
                                height: 110,
                                decoration: BoxDecoration(
                                  color: _surface2,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: _border),
                                ),
                                child: Center(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.visibility_off_rounded,
                                          color: _textMuted, size: 20),
                                      const SizedBox(height: 6),
                                      const Text('Banner hidden',
                                          style: TextStyle(
                                              color: _textSecondary,
                                              fontSize: 10)),
                                    ],
                                  ),
                                ),
                              )
                            else
                              _BannerPreviewCard(
                                title: title.isEmpty ? 'Your Title' : title,
                                subtitle: subtitle,
                                badge: badge,
                                imageUrl: imageUrl,
                                accentColor: accentColor,
                              ),

                            // Category pills (decoration)
                            SizedBox(
                              height: 34,
                              child: ListView(
                                scrollDirection: Axis.horizontal,
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 12),
                                children: [
                                  'All',
                                  'Bat',
                                  'Ball',
                                  'Gloves',
                                  'Pads',
                                  'Shoes'
                                ]
                                    .map((c) => Container(
                                          margin:
                                              const EdgeInsets.only(right: 6),
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 10, vertical: 5),
                                          decoration: BoxDecoration(
                                            color: c == 'All'
                                                ? const Color(0xFFCC0000)
                                                : const Color(0xFF131313),
                                            borderRadius:
                                                BorderRadius.circular(14),
                                          ),
                                          child: Text(c,
                                              style: const TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 8,
                                                  fontWeight: FontWeight.w600)),
                                        ))
                                    .toList(),
                              ),
                            ),
                            const SizedBox(height: 10),

                            // Product grid (decoration)
                            Padding(
                              padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
                              child: GridView.count(
                                crossAxisCount: 2,
                                crossAxisSpacing: 7,
                                mainAxisSpacing: 7,
                                childAspectRatio: 0.75,
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                children: List.generate(
                                  4,
                                  (_) => Container(
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF0D0D0D),
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(
                                          color: const Color(0xFF1C1C1C)),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Banner card rendered inside preview phone ─────────────
class _BannerPreviewCard extends StatelessWidget {
  final String title, subtitle, badge, imageUrl;
  final Color accentColor;

  const _BannerPreviewCard({
    required this.title,
    required this.subtitle,
    required this.badge,
    required this.imageUrl,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    final hasImage = imageUrl.isNotEmpty;

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      height: 110,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accentColor.withOpacity(0.3)),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Background
          if (hasImage)
            Image.network(imageUrl,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _GradBg(accent: accentColor))
          else
            _GradBg(accent: accentColor),

          // Scrim
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.centerRight,
                end: Alignment.centerLeft,
                colors: [
                  Colors.transparent,
                  Colors.black.withOpacity(0.5),
                  Colors.black.withOpacity(0.8),
                ],
              ),
            ),
          ),

          // Glow
          Positioned(
            bottom: -20,
            left: -20,
            child: Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: accentColor.withOpacity(0.25),
              ),
            ),
          ),

          // Content
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (badge.isNotEmpty) ...[
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: accentColor,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(badge.toUpperCase(),
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 6,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.8)),
                  ),
                  const SizedBox(height: 4),
                ],
                Text(title,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.3,
                        height: 1.1)),
                if (subtitle.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          color: Colors.white.withOpacity(0.6), fontSize: 8)),
                ],
                const SizedBox(height: 6),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text('Shop Now',
                      style: TextStyle(
                          color: accentColor,
                          fontSize: 7,
                          fontWeight: FontWeight.w800)),
                ),
              ],
            ),
          ),

          // Cricket icon
          Positioned(
            top: 10,
            right: 10,
            child: Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: const Text('🏏', style: TextStyle(fontSize: 11)),
            ),
          ),
        ],
      ),
    );
  }
}

class _GradBg extends StatelessWidget {
  final Color accent;
  const _GradBg({required this.accent});

  @override
  Widget build(BuildContext context) => DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topRight,
            end: Alignment.bottomLeft,
            colors: [
              accent.withOpacity(0.5),
              accent.withOpacity(0.2),
              const Color(0xFF0D0D0D),
            ],
          ),
        ),
      );
}

// ══════════════════════════════════════════════════════════
//  SHARED FORM WIDGETS
// ══════════════════════════════════════════════════════════
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

class _AdminFormLabel extends StatelessWidget {
  final String text;
  const _AdminFormLabel(this.text);

  @override
  Widget build(BuildContext context) => Text(text,
      style: const TextStyle(
          color: _textSecondary,
          fontSize: 11,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.3));
}

class _AdminTextField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final IconData? icon;

  const _AdminTextField({
    required this.controller,
    required this.hint,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      style: const TextStyle(color: _textPrimary, fontSize: 13),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: _textMuted, fontSize: 13),
        prefixIcon:
            icon != null ? Icon(icon, color: _textMuted, size: 15) : null,
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
  final TextEditingController controller;
  const _ColorField({required this.controller});

  Color get _preview {
    try {
      final c = controller.text.replaceAll('#', '');
      if (c.length == 6) return Color(int.parse('FF$c', radix: 16));
    } catch (_) {}
    return const Color(0xFFCC0000);
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: controller,
            style: const TextStyle(color: _textPrimary, fontSize: 13),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[#0-9a-fA-F]')),
              LengthLimitingTextInputFormatter(7),
            ],
            decoration: InputDecoration(
              hintText: '#CC0000',
              hintStyle: const TextStyle(color: _textMuted, fontSize: 13),
              prefixIcon: const Icon(Icons.palette_rounded,
                  color: _textMuted, size: 15),
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
                borderSide:
                    BorderSide(color: Colors.redAccent.withOpacity(0.5)),
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        // Color swatch
        AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: _preview,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: _border2),
          ),
        ),
      ],
    );
  }
}

class _VisibilityToggle extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;
  const _VisibilityToggle({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => onChanged(!value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: value ? Colors.greenAccent.withOpacity(0.06) : _surface2,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: value ? Colors.greenAccent.withOpacity(0.25) : _border),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: value ? Colors.greenAccent.withOpacity(0.1) : _surface3,
                borderRadius: BorderRadius.circular(9),
              ),
              child: Icon(
                value ? Icons.visibility_rounded : Icons.visibility_off_rounded,
                size: 16,
                color: value ? Colors.greenAccent : _textSecondary,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    value ? 'Banner is Live' : 'Banner is Hidden',
                    style: TextStyle(
                        color: value ? Colors.greenAccent : _textPrimary,
                        fontSize: 13,
                        fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value
                        ? 'Visible to all users in the app right now'
                        : 'Not shown in the app — toggle to publish',
                    style: const TextStyle(color: _textSecondary, fontSize: 11),
                  ),
                ],
              ),
            ),
            // Toggle switch
            AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: 40,
              height: 22,
              decoration: BoxDecoration(
                color: value ? Colors.greenAccent.withOpacity(0.8) : _surface3,
                borderRadius: BorderRadius.circular(11),
                border: Border.all(color: value ? Colors.greenAccent : _border),
              ),
              child: AnimatedAlign(
                duration: const Duration(milliseconds: 150),
                alignment: value ? Alignment.centerRight : Alignment.centerLeft,
                child: Container(
                  margin: const EdgeInsets.all(2),
                  width: 18,
                  height: 18,
                  decoration: BoxDecoration(
                    color: value ? Colors.white : _textMuted,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PresetChip extends StatefulWidget {
  final _Preset preset;
  final VoidCallback onTap;
  const _PresetChip({required this.preset, required this.onTap});

  @override
  State<_PresetChip> createState() => _PresetChipState();
}

class _PresetChipState extends State<_PresetChip> {
  bool _hovered = false;

  Color get _color {
    try {
      final c = widget.preset.hex.replaceAll('#', '');
      return Color(int.parse('FF$c', radix: 16));
    } catch (_) {
      return Colors.redAccent;
    }
  }

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
            color: _hovered ? _color.withOpacity(0.1) : _surface2,
            borderRadius: BorderRadius.circular(8),
            border:
                Border.all(color: _hovered ? _color.withOpacity(0.4) : _border),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: _color,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 7),
              Text(widget.preset.label,
                  style: TextStyle(
                      color: _hovered ? _textPrimary : _textSecondary,
                      fontSize: 11,
                      fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusBanner extends StatelessWidget {
  final String msg;
  final bool isError;
  const _StatusBanner({required this.msg, required this.isError});

  @override
  Widget build(BuildContext context) {
    final color = isError ? Colors.redAccent : Colors.greenAccent;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Row(
        children: [
          Icon(
            isError ? Icons.error_rounded : Icons.check_circle_rounded,
            color: color,
            size: 15,
          ),
          const SizedBox(width: 10),
          Text(msg,
              style: TextStyle(
                  color: color, fontSize: 12, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
