// ignore_for_file: unused_element_parameter

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cricket_admin/services/shop_service.dart';
import 'package:flutter/material.dart';

const _bg = Color(0xFF0D0D0D);
const _surface = Color(0xFF141414);
const _surface2 = Color(0xFF1A1A1A);
const _surface3 = Color(0xFF202020);
const _border = Color(0xFF232323);
const _border2 = Color(0xFF2A2A2A);
const _textPrimary = Color(0xFFE8E8E8);
const _textSecondary = Color(0xFF666666);
const _textMuted = Color(0xFF3A3A3A);

const _categoryIcons = {
  'bat': Icons.sports_cricket_rounded,
  'ball': Icons.sports_baseball_rounded,
  'gloves': Icons.back_hand_rounded,
  'pads': Icons.shield_rounded,
  'shoes': Icons.directions_run_rounded,
  'helmet': Icons.safety_check_rounded,
  'kit': Icons.luggage_rounded,
  'accessories': Icons.category_rounded,
};

const _sourceColors = {
  'amazon': Color(0xFFFF9900),
  'flipkart': Color(0xFF2874F0),
  'blinkit': Color(0xFFFF3F6C),
  'other': Color(0xFF666666),
};

// ══════════════════════════════════════════════════════════
//  SHOP SCREEN
// ══════════════════════════════════════════════════════════
class ShopScreen extends StatefulWidget {
  const ShopScreen({super.key});

  @override
  State<ShopScreen> createState() => _ShopScreenState();
}

class _ShopScreenState extends State<ShopScreen> {
  String _filterCategory = 'all';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: Column(
        children: [
          // ── Header ──────────────────────────────────────
          _ScreenHeader(
            onAdd: () => _showProductDialog(context, product: null),
          ),

          // ── Category filter tabs ─────────────────────────
          _CategoryTabs(
            selected: _filterCategory,
            onChanged: (c) => setState(() => _filterCategory = c),
          ),

          // ── List ────────────────────────────────────────
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _filterCategory == 'all'
                  ? ShopService.stream()
                  : ShopService.streamByCategory(_filterCategory),
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(
                        color: Colors.redAccent, strokeWidth: 2),
                  );
                }

                final docs = snap.data?.docs ?? [];
                if (docs.isEmpty) return const _EmptyState();

                final products = docs.map(ShopService.fromDoc).toList();

                return ListView.separated(
                  padding: const EdgeInsets.all(24),
                  itemCount: products.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (_, i) => _ProductCard(
                    product: products[i],
                    onEdit: () =>
                        _showProductDialog(context, product: products[i]),
                    onDelete: () =>
                        _showDeleteDialog(context, products[i]['id'] as String),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  static Future<void> _showProductDialog(
    BuildContext context, {
    required Map<String, dynamic>? product,
  }) =>
      showDialog(
        context: context,
        builder: (_) => _ProductFormDialog(product: product),
      );

  static Future<void> _showDeleteDialog(
      BuildContext context, String docId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => _DeleteDialog(),
    );
    if (confirm == true) await ShopService.deleteProduct(docId);
  }
}

// ══════════════════════════════════════════════════════════
//  HEADER
// ══════════════════════════════════════════════════════════
class _ScreenHeader extends StatelessWidget {
  final VoidCallback onAdd;
  const _ScreenHeader({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 72,
      padding: const EdgeInsets.symmetric(horizontal: 28),
      decoration: const BoxDecoration(
        color: _surface,
        border: Border(bottom: BorderSide(color: _border)),
      ),
      child: Row(
        children: [
          const Icon(Icons.storefront_rounded, color: _textSecondary, size: 18),
          const SizedBox(width: 12),
          const Text('Shop Products',
              style: TextStyle(
                  color: _textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w700)),
          const Spacer(),
          _AddButton(onTap: onAdd),
        ],
      ),
    );
  }
}

class _AddButton extends StatefulWidget {
  final VoidCallback onTap;
  const _AddButton({required this.onTap});

  @override
  State<_AddButton> createState() => _AddButtonState();
}

class _AddButtonState extends State<_AddButton> {
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
          duration: const Duration(milliseconds: 130),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
          decoration: BoxDecoration(
            color: _hovered
                ? Colors.redAccent.withOpacity(0.85)
                : Colors.redAccent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.add_rounded, color: Colors.white, size: 16),
              SizedBox(width: 7),
              Text('Add Product',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w700)),
            ],
          ),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════
//  CATEGORY FILTER TABS
// ══════════════════════════════════════════════════════════
class _CategoryTabs extends StatelessWidget {
  final String selected;
  final ValueChanged<String> onChanged;
  const _CategoryTabs({required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final all = ['all', ...ShopService.categories];
    return Container(
      height: 48,
      color: _surface,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
        itemCount: all.length,
        separatorBuilder: (_, __) => const SizedBox(width: 6),
        itemBuilder: (_, i) => _TabChip(
          label: all[i] == 'all' ? 'All' : _capitalize(all[i]),
          icon: all[i] == 'all'
              ? Icons.grid_view_rounded
              : _categoryIcons[all[i]] ?? Icons.category_rounded,
          selected: selected == all[i],
          onTap: () => onChanged(all[i]),
        ),
      ),
    );
  }

  String _capitalize(String s) =>
      s.isEmpty ? s : '${s[0].toUpperCase()}${s.substring(1)}';
}

class _TabChip extends StatefulWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;
  const _TabChip(
      {required this.label,
      required this.icon,
      required this.selected,
      required this.onTap});

  @override
  State<_TabChip> createState() => _TabChipState();
}

class _TabChipState extends State<_TabChip> {
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
          duration: const Duration(milliseconds: 120),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
          decoration: BoxDecoration(
            color: widget.selected
                ? Colors.redAccent.withOpacity(0.12)
                : _hovered
                    ? _surface2
                    : _surface3,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color:
                  widget.selected ? Colors.redAccent.withOpacity(0.4) : _border,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(widget.icon,
                  size: 12,
                  color: widget.selected ? Colors.redAccent : _textSecondary),
              const SizedBox(width: 5),
              Text(widget.label,
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight:
                          widget.selected ? FontWeight.w700 : FontWeight.w500,
                      color:
                          widget.selected ? Colors.redAccent : _textSecondary)),
            ],
          ),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════
//  PRODUCT CARD
// ══════════════════════════════════════════════════════════
class _ProductCard extends StatefulWidget {
  final Map<String, dynamic> product;
  final VoidCallback onEdit, onDelete;
  const _ProductCard(
      {required this.product, required this.onEdit, required this.onDelete});

  @override
  State<_ProductCard> createState() => _ProductCardState();
}

class _ProductCardState extends State<_ProductCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final p = widget.product;
    final discount = p['discount'] as int;
    final isTrending = p['isTrending'] as bool;
    final inStock = p['inStock'] as bool;
    final sourceColor = _sourceColors[p['source']] ?? _textSecondary;
    final catIcon = _categoryIcons[p['category']] ?? Icons.category_rounded;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 130),
        decoration: BoxDecoration(
          color: _hovered ? _surface2 : _surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _hovered ? _border2 : _border),
        ),
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            // ── Thumbnail ──────────────────────────────────
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: _surface3,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: _border),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(9),
                child: (p['image'] as String).isNotEmpty
                    ? Image.network(p['image'],
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) =>
                            _ImgFallback(icon: catIcon))
                    : _ImgFallback(icon: catIcon),
              ),
            ),
            const SizedBox(width: 16),

            // ── Info ───────────────────────────────────────
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Name + badges
                  Row(
                    children: [
                      Expanded(
                        child: Text(p['name'],
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                color: _textPrimary,
                                fontSize: 13,
                                fontWeight: FontWeight.w700)),
                      ),
                      if (isTrending) ...[
                        const SizedBox(width: 8),
                        _Badge(label: '🔥 Trending', color: Colors.orange),
                      ],
                      if (discount > 0) ...[
                        const SizedBox(width: 6),
                        _Badge(
                            label: '$discount% OFF', color: Colors.greenAccent),
                      ],
                      if (!inStock) ...[
                        const SizedBox(width: 6),
                        _Badge(label: 'Out of Stock', color: Colors.redAccent),
                      ],
                    ],
                  ),
                  const SizedBox(height: 6),

                  // Price row
                  Row(
                    children: [
                      Text(
                        '₹${p['price'].toStringAsFixed(0)}',
                        style: const TextStyle(
                            color: _textPrimary,
                            fontSize: 14,
                            fontWeight: FontWeight.w800),
                      ),
                      if ((p['originalPrice'] as double) >
                          (p['price'] as double)) ...[
                        const SizedBox(width: 8),
                        Text(
                          '₹${p['originalPrice'].toStringAsFixed(0)}',
                          style: const TextStyle(
                              color: _textMuted,
                              fontSize: 11,
                              decoration: TextDecoration.lineThrough),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Meta row
                  Row(
                    children: [
                      Icon(catIcon, size: 11, color: _textSecondary),
                      const SizedBox(width: 4),
                      Text(_capitalize(p['category']),
                          style: const TextStyle(
                              color: _textSecondary,
                              fontSize: 11,
                              fontWeight: FontWeight.w500)),
                      const SizedBox(width: 14),
                      Container(
                        width: 7,
                        height: 7,
                        decoration: BoxDecoration(
                          color: sourceColor,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(_capitalize(p['source']),
                          style: TextStyle(
                              color: sourceColor,
                              fontSize: 11,
                              fontWeight: FontWeight.w600)),
                      const SizedBox(width: 14),
                      // Rating stars
                      Icon(Icons.star_rounded,
                          size: 11, color: Colors.amber.withOpacity(0.8)),
                      const SizedBox(width: 3),
                      Text('${p['rating']}',
                          style: const TextStyle(
                              color: _textSecondary, fontSize: 11)),

                      const Spacer(),

                      // Trending toggle
                      _InlineToggle(
                        icon: Icons.local_fire_department_rounded,
                        value: isTrending,
                        activeColor: Colors.orange,
                        tooltip:
                            isTrending ? 'Remove Trending' : 'Mark Trending',
                        onToggle: (v) =>
                            ShopService.toggleTrending(p['id'] as String, v),
                      ),
                      const SizedBox(width: 8),

                      // Stock toggle
                      _InlineToggle(
                        icon: Icons.inventory_2_rounded,
                        value: inStock,
                        activeColor: Colors.greenAccent,
                        tooltip:
                            inStock ? 'Mark Out of Stock' : 'Mark In Stock',
                        onToggle: (v) =>
                            ShopService.toggleStock(p['id'] as String, v),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // ── Actions on hover ───────────────────────────
            if (_hovered) ...[
              const SizedBox(width: 12),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _ActionBtn(
                    icon: Icons.edit_rounded,
                    tooltip: 'Edit',
                    color: _textSecondary,
                    onTap: widget.onEdit,
                  ),
                  const SizedBox(height: 8),
                  _ActionBtn(
                    icon: Icons.delete_rounded,
                    tooltip: 'Delete',
                    color: Colors.redAccent,
                    onTap: widget.onDelete,
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _capitalize(String s) =>
      s.isEmpty ? s : '${s[0].toUpperCase()}${s.substring(1)}';
}

class _Badge extends StatelessWidget {
  final String label;
  final Color color;
  const _Badge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Text(label,
          style: TextStyle(
              color: color, fontSize: 9, fontWeight: FontWeight.w700)),
    );
  }
}

class _InlineToggle extends StatefulWidget {
  final IconData icon;
  final bool value;
  final Color activeColor;
  final String tooltip;
  final ValueChanged<bool> onToggle;
  const _InlineToggle(
      {required this.icon,
      required this.value,
      required this.activeColor,
      required this.tooltip,
      required this.onToggle});

  @override
  State<_InlineToggle> createState() => _InlineToggleState();
}

class _InlineToggleState extends State<_InlineToggle> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: widget.tooltip,
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: () => widget.onToggle(!widget.value),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 110),
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: widget.value
                  ? widget.activeColor.withOpacity(0.1)
                  : _hovered
                      ? _surface3
                      : Colors.transparent,
              borderRadius: BorderRadius.circular(7),
              border: Border.all(
                color: widget.value
                    ? widget.activeColor.withOpacity(0.3)
                    : _border,
              ),
            ),
            child: Icon(widget.icon,
                size: 13,
                color: widget.value ? widget.activeColor : _textMuted),
          ),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════
//  PRODUCT FORM DIALOG
// ══════════════════════════════════════════════════════════
class _ProductFormDialog extends StatefulWidget {
  final Map<String, dynamic>? product;
  const _ProductFormDialog({this.product});

  @override
  State<_ProductFormDialog> createState() => _ProductFormDialogState();
}

class _ProductFormDialogState extends State<_ProductFormDialog> {
  final _nameCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _imageCtrl = TextEditingController();
  final _priceCtrl = TextEditingController();
  final _origPriceCtrl = TextEditingController();
  final _urlCtrl = TextEditingController();
  final _ratingCtrl = TextEditingController();

  String _category = ShopService.categories.first;
  String _source = ShopService.sources.first;
  bool _isTrending = false;
  bool _inStock = true;
  bool _saving = false;

  bool get _isEdit => widget.product != null;

  int get _computedDiscount {
    final orig = double.tryParse(_origPriceCtrl.text) ?? 0;
    final price = double.tryParse(_priceCtrl.text) ?? 0;
    if (orig <= 0 || price >= orig) return 0;
    return ((orig - price) / orig * 100).round();
  }

  @override
  void initState() {
    super.initState();
    if (_isEdit) {
      final p = widget.product!;
      _nameCtrl.text = p['name'];
      _descCtrl.text = p['description'];
      _imageCtrl.text = p['image'];
      _priceCtrl.text = p['price'].toString();
      _origPriceCtrl.text = p['originalPrice'].toString();
      _urlCtrl.text = p['affiliateUrl'];
      _ratingCtrl.text = p['rating'].toString();
      _category = p['category'];
      _source = p['source'];
      _isTrending = p['isTrending'];
      _inStock = p['inStock'];
    }
    _priceCtrl.addListener(() => setState(() {}));
    _origPriceCtrl.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    for (final c in [
      _nameCtrl,
      _descCtrl,
      _imageCtrl,
      _priceCtrl,
      _origPriceCtrl,
      _urlCtrl,
      _ratingCtrl
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  bool get _valid =>
      _nameCtrl.text.trim().isNotEmpty &&
      _priceCtrl.text.trim().isNotEmpty &&
      _urlCtrl.text.trim().isNotEmpty;

  Future<void> _save() async {
    if (!_valid || _saving) return;
    setState(() => _saving = true);
    try {
      final price = double.tryParse(_priceCtrl.text) ?? 0;
      final origPrice = double.tryParse(_origPriceCtrl.text) ?? price;
      final rating = double.tryParse(_ratingCtrl.text) ?? 0;

      if (_isEdit) {
        await ShopService.updateProduct(
          widget.product!['id'] as String,
          name: _nameCtrl.text.trim(),
          description: _descCtrl.text.trim(),
          image: _imageCtrl.text.trim(),
          price: price,
          originalPrice: origPrice,
          currency: 'INR',
          category: _category,
          source: _source,
          affiliateUrl: _urlCtrl.text.trim(),
          isTrending: _isTrending,
          inStock: _inStock,
          rating: rating,
        );
      } else {
        await ShopService.addProduct(
          name: _nameCtrl.text.trim(),
          description: _descCtrl.text.trim(),
          image: _imageCtrl.text.trim(),
          price: price,
          originalPrice: origPrice,
          currency: 'INR',
          category: _category,
          source: _source,
          affiliateUrl: _urlCtrl.text.trim(),
          isTrending: _isTrending,
          inStock: _inStock,
          rating: rating,
        );
      }
      if (mounted) Navigator.pop(context);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: _surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: _border),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560, maxHeight: 780),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // ── Title ──
              Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: Colors.redAccent.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: const Icon(Icons.storefront_rounded,
                        color: Colors.redAccent, size: 18),
                  ),
                  const SizedBox(width: 12),
                  Text(_isEdit ? 'Edit Product' : 'Add Product',
                      style: const TextStyle(
                          color: _textPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.w700)),
                ],
              ),
              const SizedBox(height: 24),

              // ── Name ──
              const _FormLabel('Product Name *'),
              const SizedBox(height: 8),
              _FormField(
                  controller: _nameCtrl, hint: 'e.g. SS Ton Elite Cricket Bat'),
              const SizedBox(height: 16),

              // ── Description ──
              const _FormLabel('Description'),
              const SizedBox(height: 8),
              _FormField(
                controller: _descCtrl,
                hint: 'Short product description...',
                maxLines: 2,
              ),
              const SizedBox(height: 16),

              // ── Image URL ──
              const _FormLabel('Image URL'),
              const SizedBox(height: 8),
              _FormField(
                controller: _imageCtrl,
                hint: 'https://...',
                icon: Icons.image_rounded,
              ),
              const SizedBox(height: 16),

              // ── Price row ──
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const _FormLabel('Sale Price (₹) *'),
                        const SizedBox(height: 8),
                        _FormField(
                          controller: _priceCtrl,
                          hint: '4999',
                          icon: Icons.currency_rupee_rounded,
                          keyboardType: TextInputType.number,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const _FormLabel('Original MRP (₹)'),
                        const SizedBox(height: 8),
                        _FormField(
                          controller: _origPriceCtrl,
                          hint: '7999',
                          icon: Icons.sell_rounded,
                          keyboardType: TextInputType.number,
                        ),
                      ],
                    ),
                  ),
                  if (_computedDiscount > 0) ...[
                    const SizedBox(width: 12),
                    Column(
                      children: [
                        const _FormLabel('Discount'),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 14),
                          decoration: BoxDecoration(
                            color: Colors.greenAccent.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                                color: Colors.greenAccent.withOpacity(0.25)),
                          ),
                          child: Text(
                            '$_computedDiscount%',
                            style: const TextStyle(
                                color: Colors.greenAccent,
                                fontSize: 13,
                                fontWeight: FontWeight.w800),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 16),

              // ── Affiliate URL ──
              const _FormLabel('Affiliate URL *'),
              const SizedBox(height: 8),
              _FormField(
                controller: _urlCtrl,
                hint: 'https://amzn.to/xxxxx',
                icon: Icons.link_rounded,
              ),
              const SizedBox(height: 16),

              // ── Rating ──
              const _FormLabel('Rating (0–5)'),
              const SizedBox(height: 8),
              _FormField(
                controller: _ratingCtrl,
                hint: '4.5',
                icon: Icons.star_rounded,
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 16),

              // ── Category & Source ──
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const _FormLabel('Category'),
                        const SizedBox(height: 8),
                        _DropdownField<String>(
                          value: _category,
                          items: ShopService.categories,
                          labelBuilder: (s) =>
                              '${s[0].toUpperCase()}${s.substring(1)}',
                          iconBuilder: (s) =>
                              _categoryIcons[s] ?? Icons.category_rounded,
                          onChanged: (v) => setState(() => _category = v!),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const _FormLabel('Source'),
                        const SizedBox(height: 8),
                        _DropdownField<String>(
                          value: _source,
                          items: ShopService.sources,
                          labelBuilder: (s) =>
                              '${s[0].toUpperCase()}${s.substring(1)}',
                          iconBuilder: (s) => Icons.store_rounded,
                          onChanged: (v) => setState(() => _source = v!),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // ── Toggles ──
              Row(
                children: [
                  Expanded(
                    child: _ToggleTile(
                      icon: Icons.local_fire_department_rounded,
                      label: 'Trending',
                      subtitle: 'Show 🔥 badge',
                      value: _isTrending,
                      activeColor: Colors.orange,
                      onChanged: (v) => setState(() => _isTrending = v),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _ToggleTile(
                      icon: Icons.inventory_2_rounded,
                      label: 'In Stock',
                      subtitle: 'Available to buy',
                      value: _inStock,
                      activeColor: Colors.greenAccent,
                      onChanged: (v) => setState(() => _inStock = v),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 28),

              // ── Actions ──
              Row(
                children: [
                  Expanded(
                      child: _CancelBtn(onTap: () => Navigator.pop(context))),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _ConfirmBtn(
                      label: _saving
                          ? 'Saving…'
                          : _isEdit
                              ? 'Save Changes'
                              : 'Add Product',
                      enabled: _valid && !_saving,
                      onTap: _save,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════
//  SHARED WIDGETS (matching existing admin theme)
// ══════════════════════════════════════════════════════════
class _FormLabel extends StatelessWidget {
  final String text;
  const _FormLabel(this.text);

  @override
  Widget build(BuildContext context) => Text(text,
      style: const TextStyle(
          color: _textSecondary,
          fontSize: 11,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.3));
}

class _FormField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final IconData? icon;
  final int maxLines;
  final TextInputType? keyboardType;

  const _FormField({
    required this.controller,
    required this.hint,
    this.icon,
    this.maxLines = 1,
    this.keyboardType,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      style: const TextStyle(color: _textPrimary, fontSize: 13),
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
          borderSide: const BorderSide(color: _border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: _border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.redAccent.withOpacity(0.5)),
        ),
      ),
    );
  }
}

class _DropdownField<T> extends StatelessWidget {
  final T value;
  final List<T> items;
  final String Function(T) labelBuilder;
  final IconData Function(T) iconBuilder;
  final ValueChanged<T?> onChanged;

  const _DropdownField({
    required this.value,
    required this.items,
    required this.labelBuilder,
    required this.iconBuilder,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: _surface2,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _border),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          isExpanded: true,
          dropdownColor: _surface2,
          iconEnabledColor: _textMuted,
          style: const TextStyle(color: _textPrimary, fontSize: 13),
          items: items.map((item) {
            return DropdownMenuItem<T>(
              value: item,
              child: Row(
                children: [
                  Icon(iconBuilder(item), size: 13, color: _textSecondary),
                  const SizedBox(width: 8),
                  Text(labelBuilder(item)),
                ],
              ),
            );
          }).toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }
}

class _ToggleTile extends StatelessWidget {
  final IconData icon;
  final String label, subtitle;
  final bool value;
  final Color activeColor;
  final ValueChanged<bool> onChanged;

  const _ToggleTile({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.value,
    required this.activeColor,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => onChanged(!value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: value ? activeColor.withOpacity(0.06) : _surface2,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: value ? activeColor.withOpacity(0.3) : _border,
          ),
        ),
        child: Row(
          children: [
            Icon(icon, size: 16, color: value ? activeColor : _textSecondary),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: TextStyle(
                          color: value ? activeColor : _textPrimary,
                          fontSize: 12,
                          fontWeight: FontWeight.w700)),
                  Text(subtitle,
                      style:
                          const TextStyle(color: _textSecondary, fontSize: 10)),
                ],
              ),
            ),
            AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: 32,
              height: 18,
              decoration: BoxDecoration(
                color: value ? activeColor.withOpacity(0.8) : _surface3,
                borderRadius: BorderRadius.circular(9),
                border: Border.all(color: value ? activeColor : _border),
              ),
              child: AnimatedAlign(
                duration: const Duration(milliseconds: 150),
                alignment: value ? Alignment.centerRight : Alignment.centerLeft,
                child: Container(
                  margin: const EdgeInsets.all(2),
                  width: 14,
                  height: 14,
                  decoration: BoxDecoration(
                    color: value ? Colors.white : _textMuted,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionBtn extends StatefulWidget {
  final IconData icon;
  final String tooltip;
  final Color color;
  final VoidCallback onTap;
  const _ActionBtn(
      {required this.icon,
      required this.tooltip,
      required this.color,
      required this.onTap});

  @override
  State<_ActionBtn> createState() => _ActionBtnState();
}

class _ActionBtnState extends State<_ActionBtn> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: widget.tooltip,
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: _hovered ? widget.color.withOpacity(0.1) : _surface3,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: _hovered ? widget.color.withOpacity(0.35) : _border,
              ),
            ),
            child: Icon(widget.icon,
                color: _hovered ? widget.color : _textMuted, size: 15),
          ),
        ),
      ),
    );
  }
}

class _CancelBtn extends StatefulWidget {
  final VoidCallback onTap;
  const _CancelBtn({required this.onTap});

  @override
  State<_CancelBtn> createState() => _CancelBtnState();
}

class _CancelBtnState extends State<_CancelBtn> {
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
          duration: const Duration(milliseconds: 130),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: _hovered ? _surface2 : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: _hovered ? _border2 : _border),
          ),
          child: const Center(
            child: Text('Cancel',
                style: TextStyle(
                    color: _textSecondary,
                    fontSize: 13,
                    fontWeight: FontWeight.w500)),
          ),
        ),
      ),
    );
  }
}

class _ConfirmBtn extends StatefulWidget {
  final String label;
  final bool enabled;
  final VoidCallback onTap;
  final Color color;
  const _ConfirmBtn({
    required this.label,
    required this.enabled,
    required this.onTap,
    this.color = Colors.redAccent,
  });

  @override
  State<_ConfirmBtn> createState() => _ConfirmBtnState();
}

class _ConfirmBtnState extends State<_ConfirmBtn> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => widget.enabled ? setState(() => _hovered = true) : null,
      onExit: (_) => setState(() => _hovered = false),
      cursor: widget.enabled
          ? SystemMouseCursors.click
          : SystemMouseCursors.forbidden,
      child: GestureDetector(
        onTap: widget.enabled ? widget.onTap : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 130),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: widget.enabled
                ? _hovered
                    ? widget.color.withOpacity(0.82)
                    : widget.color
                : _surface2,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Center(
            child: Text(widget.label,
                style: TextStyle(
                    color: widget.enabled ? Colors.white : _textMuted,
                    fontSize: 13,
                    fontWeight: FontWeight.w700)),
          ),
        ),
      ),
    );
  }
}

class _DeleteDialog extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: _surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: _border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: Colors.redAccent.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: const Icon(Icons.delete_rounded,
                    color: Colors.redAccent, size: 18),
              ),
              const SizedBox(width: 12),
              const Text('Delete Product',
                  style: TextStyle(
                      color: _textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w700)),
            ]),
            const SizedBox(height: 16),
            const Text(
              'This product will be permanently deleted and removed from the shop.',
              style:
                  TextStyle(color: _textSecondary, fontSize: 13, height: 1.6),
            ),
            const SizedBox(height: 24),
            Row(children: [
              Expanded(
                  child:
                      _CancelBtn(onTap: () => Navigator.pop(context, false))),
              const SizedBox(width: 12),
              Expanded(
                child: _ConfirmBtn(
                  label: 'Delete',
                  enabled: true,
                  onTap: () => Navigator.pop(context, true),
                ),
              ),
            ]),
          ],
        ),
      ),
    );
  }
}

class _ImgFallback extends StatelessWidget {
  final IconData icon;
  const _ImgFallback({required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: _surface3,
      child: Center(child: Icon(icon, color: _textMuted, size: 24)),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: _surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: _border),
            ),
            child: const Icon(Icons.storefront_rounded,
                color: _textMuted, size: 32),
          ),
          const SizedBox(height: 20),
          const Text('No products yet',
              style: TextStyle(
                  color: _textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          const Text(
            'Click "Add Product" to add your first shop item.',
            style: TextStyle(color: _textSecondary, fontSize: 13, height: 1.6),
          ),
        ],
      ),
    );
  }
}
