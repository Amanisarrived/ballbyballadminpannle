import 'package:cloud_firestore/cloud_firestore.dart';

// ─────────────────────────────────────────────────────────────
//  MODELS
// ─────────────────────────────────────────────────────────────

class AppConfigModel {
  final ForceUpdateConfig forceUpdate;
  final MaintenanceConfig maintenance;
  final AnnouncementConfig announcement;

  const AppConfigModel({
    required this.forceUpdate,
    required this.maintenance,
    required this.announcement,
  });

  factory AppConfigModel.fromMap(Map<String, dynamic> m) => AppConfigModel(
        forceUpdate: ForceUpdateConfig.fromMap(m['force_update'] as Map? ?? {}),
        maintenance: MaintenanceConfig.fromMap(m['maintenance'] as Map? ?? {}),
        announcement:
            AnnouncementConfig.fromMap(m['announcement'] as Map? ?? {}),
      );

  factory AppConfigModel.empty() => AppConfigModel(
        forceUpdate: ForceUpdateConfig.empty(),
        maintenance: MaintenanceConfig.empty(),
        announcement: AnnouncementConfig.empty(),
      );
}

class ForceUpdateConfig {
  final bool enabled;
  final String minVersion;
  final String title;
  final String message;
  final String storeUrl;

  const ForceUpdateConfig({
    required this.enabled,
    required this.minVersion,
    required this.title,
    required this.message,
    required this.storeUrl,
  });

  factory ForceUpdateConfig.fromMap(Map m) => ForceUpdateConfig(
        enabled: m['enabled'] as bool? ?? false,
        minVersion: m['min_version'] as String? ?? '1.0.0',
        title: m['title'] as String? ?? 'Update Available',
        message: m['message'] as String? ?? '',
        storeUrl: m['store_url'] as String? ?? '',
      );

  factory ForceUpdateConfig.empty() => const ForceUpdateConfig(
        enabled: false,
        minVersion: '1.0.0',
        title: 'Update Available',
        message: '',
        storeUrl: '',
      );

  Map<String, dynamic> toMap() => {
        'enabled': enabled,
        'min_version': minVersion,
        'title': title,
        'message': message,
        'store_url': storeUrl,
      };
}

class MaintenanceConfig {
  final bool enabled;
  final String title;
  final String message;
  final String estimatedTime;

  const MaintenanceConfig({
    required this.enabled,
    required this.title,
    required this.message,
    required this.estimatedTime,
  });

  factory MaintenanceConfig.fromMap(Map m) => MaintenanceConfig(
        enabled: m['enabled'] as bool? ?? false,
        title: m['title'] as String? ?? 'Under Maintenance',
        message: m['message'] as String? ?? '',
        estimatedTime: m['estimated_time'] as String? ?? '',
      );

  factory MaintenanceConfig.empty() => const MaintenanceConfig(
        enabled: false,
        title: 'Under Maintenance',
        message: '',
        estimatedTime: '',
      );

  Map<String, dynamic> toMap() => {
        'enabled': enabled,
        'title': title,
        'message': message,
        'estimated_time': estimatedTime,
      };
}

class AnnouncementConfig {
  final bool enabled;
  final String message;
  final String type; // info | warning | success
  final bool dismissible;

  const AnnouncementConfig({
    required this.enabled,
    required this.message,
    required this.type,
    required this.dismissible,
  });

  factory AnnouncementConfig.fromMap(Map m) => AnnouncementConfig(
        enabled: m['enabled'] as bool? ?? false,
        message: m['message'] as String? ?? '',
        type: m['type'] as String? ?? 'info',
        dismissible: m['dismissible'] as bool? ?? true,
      );

  factory AnnouncementConfig.empty() => const AnnouncementConfig(
        enabled: false,
        message: '',
        type: 'info',
        dismissible: true,
      );

  Map<String, dynamic> toMap() => {
        'enabled': enabled,
        'message': message,
        'type': type,
        'dismissible': dismissible,
      };
}

// ─────────────────────────────────────────────────────────────
//  SERVICE
// ─────────────────────────────────────────────────────────────

class AppConfigService {
  AppConfigService._();

  static final _doc =
      FirebaseFirestore.instance.collection('app_config').doc('cricview');

  // ── Stream ───────────────────────────────────────────────
  static Stream<AppConfigModel> stream() {
    return _doc.snapshots().map((snap) {
      if (!snap.exists || snap.data() == null) return AppConfigModel.empty();
      return AppConfigModel.fromMap(snap.data()!);
    });
  }

  // ── One-time fetch ───────────────────────────────────────
  static Future<AppConfigModel> get() async {
    final snap = await _doc.get();
    if (!snap.exists || snap.data() == null) return AppConfigModel.empty();
    return AppConfigModel.fromMap(snap.data()!);
  }

  // ── Force Update ─────────────────────────────────────────
  static Future<void> saveForceUpdate(ForceUpdateConfig config) async {
    await _doc.set({'force_update': config.toMap()}, SetOptions(merge: true));
  }

  // ── Maintenance ──────────────────────────────────────────
  static Future<void> saveMaintenance(MaintenanceConfig config) async {
    await _doc.set({'maintenance': config.toMap()}, SetOptions(merge: true));
  }

  // ── Announcement ─────────────────────────────────────────
  static Future<void> saveAnnouncement(AnnouncementConfig config) async {
    await _doc.set({'announcement': config.toMap()}, SetOptions(merge: true));
  }

  // ── Quick toggles (single field update) ──────────────────
  static Future<void> toggleForceUpdate(bool enabled) async => _doc.set({
        'force_update': {'enabled': enabled}
      }, SetOptions(merge: true));

  static Future<void> toggleMaintenance(bool enabled) async => _doc.set({
        'maintenance': {'enabled': enabled}
      }, SetOptions(merge: true));

  static Future<void> toggleAnnouncement(bool enabled) async => _doc.set({
        'announcement': {'enabled': enabled}
      }, SetOptions(merge: true));
}
