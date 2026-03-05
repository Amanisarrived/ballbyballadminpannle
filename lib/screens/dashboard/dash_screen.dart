import 'package:cricket_admin/provider/admin_auth_provider.dart';
import 'package:cricket_admin/screens/dashboard/match_screen.dart';
import 'package:cricket_admin/screens/dashboard/notification_screen.dart';
import 'package:cricket_admin/screens/dashboard/player_screen.dart';
import 'package:cricket_admin/screens/dashboard/pointstable_screen.dart';
import 'package:cricket_admin/screens/dashboard/scoring_pannel.dart';
import 'package:cricket_admin/screens/dashboard/shop_banner_screen.dart';
import 'package:cricket_admin/screens/dashboard/shops_screen.dart';
import 'package:cricket_admin/screens/dashboard/teams_screen.dart';
import 'package:cricket_admin/screens/dashboard/toss_screen.dart';
import 'package:cricket_admin/screens/dashboard/upcoming_fixture_screen.dart';
import 'package:cricket_admin/screens/dashboard/winPrediction_screen.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

// ── Sidebar nav items ──────────────────────────────────────
enum AdminSection {
  matches,
  teams,
  players,
  scoring,
  toss,
  upcomingFixtures,
  shopScreen,
  shopbannerscreen,
  winpredictor,
  pointsTable,
  notifications, // TODO: implement notifications screen
}

extension AdminSectionExt on AdminSection {
  String get label {
    switch (this) {
      case AdminSection.matches:
        return 'Matches';
      case AdminSection.teams:
        return 'Teams';
      case AdminSection.players:
        return 'Players';
      case AdminSection.scoring:
        return 'Scoring Panel';
      case AdminSection.toss:
        return 'Toss Setup';
      case AdminSection.upcomingFixtures:
        return 'Upcoming Fixtures';
      case AdminSection.shopScreen:
        return 'Shop Screen';
      case AdminSection.shopbannerscreen:
        return 'Shop Banner Screen';
      case AdminSection.winpredictor:
        return 'Win Predictor';
      case AdminSection.pointsTable:
        return 'Points Table';
      case AdminSection.notifications:
        return 'Notifications';
    }
  }

  IconData get icon {
    switch (this) {
      case AdminSection.matches:
        return Icons.calendar_today_rounded;
      case AdminSection.teams:
        return Icons.groups_rounded;
      case AdminSection.players:
        return Icons.person_rounded;
      case AdminSection.scoring:
        return Icons.sports_cricket_rounded;
      case AdminSection.toss:
        return Icons.sports_score_rounded;
      case AdminSection.upcomingFixtures:
        return Icons.event_available_rounded;
      case AdminSection.shopScreen:
        return Icons.shop_rounded;
      case AdminSection.shopbannerscreen:
        return Icons.flag_rounded;
      case AdminSection.winpredictor:
        return Icons.bar_chart_rounded;
      case AdminSection.pointsTable:
        return Icons.table_chart_rounded;
      case AdminSection.notifications:
        return Icons.notifications_rounded;
    }
  }

  IconData get iconFilled {
    switch (this) {
      case AdminSection.matches:
        return Icons.calendar_today_rounded;
      case AdminSection.teams:
        return Icons.groups_rounded;
      case AdminSection.players:
        return Icons.person_rounded;
      case AdminSection.scoring:
        return Icons.sports_cricket_rounded;
      case AdminSection.toss:
        return Icons.sports_score_rounded;
      case AdminSection.upcomingFixtures:
        return Icons.event_available_rounded;
      case AdminSection.shopScreen:
        return Icons.shop_rounded;
      case AdminSection.shopbannerscreen:
        return Icons.flag_rounded;
      case AdminSection.winpredictor:
        return Icons.bar_chart_rounded;
      case AdminSection.pointsTable:
        return Icons.table_chart_rounded;
      case AdminSection.notifications:
        return Icons.notifications_rounded;
    }
  }
}

// ── Main dashboard shell ───────────────────────────────────
class DashScreen extends StatefulWidget {
  const DashScreen({super.key});

  @override
  State<DashScreen> createState() => _DashScreenState();
}

class _DashScreenState extends State<DashScreen> {
  AdminSection _selected = AdminSection.matches;
  bool _sidebarCollapsed = false;

  static const _bg = Color(0xFF0D0D0D);
  static const _surface = Color(0xFF141414);
  static const _surface2 = Color(0xFF1A1A1A);
  static const _border = Color(0xFF232323);
  static const _accent = Colors.redAccent;
  static const _textPrimary = Color(0xFFE8E8E8);
  static const _textSecondary = Color(0xFF666666);

  @override
  Widget build(BuildContext context) {
    final isNarrow = MediaQuery.of(context).size.width < 800;

    return Scaffold(
      backgroundColor: _bg,
      body: Row(
        children: [
          // ── Sidebar ──
          AnimatedContainer(
            duration: const Duration(milliseconds: 260),
            curve: Curves.easeInOut,
            width: isNarrow ? 0 : (_sidebarCollapsed ? 68 : 240),
            child: isNarrow
                ? const SizedBox.shrink()
                : _Sidebar(
                    collapsed: _sidebarCollapsed,
                    selected: _selected,
                    onSelect: (s) => setState(() => _selected = s),
                    onToggleCollapse: () =>
                        setState(() => _sidebarCollapsed = !_sidebarCollapsed),
                    surface: _surface,
                    surface2: _surface2,
                    border: _border,
                    accent: _accent,
                    textPrimary: _textPrimary,
                    textSecondary: _textSecondary,
                  ),
          ),

          Expanded(
            child: Column(
              children: [
                _TopBar(
                  section: _selected,
                  isNarrow: isNarrow,
                  onMenuTap: isNarrow ? () => _showMobileDrawer(context) : null,
                  surface: _surface,
                  border: _border,
                  accent: _accent,
                  textPrimary: _textPrimary,
                  textSecondary: _textSecondary,
                ),
                // Body
                Expanded(
                  child: _ContentArea(section: _selected),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showMobileDrawer(BuildContext context) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'close',
      barrierColor: Colors.black.withOpacity(0.6),
      transitionDuration: const Duration(milliseconds: 220),
      pageBuilder: (_, __, ___) => const SizedBox.shrink(),
      transitionBuilder: (ctx, anim, _, __) {
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(-1, 0),
            end: Offset.zero,
          ).animate(CurvedAnimation(parent: anim, curve: Curves.easeOut)),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Material(
              color: Colors.transparent,
              child: _Sidebar(
                collapsed: false,
                selected: _selected,
                onSelect: (s) {
                  setState(() => _selected = s);
                  Navigator.pop(ctx);
                },
                onToggleCollapse: () {},
                surface: const Color(0xFF141414),
                surface2: const Color(0xFF1A1A1A),
                border: const Color(0xFF232323),
                accent: Colors.redAccent,
                textPrimary: const Color(0xFFE8E8E8),
                textSecondary: const Color(0xFF666666),
                isMobileDrawer: true,
              ),
            ),
          ),
        );
      },
    );
  }
}

// ── Sidebar widget ─────────────────────────────────────────
class _Sidebar extends StatelessWidget {
  final bool collapsed;
  final AdminSection selected;
  final ValueChanged<AdminSection> onSelect;
  final VoidCallback onToggleCollapse;
  final Color surface, surface2, border, accent, textPrimary, textSecondary;
  final bool isMobileDrawer;

  const _Sidebar({
    required this.collapsed,
    required this.selected,
    required this.onSelect,
    required this.onToggleCollapse,
    required this.surface,
    required this.surface2,
    required this.border,
    required this.accent,
    required this.textPrimary,
    required this.textSecondary,
    this.isMobileDrawer = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: isMobileDrawer ? 240 : null,
      height: double.infinity,
      decoration: BoxDecoration(
        color: surface,
        border: Border(right: BorderSide(color: border, width: 1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Brand ──
          SizedBox(
            height: 64,
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: collapsed ? 16 : 20,
              ),
              child: Row(
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: accent.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: accent.withOpacity(0.25)),
                    ),
                    child: Icon(
                      Icons.sports_cricket_rounded,
                      color: accent,
                      size: 18,
                    ),
                  ),
                  if (!collapsed) ...[
                    const SizedBox(width: 12),
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Cricket',
                          style: TextStyle(
                            color: textPrimary,
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.2,
                          ),
                        ),
                        Text(
                          'Admin Panel',
                          style: TextStyle(
                            color: textSecondary,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                    const Spacer(),
                    if (!isMobileDrawer)
                      _CollapseButton(
                        onTap: onToggleCollapse,
                        textSecondary: textSecondary,
                        border: border,
                        surface2: surface2,
                      ),
                  ],
                ],
              ),
            ),
          ),

          Divider(color: border, height: 1, thickness: 1),
          const SizedBox(height: 12),

          // ── Nav items ──
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Column(
                children: AdminSection.values.map((section) {
                  final isSelected = selected == section;

                  // Scoring panel gets a special treatment
                  if (section == AdminSection.scoring) {
                    return Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Divider(color: border, height: 1),
                        ),
                        _NavItem(
                          section: section,
                          isSelected: isSelected,
                          collapsed: collapsed,
                          onTap: () => onSelect(section),
                          accent: accent,
                          textPrimary: textPrimary,
                          textSecondary: textSecondary,
                          surface2: surface2,
                          isHighlighted: true,
                        ),
                      ],
                    );
                  }

                  return _NavItem(
                    section: section,
                    isSelected: isSelected,
                    collapsed: collapsed,
                    onTap: () => onSelect(section),
                    accent: accent,
                    textPrimary: textPrimary,
                    textSecondary: textSecondary,
                    surface2: surface2,
                  );
                }).toList(),
              ),
            ),
          ),

          // ── Bottom: user + logout ──
          Divider(color: border, height: 1, thickness: 1),
          _SidebarFooter(
            collapsed: collapsed,
            accent: accent,
            textPrimary: textPrimary,
            textSecondary: textSecondary,
            surface2: surface2,
            border: border,
          ),
        ],
      ),
    );
  }
}

// ── Individual nav item ────────────────────────────────────
class _NavItem extends StatefulWidget {
  final AdminSection section;
  final bool isSelected;
  final bool collapsed;
  final bool isHighlighted;
  final VoidCallback onTap;
  final Color accent, textPrimary, textSecondary, surface2;

  const _NavItem({
    required this.section,
    required this.isSelected,
    required this.collapsed,
    required this.onTap,
    required this.accent,
    required this.textPrimary,
    required this.textSecondary,
    required this.surface2,
    this.isHighlighted = false,
  });

  @override
  State<_NavItem> createState() => _NavItemState();
}

class _NavItemState extends State<_NavItem> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final isActive = widget.isSelected;
    final bg = isActive
        ? widget.accent.withOpacity(0.12)
        : _hovered
            ? widget.surface2
            : Colors.transparent;

    return Padding(
      padding: const EdgeInsets.only(bottom: 3),
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            height: 42,
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(10),
              border: isActive
                  ? Border.all(color: widget.accent.withOpacity(0.2))
                  : Border.all(color: Colors.transparent),
            ),
            child: Row(
              children: [
                // Active indicator bar
                AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  width: 3,
                  height: isActive ? 20 : 0,
                  margin: const EdgeInsets.only(left: 4, right: 9),
                  decoration: BoxDecoration(
                    color: widget.accent,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                if (widget.collapsed) const SizedBox(width: 6),

                // Icon
                Icon(
                  widget.section.icon,
                  size: 18,
                  color: isActive
                      ? widget.accent
                      : _hovered
                          ? widget.textPrimary
                          : widget.textSecondary,
                ),

                // Label
                if (!widget.collapsed) ...[
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      widget.section.label,
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight:
                            isActive ? FontWeight.w600 : FontWeight.w400,
                        color: isActive
                            ? widget.textPrimary
                            : _hovered
                                ? widget.textPrimary
                                : widget.textSecondary,
                        letterSpacing: -0.1,
                      ),
                    ),
                  ),
                  if (widget.isHighlighted)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: widget.accent.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        'LIVE',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          color: widget.accent,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  const SizedBox(width: 10),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Collapse toggle button ─────────────────────────────────
class _CollapseButton extends StatefulWidget {
  final VoidCallback onTap;
  final Color textSecondary, border, surface2;

  const _CollapseButton({
    required this.onTap,
    required this.textSecondary,
    required this.border,
    required this.surface2,
  });

  @override
  State<_CollapseButton> createState() => _CollapseButtonState();
}

class _CollapseButtonState extends State<_CollapseButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: _hovered ? widget.surface2 : Colors.transparent,
            borderRadius: BorderRadius.circular(7),
            border: Border.all(
              color: _hovered ? widget.border : Colors.transparent,
            ),
          ),
          child: Icon(
            Icons.chevron_left_rounded,
            color: widget.textSecondary,
            size: 18,
          ),
        ),
      ),
    );
  }
}

// ── Sidebar footer ─────────────────────────────────────────
class _SidebarFooter extends StatelessWidget {
  final bool collapsed;
  final Color accent, textPrimary, textSecondary, surface2, border;

  const _SidebarFooter({
    required this.collapsed,
    required this.accent,
    required this.textPrimary,
    required this.textSecondary,
    required this.surface2,
    required this.border,
  });

  @override
  Widget build(BuildContext context) {
    final authProvider = context.read<AdminAuthProvider>();
    final email = authProvider.currentUser?.email ?? 'admin';
    final initials = email.isNotEmpty ? email[0].toUpperCase() : 'A';

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 12,
      ),
      child: collapsed
          ? Center(
              child: _LogoutIconButton(
                accent: accent,
                textSecondary: textSecondary,
                surface2: surface2,
                onLogout: () => _doLogout(context, authProvider),
              ),
            )
          : Row(
              children: [
                // Avatar
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: accent.withOpacity(0.15),
                    shape: BoxShape.circle,
                    border: Border.all(color: accent.withOpacity(0.3)),
                  ),
                  child: Center(
                    child: Text(
                      initials,
                      style: TextStyle(
                        color: accent,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    email,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ),
                _LogoutIconButton(
                  accent: accent,
                  textSecondary: textSecondary,
                  surface2: surface2,
                  onLogout: () => _doLogout(context, authProvider),
                ),
              ],
            ),
    );
  }

  void _doLogout(BuildContext context, AdminAuthProvider authProvider) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => _LogoutDialog(accent: accent),
    );
    if (confirm == true) {
      await authProvider.logout();
      if (context.mounted) {
        Navigator.of(context).pushNamedAndRemoveUntil('/', (_) => false);
      }
    }
  }
}

class _LogoutIconButton extends StatefulWidget {
  final Color accent, textSecondary, surface2;
  final VoidCallback onLogout;

  const _LogoutIconButton({
    required this.accent,
    required this.textSecondary,
    required this.surface2,
    required this.onLogout,
  });

  @override
  State<_LogoutIconButton> createState() => _LogoutIconButtonState();
}

class _LogoutIconButtonState extends State<_LogoutIconButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onLogout,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            color: _hovered
                ? Colors.redAccent.withOpacity(0.1)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            Icons.logout_rounded,
            size: 16,
            color: _hovered ? Colors.redAccent : widget.textSecondary,
          ),
        ),
      ),
    );
  }
}

// ── Logout confirmation dialog ─────────────────────────────
class _LogoutDialog extends StatelessWidget {
  final Color accent;
  const _LogoutDialog({required this.accent});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF141414),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: const Color(0xFF232323)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: accent.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.logout_rounded, color: accent, size: 20),
            ),
            const SizedBox(height: 16),
            const Text(
              'Sign out?',
              style: TextStyle(
                color: Colors.white,
                fontSize: 17,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'You will need to sign in again to access the admin panel.',
              style: TextStyle(
                  color: Color(0xFF666666), fontSize: 13, height: 1.5),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context, false),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF888888),
                      side: const BorderSide(color: Color(0xFF2A2A2A)),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(vertical: 13),
                    ),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context, true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: accent,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(vertical: 13),
                    ),
                    child: const Text(
                      'Sign out',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── Top bar ────────────────────────────────────────────────
class _TopBar extends StatelessWidget {
  final AdminSection section;
  final bool isNarrow;
  final VoidCallback? onMenuTap;
  final Color surface, border, accent, textPrimary, textSecondary;

  const _TopBar({
    required this.section,
    required this.isNarrow,
    required this.onMenuTap,
    required this.surface,
    required this.border,
    required this.accent,
    required this.textPrimary,
    required this.textSecondary,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: BoxDecoration(
        color: surface,
        border: Border(bottom: BorderSide(color: border, width: 1)),
      ),
      child: Row(
        children: [
          if (isNarrow && onMenuTap != null) ...[
            IconButton(
              onPressed: onMenuTap,
              icon: Icon(Icons.menu_rounded, color: textSecondary),
            ),
            const SizedBox(width: 8),
          ],
          // Page title
          Text(
            section.label,
            style: TextStyle(
              color: textPrimary,
              fontSize: 17,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.3,
            ),
          ),
          if (section == AdminSection.scoring) ...[
            const SizedBox(width: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: accent.withOpacity(0.12),
                borderRadius: BorderRadius.circular(5),
                border: Border.all(color: accent.withOpacity(0.25)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: accent,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(color: accent.withOpacity(0.6), blurRadius: 4)
                      ],
                    ),
                  ),
                  const SizedBox(width: 5),
                  Text(
                    'LIVE',
                    style: TextStyle(
                      color: accent,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),
          ],
          const Spacer(),
          // Right side — admin badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFF1A1A1A),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: border),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 7,
                  height: 7,
                  decoration: const BoxDecoration(
                    color: Color(0xFF4CAF50),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 7),
                Text(
                  'Admin',
                  style: TextStyle(
                    color: textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ContentArea extends StatelessWidget {
  final AdminSection section;
  const _ContentArea({required this.section});

  @override
  Widget build(BuildContext context) {
    switch (section) {
      case AdminSection.matches:
        return const MatchScreen();
      case AdminSection.teams:
        return const TeamsScreen();
      case AdminSection.players:
        return const PlayerScreen();
      case AdminSection.toss:
        return const TossScreen();
      case AdminSection.scoring:
        return const ScoringPanel();
      case AdminSection.upcomingFixtures:
        return const UpcomingFixturesScreen();
      case AdminSection.shopScreen:
        return const ShopScreen();
      case AdminSection.shopbannerscreen:
        return const ShopBannerScreen();
      case AdminSection.winpredictor:
        return const WinPredictorScreen();
      case AdminSection.pointsTable:
        return const PointsTableScreen();
      case AdminSection.notifications:
        return const NotificationScreen();
    }
  }
}
