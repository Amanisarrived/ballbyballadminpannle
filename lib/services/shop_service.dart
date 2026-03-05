import 'package:cloud_firestore/cloud_firestore.dart';

class ShopService {
  static final _col = FirebaseFirestore.instance.collection('products');

  // ── Stream all products ──────────────────────────────────
  static Stream<QuerySnapshot> stream() =>
      _col.orderBy('createdAt', descending: true).snapshots();

  // ── Stream by category ───────────────────────────────────
  static Stream<QuerySnapshot> streamByCategory(String category) => _col
      .where('category', isEqualTo: category)
      // .orderBy('createdAt', descending: true)
      .snapshots();

  // ── Parse doc → Map ─────────────────────────────────────
  static Map<String, dynamic> fromDoc(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return {
      'id': doc.id,
      'name': d['name'] ?? '',
      'description': d['description'] ?? '',
      'image': d['image'] ?? '',
      'price': (d['price'] ?? 0).toDouble(),
      'originalPrice': (d['originalPrice'] ?? 0).toDouble(),
      'currency': d['currency'] ?? 'INR',
      'category': d['category'] ?? 'accessories',
      'source': d['source'] ?? 'amazon',
      'affiliateUrl': d['affiliateUrl'] ?? '',
      'isTrending': d['isTrending'] ?? false,
      'discount': (d['discount'] ?? 0).toInt(),
      'inStock': d['inStock'] ?? true,
      'rating': (d['rating'] ?? 0.0).toDouble(),
      'createdAt': (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    };
  }

  // ── Add product ──────────────────────────────────────────
  static Future<void> addProduct({
    required String name,
    required String description,
    required String image,
    required double price,
    required double originalPrice,
    required String currency,
    required String category,
    required String source,
    required String affiliateUrl,
    required bool isTrending,
    required bool inStock,
    required double rating,
  }) async {
    final discount = originalPrice > 0
        ? ((originalPrice - price) / originalPrice * 100).round()
        : 0;

    await _col.add({
      'name': name,
      'description': description,
      'image': image,
      'price': price,
      'originalPrice': originalPrice,
      'currency': currency,
      'category': category,
      'source': source,
      'affiliateUrl': affiliateUrl,
      'isTrending': isTrending,
      'discount': discount,
      'inStock': inStock,
      'rating': rating,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  // ── Update product ───────────────────────────────────────
  static Future<void> updateProduct(
    String docId, {
    required String name,
    required String description,
    required String image,
    required double price,
    required double originalPrice,
    required String currency,
    required String category,
    required String source,
    required String affiliateUrl,
    required bool isTrending,
    required bool inStock,
    required double rating,
  }) async {
    final discount = originalPrice > 0
        ? ((originalPrice - price) / originalPrice * 100).round()
        : 0;

    await _col.doc(docId).update({
      'name': name,
      'description': description,
      'image': image,
      'price': price,
      'originalPrice': originalPrice,
      'currency': currency,
      'category': category,
      'source': source,
      'affiliateUrl': affiliateUrl,
      'isTrending': isTrending,
      'discount': discount,
      'inStock': inStock,
      'rating': rating,
    });
  }

  // ── Toggle trending ──────────────────────────────────────
  static Future<void> toggleTrending(String docId, bool value) async =>
      _col.doc(docId).update({'isTrending': value});

  // ── Toggle stock ─────────────────────────────────────────
  static Future<void> toggleStock(String docId, bool value) async =>
      _col.doc(docId).update({'inStock': value});

  // ── Delete ───────────────────────────────────────────────
  static Future<void> deleteProduct(String docId) async =>
      _col.doc(docId).delete();

  // ── Categories ───────────────────────────────────────────
  static const List<String> categories = [
    'bat',
    'ball',
    'gloves',
    'pads',
    'shoes',
    'helmet',
    'kit',
    'accessories',
  ];

  static const List<String> sources = [
    'amazon',
    'flipkart',
    'myntra',
    'other',
  ];
}
