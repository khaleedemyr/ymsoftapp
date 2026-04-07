class UserRole {
  final int id;
  final String namaLengkap;
  final String? namaOutlet;
  final String? namaJabatan;
  final String? namaDivisi;
  final int? roleId;
  final String? roleName;

  UserRole({
    required this.id,
    required this.namaLengkap,
    this.namaOutlet,
    this.namaJabatan,
    this.namaDivisi,
    this.roleId,
    this.roleName,
  });

  factory UserRole.fromJson(Map<String, dynamic> json) {
    return UserRole(
      id: json['id'] ?? 0,
      namaLengkap: json['nama_lengkap'] ?? '',
      namaOutlet: json['nama_outlet'],
      namaJabatan: json['nama_jabatan'],
      namaDivisi: json['nama_divisi'],
      roleId: json['role_id'],
      roleName: json['role_name'],
    );
  }
}

class Role {
  final int id;
  final String name;
  final String? description;

  Role({
    required this.id,
    required this.name,
    this.description,
  });

  factory Role.fromJson(Map<String, dynamic> json) {
    return Role(
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
      description: json['description'],
    );
  }
}

class FilterOption {
  final int id;
  final String name;

  FilterOption({
    required this.id,
    required this.name,
  });

  factory FilterOption.fromJson(Map<String, dynamic> json) {
    return FilterOption(
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
    );
  }
}

