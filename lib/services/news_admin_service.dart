import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_database/firebase_database.dart';

/// Firestore `news`, filled from Cricbuzz by the worker (doc id `cbz_<id>`).
///
/// The admin only moderates here: hide a story, pin one to the top. The
/// worker never rewrites a story once written, so these choices stick.
class NewsAdminService {
  static final _col = FirebaseFirestore.instance.collection('news');

  /// Same control block as auto scoring; the worker reads `newsEnabled`.
  static DatabaseReference get _control =>
      FirebaseDatabase.instance.ref('featured_match/admin_current/autoScore');

  static Stream<List<NewsItem>> stream({int limit = 100}) => _col
      .orderBy('publishedAt', descending: true)
      .limit(limit)
      .snapshots()
      .map((snap) => snap.docs.map(NewsItem.fromDoc).toList());

  static Stream<bool> enabledStream() => _control
      .child('newsEnabled')
      .onValue
      .map((event) => event.snapshot.value == true);

  static Future<void> setEnabled(bool enabled) =>
      _control.update({'newsEnabled': enabled});

  static Future<void> setHidden(String id, bool hidden) =>
      _col.doc(id).update({'hidden': hidden});

  static Future<void> setPinned(String id, bool pinned) =>
      _col.doc(id).update({'pinned': pinned});

  /// Push the story to every app user. The notification carries the story's
  /// Firestore id, which the app opens directly on tap.
  static Future<void> sendNotification(NewsItem item) async {
    final body = item.description.length > 120
        ? '${item.description.substring(0, 117)}...'
        : item.description;
    await FirebaseFirestore.instance
        .collection('notifications')
        .doc('queue')
        .collection('pending')
        .add({
      'title': item.title,
      'body': body,
      'imageUrl': null,
      'type': 'news',
      'newsId': item.id,
      'topic': 'cricket_notification',
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
    });
    await _col.doc(item.id).update({'notifiedAt': FieldValue.serverTimestamp()});
  }
}

class NewsItem {
  final String id;
  final String title;
  final String description;
  final String context;
  final String type;
  final String url;
  final List<String> teams;
  final DateTime? publishedAt;
  final bool hidden;
  final bool pinned;
  final DateTime? notifiedAt;

  const NewsItem({
    required this.id,
    required this.title,
    required this.description,
    required this.context,
    required this.type,
    required this.url,
    required this.teams,
    required this.publishedAt,
    required this.hidden,
    required this.pinned,
    this.notifiedAt,
  });

  factory NewsItem.fromDoc(DocumentSnapshot doc) {
    final d = (doc.data() as Map<String, dynamic>?) ?? {};
    final rawTeams = d['teams'];
    final teams = <String>[];
    if (rawTeams is List) {
      for (final t in rawTeams) {
        if (t is Map && t['name'] is String) teams.add(t['name'] as String);
      }
    }
    final published = d['publishedAt'];
    return NewsItem(
      id: doc.id,
      title: (d['title'] ?? '').toString(),
      description: (d['description'] ?? '').toString(),
      context: (d['context'] ?? '').toString(),
      type: (d['type'] ?? '').toString(),
      url: (d['url'] ?? '').toString(),
      teams: teams,
      publishedAt: published is Timestamp ? published.toDate() : null,
      hidden: d['hidden'] == true,
      pinned: d['pinned'] == true,
      notifiedAt: d['notifiedAt'] is Timestamp
          ? (d['notifiedAt'] as Timestamp).toDate()
          : null,
    );
  }
}
