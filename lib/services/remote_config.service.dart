import 'package:cloud_firestore/cloud_firestore.dart';

class RemoteConfigService {
  static final _db = FirebaseFirestore.instance;

  static DocumentReference get _doc =>
      _db.collection('app_data').doc('remoteconfig');

  // ── Stream ──────────────────────────────────────────────
  static Stream<DocumentSnapshot> stream() => _doc.snapshots();

  // ── Fetch once ──────────────────────────────────────────
  static Future<Map<String, dynamic>> fetch() async {
    final snap = await _doc.get();
    if (!snap.exists) return {};
    return snap.data() as Map<String, dynamic>? ?? {};
  }

  // ── Save all config ─────────────────────────────────────
  static Future<void> saveConfig({
    required bool showRatingPrompt,
    required String campaignId,
    required String ratingTitle,
    required String ratingBody,
    required String ratingButtonText,
    required String ratingCancelText,
    required int ratingMinSessions,
  }) async {
    await _doc.set({
      'show_rating_prompt': showRatingPrompt,
      'rating_campaign_id': campaignId,
      'rating_title': ratingTitle,
      'rating_body': ratingBody,
      'rating_button_text': ratingButtonText,
      'rating_cancel_text': ratingCancelText,
      'rating_min_sessions': ratingMinSessions,
      'updated_at': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  // ── Quick toggle ─────────────────────────────────────────
  static Future<void> toggleRatingPrompt(bool value) async {
    await _doc.update({
      'show_rating_prompt': value,
      'updated_at': FieldValue.serverTimestamp(),
    });
  }
}
