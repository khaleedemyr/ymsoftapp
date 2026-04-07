class OutletFoodGoodReceiveListItem {
  final int id;
  final String number;
  final String receiveDate;
  final String? outletName;
  final String? warehouseOutletName;
  final String? deliveryOrderNumber;
  final String? creatorName;
  final String? creatorAvatar;
  final String? creatorPhotoUrl;
  final String? creatorUploadPhoto;
  final String? status;
  final String? createdAt;

  OutletFoodGoodReceiveListItem({
    required this.id,
    required this.number,
    required this.receiveDate,
    this.outletName,
    this.warehouseOutletName,
    this.deliveryOrderNumber,
    this.creatorName,
    this.creatorAvatar,
    this.creatorPhotoUrl,
    this.creatorUploadPhoto,
    this.status,
    this.createdAt,
  });

  factory OutletFoodGoodReceiveListItem.fromJson(Map<String, dynamic> json) {
    return OutletFoodGoodReceiveListItem(
      id: int.tryParse(json['id'].toString()) ?? 0,
      number: json['number']?.toString() ?? '-',
      receiveDate: json['receive_date']?.toString() ?? '',
      outletName: json['outlet_name']?.toString(),
      warehouseOutletName: json['warehouse_outlet_name']?.toString(),
      deliveryOrderNumber: json['delivery_order_number']?.toString(),
      creatorName: json['creator_name']?.toString(),
      creatorAvatar: json['creator_avatar']?.toString(),
      creatorPhotoUrl: json['creator_photo_url']?.toString(),
      creatorUploadPhoto: json['creator_upload_photo']?.toString(),
      status: json['status']?.toString(),
      createdAt: json['created_at']?.toString(),
    );
  }
}

class OutletFoodGoodReceiveDetail {
  final int id;
  final String number;
  final String receiveDate;
  final String? status;
  final String? outletName;
  final String? deliveryOrderNumber;
  final String? notes;
  final List<OutletFoodGoodReceiveItem> items;

  OutletFoodGoodReceiveDetail({
    required this.id,
    required this.number,
    required this.receiveDate,
    this.status,
    this.outletName,
    this.deliveryOrderNumber,
    this.notes,
    required this.items,
  });

  factory OutletFoodGoodReceiveDetail.fromJson(Map<String, dynamic> json) {
    return OutletFoodGoodReceiveDetail(
      id: int.tryParse(json['id'].toString()) ?? 0,
      number: json['number']?.toString() ?? '-',
      receiveDate: json['receive_date']?.toString() ?? '',
      status: json['status']?.toString(),
      outletName: json['outlet_name']?.toString(),
      deliveryOrderNumber: json['delivery_order_number']?.toString(),
      notes: json['notes']?.toString(),
      items: (json['items'] as List<dynamic>? ?? [])
          .map((item) => OutletFoodGoodReceiveItem.fromJson(item as Map<String, dynamic>))
          .toList(),
    );
  }
}

class OutletFoodGoodReceiveItem {
  final int id;
  final int itemId;
  final String itemName;
  final double qtyDo;
  final double qtyReceived;
  final String? unitName;

  OutletFoodGoodReceiveItem({
    required this.id,
    required this.itemId,
    required this.itemName,
    required this.qtyDo,
    required this.qtyReceived,
    this.unitName,
  });

  factory OutletFoodGoodReceiveItem.fromJson(Map<String, dynamic> json) {
    return OutletFoodGoodReceiveItem(
      id: int.tryParse(json['id'].toString()) ?? 0,
      itemId: int.tryParse(json['item_id'].toString()) ?? 0,
      itemName: json['item_name']?.toString() ?? json['item']?['name']?.toString() ?? '-',
      qtyDo: double.tryParse((json['qty_do'] ?? json['qty']).toString()) ?? 0,
      qtyReceived: double.tryParse(json['received_qty']?.toString() ?? '0') ?? 0,
      unitName: json['unit_name']?.toString() ?? json['unit']?['name']?.toString(),
    );
  }
}

class OutletDeliveryOrderDetail {
  final OutletDeliveryOrderInfo? info;
  final List<OutletDeliveryOrderItem> items;
  final OutletPoInfo? poInfo;

  OutletDeliveryOrderDetail({
    this.info,
    required this.items,
    this.poInfo,
  });

  factory OutletDeliveryOrderDetail.fromJson(Map<String, dynamic> json) {
    final info = json['do'] as Map<String, dynamic>?;
    final poInfo = json['po_info'] as Map<String, dynamic>?;

    return OutletDeliveryOrderDetail(
      info: info != null ? OutletDeliveryOrderInfo.fromJson(info) : null,
      items: (json['items'] as List<dynamic>? ?? [])
          .map((item) => OutletDeliveryOrderItem.fromJson(item as Map<String, dynamic>))
          .toList(),
      poInfo: poInfo != null ? OutletPoInfo.fromJson(poInfo) : null,
    );
  }
}

class OutletDeliveryOrderInfo {
  final int id;
  final String number;
  final String? createdAt;
  final String? packingNumber;
  final String? packingReason;
  final String? floorOrderNumber;
  final String? floorOrderDate;
  final String? warehouseOutletName;
  final String? outletName;
  final String? roGrNumber;
  final String? roFloorOrderNumber;

  OutletDeliveryOrderInfo({
    required this.id,
    required this.number,
    this.createdAt,
    this.packingNumber,
    this.packingReason,
    this.floorOrderNumber,
    this.floorOrderDate,
    this.warehouseOutletName,
    this.outletName,
    this.roGrNumber,
    this.roFloorOrderNumber,
  });

  factory OutletDeliveryOrderInfo.fromJson(Map<String, dynamic> json) {
    return OutletDeliveryOrderInfo(
      id: int.tryParse((json['do_id'] ?? json['id']).toString()) ?? 0,
      number: json['do_number']?.toString() ?? json['number']?.toString() ?? '-',
      createdAt: json['do_created_at']?.toString() ?? json['created_at']?.toString(),
      packingNumber: json['packing_number']?.toString(),
      packingReason: json['packing_reason']?.toString(),
      floorOrderNumber: json['floor_order_number']?.toString(),
      floorOrderDate: json['floor_order_date']?.toString(),
      warehouseOutletName: json['warehouse_outlet_name']?.toString(),
      outletName: json['outlet_name']?.toString(),
      roGrNumber: json['ro_gr_number']?.toString(),
      roFloorOrderNumber: json['ro_floor_order_number']?.toString(),
    );
  }
}

class OutletDeliveryOrderItem {
  final int deliveryOrderItemId;
  final int itemId;
  final String itemName;
  final double qtyPackingList;
  double qtyScan;
  final String? unit;
  final int? unitId;
  final String? unitType;
  final List<String> barcodes;

  OutletDeliveryOrderItem({
    required this.deliveryOrderItemId,
    required this.itemId,
    required this.itemName,
    required this.qtyPackingList,
    required this.qtyScan,
    this.unit,
    this.unitId,
    this.unitType,
    required this.barcodes,
  });

  factory OutletDeliveryOrderItem.fromJson(Map<String, dynamic> json) {
    final rawBarcodes = json['barcodes'];
    final barcodes = <String>[];
    if (rawBarcodes is List) {
      for (final code in rawBarcodes) {
        if (code != null) barcodes.add(code.toString());
      }
    } else if (rawBarcodes is String && rawBarcodes.isNotEmpty) {
      barcodes.addAll(rawBarcodes.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty));
    }

    final singleBarcode = json['barcode']?.toString();
    if (singleBarcode != null && singleBarcode.isNotEmpty && !barcodes.contains(singleBarcode)) {
      barcodes.add(singleBarcode);
    }

    return OutletDeliveryOrderItem(
      deliveryOrderItemId: int.tryParse(json['delivery_order_item_id'].toString()) ??
          int.tryParse(json['id'].toString()) ??
          0,
      itemId: int.tryParse(json['item_id'].toString()) ?? 0,
      itemName: json['item_name']?.toString() ?? '-',
      qtyPackingList: double.tryParse(json['qty_packing_list']?.toString() ?? '0') ?? 0,
      qtyScan: double.tryParse(json['qty_scan']?.toString() ?? '0') ?? 0,
      unit: json['unit']?.toString() ?? json['unit_name']?.toString(),
      unitId: json['unit_id'] != null ? int.tryParse(json['unit_id'].toString()) : null,
      unitType: json['unit_type']?.toString(),
      barcodes: barcodes,
    );
  }
}

class OutletPoInfo {
  final int? poId;
  final String? poNumber;
  final String? sourceType;
  final String? sourceTypeDisplay;
  final List<String> outletNames;

  OutletPoInfo({
    this.poId,
    this.poNumber,
    this.sourceType,
    this.sourceTypeDisplay,
    required this.outletNames,
  });

  factory OutletPoInfo.fromJson(Map<String, dynamic> json) {
    return OutletPoInfo(
      poId: json['po_id'] != null ? int.tryParse(json['po_id'].toString()) : null,
      poNumber: json['po_number']?.toString(),
      sourceType: json['source_type']?.toString(),
      sourceTypeDisplay: json['source_type_display']?.toString(),
      outletNames: (json['outlet_names'] as List<dynamic>? ?? [])
          .map((item) => item.toString())
          .toList(),
    );
  }
}
