import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/menu_models.dart';
import 'auth_service.dart';

class MenuService {
  static String get baseUrl => '${AuthService.baseUrl}/api/approval-app';
  
  // Menu groups structure matching web AppLayout.vue
  final List<Map<String, dynamic>> _menuGroupsStructure = [
    {
      'title': 'Menu Utama',
      'icon': 'fa-solid fa-bars',
      'collapsible': false,
      'menus': [
        {'name': 'Dashboard', 'icon': 'fa-solid fa-home', 'route': '/home', 'code': 'dashboard'},
        {'name': 'Sales Outlet Dashboard', 'icon': 'fa-solid fa-chart-line', 'route': '/sales-outlet-dashboard', 'code': 'sales_outlet_dashboard'},
        {'name': 'Marketing Dashboard', 'icon': 'fa-solid fa-bullhorn', 'route': '/marketing/dashboard', 'code': 'marketing_dashboard'},
        {'name': 'Dashboard CRM', 'icon': 'fa-solid fa-chart-line', 'route': '/crm/dashboard', 'code': 'crm_dashboard'},
        {'name': 'Cashflow Outlet Dashboard', 'icon': 'fa-solid fa-chart-pie', 'route': '/cashflow-outlet-dashboard', 'code': 'cashflow_outlet_dashboard'},
        {'name': 'My Attendance', 'icon': 'fa-solid fa-user-clock', 'route': '/attendance', 'code': 'my_attendance'},
        {'name': 'Payment', 'icon': 'fa-solid fa-shopping-cart', 'route': '/purchase-requisitions', 'code': 'purchase_requisition_ops'},
        {'name': 'Payment Report', 'icon': 'fa-solid fa-chart-bar', 'route': '/pr-ops/report', 'code': 'pr_ops_report'},
        {'name': 'Payment Approval Tracker', 'icon': 'fa-solid fa-chart-line', 'route': '/purchase-requisitions/payment-tracker', 'code': 'payment_tracker'},
        {'name': 'Video Tutorial Gallery', 'icon': 'fa-solid fa-play-circle', 'route': '/video-tutorials/gallery'},
      ],
    },
    {
      'title': 'Asset Management',
      'icon': 'fa-solid fa-boxes-stacked',
      'collapsible': true,
      'open': false,
      'menus': [
        {'name': 'Dashboard', 'icon': 'fa-solid fa-gauge', 'route': '/asset-management/dashboard', 'code': 'asset_management_dashboard'},
        {'name': 'Asset Categories', 'icon': 'fa-solid fa-tags', 'route': '/asset-management/categories', 'code': 'asset_management_categories'},
        {'name': 'Assets', 'icon': 'fa-solid fa-box', 'route': '/asset-management/assets', 'code': 'asset_management_assets'},
        {'name': 'Transfers', 'icon': 'fa-solid fa-exchange-alt', 'route': '/asset-management/transfers', 'code': 'asset_management_transfers'},
        {'name': 'Maintenance Schedules', 'icon': 'fa-solid fa-calendar-check', 'route': '/asset-management/maintenance-schedules', 'code': 'asset_management_maintenance_schedules'},
        {'name': 'Maintenances', 'icon': 'fa-solid fa-wrench', 'route': '/asset-management/maintenances', 'code': 'asset_management_maintenances'},
        {'name': 'Disposals', 'icon': 'fa-solid fa-trash', 'route': '/asset-management/disposals', 'code': 'asset_management_disposals'},
        {'name': 'Documents', 'icon': 'fa-solid fa-file', 'route': '/asset-management/documents', 'code': 'asset_management_documents'},
        {'name': 'Depreciations', 'icon': 'fa-solid fa-chart-line', 'route': '/asset-management/depreciations', 'code': 'asset_management_depreciations'},
        {'name': 'Reports', 'icon': 'fa-solid fa-chart-bar', 'route': '/asset-management/reports', 'code': 'asset_management_reports'},
      ],
    },
    {
      'title': 'Master Data',
      'icon': 'fa-solid fa-database',
      'collapsible': true,
      'open': false,
      'menus': [
        {'name': 'Categories', 'icon': 'fa-solid fa-tags', 'route': '/categories', 'code': 'categories'},
        {'name': 'Sub Category', 'icon': 'fa-solid fa-tag', 'route': '/sub-categories', 'code': 'sub_categories'},
        {'name': 'Units', 'icon': 'fa-solid fa-ruler', 'route': '/units', 'code': 'units'},
        {'name': 'Items', 'icon': 'fa-solid fa-boxes-stacked', 'route': '/items', 'code': 'items'},
        {'name': 'Repack', 'icon': 'fa-solid fa-box-open', 'route': '/repack', 'code': 'repack'},
        {'name': 'Menu Type', 'icon': 'fa-solid fa-list', 'route': '/menu-types', 'code': 'menu_types'},
        {'name': 'Modifiers', 'icon': 'fa-solid fa-sliders', 'route': '/modifiers', 'code': 'modifiers'},
        {'name': 'Modifier Options', 'icon': 'fa-solid fa-sliders', 'route': '/modifier-options', 'code': 'modifier_options'},
        {'name': 'Warehouses', 'icon': 'fa-solid fa-warehouse', 'route': '/warehouses', 'code': 'warehouses'},
        {'name': 'Warehouse Outlet', 'icon': 'fa-solid fa-store', 'route': '/warehouse-outlets', 'code': 'warehouse_outlets'},
        {'name': 'Warehouse Division', 'icon': 'fa-solid fa-sitemap', 'route': '/warehouse-divisions', 'code': 'warehouse_divisions'},
        {'name': 'Outlets', 'icon': 'fa-solid fa-store', 'route': '/outlets', 'code': 'outlets'},
        {'name': 'Customers', 'icon': 'fa-solid fa-users', 'route': '/customers', 'code': 'customers'},
        {'name': 'Suppliers', 'icon': 'fa-solid fa-truck', 'route': '/suppliers', 'code': 'suppliers'},
        {'name': 'Regions', 'icon': 'fa-solid fa-globe-asia', 'route': '/regions', 'code': 'regions'},
        {'name': 'Item Schedule', 'icon': 'fa-solid fa-calendar-days', 'route': '/item-schedules', 'code': 'item_schedules'},
        {'name': 'RO Schedule', 'icon': 'fa-solid fa-calendar-days', 'route': '/fo-schedules', 'code': 'fo_schedules'},
        {'name': 'Items Supplier', 'icon': 'fa-solid fa-link', 'route': '/item-supplier', 'code': 'view-item-supplier'},
        {'name': 'Data Investor Outlet', 'icon': 'fa-solid fa-user-tie', 'route': '/investors', 'code': 'data_investor_outlet'},
        {'name': 'Officer Check', 'icon': 'fa-solid fa-user-check', 'route': '/officer-check', 'code': 'officer_check'},
        {'name': 'Jenis Pembayaran', 'icon': 'fa-solid fa-money-bill', 'route': '/payment-types', 'code': 'payment_types'},
        {'name': 'Video Tutorial', 'icon': 'fa-solid fa-video', 'route': '/video-tutorials', 'code': 'master-data-video-tutorials'},
        {'name': 'Group Video Tutorial', 'icon': 'fa-solid fa-folder', 'route': '/video-tutorial-groups', 'code': 'master-data-video-tutorial-groups'},
        {'name': 'Locked Budget Food Categories', 'icon': 'fa-solid fa-lock', 'route': '/locked-budget-food-categories', 'code': 'locked_budget_food_categories'},
        {'name': 'Budget Management', 'icon': 'fa-solid fa-chart-pie', 'route': '/budget-management', 'code': 'budget_management'},
        {'name': 'Chart of Account', 'icon': 'fa-solid fa-chart-line', 'route': '/chart-of-accounts', 'code': 'chart_of_account'},
        {'name': 'Master Data Bank', 'icon': 'fa-solid fa-building-columns', 'route': '/bank-accounts', 'code': 'bank_accounts'},
      ],
    },
    {
      'title': 'Quality Assurance',
      'icon': 'fa-solid fa-shield-halved',
      'collapsible': true,
      'open': false,
      'menus': [
        {'name': 'QA Categories', 'icon': 'fa-solid fa-clipboard-list', 'route': '/qa-categories', 'code': 'qa_categories'},
        {'name': 'QA Parameters', 'icon': 'fa-solid fa-cogs', 'route': '/qa-parameters', 'code': 'qa_parameters'},
        {'name': 'QA Guidance', 'icon': 'fa-solid fa-clipboard-check', 'route': '/qa-guidances', 'code': 'qa_guidances'},
        {'name': 'Inspections', 'icon': 'fa-solid fa-camera', 'route': '/inspections', 'code': 'inspections'},
      ],
    },
    {
      'title': 'Ops Management',
      'icon': 'fa-solid fa-cogs',
      'collapsible': true,
      'open': false,
      'menus': [
        {'name': 'Master Daily Report', 'icon': 'fa-solid fa-chart-line', 'route': '/master-report', 'code': 'master_report'},
        {'name': 'Daily Report', 'icon': 'fa-solid fa-clipboard-list', 'route': '/daily-report', 'code': 'daily_report'},
        {'name': 'Ticketing System', 'icon': 'fa-solid fa-ticket-alt', 'route': '/tickets', 'code': 'tickets'},
        {'name': 'PR Tracking Report', 'icon': 'fa-solid fa-timeline', 'route': '/purchase-requisitions/tracking-report', 'code': 'pr_tracking_report'},
      ],
    },
    {
      'title': 'Human Resource',
      'icon': 'fa-solid fa-users-gear',
      'collapsible': true,
      'open': false,
      'menus': [
        {'name': 'Data Level', 'icon': 'fa-solid fa-layer-group', 'route': '/data-levels', 'code': 'data_levels'},
        {'name': 'Data Jabatan', 'icon': 'fa-solid fa-user-tie', 'route': '/jabatans', 'code': 'data_jabatan'},
        {'name': 'Data Divisi', 'icon': 'fa-solid fa-building', 'route': '/divisis', 'code': 'data_divisi'},
        {'name': 'Data Karyawan', 'icon': 'fa-solid fa-users', 'route': '/users', 'code': 'data_karyawan'},
        {'name': 'Regional Management', 'icon': 'fa-solid fa-globe', 'route': '/regional', 'code': 'regional_management'},
        {'name': 'Report Man Power Outlet', 'icon': 'fa-solid fa-users-gear', 'route': '/man-power-outlet', 'code': 'man_power_outlet_report'},
        {'name': 'Job Vacancy', 'icon': 'fa-solid fa-briefcase', 'route': '/admin/job-vacancy', 'code': 'job_vacancy'},
        {'name': 'Master Data Outlet', 'icon': 'fa-solid fa-store', 'route': '/outlets', 'code': 'master-data-outlet'},
        {'name': 'Master Jam Kerja', 'icon': 'fa-solid fa-clock', 'route': '/shifts', 'code': 'shift_view'},
        {'name': 'Input Shift Mingguan', 'icon': 'fa-solid fa-calendar-days', 'route': '/user-shifts', 'code': 'user_shift_view'},
        {'name': 'Kalender Jadwal Shift', 'icon': 'fa-solid fa-calendar-week', 'route': '/user-shifts/calendar', 'code': 'user_shift_calendar_view'},
        {'name': 'Schedule/Attendance Correction', 'icon': 'fa-solid fa-edit', 'route': '/schedule-attendance-correction', 'code': 'schedule_attendance_correction'},
        {'name': 'Report Schedule/Attendance Correction', 'icon': 'fa-solid fa-chart-bar', 'route': '/schedule-attendance-correction/report', 'code': 'schedule_attendance_correction_report'},
        {'name': 'Report Absent', 'icon': 'fa-solid fa-file-lines', 'route': '/attendance/report', 'code': 'absent-report'},
        {'name': 'Libur Nasional', 'icon': 'fa-solid fa-calendar-day', 'route': '/kalender-perusahaan', 'code': 'libur_nasional'},
        {'name': 'Report Attendance', 'icon': 'fa-solid fa-fingerprint', 'route': '/attendance-report', 'code': 'attendance_report'},
        {'name': 'Attendance per Outlet', 'icon': 'fa-solid fa-fingerprint', 'route': '/attendance-report/employee-summary', 'code': 'attendance_outlet_summary'},
        {'name': 'Holiday Attendance', 'icon': 'fa-solid fa-calendar-day', 'route': '/holiday-attendance', 'code': 'holiday_attendance'},
        {'name': 'Extra Off & PH Report', 'icon': 'fa-solid fa-chart-line', 'route': '/extra-off-report', 'code': 'extra_off_report'},
        {'name': 'Master Payroll', 'icon': 'fa-solid fa-money-check-dollar', 'route': '/payroll/master', 'code': 'payroll_master'},
        {'name': 'Payroll', 'icon': 'fa-solid fa-file-invoice-dollar', 'route': '/payroll/report', 'code': 'payroll_report'},
        {'name': 'Employee Movement', 'icon': 'fa-solid fa-people-arrows', 'route': '/employee-movements', 'code': 'employee_movement'},
        {'name': 'Employee Resignation', 'icon': 'fa-solid fa-user-minus', 'route': '/employee-resignations', 'code': 'employee_resignation'},
        {'name': 'Outlet/HO Inspection', 'icon': 'fa-solid fa-clipboard-check', 'route': '/dynamic-inspections', 'code': 'dynamic_inspection'},
        {'name': 'Coaching', 'icon': 'fa-solid fa-user-graduate', 'route': '/coaching', 'code': 'coaching'},
        {'name': 'Employee Survey', 'icon': 'fa-solid fa-clipboard-list', 'route': '/employee-survey', 'code': 'employee_survey'},
        {'name': 'Employee Survey Report', 'icon': 'fa-solid fa-chart-bar', 'route': '/employee-survey-report', 'code': 'employee_survey_report'},
        {'name': 'Master Soal', 'icon': 'fa-solid fa-clipboard-question', 'route': '/master-soal-new', 'code': 'master_soal'},
        {'name': 'Enroll Test', 'icon': 'fa-solid fa-user-graduate', 'route': '/enroll-test', 'code': 'enroll_test'},
        {'name': 'My Tests', 'icon': 'fa-solid fa-clipboard-check', 'route': '/my-tests', 'code': 'my_tests'},
        {'name': 'Report Hasil Test', 'icon': 'fa-solid fa-chart-line', 'route': '/enroll-test-report', 'code': 'enroll_test_report'},
        {'name': 'Manajemen Cuti', 'icon': 'fa-solid fa-calendar-days', 'route': '/leave-management', 'code': 'leave_management'},
        {'name': 'Report Travel & Kasbon', 'icon': 'fa-solid fa-plane', 'route': '/travel-kasbon-report', 'code': 'travel_kasbon_report'},
      ],
    },
    {
      'title': 'Outlet Management',
      'icon': 'fa-solid fa-store',
      'collapsible': true,
      'open': false,
      'menus': [
        {'name': 'Dashboard Sales Outlet', 'icon': 'fa-solid fa-store', 'route': '/outlet-dashboard'},
        {'name': 'Request Order (RO)', 'icon': 'fa-solid fa-calendar-check', 'route': '/floor-order', 'code': 'floor_order'},
        {'name': 'Outlet Good Receive', 'icon': 'fa-solid fa-truck-loading', 'route': '/outlet-food-good-receives', 'code': 'outlet_food_good_receive'},
        {'name': 'Good Receive Outlet Supplier', 'icon': 'fa-solid fa-truck-arrow-right', 'route': '/good-receive-outlet-supplier', 'code': 'good_receive_outlet_supplier'},
        {'name': 'Outlet Stock Adjustment', 'icon': 'fa-solid fa-boxes-stacked', 'route': '/outlet-food-inventory-adjustment', 'code': 'outlet_stock_adjustment'},
        {'name': 'Laporan Stok Akhir Outlet', 'icon': 'fa-solid fa-clipboard-list', 'route': '/outlet-inventory/stock-position', 'code': 'outlet_inventory_stock_position'},
        {'name': 'Saldo Awal Stok Outlet', 'icon': 'fa-solid fa-warehouse', 'route': '/outlet-stock-balances', 'code': 'outlet_stock_balances'},
        {'name': 'Kartu Stok Outlet', 'icon': 'fa-solid fa-file-lines', 'route': '/outlet-inventory/stock-card', 'code': 'outlet_stock_card'},
        {'name': 'Laporan Nilai Persediaan Outlet', 'icon': 'fa-solid fa-coins', 'route': '/outlet-inventory/inventory-value-report', 'code': 'outlet_inventory_value_report'},
        {'name': 'Laporan Rekap Persediaan per Kategori Outlet', 'icon': 'fa-solid fa-chart-pie', 'route': '/outlet-inventory/category-recap-report', 'code': 'outlet_category_recap_report'},
        {'name': 'Category Cost Outlet', 'icon': 'fa-solid fa-trash', 'route': '/outlet-internal-use-waste', 'code': 'outlet_internal_use_waste'},
        {'name': 'Outlet Transfer', 'icon': 'fa-solid fa-right-left', 'route': '/outlet-transfer', 'code': 'outlet_transfer'},
        {'name': 'Internal Warehouse Transfer', 'icon': 'fa-solid fa-exchange-alt', 'route': '/internal-warehouse-transfer', 'code': 'internal_warehouse_transfer'},
        {'name': 'Retail Food', 'icon': 'fa-solid fa-store', 'route': '/retail-food', 'code': 'view-retail-food'},
        {'name': 'Retail Non Food', 'icon': 'fa-solid fa-shopping-bag', 'route': '/retail-non-food', 'code': 'view-retail-non-food'},
        {'name': 'Outlet Food Return', 'icon': 'fa-solid fa-undo', 'route': '/outlet-food-return', 'code': 'outlet_food_return'},
        {'name': 'Stock Opname', 'icon': 'fa-solid fa-clipboard-check', 'route': '/stock-opnames', 'code': 'stock_opname'},
        {'name': 'Report Invoice Outlet', 'icon': 'fa-solid fa-file-invoice', 'route': '/report-invoice-outlet', 'code': 'report_invoice_outlet'},
        {'name': 'Stock Cut', 'icon': 'fa-solid fa-scissors', 'route': '/stock-cut', 'code': 'stock_cut'},
        {'name': 'Outlet WIP Production', 'icon': 'fa-solid fa-industry', 'route': '/outlet-wip', 'code': 'outlet_wip_production'},
        {'name': 'Laporan Outlet WIP', 'icon': 'fa-solid fa-file-lines', 'route': '/outlet-wip/report', 'code': 'outlet_wip_report'},
      ],
    },
    {
      'title': 'Outlet Report',
      'icon': 'fa-solid fa-chart-line',
      'collapsible': true,
      'open': false,
      'menus': [
        {'name': 'Sales Report', 'icon': 'fa-solid fa-chart-line', 'route': '/report-sales-simple', 'code': 'outlet_sales_report'},
        {'name': 'Opex Outlet Dashboard', 'icon': 'fa-solid fa-chart-pie', 'route': '/opex-outlet-dashboard', 'code': 'opex_outlet_dashboard'},
        {'name': 'Daily Outlet Revenue', 'icon': 'fa-solid fa-chart-bar', 'route': '/report-daily-outlet-revenue', 'code': 'daily_outlet_revenue'},
        {'name': 'Weekly Outlet FB Revenue', 'icon': 'fa-solid fa-calendar-week', 'route': '/report-weekly-outlet-fb-revenue', 'code': 'weekly_outlet_fb_revenue'},
        {'name': 'Daily Revenue Forecast', 'icon': 'fa-solid fa-chart-line', 'route': '/report-daily-revenue-forecast', 'code': 'daily_revenue_forecast'},
        {'name': 'Monthly FB Revenue Performance', 'icon': 'fa-solid fa-chart-bar', 'route': '/report-monthly-fb-revenue-performance', 'code': 'monthly_fb_revenue_performance'},
        {'name': 'Receiving Sheet', 'icon': 'fa-solid fa-receipt', 'route': '/report-receiving-sheet', 'code': 'receiving_sheet'},
        {'name': 'Item Engineering', 'icon': 'fa-solid fa-cogs', 'route': '/item-engineering', 'code': 'item_engineering'},
      ],
    },
    {
      'title': 'HO Finance',
      'icon': 'fa-solid fa-building-columns',
      'collapsible': true,
      'open': false,
      'menus': [
        {'name': 'Jurnal', 'icon': 'fa-solid fa-book', 'route': '/jurnal', 'code': 'jurnal'},
        {'name': 'Buku Besar', 'icon': 'fa-solid fa-book-open', 'route': '/report-jurnal-buku-besar', 'code': 'jurnal_buku_besar'},
        {'name': 'Neraca Saldo', 'icon': 'fa-solid fa-balance-scale', 'route': '/report-jurnal-neraca-saldo', 'code': 'jurnal_neraca_saldo'},
        {'name': 'Laporan Arus Kas', 'icon': 'fa-solid fa-water', 'route': '/report-arus-kas', 'code': 'jurnal_arus_kas'},
        {'name': 'Contra Bon', 'icon': 'fa-solid fa-file-circle-xmark', 'route': '/contra-bons', 'code': 'contra_bon'},
        {'name': 'Food Payment', 'icon': 'fa-solid fa-money-bill-transfer', 'route': '/food-payments', 'code': 'food_payment'},
        {'name': 'Non Food Payment', 'icon': 'fa-solid fa-credit-card', 'route': '/non-food-payments', 'code': 'non_food_payment'},
        {'name': 'Retail Non Food Payment', 'icon': 'fa-solid fa-money-bill-wave', 'route': '/retail-non-food-payment', 'code': 'retail_non_food_payment'},
        {'name': 'OPEX Report', 'icon': 'fa-solid fa-chart-line', 'route': '/opex-report', 'code': 'opex_report'},
        {'name': 'OPEX By Category', 'icon': 'fa-solid fa-chart-pie', 'route': '/opex-by-category', 'code': 'opex_by_category'},
        {'name': 'Outlet Payments', 'icon': 'fa-solid fa-money-bill', 'route': '/outlet-payments', 'code': 'outlet_payments'},
        {'name': 'Buku Bank', 'icon': 'fa-solid fa-book', 'route': '/bank-books', 'code': 'bank_books'},
        {'name': 'Report Penjualan Pivot per Outlet per Sub Kategori', 'icon': 'fa-solid fa-table-columns', 'route': '/report-sales-pivot-per-outlet-sub-category', 'code': 'report_sales_pivot_per_outlet_sub_category'},
        {'name': 'Report Rekap FJ', 'icon': 'fa-solid fa-table-list', 'route': '/report-rekap-fj', 'code': 'report_rekap_fj'},
        {'name': 'Report Hutang', 'icon': 'fa-solid fa-file-invoice-dollar', 'route': '/debt-report', 'code': 'debt_report'},
      ],
    },
    {
      'title': 'Purchasing',
      'icon': 'fa-solid fa-shopping-bag',
      'collapsible': true,
      'open': false,
      'menus': [
        {'name': 'Purchase Order Foods', 'icon': 'fa-solid fa-file-invoice-dollar', 'route': '/po-foods', 'code': 'po_foods'},
        {'name': 'Purchase Order Ops', 'icon': 'fa-solid fa-file-invoice', 'route': '/po-ops', 'code': 'purchase_order_ops'},
        {'name': 'Report PO GR', 'icon': 'fa-solid fa-chart-line', 'route': '/po-report', 'code': 'po_report'},
        {'name': 'Report Purchase Order Ops', 'icon': 'fa-solid fa-chart-bar', 'route': '/po-ops/report', 'code': 'po_ops_report'},
      ],
    },
    {
      'title': 'Warehouse Management',
      'icon': 'fa-solid fa-warehouse',
      'collapsible': true,
      'open': false,
      'menus': [
        {'name': 'Purchase Requisition Foods', 'icon': 'fa-solid fa-file-invoice', 'route': '/pr-foods', 'code': 'pr_foods'},
        {'name': 'Good Receive', 'icon': 'fa-solid fa-truck', 'route': '/food-good-receive', 'code': 'food_good_receive'},
        {'name': 'Food Good Receive Report', 'icon': 'fa-solid fa-chart-bar', 'route': '/food-good-receive-report', 'code': 'food_good_receive_report'},
        {'name': 'Pindah Gudang', 'icon': 'fa-solid fa-right-left', 'route': '/warehouse-transfer', 'code': 'warehouse_transfer'},
        {'name': 'Stock Adjustment', 'icon': 'fa-solid fa-boxes-stacked', 'route': '/food-inventory-adjustment', 'code': 'stock_adjustment'},
        {'name': 'Packing List', 'icon': 'fa-solid fa-box', 'route': '/packing-list', 'code': 'packing_list'},
        {'name': 'Delivery Order', 'icon': 'fa-solid fa-truck-arrow-right', 'route': '/delivery-order', 'code': 'delivery_order'},
        {'name': 'Penjualan Warehouse Retail', 'icon': 'fa-solid fa-store', 'route': '/retail-warehouse-sale', 'code': 'retail_warehouse_sale'},
        {'name': 'Warehouse Retail Food', 'icon': 'fa-solid fa-warehouse', 'route': '/retail-warehouse-food', 'code': 'view-retail-warehouse-food'},
        {'name': 'Saldo Awal Stok', 'icon': 'fa-solid fa-money-bill-wave', 'route': '/food-stock-balances', 'code': 'food_stock_balances'},
        {'name': 'Laporan Stok Akhir', 'icon': 'fa-solid fa-clipboard-list', 'route': '/inventory/stock-position', 'code': 'inventory_stock_position'},
        {'name': 'Stock Opname', 'icon': 'fa-solid fa-clipboard-check', 'route': '/warehouse-stock-opnames', 'code': 'warehouse_stock_opname'},
        {'name': 'Laporan Kartu Stok', 'icon': 'fa-solid fa-file-lines', 'route': '/inventory/stock-card', 'code': 'inventory_stock_card'},
        {'name': 'Laporan Penerimaan Barang', 'icon': 'fa-solid fa-truck-ramp-box', 'route': '/inventory/goods-received-report', 'code': 'inventory_goods_received_report'},
        {'name': 'Laporan Nilai Persediaan', 'icon': 'fa-solid fa-money-check-dollar', 'route': '/inventory/inventory-value-report', 'code': 'inventory_value_report'},
        {'name': 'Laporan Riwayat Perubahan Harga Pokok', 'icon': 'fa-solid fa-history', 'route': '/inventory/cost-history-report', 'code': 'inventory_cost_history_report'},
        {'name': 'Laporan Stok Minimum', 'icon': 'fa-solid fa-arrow-down-short-wide', 'route': '/inventory/minimum-stock-report', 'code': 'inventory_minimum_stock_report'},
        {'name': 'Laporan Rekap Persediaan per Kategori', 'icon': 'fa-solid fa-layer-group', 'route': '/inventory/category-recap-report', 'code': 'inventory_category_recap_report'},
        {'name': 'Laporan Aging Persediaan', 'icon': 'fa-solid fa-hourglass-half', 'route': '/inventory/aging-report', 'code': 'inventory_aging_report'},
        {'name': 'Internal Use & Waste', 'icon': 'fa-solid fa-recycle', 'route': '/internal-use-waste', 'code': 'internal_use_waste'},
        {'name': 'Penjualan Antar Gudang', 'icon': 'fa-solid fa-exchange-alt', 'route': '/warehouse-sales', 'code': 'warehouse_sales'},
        {'name': 'Outlet Rejection', 'icon': 'fa-solid fa-undo', 'route': '/outlet-rejections', 'code': 'outlet_rejection'},
        {'name': 'Kelola Return Outlet', 'icon': 'fa-solid fa-undo', 'route': '/head-office-return', 'code': 'head_office_return'},
      ],
    },
    {
      'title': 'Cost Control',
      'icon': 'fa-solid fa-coins',
      'collapsible': true,
      'open': false,
      'menus': [
        {'name': 'Laporan Perubahan Harga PO', 'icon': 'fa-solid fa-arrow-trend-up', 'route': '/inventory/po-price-change-report', 'code': 'po_price_change_report_view'},
        {'name': 'MAC Report', 'icon': 'fa-solid fa-chart-line', 'route': '/mac-report', 'code': 'mac_report'},
        {'name': 'Outlet MAC Tracking', 'icon': 'fa-solid fa-triangle-exclamation', 'route': '/mac-anomaly-tracking', 'code': 'mac_anomaly_tracking'},
        {'name': 'Warehouse MAC Tracking', 'icon': 'fa-solid fa-warehouse', 'route': '/warehouse-mac-tracking', 'code': 'warehouse_mac_tracking'},
        {'name': 'Outlet Stock Report', 'icon': 'fa-solid fa-chart-line', 'route': '/outlet-stock-report', 'code': 'outlet_stock_report'},
        {'name': 'Cost Report', 'icon': 'fa-solid fa-coins', 'route': '/cost-report', 'code': 'cost_report'},
        {'name': 'Report RnD, BM, WM', 'icon': 'fa-solid fa-chart-line', 'route': '/internal-use-waste-report', 'code': 'internal_use_waste_report'},
        {'name': 'Report Penjualan per Category', 'icon': 'fa-solid fa-table-list', 'route': '/report-sales-per-category', 'code': 'report_sales_per_category'},
        {'name': 'Report Penjualan per Tanggal', 'icon': 'fa-solid fa-calendar-day', 'route': '/report-sales-per-tanggal', 'code': 'report_sales_per_tanggal'},
        {'name': 'Report Penjualan All Item ke All Outlet', 'icon': 'fa-solid fa-list-check', 'route': '/report-sales-all-item-all-outlet', 'code': 'report_sales_all_item_all_outlet'},
        {'name': 'Report Good Receive Outlet', 'icon': 'fa-solid fa-table-cells-large', 'route': '/report-good-receive-outlet', 'code': 'report_good_receive_outlet'},
        {'name': 'Report Retail Food per Supplier', 'icon': 'fa-solid fa-chart-line', 'route': '/retail-food/report-supplier', 'code': 'retail_food_supplier_report'},
        {'name': 'Stock Opname Adjustment Report', 'icon': 'fa-solid fa-chart-bar', 'route': '/stock-opname-adjustment-report', 'code': 'stock_opname_adjustment_report'},
        {'name': 'Report Rekap Diskon', 'icon': 'fa-solid fa-tags', 'route': '/report-rekap-diskon', 'code': 'report_rekap_diskon'},
      ],
    },
    {
      'title': 'Production',
      'icon': 'fa-solid fa-industry',
      'collapsible': true,
      'open': false,
      'menus': [
        {'name': 'Butcher', 'icon': 'fa-solid fa-cut', 'route': '/butcher-processes', 'code': 'butcher'},
        {'name': 'Butcher Report', 'icon': 'fa-solid fa-file-lines', 'route': '/butcher-processes/report', 'code': 'butcher_report'},
        {'name': 'Laporan Stok & Cost Butcher', 'icon': 'fa-solid fa-money-bill-trend-up', 'route': '/butcher-processes/stock-cost-report', 'code': 'butcher_stock_cost_report'},
        {'name': 'Laporan Analisis Butcher', 'icon': 'fa-solid fa-chart-line', 'route': '/butcher-processes/analysis-report', 'code': 'butcher_analysis_report'},
        {'name': 'Summary Hasil Butcher', 'icon': 'fa-solid fa-list', 'route': '/butcher-summary-report', 'code': 'butcher_summary_report'},
        {'name': 'MK Production', 'icon': 'fa-solid fa-industry', 'route': '/mk-production', 'code': 'mk_production'},
        {'name': 'Laporan MK Production', 'icon': 'fa-solid fa-file-lines', 'route': '/mk-production/report', 'code': 'mk_production_report'},
      ],
    },
    {
      'title': 'OPS-Kitchen',
      'icon': 'fa-solid fa-utensils',
      'collapsible': true,
      'open': false,
      'menus': [
        {'name': 'Action Plan Guest Review', 'icon': 'fa-solid fa-clipboard-list', 'route': '/ops-kitchen/action-plan-guest-review', 'code': 'ops_kitchen_action_plan_guest_review'},
      ],
    },
    {
      'title': 'Sales & Marketing',
      'icon': 'fa-solid fa-bullhorn',
      'collapsible': true,
      'open': false,
      'menus': [
        {'name': 'Scrapper Google Review', 'icon': 'fa-brands fa-google', 'route': '/scrapper-google-review', 'code': 'scrapper_google_review'},
        {'name': 'Promo', 'icon': 'fa-solid fa-tag', 'route': '/promos', 'code': 'promos'},
        {'name': 'Marketing Visit Checklist', 'icon': 'fa-solid fa-clipboard-check', 'route': '/marketing-visit-checklist', 'code': 'marketing_visit_checklist_view'},
        {'name': 'Reservasi', 'icon': 'fa-solid fa-calendar-check', 'route': '/reservations', 'code': 'reservations'},
        {'name': 'Data Roulette', 'icon': 'fa-solid fa-dice', 'route': '/roulette', 'code': 'data_roulette'},
        {'name': 'Menu Book', 'icon': 'fa-solid fa-book-open', 'route': '/menu-book', 'code': 'menu_book'},
        {'name': 'Web Profile', 'icon': 'fa-solid fa-globe', 'route': '/web-profile', 'code': 'web_profile'},
      ],
    },
    {
      'title': 'User Management',
      'icon': 'fa-solid fa-user-gear',
      'collapsible': true,
      'open': false,
      'menus': [
        {'name': 'Role Management', 'icon': 'fa-solid fa-user-shield', 'route': '/roles', 'code': 'role_management'},
        {'name': 'User Role Setting', 'icon': 'fa-solid fa-users-cog', 'route': '/user-roles', 'code': 'user_role_setting'},
        {'name': 'Menu Management', 'icon': 'fa-solid fa-bars-progress', 'route': '/menus', 'code': 'menu_management'},
      ],
    },
    {
      'title': 'Support',
      'icon': 'fa-solid fa-headset',
      'collapsible': true,
      'open': false,
      'menus': [
        {'name': 'Support Admin Panel', 'icon': 'fa-solid fa-comments', 'route': '/support/admin', 'code': 'support_admin_panel'},
        {'name': 'Monitoring User Aktif', 'icon': 'fa-solid fa-users-line', 'route': '/monitoring/active-users', 'code': 'monitoring_active_users'},
        {'name': 'Server Performance Monitoring', 'icon': 'fa-solid fa-server', 'route': '/monitoring/server-performance', 'code': 'server_performance_monitoring'},
        {'name': 'Activity Log Report', 'icon': 'fa-solid fa-list-alt', 'route': '/report/activity-log', 'code': 'activity_log_report'},
        {'name': 'CCTV Access Request', 'icon': 'fa-solid fa-video', 'route': '/cctv-access-requests', 'code': 'cctv_access_request'},
      ],
    },
    {
      'title': 'Announcement',
      'icon': 'fa-solid fa-bullhorn',
      'collapsible': true,
      'open': false,
      'menus': [
        {'name': 'Announcement', 'icon': 'fa-solid fa-bullhorn', 'route': '/announcement', 'code': 'announcement'},
      ],
    },
    {
      'title': 'CRM',
      'icon': 'fa-solid fa-handshake',
      'collapsible': true,
      'open': false,
      'menus': [
        {'name': 'Data Member', 'icon': 'fa-solid fa-users', 'route': '/members', 'code': 'crm_members'},
        {'name': 'Kirim Notifikasi Member', 'icon': 'fa-solid fa-paper-plane', 'route': '/member-notification', 'code': 'member_notification'},
        {'name': 'Inject Point Manual', 'icon': 'fa-solid fa-syringe', 'route': '/manual-point', 'code': 'manual_point'},
        {'name': 'Member Apps Settings', 'icon': 'fa-solid fa-mobile-screen-button', 'route': '/admin/member-apps-settings', 'code': 'member_apps_settings'},
        {'name': 'Member History & Preferences', 'icon': 'fa-solid fa-history', 'route': '/member-history', 'code': 'member_history_preferences'},
        {'name': 'Guest Comment (OCR)', 'icon': 'fa-solid fa-comment-dots', 'route': '/guest-comment-forms', 'code': 'guest_comment_form'},
      ],
    },
    {
      'title': 'LMS',
      'icon': 'fa-solid fa-graduation-cap',
      'collapsible': true,
      'open': false,
      'menus': [
        {'name': 'Kategori Training', 'icon': 'fa-solid fa-folder', 'route': '/lms/categories', 'code': 'lms-categories'},
        {'name': 'Training', 'icon': 'fa-solid fa-book', 'route': '/lms/courses', 'code': 'lms-courses'},
        {'name': 'Quiz', 'icon': 'fa-solid fa-question-circle', 'route': '/lms/quizzes', 'code': 'lms-quizzes'},
        {'name': 'Kuesioner', 'icon': 'fa-solid fa-clipboard-list', 'route': '/lms/questionnaires', 'code': 'lms-questionnaires'},
        {'name': 'Template Sertifikat', 'icon': 'fa-solid fa-certificate', 'route': '/lms/certificate-templates', 'code': 'lms-certificate-templates'},
        {'name': 'Jadwal Training', 'icon': 'fa-solid fa-calendar-alt', 'route': '/lms/schedules', 'code': 'lms-schedules'},
        {'name': 'Trainer Report', 'icon': 'fa-solid fa-chart-line', 'route': '/lms/trainer-report-page', 'code': 'lms-trainer-report'},
        {'name': 'Laporan Training Karyawan', 'icon': 'fa-solid fa-users', 'route': '/lms/employee-training-report-page', 'code': 'lms-employee-training-report'},
        {'name': 'Training Report', 'icon': 'fa-solid fa-chart-bar', 'route': '/lms/training-report-page', 'code': 'lms-training-report'},
        {'name': 'Quiz Report', 'icon': 'fa-solid fa-question-circle', 'route': '/lms/quiz-report-page', 'code': 'lms-quiz-report'},
      ],
    },
  ];

  Future<List<String>> getAllowedMenus() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');
      
      if (token == null) {
        return [];
      }

      final response = await http.get(
        Uri.parse('$baseUrl/allowed-menus'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return List<String>.from(data['allowedMenus'] ?? []);
      }
      
      return [];
    } catch (e) {
      print('Error fetching allowed menus: $e');
      return [];
    }
  }

  Future<List<MenuGroup>> getMenuGroups() async {
    try {
      final allowedMenus = await getAllowedMenus();
      
      // Filter menu groups based on allowedMenus (same logic as web)
      final filteredGroups = _menuGroupsStructure.map((group) {
        final filteredMenus = (group['menus'] as List).where((menu) {
          final menuCode = menu['code'];
          // If menu has no code, show it. Otherwise check if it's in allowedMenus
          return menuCode == null || allowedMenus.contains(menuCode);
        }).toList();
        
        return {
          ...group,
          'menus': filteredMenus,
        };
      }).where((group) {
        // Only include groups that have at least one menu
        return (group['menus'] as List).isNotEmpty;
      }).toList();

      return filteredGroups.map((g) => MenuGroup.fromJson(g)).toList();
    } catch (e) {
      print('Error getting menu groups: $e');
      return [];
    }
  }
}

