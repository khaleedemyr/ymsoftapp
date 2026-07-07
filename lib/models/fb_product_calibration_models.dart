class CalibrationModeOption {
  final String value;
  final String label;

  CalibrationModeOption({required this.value, required this.label});

  factory CalibrationModeOption.fromJson(Map<String, dynamic> json) {
    return CalibrationModeOption(
      value: json['value']?.toString() ?? '',
      label: json['label']?.toString() ?? '',
    );
  }
}

class CalibrationCalendarEvent {
  final int calibrationId;
  final String title;
  final String date;
  final String outletName;
  final String conductorName;
  final String status;
  final String mode;
  final String modeLabel;
  final int productCount;
  final List<String> products;
  final String backgroundColor;

  CalibrationCalendarEvent({
    required this.calibrationId,
    required this.title,
    required this.date,
    required this.outletName,
    required this.conductorName,
    required this.status,
    required this.mode,
    required this.modeLabel,
    required this.productCount,
    required this.products,
    required this.backgroundColor,
  });

  factory CalibrationCalendarEvent.fromJson(Map<String, dynamic> json) {
    final props = json['extendedProps'] as Map? ?? {};
    final mode = props['mode']?.toString() ?? 'kitchen';
    return CalibrationCalendarEvent(
      calibrationId: props['calibration_id'] as int? ?? 0,
      title: json['title']?.toString() ?? '',
      date: json['start']?.toString().substring(0, 10) ?? '',
      outletName: props['outlet_name']?.toString() ?? '',
      conductorName: props['conductor_name']?.toString() ?? '',
      status: props['status']?.toString() ?? 'scheduled',
      mode: mode,
      modeLabel: props['mode_label']?.toString() ?? (mode == 'bar' ? 'Bar' : 'Kitchen'),
      productCount: props['product_count'] as int? ?? 0,
      products: (props['products'] as List? ?? []).map((e) => e.toString()).toList(),
      backgroundColor: json['backgroundColor']?.toString() ?? '#7c3aed',
    );
  }
}

class CalibrationProductLine {
  final int? calibrationProductId;
  final int itemId;
  final String itemName;
  final String? categoryName;
  final String? subCategoryName;

  CalibrationProductLine({
    this.calibrationProductId,
    required this.itemId,
    required this.itemName,
    this.categoryName,
    this.subCategoryName,
  });

  factory CalibrationProductLine.fromJson(Map<String, dynamic> json) {
    return CalibrationProductLine(
      calibrationProductId: json['id'] as int?,
      itemId: json['item_id'] as int? ?? json['id'] as int? ?? 0,
      itemName: json['item_name']?.toString() ?? '',
      categoryName: json['category_name']?.toString(),
      subCategoryName: json['sub_category_name']?.toString(),
    );
  }

  Map<String, dynamic> toPayload() => {
        'item_id': itemId,
        'item_name': itemName,
        'category_name': categoryName,
        'sub_category_name': subCategoryName,
      };
}

class UserSuggestion {
  final int id;
  final String namaLengkap;
  final String jabatanName;

  UserSuggestion({
    required this.id,
    required this.namaLengkap,
    required this.jabatanName,
  });

  factory UserSuggestion.fromJson(Map<String, dynamic> json) {
    return UserSuggestion(
      id: json['id'] as int? ?? json['user_id'] as int? ?? 0,
      namaLengkap: json['nama_lengkap']?.toString() ?? json['user_name']?.toString() ?? '',
      jabatanName: json['jabatan_name']?.toString() ?? '-',
    );
  }
}

class CalibrationParticipant {
  final int userId;
  final String userName;
  final String jabatanName;

  CalibrationParticipant({
    required this.userId,
    required this.userName,
    required this.jabatanName,
  });

  factory CalibrationParticipant.fromJson(Map<String, dynamic> json) {
    return CalibrationParticipant(
      userId: json['user_id'] as int,
      userName: json['user_name']?.toString() ?? json['nama_lengkap']?.toString() ?? '',
      jabatanName: json['jabatan_name']?.toString() ?? '-',
    );
  }

  Map<String, dynamic> toPayload() => {'user_id': userId};
}

class ParameterOption {
  final String code;
  final String label;

  ParameterOption({required this.code, required this.label});

  factory ParameterOption.fromJson(Map<String, dynamic> json) {
    return ParameterOption(
      code: json['code']?.toString() ?? '',
      label: json['label']?.toString() ?? '',
    );
  }
}
