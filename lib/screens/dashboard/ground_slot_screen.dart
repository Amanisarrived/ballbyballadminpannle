import 'package:cricket_admin/services/cricspot_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

// ─────────────────────────────────────────────────────────────
//  GROUND SLOTS SCREEN — Manual slot management
// ─────────────────────────────────────────────────────────────

class GroundSlotsScreen extends StatefulWidget {
  final CricGround ground;
  const GroundSlotsScreen({super.key, required this.ground});

  @override
  State<GroundSlotsScreen> createState() => _GroundSlotsScreenState();
}

class _GroundSlotsScreenState extends State<GroundSlotsScreen> {
  static const _bg = Color(0xFF0D0D0D);
  static const _surface = Color(0xFF141414);
  static const _border = Color(0xFF232323);
  static const _red = Color(0xFFCC0000);

  DateTime _selectedDate = DateTime.now();

  String get _dateKey => DateFormat('yyyy-MM-dd').format(_selectedDate);

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 60)),
      builder: (ctx, child) => Theme(
        data: ThemeData.dark()
            .copyWith(colorScheme: const ColorScheme.dark(primary: _red)),
        child: child!,
      ),
    );
    if (picked != null && mounted) {
      setState(() => _selectedDate = picked);
    }
  }

  void _showAddSlotDialog() {
    showDialog(
      context: context,
      builder: (_) => _AddSlotDialog(
        groundId: widget.ground.id,
        date: _dateKey,
      ),
    );
  }

  Future<void> _toggleStatus(CricSlot slot) async {
    await CricSpotAdminService.toggleSlotStatus(
      groundId: widget.ground.id,
      date: _dateKey,
      startTime: slot.startTime,
      currentStatus: slot.status,
    );
  }

  Future<void> _deleteSlot(CricSlot slot) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Text('Delete Slot?',
            style: TextStyle(color: Colors.white, fontSize: 16)),
        content: Text('${slot.startTime} → ${slot.endTime} will be deleted.',
            style: const TextStyle(color: Colors.white54, fontSize: 13)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child:
                const Text('Cancel', style: TextStyle(color: Colors.white38)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete',
                style: TextStyle(color: _red, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
    if (ok == true) {
      await CricSpotAdminService.deleteSlot(
        groundId: widget.ground.id,
        date: _dateKey,
        startTime: slot.startTime,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _surface,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Manage Slots',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w700)),
            Text(widget.ground.name,
                style: TextStyle(
                    color: Colors.white.withAlpha(100), fontSize: 11)),
          ],
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: _border),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: TextButton.icon(
              onPressed: _showAddSlotDialog,
              icon: const Icon(Icons.add_rounded, color: _red, size: 18),
              label: const Text('Add Slot',
                  style: TextStyle(color: _red, fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ),
      body: Column(children: [
        // ── Date picker ───────────────────────────────────
        Container(
          padding: const EdgeInsets.all(16),
          color: _surface,
          child: GestureDetector(
            onTap: _pickDate,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: _bg,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: _border),
              ),
              child: Row(children: [
                const Icon(Icons.calendar_today_rounded, color: _red, size: 16),
                const SizedBox(width: 10),
                Text(
                  DateFormat('EEEE, dd MMMM yyyy').format(_selectedDate),
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w600),
                ),
                const Spacer(),
                const Icon(Icons.chevron_right_rounded,
                    color: Colors.white38, size: 18),
              ]),
            ),
          ),
        ),

        // ── Legend ───────────────────────────────────────
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(children: [
            _LegendDot(color: const Color(0xFF4CAF50), label: 'Available'),
            const SizedBox(width: 16),
            _LegendDot(color: _red, label: 'Booked'),
            const Spacer(),
            Text('Tap status to toggle',
                style:
                    TextStyle(color: Colors.white.withAlpha(40), fontSize: 10)),
          ]),
        ),

        Container(height: 1, color: _border),

        // ── Slots list ────────────────────────────────────
        Expanded(
          child: StreamBuilder<List<CricSlot>>(
            stream: CricSpotAdminService.slotsStream(
              groundId: widget.ground.id,
              date: _dateKey,
            ),
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Center(
                    child: CircularProgressIndicator(
                        color: _red, strokeWidth: 1.5));
              }

              final slots = snap.data ?? [];

              if (slots.isEmpty) {
                return _NoSlotsState(onAdd: _showAddSlotDialog);
              }

              return ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: slots.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (_, i) => _SlotTile(
                  slot: slots[i],
                  onToggle: () => _toggleStatus(slots[i]),
                  onDelete: () => _deleteSlot(slots[i]),
                ),
              );
            },
          ),
        ),
      ]),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: _red,
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: const Text('Add Slot',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
        onPressed: _showAddSlotDialog,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  SLOT TILE
// ─────────────────────────────────────────────────────────────

class _SlotTile extends StatelessWidget {
  final CricSlot slot;
  final VoidCallback onToggle;
  final VoidCallback onDelete;

  const _SlotTile({
    required this.slot,
    required this.onToggle,
    required this.onDelete,
  });

  static const _surface = Color(0xFF141414);
  static const _border = Color(0xFF232323);
  static const _red = Color(0xFFCC0000);
  static const _green = Color(0xFF4CAF50);

  @override
  Widget build(BuildContext context) {
    final isAvailable = slot.isAvailable;
    final statusColor = isAvailable ? _green : _red;

    return Container(
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _border),
      ),
      child: Row(children: [
        // ── Time block ────────────────────────────────
        Container(
          width: 100,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            color: statusColor.withAlpha(15),
            borderRadius:
                const BorderRadius.horizontal(left: Radius.circular(11)),
            border: Border(right: BorderSide(color: _border)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(slot.startTime,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5)),
              Text('→ ${slot.endTime}',
                  style: TextStyle(
                      color: Colors.white.withAlpha(80), fontSize: 11)),
            ],
          ),
        ),

        // ── Info ──────────────────────────────────────
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(slot.rateDisplay,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                // Status toggle
                GestureDetector(
                  onTap: onToggle,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusColor.withAlpha(20),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: statusColor.withAlpha(60)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                              color: statusColor, shape: BoxShape.circle),
                        ),
                        const SizedBox(width: 5),
                        Text(
                          isAvailable ? 'Available' : 'Booked',
                          style: TextStyle(
                              color: statusColor,
                              fontSize: 11,
                              fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(width: 4),
                        Icon(Icons.swap_horiz_rounded,
                            color: statusColor.withAlpha(160), size: 12),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        // ── Delete ────────────────────────────────────
        GestureDetector(
          onTap: onDelete,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Icon(Icons.delete_outline_rounded,
                color: Colors.white.withAlpha(40), size: 18),
          ),
        ),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  ADD SLOT DIALOG
// ─────────────────────────────────────────────────────────────

class _AddSlotDialog extends StatefulWidget {
  final String groundId;
  final String date;

  const _AddSlotDialog({
    required this.groundId,
    required this.date,
  });

  @override
  State<_AddSlotDialog> createState() => _AddSlotDialogState();
}

class _AddSlotDialogState extends State<_AddSlotDialog> {
  static const _red = Color(0xFFCC0000);

  String _startTime = '06:00';
  String _endTime = '07:00';
  final _rateCtrl = TextEditingController();
  final _rateDispCtrl = TextEditingController();
  String _status = 'available';
  bool _saving = false;

  @override
  void dispose() {
    _rateCtrl.dispose();
    _rateDispCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickTime(bool isStart) async {
    final current = isStart ? _startTime : _endTime;
    final parts = current.split(':');
    final initial =
        TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));

    final picked = await showTimePicker(
      context: context,
      initialTime: initial,
      builder: (ctx, child) => Theme(
        data: ThemeData.dark()
            .copyWith(colorScheme: const ColorScheme.dark(primary: _red)),
        child: child!,
      ),
    );
    if (picked == null || !mounted) return;
    final formatted =
        '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
    setState(() {
      if (isStart)
        _startTime = formatted;
      else
        _endTime = formatted;
    });
  }

  Future<void> _save() async {
    if (_rateCtrl.text.trim().isEmpty || _rateDispCtrl.text.trim().isEmpty) {
      return;
    }
    setState(() => _saving = true);
    try {
      await CricSpotAdminService.addSlot(
        groundId: widget.groundId,
        date: widget.date,
        startTime: _startTime,
        endTime: _endTime,
        rate: int.tryParse(_rateCtrl.text.trim()) ?? 0,
        rateDisplay: _rateDispCtrl.text.trim(),
        status: _status,
      );
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Failed: $e'),
          backgroundColor: Colors.red,
        ));
      }
    }
    if (mounted) setState(() => _saving = false);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF141414),
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: Color(0xFF232323))),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Title
            const Row(children: [
              Icon(Icons.schedule_rounded, color: _red, size: 18),
              SizedBox(width: 10),
              Text('Add Slot',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w700)),
            ]),
            const SizedBox(height: 20),

            // Time pickers
            Row(children: [
              Expanded(
                  child: _TimePickBtn(
                label: 'Start Time',
                value: _startTime,
                onTap: () => _pickTime(true),
              )),
              const SizedBox(width: 12),
              Expanded(
                  child: _TimePickBtn(
                label: 'End Time',
                value: _endTime,
                onTap: () => _pickTime(false),
              )),
            ]),
            const SizedBox(height: 14),

            // Rate
            _DialogField(
              ctrl: _rateCtrl,
              label: 'Rate (₹)',
              hint: '800',
              keyboardType: TextInputType.number,
            ),
            _DialogField(
              ctrl: _rateDispCtrl,
              label: 'Rate Display',
              hint: '₹800/hr  or  ₹400/half hr',
            ),
            const SizedBox(height: 14),

            // Status
            Row(children: [
              _StatusChip(
                label: 'Available',
                selected: _status == 'available',
                color: const Color(0xFF4CAF50),
                onTap: () => setState(() => _status = 'available'),
              ),
              const SizedBox(width: 10),
              _StatusChip(
                label: 'Booked',
                selected: _status == 'booked',
                color: _red,
                onTap: () => setState(() => _status = 'booked'),
              ),
            ]),
            const SizedBox(height: 20),

            // Buttons
            Row(children: [
              Expanded(
                  child: GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.white.withAlpha(20)),
                  ),
                  child: const Center(
                      child: Text('Cancel',
                          style:
                              TextStyle(color: Colors.white54, fontSize: 13))),
                ),
              )),
              const SizedBox(width: 12),
              Expanded(
                  child: GestureDetector(
                onTap: _saving ? null : _save,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: _saving ? _red.withAlpha(100) : _red,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: _saving
                      ? const Center(
                          child: SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white)))
                      : const Center(
                          child: Text('Add Slot',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700))),
                ),
              )),
            ]),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  SMALL WIDGETS
// ─────────────────────────────────────────────────────────────

class _TimePickBtn extends StatelessWidget {
  final String label, value;
  final VoidCallback onTap;
  const _TimePickBtn(
      {required this.label, required this.value, required this.onTap});

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: TextStyle(
                  color: Colors.white.withAlpha(120),
                  fontSize: 11,
                  fontWeight: FontWeight.w500)),
          const SizedBox(height: 5),
          GestureDetector(
            onTap: onTap,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
              decoration: BoxDecoration(
                color: const Color(0xFF0D0D0D),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFF232323)),
              ),
              child: Row(children: [
                const Icon(Icons.schedule_rounded,
                    color: Color(0xFFCC0000), size: 14),
                const SizedBox(width: 8),
                Text(value,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w700)),
              ]),
            ),
          ),
        ],
      );
}

class _DialogField extends StatelessWidget {
  final TextEditingController ctrl;
  final String label, hint;
  final TextInputType keyboardType;
  const _DialogField(
      {required this.ctrl,
      required this.label,
      required this.hint,
      this.keyboardType = TextInputType.text});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: TextStyle(
                    color: Colors.white.withAlpha(120),
                    fontSize: 11,
                    fontWeight: FontWeight.w500)),
            const SizedBox(height: 5),
            TextField(
              controller: ctrl,
              keyboardType: keyboardType,
              style: const TextStyle(color: Colors.white, fontSize: 13),
              decoration: InputDecoration(
                hintText: hint,
                hintStyle:
                    TextStyle(color: Colors.white.withAlpha(40), fontSize: 13),
                filled: true,
                fillColor: const Color(0xFF0D0D0D),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Color(0xFF232323))),
                enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Color(0xFF232323))),
                focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Color(0xFFCC0000))),
              ),
            ),
          ],
        ),
      );
}

class _StatusChip extends StatelessWidget {
  final String label;
  final bool selected;
  final Color color;
  final VoidCallback onTap;
  const _StatusChip(
      {required this.label,
      required this.selected,
      required this.color,
      required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
          decoration: BoxDecoration(
            color: selected ? color.withAlpha(20) : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
                color: selected
                    ? color.withAlpha(80)
                    : Colors.white.withAlpha(20)),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            if (selected) Icon(Icons.check_rounded, color: color, size: 13),
            if (selected) const SizedBox(width: 5),
            Text(label,
                style: TextStyle(
                    color: selected ? color : Colors.white38,
                    fontSize: 12,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w400)),
          ]),
        ),
      );
}

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;
  const _LegendDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) => Row(children: [
        Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 5),
        Text(label,
            style: TextStyle(color: Colors.white.withAlpha(120), fontSize: 11)),
      ]);
}

class _NoSlotsState extends StatelessWidget {
  final VoidCallback onAdd;
  const _NoSlotsState({required this.onAdd});

  @override
  Widget build(BuildContext context) => Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('📅', style: TextStyle(fontSize: 48)),
          const SizedBox(height: 16),
          const Text('No slots for this date',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          const Text('Add slots manually using\nthe button below',
              style:
                  TextStyle(color: Colors.white38, fontSize: 13, height: 1.5),
              textAlign: TextAlign.center),
          const SizedBox(height: 20),
          GestureDetector(
            onTap: onAdd,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 11),
              decoration: BoxDecoration(
                color: const Color(0xFFCC0000),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.add_rounded, color: Colors.white, size: 16),
                  SizedBox(width: 6),
                  Text('Add First Slot',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w700)),
                ],
              ),
            ),
          ),
        ]),
      );
}
