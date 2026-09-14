import 'package:cloud_firestore/cloud_firestore.dart';

// ─────────────────────────────────────────────────────────────
//  CRICSPOT ADMIN SERVICE
//  Full CRUD — Grounds + Tournaments + Manual Slots
// ─────────────────────────────────────────────────────────────

class CricSpotAdminService {
  CricSpotAdminService._();

  static final _db = FirebaseFirestore.instance;

  static CollectionReference get _grounds => _db.collection('cricket_grounds');
  static CollectionReference get _tournaments => _db.collection('tournaments');
  static CollectionReference _slots(String groundId) =>
      _grounds.doc(groundId).collection('slots');

  // ════════════════════════════════════════════════════════
  //  MODELS
  // ════════════════════════════════════════════════════════

  static CricGround _groundFromDoc(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return CricGround(
      id: doc.id,
      name: d['name'] as String? ?? '',
      area: d['area'] as String? ?? '',
      city: d['city'] as String? ?? '',
      state: d['state'] as String? ?? '',
      address: d['address'] as String? ?? '',
      pincode: d['pincode'] as String? ?? '',
      lat: (d['lat'] as num?)?.toDouble() ?? 0,
      lng: (d['lng'] as num?)?.toDouble() ?? 0,
      phone: d['phone'] as String? ?? '',
      whatsapp: d['whatsapp'] as String? ?? '',
      website: d['website'] as String? ?? '',
      price: (d['price'] as num?)?.toDouble() ?? 0,
      priceDisplay: d['priceDisplay'] as String? ?? '',
      priceUnit: d['priceUnit'] as String? ?? 'per_hour',
      amenities: List<String>.from(d['amenities'] ?? []),
      images: List<String>.from(d['images'] ?? []),
      logo: d['logo'] as String? ?? '',
      groundType: d['groundType'] as String? ?? 'box',
      format: List<String>.from(d['format'] ?? []),
      pitchType: d['pitchType'] as String? ?? 'turf',
      courts: (d['courts'] as num?)?.toInt() ?? 1,
      isActive: d['isActive'] as bool? ?? true,
      isPremium: d['isPremium'] as bool? ?? false,
      isVerified: d['isVerified'] as bool? ?? false,
      callTaps: (d['callTaps'] as num?)?.toInt() ?? 0,
      whatsappTaps: (d['whatsappTaps'] as num?)?.toInt() ?? 0,
      websiteTaps: (d['websiteTaps'] as num?)?.toInt() ?? 0,
      rating: (d['rating'] as num?)?.toDouble() ?? 0,
      totalReviews: (d['totalReviews'] as num?)?.toInt() ?? 0,
      createdAt: (d['createdAt'] as Timestamp?)?.toDate(),
    );
  }

  static CricTournament _tournamentFromDoc(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return CricTournament(
      id: doc.id,
      name: d['name'] as String? ?? '',
      format: d['format'] as String? ?? '',
      area: d['area'] as String? ?? '',
      city: d['city'] as String? ?? '',
      state: d['state'] as String? ?? '',
      venue: d['venue'] as String? ?? '',
      address: d['address'] as String? ?? '',
      startDate: (d['startDate'] as Timestamp?)?.toDate(),
      endDate: (d['endDate'] as Timestamp?)?.toDate(),
      lastRegDate: (d['lastRegDate'] as Timestamp?)?.toDate(),
      entryFee: (d['entryFee'] as num?)?.toInt() ?? 0,
      entryFeeDisplay: d['entryFeeDisplay'] as String? ?? '',
      prize: d['prize'] as String? ?? '',
      prizeAmount: (d['prizeAmount'] as num?)?.toInt() ?? 0,
      teamSize: (d['teamSize'] as num?)?.toInt() ?? 6,
      totalSlots: (d['totalSlots'] as num?)?.toInt() ?? 0,
      filledSlots: (d['filledSlots'] as num?)?.toInt() ?? 0,
      phone: d['phone'] as String? ?? '',
      whatsapp: d['whatsapp'] as String? ?? '',
      website: d['website'] as String? ?? '',
      status: d['status'] as String? ?? 'upcoming',
      isActive: d['isActive'] as bool? ?? true,
      isPremium: d['isPremium'] as bool? ?? false,
      isVerified: d['isVerified'] as bool? ?? false,
      callTaps: (d['callTaps'] as num?)?.toInt() ?? 0,
      whatsappTaps: (d['whatsappTaps'] as num?)?.toInt() ?? 0,
      description: d['description'] as String? ?? '',
      rules: d['rules'] as String? ?? '',
      createdAt: (d['createdAt'] as Timestamp?)?.toDate(),
    );
  }

  // ════════════════════════════════════════════════════════
  //  STREAMS
  // ════════════════════════════════════════════════════════

  static Stream<List<CricGround>> groundsStream({String? city}) {
    Query q = _grounds.orderBy('createdAt', descending: true);
    if (city != null) q = q.where('city', isEqualTo: city);
    return q.snapshots().map((s) => s.docs.map(_groundFromDoc).toList());
  }

  static Stream<List<CricTournament>> tournamentsStream({String? city}) {
    Query q = _tournaments.orderBy('createdAt', descending: true);
    if (city != null) q = q.where('city', isEqualTo: city);
    return q.snapshots().map((s) => s.docs.map(_tournamentFromDoc).toList());
  }

  // ════════════════════════════════════════════════════════
  //  GROUNDS CRUD
  // ════════════════════════════════════════════════════════

  static Future<String> saveGround({
    String? existingId,
    required String name,
    required String area,
    required String city,
    required String state,
    required String address,
    required String pincode,
    required double lat,
    required double lng,
    required String phone,
    required String whatsapp,
    required String website,
    required double price,
    required String priceDisplay,
    required String priceUnit,
    required List<String> amenities,
    required List<String> images,
    required String logo,
    required String groundType,
    required List<String> format,
    required String pitchType,
    required int courts,
    required bool isActive,
    required bool isPremium,
  }) async {
    final data = <String, dynamic>{
      'name': name,
      'area': area,
      'city': city,
      'state': state,
      'address': address,
      'pincode': pincode,
      'lat': lat,
      'lng': lng,
      'phone': phone,
      'whatsapp': whatsapp,
      'website': website,
      'price': price,
      'priceDisplay': priceDisplay,
      'priceUnit': priceUnit,
      'amenities': amenities,
      'images': images,
      'logo': logo,
      'groundType': groundType,
      'format': format,
      'pitchType': pitchType,
      'courts': courts,
      'isActive': isActive,
      'isPremium': isPremium,
      'isVerified': false,
      'updatedAt': FieldValue.serverTimestamp(),
    };

    if (existingId != null) {
      await _grounds.doc(existingId).update(data);
      return existingId;
    } else {
      data['callTaps'] = 0;
      data['whatsappTaps'] = 0;
      data['websiteTaps'] = 0;
      data['rating'] = 0.0;
      data['totalReviews'] = 0;
      data['createdAt'] = FieldValue.serverTimestamp();
      final ref = await _grounds.add(data);
      return ref.id;
    }
  }

  static Future<void> toggleGroundActive(
          String groundId, bool isActive) async =>
      _grounds.doc(groundId).update({'isActive': isActive});

  static Future<void> toggleGroundPremium(
          String groundId, bool isPremium) async =>
      _grounds.doc(groundId).update({'isPremium': isPremium});

  static Future<void> deleteGround(String groundId) async {
    final slots = await _slots(groundId).get();
    final batch = _db.batch();
    for (final doc in slots.docs) batch.delete(doc.reference);
    batch.delete(_grounds.doc(groundId));
    await batch.commit();
  }

  // ════════════════════════════════════════════════════════
  //  SLOTS — Manual management per date
  // ════════════════════════════════════════════════════════

  /// Add a slot for a date
  static Future<void> addSlot({
    required String groundId,
    required String date, // "2026-05-05"
    required String startTime, // "06:00"
    required String endTime, // "07:00"
    required int rate, // 800
    required String rateDisplay, // "₹800/hr"
    String status = 'available',
  }) async {
    await _slots(groundId).doc(date).set({
      startTime: {
        'endTime': endTime,
        'status': status,
        'rate': rate,
        'rateDisplay': rateDisplay,
      }
    }, SetOptions(merge: true));
  }

  /// Toggle slot available ↔ booked
  static Future<void> toggleSlotStatus({
    required String groundId,
    required String date,
    required String startTime,
    required String currentStatus,
  }) async {
    final next = currentStatus == 'available' ? 'booked' : 'available';
    await _slots(groundId).doc(date).update({
      '$startTime.status': next,
    });
  }

  /// Delete a slot
  static Future<void> deleteSlot({
    required String groundId,
    required String date,
    required String startTime,
  }) async {
    await _slots(groundId).doc(date).update({
      startTime: FieldValue.delete(),
    });
  }

  /// Stream all slots for a date
  static Stream<List<CricSlot>> slotsStream({
    required String groundId,
    required String date,
  }) {
    return _slots(groundId).doc(date).snapshots().map((doc) {
      if (!doc.exists || doc.data() == null) return [];
      final data = doc.data() as Map<String, dynamic>;
      final list = <CricSlot>[];
      data.forEach((k, v) {
        if (v is Map) {
          list.add(CricSlot(
            startTime: k,
            endTime: v['endTime'] as String? ?? '',
            status: v['status'] as String? ?? 'available',
            rate: (v['rate'] as num?)?.toInt() ?? 0,
            rateDisplay: v['rateDisplay'] as String? ?? '',
          ));
        }
      });
      // Sort by start time
      list.sort((a, b) => a.startTime.compareTo(b.startTime));
      return list;
    });
  }

  // ════════════════════════════════════════════════════════
  //  TOURNAMENTS CRUD
  // ════════════════════════════════════════════════════════

  static Future<String> saveTournament({
    String? existingId,
    required String name,
    required String format,
    required String area,
    required String city,
    required String state,
    required String venue,
    required String address,
    required DateTime startDate,
    required DateTime endDate,
    required DateTime lastRegDate,
    required int entryFee,
    required String entryFeeDisplay,
    required String prize,
    required int prizeAmount,
    required int teamSize,
    required int totalSlots,
    required String phone,
    required String whatsapp,
    required String website,
    required String status,
    required bool isActive,
    required bool isPremium,
    required String description,
    required String rules,
  }) async {
    final data = <String, dynamic>{
      'name': name,
      'format': format,
      'area': area,
      'city': city,
      'state': state,
      'venue': venue,
      'address': address,
      'startDate': Timestamp.fromDate(startDate),
      'endDate': Timestamp.fromDate(endDate),
      'lastRegDate': Timestamp.fromDate(lastRegDate),
      'entryFee': entryFee,
      'entryFeeDisplay': entryFeeDisplay,
      'prize': prize,
      'prizeAmount': prizeAmount,
      'teamSize': teamSize,
      'totalSlots': totalSlots,
      'phone': phone,
      'whatsapp': whatsapp,
      'website': website,
      'status': status,
      'isActive': isActive,
      'isPremium': isPremium,
      'description': description,
      'rules': rules,
      'updatedAt': FieldValue.serverTimestamp(),
    };

    if (existingId != null) {
      await _tournaments.doc(existingId).update(data);
      return existingId;
    } else {
      data['filledSlots'] = 0;
      data['callTaps'] = 0;
      data['whatsappTaps'] = 0;
      data['isVerified'] = false;
      data['createdAt'] = FieldValue.serverTimestamp();
      final ref = await _tournaments.add(data);
      return ref.id;
    }
  }

  static Future<void> updateTournamentStatus(String id, String status) async =>
      _tournaments.doc(id).update({
        'status': status,
        'updatedAt': FieldValue.serverTimestamp(),
      });

  static Future<void> toggleTournamentActive(String id, bool isActive) async =>
      _tournaments.doc(id).update({'isActive': isActive});

  static Future<void> deleteTournament(String id) async =>
      _tournaments.doc(id).delete();

  // ════════════════════════════════════════════════════════
  //  ANALYTICS
  // ════════════════════════════════════════════════════════

  static Future<void> incrementGroundTap(
          String groundId, String tapType) async =>
      _grounds.doc(groundId).update({
        tapType: FieldValue.increment(1),
      });

  static Future<void> incrementTournamentTap(
          String tournamentId, String tapType) async =>
      _tournaments.doc(tournamentId).update({
        tapType: FieldValue.increment(1),
      });
}

// ─────────────────────────────────────────────────────────────
//  MODELS
// ─────────────────────────────────────────────────────────────

class CricGround {
  final String id, name, area, city, state;
  final String address, pincode;
  final double lat, lng;
  final String phone, whatsapp, website;
  final double price;
  final String priceDisplay, priceUnit;
  final List<String> amenities, images, format;
  final String logo, groundType, pitchType;
  final int courts;
  final bool isActive, isPremium, isVerified;
  final int callTaps, whatsappTaps, websiteTaps;
  final double rating;
  final int totalReviews;
  final DateTime? createdAt;

  int get totalTaps => callTaps + whatsappTaps + websiteTaps;

  const CricGround({
    required this.id,
    required this.name,
    required this.area,
    required this.city,
    required this.state,
    required this.address,
    required this.pincode,
    required this.lat,
    required this.lng,
    required this.phone,
    required this.whatsapp,
    required this.website,
    required this.price,
    required this.priceDisplay,
    required this.priceUnit,
    required this.amenities,
    required this.images,
    required this.logo,
    required this.groundType,
    required this.format,
    required this.pitchType,
    required this.courts,
    required this.isActive,
    required this.isPremium,
    required this.isVerified,
    required this.callTaps,
    required this.whatsappTaps,
    required this.websiteTaps,
    required this.rating,
    required this.totalReviews,
    required this.createdAt,
  });
}

class CricSlot {
  final String startTime;
  final String endTime;
  final String status;
  final int rate;
  final String rateDisplay;

  bool get isAvailable => status == 'available';
  bool get isBooked => status == 'booked';

  const CricSlot({
    required this.startTime,
    required this.endTime,
    required this.status,
    required this.rate,
    required this.rateDisplay,
  });
}

class CricTournament {
  final String id, name, format;
  final String area, city, state;
  final String venue, address;
  final DateTime? startDate, endDate, lastRegDate;
  final int entryFee;
  final String entryFeeDisplay, prize;
  final int prizeAmount, teamSize, totalSlots, filledSlots;
  final String phone, whatsapp, website;
  final String status;
  final bool isActive, isPremium, isVerified;
  final int callTaps, whatsappTaps;
  final String description, rules;
  final DateTime? createdAt;

  bool get isUpcoming => status == 'upcoming';
  bool get isOngoing => status == 'ongoing';
  bool get isCompleted => status == 'completed';
  bool get isFull => filledSlots >= totalSlots;
  int get slotsLeft => totalSlots - filledSlots;

  const CricTournament({
    required this.id,
    required this.name,
    required this.format,
    required this.area,
    required this.city,
    required this.state,
    required this.venue,
    required this.address,
    required this.startDate,
    required this.endDate,
    required this.lastRegDate,
    required this.entryFee,
    required this.entryFeeDisplay,
    required this.prize,
    required this.prizeAmount,
    required this.teamSize,
    required this.totalSlots,
    required this.filledSlots,
    required this.phone,
    required this.whatsapp,
    required this.website,
    required this.status,
    required this.isActive,
    required this.isPremium,
    required this.isVerified,
    required this.callTaps,
    required this.whatsappTaps,
    required this.description,
    required this.rules,
    required this.createdAt,
  });
}
