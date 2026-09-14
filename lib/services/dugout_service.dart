import 'dart:async';
import 'package:cricket_admin/services/dugout_message.dart';
import 'package:firebase_database/firebase_database.dart';
import 'dugout_service.dart';

// ─────────────────────────────────────────────────────────────
//  MODELS
// ─────────────────────────────────────────────────────────────

enum ModerationAction { warning, timeout, ban, unban }

class DugoutUser {
  final String uid;
  final String displayName;
  final bool isOnline;
  final int? lastSeen; // timestamp
  final ModerationStatus moderation;

  const DugoutUser({
    required this.uid,
    required this.displayName,
    required this.isOnline,
    this.lastSeen,
    required this.moderation,
  });

  factory DugoutUser.fromMap(String uid, Map m, bool isOnline) {
    return DugoutUser(
      uid: uid,
      displayName: m['displayName'] as String? ?? 'Fan',
      isOnline: isOnline,
      lastSeen: (m['lastSeen'] as num?)?.toInt(),
      moderation: ModerationStatus.fromMap(
        (m['moderation'] as Map?) ?? {},
      ),
    );
  }
}

class ModerationStatus {
  final bool isBanned;
  final String banReason;
  final int? timeoutUntil; // timestamp ms — null = no timeout
  final String? lastWarning; // warning message text

  const ModerationStatus({
    this.isBanned = false,
    this.banReason = '',
    this.timeoutUntil,
    this.lastWarning,
  });

  bool get isTimedOut =>
      timeoutUntil != null &&
      timeoutUntil! > DateTime.now().millisecondsSinceEpoch;

  int get timeoutRemainingSeconds {
    if (!isTimedOut) return 0;
    return ((timeoutUntil! - DateTime.now().millisecondsSinceEpoch) / 1000)
        .ceil();
  }

  factory ModerationStatus.fromMap(Map m) {
    return ModerationStatus(
      isBanned: m['isBanned'] as bool? ?? false,
      banReason: m['banReason'] as String? ?? '',
      timeoutUntil: (m['timeoutUntil'] as num?)?.toInt(),
      lastWarning: m['lastWarning'] as String?,
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  ADMIN SERVICE
// ─────────────────────────────────────────────────────────────

class DugoutAdminService {
  DugoutAdminService._();

  static final _root = FirebaseDatabase.instance.ref('dugout/featured');
  static final _usersRef = FirebaseDatabase.instance.ref('dugout_users');
  static final _msgsRef = _root.child('messages');
  static final _presRef = _root.child('presence');
  static final _modRef = FirebaseDatabase.instance.ref('dugout_moderation');

  // ════════════════════════════════════════════════════════
  //  STREAMS
  // ════════════════════════════════════════════════════════

  /// All messages (no limit) — for admin view
  static Stream<List<DugoutMessage>> allMessagesStream() {
    return _msgsRef.orderByChild('timestamp').onValue.map((e) {
      final raw = e.snapshot.value;
      if (raw == null || raw is! Map) return <DugoutMessage>[];
      final msgs = raw.entries
          .map((entry) => DugoutMessage.fromEntry(
                entry.key.toString(),
                entry.value as Map,
              ))
          .toList();
      msgs.sort((a, b) => b.timestamp.compareTo(a.timestamp)); // newest first
      return msgs;
    });
  }

  /// All registered users with online status merged
  static Stream<List<DugoutUser>> allUsersStream() {
    // Combine users + presence in one stream
    final usersStream = _usersRef.onValue;
    final presenceStream = _presRef.onValue;

    // We use a StreamController to merge both
    late StreamController<List<DugoutUser>> ctrl;
    Map<String, dynamic> latestUsers = {};
    Map<String, dynamic> latestPresence = {};
    StreamSubscription? usersSub, presenceSub;

    void emit() {
      final onlineUids = latestPresence.keys.toSet();
      final list = latestUsers.entries
          .map((e) {
            final uid = e.key;
            final m = e.value;
            if (m is! Map) return null;
            return DugoutUser.fromMap(uid, m, onlineUids.contains(uid));
          })
          .whereType<DugoutUser>()
          .toList();

      // Sort: online first, then by displayName
      list.sort((a, b) {
        if (a.isOnline && !b.isOnline) return -1;
        if (!a.isOnline && b.isOnline) return 1;
        return a.displayName.compareTo(b.displayName);
      });

      ctrl.add(list);
    }

    ctrl = StreamController<List<DugoutUser>>.broadcast(
      onListen: () {
        usersSub = usersStream.listen((e) {
          final raw = e.snapshot.value;
          latestUsers = raw is Map
              ? Map<String, dynamic>.from(
                  raw.map((k, v) => MapEntry(k.toString(), v)))
              : {};
          emit();
        });
        presenceSub = presenceStream.listen((e) {
          final raw = e.snapshot.value;
          latestPresence = raw is Map
              ? Map<String, dynamic>.from(
                  raw.map((k, v) => MapEntry(k.toString(), v)))
              : {};
          emit();
        });
      },
      onCancel: () {
        usersSub?.cancel();
        presenceSub?.cancel();
      },
    );

    return ctrl.stream;
  }

  // ════════════════════════════════════════════════════════
  //  MODERATION ACTIONS
  // ════════════════════════════════════════════════════════

  /// Send a warning popup to user — shows in app immediately
  static Future<void> warnUser({
    required String uid,
    required String message,
  }) async {
    await Future.wait([
      // Write to moderation node — user app listens to this
      _modRef.child(uid).update({
        'lastWarning': message,
        'warnedAt': ServerValue.timestamp,
        'warningShown': false, // user app flips to true after showing
      }),
      // Also update user profile
      _usersRef.child('$uid/moderation').update({
        'lastWarning': message,
      }),
    ]);
  }

  /// Timeout user for X minutes — they can't send messages
  static Future<void> timeoutUser({
    required String uid,
    required int minutes,
    required String reason,
  }) async {
    final until =
        DateTime.now().add(Duration(minutes: minutes)).millisecondsSinceEpoch;

    await Future.wait([
      _modRef.child(uid).update({
        'timeoutUntil': until,
        'timeoutReason': reason,
        'timeoutShown': false,
      }),
      _usersRef.child('$uid/moderation').update({
        'timeoutUntil': until,
        'timeoutReason': reason,
      }),
    ]);
  }

  /// Permanently ban user
  static Future<void> banUser({
    required String uid,
    required String reason,
  }) async {
    await Future.wait([
      _modRef.child(uid).update({
        'isBanned': true,
        'banReason': reason,
        'bannedAt': ServerValue.timestamp,
        'banShown': false,
      }),
      _usersRef.child('$uid/moderation').update({
        'isBanned': true,
        'banReason': reason,
      }),
      // Remove their presence immediately
      _presRef.child(uid).remove(),
    ]);
  }

  /// Unban user — restore access
  static Future<void> unbanUser(String uid) async {
    await Future.wait([
      _modRef.child(uid).update({
        'isBanned': false,
        'banReason': '',
        'timeoutUntil': null,
      }),
      _usersRef.child('$uid/moderation').update({
        'isBanned': false,
        'banReason': '',
        'timeoutUntil': null,
      }),
    ]);
  }

  /// Delete any message (admin power — can delete anyone's)
  static Future<void> deleteMessage(String msgId) async {
    await _msgsRef.child(msgId).remove();
  }

  /// Delete all messages from a specific user
  static Future<void> deleteAllMessagesFromUser(String uid) async {
    final snap = await _msgsRef.orderByChild('userId').equalTo(uid).get();
    if (!snap.exists || snap.value == null) return;
    final raw = snap.value as Map;
    final updates = <String, dynamic>{};
    for (final key in raw.keys) {
      updates[key.toString()] = null;
    }
    await _msgsRef.update(updates);
  }

  // ════════════════════════════════════════════════════════
  //  USER-SIDE: moderation status stream
  //  (used in dugout_screen.dart to show popups)
  // ════════════════════════════════════════════════════════

  /// Stream for a specific user's moderation status
  /// Used in app to detect ban/timeout/warning in real-time
  static Stream<_UserModerationEvent?> moderationStream(String uid) {
    return FirebaseDatabase.instance
        .ref('dugout_moderation/$uid')
        .onValue
        .map((e) {
      final raw = e.snapshot.value;
      if (raw == null || raw is! Map) return null;
      return _UserModerationEvent.fromMap(Map<String, dynamic>.from(
        raw.map((k, v) => MapEntry(k.toString(), v)),
      ));
    });
  }

  /// Mark warning as shown — so it doesn't pop up again
  static Future<void> markWarningShown(String uid) async {
    await FirebaseDatabase.instance
        .ref('dugout_moderation/$uid/warningShown')
        .set(true);
  }

  /// Mark timeout popup as shown
  static Future<void> markTimeoutShown(String uid) async {
    await FirebaseDatabase.instance
        .ref('dugout_moderation/$uid/timeoutShown')
        .set(true);
  }

  /// Mark ban popup as shown
  static Future<void> markBanShown(String uid) async {
    await FirebaseDatabase.instance
        .ref('dugout_moderation/$uid/banShown')
        .set(true);
  }
}

// ─────────────────────────────────────────────────────────────
//  USER MODERATION EVENT (parsed from RTDB for app-side)
// ─────────────────────────────────────────────────────────────

class _UserModerationEvent {
  final bool isBanned;
  final String banReason;
  final bool banShown;
  final int? timeoutUntil;
  final String timeoutReason;
  final bool timeoutShown;
  final String? lastWarning;
  final bool warningShown;

  const _UserModerationEvent({
    required this.isBanned,
    required this.banReason,
    required this.banShown,
    this.timeoutUntil,
    required this.timeoutReason,
    required this.timeoutShown,
    this.lastWarning,
    required this.warningShown,
  });

  bool get isTimedOut =>
      timeoutUntil != null &&
      timeoutUntil! > DateTime.now().millisecondsSinceEpoch;

  factory _UserModerationEvent.fromMap(Map<String, dynamic> m) {
    return _UserModerationEvent(
      isBanned: m['isBanned'] as bool? ?? false,
      banReason: m['banReason'] as String? ?? '',
      banShown: m['banShown'] as bool? ?? false,
      timeoutUntil: (m['timeoutUntil'] as num?)?.toInt(),
      timeoutReason: m['timeoutReason'] as String? ?? '',
      timeoutShown: m['timeoutShown'] as bool? ?? false,
      lastWarning: m['lastWarning'] as String?,
      warningShown: m['warningShown'] as bool? ?? false,
    );
  }
}

// Re-export for convenience
typedef UserModerationEvent = _UserModerationEvent;
