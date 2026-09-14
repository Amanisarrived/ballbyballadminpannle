import 'package:cloud_firestore/cloud_firestore.dart';

// ─────────────────────────────────────────────────────────────
//  PLAYER MODEL
// ─────────────────────────────────────────────────────────────
class RankedPlayer {
  final int rank;
  final String name;
  final String imageUrl; // player photo URL
  final String flagUrl; // country flag image URL
  final int rating;
  final int points;
  final int runs; // batsmen stat
  final int wickets; // bowlers stat

  // kept for admin backwards compat
  final String team;
  final String teamFlag;

  const RankedPlayer({
    required this.rank,
    required this.name,
    this.imageUrl = '',
    this.flagUrl = '',
    this.rating = 0,
    this.points = 0,
    this.runs = 0,
    this.wickets = 0,
    this.team = '',
    this.teamFlag = '',
  });

  factory RankedPlayer.fromMap(Map<String, dynamic> m) => RankedPlayer(
        rank: (m['rank'] as num?)?.toInt() ?? 0,
        name: m['name'] as String? ?? '',
        imageUrl: m['imageUrl'] as String? ?? '',
        flagUrl: m['flagUrl'] as String? ?? '',
        rating: (m['rating'] as num?)?.toInt() ?? 0,
        points: (m['points'] as num?)?.toInt() ?? 0,
        runs: (m['runs'] as num?)?.toInt() ?? 0,
        wickets: (m['wickets'] as num?)?.toInt() ?? 0,
        team: m['team'] as String? ?? '',
        teamFlag: m['teamFlag'] as String? ?? '',
      );

  Map<String, dynamic> toMap() => {
        'rank': rank,
        'name': name,
        'imageUrl': imageUrl,
        'flagUrl': flagUrl,
        'rating': rating,
        'points': points,
        'runs': runs,
        'wickets': wickets,
        'team': team,
        'teamFlag': teamFlag,
      };

  RankedPlayer copyWith({
    int? rank,
    String? name,
    String? imageUrl,
    String? flagUrl,
    int? rating,
    int? points,
    int? runs,
    int? wickets,
    String? team,
    String? teamFlag,
  }) =>
      RankedPlayer(
        rank: rank ?? this.rank,
        name: name ?? this.name,
        imageUrl: imageUrl ?? this.imageUrl,
        flagUrl: flagUrl ?? this.flagUrl,
        rating: rating ?? this.rating,
        points: points ?? this.points,
        runs: runs ?? this.runs,
        wickets: wickets ?? this.wickets,
        team: team ?? this.team,
        teamFlag: teamFlag ?? this.teamFlag,
      );
}

// ─────────────────────────────────────────────────────────────
//  ENUMS
// ─────────────────────────────────────────────────────────────
enum RankFormat { t20, odi, test }

enum RankCategory { batsmen, bowlers, allrounders }

extension RankFormatExt on RankFormat {
  String get key => ['t20', 'odi', 'test'][index];
  String get label => ['T20', 'ODI', 'Test'][index];
}

extension RankCategoryExt on RankCategory {
  String get key => ['batsmen', 'bowlers', 'allrounders'][index];
  String get label => ['Batsmen', 'Bowlers', 'All-rounders'][index];
}

// ─────────────────────────────────────────────────────────────
//  TOURNAMENT CONFIG
// ─────────────────────────────────────────────────────────────
class TournamentConfig {
  final String id;
  final String name;
  final String logoUrl; // tournament logo image URL
  final bool isActive;
  final bool isLast; // if true → show when no active tournament
  final List<RankCategory> categories;

  const TournamentConfig({
    required this.id,
    required this.name,
    this.logoUrl = '',
    this.isActive = false,
    this.isLast = false,
    this.categories = const [RankCategory.batsmen, RankCategory.bowlers],
  });

  factory TournamentConfig.fromMap(Map<String, dynamic> m) {
    final rawCats = m['categories'] as List<dynamic>?;
    final cats = rawCats != null
        ? rawCats
            .map((e) {
              try {
                return RankCategory.values.firstWhere((c) => c.key == e);
              } catch (_) {
                return null;
              }
            })
            .whereType<RankCategory>()
            .toList()
        : [RankCategory.batsmen, RankCategory.bowlers];

    return TournamentConfig(
      id: m['id'] as String? ?? '',
      name: m['name'] as String? ?? '',
      logoUrl: m['logoUrl'] as String? ?? '',
      isActive: m['isActive'] as bool? ?? false,
      isLast: m['isLast'] as bool? ?? false,
      categories:
          cats.isEmpty ? [RankCategory.batsmen, RankCategory.bowlers] : cats,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'logoUrl': logoUrl,
        'isActive': isActive,
        'isLast': isLast,
        'categories': categories.map((c) => c.key).toList(),
      };

  TournamentConfig copyWith({
    String? id,
    String? name,
    String? logoUrl,
    bool? isActive,
    bool? isLast,
    List<RankCategory>? categories,
  }) =>
      TournamentConfig(
        id: id ?? this.id,
        name: name ?? this.name,
        logoUrl: logoUrl ?? this.logoUrl,
        isActive: isActive ?? this.isActive,
        isLast: isLast ?? this.isLast,
        categories: categories ?? this.categories,
      );
}

// ─────────────────────────────────────────────────────────────
//  SERVICE
// ─────────────────────────────────────────────────────────────
class RankingsService {
  RankingsService._();

  static final _col = FirebaseFirestore.instance.collection('rankings');
  static final _configDoc =
      FirebaseFirestore.instance.collection('config').doc('tournaments');

  static String _iccId(RankFormat f, RankCategory c) => '${f.key}_${c.key}';
  static String _tId(String tournamentId, RankCategory c) =>
      '${tournamentId}_${c.key}';

  // ── ICC ─────────────────────────────────────────────────
  static Stream<List<RankedPlayer>> streamRankings(
          RankFormat f, RankCategory c) =>
      _col.doc(_iccId(f, c)).snapshots().map(_parsePlayers);

  static Future<List<RankedPlayer>> fetchRankings(
          RankFormat f, RankCategory c) async =>
      _parsePlayers(await _col.doc(_iccId(f, c)).get());

  static Future<void> saveRankings({
    required RankFormat format,
    required RankCategory category,
    required List<RankedPlayer> players,
  }) =>
      _col.doc(_iccId(format, category)).set({
        'format': format.key,
        'category': category.key,
        'players': players.map((p) => p.toMap()).toList(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

  static Future<DateTime?> getLastUpdated(RankFormat f, RankCategory c) async {
    final snap = await _col.doc(_iccId(f, c)).get();
    return _ts(snap);
  }

  // ── Tournament ───────────────────────────────────────────
  static Stream<List<RankedPlayer>> streamTournamentRankings(
          String id, RankCategory c) =>
      _col.doc(_tId(id, c)).snapshots().map(_parsePlayers);

  static Future<List<RankedPlayer>> fetchTournamentRankings(
          String id, RankCategory c) async =>
      _parsePlayers(await _col.doc(_tId(id, c)).get());

  static Future<void> saveTournamentRankings({
    required String tournamentId,
    required String tournamentName,
    required RankCategory category,
    required List<RankedPlayer> players,
  }) =>
      _col.doc(_tId(tournamentId, category)).set({
        'tournamentId': tournamentId,
        'tournamentName': tournamentName,
        'category': category.key,
        'players': players.map((p) => p.toMap()).toList(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

  static Future<DateTime?> getTournamentLastUpdated(
          String id, RankCategory c) async =>
      _ts(await _col.doc(_tId(id, c)).get());

  /// Deletes ALL ranking docs for a tournament
  static Future<void> resetTournamentRankings(String tournamentId) async {
    final batch = FirebaseFirestore.instance.batch();
    for (final cat in RankCategory.values) {
      batch.delete(_col.doc(_tId(tournamentId, cat)));
    }
    await batch.commit();
  }

  // ── Config ───────────────────────────────────────────────

  /// App: stream active tournament. Falls back to isLast=true if none active.
  static Stream<TournamentConfig?> streamCurrentTournament() {
    return _configDoc.snapshots().map((snap) {
      if (!snap.exists) return null;
      final data = snap.data() as Map<String, dynamic>;
      final list = (data['active'] as List<dynamic>? ?? [])
          .map((e) => TournamentConfig.fromMap(e as Map<String, dynamic>))
          .toList();
      // Prefer active first
      final active = list.where((t) => t.isActive).toList();
      if (active.isNotEmpty) return active.first;
      // Fall back to last
      final last = list.where((t) => t.isLast).toList();
      if (last.isNotEmpty) return last.first;
      return null;
    });
  }

  /// Admin: fetch all tournaments
  static Future<List<TournamentConfig>> fetchAllTournaments() async {
    final snap = await _configDoc.get();
    if (!snap.exists) return [];
    final data = snap.data() as Map<String, dynamic>;
    return (data['active'] as List<dynamic>? ?? [])
        .map((e) => TournamentConfig.fromMap(e as Map<String, dynamic>))
        .toList();
  }

  static Future<void> saveTournaments(List<TournamentConfig> tournaments) =>
      _configDoc.set({
        'active': tournaments.map((t) => t.toMap()).toList(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

  static Future<void> addTournament(TournamentConfig tournament) async {
    final existing = await fetchAllTournaments();
    existing.removeWhere((t) => t.id == tournament.id);
    existing.add(tournament);
    await saveTournaments(existing);
  }

  static Future<void> toggleTournament(String id, bool isActive) async {
    var existing = await fetchAllTournaments();
    // If activating this one, mark all others inactive + not last
    if (isActive) {
      existing = existing
          .map((t) => t.id == id
              ? t.copyWith(isActive: true, isLast: false)
              : t.copyWith(isActive: false, isLast: false))
          .toList();
    } else {
      // Deactivating — mark this one as last
      existing = existing
          .map((t) => t.id == id
              ? t.copyWith(isActive: false, isLast: true)
              : t.copyWith(isLast: false))
          .toList();
    }
    await saveTournaments(existing);
  }

  static Future<void> deleteTournament(String tournamentId) async {
    final existing = await fetchAllTournaments();
    existing.removeWhere((t) => t.id == tournamentId);
    await saveTournaments(existing);
    await resetTournamentRankings(tournamentId);
  }

  // ── Helpers ──────────────────────────────────────────────
  static List<RankedPlayer> _parsePlayers(dynamic snap) {
    if (snap is DocumentSnapshot && !snap.exists) return [];
    final data = (snap as DocumentSnapshot).data() as Map<String, dynamic>?;
    if (data == null) return [];
    final list = data['players'] as List<dynamic>? ?? [];
    return list
        .map((e) => RankedPlayer.fromMap(e as Map<String, dynamic>))
        .toList()
      ..sort((a, b) => a.rank.compareTo(b.rank));
  }

  static DateTime? _ts(DocumentSnapshot snap) {
    if (!snap.exists) return null;
    final data = snap.data() as Map<String, dynamic>?;
    return (data?['updatedAt'] as Timestamp?)?.toDate();
  }
}
