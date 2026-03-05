import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cricket_admin/models/teamstanding_model.dart';

class PointsTableService {
  static final _doc =
      FirebaseFirestore.instance.collection('app_data').doc('points_table');

  // ── Stream ───────────────────────────────────────────────
  static Stream<DocumentSnapshot> stream() => _doc.snapshots();

  // ── Fetch once ───────────────────────────────────────────
  static Future<DocumentSnapshot> fetch() => _doc.get();

  // ── Save full table ──────────────────────────────────────
  static Future<void> save(PointsTable table) => _doc.set({
        'tournamentName': table.tournamentName,
        'isGroupStage': table.isGroupStage,
        'isVisible': table.isVisible,
        'groups': table.groups.map((g) => g.toMap()).toList(),
      });

  // ── Toggle visibility only ───────────────────────────────
  static Future<void> setVisible(bool value) =>
      _doc.update({'isVisible': value});

  // ── Toggle group stage mode ──────────────────────────────
  static Future<void> setGroupStage(bool value) =>
      _doc.update({'isGroupStage': value});
}
