import 'package:cloud_firestore/cloud_firestore.dart';

/// Model representing a Payment Method (e.g. bKash, Nagad, Rocket)
class PaymentMethodModel {
  final String id;
  final String name;
  final String number;
  final String iconUrl;
  final String status; // 'ON' or 'OFF'
  final String instructions;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  PaymentMethodModel({
    required this.id,
    required this.name,
    required this.number,
    this.iconUrl = '',
    this.status = 'ON',
    this.instructions = "'সেন্ড মানি' দিয়ে পরিশোধ করুন",
    this.createdAt,
    this.updatedAt,
  });

  bool get isActive => status.toUpperCase() == 'ON';

  factory PaymentMethodModel.fromFirestore(DocumentSnapshot doc) {
    final data = (doc.data() as Map<String, dynamic>?) ?? {};
    return PaymentMethodModel.fromMap(data, doc.id);
  }

  factory PaymentMethodModel.fromMap(Map<String, dynamic> data, [String? id]) {
    final rawIcon = (data['iconUrl'] ??
            data['imageUrl'] ??
            data['logoUrl'] ??
            data['logo'] ??
            data['image'] ??
            data['icon'] ??
            data['picture'] ??
            data['pictureUrl'] ??
            data['photoUrl'] ??
            '')
        .toString()
        .trim();

    return PaymentMethodModel(
      id: id ?? data['id'] ?? '',
      name: (data['name'] ?? '').toString().trim(),
      number: (data['number'] ?? '').toString().trim(),
      iconUrl: rawIcon,
      status: (data['status'] ?? 'ON').toString().toUpperCase(),
      instructions: (data['instructions'] ?? data['note'] ?? "'সেন্ড মানি' দিয়ে পরিশোধ করুন").toString(),
      createdAt: (data['createdAt'] is Timestamp)
          ? (data['createdAt'] as Timestamp).toDate()
          : null,
      updatedAt: (data['updatedAt'] is Timestamp)
          ? (data['updatedAt'] as Timestamp).toDate()
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'number': number,
      'iconUrl': iconUrl,
      'imageUrl': iconUrl,
      'logo': iconUrl,
      'status': status,
      'instructions': instructions,
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }
}

/// Model representing Diamond Recharge Package
class RechargePackageModel {
  final String id;
  final num amount; // In BDT
  final int? _diamondAmount;
  final int? _bonusDiamonds;
  final String status; // 'active' or 'inactive'
  final int? _sortOrder;

  RechargePackageModel({
    required this.id,
    required this.amount,
    int? diamondAmount,
    int? bonusDiamonds,
    this.status = 'active',
    int? sortOrder,
  })  : _diamondAmount = diamondAmount ?? 0,
        _bonusDiamonds = bonusDiamonds ?? 0,
        _sortOrder = sortOrder ?? 0;

  int get diamondAmount => _diamondAmount ?? 0;
  num get bdtPrice => amount;
  int get bonusDiamonds => _bonusDiamonds ?? 0;
  int get sortOrder => _sortOrder ?? 0;
  bool get isActive => status.toLowerCase() == 'active';
  int get totalDiamonds => diamondAmount + bonusDiamonds;
  double get bonusPercent => diamondAmount > 0 ? (bonusDiamonds / diamondAmount) * 100 : 0;
  String get bonusPercentText => bonusPercent > 0 ? '+${bonusPercent.toStringAsFixed(bonusPercent % 1 == 0 ? 0 : 1)}%' : '';

  factory RechargePackageModel.fromFirestore(DocumentSnapshot doc) {
    final data = (doc.data() as Map<String, dynamic>?) ?? {};
    return RechargePackageModel.fromMap(data, doc.id);
  }

  factory RechargePackageModel.fromMap(Map<String, dynamic> data, [String? id]) {
    final rawAmount = data['amount'];
    final parsedAmount = rawAmount is num
        ? rawAmount
        : num.tryParse(rawAmount?.toString() ?? '') ?? 0;

    final rawDiamonds = data['diamondAmount'] ?? data['diamonds'];
    final parsedDiamonds = rawDiamonds is num
        ? rawDiamonds.toInt()
        : int.tryParse(rawDiamonds?.toString() ?? '') ?? 0;

    final rawBonus = data['bonusDiamonds'];
    final parsedBonus = rawBonus is num
        ? rawBonus.toInt()
        : int.tryParse(rawBonus?.toString() ?? '') ?? 0;

    final rawSort = data['sortOrder'];
    final parsedSort = rawSort is num
        ? rawSort.toInt()
        : int.tryParse(rawSort?.toString() ?? '') ?? 0;

    return RechargePackageModel(
      id: id ?? data['id'] ?? '',
      amount: parsedAmount,
      diamondAmount: parsedDiamonds,
      bonusDiamonds: parsedBonus,
      status: data['status'] ?? 'active',
      sortOrder: parsedSort,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'amount': amount,
      'diamondAmount': diamondAmount,
      'bonusDiamonds': bonusDiamonds,
      'status': status,
      'sortOrder': sortOrder,
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }
}

/// Model representing a Recharge Order Request
class RechargeOrderModel {
  final String orderId;
  final String userId;
  final String userName;
  final String userPhoto;
  final String searchId;
  final String userPhone;
  final num amount; // BDT
  final int? _diamondAmount;
  final int? _bonusDiamonds;
  final String paymentMethod;
  final String paymentNumber;
  final String transactionId; // TrxID
  final String status; // 'Pending', 'Approved', 'Rejected'
  final DateTime? createdAt;
  final DateTime? verifiedAt;
  final String? verifiedBy;
  final String? rejectionReason;

  RechargeOrderModel({
    required this.orderId,
    required this.userId,
    this.userName = '',
    this.userPhoto = '',
    this.searchId = '',
    this.userPhone = '',
    required this.amount,
    int? diamondAmount,
    int? bonusDiamonds,
    required this.paymentMethod,
    required this.paymentNumber,
    required this.transactionId,
    this.status = 'Pending',
    this.createdAt,
    this.verifiedAt,
    this.verifiedBy,
    this.rejectionReason,
  })  : _diamondAmount = diamondAmount ?? 0,
        _bonusDiamonds = bonusDiamonds ?? 0;

  int get diamondAmount => _diamondAmount ?? 0;
  int get bonusDiamonds => _bonusDiamonds ?? 0;
  bool get isPending => status.toLowerCase() == 'pending';
  bool get isApproved => status.toLowerCase() == 'approved';
  bool get isRejected => status.toLowerCase() == 'rejected';
  int get totalDiamonds => diamondAmount + bonusDiamonds;

  factory RechargeOrderModel.fromFirestore(DocumentSnapshot doc) {
    final data = (doc.data() as Map<String, dynamic>?) ?? {};
    return RechargeOrderModel.fromMap(data, doc.id);
  }

  factory RechargeOrderModel.fromMap(Map<String, dynamic> data, [String? id]) {
    final rawAmount = data['amount'];
    final parsedAmount = rawAmount is num
        ? rawAmount
        : num.tryParse(rawAmount?.toString() ?? '') ?? 0;

    final rawDiamonds = data['diamondAmount'] ?? data['diamonds'];
    final parsedDiamonds = rawDiamonds is num
        ? rawDiamonds.toInt()
        : int.tryParse(rawDiamonds?.toString() ?? '') ?? 0;

    final rawBonus = data['bonusDiamonds'];
    final parsedBonus = rawBonus is num
        ? rawBonus.toInt()
        : int.tryParse(rawBonus?.toString() ?? '') ?? 0;

    return RechargeOrderModel(
      orderId: id ?? data['orderId'] ?? '',
      userId: data['userId'] ?? '',
      userName: data['userName'] ?? '',
      userPhoto: data['userPhoto'] ?? '',
      searchId: (data['searchId'] ?? '').toString(),
      userPhone: (data['userPhone'] ?? data['phone'] ?? data['number'] ?? '').toString(),
      amount: parsedAmount,
      diamondAmount: parsedDiamonds,
      bonusDiamonds: parsedBonus,
      paymentMethod: data['paymentMethod'] ?? '',
      paymentNumber: data['paymentNumber'] ?? '',
      transactionId: (data['transactionId'] ?? '').toString().trim(),
      status: data['status'] ?? 'Pending',
      createdAt: (data['createdAt'] is Timestamp)
          ? (data['createdAt'] as Timestamp).toDate()
          : null,
      verifiedAt: (data['verifiedAt'] is Timestamp)
          ? (data['verifiedAt'] as Timestamp).toDate()
          : null,
      verifiedBy: data['verifiedBy'],
      rejectionReason: data['rejectionReason'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'orderId': orderId,
      'userId': userId,
      'userName': userName,
      'userPhoto': userPhoto,
      'searchId': searchId,
      'userPhone': userPhone,
      'amount': amount,
      'diamondAmount': diamondAmount,
      'bonusDiamonds': bonusDiamonds,
      'paymentMethod': paymentMethod,
      'paymentNumber': paymentNumber,
      'transactionId': transactionId,
      'status': status,
      'createdAt': createdAt != null
          ? Timestamp.fromDate(createdAt!)
          : FieldValue.serverTimestamp(),
      'verifiedAt':
          verifiedAt != null ? Timestamp.fromDate(verifiedAt!) : null,
      'verifiedBy': verifiedBy,
      'rejectionReason': rejectionReason,
    };
  }
}

/// Model representing a Weekly Recharge Benefit Tier in mobile app
class WeeklyRechargeBenefitModel {
  final String id;
  final String tierName;
  final int targetDiamonds;
  final String itemId;
  final String itemName;
  final String itemIcon;
  final String itemType;
  final int validityDays;
  final int bonusDiamonds;
  final DateTime? endDate;
  final int order;
  final bool isActive;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  WeeklyRechargeBenefitModel({
    required this.id,
    this.tierName = '',
    required this.targetDiamonds,
    required this.itemId,
    required this.itemName,
    this.itemIcon = '',
    this.itemType = 'avatarFrame',
    this.validityDays = 7,
    this.bonusDiamonds = 0,
    this.endDate,
    this.order = 1,
    this.isActive = true,
    this.createdAt,
    this.updatedAt,
  });

  factory WeeklyRechargeBenefitModel.fromMap(Map<String, dynamic> data, String id) {
    return WeeklyRechargeBenefitModel(
      id: id,
      tierName: data['tierName'] ?? '',
      targetDiamonds: (data['targetDiamonds'] as num?)?.toInt() ?? 0,
      itemId: data['itemId'] ?? '',
      itemName: data['itemName'] ?? '',
      itemIcon: data['itemIcon'] ?? '',
      itemType: data['itemType'] ?? 'avatarFrame',
      validityDays: (data['validityDays'] as num?)?.toInt() ?? 7,
      bonusDiamonds: (data['bonusDiamonds'] as num?)?.toInt() ?? 0,
      endDate: (data['endDate'] is Timestamp)
          ? (data['endDate'] as Timestamp).toDate()
          : null,
      order: (data['order'] as num?)?.toInt() ?? 1,
      isActive: data['isActive'] ?? true,
      createdAt: (data['createdAt'] is Timestamp)
          ? (data['createdAt'] as Timestamp).toDate()
          : null,
      updatedAt: (data['updatedAt'] is Timestamp)
          ? (data['updatedAt'] as Timestamp).toDate()
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'tierName': tierName,
      'targetDiamonds': targetDiamonds,
      'itemId': itemId,
      'itemName': itemName,
      'itemIcon': itemIcon,
      'itemType': itemType,
      'validityDays': validityDays,
      'bonusDiamonds': bonusDiamonds,
      'endDate': endDate != null ? Timestamp.fromDate(endDate!) : null,
      'order': order,
      'isActive': isActive,
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }
}
