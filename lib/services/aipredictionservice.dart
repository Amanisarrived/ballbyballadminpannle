import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:cricket_admin/services/featured_match_service.dart';

// ── Perplexity Sonar via OpenRouter (web search enabled) ──
const _openRouterKey =
    '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'; // replace with your key
const _openRouterUrl = 'https://openrouter.ai/api/v1/chat/completions';
const _model = 'perplexity/sonar'; // has live web search

class AiPredictionService {
  static Future<String?> generateAndSave() async {
    try {
      final snap = await FeaturedMatchService.get();
      if (!snap.exists) return 'No featured match found.';

      final data = snap.data()! as Map<String, dynamic>;
      final meta = data['meta'] as Map<String, dynamic>? ?? {};
      final teams = data['teams'] as Map<String, dynamic>? ?? {};
      final teamA = teams['teamA'] as Map<String, dynamic>? ?? {};
      final teamB = teams['teamB'] as Map<String, dynamic>? ?? {};
      final aName = teamA['name'] as String? ?? 'Team A';
      final bName = teamB['name'] as String? ?? 'Team B';
      final aPlayers = teamA['players'] as List<dynamic>? ?? [];
      final bPlayers = teamB['players'] as List<dynamic>? ?? [];
      final title = meta['title'] as String? ?? '$aName vs $bName';
      final venue = meta['venue'] as String? ?? 'Unknown venue';
      final format = meta['format'] as String? ?? 'T20';
      final pitchType = meta['pitchType'] as String? ?? 'balanced';
      final pitchNote = meta['pitchNote'] as String? ?? '';
      final matchDate = meta['matchDate'] as String? ?? '';

      final systemPrompt = _buildSystemPrompt();
      final userPrompt = _buildUserPrompt(
        title: title,
        venue: venue,
        format: format.toUpperCase(),
        pitchType: pitchType,
        pitchNote: pitchNote,
        matchDate: matchDate,
        teamAName: aName,
        teamBName: bName,
        teamAPlayers: aPlayers,
        teamBPlayers: bPlayers,
      );

      // ── Perplexity Sonar API call via OpenRouter ──────────
      final response = await http.post(
        Uri.parse(_openRouterUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_openRouterKey',
          'HTTP-Referer': 'https://cricview.app',
          'X-Title': 'CricView Admin',
        },
        body: jsonEncode({
          'model': _model,
          'messages': [
            {'role': 'system', 'content': systemPrompt},
            {'role': 'user', 'content': userPrompt},
          ],
          'temperature': 0.2, // low temp = more factual, consistent
          'max_tokens': 1500,
          'web_search_mode': 'on', // Sonar searches Cricbuzz, ESPN, etc.
        }),
      );

      if (response.statusCode != 200) {
        return 'API error ${response.statusCode}: ${response.body}';
      }

      // ── Parse Perplexity response ─────────────────────────
      final responseJson = jsonDecode(response.body) as Map<String, dynamic>;
      final rawText =
          responseJson['choices']?[0]?['message']?['content'] as String? ?? '';

      if (rawText.isEmpty) return 'Empty response from AI.';

      // Strip markdown if any
      String extracted =
          rawText.replaceAll('```json', '').replaceAll('```', '').trim();

      final firstBrace = extracted.indexOf('{');
      final lastBrace = extracted.lastIndexOf('}');

      if (firstBrace == -1 || lastBrace == -1 || lastBrace <= firstBrace) {
        return 'No JSON in response.\n\nRaw: $rawText';
      }

      extracted = extracted.substring(firstBrace, lastBrace + 1);

      Map<String, dynamic> prediction;
      try {
        prediction = jsonDecode(extracted) as Map<String, dynamic>;
      } catch (e) {
        return 'JSON parse error: $e\n\nExtracted: $extracted';
      }

      await FeaturedMatchService.saveAiPrediction(prediction);
      return null;
    } catch (e) {
      return 'Unexpected error: $e';
    }
  }

  // ─────────────────────────────────────────────────────────
  //  SYSTEM PROMPT — Perplexity Sonar personality
  //  Sonar has web search — it will pull live stats from
  //  Cricbuzz, ESPN Cricinfo, ICC, etc. automatically
  // ─────────────────────────────────────────────────────────
  static String _buildSystemPrompt() => '''
You are CricView's elite cricket prediction engine — a senior analyst with 20+ years covering international and domestic cricket at the highest level.

YOUR CAPABILITIES:
- Search and use LIVE data from Cricbuzz, ESPN Cricinfo, ICC, BCCI, and cricket stats sites
- Access recent match results, player form, head-to-head records, and venue stats
- Analyze pitch reports, weather, toss impact, and team composition

YOUR ANALYSIS PROCESS (follow strictly):
1. SEARCH for both teams' last 5 match results and top performers
2. SEARCH for head-to-head record between these two teams at this venue
3. SEARCH for venue stats — average score, pitch behavior, dew factor
4. SEARCH for player injury/availability news for this match
5. Analyze toss advantage at this venue (bat first vs chase stats)
6. Consider format-specific strategies (T20 powerplay, death overs, ODI middle overs)
7. Factor in current tournament standings and pressure situations

PREDICTION ACCURACY RULES:
- Base predictions on ACTUAL recent stats — not general reputation
- A player in poor form should NOT be a top pick regardless of their career stats
- Pitch type is critical — spinners on a turning track, pacers on green tops
- Dew factor in evening T20s heavily favors chasing teams — factor this in
- Home advantage is real — factor crowd pressure and familiar conditions
- Do NOT pick injured or unavailable players

OUTPUT: Respond ONLY with a raw JSON object. No text before or after. No markdown. Start with { and end with }.
''';

  // ─────────────────────────────────────────────────────────
  //  USER PROMPT — detailed match context for Sonar
  // ─────────────────────────────────────────────────────────
  static String _buildUserPrompt({
    required String title,
    required String venue,
    required String format,
    required String pitchType,
    required String pitchNote,
    required String matchDate,
    required String teamAName,
    required String teamBName,
    required List<dynamic> teamAPlayers,
    required List<dynamic> teamBPlayers,
  }) {
    final aSquad = _formatSquad(teamAPlayers);
    final bSquad = _formatSquad(teamBPlayers);
    final pitchInfo =
        pitchNote.isNotEmpty ? '$pitchType — $pitchNote' : pitchType;
    final dateInfo = matchDate.isNotEmpty ? 'Match Date: $matchDate' : '';

    return '''
Analyze this cricket match and provide your most accurate prediction using live web data.

MATCH DETAILS:
- Title:  $title
- Format: $format
- Venue:  $venue
- Pitch:  $pitchInfo
${dateInfo.isNotEmpty ? '- Date: $matchDate' : ''}

INSTRUCTIONS:
1. Search Cricbuzz and ESPN Cricinfo for "$teamAName vs $teamBName $format" recent news and stats
2. Search "$venue cricket pitch report" for venue-specific insights
3. Search "$teamAName recent matches 2025" and "$teamBName recent matches 2025" for current form
4. Search "head to head $teamAName vs $teamBName" for historical record
5. Use the squad data below to pick the most impactful players based on CURRENT form

$teamAName SQUAD:
$aSquad

$teamBName SQUAD:
$bSquad

Based on your web research AND the squad stats above, return ONLY this JSON:
{
  "team_a": {
    "name": "$teamAName",
    "top_picks": [
      {
        "name": "Player Name",
        "role": "batsman",
        "reason": "Specific stat-backed reason — current form or venue record (max 12 words)"
      },
      {
        "name": "Player Name",
        "role": "bowler",
        "reason": "Specific reason with recent wickets or economy (max 12 words)"
      },
      {
        "name": "Player Name",
        "role": "allrounder",
        "reason": "Specific reason (max 12 words)"
      }
    ],
    "team_outlook": "One punchy sentence about this team's chances — based on current form and conditions"
  },
  "team_b": {
    "name": "$teamBName",
    "top_picks": [
      {
        "name": "Player Name",
        "role": "batsman",
        "reason": "Specific stat-backed reason (max 12 words)"
      },
      {
        "name": "Player Name",
        "role": "bowler",
        "reason": "Specific reason (max 12 words)"
      },
      {
        "name": "Player Name",
        "role": "allrounder",
        "reason": "Specific reason (max 12 words)"
      }
    ],
    "team_outlook": "One punchy sentence about this team's chances today"
  },
  "predicted_winner": "Exact team name — either $teamAName or $teamBName",
  "confidence": "high or moderate or low",
  "match_note": "One sharp insight about the KEY factor that will decide this match — pitch, form, or matchup"
}

STRICT RULES:
- top_picks: exactly 3 players per team (1 batsman, 1 bowler, 1 allrounder)
- Only pick players from the squads provided above
- reason must mention a specific stat, recent score, wickets, or venue record
- predicted_winner must be EXACTLY "$teamAName" or "$teamBName"
- confidence: "high" = clear edge exists | "moderate" = slight edge | "low" = coin flip
- match_note must be specific and insightful — NOT generic like "it will be a close match"
- If a player is injured or unavailable (from your search), DO NOT pick them
''';
  }

  // ─────────────────────────────────────────────────────────
  //  FORMAT SQUAD for prompt
  // ─────────────────────────────────────────────────────────
  static String _formatSquad(List<dynamic> players) {
    if (players.isEmpty) return '  No players added yet.';

    final lines = <String>[];
    for (final p in players) {
      final pm = p as Map<String, dynamic>;
      final name = pm['name'] as String? ?? '?';
      final role = pm['role'] as String? ?? 'batsman';
      final parts = <String>['  - $name ($role)'];

      if (pm['batting_avg'] != null) parts.add('Bat Avg: ${pm['batting_avg']}');
      if (pm['strike_rate'] != null) parts.add('SR: ${pm['strike_rate']}');
      if (pm['recent_form'] != null) {
        final form = (pm['recent_form'] as List).join(', ');
        parts.add('Recent scores: [$form]');
      }
      if (pm['bowling_avg'] != null)
        parts.add('Bowl Avg: ${pm['bowling_avg']}');
      if (pm['economy'] != null) parts.add('Eco: ${pm['economy']}');
      if (pm['recent_wickets'] != null) {
        final wkts = (pm['recent_wickets'] as List).join(', ');
        parts.add('Recent wkts: [$wkts]');
      }
      if (pm['venue_avg'] != null) parts.add('Venue Avg: ${pm['venue_avg']}');

      lines.add(parts.join(' | '));
    }
    return lines.join('\n');
  }
}
