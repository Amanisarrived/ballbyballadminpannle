import 'package:cricket_admin/screens/dashboard/fantasy_setup_screen.dart';
import 'package:cricket_admin/screens/dashboard/fantasy_stats_screen.dart';
import 'package:cricket_admin/services/fantasy_service.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

// ─────────────────────────────────────────────────────────────
//  FANTASY ADMIN SCREEN
//  All fantasy matches list + create new + navigate to stats
// ─────────────────────────────────────────────────────────────

class FantasyAdminScreen extends StatelessWidget {
  const FantasyAdminScreen({super.key});

  static const _bg = Color(0xFF0D0D0D);
  static const _surface = Color(0xFF141414);
  static const _border = Color(0xFF232323);
  static const _red = Color(0xFFCC0000);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _surface,
        elevation: 0,
        title: const Row(children: [
          Icon(Icons.emoji_events_rounded, color: _red, size: 18),
          SizedBox(width: 10),
          Text('Fantasy Matches',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w700)),
        ]),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: _border),
        ),
        actions: [
          // Create new match button
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: TextButton.icon(
              onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const FantasySetupScreen())),
              icon: const Icon(Icons.add_rounded, color: _red, size: 18),
              label: const Text('New Match',
                  style: TextStyle(
                      color: _red, fontSize: 13, fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
      body: StreamBuilder<List<FantasyMatch>>(
        stream: FantasyService.matchesStream(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(
                child:
                    CircularProgressIndicator(color: _red, strokeWidth: 1.5));
          }

          final matches = snap.data ?? [];

          if (matches.isEmpty) {
            return _EmptyState(
              onCreateTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const FantasySetupScreen())),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: matches.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (_, i) => _MatchCard(match: matches[i]),
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  MATCH CARD
// ─────────────────────────────────────────────────────────────

class _MatchCard extends StatelessWidget {
  final FantasyMatch match;
  const _MatchCard({required this.match});

  static const _surface = Color(0xFF141414);
  static const _surface2 = Color(0xFF1A1A1A);
  static const _border = Color(0xFF232323);
  static const _red = Color(0xFFCC0000);

  Color get _statusColor => switch (match.status) {
        'upcoming' => const Color(0xFF2196F3),
        'live' => const Color(0xFF4CAF50),
        'completed' => Colors.white38,
        _ => Colors.white38,
      };

  String get _statusLabel => switch (match.status) {
        'upcoming' => 'UPCOMING',
        'live' => '● LIVE',
        'completed' => 'COMPLETED',
        _ => match.status.toUpperCase(),
      };

  @override
  Widget build(BuildContext context) {
    final deadline = match.predictionDeadline;
    final deadlineStr = deadline != null
        ? DateFormat('dd MMM • hh:mm a').format(deadline)
        : '—';

    return Container(
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _border),
      ),
      child: Column(children: [
        // ── Header ───────────────────────────────────────
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
                      letterSpacing: 0.8)),
            ),
            const Spacer(),

            // Participants count
            Row(children: [
              Icon(Icons.people_rounded, color: Colors.white38, size: 13),
              const SizedBox(width: 4),
              Text('${match.totalParticipants} joined',
                  style: const TextStyle(color: Colors.white38, fontSize: 11)),
            ]),
          ]),
        ),

        // ── Body ─────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Match title from featured_match
              const Text('Featured Match',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),

              // Deadline
              Row(children: [
                const Icon(Icons.schedule_rounded,
                    color: Colors.white38, size: 13),
                const SizedBox(width: 5),
                Text('Deadline: $deadlineStr',
                    style:
                        const TextStyle(color: Colors.white38, fontSize: 11)),
              ]),
              const SizedBox(height: 6),

              // Credits count
              Row(children: [
                const Icon(Icons.people_outline_rounded,
                    color: Colors.white38, size: 13),
                const SizedBox(width: 5),
                Text('${match.playerCredits.length} players with credits',
                    style:
                        const TextStyle(color: Colors.white38, fontSize: 11)),
              ]),

              const SizedBox(height: 16),

              // ── Action buttons ────────────────────────
              Row(children: [
                // Edit / Setup
                if (!match.isCompleted)
                  Expanded(
                      child: _ActionBtn(
                    label: 'Edit Setup',
                    icon: Icons.edit_rounded,
                    color: Colors.white60,
                    onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) =>
                                FantasySetupScreen(existingMatch: match))),
                  )),

                if (!match.isCompleted) const SizedBox(width: 8),

                // Stats entry
                Expanded(
                    child: _ActionBtn(
                  label: match.isCompleted ? 'View Results' : 'Enter Stats',
                  icon: match.isCompleted
                      ? Icons.leaderboard_rounded
                      : Icons.edit_note_rounded,
                  color: _red,
                  onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => FantasyStatsScreen(match: match))),
                )),
              ]),

              // Status change buttons
              if (!match.isCompleted) ...[
                const SizedBox(height: 8),
                Row(children: [
                  if (match.isUpcoming)
                    Expanded(
                        child: _ActionBtn(
                      label: 'Lock Predictions',
                      icon: Icons.lock_rounded,
                      color: const Color(0xFFFF9800),
                      onTap: () => _updateStatus(context, 'live'),
                    )),
                  if (match.isLive) ...[
                    Expanded(
                        child: _ActionBtn(
                      label: 'Reopen',
                      icon: Icons.lock_open_rounded,
                      color: const Color(0xFF2196F3),
                      onTap: () => _updateStatus(context, 'upcoming'),
                    )),
                  ],
                ]),
              ],

              // Delete button
              const SizedBox(height: 8),
              _ActionBtn(
                label: 'Delete Match',
                icon: Icons.delete_outline_rounded,
                color: Colors.white24,
                onTap: () => _confirmDelete(context),
                fullWidth: true,
              ),
            ],
          ),
        ),
      ]),
    );
  }

  Future<void> _updateStatus(BuildContext ctx, String status) async {
    await FantasyService.updateMatchStatus(match.id, status);
  }

  Future<void> _confirmDelete(BuildContext ctx) async {
    final confirm = await showDialog<bool>(
      context: ctx,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Text('Delete Match?',
            style: TextStyle(color: Colors.white, fontSize: 16)),
        content: const Text(
            'This will delete the fantasy match. User teams will remain.',
            style: TextStyle(color: Colors.white54, fontSize: 13)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child:
                const Text('Cancel', style: TextStyle(color: Colors.white38)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete',
                style: TextStyle(color: Color(0xFFCC0000))),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await FantasyService.deleteMatch(match.id);
    }
  }
}

// ─────────────────────────────────────────────────────────────
//  ACTION BUTTON
// ─────────────────────────────────────────────────────────────

class _ActionBtn extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final bool fullWidth;

  const _ActionBtn({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
    this.fullWidth = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: fullWidth ? double.infinity : null,
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: color.withAlpha(15),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withAlpha(50)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 14),
            const SizedBox(width: 6),
            Text(label,
                style: TextStyle(
                    color: color, fontSize: 12, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  EMPTY STATE
// ─────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final VoidCallback onCreateTap;
  const _EmptyState({required this.onCreateTap});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
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
          const Text('No Fantasy Matches',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          const Text('Create a fantasy match\nfor the upcoming game',
              style:
                  TextStyle(color: Colors.white38, fontSize: 13, height: 1.6),
              textAlign: TextAlign.center),
          const SizedBox(height: 24),
          GestureDetector(
            onTap: onCreateTap,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFCC0000),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.add_rounded, color: Colors.white, size: 18),
                  SizedBox(width: 8),
                  Text('Create Match',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w700)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
