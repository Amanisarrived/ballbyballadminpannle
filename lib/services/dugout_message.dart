class DugoutMessage {
  final String id;
  final String userId;
  final String displayName;
  final String? photoUrl;
  final String text;
  final int timestamp;

  const DugoutMessage({
    required this.id,
    required this.userId,
    required this.displayName,
    this.photoUrl,
    required this.text,
    required this.timestamp,
  });

  factory DugoutMessage.fromEntry(String id, Map<dynamic, dynamic> m) {
    return DugoutMessage(
      id: id,
      userId: m['userId'] as String? ?? '',
      displayName: m['displayName'] as String? ?? 'Fan',
      photoUrl: m['photoUrl'] as String?,
      text: m['text'] as String? ?? '',
      timestamp: (m['timestamp'] as num?)?.toInt() ?? 0,
    );
  }
}
