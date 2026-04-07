import 'dart:convert';

// Helper function to safely parse double from various types
double _parseDouble(dynamic value) {
  if (value == null) return 0.0;
  if (value is double) return value;
  if (value is int) return value.toDouble();
  if (value is String) {
    return double.tryParse(value) ?? 0.0;
  }
  return 0.0;
}

class MemberHistoryModels {
  final String memberId;
  final String namaLengkap;
  final String email;
  final String mobilePhone;
  final String? photo;
  final String? tanggalLahir;
  final String? jenisKelamin;
  final String? pekerjaan;
  final String memberLevel;
  final double totalSpending;
  final int justPoints;
  final bool isExclusiveMember;
  final bool isActive;

  MemberHistoryModels({
    required this.memberId,
    required this.namaLengkap,
    required this.email,
    required this.mobilePhone,
    this.photo,
    this.tanggalLahir,
    this.jenisKelamin,
    this.pekerjaan,
    required this.memberLevel,
    required this.totalSpending,
    required this.justPoints,
    required this.isExclusiveMember,
    required this.isActive,
  });

  factory MemberHistoryModels.fromJson(Map<String, dynamic> json) {
    return MemberHistoryModels(
      memberId: json['member_id'] ?? '',
      namaLengkap: json['nama_lengkap'] ?? '',
      email: json['email'] ?? '',
      mobilePhone: json['mobile_phone'] ?? '',
      photo: json['photo'],
      tanggalLahir: json['tanggal_lahir'],
      jenisKelamin: json['jenis_kelamin'],
      pekerjaan: json['pekerjaan'],
      memberLevel: json['member_level'] ?? 'silver',
      totalSpending: _parseDouble(json['total_spending']),
      justPoints: json['just_points'] ?? 0,
      isExclusiveMember: json['is_exclusive_member'] ?? false,
      isActive: json['is_active'] ?? false,
    );
  }
}

class OrderHistoryModel {
  final String id;
  final String orderId;
  final double grandTotal;
  final String grandTotalFormatted;
  final double subTotal;
  final double tax;
  final double serviceCharge;
  final double discount;
  final int pointsEarned;
  final int pointsRedeemed;
  final String outletName;
  final String? kodeOutlet;
  final String createdAt;
  final String createdAtFormatted;

  OrderHistoryModel({
    required this.id,
    required this.orderId,
    required this.grandTotal,
    required this.grandTotalFormatted,
    required this.subTotal,
    required this.tax,
    required this.serviceCharge,
    required this.discount,
    required this.pointsEarned,
    required this.pointsRedeemed,
    required this.outletName,
    this.kodeOutlet,
    required this.createdAt,
    required this.createdAtFormatted,
  });

  factory OrderHistoryModel.fromJson(Map<String, dynamic> json) {
    return OrderHistoryModel(
      id: json['id']?.toString() ?? '',
      orderId: json['order_id']?.toString() ?? '',
      grandTotal: _parseDouble(json['grand_total']),
      grandTotalFormatted: json['grand_total_formatted'] ?? 'Rp 0',
      subTotal: _parseDouble(json['sub_total']),
      tax: _parseDouble(json['tax']),
      serviceCharge: _parseDouble(json['service_charge']),
      discount: _parseDouble(json['discount']),
      pointsEarned: json['points_earned'] ?? 0,
      pointsRedeemed: json['points_redeemed'] ?? 0,
      outletName: json['outlet_name'] ?? 'Outlet Tidak Diketahui',
      kodeOutlet: json['kode_outlet'],
      createdAt: json['created_at'] ?? '',
      createdAtFormatted: json['created_at_formatted'] ?? '',
    );
  }
}

class OrderItemModel {
  final String id;
  final String itemId;
  final String itemName;
  final int quantity;
  final double price;
  final String priceFormatted;
  final double subTotal;
  final String subTotalFormatted;
  final String? notes;
  final Map<String, dynamic>? modifiers;

  OrderItemModel({
    required this.id,
    required this.itemId,
    required this.itemName,
    required this.quantity,
    required this.price,
    required this.priceFormatted,
    required this.subTotal,
    required this.subTotalFormatted,
    this.notes,
    this.modifiers,
  });

  factory OrderItemModel.fromJson(Map<String, dynamic> json) {
    Map<String, dynamic>? parsedModifiers;
    try {
      if (json['modifiers'] != null && json['modifiers'].toString().isNotEmpty) {
        if (json['modifiers'] is String) {
          parsedModifiers = jsonDecode(json['modifiers']) as Map<String, dynamic>;
        } else if (json['modifiers'] is Map) {
          parsedModifiers = json['modifiers'] as Map<String, dynamic>;
        }
      }
    } catch (e) {
      parsedModifiers = null;
    }

    return OrderItemModel(
      id: json['id']?.toString() ?? '',
      itemId: json['item_id']?.toString() ?? '',
      itemName: json['item_name'] ?? '',
      quantity: json['quantity'] ?? 0,
      price: _parseDouble(json['price']),
      priceFormatted: json['price_formatted'] ?? 'Rp 0',
      subTotal: _parseDouble(json['sub_total']),
      subTotalFormatted: json['sub_total_formatted'] ?? 'Rp 0',
      notes: json['notes'],
      modifiers: parsedModifiers,
    );
  }
}

class OrderDetailModel {
  final String id;
  final String orderId;
  final String? memberId;
  final double grandTotal;
  final String grandTotalFormatted;
  final double subTotal;
  final double tax;
  final double serviceCharge;
  final double discount;
  final int pointsEarned;
  final int pointsRedeemed;
  final String outletName;
  final String? kodeOutlet;
  final String status;
  final String? paymentMethod;
  final String createdAt;
  final String createdAtFormatted;
  final List<OrderItemModel> items;

  OrderDetailModel({
    required this.id,
    required this.orderId,
    this.memberId,
    required this.grandTotal,
    required this.grandTotalFormatted,
    required this.subTotal,
    required this.tax,
    required this.serviceCharge,
    required this.discount,
    required this.pointsEarned,
    required this.pointsRedeemed,
    required this.outletName,
    this.kodeOutlet,
    required this.status,
    this.paymentMethod,
    required this.createdAt,
    required this.createdAtFormatted,
    required this.items,
  });

  factory OrderDetailModel.fromJson(Map<String, dynamic> json) {
    return OrderDetailModel(
      id: json['id']?.toString() ?? '',
      orderId: json['order_id']?.toString() ?? '',
      memberId: json['member_id'],
      grandTotal: _parseDouble(json['grand_total']),
      grandTotalFormatted: json['grand_total_formatted'] ?? 'Rp 0',
      subTotal: _parseDouble(json['sub_total']),
      tax: _parseDouble(json['tax']),
      serviceCharge: _parseDouble(json['service_charge']),
      discount: _parseDouble(json['discount']),
      pointsEarned: json['points_earned'] ?? 0,
      pointsRedeemed: json['points_redeemed'] ?? 0,
      outletName: json['outlet_name'] ?? 'Outlet Tidak Diketahui',
      kodeOutlet: json['kode_outlet'],
      status: json['status'] ?? '',
      paymentMethod: json['payment_method'],
      createdAt: json['created_at'] ?? '',
      createdAtFormatted: json['created_at_formatted'] ?? '',
      items: (json['items'] as List<dynamic>?)
              ?.map((item) => OrderItemModel.fromJson(item))
              .toList() ??
          [],
    );
  }
}

class FavoriteItemModel {
  final String itemId;
  final String itemName;
  final int orderCount;
  final int totalQuantity;
  final double avgPrice;
  final String avgPriceFormatted;
  final String lastOrdered;
  final String lastOrderedFormatted;
  final List<PopularModifier>? popularModifiers;

  FavoriteItemModel({
    required this.itemId,
    required this.itemName,
    required this.orderCount,
    required this.totalQuantity,
    required this.avgPrice,
    required this.avgPriceFormatted,
    required this.lastOrdered,
    required this.lastOrderedFormatted,
    this.popularModifiers,
  });

  factory FavoriteItemModel.fromJson(Map<String, dynamic> json) {
    List<PopularModifier>? modifiers;
    if (json['popular_modifiers'] != null) {
      modifiers = (json['popular_modifiers'] as List<dynamic>)
          .map((m) => PopularModifier.fromJson(m))
          .toList();
    }

    return FavoriteItemModel(
      itemId: json['item_id'] ?? '',
      itemName: json['item_name'] ?? '',
      orderCount: json['order_count'] ?? 0,
      totalQuantity: json['total_quantity'] ?? 0,
      avgPrice: _parseDouble(json['avg_price']),
      avgPriceFormatted: json['avg_price_formatted'] ?? 'Rp 0',
      lastOrdered: json['last_ordered'] ?? '',
      lastOrderedFormatted: json['last_ordered_formatted'] ?? '',
      popularModifiers: modifiers,
    );
  }
}

class PopularModifier {
  final String category;
  final String choice;
  final int frequency;

  PopularModifier({
    required this.category,
    required this.choice,
    required this.frequency,
  });

  factory PopularModifier.fromJson(Map<String, dynamic> json) {
    return PopularModifier(
      category: json['category'] ?? '',
      choice: json['choice'] ?? '',
      frequency: json['frequency'] ?? 0,
    );
  }
}

class FavoriteOutletModel {
  final String? kodeOutlet;
  final String namaOutlet;
  final int visitCount;
  final double totalSpent;
  final String totalSpentFormatted;
  final String lastVisit;
  final String lastVisitFormatted;

  FavoriteOutletModel({
    this.kodeOutlet,
    required this.namaOutlet,
    required this.visitCount,
    required this.totalSpent,
    required this.totalSpentFormatted,
    required this.lastVisit,
    required this.lastVisitFormatted,
  });

  factory FavoriteOutletModel.fromJson(Map<String, dynamic> json) {
    return FavoriteOutletModel(
      kodeOutlet: json['kode_outlet'],
      namaOutlet: json['nama_outlet'] ?? 'Outlet Tidak Diketahui',
      visitCount: json['visit_count'] ?? 0,
      totalSpent: _parseDouble(json['total_spent']),
      totalSpentFormatted: json['total_spent_formatted'] ?? 'Rp 0',
      lastVisit: json['last_visit'] ?? '',
      lastVisitFormatted: json['last_visit_formatted'] ?? '',
    );
  }
}

class MemberPreferencesModel {
  final List<FavoriteItemModel> favoriteItems;
  final FavoriteOutletModel? favoriteOutlet;

  MemberPreferencesModel({
    required this.favoriteItems,
    this.favoriteOutlet,
  });

  factory MemberPreferencesModel.fromJson(Map<String, dynamic> json) {
    return MemberPreferencesModel(
      favoriteItems: (json['favorite_items'] as List<dynamic>?)
              ?.map((item) => FavoriteItemModel.fromJson(item))
              .toList() ??
          [],
      favoriteOutlet: json['favorite_outlet'] != null
          ? FavoriteOutletModel.fromJson(json['favorite_outlet'])
          : null,
    );
  }
}
