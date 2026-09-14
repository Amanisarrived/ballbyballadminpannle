import 'package:cloud_firestore/cloud_firestore.dart';

class ReactionService {
  static final _db = FirebaseFirestore.instance;

  static DocumentReference get _doc =>
      _db.collection('featured_match').doc('admin_current');

  // ── Stream reactions ─────────────────────────────────────
  static Stream<Map<String, int>> stream() {
    return _doc.snapshots().map((snap) {
      if (!snap.exists) return _empty();
      final data = snap.data() as Map<String, dynamic>? ?? {};
      final reactions = data['reactions'] as Map<String, dynamic>? ?? {};
      return {
        'fire': reactions['fire'] as int? ?? 0,
        'shocked': reactions['shocked'] as int? ?? 0,
        'celebrate': reactions['celebrate'] as int? ?? 0,
        'heartbreak': reactions['heartbreak'] as int? ?? 0,
      };
    });
  }

  // ── Reset all reactions ──────────────────────────────────
  static Future<void> resetReactions() async {
    await _doc.update({
      'reactions': {
        'fire': 0,
        'shocked': 0,
        'celebrate': 0,
        'heartbreak': 0,
      },
    });
  }

  static Map<String, int> _empty() => {
        'fire': 0,
        'shocked': 0,
        'celebrate': 0,
        'heartbreak': 0,
      };
}
