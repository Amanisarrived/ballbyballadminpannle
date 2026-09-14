import 'package:cricket_admin/services/app_config_service.dart';
import 'package:flutter/material.dart';

// ─────────────────────────────────────────────────────────────
//  APP CONFIG ADMIN SCREEN
//  Dark + red accent theme — same as CricView admin panel
// ─────────────────────────────────────────────────────────────

class AppConfigScreen extends StatefulWidget {
  const AppConfigScreen({super.key});

  @override
  State<AppConfigScreen> createState() => _AppConfigScreenState();
}

class _AppConfigScreenState extends State<AppConfigScreen> {
  static const _red = Color(0xFFCC0000);
  static const _bg = Color(0xFF0A0A0A);
  static const _card = Color(0xFF111111);
  static const _card2 = Color(0xFF161616);

  AppConfigModel? _config;
  bool _saving = false;

  // ── Force Update controllers ──────────────────────────────
  final _fuVersionCtrl = TextEditingController();
  final _fuTitleCtrl = TextEditingController();
  final _fuMessageCtrl = TextEditingController();
  final _fuStoreCtrl = TextEditingController();

  // ── Maintenance controllers ───────────────────────────────
  final _mainTitleCtrl = TextEditingController();
  final _mainMessageCtrl = TextEditingController();
  final _mainTimeCtrl = TextEditingController();

  // ── Announcement controllers ──────────────────────────────
  final _annMessageCtrl = TextEditingController();
  String _annType = 'info';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final config = await AppConfigService.get();
    _populate(config);
  }

  void _populate(AppConfigModel config) {
    setState(() {
      _config = config;

      _fuVersionCtrl.text = config.forceUpdate.minVersion;
      _fuTitleCtrl.text = config.forceUpdate.title;
      _fuMessageCtrl.text = config.forceUpdate.message;
      _fuStoreCtrl.text = config.forceUpdate.storeUrl;

      _mainTitleCtrl.text = config.maintenance.title;
      _mainMessageCtrl.text = config.maintenance.message;
      _mainTimeCtrl.text = config.maintenance.estimatedTime;

      _annMessageCtrl.text = config.announcement.message;
      _annType = config.announcement.type;
    });
  }

  @override
  void dispose() {
    _fuVersionCtrl.dispose();
    _fuTitleCtrl.dispose();
    _fuMessageCtrl.dispose();
    _fuStoreCtrl.dispose();
    _mainTitleCtrl.dispose();
    _mainMessageCtrl.dispose();
    _mainTimeCtrl.dispose();
    _annMessageCtrl.dispose();
    super.dispose();
  }

  Future<void> _saveForceUpdate() async {
    if (_config == null) return;
    setState(() => _saving = true);
    try {
      await AppConfigService.saveForceUpdate(ForceUpdateConfig(
        enabled: _config!.forceUpdate.enabled,
        minVersion: _fuVersionCtrl.text.trim(),
        title: _fuTitleCtrl.text.trim(),
        message: _fuMessageCtrl.text.trim(),
        storeUrl: _fuStoreCtrl.text.trim(),
      ));
      _showSnack('Force Update saved ✓');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _saveMaintenance() async {
    if (_config == null) return;
    setState(() => _saving = true);
    try {
      await AppConfigService.saveMaintenance(MaintenanceConfig(
        enabled: _config!.maintenance.enabled,
        title: _mainTitleCtrl.text.trim(),
        message: _mainMessageCtrl.text.trim(),
        estimatedTime: _mainTimeCtrl.text.trim(),
      ));
      _showSnack('Maintenance saved ✓');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _saveAnnouncement() async {
    if (_config == null) return;
    setState(() => _saving = true);
    try {
      await AppConfigService.saveAnnouncement(AnnouncementConfig(
        enabled: _config!.announcement.enabled,
        message: _annMessageCtrl.text.trim(),
        type: _annType,
        dismissible: _config!.announcement.dismissible,
      ));
      _showSnack('Announcement saved ✓');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content:
          Text(msg, style: const TextStyle(color: Colors.white, fontSize: 13)),
      backgroundColor: const Color(0xFF1A1A1A),
      behavior: SnackBarBehavior.floating,
      margin: const EdgeInsets.all(16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      duration: const Duration(seconds: 2),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AppConfigModel>(
      stream: AppConfigService.stream(),
      builder: (context, snap) {
        if (snap.hasData && snap.data != null) {
          final fresh = snap.data!;
          // Sync toggle states from stream without overwriting text fields
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            if (_config?.forceUpdate.enabled != fresh.forceUpdate.enabled ||
                _config?.maintenance.enabled != fresh.maintenance.enabled ||
                _config?.announcement.enabled != fresh.announcement.enabled ||
                _config?.announcement.dismissible !=
                    fresh.announcement.dismissible) {
              setState(() => _config = fresh.copyToggles(_config!));
            }
          });
        }

        return Scaffold(
          backgroundColor: _bg,
          appBar: AppBar(
            backgroundColor: _card,
            elevation: 0,
            title: const Row(children: [
              Icon(Icons.settings_rounded, color: _red, size: 18),
              SizedBox(width: 10),
              Text('App Config',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w700)),
            ]),
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(1),
              child: Container(height: 1, color: Colors.white.withAlpha(15)),
            ),
          ),
          body: _config == null
              ? const Center(
                  child:
                      CircularProgressIndicator(color: _red, strokeWidth: 1.5))
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    _forceUpdateCard(),
                    const SizedBox(height: 16),
                    _maintenanceCard(),
                    const SizedBox(height: 16),
                    _announcementCard(),
                    const SizedBox(height: 32),
                  ],
                ),
        );
      },
    );
  }

  // ─────────────────────────────────────────────────────────
  //  FORCE UPDATE CARD
  // ─────────────────────────────────────────────────────────
  Widget _forceUpdateCard() {
    final enabled = _config!.forceUpdate.enabled;
    return _ConfigCard(
      icon: Icons.system_update_rounded,
      title: 'Force Update',
      subtitle: 'Block old versions from using the app',
      enabled: enabled,
      color: const Color(0xFFCC0000),
      onToggle: (val) async {
        setState(() => _config = _config!.withForceUpdateEnabled(val));
        await AppConfigService.toggleForceUpdate(val);
      },
      children: [
        _Field(
            label: 'Min Version',
            ctrl: _fuVersionCtrl,
            hint: 'e.g. 2.0.0',
            keyboardType: TextInputType.number),
        _Field(
            label: 'Dialog Title',
            ctrl: _fuTitleCtrl,
            hint: 'Update Available'),
        _Field(
            label: 'Message',
            ctrl: _fuMessageCtrl,
            hint: 'Please update to continue...',
            maxLines: 3),
        _Field(
            label: 'Play Store URL',
            ctrl: _fuStoreCtrl,
            hint: 'https://play.google.com/...'),
        const SizedBox(height: 4),
        _SaveButton(onTap: _saveForceUpdate, saving: _saving),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────
  //  MAINTENANCE CARD
  // ─────────────────────────────────────────────────────────
  Widget _maintenanceCard() {
    final enabled = _config!.maintenance.enabled;
    return _ConfigCard(
      icon: Icons.construction_rounded,
      title: 'Maintenance Mode',
      subtitle: 'Show maintenance screen to all users',
      enabled: enabled,
      color: const Color(0xFFFF9800),
      onToggle: (val) async {
        setState(() => _config = _config!.withMaintenanceEnabled(val));
        await AppConfigService.toggleMaintenance(val);
      },
      children: [
        _Field(label: 'Title', ctrl: _mainTitleCtrl, hint: 'Under Maintenance'),
        _Field(
            label: 'Message',
            ctrl: _mainMessageCtrl,
            hint: 'We are improving CricView...',
            maxLines: 3),
        _Field(
            label: 'Estimated Time (optional)',
            ctrl: _mainTimeCtrl,
            hint: 'e.g. 2:30 PM or 30 minutes'),
        const SizedBox(height: 4),
        _SaveButton(onTap: _saveMaintenance, saving: _saving),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────
  //  ANNOUNCEMENT CARD
  // ─────────────────────────────────────────────────────────
  Widget _announcementCard() {
    final enabled = _config!.announcement.enabled;
    final dismissible = _config!.announcement.dismissible;
    return _ConfigCard(
      icon: Icons.campaign_rounded,
      title: 'Announcement Banner',
      subtitle: 'Show a banner message to all users',
      enabled: enabled,
      color: const Color(0xFF2196F3),
      onToggle: (val) async {
        setState(() => _config = _config!.withAnnouncementEnabled(val));
        await AppConfigService.toggleAnnouncement(val);
      },
      children: [
        _Field(
            label: 'Message',
            ctrl: _annMessageCtrl,
            hint: 'IPL 2025 live scoring starts today! 🏏',
            maxLines: 2),

        // Type selector
        const SizedBox(height: 12),
        Text('Type',
            style: TextStyle(
                color: Colors.white.withAlpha(140),
                fontSize: 11,
                fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        Row(
            children: ['info', 'warning', 'success'].map((t) {
          final selected = _annType == t;
          final color = t == 'info'
              ? const Color(0xFF2196F3)
              : t == 'warning'
                  ? const Color(0xFFFF9800)
                  : const Color(0xFF4CAF50);
          return Expanded(
              child: Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () => setState(() => _annType = t),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: selected
                      ? color.withAlpha(30)
                      : Colors.white.withAlpha(8),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                      color: selected ? color : Colors.white.withAlpha(20)),
                ),
                child: Text(t.toUpperCase(),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        color: selected ? color : Colors.white38,
                        fontSize: 11,
                        fontWeight: FontWeight.w700)),
              ),
            ),
          ));
        }).toList()),

        // Dismissible toggle
        const SizedBox(height: 14),
        Row(children: [
          Expanded(
              child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Dismissible',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w500)),
              Text('User can close the banner',
                  style: TextStyle(color: Colors.white38, fontSize: 11)),
            ],
          )),
          Switch(
            value: dismissible,
            onChanged: (val) async {
              setState(() => _config = _config!.withDismissible(val));
              await AppConfigService.saveAnnouncement(AnnouncementConfig(
                enabled: enabled,
                message: _annMessageCtrl.text.trim(),
                type: _annType,
                dismissible: val,
              ));
            },
            activeColor: const Color(0xFF2196F3),
            activeTrackColor: const Color(0xFF2196F3).withAlpha(80),
          ),
        ]),

        const SizedBox(height: 4),
        _SaveButton(onTap: _saveAnnouncement, saving: _saving),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  COPY HELPERS (immutable config updates)
// ─────────────────────────────────────────────────────────────

extension AppConfigCopy on AppConfigModel {
  AppConfigModel withForceUpdateEnabled(bool val) => AppConfigModel(
        forceUpdate: ForceUpdateConfig(
            enabled: val,
            minVersion: forceUpdate.minVersion,
            title: forceUpdate.title,
            message: forceUpdate.message,
            storeUrl: forceUpdate.storeUrl),
        maintenance: maintenance,
        announcement: announcement,
      );

  AppConfigModel withMaintenanceEnabled(bool val) => AppConfigModel(
        forceUpdate: forceUpdate,
        maintenance: MaintenanceConfig(
            enabled: val,
            title: maintenance.title,
            message: maintenance.message,
            estimatedTime: maintenance.estimatedTime),
        announcement: announcement,
      );

  AppConfigModel withAnnouncementEnabled(bool val) => AppConfigModel(
        forceUpdate: forceUpdate,
        maintenance: maintenance,
        announcement: AnnouncementConfig(
            enabled: val,
            message: announcement.message,
            type: announcement.type,
            dismissible: announcement.dismissible),
      );

  AppConfigModel withDismissible(bool val) => AppConfigModel(
        forceUpdate: forceUpdate,
        maintenance: maintenance,
        announcement: AnnouncementConfig(
            enabled: announcement.enabled,
            message: announcement.message,
            type: announcement.type,
            dismissible: val),
      );

  // Sync only toggle states from stream — keep text field values
  AppConfigModel copyToggles(AppConfigModel current) => AppConfigModel(
        forceUpdate: ForceUpdateConfig(
            enabled: forceUpdate.enabled,
            minVersion: current.forceUpdate.minVersion,
            title: current.forceUpdate.title,
            message: current.forceUpdate.message,
            storeUrl: current.forceUpdate.storeUrl),
        maintenance: MaintenanceConfig(
            enabled: maintenance.enabled,
            title: current.maintenance.title,
            message: current.maintenance.message,
            estimatedTime: current.maintenance.estimatedTime),
        announcement: AnnouncementConfig(
            enabled: announcement.enabled,
            message: current.announcement.message,
            type: current.announcement.type,
            dismissible: announcement.dismissible),
      );
}

// ─────────────────────────────────────────────────────────────
//  SHARED WIDGETS
// ─────────────────────────────────────────────────────────────

class _ConfigCard extends StatelessWidget {
  final IconData icon;
  final String title, subtitle;
  final bool enabled;
  final Color color;
  final void Function(bool) onToggle;
  final List<Widget> children;

  const _ConfigCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.enabled,
    required this.color,
    required this.onToggle,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF111111),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: enabled ? color.withAlpha(60) : Colors.white.withAlpha(12)),
      ),
      child: Column(children: [
        // Header
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: enabled ? color.withAlpha(15) : Colors.white.withAlpha(5),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(13)),
          ),
          child: Row(children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withAlpha(20),
                shape: BoxShape.circle,
                border: Border.all(color: color.withAlpha(60)),
              ),
              child: Icon(icon, color: color, size: 16),
            ),
            const SizedBox(width: 12),
            Expanded(
                child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w700)),
                Text(subtitle,
                    style: TextStyle(color: Colors.white38, fontSize: 11)),
              ],
            )),
            // Toggle
            Switch(
              value: enabled,
              onChanged: onToggle,
              activeColor: color,
              activeTrackColor: color.withAlpha(80),
            ),
          ]),
        ),

        // Active indicator
        if (enabled)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 6),
            color: color.withAlpha(20),
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Container(
                  width: 6,
                  height: 6,
                  decoration:
                      BoxDecoration(color: color, shape: BoxShape.circle)),
              const SizedBox(width: 6),
              Text('ACTIVE — Users are seeing this',
                  style: TextStyle(
                      color: color,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5)),
            ]),
          ),

        // Fields
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: children,
          ),
        ),
      ]),
    );
  }
}

class _Field extends StatelessWidget {
  final String label;
  final TextEditingController ctrl;
  final String hint;
  final int maxLines;
  final TextInputType? keyboardType;

  const _Field({
    required this.label,
    required this.ctrl,
    required this.hint,
    this.maxLines = 1,
    this.keyboardType,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label,
            style: TextStyle(
                color: Colors.white.withAlpha(140),
                fontSize: 11,
                fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        TextField(
          controller: ctrl,
          maxLines: maxLines,
          keyboardType: keyboardType,
          style: const TextStyle(color: Colors.white, fontSize: 13),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: Colors.white38, fontSize: 12),
            filled: true,
            fillColor: Colors.white.withAlpha(8),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide.none),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.white.withAlpha(15))),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Color(0xFFCC0000))),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          ),
        ),
      ]),
    );
  }
}

class _SaveButton extends StatelessWidget {
  final VoidCallback onTap;
  final bool saving;

  const _SaveButton({required this.onTap, required this.saving});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: GestureDetector(
        onTap: saving ? null : onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 11),
          decoration: BoxDecoration(
            color: saving
                ? Colors.white.withAlpha(10)
                : const Color(0xFFCC0000).withAlpha(200),
            borderRadius: BorderRadius.circular(10),
          ),
          child: saving
              ? const Center(
                  child: SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white)))
              : const Text('Save Changes',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w700)),
        ),
      ),
    );
  }
}
