import 'package:cricket_admin/services/rankinsservice.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// ─────────────────────────────────────────────────────────────
//  THEME
// ─────────────────────────────────────────────────────────────
const _bg = Color(0xFF0C0C0C);
const _surface = Color(0xFF131313);
const _surf2 = Color(0xFF191919);
const _surf3 = Color(0xFF1F1F1F);
const _bdr = Color(0xFF242424);
const _bdr2 = Color(0xFF2E2E2E);
const _accent = Color(0xFFCC0000);
const _tp = Color(0xFFCCCCCC);
const _ts = Color(0xFF484848);
const _green = Color(0xFF22CC66);
const _orange = Color(0xFFFF8800);

// ═════════════════════════════════════════════════════════════
//  RANKINGS ADMIN SCREEN
//
//  Single tournament flow:
//  → Edit tournament meta (name + logo)
//  → Add / edit / reorder players
//  → Reset players when new tournament starts (keeps meta)
// ═════════════════════════════════════════════════════════════
class RankingsAdminScreen extends StatefulWidget {
  const RankingsAdminScreen({super.key});
  @override
  State<RankingsAdminScreen> createState() => _RankingsAdminScreenState();
}

class _RankingsAdminScreenState extends State<RankingsAdminScreen>
    with TickerProviderStateMixin {
  TournamentConfig? _tournament;
  bool _loadingMeta = true;

  RankCategory _category = RankCategory.batsmen;
  List<RankedPlayer> _players = [];
  bool _loading = true;
  bool _saving = false;
  DateTime? _lastUpdated;

  static const _tournamentId = 'current'; // single fixed doc id

  @override
  void initState() {
    super.initState();
    _loadMeta();
  }

  // ── Meta (tournament name + logo) ────────────────────────

  Future<void> _loadMeta() async {
    setState(() => _loadingMeta = true);
    final all = await RankingsService.fetchAllTournaments();
    final t = all.isNotEmpty ? all.first : null;
    if (!mounted) return;
    setState(() {
      _tournament = t;
      _loadingMeta = false;
    });
    _loadPlayers();
  }

  Future<void> _saveMeta(TournamentConfig updated) async {
    await RankingsService.saveTournaments([updated]);
    if (!mounted) return;
    setState(() => _tournament = updated);
    _snack('Tournament updated');
  }

  void _openEditMeta() async {
    final result = await showDialog<TournamentConfig>(
      context: context,
      builder: (_) => _TournamentMetaDialog(existing: _tournament),
    );
    if (result == null) return;
    await _saveMeta(result);
  }

  // ── Players ──────────────────────────────────────────────

  Future<void> _loadPlayers() async {
    setState(() => _loading = true);
    final players =
        await RankingsService.fetchTournamentRankings(_tournamentId, _category);
    final updated = await RankingsService.getTournamentLastUpdated(
        _tournamentId, _category);
    if (!mounted) return;
    setState(() {
      _players = players;
      _lastUpdated = updated;
      _loading = false;
    });
  }

  Future<void> _savePlayers() async {
    setState(() => _saving = true);
    try {
      await RankingsService.saveTournamentRankings(
        tournamentId: _tournamentId,
        tournamentName: _tournament?.name ?? '',
        category: _category,
        players: _players,
      );
      _snack('Saved successfully');
      await _loadPlayers();
    } catch (e) {
      _snack('Error: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _openAddOrEdit({RankedPlayer? existing}) async {
    final result = await showDialog<RankedPlayer>(
      context: context,
      builder: (_) => _PlayerFormDialog(
        existing: existing,
        category: _category,
        usedRanks: _players.map((p) => p.rank).toList(),
        editingRank: existing?.rank,
      ),
    );
    if (result == null) return;
    setState(() {
      if (existing != null) {
        final i = _players.indexWhere((p) => p.rank == existing.rank);
        if (i >= 0) _players[i] = result;
      } else {
        _players.add(result);
      }
      _players.sort((a, b) => a.rank.compareTo(b.rank));
    });
  }

  Future<void> _deletePlayer(int rank) async {
    if (!await _confirm(
        'Remove player?', 'Removed from local list. Press Save to apply.'))
      return;
    setState(() => _players.removeWhere((p) => p.rank == rank));
  }

  // ── Reset ────────────────────────────────────────────────

  Future<void> _resetPlayers() async {
    if (!await _confirm(
      'Reset all players?',
      'This will delete ALL player rankings for both Batsmen and Bowlers.\n\nTournament name and logo will stay.\n\nUse this when a new tournament starts.',
    )) return;
    await RankingsService.resetTournamentRankings(_tournamentId);
    setState(() {
      _players = [];
      _lastUpdated = null;
    });
    _snack('All rankings cleared');
  }

  // ── Helpers ──────────────────────────────────────────────

  Future<bool> _confirm(String title, String body) async {
    return await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            backgroundColor: _surface,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: const BorderSide(color: _bdr)),
            title: Text(title,
                style: const TextStyle(
                    color: _tp, fontSize: 15, fontWeight: FontWeight.w600)),
            content: Text(body,
                style: const TextStyle(color: _ts, fontSize: 12, height: 1.6)),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Cancel', style: TextStyle(color: _ts))),
              TextButton(
                  onPressed: () => Navigator.pop(context, true),
                  child:
                      const Text('Confirm', style: TextStyle(color: _accent))),
            ],
          ),
        ) ??
        false;
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(
        content: Text(msg, style: const TextStyle(fontSize: 12, color: _tp)),
        backgroundColor: _surf3,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ));
  }

  // ─────────────────────────────────────────────────────────
  //  BUILD
  // ─────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      floatingActionButton: FloatingActionButton(
        backgroundColor: _accent,
        onPressed: _openAddOrEdit,
        child: const Icon(Icons.add_rounded, color: Colors.white),
      ),
      body: SafeArea(
        child: Column(children: [
          _buildHeader(),
          _buildCategoryTabs(),
          if (_lastUpdated != null) _buildLastUpdated(),
          Expanded(child: _loading ? _buildLoader() : _buildBody()),
        ]),
      ),
    );
  }

  // ── Header ───────────────────────────────────────────────
  Widget _buildHeader() {
    final t = _tournament;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration:
          const BoxDecoration(border: Border(bottom: BorderSide(color: _bdr))),
      child: Row(children: [
        // Logo
        GestureDetector(
          onTap: _openEditMeta,
          child: Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: _surf2,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: _bdr2),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: t != null && t.logoUrl.isNotEmpty
                  ? Image.network(t.logoUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const Icon(
                          Icons.emoji_events_rounded,
                          color: _accent,
                          size: 20))
                  : const Icon(Icons.emoji_events_rounded,
                      color: _accent, size: 20),
            ),
          ),
        ),
        const SizedBox(width: 12),

        // Name + subtitle
        Expanded(
          child: GestureDetector(
            onTap: _openEditMeta,
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Flexible(
                  child: Text(
                    t?.name ?? 'No tournament set',
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: _tp, fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                ),
                const SizedBox(width: 6),
                const Icon(Icons.edit_outlined, color: _ts, size: 12),
              ]),
              const SizedBox(height: 2),
              const Text('Tap to edit name & logo',
                  style: TextStyle(color: _ts, fontSize: 10)),
            ]),
          ),
        ),
        const SizedBox(width: 10),

        // Reset button
        GestureDetector(
          onTap: _resetPlayers,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: _orange.withOpacity(0.08),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: _orange.withOpacity(0.25)),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: const [
              Icon(Icons.refresh_rounded, color: _orange, size: 14),
              SizedBox(width: 5),
              Text('Reset',
                  style: TextStyle(
                      color: _orange,
                      fontSize: 12,
                      fontWeight: FontWeight.w600)),
            ]),
          ),
        ),
        const SizedBox(width: 8),

        // Save button
        GestureDetector(
          onTap: _saving || _players.isEmpty ? null : _savePlayers,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: _saving || _players.isEmpty ? _surf2 : _accent,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                  color: _saving || _players.isEmpty ? _bdr : _accent),
            ),
            child: _saving
                ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 1.5))
                : const Text('Save',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600)),
          ),
        ),
      ]),
    );
  }

  // ── Category tabs ────────────────────────────────────────
  Widget _buildCategoryTabs() {
    final cats = [RankCategory.batsmen, RankCategory.bowlers];
    return Container(
      color: _surf2,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      child: Row(
        children: cats.map((cat) {
          final sel = _category == cat;
          return Expanded(
            child: GestureDetector(
              onTap: () {
                if (_category == cat) return;
                setState(() => _category = cat);
                _loadPlayers();
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                margin: const EdgeInsets.symmetric(horizontal: 3),
                padding: const EdgeInsets.symmetric(vertical: 9),
                decoration: BoxDecoration(
                  color: sel ? _accent.withOpacity(0.1) : Colors.transparent,
                  borderRadius: BorderRadius.circular(7),
                  border:
                      Border.all(color: sel ? _accent.withOpacity(0.3) : _bdr),
                ),
                child: Text(cat.label,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        color: sel ? _accent : _ts,
                        fontSize: 11,
                        fontWeight: sel ? FontWeight.w600 : FontWeight.w400)),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildLastUpdated() {
    final dt = _lastUpdated!;
    final f =
        '${dt.day}/${dt.month}/${dt.year}  ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
      decoration:
          const BoxDecoration(border: Border(bottom: BorderSide(color: _bdr))),
      child: Row(children: [
        const Icon(Icons.access_time_rounded, color: _ts, size: 11),
        const SizedBox(width: 5),
        Text('Last saved  $f',
            style: const TextStyle(color: _ts, fontSize: 10)),
        const Spacer(),
        Text('${_players.length} players',
            style: const TextStyle(color: _ts, fontSize: 10)),
      ]),
    );
  }

  Widget _buildLoader() => const Center(
      child: CircularProgressIndicator(color: _accent, strokeWidth: 1.5));

  Widget _buildBody() {
    if (_players.isEmpty) {
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: _surface,
              borderRadius: BorderRadius.circular(13),
              border: Border.all(color: _bdr),
            ),
            child: const Icon(Icons.format_list_numbered_rounded,
                color: _ts, size: 22),
          ),
          const SizedBox(height: 14),
          Text('No ${_category.label} added yet',
              style: const TextStyle(
                  color: _tp, fontSize: 13, fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          const Text('Tap + to add the first player',
              style: TextStyle(color: _ts, fontSize: 11)),
        ]),
      );
    }

    return ReorderableListView.builder(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 80),
      itemCount: _players.length,
      onReorder: (oldIndex, newIndex) {
        setState(() {
          if (newIndex > oldIndex) newIndex--;
          final item = _players.removeAt(oldIndex);
          _players.insert(newIndex, item);
          for (var i = 0; i < _players.length; i++) {
            _players[i] = _players[i].copyWith(rank: i + 1);
          }
        });
      },
      itemBuilder: (_, i) {
        final p = _players[i];
        return RepaintBoundary(
          key: ValueKey('player_${p.rank}_${p.name}'),
          child: Row(children: [
            Expanded(
              child: _PlayerTile(
                player: p,
                category: _category,
                onEdit: () => _openAddOrEdit(existing: p),
                onDelete: () => _deletePlayer(p.rank),
              ),
            ),
            ReorderableDragStartListener(
              index: i,
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 10, vertical: 16),
                child: Icon(Icons.drag_handle_rounded, color: _ts, size: 18),
              ),
            ),
          ]),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  TOURNAMENT META DIALOG  (edit name + logo only)
// ─────────────────────────────────────────────────────────────
class _TournamentMetaDialog extends StatefulWidget {
  final TournamentConfig? existing;
  const _TournamentMetaDialog({this.existing});
  @override
  State<_TournamentMetaDialog> createState() => _TournamentMetaDialogState();
}

class _TournamentMetaDialogState extends State<_TournamentMetaDialog> {
  late final TextEditingController _name;
  late final TextEditingController _logo;
  String? _err;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.existing?.name ?? '');
    _logo = TextEditingController(text: widget.existing?.logoUrl ?? '');
  }

  @override
  void dispose() {
    _name.dispose();
    _logo.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _name.text.trim();
    if (name.isEmpty) {
      setState(() => _err = 'Enter tournament name');
      return;
    }
    Navigator.pop(
      context,
      TournamentConfig(
        id: 'current',
        name: name,
        logoUrl: _logo.text.trim(),
        isActive: true,
        categories: const [RankCategory.batsmen, RankCategory.bowlers],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: _surface,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: _bdr)),
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Tournament Info',
                  style: TextStyle(
                      color: _tp, fontSize: 15, fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              const Text('Update the current tournament name and logo',
                  style: TextStyle(color: _ts, fontSize: 11)),
              const SizedBox(height: 20),

              _label('Tournament / Series Name'),
              const SizedBox(height: 5),
              _input(
                  ctrl: _name,
                  hint: 'e.g. IPL 2025',
                  icon: Icons.emoji_events_rounded),
              const SizedBox(height: 12),

              _label('Logo Image URL'),
              const SizedBox(height: 5),
              _input(
                  ctrl: _logo,
                  hint: 'https://...logo.png',
                  icon: Icons.image_outlined),

              // Logo preview
              if (_logo.text.isNotEmpty) ...[
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(_logo.text.trim(),
                      height: 48,
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => const SizedBox()),
                ),
              ],

              if (_err != null) ...[
                const SizedBox(height: 10),
                Text(_err!,
                    style: const TextStyle(color: _accent, fontSize: 11)),
              ],

              const SizedBox(height: 20),
              Row(children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                          color: _surf2,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: _bdr)),
                      child: const Center(
                          child: Text('Cancel',
                              style: TextStyle(
                                  color: _ts,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500))),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: GestureDetector(
                    onTap: _submit,
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                          color: _accent,
                          borderRadius: BorderRadius.circular(8)),
                      child: const Center(
                          child: Text('Save',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600))),
                    ),
                  ),
                ),
              ]),
            ]),
      ),
    );
  }

  Widget _label(String t) =>
      Text(t, style: const TextStyle(color: _ts, fontSize: 10));

  Widget _input({
    required TextEditingController ctrl,
    required String hint,
    required IconData icon,
  }) =>
      Container(
        decoration: BoxDecoration(
            color: _surf2,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: _bdr)),
        child: TextField(
          controller: ctrl,
          onChanged: (_) => setState(() {}),
          style: const TextStyle(color: _tp, fontSize: 13),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: _ts, fontSize: 12),
            prefixIcon: Icon(icon, color: _ts, size: 15),
            border: InputBorder.none,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
          ),
        ),
      );
}

// ─────────────────────────────────────────────────────────────
//  PLAYER TILE
// ─────────────────────────────────────────────────────────────
class _PlayerTile extends StatelessWidget {
  final RankedPlayer player;
  final RankCategory category;
  final VoidCallback onEdit, onDelete;
  const _PlayerTile({
    required this.player,
    required this.category,
    required this.onEdit,
    required this.onDelete,
  });

  bool get _isBat => category == RankCategory.batsmen;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(
          color: _surface,
          borderRadius: BorderRadius.circular(9),
          border: Border.all(color: _bdr)),
      child: Row(children: [
        // Player image
        Container(
          width: 36,
          height: 36,
          margin: const EdgeInsets.only(left: 10),
          decoration: BoxDecoration(
              color: _surf2,
              shape: BoxShape.circle,
              border: Border.all(color: _bdr)),
          child: ClipOval(
            child: player.imageUrl.isNotEmpty
                ? Image.network(player.imageUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => _fallback(player.name))
                : _fallback(player.name),
          ),
        ),
        // Flag
        if (player.flagUrl.isNotEmpty)
          Container(
            width: 20,
            height: 20,
            margin: const EdgeInsets.only(left: 6),
            decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: _bdr, width: 0.5)),
            child: ClipOval(
              child: Image.network(player.flagUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const SizedBox()),
            ),
          )
        else
          const SizedBox(width: 6),

        // Rank badge
        Container(
          width: 28,
          height: 28,
          margin: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            color: player.rank <= 3 ? _accent.withOpacity(0.1) : _surf2,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
                color: player.rank <= 3 ? _accent.withOpacity(0.25) : _bdr),
          ),
          child: Center(
            child: Text('#${player.rank}',
                style: TextStyle(
                    color: player.rank <= 3 ? _accent : _ts,
                    fontSize: 9,
                    fontWeight: FontWeight.w700)),
          ),
        ),

        // Name
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text(player.name,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    color: _tp, fontSize: 13, fontWeight: FontWeight.w500)),
          ),
        ),

        // Stat
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text(
            _isBat ? '${player.runs}' : '${player.wickets}',
            style: const TextStyle(
                color: _tp, fontSize: 13, fontWeight: FontWeight.w600),
          ),
          Text(_isBat ? 'runs' : 'wkts',
              style: const TextStyle(color: _ts, fontSize: 8)),
        ]),
        const SizedBox(width: 10),

        // Actions
        Row(mainAxisSize: MainAxisSize.min, children: [
          _btn(Icons.edit_outlined, _ts, onEdit),
          _btn(
              Icons.delete_outline_rounded, _accent.withOpacity(0.6), onDelete),
          const SizedBox(width: 6),
        ]),
      ]),
    );
  }

  Widget _btn(IconData icon, Color color, VoidCallback onTap) =>
      GestureDetector(
        onTap: onTap,
        child: Container(
          width: 32,
          height: 32,
          margin: const EdgeInsets.only(left: 4),
          decoration: BoxDecoration(
            color: color.withOpacity(0.08),
            borderRadius: BorderRadius.circular(7),
            border: Border.all(color: color.withOpacity(0.15)),
          ),
          child: Icon(icon, color: color, size: 14),
        ),
      );

  Widget _fallback(String name) => Container(
        color: _surf3,
        child: Center(
          child: Text(
            name.isNotEmpty ? name[0].toUpperCase() : '?',
            style: const TextStyle(
                color: _ts, fontSize: 13, fontWeight: FontWeight.w700),
          ),
        ),
      );
}

// ─────────────────────────────────────────────────────────────
//  PLAYER FORM DIALOG
// ─────────────────────────────────────────────────────────────
class _PlayerFormDialog extends StatefulWidget {
  final RankedPlayer? existing;
  final RankCategory category;
  final List<int> usedRanks;
  final int? editingRank;
  const _PlayerFormDialog({
    required this.existing,
    required this.category,
    required this.usedRanks,
    required this.editingRank,
  });
  @override
  State<_PlayerFormDialog> createState() => _PlayerFormDialogState();
}

class _PlayerFormDialogState extends State<_PlayerFormDialog> {
  late final TextEditingController _rank;
  late final TextEditingController _name;
  late final TextEditingController _imageUrl;
  late final TextEditingController _flagUrl;
  late final TextEditingController _stat;
  String? _err;

  bool get _isBat => widget.category == RankCategory.batsmen;

  @override
  void initState() {
    super.initState();
    final p = widget.existing;
    _rank = TextEditingController(text: p != null ? '${p.rank}' : '');
    _name = TextEditingController(text: p?.name ?? '');
    _imageUrl = TextEditingController(text: p?.imageUrl ?? '');
    _flagUrl = TextEditingController(text: p?.flagUrl ?? '');
    _stat = TextEditingController(
        text: p != null ? (_isBat ? '${p.runs}' : '${p.wickets}') : '');
  }

  @override
  void dispose() {
    _rank.dispose();
    _name.dispose();
    _imageUrl.dispose();
    _flagUrl.dispose();
    _stat.dispose();
    super.dispose();
  }

  void _submit() {
    final rank = int.tryParse(_rank.text.trim());
    final name = _name.text.trim();
    final stat = int.tryParse(_stat.text.trim());

    if (rank == null || rank < 1) {
      setState(() => _err = 'Enter a valid rank');
      return;
    }
    if (name.isEmpty) {
      setState(() => _err = 'Enter player name');
      return;
    }
    if (stat == null) {
      setState(() => _err = _isBat ? 'Enter runs' : 'Enter wickets');
      return;
    }

    final taken =
        widget.usedRanks.where((r) => r != widget.editingRank).toList();
    if (taken.contains(rank)) {
      setState(() => _err = 'Rank #$rank already taken');
      return;
    }

    Navigator.pop(
        context,
        RankedPlayer(
          rank: rank,
          name: name,
          imageUrl: _imageUrl.text.trim(),
          flagUrl: _flagUrl.text.trim(),
          runs: _isBat ? stat : (widget.existing?.runs ?? 0),
          wickets: _isBat ? (widget.existing?.wickets ?? 0) : stat,
        ));
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.existing != null;
    return Dialog(
      backgroundColor: _surface,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: _bdr)),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(22),
        child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(isEdit ? 'Edit Player' : 'Add Player',
                  style: const TextStyle(
                      color: _tp, fontSize: 15, fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              Text(
                '${widget.category.label} — '
                '${_isBat ? 'enter runs scored' : 'enter wickets taken'}',
                style: const TextStyle(color: _ts, fontSize: 11),
              ),
              const SizedBox(height: 20),
              Row(children: [
                Expanded(
                    child: _field(
                  ctrl: _rank,
                  label: 'Rank',
                  hint: '1',
                  icon: Icons.format_list_numbered_rounded,
                  type: TextInputType.number,
                  fmt: [FilteringTextInputFormatter.digitsOnly],
                )),
                const SizedBox(width: 10),
                Expanded(
                    child: _field(
                  ctrl: _stat,
                  label: _isBat ? 'Runs' : 'Wickets',
                  hint: _isBat ? '450' : '18',
                  icon: _isBat
                      ? Icons.sports_cricket_rounded
                      : Icons.track_changes_rounded,
                  type: TextInputType.number,
                  fmt: [FilteringTextInputFormatter.digitsOnly],
                )),
              ]),
              const SizedBox(height: 12),
              _field(
                  ctrl: _name,
                  label: 'Player Name',
                  hint: 'e.g. Virat Kohli',
                  icon: Icons.person_outline_rounded,
                  type: TextInputType.text),
              const SizedBox(height: 12),
              _field(
                  ctrl: _imageUrl,
                  label: 'Player Image URL',
                  hint: 'https://...player.jpg',
                  icon: Icons.account_circle_outlined,
                  type: TextInputType.url),
              const SizedBox(height: 12),
              _field(
                  ctrl: _flagUrl,
                  label: 'Country Flag Image URL',
                  hint: 'https://...flag.png',
                  icon: Icons.flag_outlined,
                  type: TextInputType.url),
              if (_err != null) ...[
                const SizedBox(height: 10),
                Text(_err!,
                    style: const TextStyle(color: _accent, fontSize: 11)),
              ],
              const SizedBox(height: 20),
              Row(children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                          color: _surf2,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: _bdr)),
                      child: const Center(
                          child: Text('Cancel',
                              style: TextStyle(
                                  color: _ts,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500))),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: GestureDetector(
                    onTap: _submit,
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                          color: _accent,
                          borderRadius: BorderRadius.circular(8)),
                      child: Center(
                          child: Text(isEdit ? 'Update' : 'Add Player',
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600))),
                    ),
                  ),
                ),
              ]),
            ]),
      ),
    );
  }

  Widget _field({
    required TextEditingController ctrl,
    required String label,
    required String hint,
    required IconData icon,
    required TextInputType type,
    List<TextInputFormatter>? fmt,
  }) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: const TextStyle(color: _ts, fontSize: 10)),
      const SizedBox(height: 5),
      Container(
        decoration: BoxDecoration(
            color: _surf2,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: _bdr)),
        child: TextField(
          controller: ctrl,
          keyboardType: type,
          inputFormatters: fmt,
          style: const TextStyle(color: _tp, fontSize: 13),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: _ts, fontSize: 12),
            prefixIcon: Icon(icon, color: _ts, size: 15),
            border: InputBorder.none,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
          ),
        ),
      ),
    ]);
  }
}
