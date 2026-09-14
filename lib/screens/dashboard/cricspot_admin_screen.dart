import 'package:cricket_admin/screens/dashboard/grounds_list_screen.dart';
import 'package:cricket_admin/screens/dashboard/tournament_list_screen.dart';
import 'package:flutter/material.dart';

// ─────────────────────────────────────────────────────────────
//  CRICSPOT ADMIN SCREEN
//  Main screen with Grounds | Tournaments tabs
// ─────────────────────────────────────────────────────────────

class CricSpotAdminScreen extends StatefulWidget {
  const CricSpotAdminScreen({super.key});

  @override
  State<CricSpotAdminScreen> createState() => _CricSpotAdminScreenState();
}

class _CricSpotAdminScreenState extends State<CricSpotAdminScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tab;

  static const _bg = Color(0xFF0D0D0D);
  static const _surface = Color(0xFF141414);
  static const _border = Color(0xFF232323);
  static const _red = Color(0xFFCC0000);

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _surface,
        elevation: 0,
        title: const Row(children: [
          Icon(Icons.location_on_rounded, color: _red, size: 18),
          SizedBox(width: 8),
          Text('CricSpot',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w700)),
        ]),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(49),
          child: Column(children: [
            Container(height: 1, color: _border),
            TabBar(
              controller: _tab,
              indicatorColor: _red,
              indicatorWeight: 2,
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white38,
              labelStyle:
                  const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
              unselectedLabelStyle:
                  const TextStyle(fontSize: 13, fontWeight: FontWeight.w400),
              tabs: const [
                Tab(text: '🏟️  Grounds'),
                Tab(text: '🏆  Tournaments'),
              ],
            ),
          ]),
        ),
      ),
      body: TabBarView(
        controller: _tab,
        children: const [
          GroundsListScreen(),
          TournamentsListScreen(),
        ],
      ),
    );
  }
}
