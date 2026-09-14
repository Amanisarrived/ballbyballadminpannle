import 'package:cricket_admin/services/cricspot_service.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

// ─────────────────────────────────────────────────────────────
//  TOURNAMENT FORM SCREEN — Add / Edit
// ─────────────────────────────────────────────────────────────

class TournamentFormScreen extends StatefulWidget {
  final CricTournament? tournament;
  const TournamentFormScreen({super.key, this.tournament});

  @override
  State<TournamentFormScreen> createState() => _TournamentFormScreenState();
}

class _TournamentFormScreenState extends State<TournamentFormScreen> {
  static const _bg = Color(0xFF0D0D0D);
  static const _surface = Color(0xFF141414);
  static const _border = Color(0xFF232323);
  static const _red = Color(0xFFCC0000);

  final _formKey = GlobalKey<FormState>();
  bool _saving = false;
  bool get _isEdit => widget.tournament != null;

  // ── Controllers ──────────────────────────────────────────
  late final TextEditingController _name;
  late final TextEditingController _area;
  late final TextEditingController _city;
  late final TextEditingController _state;
  late final TextEditingController _venue;
  late final TextEditingController _address;
  late final TextEditingController _entryFee;
  late final TextEditingController _entryFeeDisplay;
  late final TextEditingController _prize;
  late final TextEditingController _prizeAmount;
  late final TextEditingController _teamSize;
  late final TextEditingController _totalSlots;
  late final TextEditingController _phone;
  late final TextEditingController _whatsapp;
  late final TextEditingController _website;
  late final TextEditingController _description;
  late final TextEditingController _rules;

  // ── State ────────────────────────────────────────────────
  String _format = 'Box Cricket';
  String _status = 'upcoming';
  bool _isActive = true;
  bool _isPremium = false;
  DateTime? _startDate;
  DateTime? _endDate;
  DateTime? _lastRegDate;

  static const _formats = ['Box Cricket', 'T20', 'T10', 'T5', 'ODI'];

  @override
  void initState() {
    super.initState();
    final t = widget.tournament;
    _name = TextEditingController(text: t?.name ?? '');
    _area = TextEditingController(text: t?.area ?? '');
    _city = TextEditingController(text: t?.city ?? 'Delhi');
    _state = TextEditingController(text: t?.state ?? 'Delhi');
    _venue = TextEditingController(text: t?.venue ?? '');
    _address = TextEditingController(text: t?.address ?? '');
    _entryFee =
        TextEditingController(text: t != null ? t.entryFee.toString() : '');
    _entryFeeDisplay = TextEditingController(text: t?.entryFeeDisplay ?? '');
    _prize = TextEditingController(text: t?.prize ?? '');
    _prizeAmount =
        TextEditingController(text: t != null ? t.prizeAmount.toString() : '');
    _teamSize =
        TextEditingController(text: t != null ? t.teamSize.toString() : '6');
    _totalSlots =
        TextEditingController(text: t != null ? t.totalSlots.toString() : '16');
    _phone = TextEditingController(text: t?.phone ?? '');
    _whatsapp = TextEditingController(text: t?.whatsapp ?? '');
    _website = TextEditingController(text: t?.website ?? '');
    _description = TextEditingController(text: t?.description ?? '');
    _rules = TextEditingController(text: t?.rules ?? '');

    if (t != null) {
      _format = t.format;
      _status = t.status;
      _isActive = t.isActive;
      _isPremium = t.isPremium;
      _startDate = t.startDate;
      _endDate = t.endDate;
      _lastRegDate = t.lastRegDate;
    }
  }

  @override
  void dispose() {
    for (final c in [
      _name,
      _area,
      _city,
      _state,
      _venue,
      _address,
      _entryFee,
      _entryFeeDisplay,
      _prize,
      _prizeAmount,
      _teamSize,
      _totalSlots,
      _phone,
      _whatsapp,
      _website,
      _description,
      _rules
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _pickDate(String which) async {
    final initial = switch (which) {
      'start' => _startDate ?? DateTime.now(),
      'end' => _endDate ?? DateTime.now().add(const Duration(days: 3)),
      _ => _lastRegDate ?? DateTime.now(),
    };

    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime.now().subtract(const Duration(days: 30)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (ctx, child) => Theme(
        data: ThemeData.dark()
            .copyWith(colorScheme: const ColorScheme.dark(primary: _red)),
        child: child!,
      ),
    );
    if (picked == null || !mounted) return;
    setState(() {
      switch (which) {
        case 'start':
          _startDate = picked;
        case 'end':
          _endDate = picked;
        default:
          _lastRegDate = picked;
      }
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_startDate == null || _endDate == null || _lastRegDate == null) {
      _showSnack('Please set all dates', isError: true);
      return;
    }
    setState(() => _saving = true);
    try {
      await CricSpotAdminService.saveTournament(
        existingId: _isEdit ? widget.tournament!.id : null,
        name: _name.text.trim(),
        format: _format,
        area: _area.text.trim(),
        city: _city.text.trim(),
        state: _state.text.trim(),
        venue: _venue.text.trim(),
        address: _address.text.trim(),
        startDate: _startDate!,
        endDate: _endDate!,
        lastRegDate: _lastRegDate!,
        entryFee: int.tryParse(_entryFee.text.trim()) ?? 0,
        entryFeeDisplay: _entryFeeDisplay.text.trim(),
        prize: _prize.text.trim(),
        prizeAmount: int.tryParse(_prizeAmount.text.trim()) ?? 0,
        teamSize: int.tryParse(_teamSize.text.trim()) ?? 6,
        totalSlots: int.tryParse(_totalSlots.text.trim()) ?? 16,
        phone: _phone.text.trim(),
        whatsapp: _whatsapp.text.trim(),
        website: _website.text.trim(),
        status: _status,
        isActive: _isActive,
        isPremium: _isPremium,
        description: _description.text.trim(),
        rules: _rules.text.trim(),
      );
      if (mounted) {
        _showSnack(
            _isEdit ? '${_name.text} updated ✓' : '${_name.text} added ✓');
        await Future.delayed(const Duration(milliseconds: 600));
        if (mounted) Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) _showSnack('Failed: $e', isError: true);
    }
    if (mounted) setState(() => _saving = false);
  }

  void _showSnack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(
        content: Text(msg, style: const TextStyle(color: Colors.white)),
        backgroundColor:
            isError ? const Color(0xFFB71C1C) : const Color(0xFF2E7D32),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        duration: const Duration(seconds: 2),
      ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _surface,
        elevation: 0,
        title: Text(
          _isEdit ? 'Edit Tournament' : 'Add Tournament',
          style: const TextStyle(
              color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: _border),
        ),
      ),
      body: Form(
        key: _formKey,
        child: Column(children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // ── Basic Info ────────────────────────────
                _SectionLabel('Basic Info'),
                const SizedBox(height: 10),
                _Field(
                    ctrl: _name,
                    label: 'Tournament Name *',
                    hint: 'Rohini Premier League 2026'),
                _DropdownField<String>(
                  label: 'Format *',
                  value: _format,
                  items: {for (final f in _formats) f: f},
                  onChanged: (v) => setState(() => _format = v!),
                ),
                Row(children: [
                  Expanded(
                      child:
                          _Field(ctrl: _area, label: 'Area *', hint: 'Rohini')),
                  const SizedBox(width: 10),
                  Expanded(
                      child:
                          _Field(ctrl: _city, label: 'City *', hint: 'Delhi')),
                ]),
                _Field(
                    ctrl: _venue,
                    label: 'Venue Name *',
                    hint: 'Box Cricket Arena, Rohini'),
                _Field(
                    ctrl: _address,
                    label: 'Address',
                    hint: 'Sector 7, Rohini',
                    required: false,
                    maxLines: 2),

                const SizedBox(height: 20),

                // ── Dates ─────────────────────────────────
                _SectionLabel('Dates'),
                const SizedBox(height: 10),
                _DatePicker(
                  label: 'Start Date *',
                  value: _startDate,
                  onTap: () => _pickDate('start'),
                ),
                _DatePicker(
                  label: 'End Date *',
                  value: _endDate,
                  onTap: () => _pickDate('end'),
                ),
                _DatePicker(
                  label: 'Last Registration Date *',
                  value: _lastRegDate,
                  onTap: () => _pickDate('reg'),
                ),

                const SizedBox(height: 20),

                // ── Entry & Prize ─────────────────────────
                _SectionLabel('Entry & Prize'),
                const SizedBox(height: 10),
                Row(children: [
                  Expanded(
                      child: _Field(
                          ctrl: _entryFee,
                          label: 'Entry Fee (₹) *',
                          hint: '500',
                          keyboardType: TextInputType.number)),
                  const SizedBox(width: 10),
                  Expanded(
                      child: _Field(
                          ctrl: _entryFeeDisplay,
                          label: 'Display Text *',
                          hint: '₹500/team')),
                ]),
                _Field(
                    ctrl: _prize,
                    label: 'Prize *',
                    hint: '₹10,000 cash + Trophy'),
                _Field(
                    ctrl: _prizeAmount,
                    label: 'Prize Amount (₹)',
                    hint: '10000',
                    required: false,
                    keyboardType: TextInputType.number),

                const SizedBox(height: 20),

                // ── Teams ─────────────────────────────────
                _SectionLabel('Teams'),
                const SizedBox(height: 10),
                Row(children: [
                  Expanded(
                      child: _Field(
                          ctrl: _teamSize,
                          label: 'Players per Team *',
                          hint: '6',
                          keyboardType: TextInputType.number)),
                  const SizedBox(width: 10),
                  Expanded(
                      child: _Field(
                          ctrl: _totalSlots,
                          label: 'Max Teams *',
                          hint: '16',
                          keyboardType: TextInputType.number)),
                ]),

                const SizedBox(height: 20),

                // ── Contact ───────────────────────────────
                _SectionLabel('Contact'),
                const SizedBox(height: 10),
                _Field(
                    ctrl: _phone,
                    label: 'Phone *',
                    hint: '+919876543210',
                    keyboardType: TextInputType.phone),
                _Field(
                    ctrl: _whatsapp,
                    label: 'WhatsApp',
                    hint: '+919876543210',
                    required: false,
                    keyboardType: TextInputType.phone),
                _Field(
                    ctrl: _website,
                    label: 'Website',
                    hint: 'https://...',
                    required: false),

                const SizedBox(height: 20),

                // ── Details ───────────────────────────────
                _SectionLabel('Details (Optional)'),
                const SizedBox(height: 10),
                _Field(
                    ctrl: _description,
                    label: 'Description',
                    hint: 'Annual box cricket tournament...',
                    required: false,
                    maxLines: 3),
                _Field(
                    ctrl: _rules,
                    label: 'Rules',
                    hint: 'No ball limit 3 per over...',
                    required: false,
                    maxLines: 3),

                const SizedBox(height: 20),

                // ── Settings ──────────────────────────────
                _SectionLabel('Settings'),
                const SizedBox(height: 10),
                _Toggle(
                  label: 'Active',
                  subtitle: 'Show in app',
                  value: _isActive,
                  onChanged: (v) => setState(() => _isActive = v),
                ),
                const SizedBox(height: 8),
                _Toggle(
                  label: 'Premium',
                  subtitle: 'Featured at top',
                  value: _isPremium,
                  onChanged: (v) => setState(() => _isPremium = v),
                ),

                const SizedBox(height: 32),
              ],
            ),
          ),

          // ── Save button ───────────────────────────────
          Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            decoration: BoxDecoration(
              color: _surface,
              border: Border(top: BorderSide(color: _border)),
            ),
            child: GestureDetector(
              onTap: _saving ? null : _save,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: _saving ? _red.withAlpha(100) : _red,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                        color: _red.withAlpha(60),
                        blurRadius: 16,
                        offset: const Offset(0, 4))
                  ],
                ),
                child: _saving
                    ? const Center(
                        child: SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white)))
                    : Text(_isEdit ? 'Update Tournament' : 'Add Tournament',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w700)),
              ),
            ),
          ),
        ]),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  SHARED FORM WIDGETS
// ─────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel(this.label);

  @override
  Widget build(BuildContext context) => Row(children: [
        Container(
            width: 3,
            height: 14,
            decoration: BoxDecoration(
                color: const Color(0xFFCC0000),
                borderRadius: BorderRadius.circular(2))),
        const SizedBox(width: 8),
        Text(label,
            style: TextStyle(
                color: Colors.white.withAlpha(200),
                fontSize: 13,
                fontWeight: FontWeight.w700)),
      ]);
}

class _Field extends StatelessWidget {
  final TextEditingController ctrl;
  final String label, hint;
  final bool required;
  final int maxLines;
  final TextInputType keyboardType;

  const _Field({
    required this.ctrl,
    required this.label,
    required this.hint,
    this.required = true,
    this.maxLines = 1,
    this.keyboardType = TextInputType.text,
  });

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: TextStyle(
                    color: Colors.white.withAlpha(140),
                    fontSize: 11,
                    fontWeight: FontWeight.w500)),
            const SizedBox(height: 5),
            TextFormField(
              controller: ctrl,
              keyboardType: keyboardType,
              maxLines: maxLines,
              style: const TextStyle(color: Colors.white, fontSize: 13),
              validator: required
                  ? (v) => (v == null || v.trim().isEmpty) ? 'Required' : null
                  : null,
              decoration: InputDecoration(
                hintText: hint,
                hintStyle:
                    TextStyle(color: Colors.white.withAlpha(40), fontSize: 13),
                filled: true,
                fillColor: const Color(0xFF141414),
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
                errorBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Colors.redAccent)),
                focusedErrorBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Colors.redAccent)),
              ),
            ),
          ],
        ),
      );
}

class _DropdownField<T> extends StatelessWidget {
  final String label;
  final T value;
  final Map<T, String> items;
  final ValueChanged<T?> onChanged;

  const _DropdownField({
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: TextStyle(
                    color: Colors.white.withAlpha(140),
                    fontSize: 11,
                    fontWeight: FontWeight.w500)),
            const SizedBox(height: 5),
            Container(
              height: 42,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: const Color(0xFF141414),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFF232323)),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<T>(
                  value: value,
                  isExpanded: true,
                  dropdownColor: const Color(0xFF1A1A1A),
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                  items: items.entries
                      .map((e) =>
                          DropdownMenuItem(value: e.key, child: Text(e.value)))
                      .toList(),
                  onChanged: onChanged,
                ),
              ),
            ),
          ],
        ),
      );
}

class _DatePicker extends StatelessWidget {
  final String label;
  final DateTime? value;
  final VoidCallback onTap;

  const _DatePicker({
    required this.label,
    required this.value,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: TextStyle(
                    color: Colors.white.withAlpha(140),
                    fontSize: 11,
                    fontWeight: FontWeight.w500)),
            const SizedBox(height: 5),
            GestureDetector(
              onTap: onTap,
              child: Container(
                height: 42,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFF141414),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: value != null
                        ? const Color(0xFFCC0000).withAlpha(80)
                        : const Color(0xFF232323),
                  ),
                ),
                child: Row(children: [
                  Icon(Icons.calendar_today_rounded,
                      color: value != null
                          ? const Color(0xFFCC0000)
                          : Colors.white38,
                      size: 16),
                  const SizedBox(width: 10),
                  Text(
                    value != null
                        ? DateFormat('dd MMM yyyy').format(value!)
                        : 'Select date',
                    style: TextStyle(
                      color: value != null ? Colors.white : Colors.white38,
                      fontSize: 13,
                      fontWeight:
                          value != null ? FontWeight.w600 : FontWeight.w400,
                    ),
                  ),
                ]),
              ),
            ),
          ],
        ),
      );
}

class _Toggle extends StatelessWidget {
  final String label, subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _Toggle({
    required this.label,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFF141414),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFF232323)),
        ),
        child: Row(children: [
          Expanded(
              child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w600)),
              Text(subtitle,
                  style: TextStyle(
                      color: Colors.white.withAlpha(80), fontSize: 11)),
            ],
          )),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: const Color(0xFFCC0000),
          ),
        ]),
      );
}
