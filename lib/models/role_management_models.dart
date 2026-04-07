class Role {
  final int id;
  final String name;
  final String? description;
  final List<Permission> permissions;

  Role({
    required this.id,
    required this.name,
    this.description,
    required this.permissions,
  });

  factory Role.fromJson(Map<String, dynamic> json) {
    return Role(
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
      description: json['description'],
      permissions: (json['permissions'] as List<dynamic>?)
              ?.map((p) => Permission.fromJson(p))
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'permissions': permissions.map((p) => p.toJson()).toList(),
    };
  }
}

class Permission {
  final int id;
  final int menuId;
  final String action;
  final Menu? menu;

  Permission({
    required this.id,
    required this.menuId,
    required this.action,
    this.menu,
  });

  factory Permission.fromJson(Map<String, dynamic> json) {
    return Permission(
      id: json['id'] ?? 0,
      menuId: json['menu_id'] ?? 0,
      action: json['action'] ?? '',
      menu: json['menu'] != null ? Menu.fromJson(json['menu']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'menu_id': menuId,
      'action': action,
      'menu': menu?.toJson(),
    };
  }
}

class Menu {
  final int id;
  final String name;
  final String? code;
  final int? parentId;
  final String? route;
  final String? icon;

  Menu({
    required this.id,
    required this.name,
    this.code,
    this.parentId,
    this.route,
    this.icon,
  });

  factory Menu.fromJson(Map<String, dynamic> json) {
    return Menu(
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
      code: json['code'],
      parentId: json['parent_id'],
      route: json['route'],
      icon: json['icon'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'code': code,
      'parent_id': parentId,
      'route': route,
      'icon': icon,
    };
  }
}

