import 'dart:async';
import 'package:cricket_admin/services/dugout_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';

// ─────────────────────────────────────────────────────────────
//  DUGOUT MODERATION GUARD
//
//  Wrap this around DugoutScreen content.
//  Listens to RTDB moderation node and shows appropriate popup:
//    - Warning  → dismissible toast overlay
//    - Timeout  → blocks input with countdown
//    - Ban      → full screen block
//
//  Usage:
//    DugoutModerationGuard(
//      child: YourChatWidget(),
//    )
// ─────────────────────────────────────────────────────────────

class DugoutModerationGuard extends StatefulWidget {
  final Widget child;
  const DugoutModerationGuard({super.key, required this.child});

  @override
  State<DugoutModerationGuard> createState() => _DugoutModerationGuardState();
}

class _DugoutModerationGuardState extends State<DugoutModerationGuard> {
  StreamSubscription? _sub;
  String? _uid;

  // Current moderation state
  bool _isBanned = false;
  String _banReason = '';
  bool _isTimedOut = false;
  int? _timeoutUntil;
  String _timeoutReason = '';
  bool _showWarning = false;
  String _warningText = '';

  // Countdown timer for timeout
  Timer? _countdownTimer;
  int _secondsLeft = 0;

  @override
  void initState() {
    super.initState();
    _uid = FirebaseAuth.instance.currentUser?.uid;
    if (_uid != null) _startListening();
  }

  void _startListening() {
    _sub = DugoutAdminService.moderationStream(_uid!).listen((event) {
      if (event == null || !mounted) return;

      setState(() {
        _isBanned = event.isBanned;
        _banReason = event.banReason;

        // Timeout
        _isTimedOut = event.isTimedOut;
        _timeoutUntil = event.timeoutUntil;
        _timeoutReason = event.timeoutReason;

        // Warning — only show if not shown yet
        if (event.lastWarning != null &&
            event.lastWarning!.isNotEmpty &&
            !event.warningShown) {
          _warningText = event.lastWarning!;
          _showWarning = true;
          // Auto-dismiss after 6s
          Future.delayed(const Duration(seconds: 6), () {
            if (mounted) setState(() => _showWarning = false);
          });
          // Mark as shown on backend
          DugoutAdminService.markWarningShown(_uid!);
        }
      });

      // Start countdown if timed out
      if (event.isTimedOut) _startCountdown();

      // Mark ban/timeout popup shown
      if (event.isBanned && !event.banShown) {
        DugoutAdminService.markBanShown(_uid!);
      }
      if (event.isTimedOut && !event.timeoutShown) {
        DugoutAdminService.markTimeoutShown(_uid!);
      }
    });
  }

  void _startCountdown() {
    _countdownTimer?.cancel();
    _updateCountdown();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      _updateCountdown();
    });
  }

  void _updateCountdown() {
    if (_timeoutUntil == null) return;
    final remaining = _timeoutUntil! - DateTime.now().millisecondsSinceEpoch;
    if (remaining <= 0) {
      _countdownTimer?.cancel();
      if (mounted)
        setState(() {
          _isTimedOut = false;
          _secondsLeft = 0;
        });
    } else {
      if (mounted) setState(() => _secondsLeft = (remaining / 1000).ceil());
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    _countdownTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Main content
        widget.child,

        // Warning toast — slides in from top
        if (_showWarning)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: _WarningToast(
              message: _warningText,
              onDismiss: () => setState(() => _showWarning = false),
            ),
          ),

        // Timeout overlay — blocks interaction, shows countdown
        if (_isTimedOut && !_isBanned)
          _TimeoutOverlay(
            secondsLeft: _secondsLeft,
            reason: _timeoutReason,
          ),

        // Ban overlay — full block, no dismiss
        if (_isBanned) _BanOverlay(reason: _banReason),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  EXPOSE: check if user can send message
//  Use this before sendMessage() in dugout_screen.dart
// ─────────────────────────────────────────────────────────────

/// Returns true if user is currently allowed to send messages
Future<bool> canUserChat(String uid) async {
  try {
    final snap =
        await FirebaseDatabase.instance.ref('dugout_moderation/$uid').get();
    if (!snap.exists || snap.value == null) return true;
    final m = Map<String, dynamic>.from(
        (snap.value as Map).map((k, v) => MapEntry(k.toString(), v)));

    if (m['isBanned'] == true) return false;
    final timeoutUntil = (m['timeoutUntil'] as num?)?.toInt();
    if (timeoutUntil != null &&
        timeoutUntil > DateTime.now().millisecondsSinceEpoch) return false;

    return true;
  } catch (_) {
    return true; // fail open
  }
}

// ─────────────────────────────────────────────────────────────
//  WARNING TOAST
// ─────────────────────────────────────────────────────────────

class _WarningToast extends StatefulWidget {
  final String message;
  final VoidCallback onDismiss;
  const _WarningToast({required this.message, required this.onDismiss});

  @override
  State<_WarningToast> createState() => _WarningToastState();
}

class _WarningToastState extends State<_WarningToast>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<Offset> _slide;
  late Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 350));
    _slide = Tween<Offset>(begin: const Offset(0, -1), end: Offset.zero)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
    _fade = Tween<double>(begin: 0, end: 1)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SlideTransition(
      position: _slide,
      child: FadeTransition(
        opacity: _fade,
        child: Container(
          margin: const EdgeInsets.all(12),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0xFF1A1200),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
                color: const Color(0xFFFFB300).withAlpha(120), width: 1.5),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withAlpha(100),
                  blurRadius: 20,
                  offset: const Offset(0, 4)),
            ],
          ),
          child: Row(children: [
            const Icon(Icons.warning_amber_rounded,
                color: Color(0xFFFFB300), size: 20),
            const SizedBox(width: 10),
            Expanded(
                child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Warning from Admin',
                    style: TextStyle(
                        color: Color(0xFFFFB300),
                        fontSize: 12,
                        fontWeight: FontWeight.w700)),
                const SizedBox(height: 3),
                Text(widget.message,
                    style: TextStyle(
                        color: Colors.white.withAlpha(200), fontSize: 12)),
              ],
            )),
            GestureDetector(
                onTap: widget.onDismiss,
                child:
                    Icon(Icons.close_rounded, color: Colors.white38, size: 16)),
          ]),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  TIMEOUT OVERLAY
// ─────────────────────────────────────────────────────────────

class _TimeoutOverlay extends StatelessWidget {
  final int secondsLeft;
  final String reason;
  const _TimeoutOverlay({required this.secondsLeft, required this.reason});

  String get _formattedTime {
    final m = secondsLeft ~/ 60;
    final s = secondsLeft % 60;
    return m > 0 ? '${m}m ${s}s' : '${s}s';
  }

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: Container(
        color: Colors.black.withAlpha(180),
        child: Center(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 32),
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xFF1A0800),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                  color: const Color(0xFFFF7043).withAlpha(120), width: 1.5),
            ),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.timer_outlined,
                  color: Color(0xFFFF7043), size: 40),
              const SizedBox(height: 12),
              const Text('You\'ve been timed out',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              if (reason.isNotEmpty)
                Text(reason,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white60, fontSize: 12)),
              const SizedBox(height: 16),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                decoration: BoxDecoration(
                    color: const Color(0xFFFF7043).withAlpha(25),
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(
                        color: const Color(0xFFFF7043).withAlpha(80))),
                child: Text(_formattedTime,
                    style: const TextStyle(
                        color: Color(0xFFFF7043),
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1)),
              ),
              const SizedBox(height: 10),
              Text('Chat will resume automatically',
                  style: TextStyle(color: Colors.white38, fontSize: 11)),
            ]),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  BAN OVERLAY
// ─────────────────────────────────────────────────────────────

class _BanOverlay extends StatelessWidget {
  final String reason;
  const _BanOverlay({required this.reason});

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: Container(
        color: const Color(0xFF0A0000),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                    color: const Color(0xFFCC0000).withAlpha(20),
                    shape: BoxShape.circle,
                    border: Border.all(
                        color: const Color(0xFFCC0000).withAlpha(80),
                        width: 2)),
                child: const Icon(Icons.block_rounded,
                    color: Color(0xFFCC0000), size: 32),
              ),
              const SizedBox(height: 20),
              const Text('You\'ve been banned',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              const Text('You can no longer participate in Dugout.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white54, fontSize: 13)),
              if (reason.isNotEmpty) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                      color: Colors.white.withAlpha(8),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.white.withAlpha(15))),
                  child: Row(children: [
                    Icon(Icons.info_outline, color: Colors.white38, size: 14),
                    const SizedBox(width: 8),
                    Expanded(
                        child: Text('Reason: $reason',
                            style: TextStyle(
                                color: Colors.white54, fontSize: 12))),
                  ]),
                ),
              ],
              const SizedBox(height: 24),
              Text('If you think this is a mistake,\ncontact support.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white24, fontSize: 11)),
            ]),
          ),
        ),
      ),
    );
  }
}
