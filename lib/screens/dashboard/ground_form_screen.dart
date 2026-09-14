import 'package:cricket_admin/services/cricspot_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// ─────────────────────────────────────────────────────────────
//  GROUND FORM SCREEN — Add / Edit
// ─────────────────────────────────────────────────────────────

class GroundFormScreen extends StatefulWidget {
  final CricGround? ground;
  const GroundFormScreen({super.key, this.ground});

  @override
  State<GroundFormScreen> createState() => _GroundFormScreenState();
}

class _GroundFormScreenState extends State<GroundFormScreen> {
  static const _bg = Color(0xFF0D0D0D);
  static const _surface = Color(0xFF141414);
  static const _border = Color(0xFF232323);
  static const _red = Color(0xFFCC0000);

  final _formKey = GlobalKey<FormState>();
  bool _saving = false;
  bool get _isEdit => widget.ground != null;

  // ── Controllers ──────────────────────────────────────────
  late final TextEditingController _name;
  late final TextEditingController _area;
  late final TextEditingController _city;
  late final TextEditingController _state;
  late final TextEditingController _address;
  late final TextEditingController _pincode;
  late final TextEditingController _lat;
  late final TextEditingController _lng;
  late final TextEditingController _phone;
  late final TextEditingController _whatsapp;
  late final TextEditingController _website;
  late final TextEditingController _price;
  late final TextEditingController _priceDisplay;
  late final TextEditingController _logo;
  late final TextEditingController _courts;

  // ── State values ─────────────────────────────────────────
  String _priceUnit = 'per_hour';
  String _groundType = 'box';
  String _pitchType = 'turf';
  bool _isActive = true;
  bool _isPremium = false;

  final List<String> _amenities = [];
  final List<String> _format = [];

  static const _amenityOptions = [
    'Turf',
    'Floodlights',
    'Parking',
    'Washroom',
    'Canteen',
    'Changing Room',
    'First Aid',
    'CCTV',
  ];

  static const _formatOptions = ['T20', 'Box', 'T10', 'T5', 'ODI'];

  @override
  void initState() {
    super.initState();
    final g = widget.ground;
    _name = TextEditingController(text: g?.name ?? '');
    _area = TextEditingController(text: g?.area ?? '');
    _city = TextEditingController(text: g?.city ?? 'Delhi');
    _state = TextEditingController(text: g?.state ?? 'Delhi');
    _address = TextEditingController(text: g?.address ?? '');
    _pincode = TextEditingController(text: g?.pincode ?? '');
    _lat = TextEditingController(text: g?.lat.toString() ?? '');
    _lng = TextEditingController(text: g?.lng.toString() ?? '');
    _phone = TextEditingController(text: g?.phone ?? '');
    _whatsapp = TextEditingController(text: g?.whatsapp ?? '');
    _website = TextEditingController(text: g?.website ?? '');
    _price = TextEditingController(
        text: g != null ? g.price.toStringAsFixed(0) : '');
    _priceDisplay = TextEditingController(text: g?.priceDisplay ?? '');
    _logo = TextEditingController(text: g?.logo ?? '');
    _courts =
        TextEditingController(text: g != null ? g.courts.toString() : '1');

    if (g != null) {
      _priceUnit = g.priceUnit;
      _groundType = g.groundType;
      _pitchType = g.pitchType;
      _isActive = g.isActive;
      _isPremium = g.isPremium;
      _amenities.addAll(g.amenities);
      _format.addAll(g.format);
    }
  }

  @override
  void dispose() {
    for (final c in [
      _name,
      _area,
      _city,
      _state,
      _address,
      _pincode,
      _lat,
      _lng,
      _phone,
      _whatsapp,
      _website,
      _price,
      _priceDisplay,
      _logo,
      _courts
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await CricSpotAdminService.saveGround(
        existingId: _isEdit ? widget.ground!.id : null,
        name: _name.text.trim(),
        area: _area.text.trim(),
        city: _city.text.trim(),
        state: _state.text.trim(),
        address: _address.text.trim(),
        pincode: _pincode.text.trim(),
        lat: double.tryParse(_lat.text.trim()) ?? 0,
        lng: double.tryParse(_lng.text.trim()) ?? 0,
        phone: _phone.text.trim(),
        whatsapp: _whatsapp.text.trim(),
        website: _website.text.trim(),
        price: double.tryParse(_price.text.trim()) ?? 0,
        priceDisplay: _priceDisplay.text.trim(),
        priceUnit: _priceUnit,
        amenities: _amenities,
        images: [],
        logo: _logo.text.trim(),
        groundType: _groundType,
        format: _format,
        pitchType: _pitchType,
        courts: int.tryParse(_courts.text.trim()) ?? 1,
        isActive: _isActive,
        isPremium: _isPremium,
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
          _isEdit ? 'Edit Ground' : 'Add Ground',
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
                    label: 'Ground Name *',
                    hint: 'Box Cricket Arena'),
                _Field(ctrl: _area, label: 'Area / Locality *', hint: 'Rohini'),
                Row(children: [
                  Expanded(
                      child:
                          _Field(ctrl: _city, label: 'City *', hint: 'Delhi')),
                  const SizedBox(width: 10),
                  Expanded(
                      child: _Field(
                          ctrl: _state, label: 'State *', hint: 'Delhi')),
                ]),
                _Field(
                    ctrl: _address,
                    label: 'Full Address *',
                    hint: 'Sector 7, Rohini, Delhi - 110085',
                    maxLines: 2),
                Row(children: [
                  Expanded(
                      child: _Field(
                          ctrl: _pincode,
                          label: 'Pincode',
                          hint: '110085',
                          keyboardType: TextInputType.number)),
                  const SizedBox(width: 10),
                  Expanded(
                      child: _Field(
                          ctrl: _courts,
                          label: 'No. of Courts',
                          hint: '1',
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
                    keyboardType: TextInputType.phone),
                _Field(
                    ctrl: _website,
                    label: 'Website',
                    hint: 'https://groundname.com',
                    required: false),
                _Field(
                    ctrl: _logo,
                    label: 'Logo URL',
                    hint: 'https://...',
                    required: false),

                const SizedBox(height: 20),

                // ── Pricing ───────────────────────────────
                _SectionLabel('Pricing'),
                const SizedBox(height: 10),
                Row(children: [
                  Expanded(
                      child: _Field(
                          ctrl: _price,
                          label: 'Price (₹) *',
                          hint: '800',
                          keyboardType: TextInputType.number)),
                  const SizedBox(width: 10),
                  Expanded(
                      child: _DropdownField<String>(
                    label: 'Price Unit',
                    value: _priceUnit,
                    items: const {
                      'per_hour': 'Per Hour',
                      'per_game': 'Per Game',
                    },
                    onChanged: (v) => setState(() => _priceUnit = v!),
                  )),
                ]),
                _Field(
                    ctrl: _priceDisplay,
                    label: 'Display Text *',
                    hint: '₹800/hr'),

                const SizedBox(height: 20),

                // ── Ground Details ────────────────────────
                _SectionLabel('Ground Details'),
                const SizedBox(height: 10),
                Row(children: [
                  Expanded(
                      child: _DropdownField<String>(
                    label: 'Ground Type',
                    value: _groundType,
                    items: const {
                      'box': 'Box Cricket',
                      'turf': 'Turf Ground',
                      'open': 'Open Ground',
                    },
                    onChanged: (v) => setState(() => _groundType = v!),
                  )),
                  const SizedBox(width: 10),
                  Expanded(
                      child: _DropdownField<String>(
                    label: 'Pitch Type',
                    value: _pitchType,
                    items: const {
                      'turf': 'Turf',
                      'concrete': 'Concrete',
                      'matting': 'Matting',
                    },
                    onChanged: (v) => setState(() => _pitchType = v!),
                  )),
                ]),

                const SizedBox(height: 16),

                // Formats
                _SectionLabel('Supported Formats'),
                const SizedBox(height: 8),
                Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _formatOptions.map((f) {
                      final sel = _format.contains(f);
                      return _Chip(
                        label: f,
                        selected: sel,
                        onTap: () => setState(
                            () => sel ? _format.remove(f) : _format.add(f)),
                      );
                    }).toList()),

                const SizedBox(height: 16),

                // Amenities
                _SectionLabel('Amenities'),
                const SizedBox(height: 8),
                Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _amenityOptions.map((a) {
                      final sel = _amenities.contains(a);
                      return _Chip(
                        label: a,
                        selected: sel,
                        onTap: () => setState(() =>
                            sel ? _amenities.remove(a) : _amenities.add(a)),
                      );
                    }).toList()),

                const SizedBox(height: 20),

                // ── Location ──────────────────────────────
                _SectionLabel('Location (Optional)'),
                const SizedBox(height: 10),
                Row(children: [
                  Expanded(
                      child: _Field(
                          ctrl: _lat,
                          label: 'Latitude',
                          hint: '28.7041',
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true),
                          required: false)),
                  const SizedBox(width: 10),
                  Expanded(
                      child: _Field(
                          ctrl: _lng,
                          label: 'Longitude',
                          hint: '77.1025',
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true),
                          required: false)),
                ]),

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
                    : Text(_isEdit ? 'Update Ground' : 'Add Ground',
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
  final String label;
  final String hint;
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
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
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
      ]),
    );
  }
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
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
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
      ]),
    );
  }
}

class _TimePicker extends StatelessWidget {
  final String label, value;
  final VoidCallback onTap;

  const _TimePicker({
    required this.label,
    required this.value,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
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
              border: Border.all(color: const Color(0xFF232323)),
            ),
            child: Row(children: [
              const Icon(Icons.schedule_rounded,
                  color: Color(0xFFCC0000), size: 16),
              const SizedBox(width: 8),
              Text(value,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w600)),
            ]),
          ),
        ),
      ]),
    );
  }
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
  Widget build(BuildContext context) {
    return Container(
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
                style:
                    TextStyle(color: Colors.white.withAlpha(80), fontSize: 11)),
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
}

class _Chip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _Chip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: selected
              ? const Color(0xFFCC0000).withAlpha(20)
              : const Color(0xFF141414),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
              color: selected
                  ? const Color(0xFFCC0000).withAlpha(80)
                  : const Color(0xFF232323)),
        ),
        child: Text(label,
            style: TextStyle(
                color: selected ? const Color(0xFFCC0000) : Colors.white54,
                fontSize: 12,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w400)),
      ),
    );
  }
}
