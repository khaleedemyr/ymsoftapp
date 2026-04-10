import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../services/menu_service.dart';
import '../models/menu_models.dart';
import '../screens/video_tutorial_gallery_screen.dart';
import '../screens/home_screen.dart';
import '../screens/sales_outlet_dashboard_screen.dart';
import '../screens/web_only_feature_screen.dart';
import '../screens/my_attendance_screen.dart';
import '../screens/purchase_requisition_list_screen.dart';
import '../screens/tickets/ticket_list_screen.dart';
import '../screens/support/support_admin_panel_screen.dart';
import '../screens/settings/user_role_settings_screen.dart';
import '../screens/settings/role_management_screen.dart';
import '../screens/reports/activity_log_report_screen.dart';
import '../screens/reports/report_invoice_outlet_screen.dart';
import '../screens/reports/attendance_report_screen.dart';
import '../screens/reports/sales_report_simple_screen.dart';
import '../screens/reports/item_engineering_screen.dart';
import '../screens/schedule_attendance_correction/schedule_attendance_correction_screen.dart';
import '../screens/user_shift_input_screen.dart';
import '../screens/packing_list/packing_list_index_screen.dart';
import '../screens/pr_food/pr_food_index_screen.dart';
import '../screens/good_receive/good_receive_index_screen.dart';
import '../screens/outlet_food_good_receive/outlet_food_good_receive_index_screen.dart';
import '../screens/outlet_supplier_good_receive/outlet_supplier_good_receive_index_screen.dart';
import '../screens/outlet_stock_adjustment/outlet_stock_adjustment_index_screen.dart';
import '../screens/warehouse_stock_adjustment/warehouse_stock_adjustment_index_screen.dart';
import '../screens/retail_warehouse_sale/retail_warehouse_sale_index_screen.dart';
import '../screens/warehouse_sale/warehouse_sale_index_screen.dart';
import '../screens/outlet_rejection/outlet_rejection_index_screen.dart';
import '../screens/retail_warehouse_food/retail_warehouse_food_index_screen.dart';
import '../screens/outlet_wip/outlet_wip_index_screen.dart';
import '../screens/outlet_wip/outlet_wip_report_screen.dart';
import '../screens/outlet_inventory/outlet_stock_position_screen.dart';
import '../screens/inventory/warehouse_stock_position_screen.dart';
import '../screens/inventory/warehouse_stock_card_screen.dart';
import '../screens/outlet_inventory/outlet_stock_card_screen.dart';
import '../screens/outlet_inventory/category_cost_outlet_index_screen.dart';
import '../screens/warehouse_internal_use_waste/warehouse_internal_use_waste_index_screen.dart';
import '../screens/member_history_search_screen.dart';
import '../screens/warehouse_transfer/warehouse_transfer_index_screen.dart';
import '../screens/outlet_transfer/outlet_transfer_index_screen.dart';
import '../screens/internal_warehouse_transfer/internal_warehouse_transfer_index_screen.dart';
import '../screens/retail_food/retail_food_index_screen.dart';
import '../screens/retail_nono_food/retail_nono_food_index_screen.dart';
import '../screens/reservations/reservation_index_screen.dart';
import '../screens/outlet_food_return/outlet_food_return_index_screen.dart';
import '../screens/head_office_return/head_office_return_index_screen.dart';
import '../screens/stock_opname/stock_opname_index_screen.dart';
import '../screens/warehouse_stock_opname/warehouse_stock_opname_index_screen.dart';
import '../screens/floor_order/floor_order_index_screen.dart';
import '../screens/categories/category_index_screen.dart';
import '../screens/sub_categories/sub_category_index_screen.dart';
import '../screens/units/unit_index_screen.dart';
import '../screens/data_level/data_level_index_screen.dart';
import '../screens/jabatan/jabatan_index_screen.dart';
import '../screens/stock_cut/stock_cut_index_screen.dart';
import '../screens/mk_production/mk_production_index_screen.dart';
import 'app_loading_indicator.dart';

class AppSidebar extends StatefulWidget {
  final VoidCallback? onMenuTap;
  final String? currentRoute;

  const AppSidebar({
    super.key,
    this.onMenuTap,
    this.currentRoute,
  });

  @override
  State<AppSidebar> createState() => _AppSidebarState();
}

class _AppSidebarState extends State<AppSidebar> {
  final MenuService _menuService = MenuService();
  List<MenuGroup> _menuGroups = [];
  bool _isLoading = true;
  Map<String, bool> _expandedGroups = {};
  String _appVersion = '';

  @override
  void initState() {
    super.initState();
    _loadMenus();
    _loadAppVersion();
  }

  Future<void> _loadAppVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      if (mounted) {
        setState(() => _appVersion = info.version);
      }
    } catch (_) {
      if (mounted) setState(() => _appVersion = '');
    }
  }

  Future<void> _loadMenus() async {
    try {
      final menuGroups = await _menuService.getMenuGroups();
      if (mounted) {
        setState(() {
          _menuGroups = menuGroups;
          _isLoading = false;
          // Initialize expanded state
          for (var group in menuGroups) {
            _expandedGroups[group.title] = group.open ?? false;
          }
        });
      }
    } catch (e) {
      print('Error loading menus: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _toggleGroup(String title) {
    setState(() {
      _expandedGroups[title] = !(_expandedGroups[title] ?? false);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: const Color(0xFFF8FAFC),
      child: Column(
        children: [
          // Header
          Builder(
            builder: (context) {
              // Get drawer width (typically 80% of screen width on mobile)
              final screenWidth = MediaQuery.of(context).size.width;
              final drawerWidth = screenWidth * 0.8; // Drawer is typically 80% of screen width
              
              // Logo size: batasi agar header tidak overflow (content = padding + logo + version)
              final logoSize = (drawerWidth * 0.6).clamp(140.0, 200.0);
              final headerHeight = 56 + logoSize + 8 + 20; // padding + logo + gap + version text
              
              return Container(
                height: headerHeight.clamp(200.0, 284.0),
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: SafeArea(
                  top: true,
                  bottom: false,
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Image.asset(
                            'assets/images/logo.png',
                            height: logoSize,
                            width: logoSize,
                            fit: BoxFit.contain,
                            errorBuilder: (context, error, stackTrace) {
                              return Container(
                                width: logoSize,
                                height: logoSize,
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [
                                      Color(0xFF6366F1),
                                      Color(0xFF8B5CF6),
                                    ],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Icon(
                                  Icons.business,
                                  color: Colors.white,
                                  size: logoSize * 0.5,
                                ),
                              );
                            },
                          ),
                          if (_appVersion.isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Text(
                              'Versi $_appVersion',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey.shade600,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
          
          // Menu List
          Expanded(
            child: _isLoading
                ? Center(
                    child: AppLoadingIndicator(size: 24, color: Colors.white),
                  )
                : _menuGroups.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.menu_open,
                              size: 64,
                              color: Colors.grey.shade400,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Tidak ada menu',
                              style: TextStyle(
                                color: Colors.grey.shade600,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: EdgeInsets.only(
                          top: 12,
                          bottom: MediaQuery.of(context).padding.bottom + 12,
                        ),
                        itemCount: _menuGroups.length,
                        itemBuilder: (context, index) {
                          final group = _menuGroups[index];
                          final isExpanded = _expandedGroups[group.title] ?? false;
                          
                          return Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Group Header
                                if (group.collapsible)
                                  Material(
                                    color: Colors.transparent,
                                    child: InkWell(
                                      onTap: () => _toggleGroup(group.title),
                                      borderRadius: BorderRadius.circular(12),
                                      child: Container(
                                        margin: const EdgeInsets.symmetric(horizontal: 12),
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 16,
                                          vertical: 14,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          borderRadius: BorderRadius.circular(12),
                                          boxShadow: [
                                            BoxShadow(
                                              color: Colors.black.withOpacity(0.03),
                                              blurRadius: 8,
                                              offset: const Offset(0, 2),
                                            ),
                                          ],
                                        ),
                                        child: Row(
                                          children: [
                                            Container(
                                              width: 36,
                                              height: 36,
                                              decoration: BoxDecoration(
                                                gradient: const LinearGradient(
                                                  colors: [
                                                    Color(0xFF6366F1),
                                                    Color(0xFF8B5CF6),
                                                  ],
                                                  begin: Alignment.topLeft,
                                                  end: Alignment.bottomRight,
                                                ),
                                                borderRadius: BorderRadius.circular(10),
                                              ),
                                              child: Icon(
                                                _getIconData(group.icon),
                                                size: 20,
                                                color: Colors.white,
                                              ),
                                            ),
                                            const SizedBox(width: 12),
                                            Expanded(
                                              child: Text(
                                                group.title,
                                                style: const TextStyle(
                                                  fontSize: 15,
                                                  fontWeight: FontWeight.w600,
                                                  color: Color(0xFF1A1A1A),
                                                  letterSpacing: 0.3,
                                                ),
                                              ),
                                            ),
                                            AnimatedRotation(
                                              turns: isExpanded ? 0.25 : 0,
                                              duration: const Duration(milliseconds: 200),
                                              child: Icon(
                                                Icons.chevron_right,
                                                size: 20,
                                                color: Colors.grey.shade400,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  )
                                else
                                  Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                    child: Text(
                                      group.title,
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.grey.shade600,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                  ),
                                
                                // Menu Items
                                if (!group.collapsible || isExpanded)
                                  ...group.menus.map((menu) {
                                    final isActive = widget.currentRoute != null &&
                                        menu.route.startsWith(widget.currentRoute!);
                                    
                                    return _buildMenuItem(menu, isActive);
                                  }),
                              ],
                            ),
                          );
                        },
                      ),
          ),
          
          // Bottom padding separator
          Container(
            height: 1,
            margin: EdgeInsets.only(
              bottom: MediaQuery.of(context).padding.bottom,
            ),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.transparent,
                  Colors.grey.shade300,
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuItem(MenuItem menu, bool isActive) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          widget.onMenuTap?.call();
          _navigateToRoute(context, menu.route, menuTitle: menu.name);
        },
        borderRadius: BorderRadius.circular(12),
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: isActive ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            border: isActive
                ? Border.all(
                    color: const Color(0xFF6366F1).withOpacity(0.2),
                    width: 1,
                  )
                : null,
            boxShadow: isActive
                ? [
                    BoxShadow(
                      color: const Color(0xFF6366F1).withOpacity(0.1),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : null,
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: isActive
                      ? const Color(0xFF6366F1).withOpacity(0.1)
                      : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  _getIconData(menu.icon),
                  size: 22,
                  color: isActive
                      ? const Color(0xFF6366F1)
                      : Colors.grey.shade700,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  menu.name,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
                    color: isActive
                        ? const Color(0xFF1A1A1A)
                        : Colors.grey.shade800,
                    letterSpacing: 0.2,
                  ),
                ),
              ),
              if (isActive)
                Container(
                  width: 6,
                  height: 6,
                  decoration: const BoxDecoration(
                    color: Color(0xFF6366F1),
                    shape: BoxShape.circle,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _getIconData(String iconClass) {
    // Map FontAwesome classes to Material Icons
    // This is a simplified mapping - you might want to use a package like font_awesome_flutter
    final lowerClass = iconClass.toLowerCase();
    
    // Main menu icons
    if (lowerClass.contains('home')) return Icons.home;
    if (lowerClass.contains('bars')) return Icons.menu;
    if (lowerClass.contains('play-circle')) return Icons.play_circle;
    
    // Chart icons
    if (lowerClass.contains('chart-line') || lowerClass.contains('timeline')) return Icons.trending_up;
    if (lowerClass.contains('chart-pie')) return Icons.pie_chart;
    if (lowerClass.contains('chart-bar')) return Icons.bar_chart;
    
    // User/People icons
    if (lowerClass.contains('user-clock')) return Icons.access_time;
    if (lowerClass.contains('users-gear') || lowerClass.contains('users')) return Icons.people;
    if (lowerClass.contains('user-tie') || lowerClass.contains('user-minus') || lowerClass.contains('user-graduate')) return Icons.person;
    if (lowerClass.contains('user-shield')) return Icons.admin_panel_settings;
    if (lowerClass.contains('users-cog')) return Icons.people_outline;
    if (lowerClass.contains('users-line')) return Icons.people_alt;
    
    // Shopping/Cart icons
    if (lowerClass.contains('shopping-cart')) return Icons.shopping_cart;
    if (lowerClass.contains('shopping-bag')) return Icons.shopping_bag;
    
    // Data/Storage icons
    if (lowerClass.contains('database')) return Icons.storage;
    if (lowerClass.contains('warehouse')) return Icons.warehouse;
    if (lowerClass.contains('store')) return Icons.store;
    
    // Finance icons
    if (lowerClass.contains('building-columns')) return Icons.account_balance;
    if (lowerClass.contains('money-bill') || lowerClass.contains('money-check') || lowerClass.contains('coins')) return Icons.monetization_on;
    if (lowerClass.contains('credit-card') || lowerClass.contains('file-invoice')) return Icons.credit_card;
    
    // Settings/Management icons
    if (lowerClass.contains('cogs') || lowerClass.contains('gear')) return Icons.settings;
    if (lowerClass.contains('shield-halved') || lowerClass.contains('shield')) return Icons.shield;
    if (lowerClass.contains('bars-progress')) return Icons.menu;
    
    // Calendar/Time icons
    if (lowerClass.contains('calendar') || lowerClass.contains('calendar-days') || lowerClass.contains('calendar-week') || lowerClass.contains('calendar-day') || lowerClass.contains('calendar-check') || lowerClass.contains('calendar-alt')) return Icons.calendar_today;
    if (lowerClass.contains('clock')) return Icons.access_time;
    
    // File/Document icons
    if (lowerClass.contains('file-lines') || lowerClass.contains('file-invoice') || lowerClass.contains('clipboard-list') || lowerClass.contains('clipboard-check') || lowerClass.contains('clipboard-question') || lowerClass.contains('list-alt')) return Icons.description;
    if (lowerClass.contains('receipt')) return Icons.receipt;
    
    // Transport icons
    if (lowerClass.contains('truck') || lowerClass.contains('truck-loading') || lowerClass.contains('truck-arrow-right') || lowerClass.contains('truck-ramp-box')) return Icons.local_shipping;
    if (lowerClass.contains('plane')) return Icons.flight;
    
    // Box/Inventory icons
    if (lowerClass.contains('boxes-stacked') || lowerClass.contains('box') || lowerClass.contains('box-open') || lowerClass.contains('fa-box')) return Icons.inventory_2;
    if (lowerClass.contains('right-left') || lowerClass.contains('exchange-alt')) return Icons.swap_horiz;
    
    // Industry/Production icons
    if (lowerClass.contains('industry')) return Icons.factory;
    if (lowerClass.contains('utensils')) return Icons.restaurant;
    if (lowerClass.contains('cut') || lowerClass.contains('scissors')) return Icons.content_cut;
    
    // Communication icons
    if (lowerClass.contains('bullhorn')) return Icons.campaign;
    if (lowerClass.contains('headset')) return Icons.headset_mic;
    if (lowerClass.contains('comments')) return Icons.comment;
    if (lowerClass.contains('bell')) return Icons.notifications;
    
    // Business icons
    if (lowerClass.contains('handshake')) return Icons.handshake;
    if (lowerClass.contains('briefcase')) return Icons.business_center;
    if (lowerClass.contains('building')) return Icons.business;
    
    // Education icons
    if (lowerClass.contains('graduation-cap') || lowerClass.contains('school')) return Icons.school;
    if (lowerClass.contains('book')) return Icons.book;
    if (lowerClass.contains('question-circle')) return Icons.help;
    if (lowerClass.contains('certificate')) return Icons.verified;
    
    // Other icons
    if (lowerClass.contains('tags') || lowerClass.contains('tag')) return Icons.label;
    if (lowerClass.contains('ruler')) return Icons.straighten;
    if (lowerClass.contains('sliders')) return Icons.tune;
    if (lowerClass.contains('sitemap')) return Icons.account_tree;
    if (lowerClass.contains('truck')) return Icons.local_shipping;
    if (lowerClass.contains('globe') || lowerClass.contains('globe-asia')) return Icons.public;
    if (lowerClass.contains('link')) return Icons.link;
    if (lowerClass.contains('check') || lowerClass.contains('user-check')) return Icons.check_circle;
    if (lowerClass.contains('lock')) return Icons.lock;
    if (lowerClass.contains('folder')) return Icons.folder;
    if (lowerClass.contains('video')) return Icons.video_library;
    if (lowerClass.contains('camera')) return Icons.camera_alt;
    if (lowerClass.contains('ticket-alt')) return Icons.confirmation_number;
    if (lowerClass.contains('edit') || lowerClass.contains('pen-nib')) return Icons.edit;
    if (lowerClass.contains('fingerprint')) return Icons.fingerprint;
    if (lowerClass.contains('people-arrows')) return Icons.swap_horiz;
    if (lowerClass.contains('clipboard-check')) return Icons.checklist;
    if (lowerClass.contains('recycle') || lowerClass.contains('trash') || lowerClass.contains('undo')) return Icons.delete;
    if (lowerClass.contains('history') || lowerClass.contains('arrow-trend-up')) return Icons.trending_up;
    if (lowerClass.contains('arrow-down-short-wide') || lowerClass.contains('hourglass-half')) return Icons.hourglass_empty;
    if (lowerClass.contains('layer-group')) return Icons.layers;
    if (lowerClass.contains('table-columns') || lowerClass.contains('table-list') || lowerClass.contains('table-cells-large')) return Icons.table_chart;
    if (lowerClass.contains('list-check')) return Icons.checklist;
    if (lowerClass.contains('dice')) return Icons.casino;
    if (lowerClass.contains('mobile-screen-button')) return Icons.smartphone;
    if (lowerClass.contains('google')) return Icons.search;
    
    return Icons.circle;
  }

  void _navigateToRoute(BuildContext context, String route, {String? menuTitle}) {
    Navigator.pop(context); // Close drawer first
    
    // Normalize route - handle role management routes
    if (route == '/roles' || route.startsWith('/roles/')) {
      route = '/role-management';
    }
    
    // Normalize route - handle activity log report routes
    if (route == '/report/activity-log' || route.startsWith('/report/activity-log')) {
      route = '/report/activity-log';
    }
    if (route == '/report-invoice-outlet' || route.startsWith('/report-invoice-outlet')) {
      route = '/report-invoice-outlet';
    }
    if (route == '/stock-cut' || route.startsWith('/stock-cut')) {
      route = '/stock-cut';
    }
    if (route == '/categories' || route.startsWith('/categories')) {
      route = '/categories';
    }
    if (route == '/sub-categories' || route.startsWith('/sub-categories')) {
      route = '/sub-categories';
    }
    if (route == '/units' || route.startsWith('/units')) {
      route = '/units';
    }
    if (route == '/items' || route.startsWith('/items')) {
      route = '/items';
    }

    // List of allowed routes that can be accessed in mobile app
    // Only: Beranda, Sales Outlet Dashboard, My Attendance, Payment, Support Admin
      final allowedRoutes = [
      '/home',
      '/',
      '/video-tutorials/gallery',
      '/sales-outlet-dashboard',
      '/attendance', // My Attendance
      '/attendance-report', // Report Attendance
      '/schedule-attendance-correction', // Schedule/Attendance Correction
      '/purchase-requisitions', // Payment
      '/support/admin', // Support Admin Panel
      '/user-roles', // User Role Settings
      '/role-management', // Role Management
      '/roles', // Role Management (backend route)
      '/report/activity-log', // Activity Log Report
      '/report-invoice-outlet', // Laporan Invoice Outlet
      '/stock-cut', // Stock Cut → native di mobile, WebView di web
      '/user-shifts', // Input Shift Mingguan
      '/packing-list', // Packing List
      '/pr-foods', // PR Foods
      '/food-good-receive', // Good Receive
      '/outlet-food-good-receives', // Outlet Good Receive
      '/good-receive-outlet-supplier', // Outlet Supplier Good Receive
      '/outlet-food-inventory-adjustment', // Outlet Stock Adjustment
      '/food-inventory-adjustment', // Warehouse Stock Adjustment
      '/retail-warehouse-sale', // Penjualan Warehouse Retail
      '/warehouse-sales', // Penjualan Antar Gudang
      '/outlet-rejections', // Outlet Rejection
      '/retail-warehouse-food', // Warehouse Retail Food
      '/outlet-inventory/stock-position', // Stock Position Outlet
      '/inventory/stock-position', // Laporan Stok Akhir Warehouse
      '/inventory/stock-card', // Kartu Stok Gudang
      '/outlet-inventory/stock-card', // Stock Card Outlet
      '/internal-use-waste', // Warehouse Internal Use & Waste
      '/outlet-internal-use-waste', // Category Cost Outlet
      '/outlet-transfer', // Pindah Outlet (Outlet Transfer)
      '/internal-warehouse-transfer', // Internal Warehouse Transfer
      '/retail-food', // Retail Food (Outlet Retail Food)
      '/retail-non-food', // Retail Non Food
      '/outlet-food-return', // Outlet Food Return
      '/head-office-return', // Kelola Return Outlet (Head Office)
      '/stock-opnames', // Outlet Stock Opname
      '/warehouse-stock-opnames', // Warehouse Stock Opname
      '/warehouse-transfer', // Warehouse Transfer
      '/floor-order', // Request Order (RO)
      '/outlet-wip', // Outlet WIP Production
      '/outlet-wip/report', // Laporan Outlet WIP
      '/categories', // Master Data - Categories
      '/sub-categories', // Master Data - Sub Categories
      '/data-levels', // Master Data - Data Level
      '/jabatans', // Master Data - Data Jabatan
      '/units', // Master Data - Units
      '/items', // Master Data - Items
      // Menu Utama (web)
      '/marketing/dashboard',
      '/crm/dashboard',
      '/cashflow-outlet-dashboard',
      '/pr-ops/report',
      '/purchase-requisitions/payment-tracker',
      // Schedule/Attendance Report
      '/schedule-attendance-correction/report',
      // Asset Management
      '/asset-management/dashboard',
      '/asset-management/categories',
      '/asset-management/assets',
      '/asset-management/transfers',
      '/asset-management/maintenance-schedules',
      '/asset-management/maintenances',
      '/asset-management/disposals',
      '/asset-management/documents',
      '/asset-management/depreciations',
      '/asset-management/reports',
      // Master Data (tambah)
      '/repack',
      '/menu-types',
      '/modifiers',
      '/modifier-options',
      '/warehouses',
      '/warehouse-outlets',
      '/warehouse-divisions',
      '/outlets',
      '/customers',
      '/suppliers',
      '/regions',
      '/item-schedules',
      '/fo-schedules',
      '/item-supplier',
      '/investors',
      '/officer-check',
      '/payment-types',
      '/video-tutorials',
      '/video-tutorial-groups',
      '/locked-budget-food-categories',
      '/budget-management',
      '/chart-of-accounts',
      '/bank-accounts',
      // Quality Assurance
      '/qa-categories',
      '/qa-parameters',
      '/qa-guidances',
      '/inspections',
      // Ops Management
      '/master-report',
      '/daily-report',
      '/tickets',
      '/purchase-requisitions/tracking-report',
      // Human Resource (tambah)
      '/divisis',
      '/users',
      '/regional',
      '/man-power-outlet',
      '/admin/job-vacancy',
      '/shifts',
      '/user-shifts/calendar',
      '/attendance/report',
      '/kalender-perusahaan',
      '/attendance-report/employee-summary',
      '/holiday-attendance',
      '/extra-off-report',
      '/payroll/master',
      '/payroll/report',
      '/employee-movements',
      '/employee-resignations',
      '/dynamic-inspections',
      '/coaching',
      '/employee-survey',
      '/employee-survey-report',
      '/master-soal-new',
      '/enroll-test',
      '/my-tests',
      '/enroll-test-report',
      '/leave-management',
      '/travel-kasbon-report',
      // Outlet Management (tambah)
      '/outlet-dashboard',
      '/outlet-stock-balances',
      '/outlet-inventory/inventory-value-report',
      '/outlet-inventory/category-recap-report',
      // Outlet Report
      '/report-sales-simple',
      '/opex-outlet-dashboard',
      '/report-daily-outlet-revenue',
      '/report-weekly-outlet-fb-revenue',
      '/report-daily-revenue-forecast',
      '/report-monthly-fb-revenue-performance',
      '/report-receiving-sheet',
      '/item-engineering',
      // HO Finance
      '/jurnal',
      '/report-jurnal-buku-besar',
      '/report-jurnal-neraca-saldo',
      '/report-arus-kas',
      '/contra-bons',
      '/food-payments',
      '/non-food-payments',
      '/retail-non-food-payment',
      '/opex-report',
      '/opex-by-category',
      '/outlet-payments',
      '/bank-books',
      '/report-sales-pivot-per-outlet-sub-category',
      '/report-rekap-fj',
      '/debt-report',
      // Purchasing
      '/po-foods',
      '/po-ops',
      '/po-report',
      '/po-ops/report',
      // Warehouse (tambah)
      '/food-good-receive-report',
      '/delivery-order',
      '/food-stock-balances',
      '/inventory/goods-received-report',
      '/inventory/cost-history-report',
      '/inventory/minimum-stock-report',
      '/inventory/aging-report',
      '/inventory/po-price-change-report',
      '/inventory/category-recap-report',
      '/inventory/inventory-value-report',
      // Cost Control
      '/mac-report',
      '/mac-anomaly-tracking',
      '/warehouse-mac-tracking',
      '/outlet-stock-report',
      '/cost-report',
      '/internal-use-waste-report',
      '/report-sales-per-category',
      '/report-sales-per-tanggal',
      '/report-sales-all-item-all-outlet',
      '/report-good-receive-outlet',
      '/retail-food/report-supplier',
      '/stock-opname-adjustment-report',
      '/report-rekap-diskon',
      // Production
      '/butcher-processes',
      '/butcher-processes/report',
      '/butcher-processes/stock-cost-report',
      '/butcher-processes/analysis-report',
      '/butcher-summary-report',
      '/mk-production',
      '/mk-production/report',
      // OPS-Kitchen
      '/ops-kitchen/action-plan-guest-review',
      // Sales & Marketing
      '/scrapper-google-review',
      '/promos',
      '/marketing-visit-checklist',
      '/roulette',
      '/menu-book',
      '/web-profile',
      // User Management
      '/menus',
      // Support
      '/monitoring/active-users',
      '/monitoring/server-performance',
      '/cctv-access-requests',
      // Announcement
      '/announcement',
      // CRM
      '/members',
      '/member-notification',
      '/manual-point',
      '/admin/member-apps-settings',
      // LMS
      '/lms/categories',
      '/lms/courses',
      '/lms/quizzes',
      '/lms/questionnaires',
      '/lms/certificate-templates',
      '/lms/schedules',
      '/lms/trainer-report-page',
      '/lms/employee-training-report-page',
      '/lms/training-report-page',
      '/lms/quiz-report-page',
    ];
    
    // Check if route is allowed
    final isAllowedRoute = allowedRoutes.contains(route);
    
    if (route == '/home' || route == '/') {
      // Navigate to home screen, but pop all routes first to go to root
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (context) => const HomeScreen(),
        ),
        (route) => false,
      );
    } else if (route == '/video-tutorials/gallery') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => const VideoTutorialGalleryScreen(),
        ),
      );
    } else if (route == '/sales-outlet-dashboard') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => const SalesOutletDashboardScreen(),
        ),
      );
    } else if (route == '/attendance') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => const MyAttendanceScreen(),
        ),
      );
    } else if (route == '/attendance-report') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => const AttendanceReportScreen(),
        ),
      );
    } else if (route == '/report-sales-simple') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => const SalesReportSimpleScreen(),
        ),
      );
    } else if (route == '/item-engineering') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => const ItemEngineeringScreen(),
        ),
      );
    } else if (route == '/schedule-attendance-correction') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => const ScheduleAttendanceCorrectionScreen(),
        ),
      );
    } else if (route == '/purchase-requisitions') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => const PurchaseRequisitionListScreen(),
        ),
      );
    } else if (route == '/tickets') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => const TicketListScreen(),
        ),
      );
    } else if (route == '/support/admin') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => const SupportAdminPanelScreen(),
        ),
      );
    } else if (route == '/user-roles') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => const UserRoleSettingsScreen(),
        ),
      );
    } else if (route == '/role-management') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => const RoleManagementScreen(),
        ),
      );
    } else if (route == '/report/activity-log') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => const ActivityLogReportScreen(),
        ),
      );
    } else if (route == '/report-invoice-outlet') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => const ReportInvoiceOutletScreen(),
        ),
      );
    } else if (route == '/stock-cut') {
      // Mobile (Android/iOS): native Stock Cut screens; Web: WebView
      if (kIsWeb) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const WebOnlyFeatureScreen(
              featureName: 'Stock Cut (Potong Stock)',
              webPath: '/stock-cut',
            ),
          ),
        );
      } else {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const StockCutIndexScreen(),
          ),
        );
      }
    } else if (route == '/user-shifts') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => const UserShiftInputScreen(),
        ),
      );
    } else if (route == '/packing-list') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => const PackingListIndexScreen(),
        ),
      );
    } else if (route == '/pr-foods') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => const PrFoodIndexScreen(),
        ),
      );
    } else if (route == '/food-good-receive') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => const GoodReceiveIndexScreen(),
        ),
      );
    } else if (route == '/warehouse-transfer') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => const WarehouseTransferIndexScreen(),
        ),
      );
    } else if (route == '/outlet-food-good-receives') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => const OutletFoodGoodReceiveIndexScreen(),
        ),
      );
    } else if (route == '/good-receive-outlet-supplier') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => const OutletSupplierGoodReceiveIndexScreen(),
        ),
      );
    } else if (route == '/outlet-food-inventory-adjustment') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => const OutletStockAdjustmentIndexScreen(),
        ),
      );
    } else if (route == '/food-inventory-adjustment') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => const WarehouseStockAdjustmentIndexScreen(),
        ),
      );
    } else if (route == '/retail-warehouse-sale') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => const RetailWarehouseSaleIndexScreen(),
        ),
      );
    } else if (route == '/warehouse-sales') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => const WarehouseSaleIndexScreen(),
        ),
      );
    } else if (route == '/outlet-rejections') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => const OutletRejectionIndexScreen(),
        ),
      );
    } else if (route == '/retail-warehouse-food') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => const RetailWarehouseFoodIndexScreen(),
        ),
      );
    } else if (route == '/outlet-inventory/stock-position') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => const OutletStockPositionScreen(),
        ),
      );
    } else if (route == '/inventory/stock-position') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => const WarehouseStockPositionScreen(),
        ),
      );
    } else if (route == '/inventory/stock-card') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => const WarehouseStockCardScreen(),
        ),
      );
    } else if (route == '/outlet-inventory/stock-card') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => const OutletStockCardScreen(),
        ),
      );
    } else if (route == '/internal-use-waste') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => const WarehouseInternalUseWasteIndexScreen(),
        ),
      );
    } else if (route == '/outlet-internal-use-waste') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => const CategoryCostOutletIndexScreen(),
        ),
      );
    } else if (route == '/outlet-transfer') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => const OutletTransferIndexScreen(),
        ),
      );
    } else if (route == '/internal-warehouse-transfer') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => const InternalWarehouseTransferIndexScreen(),
        ),
      );
    } else if (route == '/retail-food') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => const RetailFoodIndexScreen(),
        ),
      );
    } else if (route == '/retail-non-food') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => const RetailNonoFoodIndexScreen(),
        ),
      );
    } else if (route == '/floor-order') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => const FloorOrderIndexScreen(),
        ),
      );
    } else if (route == '/outlet-food-return') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => const OutletFoodReturnIndexScreen(),
        ),
      );
    } else if (route == '/head-office-return') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => const HeadOfficeReturnIndexScreen(),
        ),
      );
    } else if (route == '/stock-opnames') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => const StockOpnameIndexScreen(),
        ),
      );
    } else if (route == '/warehouse-stock-opnames') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => const WarehouseStockOpnameIndexScreen(),
        ),
      );
    } else if (route == '/outlet-wip') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => const OutletWIPIndexScreen(),
        ),
      );
    } else if (route == '/outlet-wip/report') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => const OutletWIPReportScreen(),
        ),
      );
    } else if (route == '/member-history') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => const MemberHistorySearchScreen(),
        ),
      );
    } else if (route == '/mk-production') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => const MKProductionIndexScreen(),
        ),
      );
    } else if (route == '/categories') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => const CategoryIndexScreen(),
        ),
      );
    } else if (route == '/sub-categories') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => const SubCategoryIndexScreen(),
        ),
      );
    } else if (route == '/data-levels') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => const DataLevelIndexScreen(),
        ),
      );
    } else if (route == '/jabatans') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => const JabatanIndexScreen(),
        ),
      );
    } else if (route == '/units') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => const UnitIndexScreen(),
        ),
      );
    } else if (route == '/items') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => const WebOnlyFeatureScreen(
            featureName: 'Items',
            webPath: '/items',
          ),
        ),
      );
    } else if (route == '/reservations') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => const ReservationIndexScreen(),
        ),
      );
    } else if (isAllowedRoute) {
      // For allowed routes that don't have native screen, open WebOnlyFeatureScreen with webPath so "Buka di web" works
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => WebOnlyFeatureScreen(
            featureName: menuTitle,
            webPath: route,
          ),
        ),
      );
    } else {
      // Route not in allowed list: still show WebOnlyFeatureScreen with webPath so user can open in browser
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => WebOnlyFeatureScreen(
            featureName: menuTitle,
            webPath: route,
          ),
        ),
      );
    }
  }
}

