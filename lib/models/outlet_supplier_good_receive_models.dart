class OutletSupplierGoodReceiveListItem {
  final int id;
  final String number;
  final String receiveDate;
  final String? roNumber;
  final String? doNumber;
  final String? outletName;
  final String? warehouseOutletName;
  final String? supplierName;
  final String? receivedByName;
  final String? receivedByAvatar;
  final String? status;

  OutletSupplierGoodReceiveListItem({
    required this.id,
    required this.number,
    required this.receiveDate,
    this.roNumber,
    this.doNumber,
    this.outletName,
    this.warehouseOutletName,
    this.supplierName,
    this.receivedByName,
    this.receivedByAvatar,
    this.status,
  });

  factory OutletSupplierGoodReceiveListItem.fromJson(Map<String, dynamic> json) {
    return OutletSupplierGoodReceiveListItem(
      id: int.tryParse(json['id'].toString()) ?? 0,
      number: json['gr_number']?.toString() ?? json['number']?.toString() ?? '-',
      receiveDate: json['receive_date']?.toString() ?? '',
      roNumber: json['ro_number']?.toString(),
      doNumber: json['do_number']?.toString(),
      outletName: json['outlet_name']?.toString(),
      warehouseOutletName: json['warehouse_outlet_name']?.toString(),
      supplierName: json['supplier_name']?.toString(),
      receivedByName: json['received_by_name']?.toString(),
      receivedByAvatar: json['received_by_avatar']?.toString(),
      status: json['status']?.toString(),
    );
  }
}

class OutletSupplierGoodReceiveDetail {
  final int id;
  final String number;
  final String receiveDate;
  final String? roNumber;
  final String? roDate;
  final String? poNumber;
  final String? poDate;
  final String? outletName;
  final String? warehouseOutletName;
  final String? supplierName;
  final String? receivedByName;
  final String? status;
  final String? notes;
  final List<OutletSupplierGoodReceiveItem> items;

  OutletSupplierGoodReceiveDetail({
    required this.id,
    required this.number,
    required this.receiveDate,
    this.roNumber,
    this.roDate,
    this.poNumber,
    this.poDate,
    this.outletName,
    this.warehouseOutletName,
    this.supplierName,
    this.receivedByName,
    this.status,
    this.notes,
    required this.items,
  });

  factory OutletSupplierGoodReceiveDetail.fromJson(Map<String, dynamic> json) {
    return OutletSupplierGoodReceiveDetail(
      id: int.tryParse(json['id'].toString()) ?? 0,
      number: json['gr_number']?.toString() ?? json['number']?.toString() ?? '-',
      receiveDate: json['receive_date']?.toString() ?? '',
      roNumber: json['ro_number']?.toString(),
      roDate: json['ro_date']?.toString(),
      poNumber: json['po_number']?.toString(),
      poDate: json['po_date']?.toString(),
      outletName: json['outlet_name']?.toString(),
      warehouseOutletName: json['warehouse_outlet_name']?.toString(),
      supplierName: json['supplier_name']?.toString(),
      receivedByName: json['received_by_name']?.toString(),
      status: json['status']?.toString(),
      notes: json['notes']?.toString(),
      items: (json['items'] as List<dynamic>? ?? [])
          .map((item) => OutletSupplierGoodReceiveItem.fromJson(item as Map<String, dynamic>))
          .toList(),
    );
  }
}

class OutletSupplierGoodReceiveItem {
  final int id;
  final int itemId;
  final String itemName;
  final double qtyOrdered;
  final double qtyReceived;
  final int? unitId;
  final String? unitName;
  final double? price;

  OutletSupplierGoodReceiveItem({
    required this.id,
    required this.itemId,
    required this.itemName,
    required this.qtyOrdered,
    required this.qtyReceived,
    this.unitId,
    this.unitName,
    this.price,
  });

  factory OutletSupplierGoodReceiveItem.fromJson(Map<String, dynamic> json) {
    return OutletSupplierGoodReceiveItem(
      id: int.tryParse(json['id'].toString()) ?? 0,
      itemId: int.tryParse(json['item_id'].toString()) ?? 0,
      itemName: json['item_name']?.toString() ?? '-',
      qtyOrdered: double.tryParse(json['qty_ordered']?.toString() ?? '0') ?? 0,
      qtyReceived: double.tryParse(json['qty_received']?.toString() ?? '0') ?? 0,
      unitId: json['unit_id'] != null ? int.tryParse(json['unit_id'].toString()) : null,
      unitName: json['unit_name']?.toString(),
      price: json['price'] != null ? double.tryParse(json['price'].toString()) : null,
    );
  }
}

class OutletSupplierRoOption {
  final int id;
  final String roNumber;
  final String? floorOrderNumber;
  final String? date;
  final String? supplierName;
  final String? warehouseOutletName;

  OutletSupplierRoOption({
    required this.id,
    required this.roNumber,
    this.floorOrderNumber,
    this.date,
    this.supplierName,
    this.warehouseOutletName,
  });

  factory OutletSupplierRoOption.fromJson(Map<String, dynamic> json) {
    return OutletSupplierRoOption(
      id: int.tryParse(json['id'].toString()) ?? 0,
      roNumber: json['ro_number']?.toString() ?? '-',
      floorOrderNumber: json['floor_order_number']?.toString(),
      date: json['tanggal']?.toString(),
      supplierName: json['supplier_name']?.toString(),
      warehouseOutletName: json['warehouse_outlet_name']?.toString(),
    );
  }
}

class OutletSupplierDoOption {
  final int id;
  final String doNumber;
  final String? roGrNumber;
  final String? roFloorOrderNumber;
  final String? outletName;
  final String? date;

  OutletSupplierDoOption({
    required this.id,
    required this.doNumber,
    this.roGrNumber,
    this.roFloorOrderNumber,
    this.outletName,
    this.date,
  });

  factory OutletSupplierDoOption.fromJson(Map<String, dynamic> json) {
    return OutletSupplierDoOption(
      id: int.tryParse(json['id'].toString()) ?? 0,
      doNumber: json['do_number']?.toString() ?? '-',
      roGrNumber: json['ro_gr_number']?.toString(),
      roFloorOrderNumber: json['ro_floor_order_number']?.toString(),
      outletName: json['outlet_name']?.toString(),
      date: json['do_date']?.toString(),
    );
  }
}

class OutletSupplierRoDetail {
  final Map<String, dynamic> header;
  final List<OutletSupplierInputItem> items;

  OutletSupplierRoDetail({
    required this.header,
    required this.items,
  });

  factory OutletSupplierRoDetail.fromJson(Map<String, dynamic> json) {
    return OutletSupplierRoDetail(
      header: json['ro'] as Map<String, dynamic>? ?? {},
      items: (json['items'] as List<dynamic>? ?? [])
          .map((item) => OutletSupplierInputItem.fromJson(item as Map<String, dynamic>))
          .toList(),
    );
  }
}

class OutletSupplierDoDetail {
  final Map<String, dynamic> header;
  final List<OutletSupplierInputItem> items;

  OutletSupplierDoDetail({
    required this.header,
    required this.items,
  });

  factory OutletSupplierDoDetail.fromJson(Map<String, dynamic> json) {
    return OutletSupplierDoDetail(
      header: json['deliveryOrder'] as Map<String, dynamic>? ?? {},
      items: (json['items'] as List<dynamic>? ?? [])
          .map((item) => OutletSupplierInputItem.fromJson(item as Map<String, dynamic>))
          .toList(),
    );
  }
}

class OutletSupplierInputItem {
  final int? roItemId;
  final int itemId;
  final String itemName;
  final double qtyOrdered;
  double qtyReceived;
  final int? unitId;
  final String? unitName;
  final double? price;

  OutletSupplierInputItem({
    this.roItemId,
    required this.itemId,
    required this.itemName,
    required this.qtyOrdered,
    required this.qtyReceived,
    this.unitId,
    this.unitName,
    this.price,
  });

  factory OutletSupplierInputItem.fromJson(Map<String, dynamic> json) {
    return OutletSupplierInputItem(
      roItemId: json['ro_item_id'] != null ? int.tryParse(json['ro_item_id'].toString()) : null,
      itemId: int.tryParse(json['item_id'].toString()) ?? 0,
      itemName: json['item_name']?.toString() ?? '-',
      qtyOrdered: double.tryParse(json['qty_ordered']?.toString() ?? '0') ?? 0,
      qtyReceived: double.tryParse(json['qty_received']?.toString() ?? '0') ?? 0,
      unitId: json['unit_id'] != null ? int.tryParse(json['unit_id'].toString()) : null,
      unitName: json['unit_name']?.toString(),
      price: json['price'] != null ? double.tryParse(json['price'].toString()) : null,
    );
  }
}
