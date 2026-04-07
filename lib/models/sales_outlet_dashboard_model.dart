// Helper functions for safe type conversion
double _toDouble(dynamic value) {
  if (value == null) return 0.0;
  if (value is double) return value;
  if (value is int) return value.toDouble();
  if (value is String) {
    return double.tryParse(value) ?? 0.0;
  }
  return 0.0;
}

int _toInt(dynamic value) {
  if (value == null) return 0;
  if (value is int) return value;
  if (value is double) return value.toInt();
  if (value is String) {
    return int.tryParse(value) ?? 0;
  }
  return 0;
}

class SalesOutletDashboardData {
  final OverviewMetrics overview;
  final List<SalesTrend> salesTrend;
  final List<TopItem> topItems;
  final List<PaymentMethod> paymentMethods;
  final List<HourlySales> hourlySales;
  final List<RecentOrder> recentOrders;
  final PromoUsage promoUsage;
  final BankPromoDiscount bankPromoDiscount;
  final AverageOrderValue avgOrderValue;
  final List<PeakHour> peakHours;
  final LunchDinnerOrders lunchDinnerOrders;
  final WeekdayWeekendRevenue weekdayWeekendRevenue;
  final Map<String, RevenuePerOutletRegion> revenuePerOutlet;
  final Map<String, RevenuePerOutletRegion> revenuePerOutletLunchDinner;
  final Map<String, RevenuePerOutletRegion> revenuePerOutletWeekendWeekday;
  final RevenuePerRegion revenuePerRegion;

  SalesOutletDashboardData({
    required this.overview,
    required this.salesTrend,
    required this.topItems,
    required this.paymentMethods,
    required this.hourlySales,
    required this.recentOrders,
    required this.promoUsage,
    required this.bankPromoDiscount,
    required this.avgOrderValue,
    required this.peakHours,
    required this.lunchDinnerOrders,
    required this.weekdayWeekendRevenue,
    required this.revenuePerOutlet,
    required this.revenuePerOutletLunchDinner,
    required this.revenuePerOutletWeekendWeekday,
    required this.revenuePerRegion,
  });

  factory SalesOutletDashboardData.fromJson(Map<String, dynamic> json) {
    return SalesOutletDashboardData(
      overview: OverviewMetrics.fromJson(json['overview'] ?? {}),
      salesTrend: (json['salesTrend'] as List<dynamic>?)
              ?.map((e) => SalesTrend.fromJson(e))
              .toList() ??
          [],
      topItems: (json['topItems'] as List<dynamic>?)
              ?.map((e) => TopItem.fromJson(e))
              .toList() ??
          [],
      paymentMethods: (json['paymentMethods'] as List<dynamic>?)
              ?.map((e) => PaymentMethod.fromJson(e))
              .toList() ??
          [],
      hourlySales: (json['hourlySales'] as List<dynamic>?)
              ?.map((e) => HourlySales.fromJson(e))
              .toList() ??
          [],
      recentOrders: (json['recentOrders'] as List<dynamic>?)
              ?.map((e) => RecentOrder.fromJson(e))
              .toList() ??
          [],
      promoUsage: PromoUsage.fromJson(json['promoUsage'] ?? {}),
      bankPromoDiscount: BankPromoDiscount.fromJson(json['bankPromoDiscount'] ?? {}),
      avgOrderValue: AverageOrderValue.fromJson(json['avgOrderValue'] ?? {}),
      peakHours: (json['peakHours'] as List<dynamic>?)
              ?.map((e) => PeakHour.fromJson(e))
              .toList() ??
          [],
      lunchDinnerOrders: LunchDinnerOrders.fromJson(json['lunchDinnerOrders'] ?? {}),
      weekdayWeekendRevenue: WeekdayWeekendRevenue.fromJson(json['weekdayWeekendRevenue'] ?? {}),
      revenuePerOutlet: (json['revenuePerOutlet'] as Map<String, dynamic>?)
              ?.map((key, value) => MapEntry(key, RevenuePerOutletRegion.fromJson(value))) ??
          {},
      revenuePerOutletLunchDinner: (json['revenuePerOutletLunchDinner'] as Map<String, dynamic>?)
              ?.map((key, value) => MapEntry(key, RevenuePerOutletRegion.fromJson(value))) ??
          {},
      revenuePerOutletWeekendWeekday: (json['revenuePerOutletWeekendWeekday'] as Map<String, dynamic>?)
              ?.map((key, value) => MapEntry(key, RevenuePerOutletRegion.fromJson(value))) ??
          {},
      revenuePerRegion: RevenuePerRegion.fromJson(json['revenuePerRegion'] ?? {}),
    );
  }
}

class OverviewMetrics {
  final int totalOrders;
  final double totalRevenue;
  final double avgOrderValue;
  final int totalCustomers;
  final double avgPaxPerOrder;
  final double avgCheck;
  final double totalDiscount;
  final double totalServiceCharge;
  final double totalCommissionFee;
  final double totalManualDiscount;
  final double revenueGrowth;
  final double orderGrowth;

  OverviewMetrics({
    required this.totalOrders,
    required this.totalRevenue,
    required this.avgOrderValue,
    required this.totalCustomers,
    required this.avgPaxPerOrder,
    required this.avgCheck,
    required this.totalDiscount,
    required this.totalServiceCharge,
    required this.totalCommissionFee,
    required this.totalManualDiscount,
    required this.revenueGrowth,
    required this.orderGrowth,
  });

  factory OverviewMetrics.fromJson(Map<String, dynamic> json) {
    return OverviewMetrics(
      totalOrders: _toInt(json['total_orders']),
      totalRevenue: _toDouble(json['total_revenue']),
      avgOrderValue: _toDouble(json['avg_order_value']),
      totalCustomers: _toInt(json['total_customers']),
      avgPaxPerOrder: _toDouble(json['avg_pax_per_order']),
      avgCheck: _toDouble(json['avg_check']),
      totalDiscount: _toDouble(json['total_discount']),
      totalServiceCharge: _toDouble(json['total_service_charge']),
      totalCommissionFee: _toDouble(json['total_commission_fee']),
      totalManualDiscount: _toDouble(json['total_manual_discount']),
      revenueGrowth: _toDouble(json['revenue_growth']),
      orderGrowth: _toDouble(json['order_growth']),
    );
  }
}

class SalesTrend {
  final String period;
  final int orders;
  final double revenue;
  final double avgOrderValue;
  final int customers;

  SalesTrend({
    required this.period,
    required this.orders,
    required this.revenue,
    required this.avgOrderValue,
    required this.customers,
  });

  factory SalesTrend.fromJson(Map<String, dynamic> json) {
    return SalesTrend(
      period: json['period']?.toString() ?? '',
      orders: _toInt(json['orders']),
      revenue: _toDouble(json['revenue']),
      avgOrderValue: _toDouble(json['avg_order_value']),
      customers: _toInt(json['customers']),
    );
  }
}

class TopItem {
  final String itemName;
  final int totalQty;
  final double totalRevenue;
  final int orderCount;
  final double avgPrice;

  TopItem({
    required this.itemName,
    required this.totalQty,
    required this.totalRevenue,
    required this.orderCount,
    required this.avgPrice,
  });

  factory TopItem.fromJson(Map<String, dynamic> json) {
    return TopItem(
      itemName: json['item_name']?.toString() ?? '',
      totalQty: _toInt(json['total_qty']),
      totalRevenue: _toDouble(json['total_revenue']),
      orderCount: _toInt(json['order_count']),
      avgPrice: _toDouble(json['avg_price']),
    );
  }
}

class PaymentMethod {
  final String paymentCode;
  final int transactionCount;
  final double totalAmount;
  final double avgAmount;
  final List<PaymentMethodDetail> details;

  PaymentMethod({
    required this.paymentCode,
    required this.transactionCount,
    required this.totalAmount,
    required this.avgAmount,
    required this.details,
  });

  factory PaymentMethod.fromJson(Map<String, dynamic> json) {
    return PaymentMethod(
      paymentCode: json['payment_code']?.toString() ?? '',
      transactionCount: _toInt(json['transaction_count']),
      totalAmount: _toDouble(json['total_amount']),
      avgAmount: _toDouble(json['avg_amount']),
      details: (json['details'] as List<dynamic>?)
              ?.map((e) => PaymentMethodDetail.fromJson(e))
              .toList() ??
          [],
    );
  }
}

class PaymentMethodDetail {
  final String paymentCode;
  final String? paymentType;
  final int transactionCount;
  final double totalAmount;
  final double avgAmount;

  PaymentMethodDetail({
    required this.paymentCode,
    this.paymentType,
    required this.transactionCount,
    required this.totalAmount,
    required this.avgAmount,
  });

  factory PaymentMethodDetail.fromJson(Map<String, dynamic> json) {
    return PaymentMethodDetail(
      paymentCode: json['payment_code']?.toString() ?? '',
      paymentType: json['payment_type']?.toString(),
      transactionCount: _toInt(json['transaction_count']),
      totalAmount: _toDouble(json['total_amount']),
      avgAmount: _toDouble(json['avg_amount']),
    );
  }
}

class HourlySales {
  final int hour;
  final int orders;
  final double revenue;
  final double avgOrderValue;

  HourlySales({
    required this.hour,
    required this.orders,
    required this.revenue,
    required this.avgOrderValue,
  });

  factory HourlySales.fromJson(Map<String, dynamic> json) {
    return HourlySales(
      hour: _toInt(json['hour']),
      orders: _toInt(json['orders']),
      revenue: _toDouble(json['revenue']),
      avgOrderValue: _toDouble(json['avg_order_value']),
    );
  }
}

class RecentOrder {
  final int id;
  final String nomor;
  final String? table;
  final String? memberName;
  final int pax;
  final double grandTotal;
  final String status;
  final String createdAt;
  final String? waiters;
  final String kodeOutlet;
  final String outletName;

  RecentOrder({
    required this.id,
    required this.nomor,
    this.table,
    this.memberName,
    required this.pax,
    required this.grandTotal,
    required this.status,
    required this.createdAt,
    this.waiters,
    required this.kodeOutlet,
    required this.outletName,
  });

  factory RecentOrder.fromJson(Map<String, dynamic> json) {
    return RecentOrder(
      id: _toInt(json['id']),
      nomor: json['nomor']?.toString() ?? '',
      table: json['table']?.toString(),
      memberName: json['member_name']?.toString(),
      pax: _toInt(json['pax']),
      grandTotal: _toDouble(json['grand_total']),
      status: json['status']?.toString() ?? '',
      createdAt: json['created_at']?.toString() ?? '',
      waiters: json['waiters']?.toString(),
      kodeOutlet: json['kode_outlet']?.toString() ?? '',
      outletName: json['outlet_name']?.toString() ?? '',
    );
  }
}

class PromoUsage {
  final int ordersWithPromo;
  final int totalPromoUsage;
  final double promoUsagePercentage;

  PromoUsage({
    required this.ordersWithPromo,
    required this.totalPromoUsage,
    required this.promoUsagePercentage,
  });

  factory PromoUsage.fromJson(Map<String, dynamic> json) {
    return PromoUsage(
      ordersWithPromo: _toInt(json['orders_with_promo']),
      totalPromoUsage: _toInt(json['total_promo_usage']),
      promoUsagePercentage: _toDouble(json['promo_usage_percentage']),
    );
  }
}

class BankPromoDiscount {
  final int ordersWithBankPromo;
  final double totalBankDiscountAmount;
  final double avgBankDiscountAmount;
  final double bankPromoPercentage;

  BankPromoDiscount({
    required this.ordersWithBankPromo,
    required this.totalBankDiscountAmount,
    required this.avgBankDiscountAmount,
    required this.bankPromoPercentage,
  });

  factory BankPromoDiscount.fromJson(Map<String, dynamic> json) {
    return BankPromoDiscount(
      ordersWithBankPromo: _toInt(json['orders_with_bank_promo']),
      totalBankDiscountAmount: _toDouble(json['total_bank_discount_amount']),
      avgBankDiscountAmount: _toDouble(json['avg_bank_discount_amount']),
      bankPromoPercentage: _toDouble(json['bank_promo_percentage']),
    );
  }
}

class AverageOrderValue {
  final double avgOrderValue;
  final double minOrderValue;
  final double maxOrderValue;
  final double medianOrderValue;

  AverageOrderValue({
    required this.avgOrderValue,
    required this.minOrderValue,
    required this.maxOrderValue,
    required this.medianOrderValue,
  });

  factory AverageOrderValue.fromJson(Map<String, dynamic> json) {
    return AverageOrderValue(
      avgOrderValue: _toDouble(json['avg_order_value']),
      minOrderValue: _toDouble(json['min_order_value']),
      maxOrderValue: _toDouble(json['max_order_value']),
      medianOrderValue: _toDouble(json['median_order_value']),
    );
  }
}

class PeakHour {
  final int hour;
  final int orderCount;
  final double revenue;
  final double avgOrderValue;
  final int totalCustomers;

  PeakHour({
    required this.hour,
    required this.orderCount,
    required this.revenue,
    required this.avgOrderValue,
    required this.totalCustomers,
  });

  factory PeakHour.fromJson(Map<String, dynamic> json) {
    return PeakHour(
      hour: _toInt(json['hour']),
      orderCount: _toInt(json['order_count']),
      revenue: _toDouble(json['revenue']),
      avgOrderValue: _toDouble(json['avg_order_value']),
      totalCustomers: _toInt(json['total_customers']),
    );
  }
}

class LunchDinnerOrders {
  final LunchDinnerData lunch;
  final LunchDinnerData dinner;

  LunchDinnerOrders({
    required this.lunch,
    required this.dinner,
  });

  factory LunchDinnerOrders.fromJson(Map<String, dynamic> json) {
    return LunchDinnerOrders(
      lunch: LunchDinnerData.fromJson(json['lunch'] ?? {}),
      dinner: LunchDinnerData.fromJson(json['dinner'] ?? {}),
    );
  }
}

class LunchDinnerData {
  final int orderCount;
  final double totalRevenue;
  final int totalPax;
  final double avgOrderValue;

  LunchDinnerData({
    required this.orderCount,
    required this.totalRevenue,
    required this.totalPax,
    required this.avgOrderValue,
  });

  factory LunchDinnerData.fromJson(Map<String, dynamic> json) {
    return LunchDinnerData(
      orderCount: _toInt(json['order_count']),
      totalRevenue: _toDouble(json['total_revenue']),
      totalPax: _toInt(json['total_pax']),
      avgOrderValue: _toDouble(json['avg_order_value']),
    );
  }
}

class WeekdayWeekendRevenue {
  final WeekdayWeekendData weekday;
  final WeekdayWeekendData weekend;

  WeekdayWeekendRevenue({
    required this.weekday,
    required this.weekend,
  });

  factory WeekdayWeekendRevenue.fromJson(Map<String, dynamic> json) {
    return WeekdayWeekendRevenue(
      weekday: WeekdayWeekendData.fromJson(json['weekday'] ?? {}),
      weekend: WeekdayWeekendData.fromJson(json['weekend'] ?? {}),
    );
  }
}

class WeekdayWeekendData {
  final int orderCount;
  final double totalRevenue;
  final int totalPax;
  final double avgOrderValue;

  WeekdayWeekendData({
    required this.orderCount,
    required this.totalRevenue,
    required this.totalPax,
    required this.avgOrderValue,
  });

  factory WeekdayWeekendData.fromJson(Map<String, dynamic> json) {
    return WeekdayWeekendData(
      orderCount: _toInt(json['order_count']),
      totalRevenue: _toDouble(json['total_revenue']),
      totalPax: _toInt(json['total_pax']),
      avgOrderValue: _toDouble(json['avg_order_value']),
    );
  }
}

class RevenuePerOutletRegion {
  final String regionCode;
  final List<OutletRevenue> outlets;
  final double totalRevenue;
  final int totalOrders;
  final int totalPax;
  final LunchDinnerData? lunch;
  final LunchDinnerData? dinner;
  final WeekdayWeekendData? weekday;
  final WeekdayWeekendData? weekend;

  RevenuePerOutletRegion({
    required this.regionCode,
    required this.outlets,
    required this.totalRevenue,
    required this.totalOrders,
    required this.totalPax,
    this.lunch,
    this.dinner,
    this.weekday,
    this.weekend,
  });

  factory RevenuePerOutletRegion.fromJson(Map<String, dynamic> json) {
    return RevenuePerOutletRegion(
      regionCode: json['region_code']?.toString() ?? '',
      outlets: (json['outlets'] as List<dynamic>?)
              ?.map((e) => OutletRevenue.fromJson(e))
              .toList() ??
          [],
      totalRevenue: _toDouble(json['total_revenue']),
      totalOrders: _toInt(json['total_orders']),
      totalPax: _toInt(json['total_pax']),
      lunch: json['lunch'] != null ? LunchDinnerData.fromJson(json['lunch']) : null,
      dinner: json['dinner'] != null ? LunchDinnerData.fromJson(json['dinner']) : null,
      weekday: json['weekday'] != null ? WeekdayWeekendData.fromJson(json['weekday']) : null,
      weekend: json['weekend'] != null ? WeekdayWeekendData.fromJson(json['weekend']) : null,
    );
  }
}

class OutletRevenue {
  final String outletCode;
  final String outletName;
  final int orderCount;
  final double totalRevenue;
  final int totalPax;
  final double avgOrderValue;

  OutletRevenue({
    required this.outletCode,
    required this.outletName,
    required this.orderCount,
    required this.totalRevenue,
    required this.totalPax,
    required this.avgOrderValue,
  });

  factory OutletRevenue.fromJson(Map<String, dynamic> json) {
    return OutletRevenue(
      outletCode: json['outlet_code']?.toString() ?? '',
      outletName: json['outlet_name']?.toString() ?? '',
      orderCount: _toInt(json['order_count']),
      totalRevenue: _toDouble(json['total_revenue']),
      totalPax: _toInt(json['total_pax']),
      avgOrderValue: _toDouble(json['avg_order_value']),
    );
  }
}

class RevenuePerRegion {
  final List<RegionRevenue> totalRevenue;
  final Map<String, RegionLunchDinner> lunchDinner;
  final Map<String, RegionWeekdayWeekend> weekdayWeekend;

  RevenuePerRegion({
    required this.totalRevenue,
    required this.lunchDinner,
    required this.weekdayWeekend,
  });

  factory RevenuePerRegion.fromJson(Map<String, dynamic> json) {
    return RevenuePerRegion(
      totalRevenue: (json['total_revenue'] as List<dynamic>?)
              ?.map((e) => RegionRevenue.fromJson(e))
              .toList() ??
          [],
      lunchDinner: (json['lunch_dinner'] as Map<String, dynamic>?)
              ?.map((key, value) => MapEntry(key, RegionLunchDinner.fromJson(value))) ??
          {},
      weekdayWeekend: (json['weekday_weekend'] as Map<String, dynamic>?)
              ?.map((key, value) => MapEntry(key, RegionWeekdayWeekend.fromJson(value))) ??
          {},
    );
  }
}

class RegionRevenue {
  final String regionName;
  final String regionCode;
  final int totalOrders;
  final double totalRevenue;
  final int totalPax;
  final double avgOrderValue;

  RegionRevenue({
    required this.regionName,
    required this.regionCode,
    required this.totalOrders,
    required this.totalRevenue,
    required this.totalPax,
    required this.avgOrderValue,
  });

  factory RegionRevenue.fromJson(Map<String, dynamic> json) {
    return RegionRevenue(
      regionName: json['region_name']?.toString() ?? '',
      regionCode: json['region_code']?.toString() ?? '',
      totalOrders: _toInt(json['total_orders']),
      totalRevenue: _toDouble(json['total_revenue']),
      totalPax: _toInt(json['total_pax']),
      avgOrderValue: _toDouble(json['avg_order_value']),
    );
  }
}

class RegionLunchDinner {
  final String regionCode;
  final LunchDinnerData lunch;
  final LunchDinnerData dinner;

  RegionLunchDinner({
    required this.regionCode,
    required this.lunch,
    required this.dinner,
  });

  factory RegionLunchDinner.fromJson(Map<String, dynamic> json) {
    return RegionLunchDinner(
      regionCode: json['region_code']?.toString() ?? '',
      lunch: LunchDinnerData.fromJson(json['lunch'] ?? {}),
      dinner: LunchDinnerData.fromJson(json['dinner'] ?? {}),
    );
  }
}

class RegionWeekdayWeekend {
  final String regionCode;
  final WeekdayWeekendData weekday;
  final WeekdayWeekendData weekend;

  RegionWeekdayWeekend({
    required this.regionCode,
    required this.weekday,
    required this.weekend,
  });

  factory RegionWeekdayWeekend.fromJson(Map<String, dynamic> json) {
    return RegionWeekdayWeekend(
      regionCode: json['region_code']?.toString() ?? '',
      weekday: WeekdayWeekendData.fromJson(json['weekday'] ?? {}),
      weekend: WeekdayWeekendData.fromJson(json['weekend'] ?? {}),
    );
  }
}

