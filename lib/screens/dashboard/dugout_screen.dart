import 'dart:async';
import 'package:cricket_admin/services/dugout_message.dart';
import 'package:cricket_admin/services/dugout_service.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

// ─────────────────────────────────────────────────────────────
//  DUGOUT ADMIN SCREEN
//  Flutter Web admin panel — messages, users, moderation
// ─────────────────────────────────────────────────────────────

class DugoutAdminScreen extends StatefulWidget {
  const DugoutAdminScreen({super.key});

  @override
  State<DugoutAdminScreen> createState() => _DugoutAdminScreenState();
}

class _DugoutAdminScreenState extends State<DugoutAdminScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tab;

  // ── Streams owned at the top level ──
  late final Stream<List<DugoutMessage>> _messagesStream;
  late final Stream<List<DugoutUser>> _usersStream;

  List<DugoutMessage> _messages = [];
  List<DugoutUser> _users = [];
  bool _messagesReady = false;
  bool _usersReady = false;

  StreamSubscription<List<DugoutMessage>>? _msgSub;
  StreamSubscription<List<DugoutUser>>? _userSub;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);

    // Create broadcast streams so both the stats AND the tab children
    // can listen without duplicating Firestore reads.
    _messagesStream =
        DugoutAdminService.allMessagesStream().asBroadcastStream();
    _usersStream = DugoutAdminService.allUsersStream().asBroadcastStream();

    // Update stats in one place — the parent — so children never call
    // setState upward, which was the root cause of flickering.
    _msgSub = _messagesStream.listen((msgs) {
      if (!mounted) return;
      setState(() {
        _messages = msgs;
        _messagesReady = true;
      });
    });
    _userSub = _usersStream.listen((users) {
      if (!mounted) return;
      setState(() {
        _users = users;
        _usersReady = true;
      });
    });
  }

  @override
  void dispose() {
    _tab.dispose();
    _msgSub?.cancel();
    _userSub?.cancel();
    super.dispose();
  }

  int get _onlineCount => _users.where((u) => u.isOnline).length;
  int get _totalUsers => _users.length;
  int get _totalMsgs => _messages.length;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF111111),
        elevation: 0,
        title: Row(children: [
          const Icon(Icons.chat_bubble_rounded,
              color: Color(0xFFCC0000), size: 18),
          const SizedBox(width: 10),
          const Text('Dugout Admin',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w700)),
          const SizedBox(width: 16),
          _StatPill(
              label: 'Online',
              value: _onlineCount,
              color: const Color(0xFF4CAF50)),
          const SizedBox(width: 8),
          _StatPill(
              label: 'Users',
              value: _totalUsers,
              color: const Color(0xFF2196F3)),
          const SizedBox(width: 8),
          _StatPill(
              label: 'Msgs', value: _totalMsgs, color: const Color(0xFFFF9800)),
        ]),
        bottom: TabBar(
          controller: _tab,
          indicatorColor: const Color(0xFFCC0000),
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white38,
          tabs: const [
            Tab(text: 'Messages'),
            Tab(text: 'Users'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tab,
        children: [
          _MessagesTab(messages: _messages, ready: _messagesReady),
          _UsersTab(users: _users, ready: _usersReady),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  MESSAGES TAB
// ─────────────────────────────────────────────────────────────

class _MessagesTab extends StatefulWidget {
  final List<DugoutMessage> messages;
  final bool ready;
  const _MessagesTab({required this.messages, required this.ready});

  @override
  State<_MessagesTab> createState() => _MessagesTabState();
}

class _MessagesTabState extends State<_MessagesTab> {
  final _search = TextEditingController();
  String _filter = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      // Search bar
      Padding(
        padding: const EdgeInsets.all(12),
        child: TextField(
          controller: _search,
          style: const TextStyle(color: Colors.white, fontSize: 13),
          decoration: InputDecoration(
            hintText: 'Search messages or users...',
            hintStyle: const TextStyle(color: Colors.white38, fontSize: 13),
            prefixIcon:
                const Icon(Icons.search, color: Colors.white38, size: 18),
            filled: true,
            fillColor: Colors.white.withAlpha(10),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide.none),
            contentPadding: const EdgeInsets.symmetric(vertical: 10),
          ),
          onChanged: (v) => setState(() => _filter = v.toLowerCase()),
        ),
      ),

      // Messages list — parent owns the stream subscription and passes current data.
      Expanded(
        child: !widget.ready
            ? const Center(
                child: CircularProgressIndicator(
                    color: Color(0xFFCC0000), strokeWidth: 1.5))
            : Builder(builder: (_) {
                final all = widget.messages;
                final msgs = _filter.isEmpty
                    ? all
                    : all
                        .where((m) =>
                            m.text.toLowerCase().contains(_filter) ||
                            m.displayName.toLowerCase().contains(_filter))
                        .toList();

                if (msgs.isEmpty) {
                  return const Center(
                      child: Text('No messages',
                          style: TextStyle(color: Colors.white38)));
                }

                return ListView.builder(
                  key: const PageStorageKey('dugoutMessagesList'),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  itemCount: msgs.length,
                  itemBuilder: (_, i) => _MessageRow(
                    key: ValueKey(msgs[i].id),
                    msg: msgs[i],
                  ),
                );
              }),
      ),
    ]);
  }
}

class _MessageRow extends StatelessWidget {
  final DugoutMessage msg;
  const _MessageRow({Key? key, required this.msg}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final time = msg.timestamp > 0
        ? DateFormat('HH:mm')
            .format(DateTime.fromMillisecondsSinceEpoch(msg.timestamp))
        : '--';

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(7),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withAlpha(10)),
      ),
      child: Row(children: [
        // Avatar initial
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: const Color(0xFFCC0000).withAlpha(30),
            shape: BoxShape.circle,
          ),
          child: Center(
              child: Text(
            msg.displayName.isNotEmpty ? msg.displayName[0].toUpperCase() : '?',
            style: const TextStyle(
                color: Color(0xFFCC0000),
                fontSize: 13,
                fontWeight: FontWeight.w700),
          )),
        ),
        const SizedBox(width: 10),

        // Name + message
        Expanded(
            child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Text(msg.displayName,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600)),
              const SizedBox(width: 6),
              Text(time,
                  style: const TextStyle(color: Colors.white38, fontSize: 10)),
            ]),
            const SizedBox(height: 2),
            Text(msg.text,
                style:
                    TextStyle(color: Colors.white.withAlpha(180), fontSize: 12),
                maxLines: 2,
                overflow: TextOverflow.ellipsis),
          ],
        )),

        // Actions
        Row(mainAxisSize: MainAxisSize.min, children: [
          _ActionBtn(
            icon: Icons.warning_amber_rounded,
            color: const Color(0xFFFFB300),
            tooltip: 'Warn user',
            onTap: () =>
                _showActionDialog(context, msg, ModerationAction.warning),
          ),
          _ActionBtn(
            icon: Icons.timer_outlined,
            color: const Color(0xFFFF7043),
            tooltip: 'Timeout',
            onTap: () =>
                _showActionDialog(context, msg, ModerationAction.timeout),
          ),
          _ActionBtn(
            icon: Icons.block_rounded,
            color: const Color(0xFFCC0000),
            tooltip: 'Ban user',
            onTap: () => _showActionDialog(context, msg, ModerationAction.ban),
          ),
          _ActionBtn(
            icon: Icons.delete_outline_rounded,
            color: Colors.white38,
            tooltip: 'Delete message',
            onTap: () async {
              await DugoutAdminService.deleteMessage(msg.id);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                  content: Text('Message deleted'),
                  backgroundColor: Color(0xFF333333),
                  behavior: SnackBarBehavior.floating,
                ));
              }
            },
          ),
        ]),
      ]),
    );
  }

  void _showActionDialog(
      BuildContext context, DugoutMessage msg, ModerationAction action) {
    showDialog(
      context: context,
      builder: (_) => _ModerationDialog(
        uid: msg.userId,
        displayName: msg.displayName,
        action: action,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  USERS TAB
// ─────────────────────────────────────────────────────────────

class _UsersTab extends StatelessWidget {
  final List<DugoutUser> users;
  final bool ready;
  const _UsersTab({required this.users, required this.ready});

  @override
  Widget build(BuildContext context) {
    if (!ready) {
      return const Center(
          child: CircularProgressIndicator(
              color: Color(0xFFCC0000), strokeWidth: 1.5));
    }

    if (users.isEmpty) {
      return const Center(
          child: Text('No users yet', style: TextStyle(color: Colors.white38)));
    }

    return ListView.builder(
      key: const PageStorageKey('dugoutUsersList'),
      padding: const EdgeInsets.all(12),
      itemCount: users.length,
      itemBuilder: (_, i) => _UserRow(
        key: ValueKey(users[i].uid),
        user: users[i],
      ),
    );
  }
}

class _UserRow extends StatelessWidget {
  final DugoutUser user;
  const _UserRow({Key? key, required this.user}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final mod = user.moderation;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: mod.isBanned
            ? const Color(0xFFCC0000).withAlpha(15)
            : Colors.white.withAlpha(7),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
            color: mod.isBanned
                ? const Color(0xFFCC0000).withAlpha(40)
                : Colors.white.withAlpha(10)),
      ),
      child: Row(children: [
        // Online indicator
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
              color: user.isOnline ? const Color(0xFF4CAF50) : Colors.white24,
              shape: BoxShape.circle),
        ),
        const SizedBox(width: 10),

        // Avatar
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
              color: Colors.white.withAlpha(12), shape: BoxShape.circle),
          child: Center(
              child: Text(
            user.displayName.isNotEmpty
                ? user.displayName[0].toUpperCase()
                : '?',
            style: const TextStyle(
                color: Colors.white70,
                fontSize: 13,
                fontWeight: FontWeight.w600),
          )),
        ),
        const SizedBox(width: 10),

        // Name + status chips
        Expanded(
            child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(user.displayName,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w600)),
            Row(children: [
              if (mod.isBanned)
                _StatusChip(label: 'BANNED', color: const Color(0xFFCC0000)),
              if (mod.isTimedOut && !mod.isBanned)
                _StatusChip(
                    label: 'TIMEOUT ${mod.timeoutRemainingSeconds ~/ 60}m',
                    color: const Color(0xFFFF7043)),
              if (mod.lastWarning != null && !mod.isBanned)
                _StatusChip(label: 'WARNED', color: const Color(0xFFFFB300)),
            ]),
          ],
        )),

        // Actions
        Row(mainAxisSize: MainAxisSize.min, children: [
          _ActionBtn(
            icon: Icons.warning_amber_rounded,
            color: const Color(0xFFFFB300),
            tooltip: 'Warn',
            onTap: () => showDialog(
                context: context,
                builder: (_) => _ModerationDialog(
                    uid: user.uid,
                    displayName: user.displayName,
                    action: ModerationAction.warning)),
          ),
          _ActionBtn(
            icon: Icons.timer_outlined,
            color: const Color(0xFFFF7043),
            tooltip: 'Timeout',
            onTap: () => showDialog(
                context: context,
                builder: (_) => _ModerationDialog(
                    uid: user.uid,
                    displayName: user.displayName,
                    action: ModerationAction.timeout)),
          ),
          if (mod.isBanned)
            _ActionBtn(
              icon: Icons.lock_open_rounded,
              color: const Color(0xFF4CAF50),
              tooltip: 'Unban',
              onTap: () async {
                await DugoutAdminService.unbanUser(user.uid);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text('${user.displayName} unbanned'),
                    backgroundColor: const Color(0xFF4CAF50),
                    behavior: SnackBarBehavior.floating,
                  ));
                }
              },
            )
          else
            _ActionBtn(
              icon: Icons.block_rounded,
              color: const Color(0xFFCC0000),
              tooltip: 'Ban',
              onTap: () => showDialog(
                  context: context,
                  builder: (_) => _ModerationDialog(
                      uid: user.uid,
                      displayName: user.displayName,
                      action: ModerationAction.ban)),
            ),
          _ActionBtn(
            icon: Icons.delete_sweep_outlined,
            color: Colors.white38,
            tooltip: 'Delete all messages',
            onTap: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (_) => _ConfirmDialog(
                  title: 'Delete all messages?',
                  message: 'Delete all messages from ${user.displayName}?',
                  confirmLabel: 'Delete',
                  confirmColor: const Color(0xFFCC0000),
                ),
              );
              if (confirm == true) {
                await DugoutAdminService.deleteAllMessagesFromUser(user.uid);
              }
            },
          ),
        ]),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  MODERATION ACTION DIALOG
// ─────────────────────────────────────────────────────────────

class _ModerationDialog extends StatefulWidget {
  final String uid;
  final String displayName;
  final ModerationAction action;
  const _ModerationDialog({
    required this.uid,
    required this.displayName,
    required this.action,
  });

  @override
  State<_ModerationDialog> createState() => _ModerationDialogState();
}

class _ModerationDialogState extends State<_ModerationDialog> {
  final _textCtrl = TextEditingController();
  int _timeoutMins = 10;
  bool _loading = false;

  @override
  void dispose() {
    _textCtrl.dispose();
    super.dispose();
  }

  String get _title => switch (widget.action) {
        ModerationAction.warning => '⚠️ Warn User',
        ModerationAction.timeout => '⏱ Timeout User',
        ModerationAction.ban => '🚫 Ban User',
        ModerationAction.unban => 'Unban',
      };

  String get _hint => switch (widget.action) {
        ModerationAction.warning => 'Warning message to show user...',
        ModerationAction.timeout => 'Reason for timeout...',
        ModerationAction.ban => 'Reason for ban...',
        ModerationAction.unban => '',
      };

  Future<void> _submit() async {
    final reason = _textCtrl.text.trim();
    if (reason.isEmpty) return;

    setState(() => _loading = true);
    try {
      switch (widget.action) {
        case ModerationAction.warning:
          await DugoutAdminService.warnUser(uid: widget.uid, message: reason);
        case ModerationAction.timeout:
          await DugoutAdminService.timeoutUser(
              uid: widget.uid, minutes: _timeoutMins, reason: reason);
        case ModerationAction.ban:
          await DugoutAdminService.banUser(uid: widget.uid, reason: reason);
        case ModerationAction.unban:
          await DugoutAdminService.unbanUser(widget.uid);
      }
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF161616),
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: Colors.white.withAlpha(15))),
      title: Text(_title,
          style: const TextStyle(
              color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
      content: SizedBox(
        width: 400,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('User: ${widget.displayName}',
              style: const TextStyle(color: Colors.white54, fontSize: 13)),
          const SizedBox(height: 16),

          // Reason / message input
          TextField(
            controller: _textCtrl,
            style: const TextStyle(color: Colors.white, fontSize: 13),
            maxLines: 3,
            decoration: InputDecoration(
              hintText: _hint,
              hintStyle: const TextStyle(color: Colors.white38, fontSize: 12),
              filled: true,
              fillColor: Colors.white.withAlpha(8),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Colors.white.withAlpha(20))),
              enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Colors.white.withAlpha(20))),
              focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Color(0xFFCC0000))),
            ),
          ),

          // Timeout duration picker
          if (widget.action == ModerationAction.timeout) ...[
            const SizedBox(height: 14),
            const Text('Duration',
                style: TextStyle(color: Colors.white54, fontSize: 12)),
            const SizedBox(height: 8),
            Row(
                children: [5, 10, 30, 60]
                    .map((m) => Expanded(
                            child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 3),
                          child: GestureDetector(
                            onTap: () => setState(() => _timeoutMins = m),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 150),
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              decoration: BoxDecoration(
                                color: _timeoutMins == m
                                    ? const Color(0xFFFF7043).withAlpha(30)
                                    : Colors.white.withAlpha(8),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                    color: _timeoutMins == m
                                        ? const Color(0xFFFF7043)
                                        : Colors.white.withAlpha(15)),
                              ),
                              child: Text('${m}m',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                      color: _timeoutMins == m
                                          ? const Color(0xFFFF7043)
                                          : Colors.white54,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600)),
                            ),
                          ),
                        )))
                    .toList()),
          ],
        ]),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child:
                const Text('Cancel', style: TextStyle(color: Colors.white38))),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: switch (widget.action) {
              ModerationAction.warning => const Color(0xFFFFB300),
              ModerationAction.timeout => const Color(0xFFFF7043),
              ModerationAction.ban => const Color(0xFFCC0000),
              ModerationAction.unban => const Color(0xFF4CAF50),
            },
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          onPressed: _loading ? null : _submit,
          child: _loading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white))
              : Text(switch (widget.action) {
                  ModerationAction.warning => 'Send Warning',
                  ModerationAction.timeout => 'Apply Timeout',
                  ModerationAction.ban => 'Ban User',
                  ModerationAction.unban => 'Unban',
                }),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  SHARED SMALL WIDGETS
// ─────────────────────────────────────────────────────────────

class _StatPill extends StatelessWidget {
  final String label;
  final int value;
  final Color color;
  const _StatPill(
      {required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withAlpha(25),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withAlpha(60)),
      ),
      child: Text('$label: $value',
          style: TextStyle(
              color: color, fontSize: 11, fontWeight: FontWeight.w600)),
    );
  }
}

class _ActionBtn extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String tooltip;
  final VoidCallback onTap;
  const _ActionBtn(
      {required this.icon,
      required this.color,
      required this.tooltip,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        borderRadius: BorderRadius.circular(6),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Icon(icon, size: 16, color: color),
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String label;
  final Color color;
  const _StatusChip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(right: 4, top: 3),
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      decoration: BoxDecoration(
        color: color.withAlpha(25),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withAlpha(60)),
      ),
      child: Text(label,
          style: TextStyle(
              color: color, fontSize: 9, fontWeight: FontWeight.w700)),
    );
  }
}

class _ConfirmDialog extends StatelessWidget {
  final String title, message, confirmLabel;
  final Color confirmColor;
  const _ConfirmDialog(
      {required this.title,
      required this.message,
      required this.confirmLabel,
      required this.confirmColor});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF161616),
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: Colors.white.withAlpha(15))),
      title: Text(title,
          style: const TextStyle(
              color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700)),
      content: Text(message,
          style: const TextStyle(color: Colors.white60, fontSize: 13)),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context, false),
            child:
                const Text('Cancel', style: TextStyle(color: Colors.white38))),
        FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: confirmColor,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8))),
            onPressed: () => Navigator.pop(context, true),
            child: Text(confirmLabel)),
      ],
    );
  }
}
