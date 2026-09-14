import 'package:cloud_firestore/cloud_firestore.dart';

// ─────────────────────────────────────────────────────────────
//  MEME ADMIN SERVICE
//  CRUD + Like tracking
// ─────────────────────────────────────────────────────────────

class MemeAdminService {
  MemeAdminService._();

  static final _db = FirebaseFirestore.instance;
  static CollectionReference get _memes => _db.collection('memes');

  // ════════════════════════════════════════════════════════
  //  MODEL
  // ════════════════════════════════════════════════════════

  static MemeModel _fromDoc(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return MemeModel(
      id: doc.id,
      mediaUrl: d['mediaUrl'] as String? ?? '',
      mediaType: d['mediaType'] as String? ?? 'image',
      thumbnailUrl: d['thumbnailUrl'] as String? ?? '',
      caption: d['caption'] as String? ?? '',
      tags: List<String>.from(d['tags'] ?? []),
      likes: (d['likes'] as num?)?.toInt() ?? 0,
      shares: (d['shares'] as num?)?.toInt() ?? 0,
      views: (d['views'] as num?)?.toInt() ?? 0,
      isActive: d['isActive'] as bool? ?? true,
      isPinned: d['isPinned'] as bool? ?? false,
      order: (d['order'] as num?)?.toInt() ?? 0,
      createdAt: (d['createdAt'] as Timestamp?)?.toDate(),
    );
  }

  // ════════════════════════════════════════════════════════
  //  STREAMS
  // ════════════════════════════════════════════════════════

  static Stream<List<MemeModel>> memesStream() {
    return _memes
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((s) => s.docs.map(_fromDoc).toList());
  }

  // ════════════════════════════════════════════════════════
  //  CRUD
  // ════════════════════════════════════════════════════════

  static Future<String> saveMeme({
    String? existingId,
    required String mediaUrl,
    required String mediaType,
    required String thumbnailUrl,
    required String caption,
    required List<String> tags,
    required bool isActive,
    required bool isPinned,
    required int order,
  }) async {
    final data = <String, dynamic>{
      'mediaUrl': mediaUrl,
      'mediaType': mediaType,
      'thumbnailUrl': thumbnailUrl.isNotEmpty ? thumbnailUrl : mediaUrl,
      'caption': caption,
      'tags': tags,
      'isActive': isActive,
      'isPinned': isPinned,
      'order': order,
      'updatedAt': FieldValue.serverTimestamp(),
    };

    if (existingId != null) {
      await _memes.doc(existingId).update(data);
      return existingId;
    } else {
      data['likes'] = 0;
      data['shares'] = 0;
      data['views'] = 0;
      data['createdAt'] = FieldValue.serverTimestamp();
      final ref = await _memes.add(data);
      return ref.id;
    }
  }

  static Future<void> toggleActive(String id, bool isActive) async =>
      _memes.doc(id).update({'isActive': isActive});

  static Future<void> togglePinned(String id, bool isPinned) async =>
      _memes.doc(id).update({'isPinned': isPinned});

  static Future<void> deleteMeme(String id) async => _memes.doc(id).delete();
}

// ─────────────────────────────────────────────────────────────
//  MODEL
// ─────────────────────────────────────────────────────────────

class MemeModel {
  final String id;
  final String mediaUrl;
  final String mediaType;
  final String thumbnailUrl;
  final String caption;
  final List<String> tags;
  final int likes;
  final int shares;
  final int views;
  final bool isActive;
  final bool isPinned;
  final int order;
  final DateTime? createdAt;

  bool get isImage => mediaType == 'image';
  bool get isVideo => mediaType == 'video';

  const MemeModel({
    required this.id,
    required this.mediaUrl,
    required this.mediaType,
    required this.thumbnailUrl,
    required this.caption,
    required this.tags,
    required this.likes,
    required this.shares,
    required this.views,
    required this.isActive,
    required this.isPinned,
    required this.order,
    required this.createdAt,
  });
}
