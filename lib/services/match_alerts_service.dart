import 'package:cloud_firestore/cloud_firestore.dart';

/// Automatic match push notifications, sent by the `autoScoreNotification`
/// and `matchStatusNotification` Cloud Functions (functions/alerts.js).
///
/// Settings live in Firestore `config/match_alerts` and are read on every
/// alert, so changes apply immediately without a deploy. Each alert sent is
/// logged under `notifications/alerts/log`.
class MatchAlertsService {
  static final _db = FirebaseFirestore.instance;
  static DocumentReference<Map<String, dynamic>> get _settings =>
      _db.collection('config').doc('match_alerts');
  static CollectionReference<Map<String, dynamic>> get _log =>
      _db.collection('notifications').doc('alerts').collection('log');

  static Stream<MatchAlertSettings> settings() => _settings
      .snapshots()
      .map((s) => MatchAlertSettings.fromMap(s.data() ?? const {}));

  static Future<void> update(Map<String, dynamic> fields) =>
      _settings.set(fields, SetOptions(merge: true));

  static Stream<List<MatchAlertLog>> log({int limit = 60}) => _log
      .orderBy('createdAt', descending: true)
      .limit(limit)
      .snapshots()
      .map((snap) => snap.docs.map(MatchAlertLog.fromDoc).toList());
}

/// Mirrors DEFAULT_SETTINGS in functions/alerts.js; keep the two in step.
class MatchAlertSettings {
  final bool enabled;
  final bool toss;
  final String wickets; // all | key | off
  final bool milestones;
  final bool inningsBreak;
  final bool chase;
  final bool result;
  final bool powerplay;
  final int maxPerMatch;

  const MatchAlertSettings({
    this.enabled = true,
    this.toss = true,
    this.wickets = 'key',
    this.milestones = true,
    this.inningsBreak = true,
    this.chase = true,
    this.result = true,
    this.powerplay = false,
    this.maxPerMatch = 12,
  });

  factory MatchAlertSettings.fromMap(Map<String, dynamic> m) {
    const d = MatchAlertSettings();
    bool flag(String key, bool fallback) =>
        m[key] is bool ? m[key] as bool : fallback;
    final wickets = m['wickets'];
    final max = m['maxPerMatch'];
    return MatchAlertSettings(
      enabled: flag('enabled', d.enabled),
      toss: flag('toss', d.toss),
      wickets: const ['all', 'key', 'off'].contains(wickets)
          ? wickets as String
          : d.wickets,
      milestones: flag('milestones', d.milestones),
      inningsBreak: flag('inningsBreak', d.inningsBreak),
      chase: flag('chase', d.chase),
      result: flag('result', d.result),
      powerplay: flag('powerplay', d.powerplay),
      maxPerMatch: max is num ? max.toInt().clamp(1, 40) : d.maxPerMatch,
    );
  }
}

class MatchAlertLog {
  final String id;
  final String kind;
  final String title;
  final String body;
  final String matchTitle;
  final String status; // queued | sent | failed
  final String error;
  final DateTime? createdAt;

  const MatchAlertLog({
    required this.id,
    required this.kind,
    required this.title,
    required this.body,
    required this.matchTitle,
    required this.status,
    this.error = '',
    this.createdAt,
  });

  factory MatchAlertLog.fromDoc(DocumentSnapshot doc) {
    final d = (doc.data() as Map<String, dynamic>?) ?? {};
    final created = d['createdAt'];
    return MatchAlertLog(
      id: doc.id,
      kind: (d['kind'] ?? '').toString(),
      title: (d['title'] ?? '').toString(),
      body: (d['body'] ?? '').toString(),
      matchTitle: (d['matchTitle'] ?? '').toString(),
      status: (d['status'] ?? 'queued').toString(),
      error: (d['error'] ?? '').toString(),
      createdAt: created is Timestamp ? created.toDate() : null,
    );
  }
}
