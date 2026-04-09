class SalesReportSimpleResponse {
  final SalesReportSimpleSummary summary;
  final Map<String, SalesReportSimpleDay> perDay;
  final List<SalesReportSimpleOrder> orders;

  SalesReportSimpleResponse({
    required this.summary,
    required this.perDay,
    required this.orders,
  });

  factory SalesReportSimpleResponse.fromJson(Map<String, dynamic> json) {
    final rawPerDay = (json['per_day'] as Map?) ?? {};
    final perDay = <String, SalesReportSimpleDay>{};
    rawPerDay.forEach((key, value) {
      perDay[key.toString()] = SalesReportSimpleDay.fromJson(
        Map<String, dynamic>.from((value as Map?) ?? const {}),
      );
    });

    final rawOrders = (json['orders'] as List?) ?? const [];
    final orders = rawOrders
        .map((e) => SalesReportSimpleOrder.fromJson(Map<String, dynamic>.from((e as Map?) ?? const {})))
        .toList();

    return SalesReportSimpleResponse(
      summary: SalesReportSimpleSummary.fromJson(
        Map<String, dynamic>.from((json['summary'] as Map?) ?? const {}),
      ),
      perDay: perDay,
      orders: orders,
    );
  }
}

class SalesReportSimpleSummary {
  final double totalSales;
  final double grandTotal;
  final int totalOrder;
  final int totalPax;
  final double totalDiscount;
  final double totalCashback;
  final double totalService;
  final double totalPb1;
  final double totalCommfee;
  final double totalRounding;
  final double netSales;

  SalesReportSimpleSummary({
    required this.totalSales,
    required this.grandTotal,
    required this.totalOrder,
    required this.totalPax,
    required this.totalDiscount,
    required this.totalCashback,
    required this.totalService,
    required this.totalPb1,
    required this.totalCommfee,
    required this.totalRounding,
    required this.netSales,
  });

  factory SalesReportSimpleSummary.fromJson(Map<String, dynamic> json) {
    return SalesReportSimpleSummary(
      totalSales: _toDouble(json['total_sales']),
      grandTotal: _toDouble(json['grand_total']),
      totalOrder: _toInt(json['total_order']),
      totalPax: _toInt(json['total_pax']),
      totalDiscount: _toDouble(json['total_discount']),
      totalCashback: _toDouble(json['total_cashback']),
      totalService: _toDouble(json['total_service']),
      totalPb1: _toDouble(json['total_pb1']),
      totalCommfee: _toDouble(json['total_commfee']),
      totalRounding: _toDouble(json['total_rounding']),
      netSales: _toDouble(json['net_sales']),
    );
  }
}

class SalesReportSimpleDay {
  final int totalOrder;
  final int totalPax;
  final double avgCheck;
  final double totalDiscount;
  final double totalCashback;
  final double totalService;
  final double totalPb1;
  final double totalCommfee;
  final double totalRounding;
  final double totalSales;
  final double grandTotal;
  final double netSales;

  SalesReportSimpleDay({
    required this.totalOrder,
    required this.totalPax,
    required this.avgCheck,
    required this.totalDiscount,
    required this.totalCashback,
    required this.totalService,
    required this.totalPb1,
    required this.totalCommfee,
    required this.totalRounding,
    required this.totalSales,
    required this.grandTotal,
    required this.netSales,
  });

  factory SalesReportSimpleDay.fromJson(Map<String, dynamic> json) {
    return SalesReportSimpleDay(
      totalOrder: _toInt(json['total_order']),
      totalPax: _toInt(json['total_pax']),
      avgCheck: _toDouble(json['avg_check']),
      totalDiscount: _toDouble(json['total_discount']),
      totalCashback: _toDouble(json['total_cashback']),
      totalService: _toDouble(json['total_service']),
      totalPb1: _toDouble(json['total_pb1']),
      totalCommfee: _toDouble(json['total_commfee']),
      totalRounding: _toDouble(json['total_rounding']),
      totalSales: _toDouble(json['total_sales']),
      grandTotal: _toDouble(json['grand_total']),
      netSales: _toDouble(json['net_sales']),
    );
  }
}

class SalesReportSimpleOrder {
  final int id;
  final String nomor;
  final String createdAt;
  final String paidNumber;
  final String outletName;
  final String outletCode;
  final String tableName;
  final String cashier;
  final String waiters;
  final String memberName;
  final int pax;
  final double total;
  final double discount;
  final double manualDiscountAmount;
  final double cashback;
  final double service;
  final double pb1;
  final double grandTotal;
  final String status;
  final String mode;
  final List<String> promoNames;
  final List<SalesReportSimplePayment> payments;
  final List<SalesReportSimpleOrderItem> items;

  SalesReportSimpleOrder({
    required this.id,
    required this.nomor,
    required this.createdAt,
    required this.paidNumber,
    required this.outletName,
    required this.outletCode,
    required this.tableName,
    required this.cashier,
    required this.waiters,
    required this.memberName,
    required this.pax,
    required this.total,
    required this.discount,
    required this.manualDiscountAmount,
    required this.cashback,
    required this.service,
    required this.pb1,
    required this.grandTotal,
    required this.status,
    required this.mode,
    required this.promoNames,
    required this.payments,
    required this.items,
  });

  factory SalesReportSimpleOrder.fromJson(Map<String, dynamic> json) {
    final rawPromoNames = (json['promo_names'] as List?) ?? const [];
    final promoNames = rawPromoNames.map((e) => e.toString()).toList();

    final rawPayments = (json['payments'] as List?) ?? const [];
    final payments = rawPayments
        .map((e) => SalesReportSimplePayment.fromJson(Map<String, dynamic>.from((e as Map?) ?? const {})))
        .toList();

    final rawItems = (json['items'] as List?) ?? const [];
    final items = rawItems
        .map((e) => SalesReportSimpleOrderItem.fromJson(Map<String, dynamic>.from((e as Map?) ?? const {})))
        .toList();

    return SalesReportSimpleOrder(
      id: _toInt(json['id']),
      nomor: (json['nomor'] ?? '').toString(),
      createdAt: (json['created_at'] ?? '').toString(),
      paidNumber: (json['paid_number'] ?? '').toString(),
      outletName: (json['nama_outlet'] ?? '').toString(),
      outletCode: (json['kode_outlet'] ?? '').toString(),
      tableName: (json['table'] ?? '').toString(),
      cashier: (json['cashier'] ?? '').toString(),
      waiters: (json['waiters'] ?? '').toString(),
      memberName: (json['member_name'] ?? '').toString(),
      pax: _toInt(json['pax']),
      total: _toDouble(json['total']),
      discount: _toDouble(json['discount']),
      manualDiscountAmount: _toDouble(json['manual_discount_amount']),
      cashback: _toDouble(json['cashback']),
      service: _toDouble(json['service']),
      pb1: _toDouble(json['pb1']),
      grandTotal: _toDouble(json['grand_total']),
      status: (json['status'] ?? '').toString(),
      mode: (json['mode'] ?? '').toString(),
      promoNames: promoNames,
      payments: payments,
      items: items,
    );
  }

  double get effectiveDiscount {
    if (discount > 0 && manualDiscountAmount > 0) {
      return discount > manualDiscountAmount ? discount : manualDiscountAmount;
    }
    return discount + manualDiscountAmount;
  }
}

class SalesReportSimplePayment {
  final String paymentCode;
  final String paymentType;
  final double amount;
  final double change;
  final String kasir;

  SalesReportSimplePayment({
    required this.paymentCode,
    required this.paymentType,
    required this.amount,
    required this.change,
    required this.kasir,
  });

  factory SalesReportSimplePayment.fromJson(Map<String, dynamic> json) {
    return SalesReportSimplePayment(
      paymentCode: (json['payment_code'] ?? '').toString(),
      paymentType: (json['payment_type'] ?? '').toString(),
      amount: _toDouble(json['amount']),
      change: _toDouble(json['change']),
      kasir: (json['kasir'] ?? '').toString(),
    );
  }
}

class SalesReportSimpleOrderItem {
  final int id;
  final String itemName;
  final double qty;
  final double price;
  final double subtotal;
  final List<String> modifiersFormatted;
  final String notes;

  SalesReportSimpleOrderItem({
    required this.id,
    required this.itemName,
    required this.qty,
    required this.price,
    required this.subtotal,
    required this.modifiersFormatted,
    required this.notes,
  });

  factory SalesReportSimpleOrderItem.fromJson(Map<String, dynamic> json) {
    final rawModifiers = (json['modifiers_formatted'] as List?) ?? const [];
    return SalesReportSimpleOrderItem(
      id: _toInt(json['id']),
      itemName: (json['item_name'] ?? '').toString(),
      qty: _toDouble(json['qty']),
      price: _toDouble(json['price']),
      subtotal: _toDouble(json['subtotal']),
      modifiersFormatted: rawModifiers.map((e) => e.toString()).toList(),
      notes: (json['notes'] ?? '').toString(),
    );
  }
}

double _toDouble(dynamic value) {
  if (value == null) return 0.0;
  if (value is double) return value;
  if (value is int) return value.toDouble();
  if (value is String) return double.tryParse(value) ?? 0.0;
  return 0.0;
}

int _toInt(dynamic value) {
  if (value == null) return 0;
  if (value is int) return value;
  if (value is double) return value.toInt();
  if (value is String) return int.tryParse(value) ?? 0;
  return 0;
}
