class MenuGroup {
  final String title;
  final String icon;
  final bool collapsible;
  final bool? open;
  final List<MenuItem> menus;

  MenuGroup({
    required this.title,
    required this.icon,
    this.collapsible = false,
    this.open,
    required this.menus,
  });

  factory MenuGroup.fromJson(Map<String, dynamic> json) {
    return MenuGroup(
      title: json['title'] ?? '',
      icon: json['icon'] ?? '',
      collapsible: json['collapsible'] ?? false,
      open: json['open'],
      menus: (json['menus'] as List<dynamic>?)
              ?.map((m) => MenuItem.fromJson(m))
              .toList() ?? [],
    );
  }
}

class MenuItem {
  final String name;
  final String icon;
  final String route;
  final String? code;

  MenuItem({
    required this.name,
    required this.icon,
    required this.route,
    this.code,
  });

  factory MenuItem.fromJson(Map<String, dynamic> json) {
    return MenuItem(
      name: json['name'] ?? '',
      icon: json['icon'] ?? '',
      route: json['route'] ?? '',
      code: json['code'],
    );
  }
}

