import 'package:cricket_admin/services/aipredictionservice.dart';
import 'package:cricket_admin/services/featured_match_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

// ── Theme ──────────────────────────────────────────────────
const _bg = Color(0xFF0D0D0D);
const _surface = Color(0xFF141414);
const _surface2 = Color(0xFF1A1A1A);
const _border = Color(0xFF232323);
const _t1 = Color(0xFFE8E8E8);
const _t2 = Color(0xFF666666);
const _t3 = Color(0xFF444444);
const _red = Colors.redAccent;

// ─────────────────────────────────────────────────────────────
//  AiPredictionScreen — Admin
// ─────────────────────────────────────────────────────────────
class AiPredictionScreen extends StatefulWidget {
  const AiPredictionScreen({super.key});

  @override
  State<AiPredictionScreen> createState() => _AiPredictionScreenState();
}

class _AiPredictionScreenState extends State<AiPredictionScreen> {
  bool _generating = false;
  String? _error;

  Future<void> _generate() async {
    setState(() {
      _generating = true;
      _error = null;
    });

    final err = await AiPredictionService.generateAndSave();

    if (mounted) {
      setState(() {
        _generating = false;
        _error = err;
      });
      if (err == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              'Prediction generated!',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            backgroundColor: const Color(0xFF1A1A1A),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
              side: BorderSide(
                  color: Colors.redAccent.withOpacity(0.4), width: 0.5),
            ),
          ),
        );
      }
    }
  }

  Future<void> _clear() async {
    await FeaturedMatchService.clearAiPrediction();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Prediction cleared.'),
          backgroundColor: _surface2,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: const BorderSide(color: _border, width: 0.5),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ──────────────────────────────────
            Row(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'AI Prediction',
                      style: TextStyle(
                        color: _t1,
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.4,
                      ),
                    ),
                    const SizedBox(height: 3),
                    const Text(
                      'Generate match day predictions using AI',
                      style: TextStyle(color: _t2, fontSize: 13),
                    ),
                  ],
                ),
                const Spacer(),
                // Clear button
                _GhostBtn(
                  label: 'Clear',
                  icon: Icons.delete_outline_rounded,
                  onTap: _clear,
                ),
                const SizedBox(width: 12),
                // Generate button
                _GenerateBtn(
                  loading: _generating,
                  onTap: _generate,
                ),
              ],
            ),

            const SizedBox(height: 24),

            // ── Error banner ─────────────────────────────
            if (_error != null) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.redAccent.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.redAccent.withOpacity(0.25)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.error_outline_rounded,
                        color: Colors.redAccent, size: 15),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _error!,
                        style: const TextStyle(
                          color: Color(0xFFFF8A80),
                          fontSize: 12,
                          height: 1.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // ── Live prediction preview ──────────────────
            Expanded(
              child: StreamBuilder<DocumentSnapshot>(
                stream: FeaturedMatchService.stream(),
                builder: (context, snap) {
                  if (!snap.hasData) {
                    return const Center(
                      child: CircularProgressIndicator(
                          color: Colors.redAccent, strokeWidth: 1.5),
                    );
                  }

                  final data = snap.data!.data() as Map<String, dynamic>? ?? {};
                  final pred = data['ai_prediction'] as Map<String, dynamic>?;
                  final meta = data['meta'] as Map<String, dynamic>? ?? {};

                  // No prediction yet
                  if (pred == null ||
                      pred.isEmpty ||
                      pred['generated'] != true) {
                    return _NoPrediction(
                      matchTitle: meta['title'] as String? ?? '',
                      onGenerate: _generate,
                      generating: _generating,
                    );
                  }

                  return _PredictionPreview(
                    prediction: pred,
                    meta: meta,
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  No Prediction State
// ─────────────────────────────────────────────────────────────
class _NoPrediction extends StatelessWidget {
  final String matchTitle;
  final VoidCallback onGenerate;
  final bool generating;

  const _NoPrediction({
    required this.matchTitle,
    required this.onGenerate,
    required this.generating,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: _surface,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: _border),
            ),
            child: const Center(
              child: Text('🤖', style: TextStyle(fontSize: 28)),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            matchTitle.isNotEmpty
                ? 'No prediction for "$matchTitle"'
                : 'No prediction yet',
            style: const TextStyle(
                color: _t1, fontSize: 16, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 6),
          const Text(
            'Make sure teams and player stats are added,\nthen click Generate.',
            style: TextStyle(color: _t2, fontSize: 13, height: 1.5),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          _GenerateBtn(loading: generating, onTap: onGenerate),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  Prediction Preview
// ─────────────────────────────────────────────────────────────
class _PredictionPreview extends StatelessWidget {
  final Map<String, dynamic> prediction;
  final Map<String, dynamic> meta;

  const _PredictionPreview({
    required this.prediction,
    required this.meta,
  });

  @override
  Widget build(BuildContext context) {
    final teamA = prediction['team_a'] as Map<String, dynamic>? ?? {};
    final teamB = prediction['team_b'] as Map<String, dynamic>? ?? {};
    final winner = prediction['predicted_winner'] as String? ?? '';
    final conf = prediction['confidence'] as String? ?? 'moderate';
    final note = prediction['match_note'] as String? ?? '';
    final genAt = prediction['generatedAt'] as dynamic;

    String genLabel = '';
    if (genAt is Timestamp) {
      final dt = genAt.toDate();
      genLabel =
          'Generated ${dt.day}/${dt.month}/${dt.year} at ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    }

    return ListView(
      children: [
        // ── Generated at + confidence ──────────────────
        Row(
          children: [
            if (genLabel.isNotEmpty)
              Text(genLabel, style: const TextStyle(color: _t3, fontSize: 11)),
            const Spacer(),
            _ConfidenceBadge(confidence: conf),
          ],
        ),
        const SizedBox(height: 16),

        // ── Match note ─────────────────────────────────
        if (note.isNotEmpty)
          Container(
            padding: const EdgeInsets.all(14),
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: _surface,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: _border),
            ),
            child: Row(
              children: [
                const Icon(Icons.lightbulb_outline_rounded,
                    color: Colors.amber, size: 14),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    note,
                    style:
                        const TextStyle(color: _t2, fontSize: 13, height: 1.4),
                  ),
                ),
              ],
            ),
          ),

        // ── Two team cards ─────────────────────────────
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _TeamPredCard(
                teamData: teamA,
                winner: winner,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _TeamPredCard(
                teamData: teamB,
                winner: winner,
              ),
            ),
          ],
        ),

        const SizedBox(height: 16),

        // ── Predicted winner banner ────────────────────
        if (winner.isNotEmpty)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            decoration: BoxDecoration(
              color: Colors.redAccent.withOpacity(0.07),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.redAccent.withOpacity(0.2)),
            ),
            child: Row(
              children: [
                const Text('🏆', style: TextStyle(fontSize: 18)),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'PREDICTED WINNER',
                      style: TextStyle(
                        color: _t3,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      winner,
                      style: const TextStyle(
                        color: _t1,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.3,
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                _ConfidenceBadge(confidence: conf),
              ],
            ),
          ),
      ],
    );
  }
}

// ── Team prediction card ───────────────────────────────────
class _TeamPredCard extends StatelessWidget {
  final Map<String, dynamic> teamData;
  final String winner;

  const _TeamPredCard({
    required this.teamData,
    required this.winner,
  });

  @override
  Widget build(BuildContext context) {
    final name = teamData['name'] as String? ?? '—';
    final picks = teamData['top_picks'] as List<dynamic>? ?? [];
    final outlook = teamData['team_outlook'] as String? ?? '';
    final isWinner = winner == name;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isWinner ? Colors.redAccent.withOpacity(0.35) : _border,
          width: isWinner ? 1.0 : 0.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Team name + winner badge
          Row(
            children: [
              Text(
                name,
                style: const TextStyle(
                  color: _t1,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.2,
                ),
              ),
              if (isWinner) ...[
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.redAccent.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(4),
                    border:
                        Border.all(color: Colors.redAccent.withOpacity(0.3)),
                  ),
                  child: const Text(
                    'FAVOURED',
                    style: TextStyle(
                      color: Colors.redAccent,
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.8,
                    ),
                  ),
                ),
              ],
            ],
          ),

          const SizedBox(height: 14),

          // Top picks
          const Text(
            'TOP PICKS',
            style: TextStyle(
              color: _t3,
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 8),

          ...picks.asMap().entries.map((e) {
            final i = e.key;
            final pick = e.value as Map<String, dynamic>;
            final pName = pick['name'] as String? ?? '—';
            final pRole = pick['role'] as String? ?? '';
            final pReason = pick['reason'] as String? ?? '';
            return Padding(
              padding: EdgeInsets.only(bottom: i == picks.length - 1 ? 0 : 12),
              child: _PickRow(
                number: i + 1,
                name: pName,
                role: pRole,
                reason: pReason,
              ),
            );
          }),

          // Team outlook
          if (outlook.isNotEmpty) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: _bg,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: _border),
              ),
              child: Text(
                outlook,
                style: const TextStyle(
                  color: _t2,
                  fontSize: 12,
                  height: 1.45,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Pick row ───────────────────────────────────────────────
class _PickRow extends StatelessWidget {
  final int number;
  final String name, role, reason;

  const _PickRow({
    required this.number,
    required this.name,
    required this.role,
    required this.reason,
  });

  Color get _roleColor {
    switch (role) {
      case 'batsman':
        return const Color(0xFF4FC3F7);
      case 'bowler':
        return const Color(0xFFFF8A65);
      case 'allrounder':
        return const Color(0xFF81C784);
      case 'wicketkeeper':
        return const Color(0xFFFFD54F);
      default:
        return const Color(0xFF666666);
    }
  }

  String get _roleShort {
    switch (role) {
      case 'batsman':
        return 'BAT';
      case 'bowler':
        return 'BWL';
      case 'allrounder':
        return 'AR';
      case 'wicketkeeper':
        return 'WK';
      default:
        return role.toUpperCase();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Number
        Container(
          width: 20,
          height: 20,
          decoration: BoxDecoration(
            color: _surface2,
            shape: BoxShape.circle,
            border: Border.all(color: _border),
          ),
          child: Center(
            child: Text(
              '$number',
              style: const TextStyle(
                  color: _t2, fontSize: 10, fontWeight: FontWeight.w700),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    name,
                    style: const TextStyle(
                      color: _t1,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                    decoration: BoxDecoration(
                      color: _roleColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(3),
                      border: Border.all(color: _roleColor.withOpacity(0.25)),
                    ),
                    child: Text(
                      _roleShort,
                      style: TextStyle(
                        color: _roleColor,
                        fontSize: 8,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ],
              ),
              if (reason.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  reason,
                  style: const TextStyle(color: _t2, fontSize: 11, height: 1.4),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

// ── Confidence badge ───────────────────────────────────────
class _ConfidenceBadge extends StatelessWidget {
  final String confidence;
  const _ConfidenceBadge({required this.confidence});

  Color get _color {
    switch (confidence) {
      case 'high':
        return const Color(0xFF4CAF50);
      case 'low':
        return const Color(0xFF888888);
      default:
        return const Color(0xFFFFB300);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: _color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: _color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 5,
            height: 5,
            decoration: BoxDecoration(
              color: _color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 5),
          Text(
            '${confidence[0].toUpperCase()}${confidence.substring(1)} confidence',
            style: TextStyle(
              color: _color,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Shared buttons ─────────────────────────────────────────
class _GenerateBtn extends StatefulWidget {
  final bool loading;
  final VoidCallback onTap;
  const _GenerateBtn({required this.loading, required this.onTap});

  @override
  State<_GenerateBtn> createState() => _GenerateBtnState();
}

class _GenerateBtnState extends State<_GenerateBtn> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.loading ? null : widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
          decoration: BoxDecoration(
            color: widget.loading
                ? Colors.redAccent.withOpacity(0.5)
                : _hovered
                    ? Colors.redAccent.shade700
                    : Colors.redAccent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              widget.loading
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2),
                    )
                  : const Icon(Icons.auto_awesome_rounded,
                      color: Colors.white, size: 15),
              const SizedBox(width: 8),
              Text(
                widget.loading ? 'Generating...' : 'Generate Prediction',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GhostBtn extends StatefulWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  const _GhostBtn(
      {required this.label, required this.icon, required this.onTap});

  @override
  State<_GhostBtn> createState() => _GhostBtnState();
}

class _GhostBtnState extends State<_GhostBtn> {
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
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: _hovered ? _surface2 : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: _hovered ? _border : Colors.transparent),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(widget.icon, color: _hovered ? _t2 : _t3, size: 15),
              const SizedBox(width: 6),
              Text(
                widget.label,
                style: TextStyle(
                    color: _hovered ? _t2 : _t3,
                    fontSize: 13,
                    fontWeight: FontWeight.w500),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
