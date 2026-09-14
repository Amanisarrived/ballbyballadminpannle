import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cricket_admin/services/remote_config.service.dart';
import 'package:flutter/material.dart';

// ── Theme ──────────────────────────────────────────────────
const _bg = Color(0xFF0D0D0D);
const _surface = Color(0xFF141414);
const _surface2 = Color(0xFF1A1A1A);
const _surface3 = Color(0xFF202020);
const _border = Color(0xFF232323);
const _border2 = Color(0xFF2A2A2A);
const _textPrimary = Color(0xFFE8E8E8);
const _textSecondary = Color(0xFF666666);
const _textMuted = Color(0xFF3A3A3A);

class RemoteConfigScreen extends StatelessWidget {
  const RemoteConfigScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: StreamBuilder<DocumentSnapshot>(
        stream: RemoteConfigService.stream(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(
                  color: Colors.redAccent, strokeWidth: 2),
            );
          }

          final data = snap.data?.data() as Map<String, dynamic>? ?? {};

          return SingleChildScrollView(
            padding: const EdgeInsets.all(32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Header ──────────────────────────────
                _SectionHeader(
                  icon: Icons.tune_rounded,
                  title: 'Remote Config',
                  subtitle: 'Control app behavior without an update',
                ),
                const SizedBox(height: 32),

                // ── Rating Prompt Card ───────────────────
                _RatingConfigCard(data: data),

                const SizedBox(height: 24),

                // ── Last updated ────────────────────────
                if (data['updated_at'] != null)
                  _LastUpdatedRow(timestamp: data['updated_at'] as Timestamp),
              ],
            ),
          );
        },
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════
//  RATING CONFIG CARD
// ════════════════════════════════════════════════════════════
class _RatingConfigCard extends StatefulWidget {
  final Map<String, dynamic> data;
  const _RatingConfigCard({required this.data});

  @override
  State<_RatingConfigCard> createState() => _RatingConfigCardState();
}

class _RatingConfigCardState extends State<_RatingConfigCard> {
  final _formKey = GlobalKey<FormState>();
  bool _saving = false;

  late bool _showPrompt;
  late TextEditingController _campaignCtrl;
  late TextEditingController _titleCtrl;
  late TextEditingController _bodyCtrl;
  late TextEditingController _buttonCtrl;
  late TextEditingController _cancelCtrl;
  late TextEditingController _minSessionsCtrl;

  @override
  void initState() {
    super.initState();
    _initFromData(widget.data);
  }

  @override
  void didUpdateWidget(_RatingConfigCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_saving) _initFromData(widget.data);
  }

  void _initFromData(Map<String, dynamic> data) {
    _showPrompt = data['show_rating_prompt'] as bool? ?? false;
    _campaignCtrl = TextEditingController(
        text: data['rating_campaign_id'] as String? ?? '');
    _titleCtrl = TextEditingController(
        text: data['rating_title'] as String? ?? 'Enjoying BallByBall? ⭐');
    _bodyCtrl = TextEditingController(
        text: data['rating_body'] as String? ?? 'Rate us on Play Store!');
    _buttonCtrl = TextEditingController(
        text: data['rating_button_text'] as String? ?? 'Rate Now');
    _cancelCtrl = TextEditingController(
        text: data['rating_cancel_text'] as String? ?? 'Later');
    _minSessionsCtrl = TextEditingController(
        text: '${data['rating_min_sessions'] as int? ?? 3}');
  }

  @override
  void dispose() {
    _campaignCtrl.dispose();
    _titleCtrl.dispose();
    _bodyCtrl.dispose();
    _buttonCtrl.dispose();
    _cancelCtrl.dispose();
    _minSessionsCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await RemoteConfigService.saveConfig(
        showRatingPrompt: _showPrompt,
        campaignId: _campaignCtrl.text.trim(),
        ratingTitle: _titleCtrl.text.trim(),
        ratingBody: _bodyCtrl.text.trim(),
        ratingButtonText: _buttonCtrl.text.trim(),
        ratingCancelText: _cancelCtrl.text.trim(),
        ratingMinSessions: int.tryParse(_minSessionsCtrl.text.trim()) ?? 3,
      );
      if (mounted) _showSnack('Config saved ✅');
    } catch (e) {
      if (mounted) _showSnack('Error: $e', error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _quickToggle(bool value) async {
    setState(() => _showPrompt = value);
    try {
      await RemoteConfigService.toggleRatingPrompt(value);
      if (mounted) {
        _showSnack(
            value ? '✅ Rating prompt enabled' : '⛔ Rating prompt disabled');
      }
    } catch (e) {
      if (mounted) _showSnack('Error: $e', error: true);
    }
  }

  void _showSnack(String msg, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: error ? Colors.redAccent : const Color(0xFF1A1A1A),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Toggle Card ─────────────────────────────
          _Card(
            child: Row(children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color:
                      _showPrompt ? Colors.amber.withOpacity(0.1) : _surface3,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.star_rounded,
                  color: _showPrompt ? Colors.amber : _textMuted,
                  size: 20,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Rating Prompt',
                          style: TextStyle(
                              color: _textPrimary,
                              fontSize: 15,
                              fontWeight: FontWeight.w700)),
                      const SizedBox(height: 2),
                      Text(
                        _showPrompt
                            ? 'Active — users will see the popup'
                            : 'Inactive — popup is hidden',
                        style: TextStyle(
                            color: _showPrompt ? Colors.amber : _textSecondary,
                            fontSize: 12),
                      ),
                    ]),
              ),
              // ── Toggle ────────────────────────────────
              GestureDetector(
                onTap: () => _quickToggle(!_showPrompt),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 52,
                  height: 28,
                  decoration: BoxDecoration(
                    color: _showPrompt ? Colors.amber : _surface3,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                        color: _showPrompt ? Colors.amber : _border2),
                  ),
                  child: AnimatedAlign(
                    duration: const Duration(milliseconds: 200),
                    alignment: _showPrompt
                        ? Alignment.centerRight
                        : Alignment.centerLeft,
                    child: Container(
                      width: 22,
                      height: 22,
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: const [
                          BoxShadow(color: Colors.black26, blurRadius: 4)
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ]),
          ),

          const SizedBox(height: 16),

          // ── Preview Card ─────────────────────────────
          _PreviewCard(
            title: _titleCtrl.text,
            body: _bodyCtrl.text,
            buttonText: _buttonCtrl.text,
            cancelText: _cancelCtrl.text,
          ),

          const SizedBox(height: 16),

          // ── Campaign ID Card ─────────────────────────
          _Card(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const _CardLabel(icon: Icons.campaign_rounded, label: 'CAMPAIGN'),
              const SizedBox(height: 4),
              // Info box
              Container(
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 14),
                decoration: BoxDecoration(
                  color: Colors.amber.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.amber.withOpacity(0.15)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline_rounded,
                        color: Colors.amber.withOpacity(0.7), size: 14),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Campaign ID change karo → sab users ko dobara popup dikhega',
                        style: TextStyle(
                            color: Color(0xFF888866),
                            fontSize: 11,
                            height: 1.4),
                      ),
                    ),
                  ],
                ),
              ),
              _Field(
                label: 'Campaign ID',
                controller: _campaignCtrl,
                hint: 'e.g. ipl_2025, ipl_week2, finals',
                helperText: 'Unique ID — change to re-trigger for all users',
              ),
            ]),
          ),

          const SizedBox(height: 16),

          // ── Dialog Content Card ──────────────────────
          _Card(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const _CardLabel(
                  icon: Icons.edit_rounded, label: 'DIALOG CONTENT'),
              const SizedBox(height: 16),
              _Field(
                label: 'Title',
                controller: _titleCtrl,
                hint: 'Enjoying BallByBall? ⭐',
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 12),
              _Field(
                label: 'Body',
                controller: _bodyCtrl,
                hint: 'Rate us on Play Store!',
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(
                    child: _Field(
                  label: 'Rate Button',
                  controller: _buttonCtrl,
                  hint: 'Rate Now',
                  onChanged: (_) => setState(() {}),
                )),
                const SizedBox(width: 12),
                Expanded(
                    child: _Field(
                  label: 'Later Button',
                  controller: _cancelCtrl,
                  hint: 'Later',
                  onChanged: (_) => setState(() {}),
                )),
              ]),
            ]),
          ),

          const SizedBox(height: 16),

          // ── Trigger Settings Card ────────────────────
          _Card(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const _CardLabel(
                  icon: Icons.settings_rounded, label: 'TRIGGER SETTINGS'),
              const SizedBox(height: 16),
              _Field(
                label: 'Min Sessions',
                controller: _minSessionsCtrl,
                hint: '3',
                keyboardType: TextInputType.number,
                helperText:
                    'Show after X app opens (Later wale users ko bhi count hoga)',
              ),
            ]),
          ),

          const SizedBox(height: 24),

          // ── Save Button ──────────────────────────────
          _SaveButton(saving: _saving, onTap: _save),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════
//  PREVIEW CARD
// ════════════════════════════════════════════════════════════
class _PreviewCard extends StatelessWidget {
  final String title, body, buttonText, cancelText;
  const _PreviewCard({
    required this.title,
    required this.body,
    required this.buttonText,
    required this.cancelText,
  });

  @override
  Widget build(BuildContext context) {
    return _Card(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const _CardLabel(
            icon: Icons.phone_android_rounded, label: 'LIVE PREVIEW'),
        const SizedBox(height: 16),
        Center(
          child: Container(
            width: 280,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xFF111111),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: _border2),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withOpacity(0.4),
                    blurRadius: 20,
                    offset: const Offset(0, 8))
              ],
            ),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: Colors.amber.withOpacity(0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.star_rounded,
                        color: Colors.amber, size: 28),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    title.isEmpty ? 'Enjoying BallByBall? ⭐' : title,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        color: _textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        height: 1.3),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    body.isEmpty ? 'Rate us on Play Store!' : body,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        color: _textSecondary, fontSize: 13, height: 1.5),
                  ),
                  const SizedBox(height: 20),
                  // Star row preview
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(
                      5,
                      (_) => const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 2),
                        child: Icon(Icons.star_rounded,
                            color: Colors.amber, size: 24),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                          colors: [Color(0xFFFFB300), Color(0xFFFF8F00)]),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      buttonText.isEmpty ? 'Rate Now' : buttonText,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          color: Colors.black,
                          fontSize: 14,
                          fontWeight: FontWeight.w700),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: _surface3,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: _border),
                    ),
                    child: Text(
                      cancelText.isEmpty ? 'Later' : cancelText,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          color: _textSecondary,
                          fontSize: 13,
                          fontWeight: FontWeight.w500),
                    ),
                  ),
                ]),
          ),
        ),
      ]),
    );
  }
}

// ════════════════════════════════════════════════════════════
//  SHARED WIDGETS
// ════════════════════════════════════════════════════════════

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String title, subtitle;
  const _SectionHeader(
      {required this.icon, required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: Colors.redAccent.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.redAccent.withOpacity(0.2)),
        ),
        child:
            const Icon(Icons.tune_rounded, color: Colors.redAccent, size: 20),
      ),
      const SizedBox(width: 14),
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title,
            style: const TextStyle(
                color: _textPrimary,
                fontSize: 20,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.5)),
        Text(subtitle,
            style: const TextStyle(color: _textSecondary, fontSize: 13)),
      ]),
    ]);
  }
}

class _Card extends StatelessWidget {
  final Widget child;
  const _Card({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _border),
      ),
      child: child,
    );
  }
}

class _CardLabel extends StatelessWidget {
  final IconData icon;
  final String label;
  const _CardLabel({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Icon(icon, color: _textMuted, size: 13),
      const SizedBox(width: 6),
      Text(label,
          style: const TextStyle(
              color: _textSecondary,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5)),
    ]);
  }
}

class _Field extends StatelessWidget {
  final String label, hint;
  final TextEditingController controller;
  final TextInputType? keyboardType;
  final String? helperText;
  final ValueChanged<String>? onChanged;

  const _Field({
    required this.label,
    required this.controller,
    required this.hint,
    this.keyboardType,
    this.helperText,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label,
          style: const TextStyle(
              color: _textSecondary,
              fontSize: 11,
              fontWeight: FontWeight.w600)),
      const SizedBox(height: 6),
      TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        onChanged: onChanged,
        style: const TextStyle(color: _textPrimary, fontSize: 13),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(color: _textMuted, fontSize: 13),
          helperText: helperText,
          helperStyle: const TextStyle(color: _textMuted, fontSize: 10),
          helperMaxLines: 2,
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
            borderSide: const BorderSide(color: Colors.redAccent),
          ),
        ),
        validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
      ),
    ]);
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
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: _hovered ? Colors.redAccent.shade700 : Colors.redAccent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Center(
            child: widget.saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2),
                  )
                : const Text('Save Config',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w700)),
          ),
        ),
      ),
    );
  }
}

class _LastUpdatedRow extends StatelessWidget {
  final Timestamp timestamp;
  const _LastUpdatedRow({required this.timestamp});

  @override
  Widget build(BuildContext context) {
    final dt = timestamp.toDate().toLocal();
    final formatted =
        '${dt.day}/${dt.month}/${dt.year} ${dt.hour}:${dt.minute.toString().padLeft(2, '0')}';
    return Row(children: [
      const Icon(Icons.access_time_rounded, color: _textMuted, size: 12),
      const SizedBox(width: 6),
      Text('Last updated: $formatted',
          style: const TextStyle(color: _textMuted, fontSize: 11)),
    ]);
  }
}
