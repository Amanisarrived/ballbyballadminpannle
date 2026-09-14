class WinProbability {
  WinProbability._();

  static const _parScores = {
    't20': 165,
    't10': 100,
    'odi': 270,
    'test': 300,
  };

  static const _totalOvers = {
    't20': 20,
    't10': 10,
    'odi': 50,
    'test': 90,
  };

  static Map<String, int> calculate({
    required String format,
    required int innings,
    required String battingTeamKey,
    required int runs,
    required int wickets,
    required int overs,
    required int balls,
    int? targetRuns,
    int? totalBalls,
    int? ballsBowled,
  }) {
    final fmt = format.toLowerCase();
    final bowlingTeamKey = battingTeamKey == 'teamA' ? 'teamB' : 'teamA';

    double battingProb;

    if (innings == 1) {
      battingProb = _firstInningsProb(
        format: fmt,
        runs: runs,
        wickets: wickets,
        overs: overs,
        balls: balls,
      );
    } else {
      battingProb = _secondInningsProb(
        format: fmt,
        runs: runs,
        wickets: wickets,
        overs: overs,
        balls: balls,
        targetRuns: targetRuns ?? 0,
        totalBalls: totalBalls ?? (_totalOvers[fmt] ?? 20) * 6,
        ballsBowled: ballsBowled,
      );
    }

    battingProb = battingProb.clamp(2, 98);

    final battingPct = battingProb.round();
    final bowlingPct = 100 - battingPct;

    return {
      battingTeamKey: battingPct,
      bowlingTeamKey: bowlingPct,
    };
  }

  static double _firstInningsProb({
    required String format,
    required int runs,
    required int wickets,
    required int overs,
    required int balls,
  }) {
    final maxOvers = _totalOvers[format] ?? 20;
    final parScore = _parScores[format] ?? 165;
    final totalBalls = overs * 6 + balls;

    // Too early — not enough data
    if (totalBalls < 12) return 50.0;

    // ── Factor 1: Run rate vs par rate ──
    final currentRR = runs / (totalBalls / 6);
    final parRR = parScore / maxOvers;
    // How much faster/slower than par (normalized)
    final rrRatio = currentRR / parRR;
    // Convert to -1 to +1 scale, centered at par
    final rrFactor = (rrRatio - 1.0).clamp(-0.6, 0.6);

    // ── Factor 2: Wickets pressure ──
    // More wickets lost = worse position
    // Weighted more in middle/death overs
    final oversProgress = totalBalls / (maxOvers * 6);
    final wicketPressure = _wicketPressure(wickets, oversProgress, format);
    final phaseMultiplier = _phaseMultiplier(oversProgress, format);
    double prob = 50.0;
    prob += rrFactor * 25 * phaseMultiplier;
    prob -= wicketPressure * 30;

    return prob;
  }

  static double _secondInningsProb({
    required String format,
    required int runs,
    required int wickets,
    required int overs,
    required int balls,
    required int targetRuns,
    required int totalBalls,
    int? ballsBowled,
  }) {
    final bowled = ballsBowled ?? (overs * 6 + balls);

    if (bowled < 12) return 50.0;

    final runsNeeded = targetRuns - runs;
    final ballsLeft = totalBalls - bowled;
    final wicketsLeft = 10 - wickets;

    if (runsNeeded <= 0) return 98.0;

    if (wicketsLeft <= 0 || ballsLeft <= 0) return 2.0;

    // ── Factor 1: Required rate vs current rate ──
    final currentRR = bowled > 0 ? runs / (bowled / 6) : 0.0;
    final requiredRR = ballsLeft > 0 ? runsNeeded / (ballsLeft / 6) : 99.0;

    double rrDiff;
    if (requiredRR <= 0) {
      rrDiff = 1.0; // Already winning
    } else {
      // How achievable is the required rate?
      // < 1.0 means required is harder than current
      rrDiff = currentRR / requiredRR;
    }
    final rrFactor = (rrDiff - 1.0).clamp(-1.0, 1.0);

    // ── Factor 2: Wickets in hand ──
    // More wickets = more chances to chase
    final wicketFactor = wicketsLeft / 10.0; // 0.0 to 1.0

    // ── Factor 3: Runs per ball needed ──
    final runsPerBall = runsNeeded / ballsLeft;
    double rpbPenalty;
    if (format == 't20' || format == 't10') {
      // T20: > 2.0 rpb is very hard, > 2.5 almost impossible
      rpbPenalty = (runsPerBall - 1.0).clamp(0, 2.0) / 2.0;
    } else {
      // ODI: > 1.5 rpb is hard
      rpbPenalty = (runsPerBall - 0.8).clamp(0, 1.5) / 1.5;
    }

    // ── Factor 4: Match progression ──
    final progress = bowled / totalBalls; // 0 to 1

    // ── Combine ──
    double prob = 50.0;

    // RR comparison (max ±20%)
    prob += rrFactor * 20;

    // Wickets in hand bonus (max +15%)
    prob += (wicketFactor - 0.5) * 15;

    // Runs per ball penalty (max -25%)
    prob -= rpbPenalty * 25;

    // Late game amplification
    // As match progresses, factors matter more
    if (progress > 0.6) {
      final amplify = 1.0 + (progress - 0.6) * 1.5;
      prob = 50 + (prob - 50) * amplify;
    }

    return prob;
  }

  // ─────────────────────────────────────────────
  //  Helper: Wicket pressure
  // ─────────────────────────────────────────────

  static double _wicketPressure(
      int wickets, double oversProgress, String format) {
    if (wickets == 0) return 0.0;

    final perWicket = {
      't20': [0.03, 0.05, 0.08, 0.12, 0.18, 0.25, 0.35, 0.50, 0.70, 0.90],
      't10': [0.04, 0.07, 0.12, 0.18, 0.28, 0.40, 0.55, 0.70, 0.85, 0.95],
      'odi': [0.02, 0.04, 0.06, 0.09, 0.13, 0.18, 0.25, 0.35, 0.55, 0.80],
      'test': [0.01, 0.03, 0.05, 0.07, 0.10, 0.14, 0.20, 0.30, 0.45, 0.70],
    };

    final pressureTable = perWicket[format] ?? perWicket['t20']!;
    final idx = (wickets - 1).clamp(0, 9);
    double pressure = pressureTable[idx];

    // Early wickets hurt more (collapse fear)
    if (oversProgress < 0.3 && wickets >= 3) {
      pressure *= 1.3;
    }

    return pressure.clamp(0, 1.0);
  }

  // ─────────────────────────────────────────────

  static double _phaseMultiplier(double oversProgress, String format) {
    if (format == 't20' || format == 't10') {
      // Powerplay (0-30%): RR less meaningful
      if (oversProgress < 0.3) return 0.6;
      // Middle (30-75%): Normal
      if (oversProgress < 0.75) return 1.0;
      // Death (75%+): RR and wickets highly meaningful
      return 1.4;
    } else if (format == 'odi') {
      if (oversProgress < 0.2) return 0.5;
      if (oversProgress < 0.7) return 1.0;
      return 1.3;
    }
    // Test
    return 0.8;
  }
}
