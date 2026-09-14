import 'package:cricket_admin/screens/dashboard/ground_slot_screen.dart';
import 'package:cricket_admin/services/cricspot_service.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'ground_form_screen.dart';

class GroundsListScreen extends StatelessWidget {
  const GroundsListScreen({super.key});

  static const _bg = Color(0xFF0D0D0D);
  static const _red = Color(0xFFCC0000);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: _red,
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: const Text('Add Ground',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
        onPressed: () => Navigator.push(context,
            MaterialPageRoute(builder: (_) => const GroundFormScreen())),
      ),
      body: StreamBuilder<List<CricGround>>(
        stream: CricSpotAdminService.groundsStream(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(
                child:
                    CircularProgressIndicator(color: _red, strokeWidth: 1.5));
          }
          final grounds = snap.data ?? [];
          if (grounds.isEmpty) {
            return _EmptyState(
                onAdd: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const GroundFormScreen())));
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
            itemCount: grounds.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (_, i) => _GroundCard(ground: grounds[i]),
          );
        },
      ),
    );
  }
}

class _GroundCard extends StatelessWidget {
  final CricGround ground;
  const _GroundCard({required this.ground});

  static const _surface = Color(0xFF141414);
  static const _surface2 = Color(0xFF1A1A1A);
  static const _border = Color(0xFF232323);
  static const _red = Color(0xFFCC0000);

  @override
  Widget build(BuildContext context) {
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
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color:
                    ground.isActive ? const Color(0xFF4CAF50) : Colors.white24,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
                child: Text(ground.name,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w700),
                    overflow: TextOverflow.ellipsis)),
            if (ground.isPremium)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.amber.withAlpha(20),
                  borderRadius: BorderRadius.circular(5),
                  border: Border.all(color: Colors.amber.withAlpha(60)),
                ),
                child: const Text('⭐ PREMIUM',
                    style: TextStyle(
                        color: Colors.amber,
                        fontSize: 8,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5)),
              ),
          ]),
        ),

        // ── Body ─────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Area + Price
              Row(children: [
                const Icon(Icons.location_on_rounded,
                    color: Colors.white38, size: 13),
                const SizedBox(width: 4),
                Text('${ground.area}, ${ground.city}',
                    style:
                        const TextStyle(color: Colors.white54, fontSize: 12)),
                const Spacer(),
                Text(ground.priceDisplay,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w700)),
              ]),
              const SizedBox(height: 6),

              // Courts + Ground Type
              Row(children: [
                const Icon(Icons.sports_cricket_rounded,
                    color: Colors.white38, size: 13),
                const SizedBox(width: 4),
                Text('${ground.courts} court${ground.courts > 1 ? 's' : ''}',
                    style:
                        const TextStyle(color: Colors.white54, fontSize: 12)),
                const SizedBox(width: 12),
                const Icon(Icons.grass_rounded,
                    color: Colors.white38, size: 13),
                const SizedBox(width: 4),
                Text(ground.groundType.toUpperCase(),
                    style:
                        const TextStyle(color: Colors.white54, fontSize: 12)),
              ]),
              const SizedBox(height: 10),

              // Analytics
              Row(children: [
                _TapStat(
                    icon: Icons.call_rounded,
                    label: 'Calls',
                    value: ground.callTaps,
                    color: const Color(0xFF4CAF50)),
                const SizedBox(width: 16),
                _TapStat(
                    icon: Icons.chat_rounded,
                    label: 'WhatsApp',
                    value: ground.whatsappTaps,
                    color: const Color(0xFF25D366)),
                const SizedBox(width: 16),
                _TapStat(
                    icon: Icons.language_rounded,
                    label: 'Web',
                    value: ground.websiteTaps,
                    color: const Color(0xFF2196F3)),
                const Spacer(),
                Text('${ground.totalTaps} total taps',
                    style: TextStyle(
                        color: Colors.white.withAlpha(40), fontSize: 10)),
              ]),

              const SizedBox(height: 14),

              // Action buttons
              Row(children: [
                Expanded(
                    child: _ActionBtn(
                  label: 'Manage Slots',
                  icon: Icons.calendar_month_rounded,
                  color: Colors.amber,
                  onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => GroundSlotsScreen(ground: ground))),
                )),
                const SizedBox(width: 8),
                Expanded(
                    child: _ActionBtn(
                  label: 'Edit',
                  icon: Icons.edit_rounded,
                  color: Colors.white60,
                  onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => GroundFormScreen(ground: ground))),
                )),
              ]),
              const SizedBox(height: 8),

              // Toggle + Delete
              Row(children: [
                Expanded(
                    child: GestureDetector(
                  onTap: () => CricSpotAdminService.toggleGroundActive(
                      ground.id, !ground.isActive),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 9),
                    decoration: BoxDecoration(
                      color: ground.isActive
                          ? const Color(0xFF4CAF50).withAlpha(15)
                          : Colors.white.withAlpha(8),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                          color: ground.isActive
                              ? const Color(0xFF4CAF50).withAlpha(50)
                              : Colors.white.withAlpha(15)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                            ground.isActive
                                ? Icons.visibility_rounded
                                : Icons.visibility_off_rounded,
                            size: 13,
                            color: ground.isActive
                                ? const Color(0xFF4CAF50)
                                : Colors.white38),
                        const SizedBox(width: 5),
                        Text(ground.isActive ? 'Active' : 'Inactive',
                            style: TextStyle(
                                color: ground.isActive
                                    ? const Color(0xFF4CAF50)
                                    : Colors.white38,
                                fontSize: 12,
                                fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                )),
                const SizedBox(width: 8),
                Expanded(
                    child: GestureDetector(
                  onTap: () => CricSpotAdminService.toggleGroundPremium(
                      ground.id, !ground.isPremium),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 9),
                    decoration: BoxDecoration(
                      color: ground.isPremium
                          ? Colors.amber.withAlpha(15)
                          : Colors.white.withAlpha(8),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                          color: ground.isPremium
                              ? Colors.amber.withAlpha(50)
                              : Colors.white.withAlpha(15)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.star_rounded,
                            size: 13,
                            color: ground.isPremium
                                ? Colors.amber
                                : Colors.white38),
                        const SizedBox(width: 5),
                        Text('Premium',
                            style: TextStyle(
                                color: ground.isPremium
                                    ? Colors.amber
                                    : Colors.white38,
                                fontSize: 12,
                                fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                )),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () => _confirmDelete(context),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
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
        title: const Text('Delete Ground?',
            style: TextStyle(color: Colors.white, fontSize: 16)),
        content: Text('${ground.name} will be permanently deleted.',
            style: const TextStyle(color: Colors.white54, fontSize: 13)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel',
                  style: TextStyle(color: Colors.white38))),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Delete',
                  style: TextStyle(
                      color: Color(0xFFCC0000), fontWeight: FontWeight.w700))),
        ],
      ),
    );
    if (ok == true) await CricSpotAdminService.deleteGround(ground.id);
  }
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
            child: const Icon(Icons.stadium_rounded,
                color: Color(0xFFCC0000), size: 32),
          ),
          const SizedBox(height: 20),
          const Text('No Grounds Yet',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          const Text('Add Delhi cricket grounds\nfor users to discover',
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
                Text('Add Ground',
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
