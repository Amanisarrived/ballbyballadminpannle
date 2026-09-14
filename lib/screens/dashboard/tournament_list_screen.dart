import 'package:cricket_admin/services/cricspot_service.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'tournament_form_screen.dart';

// ─────────────────────────────────────────────────────────────
//  TOURNAMENTS LIST SCREEN
// ─────────────────────────────────────────────────────────────

class TournamentsListScreen extends StatelessWidget {
  const TournamentsListScreen({super.key});

  static const _bg = Color(0xFF0D0D0D);
  static const _red = Color(0xFFCC0000);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: _red,
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: const Text('Add Tournament',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
        onPressed: () => Navigator.push(context,
            MaterialPageRoute(builder: (_) => const TournamentFormScreen())),
      ),
      body: StreamBuilder<List<CricTournament>>(
        stream: CricSpotAdminService.tournamentsStream(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(
                child:
                    CircularProgressIndicator(color: _red, strokeWidth: 1.5));
          }

          final tournaments = snap.data ?? [];

          if (tournaments.isEmpty) {
            return _EmptyState(
              onAdd: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const TournamentFormScreen())),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
            itemCount: tournaments.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (_, i) => _TournamentCard(tournament: tournaments[i]),
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  TOURNAMENT CARD
// ─────────────────────────────────────────────────────────────

class _TournamentCard extends StatelessWidget {
  final CricTournament tournament;
  const _TournamentCard({required this.tournament});

  static const _surface = Color(0xFF141414);
  static const _surface2 = Color(0xFF1A1A1A);
  static const _border = Color(0xFF232323);
  static const _red = Color(0xFFCC0000);

  Color get _statusColor => switch (tournament.status) {
        'upcoming' => const Color(0xFF2196F3),
        'ongoing' => const Color(0xFF4CAF50),
        'completed' => Colors.white38,
        _ => Colors.white38,
      };

  String get _statusLabel => switch (tournament.status) {
        'upcoming' => 'UPCOMING',
        'ongoing' => '● LIVE',
        'completed' => 'COMPLETED',
        _ => tournament.status.toUpperCase(),
      };

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('dd MMM yyyy');
    return Container(
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _border),
      ),
      child: Column(children: [
        // ── Header ───────────────────────────────────────
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: _surface2,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(13)),
          ),
          child: Row(children: [
            // Status badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: _statusColor.withAlpha(20),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: _statusColor.withAlpha(60)),
              ),
              child: Text(_statusLabel,
                  style: TextStyle(
                      color: _statusColor,
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5)),
            ),
            const SizedBox(width: 10),
            Expanded(
                child: Text(tournament.name,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w700),
                    overflow: TextOverflow.ellipsis)),
            if (tournament.isPremium)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.amber.withAlpha(20),
                  borderRadius: BorderRadius.circular(5),
                  border: Border.all(color: Colors.amber.withAlpha(60)),
                ),
                child: const Text('⭐', style: TextStyle(fontSize: 10)),
              ),
          ]),
        ),

        // ── Body ─────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Venue + Format
              Row(children: [
                const Icon(Icons.location_on_rounded,
                    color: Colors.white38, size: 13),
                const SizedBox(width: 4),
                Expanded(
                    child: Text('${tournament.area}, ${tournament.city}',
                        style: const TextStyle(
                            color: Colors.white54, fontSize: 12),
                        overflow: TextOverflow.ellipsis)),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.white.withAlpha(8),
                    borderRadius: BorderRadius.circular(5),
                    border: Border.all(color: Colors.white.withAlpha(15)),
                  ),
                  child: Text(tournament.format,
                      style: TextStyle(
                          color: Colors.white.withAlpha(120),
                          fontSize: 10,
                          fontWeight: FontWeight.w600)),
                ),
              ]),

              const SizedBox(height: 8),

              // Dates
              Row(children: [
                const Icon(Icons.calendar_today_rounded,
                    color: Colors.white38, size: 13),
                const SizedBox(width: 4),
                Text(
                  tournament.startDate != null
                      ? '${fmt.format(tournament.startDate!)} → ${tournament.endDate != null ? fmt.format(tournament.endDate!) : '—'}'
                      : '—',
                  style: const TextStyle(color: Colors.white54, fontSize: 12),
                ),
              ]),

              const SizedBox(height: 8),

              // Slots + Prize + Entry
              Row(children: [
                _InfoChip(
                  label:
                      '${tournament.filledSlots}/${tournament.totalSlots} teams',
                  color: tournament.isFull ? _red : const Color(0xFF4CAF50),
                ),
                const SizedBox(width: 8),
                _InfoChip(
                    label: tournament.entryFeeDisplay, color: Colors.white54),
                const SizedBox(width: 8),
                _InfoChip(label: tournament.prize, color: Colors.amber),
              ]),

              const SizedBox(height: 10),

              // Analytics
              Row(children: [
                _TapStat(
                    icon: Icons.call_rounded,
                    label: 'Calls',
                    value: tournament.callTaps,
                    color: const Color(0xFF4CAF50)),
                const SizedBox(width: 16),
                _TapStat(
                    icon: Icons.chat_rounded,
                    label: 'WhatsApp',
                    value: tournament.whatsappTaps,
                    color: const Color(0xFF25D366)),
              ]),

              const SizedBox(height: 14),

              // Status change buttons
              if (!tournament.isCompleted) ...[
                Row(children: [
                  if (tournament.isUpcoming)
                    Expanded(
                        child: _ActionBtn(
                      label: 'Mark Ongoing',
                      icon: Icons.play_arrow_rounded,
                      color: const Color(0xFF4CAF50),
                      onTap: () => CricSpotAdminService.updateTournamentStatus(
                          tournament.id, 'ongoing'),
                    )),
                  if (tournament.isOngoing) ...[
                    Expanded(
                        child: _ActionBtn(
                      label: 'Mark Completed',
                      icon: Icons.flag_rounded,
                      color: Colors.white60,
                      onTap: () => CricSpotAdminService.updateTournamentStatus(
                          tournament.id, 'completed'),
                    )),
                  ],
                  const SizedBox(width: 8),
                  Expanded(
                      child: _ActionBtn(
                    label: 'Edit',
                    icon: Icons.edit_rounded,
                    color: Colors.white60,
                    onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) =>
                                TournamentFormScreen(tournament: tournament))),
                  )),
                ]),
                const SizedBox(height: 8),
              ],

              // Active toggle + Delete
              Row(children: [
                Expanded(
                    child: GestureDetector(
                  onTap: () => CricSpotAdminService.toggleTournamentActive(
                      tournament.id, !tournament.isActive),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 9),
                    decoration: BoxDecoration(
                      color: tournament.isActive
                          ? const Color(0xFF4CAF50).withAlpha(15)
                          : Colors.white.withAlpha(8),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                          color: tournament.isActive
                              ? const Color(0xFF4CAF50).withAlpha(50)
                              : Colors.white.withAlpha(15)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          tournament.isActive
                              ? Icons.visibility_rounded
                              : Icons.visibility_off_rounded,
                          size: 13,
                          color: tournament.isActive
                              ? const Color(0xFF4CAF50)
                              : Colors.white38,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          tournament.isActive ? 'Active' : 'Inactive',
                          style: TextStyle(
                              color: tournament.isActive
                                  ? const Color(0xFF4CAF50)
                                  : Colors.white38,
                              fontSize: 12,
                              fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                )),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () => _confirmDelete(context),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
                    decoration: BoxDecoration(
                      color: Colors.white.withAlpha(8),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.white.withAlpha(15)),
                    ),
                    child: const Icon(Icons.delete_outline_rounded,
                        size: 16, color: Colors.white38),
                  ),
                ),
              ]),
            ],
          ),
        ),
      ]),
    );
  }

  Future<void> _confirmDelete(BuildContext ctx) async {
    final ok = await showDialog<bool>(
      context: ctx,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Text('Delete Tournament?',
            style: TextStyle(color: Colors.white, fontSize: 16)),
        content: Text('${tournament.name} will be permanently deleted.',
            style: const TextStyle(color: Colors.white54, fontSize: 13)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child:
                const Text('Cancel', style: TextStyle(color: Colors.white38)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete',
                style: TextStyle(
                    color: Color(0xFFCC0000), fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
    if (ok == true) {
      await CricSpotAdminService.deleteTournament(tournament.id);
    }
  }
}

// ─────────────────────────────────────────────────────────────
//  SMALL WIDGETS
// ─────────────────────────────────────────────────────────────

class _InfoChip extends StatelessWidget {
  final String label;
  final Color color;
  const _InfoChip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: color.withAlpha(15),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: color.withAlpha(50)),
        ),
        child: Text(label,
            style: TextStyle(
                color: color, fontSize: 10, fontWeight: FontWeight.w600)),
      );
}

class _TapStat extends StatelessWidget {
  final IconData icon;
  final String label;
  final int value;
  final Color color;
  const _TapStat(
      {required this.icon,
      required this.label,
      required this.value,
      required this.color});

  @override
  Widget build(BuildContext context) => Row(children: [
        Icon(icon, size: 12, color: color.withAlpha(160)),
        const SizedBox(width: 4),
        Text('$value',
            style: TextStyle(
                color: color, fontSize: 12, fontWeight: FontWeight.w700)),
      ]);
}

class _ActionBtn extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  const _ActionBtn(
      {required this.label,
      required this.icon,
      required this.color,
      required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: color.withAlpha(12),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: color.withAlpha(50)),
          ),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(icon, color: color, size: 13),
            const SizedBox(width: 6),
            Text(label,
                style: TextStyle(
                    color: color, fontSize: 12, fontWeight: FontWeight.w600)),
          ]),
        ),
      );
}

class _EmptyState extends StatelessWidget {
  final VoidCallback onAdd;
  const _EmptyState({required this.onAdd});

  @override
  Widget build(BuildContext context) => Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: const Color(0xFFCC0000).withAlpha(15),
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFFCC0000).withAlpha(40)),
            ),
            child: const Icon(Icons.emoji_events_rounded,
                color: Color(0xFFCC0000), size: 32),
          ),
          const SizedBox(height: 20),
          const Text('No Tournaments Yet',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          const Text(
              'Add local cricket tournaments\nfor users to discover & register',
              style:
                  TextStyle(color: Colors.white38, fontSize: 13, height: 1.6),
              textAlign: TextAlign.center),
          const SizedBox(height: 24),
          GestureDetector(
            onTap: onAdd,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFCC0000),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.add_rounded, color: Colors.white, size: 18),
                SizedBox(width: 8),
                Text('Add Tournament',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w700)),
              ]),
            ),
          ),
        ]),
      );
}
