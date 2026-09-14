import 'package:cricket_admin/screens/dashboard/meme_form_screen.dart';
import 'package:cricket_admin/services/meme_admin_service.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

// ─────────────────────────────────────────────────────────────
//  MEME ADMIN SCREEN — List + manage
// ─────────────────────────────────────────────────────────────

class MemeAdminScreen extends StatelessWidget {
  const MemeAdminScreen({super.key});

  static const _bg = Color(0xFF0D0D0D);
  static const _red = Color(0xFFCC0000);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: _red,
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: const Text('Add Meme',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
        onPressed: () => Navigator.push(
            context, MaterialPageRoute(builder: (_) => const MemeFormScreen())),
      ),
      body: StreamBuilder<List<MemeModel>>(
        stream: MemeAdminService.memesStream(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(
                child:
                    CircularProgressIndicator(color: _red, strokeWidth: 1.5));
          }
          final memes = snap.data ?? [];
          // ignore: curly_braces_in_flow_control_structures
          if (memes.isEmpty)
            return _EmptyState(
              onAdd: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const MemeFormScreen())),
            );
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
            itemCount: memes.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (_, i) => _MemeCard(meme: memes[i]),
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  MEME CARD
// ─────────────────────────────────────────────────────────────

class _MemeCard extends StatelessWidget {
  final MemeModel meme;
  const _MemeCard({required this.meme});

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
        // ── Header ───────────────────────────────────
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: _surface2,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(13)),
          ),
          child: Row(children: [
            // Media type badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
              decoration: BoxDecoration(
                color: meme.isVideo
                    ? Colors.purple.withAlpha(30)
                    : Colors.blue.withAlpha(30),
                borderRadius: BorderRadius.circular(5),
                border: Border.all(
                  color: meme.isVideo
                      ? Colors.purple.withAlpha(80)
                      : Colors.blue.withAlpha(80),
                ),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(
                  meme.isVideo ? Icons.videocam_rounded : Icons.image_rounded,
                  size: 10,
                  color: meme.isVideo ? Colors.purple : Colors.blue,
                ),
                const SizedBox(width: 4),
                Text(
                  meme.isVideo ? 'VIDEO' : 'IMAGE',
                  style: TextStyle(
                    color: meme.isVideo ? Colors.purple : Colors.blue,
                    fontSize: 8,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                  ),
                ),
              ]),
            ),
            const SizedBox(width: 8),

            // Status dot
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: meme.isActive ? const Color(0xFF4CAF50) : Colors.white24,
              ),
            ),
            const SizedBox(width: 6),

            Expanded(
                child: Text(
              meme.caption.isNotEmpty ? meme.caption : 'No caption',
              style: TextStyle(
                color: meme.caption.isNotEmpty ? Colors.white : Colors.white38,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            )),

            if (meme.isPinned)
              const Padding(
                padding: EdgeInsets.only(left: 6),
                child:
                    Icon(Icons.push_pin_rounded, size: 14, color: Colors.amber),
              ),
          ]),
        ),

        // ── Body ─────────────────────────────────────
        Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Thumbnail ────────────────────────
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: SizedBox(
                  width: 90,
                  height: 90,
                  child: meme.thumbnailUrl.isNotEmpty
                      ? Image.network(
                          meme.thumbnailUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) =>
                              _PlaceholderThumb(isVideo: meme.isVideo),
                        )
                      : _PlaceholderThumb(isVideo: meme.isVideo),
                ),
              ),
              const SizedBox(width: 12),

              // ── Info + Actions ────────────────────
              Expanded(
                  child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Stats row
                  Row(children: [
                    _Stat(
                        icon: Icons.favorite_rounded,
                        value: meme.likes,
                        color: Colors.red),
                    const SizedBox(width: 14),
                    _Stat(
                        icon: Icons.share_rounded,
                        value: meme.shares,
                        color: Colors.blue),
                    const SizedBox(width: 14),
                    _Stat(
                        icon: Icons.visibility_rounded,
                        value: meme.views,
                        color: Colors.white38),
                  ]),
                  const SizedBox(height: 8),

                  // Tags
                  if (meme.tags.isNotEmpty)
                    Wrap(
                        spacing: 4,
                        children: meme.tags
                            .take(3)
                            .map((t) => Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: _red.withAlpha(15),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text('#$t',
                                      style: TextStyle(
                                          color: _red.withAlpha(200),
                                          fontSize: 9,
                                          fontWeight: FontWeight.w600)),
                                ))
                            .toList()),

                  const SizedBox(height: 10),

                  // Action buttons
                  Row(children: [
                    // Edit
                    _ActionBtn(
                      icon: Icons.edit_rounded,
                      color: Colors.white60,
                      onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => MemeFormScreen(meme: meme))),
                    ),
                    const SizedBox(width: 6),

                    // Pin toggle
                    _ActionBtn(
                      icon: Icons.push_pin_rounded,
                      color: meme.isPinned ? Colors.amber : Colors.white24,
                      onTap: () => MemeAdminService.togglePinned(
                          meme.id, !meme.isPinned),
                    ),
                    const SizedBox(width: 6),

                    // Active toggle
                    _ActionBtn(
                      icon: meme.isActive
                          ? Icons.visibility_rounded
                          : Icons.visibility_off_rounded,
                      color: meme.isActive
                          ? const Color(0xFF4CAF50)
                          : Colors.white24,
                      onTap: () => MemeAdminService.toggleActive(
                          meme.id, !meme.isActive),
                    ),
                    const SizedBox(width: 6),

                    // Delete
                    _ActionBtn(
                      icon: Icons.delete_outline_rounded,
                      color: Colors.white24,
                      onTap: () => _confirmDelete(context),
                    ),
                  ]),
                ],
              )),
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
        title: const Text('Delete Meme?',
            style: TextStyle(color: Colors.white, fontSize: 16)),
        content: const Text('This meme will be permanently deleted.',
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
                style: TextStyle(
                    color: Color(0xFFCC0000), fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
    if (ok == true) await MemeAdminService.deleteMeme(meme.id);
  }
}

// ─────────────────────────────────────────────────────────────
//  SMALL WIDGETS
// ─────────────────────────────────────────────────────────────

class _Stat extends StatelessWidget {
  final IconData icon;
  final int value;
  final Color color;
  const _Stat({required this.icon, required this.value, required this.color});

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text('$value',
              style: TextStyle(
                  color: color, fontSize: 11, fontWeight: FontWeight.w600)),
        ],
      );
}

class _ActionBtn extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  const _ActionBtn(
      {required this.icon, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(
            color: color.withAlpha(15),
            borderRadius: BorderRadius.circular(7),
            border: Border.all(color: color.withAlpha(40)),
          ),
          child: Icon(icon, size: 14, color: color),
        ),
      );
}

class _PlaceholderThumb extends StatelessWidget {
  final bool isVideo;
  const _PlaceholderThumb({required this.isVideo});

  @override
  Widget build(BuildContext context) => Container(
        color: const Color(0xFF0D0D0D),
        child: Center(
            child: Icon(
          isVideo ? Icons.videocam_rounded : Icons.image_rounded,
          color: Colors.white12,
          size: 28,
        )),
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
            child: const Text('😂',
                textAlign: TextAlign.center, style: TextStyle(fontSize: 32)),
          ),
          const SizedBox(height: 20),
          const Text('No Memes Yet',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          const Text('Add cricket memes for users to enjoy!',
              style: TextStyle(color: Colors.white38, fontSize: 13)),
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
                Text('Add Meme',
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
