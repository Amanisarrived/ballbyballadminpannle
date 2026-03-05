import 'package:cloud_firestore/cloud_firestore.dart';

// ════════════════════════════════════════════════════════════
//  MODELS
// ════════════════════════════════════════════════════════════

class TeamStanding {
  final String name;
  final String logo;
  final int played;
  final int won;
  final int lost;
  final int points;
  final double nrr;

  const TeamStanding({
    required this.name,
    required this.logo,
    required this.played,
    required this.won,
    required this.lost,
    required this.points,
    required this.nrr,
  });

  factory TeamStanding.fromMap(Map<String, dynamic> m) => TeamStanding(
        name: m['name'] as String? ?? '',
        logo: m['logo'] as String? ?? '',
        played: (m['played'] as num?)?.toInt() ?? 0,
        won: (m['won'] as num?)?.toInt() ?? 0,
        lost: (m['lost'] as num?)?.toInt() ?? 0,
        points: (m['points'] as num?)?.toInt() ?? 0,
        nrr: (m['nrr'] as num?)?.toDouble() ?? 0.0,
      );

  Map<String, dynamic> toMap() => {
        'name': name,
        'logo': logo,
        'played': played,
        'won': won,
        'lost': lost,
        'points': points,
        'nrr': nrr,
      };

  TeamStanding copyWith({
    String? name,
    String? logo,
    int? played,
    int? won,
    int? lost,
    int? points,
    double? nrr,
  }) =>
      TeamStanding(
        name: name ?? this.name,
        logo: logo ?? this.logo,
        played: played ?? this.played,
        won: won ?? this.won,
        lost: lost ?? this.lost,
        points: points ?? this.points,
        nrr: nrr ?? this.nrr,
      );
}

class TableGroup {
  final String groupName; // ignored if single table
  final List<TeamStanding> teams;

  const TableGroup({
    required this.groupName,
    required this.teams,
  });

  factory TableGroup.fromMap(Map<String, dynamic> m) => TableGroup(
        groupName: m['groupName'] as String? ?? '',
        teams: ((m['teams'] as List?) ?? [])
            .map((t) => TeamStanding.fromMap(t as Map<String, dynamic>))
            .toList(),
      );

  Map<String, dynamic> toMap() => {
        'groupName': groupName,
        'teams': teams.map((t) => t.toMap()).toList(),
      };

  TableGroup copyWith({String? groupName, List<TeamStanding>? teams}) =>
      TableGroup(
        groupName: groupName ?? this.groupName,
        teams: teams ?? this.teams,
      );
}

class PointsTable {
  final String tournamentName;
  final bool isGroupStage;
  final bool isVisible;
  final List<TableGroup> groups;

  const PointsTable({
    required this.tournamentName,
    required this.isGroupStage,
    required this.isVisible,
    required this.groups,
  });

  factory PointsTable.fromDoc(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return PointsTable(
      tournamentName: d['tournamentName'] as String? ?? '',
      isGroupStage: d['isGroupStage'] as bool? ?? false,
      isVisible: d['isVisible'] as bool? ?? false,
      groups: ((d['groups'] as List?) ?? [])
          .map((g) => TableGroup.fromMap(g as Map<String, dynamic>))
          .toList(),
    );
  }

  // Empty default
  factory PointsTable.empty() => const PointsTable(
        tournamentName: '',
        isGroupStage: false,
        isVisible: false,
        groups: [],
      );
}
