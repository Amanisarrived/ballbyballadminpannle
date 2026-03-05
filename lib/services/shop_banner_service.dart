import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

// ══════════════════════════════════════════════════════════
//  MODEL  (mirrors the app's ShopBanner exactly)
// ══════════════════════════════════════════════════════════
class AdminShopBanner {
  final String imageUrl;
  final String title;
  final String subtitle;
  final String badgeText;
  final String accentColorHex; // store as hex string — easy to edit in UI
  final bool isActive;

  const AdminShopBanner({
    required this.imageUrl,
    required this.title,
    required this.subtitle,
    required this.badgeText,
    required this.accentColorHex,
    required this.isActive,
  });

  Color get accentColor {
    try {
      final cleaned = accentColorHex.replaceAll('#', '');
      return Color(int.parse('FF$cleaned', radix: 16));
    } catch (_) {
      return const Color(0xFFCC0000);
    }
  }

  // ── Empty state for "new banner" form ─────────────────
  static AdminShopBanner empty() => const AdminShopBanner(
        imageUrl: '',
        title: '',
        subtitle: '',
        badgeText: '',
        accentColorHex: '#CC0000',
        isActive: false,
      );

  // ── From Firestore ────────────────────────────────────
  factory AdminShopBanner.fromFirestore(Map<String, dynamic> data) {
    return AdminShopBanner(
      imageUrl: data['imageUrl'] as String? ?? '',
      title: data['title'] as String? ?? '',
      subtitle: data['subtitle'] as String? ?? '',
      badgeText: data['badgeText'] as String? ?? '',
      accentColorHex: data['accentColor'] as String? ?? '#CC0000',
      isActive: data['isActive'] as bool? ?? false,
    );
  }

  // ── To Firestore ──────────────────────────────────────
  Map<String, dynamic> toFirestore() {
    return {
      'imageUrl': imageUrl.trim(),
      'title': title.trim(),
      'subtitle': subtitle.trim(),
      'badgeText': badgeText.trim(),
      'accentColor': accentColorHex.trim(),
      'isActive': isActive,
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  AdminShopBanner copyWith({
    String? imageUrl,
    String? title,
    String? subtitle,
    String? badgeText,
    String? accentColorHex,
    bool? isActive,
  }) {
    return AdminShopBanner(
      imageUrl: imageUrl ?? this.imageUrl,
      title: title ?? this.title,
      subtitle: subtitle ?? this.subtitle,
      badgeText: badgeText ?? this.badgeText,
      accentColorHex: accentColorHex ?? this.accentColorHex,
      isActive: isActive ?? this.isActive,
    );
  }
}

// ══════════════════════════════════════════════════════════
//  SERVICE
// ══════════════════════════════════════════════════════════
class AdminShopBannerService {
  static final _db = FirebaseFirestore.instance;
  static const _col = 'shop_banners';
  static const _doc = 'active';

  // ── READ: fetch current banner ────────────────────────
  static Future<AdminShopBanner?> fetchBanner() async {
    try {
      final snap = await _db.collection(_col).doc(_doc).get();
      if (!snap.exists || snap.data() == null) return null;
      return AdminShopBanner.fromFirestore(snap.data()!);
    } catch (e) {
      debugPrint('AdminShopBannerService.fetchBanner error: $e');
      return null;
    }
  }

  // ── WRITE: save / overwrite banner ───────────────────
  static Future<bool> saveBanner(AdminShopBanner banner) async {
    try {
      await _db
          .collection(_col)
          .doc(_doc)
          .set(banner.toFirestore(), SetOptions(merge: true));
      return true;
    } catch (e) {
      debugPrint('AdminShopBannerService.saveBanner error: $e');
      return false;
    }
  }

  // ── TOGGLE: flip isActive without touching other fields
  static Future<bool> setActive(bool isActive) async {
    try {
      await _db.collection(_col).doc(_doc).update({
        'isActive': isActive,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return true;
    } catch (e) {
      debugPrint('AdminShopBannerService.setActive error: $e');
      return false;
    }
  }

  // ── DELETE: remove banner doc entirely ────────────────
  static Future<bool> deleteBanner() async {
    try {
      await _db.collection(_col).doc(_doc).delete();
      return true;
    } catch (e) {
      debugPrint('AdminShopBannerService.deleteBanner error: $e');
      return false;
    }
  }

  // ── STREAM: real-time updates (optional, for live preview)
  static Stream<AdminShopBanner?> bannerStream() {
    return _db.collection(_col).doc(_doc).snapshots().map((snap) {
      if (!snap.exists || snap.data() == null) return null;
      return AdminShopBanner.fromFirestore(snap.data()!);
    });
  }
}
