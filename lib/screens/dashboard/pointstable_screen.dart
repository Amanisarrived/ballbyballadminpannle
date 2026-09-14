import 'package:cricket_admin/models/teamstanding_model.dart';
import 'package:cricket_admin/services/pointsTableService.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// ── Theme ─────────────────────────────────────────────────
const _bg = Color(0xFF0D0D0D);
const _surface = Color(0xFF141414);
const _surface2 = Color(0xFF1A1A1A);
const _surface3 = Color(0xFF202020);
const _border = Color(0xFF232323);
const _border2 = Color(0xFF2A2A2A);
const _text = Color(0xFFE8E8E8);
const _textDim = Color(0xFF666666);
const _textMuted = Color(0xFF3A3A3A);
const _red = Color(0xFFCC0000);

// ════════════════════════════════════════════════════════════
//  POINTS TABLE ADMIN SCREEN
// ════════════════════════════════════════════════════════════
class PointsTableScreen extends StatefulWidget {
  const PointsTableScreen({super.key});
  @override
  State<PointsTableScreen> createState() => _PointsTableScreenState();
}

class _PointsTableScreenState extends State<PointsTableScreen> {
  final _tournamentCtrl = TextEditingController();

  bool _isGroupStage = false;
  bool _isVisible = false;
  bool _saving = false;
  bool _loaded = false;
  String _status = '';

  List<TableGroup> _groups = [TableGroup(groupName: 'Group A', teams: [])];
  int _expandedGroup = 0;

  @override
  void dispose() {
    _tournamentCtrl.dispose();
    super.dispose();
  }

  void _loadTable(PointsTable table) {
    if (_loaded) return;
    _loaded = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() {
        _tournamentCtrl.text = table.tournamentName;
        _isGroupStage = table.isGroupStage;
        _isVisible = table.isVisible;
        _groups = table.groups.isNotEmpty ? table.groups : _groups;
      });
    });
  }

  void _addGroup() {
    setState(() {
      final nextLetter = String.fromCharCode(65 + _groups.length);
      _groups.add(TableGroup(groupName: 'Group $nextLetter', teams: []));
      _expandedGroup = _groups.length - 1;
    });
  }

  void _removeGroup(int index) {
    if (_groups.length <= 1) return;
    setState(() {
      _groups.removeAt(index);
      _expandedGroup = _expandedGroup.clamp(0, _groups.length - 1);
    });
  }

  void _renameGroup(int index, String name) {
    _groups[index] = _groups[index].copyWith(groupName: name);
  }

  void _addTeam(int groupIndex) {
    setState(() {
      final updated = List<TeamStanding>.from(_groups[groupIndex].teams)
        ..add(const TeamStanding(
            name: '',
            logo: '',
            played: 0,
            won: 0,
            lost: 0,
            points: 0,
            nrr: 0.0));
      _groups[groupIndex] = _groups[groupIndex].copyWith(teams: updated);
    });
  }

  void _removeTeam(int groupIndex, int teamIndex) {
    setState(() {
      final updated = List<TeamStanding>.from(_groups[groupIndex].teams)
        ..removeAt(teamIndex);
      _groups[groupIndex] = _groups[groupIndex].copyWith(teams: updated);
    });
  }

  void _updateTeam(int gIdx, int tIdx, TeamStanding updated) {
    final teams = List<TeamStanding>.from(_groups[gIdx].teams);
    teams[tIdx] = updated;
    _groups[gIdx] = _groups[gIdx].copyWith(teams: teams);
  }

  // ── NEW: reorder teams within a group ────────────────────
  void _reorderTeam(int groupIndex, int oldIndex, int newIndex) {
    setState(() {
      // ReorderableListView fires newIndex AFTER removal, so adjust
      if (newIndex > oldIndex) newIndex -= 1;
      final teams = List<TeamStanding>.from(_groups[groupIndex].teams);
      final item = teams.removeAt(oldIndex);
      teams.insert(newIndex, item);
      _groups[groupIndex] = _groups[groupIndex].copyWith(teams: teams);
    });
  }

  Future<void> _save() async {
    if (_saving) return;
    if (_tournamentCtrl.text.trim().isEmpty) {
      _setStatus('error');
      return;
    }
    setState(() => _saving = true);
    try {
      await PointsTableService.save(PointsTable(
        tournamentName: _tournamentCtrl.text.trim(),
        isGroupStage: _isGroupStage,
        isVisible: _isVisible,
        groups: _groups,
      ));
      _setStatus('success');
    } catch (_) {
      _setStatus('error');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _setStatus(String s) {
    setState(() => _status = s);
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) setState(() => _status = '');
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: StreamBuilder(
        stream: PointsTableService.stream(),
        builder: (context, snap) {
          if (snap.hasData && snap.data?.data() != null) {
            _loadTable(PointsTable.fromDoc(snap.data!));
          }

          return Column(
            children: [
              _Header(
                isVisible: _isVisible,
                saving: _saving,
                onToggle: (v) async {
                  setState(() => _isVisible = v);
                  await PointsTableService.setVisible(v);
                },
                onSave: _save,
              ),
              if (_status.isNotEmpty) _StatusBanner(type: _status),
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 420,
                      child: _LeftPanel(
                        tournamentCtrl: _tournamentCtrl,
                        isGroupStage: _isGroupStage,
                        isVisible: _isVisible,
                        groups: _groups,
                        expandedGroup: _expandedGroup,
                        onGroupStageChanged: (v) async {
                          setState(() => _isGroupStage = v);
                          await PointsTableService.setGroupStage(v);
                        },
                        onExpandGroup: (i) =>
                            setState(() => _expandedGroup = i),
                        onAddGroup: _addGroup,
                        onRemoveGroup: _removeGroup,
                        onRenameGroup: _renameGroup,
                        onAddTeam: _addTeam,
                        onRemoveTeam: _removeTeam,
                        onUpdateTeam: _updateTeam,
                        onReorderTeam: _reorderTeam, // ← NEW
                      ),
                    ),
                    Container(width: 1, color: _border),
                    Expanded(
                      child: _PreviewPanel(
                        groups: _groups,
                        isGroupStage: _isGroupStage,
                        tournament: _tournamentCtrl.text,
                        isVisible: _isVisible,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════
//  HEADER
// ════════════════════════════════════════════════════════════
class _Header extends StatelessWidget {
  final bool isVisible, saving;
  final ValueChanged<bool> onToggle;
  final VoidCallback onSave;

  const _Header({
    required this.isVisible,
    required this.saving,
    required this.onToggle,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 72,
      padding: const EdgeInsets.symmetric(horizontal: 28),
      decoration: const BoxDecoration(
          color: _surface, border: Border(bottom: BorderSide(color: _border))),
      child: Row(
        children: [
          const Icon(Icons.table_chart_rounded, color: _textDim, size: 18),
          const SizedBox(width: 12),
          const Text('Points Table',
              style: TextStyle(
                  color: _text, fontSize: 16, fontWeight: FontWeight.w700)),
          const SizedBox(width: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color:
                  isVisible ? Colors.greenAccent.withOpacity(0.08) : _surface2,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                  color: isVisible
                      ? Colors.greenAccent.withOpacity(0.3)
                      : _border),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 5,
                  height: 5,
                  decoration: BoxDecoration(
                    color: isVisible ? Colors.greenAccent : _textMuted,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  isVisible ? 'Visible' : 'Hidden',
                  style: TextStyle(
                      color: isVisible ? Colors.greenAccent : _textDim,
                      fontSize: 11,
                      fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
          const Spacer(),
          _AdminBtn(
              label: isVisible ? 'Hide Table' : 'Show Table',
              onTap: () => onToggle(!isVisible)),
          const SizedBox(width: 10),
          _SaveBtn(saving: saving, onTap: onSave),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════
//  LEFT PANEL
// ════════════════════════════════════════════════════════════
class _LeftPanel extends StatelessWidget {
  final TextEditingController tournamentCtrl;
  final bool isGroupStage, isVisible;
  final List<TableGroup> groups;
  final int expandedGroup;
  final ValueChanged<bool> onGroupStageChanged;
  final ValueChanged<int> onExpandGroup;
  final VoidCallback onAddGroup;
  final ValueChanged<int> onRemoveGroup;
  final void Function(int, String) onRenameGroup;
  final ValueChanged<int> onAddTeam;
  final void Function(int, int) onRemoveTeam;
  final void Function(int, int, TeamStanding) onUpdateTeam;
  final void Function(int, int, int) onReorderTeam; // ← NEW

  const _LeftPanel({
    required this.tournamentCtrl,
    required this.isGroupStage,
    required this.isVisible,
    required this.groups,
    required this.expandedGroup,
    required this.onGroupStageChanged,
    required this.onExpandGroup,
    required this.onAddGroup,
    required this.onRemoveGroup,
    required this.onRenameGroup,
    required this.onAddTeam,
    required this.onRemoveTeam,
    required this.onUpdateTeam,
    required this.onReorderTeam, // ← NEW
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Label('TOURNAMENT'),
          const SizedBox(height: 8),
          _Field(
              ctrl: tournamentCtrl,
              hint: 'e.g. ICC World Cup 2025',
              icon: Icons.emoji_events_rounded),
          const SizedBox(height: 20),
          _ToggleRow(
            label: 'Group Stage Format',
            sublabel: 'Multiple groups (Group A, B…) instead of single table',
            value: isGroupStage,
            onChanged: onGroupStageChanged,
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              _Label(isGroupStage ? 'GROUPS' : 'TEAMS'),
              const Spacer(),
              if (isGroupStage)
                _SmallBtn(label: '+ Add Group', onTap: onAddGroup),
            ],
          ),
          const SizedBox(height: 12),
          ...groups.asMap().entries.map((e) {
            final gIdx = e.key;
            final group = e.value;
            return _GroupAccordion(
              key: ValueKey('group_${gIdx}_${group.groupName}'),
              group: group,
              groupIndex: gIdx,
              isExpanded: expandedGroup == gIdx,
              isGroupStage: isGroupStage,
              canRemove: groups.length > 1,
              onTap: () => onExpandGroup(gIdx),
              onRename: (n) => onRenameGroup(gIdx, n),
              onRemoveGroup: () => onRemoveGroup(gIdx),
              onAddTeam: () => onAddTeam(gIdx),
              onRemoveTeam: (tIdx) => onRemoveTeam(gIdx, tIdx),
              onUpdateTeam: (tIdx, t) => onUpdateTeam(gIdx, tIdx, t),
              onReorderTeam: (oldIdx, newIdx) =>
                  onReorderTeam(gIdx, oldIdx, newIdx), // ← NEW
            );
          }),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════
//  GROUP ACCORDION
// ════════════════════════════════════════════════════════════
class _GroupAccordion extends StatefulWidget {
  final TableGroup group;
  final int groupIndex;
  final bool isExpanded, isGroupStage, canRemove;
  final VoidCallback onTap, onAddTeam, onRemoveGroup;
  final ValueChanged<String> onRename;
  final ValueChanged<int> onRemoveTeam;
  final void Function(int, TeamStanding) onUpdateTeam;
  final void Function(int, int) onReorderTeam; // ← NEW

  const _GroupAccordion({
    super.key,
    required this.group,
    required this.groupIndex,
    required this.isExpanded,
    required this.isGroupStage,
    required this.canRemove,
    required this.onTap,
    required this.onRename,
    required this.onRemoveGroup,
    required this.onAddTeam,
    required this.onRemoveTeam,
    required this.onUpdateTeam,
    required this.onReorderTeam, // ← NEW
  });

  @override
  State<_GroupAccordion> createState() => _GroupAccordionState();
}

class _GroupAccordionState extends State<_GroupAccordion> {
  late TextEditingController _nameCtrl;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.group.groupName);
  }

  @override
  void didUpdateWidget(_GroupAccordion oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.group.groupName != widget.group.groupName &&
        _nameCtrl.text != widget.group.groupName) {
      _nameCtrl.text = widget.group.groupName;
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: widget.isExpanded ? _border2 : _border),
      ),
      child: Column(
        children: [
          // ── Accordion header ──────────────────────────────
          GestureDetector(
            onTap: widget.onTap,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  if (widget.isGroupStage) ...[
                    Expanded(
                      child: TextField(
                        controller: _nameCtrl,
                        onChanged: widget.onRename,
                        style: const TextStyle(
                            color: _text,
                            fontSize: 13,
                            fontWeight: FontWeight.w600),
                        decoration: const InputDecoration(
                          border: InputBorder.none,
                          isDense: true,
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                    ),
                  ] else ...[
                    const Text('Teams',
                        style: TextStyle(
                            color: _text,
                            fontSize: 13,
                            fontWeight: FontWeight.w600)),
                    const Spacer(),
                  ],
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                        color: _surface2,
                        borderRadius: BorderRadius.circular(6)),
                    child: Text('${widget.group.teams.length} teams',
                        style: const TextStyle(
                            color: _textDim,
                            fontSize: 10,
                            fontWeight: FontWeight.w500)),
                  ),
                  if (widget.isGroupStage && widget.canRemove) ...[
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: widget.onRemoveGroup,
                      child: const Icon(Icons.delete_outline_rounded,
                          color: _textDim, size: 16),
                    ),
                  ],
                  const SizedBox(width: 8),
                  Icon(
                    widget.isExpanded
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    color: _textDim,
                    size: 18,
                  ),
                ],
              ),
            ),
          ),

          // ── Expanded body with reorderable team list ──────
          if (widget.isExpanded) ...[
            Container(height: 1, color: _border),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _TeamRowHeader(),
                  const SizedBox(height: 8),

                  // ── ReorderableListView for drag-to-reorder ──
                  if (widget.group.teams.isNotEmpty)
                    ReorderableListView.builder(
                      // Must be shrinkWrap inside a Column/ScrollView
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: widget.group.teams.length,
                      onReorder: widget.onReorderTeam,
                      // Remove the default drag handle from the end
                      buildDefaultDragHandles: false,
                      // Subtle drag feedback styling
                      proxyDecorator: (child, index, animation) {
                        return Material(
                          elevation: 0,
                          color: Colors.transparent,
                          child: Container(
                            decoration: BoxDecoration(
                              color: _surface3,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: _red.withOpacity(0.4)),
                            ),
                            child: child,
                          ),
                        );
                      },
                      itemBuilder: (context, tIdx) {
                        final team = widget.group.teams[tIdx];
                        return _TeamRowEditable(
                          // Key MUST be stable per team identity for reorder to work correctly
                          key: ValueKey(
                              'team_${widget.groupIndex}_${tIdx}_${team.name}'),
                          team: team,
                          index: tIdx,
                          // Pass the reorder index so the drag handle
                          // can register itself with ReorderableListView
                          reorderIndex: tIdx,
                          onUpdate: (t) => widget.onUpdateTeam(tIdx, t),
                          onRemove: () => widget.onRemoveTeam(tIdx),
                        );
                      },
                    ),

                  const SizedBox(height: 10),
                  GestureDetector(
                    onTap: widget.onAddTeam,
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: _border2),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.add_rounded, color: _textDim, size: 14),
                          SizedBox(width: 6),
                          Text('Add Team',
                              style: TextStyle(
                                  color: _textDim,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Team row header ───────────────────────────────────────
class _TeamRowHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // Extra leading space to align with the drag handle
        const SizedBox(width: 20),
        const SizedBox(width: 8),
        const Expanded(
          flex: 3,
          child: Text('Team',
              style: TextStyle(
                  color: _textMuted,
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1)),
        ),
        _ColHead('P'),
        _ColHead('W'),
        _ColHead('L'),
        _ColHead('Pts'),
        _ColHead('NRR'),
        // Space for the remove button + drag handle
        const SizedBox(width: 40),
      ],
    );
  }
}

class _ColHead extends StatelessWidget {
  final String label;
  const _ColHead(this.label);
  @override
  Widget build(BuildContext context) => SizedBox(
        width: 36,
        child: Text(label,
            textAlign: TextAlign.center,
            style: const TextStyle(
                color: _textMuted,
                fontSize: 9,
                fontWeight: FontWeight.w700,
                letterSpacing: 1)),
      );
}

// ════════════════════════════════════════════════════════════
//  TEAM ROW — EDITABLE  (with drag handle)
// ════════════════════════════════════════════════════════════
class _TeamRowEditable extends StatefulWidget {
  final TeamStanding team;
  final int index;
  final int reorderIndex; // ← NEW: index used by ReorderableDragStartListener
  final ValueChanged<TeamStanding> onUpdate;
  final VoidCallback onRemove;

  const _TeamRowEditable({
    super.key,
    required this.team,
    required this.index,
    required this.reorderIndex,
    required this.onUpdate,
    required this.onRemove,
  });

  @override
  State<_TeamRowEditable> createState() => _TeamRowEditableState();
}

class _TeamRowEditableState extends State<_TeamRowEditable> {
  late TextEditingController _name, _logo;
  late TextEditingController _p, _w, _l, _pts, _nrr;

  @override
  void initState() {
    super.initState();
    _init(widget.team);
  }

  void _init(TeamStanding t) {
    _name = TextEditingController(text: t.name);
    _logo = TextEditingController(text: t.logo);
    _p = TextEditingController(text: t.played.toString());
    _w = TextEditingController(text: t.won.toString());
    _l = TextEditingController(text: t.lost.toString());
    _pts = TextEditingController(text: t.points.toString());
    _nrr = TextEditingController(text: t.nrr.toStringAsFixed(3));
  }

  @override
  void dispose() {
    for (final c in [_name, _logo, _p, _w, _l, _pts, _nrr]) {
      c.dispose();
    }
    super.dispose();
  }

  void _emit() {
    widget.onUpdate(TeamStanding(
      name: _name.text.trim(),
      logo: _logo.text.trim(),
      played: int.tryParse(_p.text) ?? 0,
      won: int.tryParse(_w.text) ?? 0,
      lost: int.tryParse(_l.text) ?? 0,
      points: int.tryParse(_pts.text) ?? 0,
      nrr: double.tryParse(_nrr.text) ?? 0.0,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      // No margin bottom here — ReorderableListView handles spacing
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: _surface2,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _border),
      ),
      child: Column(
        children: [
          // ── Row 1: logo + name + logo URL ─────────────────
          Row(
            children: [
              // ── DRAG HANDLE (burger icon) ──────────────────
              // ReorderableDragStartListener wraps only the handle icon.
              // Dragging anywhere else on the row still works for text selection.
              ReorderableDragStartListener(
                index: widget.reorderIndex,
                child: MouseRegion(
                  cursor: SystemMouseCursors.grab,
                  child: Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Icon(
                      Icons.drag_indicator_rounded,
                      color: _textDim,
                      size: 18,
                    ),
                  ),
                ),
              ),

              // Team logo preview circle
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _surface3,
                    border: Border.all(color: _border2)),
                child: ClipOval(
                  child: _logo.text.isNotEmpty
                      ? Image.network(_logo.text,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) =>
                              _LogoFb(name: _name.text))
                      : _LogoFb(name: _name.text),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 3,
                child: _InlineField(
                    ctrl: _name, hint: 'Team name', onChanged: (_) => _emit()),
              ),
              const SizedBox(width: 6),
              Expanded(
                flex: 3,
                child: _InlineField(
                    ctrl: _logo,
                    hint: 'Logo URL',
                    onChanged: (_) => setState(() => _emit())),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // ── Row 2: stats + remove button ──────────────────
          Row(
            children: [
              // Spacer to align under drag handle + logo
              const SizedBox(width: 54),
              _NumField(ctrl: _p, hint: 'P', onChanged: (_) => _emit()),
              _NumField(ctrl: _w, hint: 'W', onChanged: (_) => _emit()),
              _NumField(ctrl: _l, hint: 'L', onChanged: (_) => _emit()),
              _NumField(ctrl: _pts, hint: 'Pts', onChanged: (_) => _emit()),
              _NumField(
                  ctrl: _nrr,
                  hint: 'NRR',
                  onChanged: (_) => _emit(),
                  decimal: true),
              const Spacer(),
              GestureDetector(
                onTap: widget.onRemove,
                child:
                    const Icon(Icons.close_rounded, color: _textDim, size: 16),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════
//  PREVIEW PANEL
// ════════════════════════════════════════════════════════════
class _PreviewPanel extends StatelessWidget {
  final List<TableGroup> groups;
  final bool isGroupStage, isVisible;
  final String tournament;

  const _PreviewPanel({
    required this.groups,
    required this.isGroupStage,
    required this.isVisible,
    required this.tournament,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Label('APP PREVIEW'),
          const SizedBox(height: 16),
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFF0A0A0A),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withOpacity(0.06)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                  child: Row(
                    children: [
                      Container(
                          width: 3,
                          height: 14,
                          margin: const EdgeInsets.only(right: 10),
                          decoration: BoxDecoration(
                              color: _red,
                              borderRadius: BorderRadius.circular(2))),
                      Expanded(
                        child: Text(
                          tournament.isEmpty ? 'Tournament Name' : tournament,
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w700),
                        ),
                      ),
                      if (!isVisible)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.05),
                              borderRadius: BorderRadius.circular(6)),
                          child: const Text('Hidden',
                              style: TextStyle(
                                  color: Colors.white24, fontSize: 9)),
                        ),
                    ],
                  ),
                ),
                ...groups.map((group) => Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (isGroupStage && group.groupName.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                            child: Text(group.groupName.toUpperCase(),
                                style: TextStyle(
                                    color: Colors.white.withOpacity(0.3),
                                    fontSize: 9,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 1.5)),
                          ),
                        _PreviewTableHeader(),
                        Container(
                            height: 1, color: Colors.white.withOpacity(0.05)),
                        if (group.teams.isEmpty)
                          Padding(
                            padding: const EdgeInsets.all(16),
                            child: Text('No teams added yet',
                                style: TextStyle(
                                    color: Colors.white.withOpacity(0.2),
                                    fontSize: 12)),
                          )
                        else
                          ...group.teams.asMap().entries.map((e) =>
                              _PreviewTeamRow(
                                  team: e.value,
                                  position: e.key + 1,
                                  isLast: e.key == group.teams.length - 1)),
                        if (groups.indexOf(group) < groups.length - 1)
                          Container(
                              height: 8, color: Colors.white.withOpacity(0.02)),
                      ],
                    )),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PreviewTableHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          const SizedBox(width: 20),
          const SizedBox(width: 8),
          const Expanded(
            child: Text('Team',
                style: TextStyle(
                    color: Colors.white24,
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1)),
          ),
          ...[' P', ' W', ' L', 'Pts', 'NRR'].map((h) => SizedBox(
                width: 32,
                child: Text(h,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        color: Colors.white24,
                        fontSize: 9,
                        fontWeight: FontWeight.w700)),
              )),
        ],
      ),
    );
  }
}

class _PreviewTeamRow extends StatelessWidget {
  final TeamStanding team;
  final int position;
  final bool isLast;

  const _PreviewTeamRow({
    required this.team,
    required this.position,
    required this.isLast,
  });

  @override
  Widget build(BuildContext context) {
    final isTop = position <= 2;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              SizedBox(
                width: 20,
                child: Text('$position',
                    style: TextStyle(
                        color: isTop ? _red : Colors.white.withOpacity(0.3),
                        fontSize: 10,
                        fontWeight: FontWeight.w700)),
              ),
              const SizedBox(width: 8),
              Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withOpacity(0.06),
                    border: Border.all(color: Colors.white.withOpacity(0.1))),
                child: ClipOval(
                  child: team.logo.isNotEmpty
                      ? Image.network(team.logo,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) =>
                              _LogoFb(name: team.name))
                      : _LogoFb(name: team.name),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(team.name.isEmpty ? '—' : team.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        color: Colors.white.withOpacity(isTop ? 0.9 : 0.6),
                        fontSize: 11,
                        fontWeight: isTop ? FontWeight.w700 : FontWeight.w500)),
              ),
              ...[
                team.played.toString(),
                team.won.toString(),
                team.lost.toString(),
                team.points.toString(),
                team.nrr >= 0
                    ? '+${team.nrr.toStringAsFixed(3)}'
                    : team.nrr.toStringAsFixed(3),
              ].map((v) => SizedBox(
                    width: 32,
                    child: Text(v,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            color: Colors.white.withOpacity(0.5),
                            fontSize: 10,
                            fontWeight: FontWeight.w600)),
                  )),
            ],
          ),
        ),
        if (!isLast)
          Container(height: 1, color: Colors.white.withOpacity(0.04)),
      ],
    );
  }
}

// ════════════════════════════════════════════════════════════
//  SHARED WIDGETS
// ════════════════════════════════════════════════════════════
class _Label extends StatelessWidget {
  final String text;
  const _Label(this.text);
  @override
  Widget build(BuildContext context) => Text(text,
      style: const TextStyle(
          color: _textDim,
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.5));
}

class _Field extends StatelessWidget {
  final TextEditingController ctrl;
  final String hint;
  final IconData? icon;
  const _Field({required this.ctrl, required this.hint, this.icon});

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: ctrl,
      style: const TextStyle(color: _text, fontSize: 13),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: _textMuted, fontSize: 13),
        prefixIcon:
            icon != null ? Icon(icon, color: _textMuted, size: 16) : null,
        filled: true,
        fillColor: _surface2,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: _border)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: _border)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: _red.withOpacity(0.5))),
      ),
    );
  }
}

class _InlineField extends StatelessWidget {
  final TextEditingController ctrl;
  final String hint;
  final ValueChanged<String> onChanged;

  const _InlineField(
      {required this.ctrl, required this.hint, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: ctrl,
      onChanged: onChanged,
      style: const TextStyle(color: _text, fontSize: 12),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: _textMuted, fontSize: 12),
        filled: true,
        fillColor: _surface3,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(7),
            borderSide: const BorderSide(color: _border)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(7),
            borderSide: const BorderSide(color: _border)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(7),
            borderSide: BorderSide(color: _red.withOpacity(0.4))),
      ),
    );
  }
}

class _NumField extends StatelessWidget {
  final TextEditingController ctrl;
  final String hint;
  final ValueChanged<String> onChanged;
  final bool decimal;

  const _NumField({
    required this.ctrl,
    required this.hint,
    required this.onChanged,
    this.decimal = false,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 36,
      child: TextField(
        controller: ctrl,
        onChanged: onChanged,
        textAlign: TextAlign.center,
        keyboardType: decimal
            ? const TextInputType.numberWithOptions(decimal: true, signed: true)
            : TextInputType.number,
        inputFormatters: decimal
            ? [FilteringTextInputFormatter.allow(RegExp(r'^-?\d*\.?\d*'))]
            : [FilteringTextInputFormatter.digitsOnly],
        style: const TextStyle(color: _text, fontSize: 11),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(color: _textMuted, fontSize: 10),
          filled: true,
          fillColor: _surface3,
          isDense: true,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 4, vertical: 7),
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6),
              borderSide: const BorderSide(color: _border)),
          enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6),
              borderSide: const BorderSide(color: _border)),
          focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6),
              borderSide: BorderSide(color: _red.withOpacity(0.4))),
        ),
      ),
    );
  }
}

class _ToggleRow extends StatelessWidget {
  final String label, sublabel;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _ToggleRow({
    required this.label,
    required this.sublabel,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: _surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _border)),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: const TextStyle(
                        color: _text,
                        fontSize: 13,
                        fontWeight: FontWeight.w600)),
                const SizedBox(height: 3),
                Text(sublabel,
                    style: const TextStyle(color: _textDim, fontSize: 11)),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: _red,
            trackColor: MaterialStateProperty.resolveWith((s) =>
                s.contains(MaterialState.selected)
                    ? _red.withOpacity(0.3)
                    : _surface2),
          ),
        ],
      ),
    );
  }
}

class _StatusBanner extends StatelessWidget {
  final String type;
  const _StatusBanner({required this.type});

  @override
  Widget build(BuildContext context) {
    final ok = type == 'success';
    final color = ok ? Colors.greenAccent : Colors.redAccent;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
      color: color.withOpacity(0.08),
      child: Text(
        ok ? 'Saved successfully ✓' : 'Error — check all fields',
        style:
            TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _AdminBtn extends StatefulWidget {
  final String label;
  final VoidCallback onTap;
  const _AdminBtn({required this.label, required this.onTap});
  @override
  State<_AdminBtn> createState() => _AdminBtnState();
}

class _AdminBtnState extends State<_AdminBtn> {
  bool _h = false;
  @override
  Widget build(BuildContext context) => MouseRegion(
        onEnter: (_) => setState(() => _h = true),
        onExit: (_) => setState(() => _h = false),
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 130),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: _h ? _surface3 : _surface2,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: _h ? _border2 : _border),
            ),
            child: Text(widget.label,
                style: const TextStyle(
                    color: _text, fontSize: 12, fontWeight: FontWeight.w600)),
          ),
        ),
      );
}

class _SmallBtn extends StatefulWidget {
  final String label;
  final VoidCallback onTap;
  const _SmallBtn({required this.label, required this.onTap});
  @override
  State<_SmallBtn> createState() => _SmallBtnState();
}

class _SmallBtnState extends State<_SmallBtn> {
  bool _h = false;
  @override
  Widget build(BuildContext context) => MouseRegion(
        onEnter: (_) => setState(() => _h = true),
        onExit: (_) => setState(() => _h = false),
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 130),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: _h ? _red.withOpacity(0.12) : Colors.transparent,
              borderRadius: BorderRadius.circular(7),
              border: Border.all(color: _h ? _red.withOpacity(0.4) : _border),
            ),
            child: Text(widget.label,
                style: TextStyle(
                    color: _h ? _red : _textDim,
                    fontSize: 11,
                    fontWeight: FontWeight.w600)),
          ),
        ),
      );
}

class _SaveBtn extends StatefulWidget {
  final bool saving;
  final VoidCallback onTap;
  const _SaveBtn({required this.saving, required this.onTap});
  @override
  State<_SaveBtn> createState() => _SaveBtnState();
}

class _SaveBtnState extends State<_SaveBtn> {
  bool _h = false;
  @override
  Widget build(BuildContext context) => MouseRegion(
        onEnter: (_) => setState(() => _h = true),
        onExit: (_) => setState(() => _h = false),
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: widget.saving ? null : widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 130),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
            decoration: BoxDecoration(
              color: _h ? _red.withOpacity(0.85) : _red,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (widget.saving)
                  const SizedBox(
                    width: 12,
                    height: 12,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 1.5),
                  )
                else
                  const Icon(Icons.save_rounded, color: Colors.white, size: 15),
                const SizedBox(width: 7),
                Text(widget.saving ? 'Saving…' : 'Save & Publish',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w700)),
              ],
            ),
          ),
        ),
      );
}

class _LogoFb extends StatelessWidget {
  final String name;
  const _LogoFb({required this.name});
  @override
  Widget build(BuildContext context) => Container(
        color: Colors.white.withOpacity(0.05),
        child: Center(
          child: Text(
            name.isNotEmpty ? name[0].toUpperCase() : '?',
            style: const TextStyle(
                color: Colors.white38,
                fontSize: 8,
                fontWeight: FontWeight.w800),
          ),
        ),
      );
}
