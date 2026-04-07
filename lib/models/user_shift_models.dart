class UserShift {
  final int id;
  final int userId;
  final int? shiftId;
  final String tanggal;
  final int outletId;
  final int divisionId;

  UserShift({
    required this.id,
    required this.userId,
    this.shiftId,
    required this.tanggal,
    required this.outletId,
    required this.divisionId,
  });

  factory UserShift.fromJson(Map<String, dynamic> json) {
    // Parse shift_id - can be int, null, or string representation
    int? shiftId;
    final shiftIdValue = json['shift_id'];
    if (shiftIdValue != null) {
      if (shiftIdValue is int) {
        shiftId = shiftIdValue;
      } else if (shiftIdValue is num) {
        shiftId = shiftIdValue.toInt();
      } else if (shiftIdValue is String && shiftIdValue.isNotEmpty) {
        shiftId = int.tryParse(shiftIdValue);
      }
    }
    
    return UserShift(
      id: json['id'] ?? 0,
      userId: json['user_id'] ?? 0,
      shiftId: shiftId,
      tanggal: json['tanggal'] ?? '',
      outletId: json['outlet_id'] ?? 0,
      divisionId: json['division_id'] ?? 0,
    );
  }
}

class Shift {
  final int id;
  final int divisionId;
  final String shiftName;
  final String timeStart;
  final String timeEnd;

  Shift({
    required this.id,
    required this.divisionId,
    required this.shiftName,
    required this.timeStart,
    required this.timeEnd,
  });

  factory Shift.fromJson(Map<String, dynamic> json) {
    return Shift(
      id: json['id'] ?? 0,
      divisionId: json['division_id'] ?? 0,
      shiftName: json['shift_name'] ?? '',
      timeStart: json['time_start'] ?? '',
      timeEnd: json['time_end'] ?? '',
    );
  }
}

class UserShiftUser {
  final int id;
  final String namaLengkap;
  final String? jabatan;
  final int idOutlet;
  final int divisionId;
  final String status;

  UserShiftUser({
    required this.id,
    required this.namaLengkap,
    this.jabatan,
    required this.idOutlet,
    required this.divisionId,
    required this.status,
  });

  factory UserShiftUser.fromJson(Map<String, dynamic> json) {
    return UserShiftUser(
      id: json['id'] ?? 0,
      namaLengkap: json['nama_lengkap'] ?? '',
      jabatan: json['jabatan'],
      idOutlet: json['id_outlet'] ?? 0,
      divisionId: json['division_id'] ?? 0,
      status: json['status'] ?? '',
    );
  }
}

class Holiday {
  final String date;
  final String name;

  Holiday({
    required this.date,
    required this.name,
  });

  factory Holiday.fromJson(Map<String, dynamic> json) {
    return Holiday(
      date: json['date']?.toString() ?? '',
      name: json['name'] ?? '',
    );
  }
}

class ApprovedAbsent {
  final int userId;
  final String dateFrom;
  final String dateTo;
  final String? leaveTypeName;
  final String? reason;

  ApprovedAbsent({
    required this.userId,
    required this.dateFrom,
    required this.dateTo,
    this.leaveTypeName,
    this.reason,
  });

  factory ApprovedAbsent.fromJson(Map<String, dynamic> json) {
    return ApprovedAbsent(
      userId: json['user_id'] ?? 0,
      dateFrom: json['date_from']?.toString() ?? '',
      dateTo: json['date_to']?.toString() ?? '',
      leaveTypeName: json['leave_type_name'],
      reason: json['reason'],
    );
  }
}

