import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../widgets/app_scaffold.dart';
import '../widgets/app_loading_indicator.dart';
import '../services/sales_outlet_dashboard_service.dart';
import '../models/sales_outlet_dashboard_model.dart';

class SalesOutletDashboardScreen extends StatefulWidget {
  const SalesOutletDashboardScreen({super.key});

  @override
  State<SalesOutletDashboardScreen> createState() => _SalesOutletDashboardScreenState();
}

class _SalesOutletDashboardScreenState extends State<SalesOutletDashboardScreen> {
  final SalesOutletDashboardService _service = SalesOutletDashboardService();
  
  SalesOutletDashboardData? _dashboardData;
  bool _isLoading = true;
  String? _error;
  
  DateTime _dateFrom = DateTime.now().copyWith(day: 1);
  DateTime _dateTo = DateTime.now();

  @override
  void initState() {
    super.initState();
    _loadDashboard();
  }

  Future<void> _loadDashboard() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final result = await _service.getDashboard(
        dateFrom: DateFormat('yyyy-MM-dd').format(_dateFrom),
        dateTo: DateFormat('yyyy-MM-dd').format(_dateTo),
      );

      if (result['success'] == true) {
        setState(() {
          _dashboardData = result['data'];
          _isLoading = false;
        });
      } else {
        setState(() {
          _error = result['error'] ?? 'Gagal memuat dashboard';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Error: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _selectDateRange() async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: DateTimeRange(start: _dateFrom, end: _dateTo),
      helpText: 'Pilih Rentang Tanggal',
    );

    if (picked != null) {
      setState(() {
        _dateFrom = picked.start;
        _dateTo = picked.end;
      });
      _loadDashboard();
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Sales Outlet Dashboard',
      body: _isLoading
          ? Center(child: AppLoadingIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.error_outline, size: 64, color: Colors.grey.shade400),
                      const SizedBox(height: 16),
                      Text(
                        _error!,
                        style: TextStyle(color: Colors.grey.shade600),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loadDashboard,
                        child: const Text('Coba Lagi'),
                      ),
                    ],
                  ),
                )
              : _dashboardData == null
                  ? const Center(child: Text('Tidak ada data'))
                  : RefreshIndicator(
                      onRefresh: _loadDashboard,
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Date Range Picker
                            _buildDateRangePicker(),
                            const SizedBox(height: 16),
                            
                            // Overview Metrics
                            _buildOverviewMetrics(_dashboardData!.overview),
                            const SizedBox(height: 16),
                            
                            // Additional Metrics
                            _buildAdditionalMetrics(_dashboardData!.overview, _dashboardData!.promoUsage, _dashboardData!.bankPromoDiscount),
                            const SizedBox(height: 16),
                            
                            // Sales Trend
                            _buildSalesTrend(_dashboardData!.salesTrend),
                            const SizedBox(height: 16),
                            
                            // Hourly Sales
                            _buildHourlySales(_dashboardData!.hourlySales),
                            const SizedBox(height: 16),
                            
                            // Lunch/Dinner Analysis
                            _buildLunchDinnerAnalysis(_dashboardData!.lunchDinnerOrders),
                            const SizedBox(height: 16),
                            
                            // Weekday/Weekend Analysis
                            _buildWeekdayWeekendAnalysis(_dashboardData!.weekdayWeekendRevenue),
                            const SizedBox(height: 16),
                            
                            // Payment Methods
                            _buildPaymentMethods(_dashboardData!.paymentMethods),
                            const SizedBox(height: 16),
                            
                            // Revenue per Outlet by Region
                            _buildRevenuePerOutlet(_dashboardData!.revenuePerOutlet),
                            const SizedBox(height: 16),
                            
                            // Revenue per Outlet by Region (Lunch/Dinner)
                            _buildRevenuePerOutletLunchDinner(_dashboardData!.revenuePerOutletLunchDinner),
                            const SizedBox(height: 16),
                            
                            // Revenue per Outlet by Region (Weekend/Weekday)
                            _buildRevenuePerOutletWeekendWeekday(_dashboardData!.revenuePerOutletWeekendWeekday),
                            const SizedBox(height: 16),
                            
                            // Revenue per Region
                            _buildRevenuePerRegion(_dashboardData!.revenuePerRegion),
                            const SizedBox(height: 16),
                            
                            // Top Items
                            _buildTopItems(_dashboardData!.topItems),
                            const SizedBox(height: 16),
                            
                            // Promo Usage
                            _buildPromoUsage(_dashboardData!.promoUsage, _dashboardData!.bankPromoDiscount),
                          ],
                        ),
                      ),
                    ),
    );
  }

  Widget _buildDateRangePicker() {
    return Card(
      child: InkWell(
        onTap: _selectDateRange,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              const Icon(Icons.calendar_today, color: Color(0xFF6366F1)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Rentang Tanggal',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${DateFormat('dd MMM yyyy', 'id_ID').format(_dateFrom)} - ${DateFormat('dd MMM yyyy', 'id_ID').format(_dateTo)}',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOverviewMetrics(OverviewMetrics overview) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Overview',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 1.5,
          children: [
            _buildMetricCard(
              'Total Orders',
              '${overview.totalOrders}',
              Icons.shopping_cart,
              const Color(0xFF6366F1),
              overview.orderGrowth,
            ),
            _buildMetricCard(
              'Total Revenue',
              _formatCurrency(overview.totalRevenue),
              Icons.attach_money,
              const Color(0xFF10B981),
              overview.revenueGrowth,
            ),
            _buildMetricCard(
              'Avg Order Value',
              _formatCurrency(overview.avgOrderValue),
              Icons.calculate,
              const Color(0xFF8B5CF6),
              null,
            ),
            _buildMetricCard(
              'Total Customers',
              '${overview.totalCustomers}',
              Icons.people,
              const Color(0xFFF59E0B),
              null,
              subtitle: 'Avg ${overview.avgPaxPerOrder.toStringAsFixed(1)} pax/order',
            ),
            _buildMetricCard(
              'Avg Check',
              _formatCurrency(overview.avgCheck),
              Icons.receipt,
              const Color(0xFF06B6D4),
              null,
              subtitle: 'Per customer',
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildAdditionalMetrics(OverviewMetrics overview, PromoUsage promoUsage, BankPromoDiscount bankPromo) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Additional Metrics',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 1.5,
          children: [
            _buildMetricCard(
              'Total Discount',
              _formatCurrency(overview.totalDiscount),
              Icons.percent,
              const Color(0xFFEF4444),
              null,
            ),
            _buildMetricCard(
              'Service Charge',
              _formatCurrency(overview.totalServiceCharge),
              Icons.handshake,
              const Color(0xFFF59E0B),
              null,
            ),
            _buildMetricCard(
              'Commission Fee',
              _formatCurrency(overview.totalCommissionFee),
              Icons.account_balance_wallet,
              const Color(0xFF6366F1),
              null,
            ),
            _buildMetricCard(
              'Promo Usage',
              '${promoUsage.ordersWithPromo}',
              Icons.local_offer,
              const Color(0xFFEC4899),
              null,
              subtitle: '${promoUsage.promoUsagePercentage.toStringAsFixed(1)}% of orders',
            ),
            _buildMetricCard(
              'Bank Promo',
              '${bankPromo.ordersWithBankPromo}',
              Icons.credit_card,
              const Color(0xFF10B981),
              null,
              subtitle: _formatCurrency(bankPromo.totalBankDiscountAmount),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMetricCard(String label, String value, IconData icon, Color color, double? growth, {String? subtitle}) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              color.withOpacity(0.1),
              color.withOpacity(0.05),
            ],
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Icon(icon, color: color, size: 24),
                if (growth != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: growth >= 0 ? Colors.green.shade100 : Colors.red.shade100,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      '${growth >= 0 ? '+' : ''}${growth.toStringAsFixed(1)}%',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: growth >= 0 ? Colors.green.shade700 : Colors.red.shade700,
                      ),
                    ),
                  ),
              ],
            ),
            const Spacer(),
            Text(
              value,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: color,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: Colors.grey.shade600,
              ),
            ),
            if (subtitle != null)
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 10,
                  color: Colors.grey.shade500,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSalesTrend(List<SalesTrend> salesTrend) {
    if (salesTrend.isEmpty) {
      return const SizedBox.shrink();
    }

    final maxRevenue = salesTrend.map((e) => e.revenue).reduce((a, b) => a > b ? a : b);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Sales Trend',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'Klik bar untuk detail',
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.blue.shade700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: salesTrend.length * 50.0 + 20, // Dynamic height based on number of items
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: salesTrend.map((item) {
                  final widthFactor = maxRevenue > 0 ? (item.revenue / maxRevenue).toDouble() : 0.0;
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: GestureDetector(
                      onTap: () => _showOutletListModal(item.period),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          // Period label
                          SizedBox(
                            width: 60,
                            child: Text(
                              DateFormat('dd/MM', 'id_ID').format(DateTime.parse(item.period)),
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                              textAlign: TextAlign.left,
                            ),
                          ),
                          const SizedBox(width: 8),
                          // Bar with value inside
                          Expanded(
                            child: Stack(
                              children: [
                                Container(
                                  height: 36,
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade200,
                                    borderRadius: BorderRadius.circular(18),
                                  ),
                                ),
                                FractionallySizedBox(
                                  widthFactor: widthFactor,
                                  alignment: Alignment.centerLeft,
                                  child: Container(
                                    height: 36,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF6366F1),
                                      borderRadius: BorderRadius.circular(18),
                                    ),
                                    padding: const EdgeInsets.symmetric(horizontal: 10),
                                    alignment: Alignment.centerRight,
                                    child: Text(
                                      _formatCurrency(item.revenue),
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.visible,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showOutletListModal(String selectedDate) async {
    // Show loading first
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: AppLoadingIndicator(),
      ),
    );

    // Fetch outlet details for the selected date
    final result = await _service.getOutletDetailsByDate(
      date: selectedDate,
    );

    if (!mounted) return;
    Navigator.pop(context); // Close loading

    if (result['success'] != true) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result['error'] ?? 'Gagal memuat data outlet'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final data = result['data'];
    final List<Map<String, dynamic>> outlets = [];
    
    if (data != null && data['outlets'] != null) {
      final outletsData = data['outlets'] as List<dynamic>;
      for (var outlet in outletsData) {
        if (outlet is Map<String, dynamic>) {
          double revenue = 0.0;
          if (outlet['revenue'] != null) {
            if (outlet['revenue'] is num) {
              revenue = (outlet['revenue'] as num).toDouble();
            } else if (outlet['revenue'] is String) {
              revenue = double.tryParse(outlet['revenue']) ?? 0.0;
            }
          }
          
          outlets.add({
            'outlet_code': outlet['outlet_code'] ?? '',
            'outlet_name': outlet['outlet_name'] ?? '',
            'total_revenue': revenue,
            'region': outlet['region_name'] ?? '',
            'orders': outlet['orders'] is int ? outlet['orders'] : (outlet['orders'] is num ? (outlet['orders'] as num).toInt() : 0),
            'customers': outlet['customers'] is int ? outlet['customers'] : (outlet['customers'] is num ? (outlet['customers'] as num).toInt() : 0),
          });
        }
      }
    }

    // Sort by revenue descending
    outlets.sort((a, b) => (b['total_revenue'] as double).compareTo(a['total_revenue'] as double));

    // Show summary if available
    final summary = data?['summary'];
    final dateFormatted = data?['date_formatted'] ?? DateFormat('EEEE, dd MMMM yyyy', 'id_ID').format(DateTime.parse(selectedDate));

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (context, scrollController) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              // Handle bar
              Container(
                margin: const EdgeInsets.only(top: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // Header
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Revenue Outlet per Tanggal',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            dateFormatted,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                          ),
                          if (summary != null) ...[
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Icon(Icons.store, size: 14, color: Colors.grey.shade600),
                                const SizedBox(width: 4),
                                Text(
                                  '${summary['total_outlets'] ?? 0} Outlet',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Icon(Icons.attach_money, size: 14, color: Colors.grey.shade600),
                                const SizedBox(width: 4),
                                Text(
                                  summary['total_revenue_formatted'] ?? _formatCurrency((summary['total_revenue'] ?? 0.0).toDouble()),
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: const Color(0xFF10B981),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              // Outlet List
              Expanded(
                child: outlets.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.store_outlined, size: 64, color: Colors.grey.shade400),
                            const SizedBox(height: 16),
                            Text(
                              'Tidak ada data outlet pada tanggal ini',
                              style: TextStyle(color: Colors.grey.shade600),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        controller: scrollController,
                        padding: const EdgeInsets.all(16),
                        itemCount: outlets.length,
                        itemBuilder: (context, index) {
                          final outlet = outlets[index];
                          return Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            child: ListTile(
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              leading: Container(
                                width: 48,
                                height: 48,
                                decoration: BoxDecoration(
                                  color: const Color(0xFF6366F1).withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(
                                  Icons.store,
                                  color: Color(0xFF6366F1),
                                ),
                              ),
                              title: Text(
                                outlet['outlet_name'] ?? outlet['outlet_code'],
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const SizedBox(height: 4),
                                  Text(
                                    outlet['region'] ?? '',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          _formatCurrency(outlet['total_revenue'] as double),
                                          style: const TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.bold,
                                            color: Color(0xFF10B981),
                                          ),
                                        ),
                                      ),
                                      if (outlet['orders'] != null && outlet['orders'] > 0)
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: Colors.blue.shade50,
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: Text(
                                            '${outlet['orders']} orders',
                                            style: TextStyle(
                                              fontSize: 10,
                                              color: Colors.blue.shade700,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ],
                              ),
                              trailing: const Icon(Icons.chevron_right),
                              onTap: () {
                                Navigator.pop(context);
                                _showOutletDailyRevenueModal(
                                  outlet['outlet_code'] as String,
                                  outlet['outlet_name'] as String,
                                  selectedDate,
                                );
                              },
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showOutletDailyRevenueModal(String outletCode, String outletName, String selectedDate) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => _OutletDailyRevenueModal(
        outletCode: outletCode,
        outletName: outletName,
        selectedDate: selectedDate,
        dateFrom: DateFormat('yyyy-MM-dd').format(_dateFrom),
        dateTo: DateFormat('yyyy-MM-dd').format(_dateTo),
        service: _service,
      ),
    );
  }

  Widget _buildTopItems(List<TopItem> topItems) {
    if (topItems.isEmpty) {
      return const SizedBox.shrink();
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Top 10 Items',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            ...topItems.take(10).map((item) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          item.itemName,
                          style: const TextStyle(fontSize: 14),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${item.totalQty}x',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF6366F1),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _formatCurrency(item.totalRevenue),
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                )),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentMethods(List<PaymentMethod> paymentMethods) {
    if (paymentMethods.isEmpty) {
      return const SizedBox.shrink();
    }

    final totalAmount = paymentMethods.fold<double>(0.0, (sum, method) => sum + method.totalAmount);
    final colors = [
      const Color(0xFF3B82F6),
      const Color(0xFF10B981),
      const Color(0xFFF59E0B),
      const Color(0xFFEF4444),
      const Color(0xFF8B5CF6),
      const Color(0xFFEC4899),
      const Color(0xFF06B6D4),
      const Color(0xFF84CC16),
      const Color(0xFFF97316),
      const Color(0xFF6366F1),
    ];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Payment Methods Distribution',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            // Pie Chart - Centered
            Center(
              child: SizedBox(
                width: 200,
                height: 200,
                child: CustomPaint(
                  painter: PieChartPainter(
                    paymentMethods: paymentMethods,
                    totalAmount: totalAmount,
                    colors: colors,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            // Legend - Below chart
            ...paymentMethods.asMap().entries.map((entry) {
              final index = entry.key;
              final method = entry.value;
              final percentage = totalAmount > 0 ? (method.totalAmount / totalAmount) * 100 : 0.0;
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  children: [
                    Container(
                      width: 16,
                      height: 16,
                      decoration: BoxDecoration(
                        color: colors[index % colors.length],
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            method.paymentCode,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${percentage.toStringAsFixed(1)}% • ${method.transactionCount} transaksi',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                          ),
                          Text(
                            _formatCurrency(method.totalAmount),
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF10B981),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ],
        ),
      ),
    );
  }

  Widget _buildLunchDinnerAnalysis(LunchDinnerOrders lunchDinner) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Lunch vs Dinner',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildPeriodCard(
                    'Lunch',
                    lunchDinner.lunch.totalRevenue,
                    lunchDinner.lunch.orderCount,
                    const Color(0xFFF59E0B),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildPeriodCard(
                    'Dinner',
                    lunchDinner.dinner.totalRevenue,
                    lunchDinner.dinner.orderCount,
                    const Color(0xFF6366F1),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWeekdayWeekendAnalysis(WeekdayWeekendRevenue weekdayWeekend) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Weekday vs Weekend',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildPeriodCard(
                    'Weekday',
                    weekdayWeekend.weekday.totalRevenue,
                    weekdayWeekend.weekday.orderCount,
                    const Color(0xFF10B981),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildPeriodCard(
                    'Weekend',
                    weekdayWeekend.weekend.totalRevenue,
                    weekdayWeekend.weekend.orderCount,
                    const Color(0xFF8B5CF6),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPeriodCard(String label, double revenue, int orders, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _formatCurrency(revenue),
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '$orders orders',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPromoUsage(PromoUsage promoUsage, BankPromoDiscount bankPromo) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Promo Usage',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            _buildInfoRow('Orders with Promo', '${promoUsage.ordersWithPromo}'),
            _buildInfoRow('Total Promo Usage', '${promoUsage.totalPromoUsage}'),
            _buildInfoRow('Promo Usage %', '${promoUsage.promoUsagePercentage.toStringAsFixed(1)}%'),
            const Divider(height: 24),
            const Text(
              'Bank Promo Discount',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            _buildInfoRow('Orders with Bank Promo', '${bankPromo.ordersWithBankPromo}'),
            _buildInfoRow('Total Discount', _formatCurrency(bankPromo.totalBankDiscountAmount)),
            _buildInfoRow('Bank Promo %', '${bankPromo.bankPromoPercentage.toStringAsFixed(1)}%'),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade700,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHourlySales(List<HourlySales> hourlySales) {
    if (hourlySales.isEmpty) {
      return const SizedBox.shrink();
    }

    final maxOrders = hourlySales.map((e) => e.orders).reduce((a, b) => a > b ? a : b);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Orders by Hour',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: hourlySales.length * 50.0 + 20, // Dynamic height based on number of items
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: hourlySales.map((item) {
                  final widthFactor = maxOrders > 0 ? (item.orders / maxOrders).toDouble() : 0.0;
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // Hour label
                        SizedBox(
                          width: 60,
                          child: Text(
                            '${item.hour}:00',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                            textAlign: TextAlign.left,
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Bar with value inside
                        Expanded(
                          child: Stack(
                            children: [
                              // Background bar
                              Container(
                                height: 36,
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade200,
                                  borderRadius: BorderRadius.circular(18),
                                ),
                              ),
                              // Colored bar with value inside
                              FractionallySizedBox(
                                widthFactor: widthFactor,
                                alignment: Alignment.centerLeft,
                                child: Container(
                                  height: 36,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF6366F1),
                                    borderRadius: BorderRadius.circular(18),
                                  ),
                                  padding: const EdgeInsets.symmetric(horizontal: 10),
                                  alignment: Alignment.centerRight,
                                  child: Text(
                                    '${item.orders}',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.visible,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRevenuePerOutlet(Map<String, RevenuePerOutletRegion> revenuePerOutlet) {
    if (revenuePerOutlet.isEmpty) {
      return const SizedBox.shrink();
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Revenue per Outlet by Region',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'Klik bar untuk detail',
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.blue.shade700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ...revenuePerOutlet.entries.map((entry) {
              final region = entry.key;
              final data = entry.value;
              
              if (data.outlets.isEmpty) {
                return const SizedBox.shrink();
              }
              
              // Get max revenue for scaling
              final maxRevenue = data.outlets.map((e) => e.totalRevenue).reduce((a, b) => a > b ? a : b);
              
              return Padding(
                padding: const EdgeInsets.only(bottom: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      region,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: data.outlets.length * 60.0 + 50,
                      child: ListView.builder(
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: data.outlets.length,
                        itemBuilder: (context, index) {
                          final outlet = data.outlets[index];
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: GestureDetector(
                              onTap: () => _showOutletDailyRevenueModal(
                                outlet.outletCode,
                                outlet.outletName,
                                DateFormat('yyyy-MM-dd').format(_dateFrom), // selectedDate - will use full date range in modal
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  SizedBox(
                                    width: 100,
                                    child: Text(
                                      outlet.outletName,
                                      style: const TextStyle(fontSize: 12),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Stack(
                                      alignment: Alignment.centerLeft,
                                      children: [
                                        Container(
                                          height: 30,
                                          width: maxRevenue > 0 ? (outlet.totalRevenue / maxRevenue) * MediaQuery.of(context).size.width * 0.6 : 0,
                                          decoration: BoxDecoration(
                                            color: _getRegionColor(region, index),
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                        ),
                                        Padding(
                                          padding: const EdgeInsets.symmetric(horizontal: 8),
                                          child: Text(
                                            _formatCurrency(outlet.totalRevenue),
                                            style: const TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.white,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Color _getRegionColor(String region, int index) {
    final colors = [
      const Color(0xFF3B82F6),
      const Color(0xFF10B981),
      const Color(0xFFF59E0B),
      const Color(0xFFEF4444),
      const Color(0xFF8B5CF6),
      const Color(0xFF06B6D4),
      const Color(0xFF84CC16),
      const Color(0xFFF97316),
    ];
    return colors[index % colors.length];
  }

  Widget _buildRevenuePerOutletLunchDinner(Map<String, RevenuePerOutletRegion> revenuePerOutletLunchDinner) {
    if (revenuePerOutletLunchDinner.isEmpty) {
      return const SizedBox.shrink();
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Revenue per Outlet by Region (Lunch/Dinner)',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            ...revenuePerOutletLunchDinner.entries.map((entry) {
              final region = entry.key;
              final data = entry.value;
              return Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      region,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFF10B981).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Lunch',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF10B981),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _formatCurrency(data.lunch?.totalRevenue ?? 0.0),
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF59E0B).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Dinner',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFFF59E0B),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _formatCurrency(data.dinner?.totalRevenue ?? 0.0),
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildRevenuePerOutletWeekendWeekday(Map<String, RevenuePerOutletRegion> revenuePerOutletWeekendWeekday) {
    if (revenuePerOutletWeekendWeekday.isEmpty) {
      return const SizedBox.shrink();
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Revenue per Outlet by Region (Weekend/Weekday)',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            ...revenuePerOutletWeekendWeekday.entries.map((entry) {
              final region = entry.key;
              final data = entry.value;
              return Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      region,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFF8B5CF6).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Weekend',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF8B5CF6),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _formatCurrency(data.weekend?.totalRevenue ?? 0.0),
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFF3B82F6).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Weekday',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF3B82F6),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _formatCurrency(data.weekday?.totalRevenue ?? 0.0),
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildRevenuePerRegion(RevenuePerRegion revenuePerRegion) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Revenue per Region',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            if (revenuePerRegion.totalRevenue.isNotEmpty) ...[
              const Text(
                'Total Revenue',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              ...revenuePerRegion.totalRevenue.map((region) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            region.regionName,
                            style: const TextStyle(fontSize: 14),
                          ),
                        ),
                        Text(
                          _formatCurrency(region.totalRevenue),
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF10B981),
                          ),
                        ),
                      ],
                    ),
                  )),
              const SizedBox(height: 16),
            ],
            if (revenuePerRegion.lunchDinner.isNotEmpty) ...[
              const Text(
                'Lunch/Dinner Revenue',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              ...revenuePerRegion.lunchDinner.entries.map((entry) {
                final region = entry.key;
                final data = entry.value;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        region,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: const Color(0xFF10B981).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                'Lunch: ${_formatCurrency(data.lunch.totalRevenue)}',
                                style: const TextStyle(fontSize: 12),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF59E0B).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                'Dinner: ${_formatCurrency(data.dinner.totalRevenue)}',
                                style: const TextStyle(fontSize: 12),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              }),
              const SizedBox(height: 16),
            ],
            if (revenuePerRegion.weekdayWeekend.isNotEmpty) ...[
              const Text(
                'Weekday/Weekend Revenue',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              ...revenuePerRegion.weekdayWeekend.entries.map((entry) {
                final region = entry.key;
                final data = entry.value;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        region,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: const Color(0xFF3B82F6).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                'Weekday: ${_formatCurrency(data.weekday.totalRevenue)}',
                                style: const TextStyle(fontSize: 12),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: const Color(0xFF8B5CF6).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                'Weekend: ${_formatCurrency(data.weekend.totalRevenue)}',
                                style: const TextStyle(fontSize: 12),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              }),
            ],
          ],
        ),
      ),
    );
  }

  String _formatCurrency(double amount) {
    return 'Rp ${NumberFormat('#,###', 'id_ID').format(amount)}';
  }
}

class PieChartPainter extends CustomPainter {
  final List<PaymentMethod> paymentMethods;
  final double totalAmount;
  final List<Color> colors;

  PieChartPainter({
    required this.paymentMethods,
    required this.totalAmount,
    required this.colors,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (totalAmount == 0 || paymentMethods.isEmpty) return;

    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2 - 10;
    final rect = Rect.fromCircle(center: center, radius: radius);

    double startAngle = -math.pi / 2; // Start from top

    final textStyle = TextStyle(
      fontSize: 10,
      fontWeight: FontWeight.bold,
      color: Colors.white,
    );

    for (int i = 0; i < paymentMethods.length; i++) {
      final method = paymentMethods[i];
      final sweepAngle = (method.totalAmount / totalAmount) * 2 * math.pi;
      final percentage = (method.totalAmount / totalAmount) * 100;

      final paint = Paint()
        ..color = colors[i % colors.length]
        ..style = PaintingStyle.fill;

      canvas.drawArc(rect, startAngle, sweepAngle, true, paint);

      // Draw border
      final borderPaint = Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2;
      canvas.drawArc(rect, startAngle, sweepAngle, true, borderPaint);

      // Draw labels only for top slices (>= 5%) to avoid clutter
      // Only show label if slice is large enough and not too many labels
      if (percentage >= 5.0 && i < 6) {
        final midAngle = startAngle + sweepAngle / 2;
        
        // Position label outside the pie chart
        final labelRadius = radius + 25; // Position label outside the chart
        final labelX = center.dx + labelRadius * math.cos(midAngle);
        final labelY = center.dy + labelRadius * math.sin(midAngle);

        // Draw line from slice to label
        final lineStartX = center.dx + radius * math.cos(midAngle);
        final lineStartY = center.dy + radius * math.sin(midAngle);
        final lineEndX = center.dx + (radius + 12) * math.cos(midAngle);
        final lineEndY = center.dy + (radius + 12) * math.sin(midAngle);
        
        final linePaint = Paint()
          ..color = colors[i % colors.length].withOpacity(0.6)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5;
        canvas.drawLine(
          Offset(lineStartX, lineStartY),
          Offset(lineEndX, lineEndY),
          linePaint,
        );

        // Draw text - shorter format
        final displayText = method.paymentCode.length > 12 
            ? '${method.paymentCode.substring(0, 12)}...\n${percentage.toStringAsFixed(1)}%'
            : '${method.paymentCode}\n${percentage.toStringAsFixed(1)}%';
        
        final textSpan = TextSpan(
          text: displayText,
          style: textStyle.copyWith(fontSize: 8),
        );
        final textPainter = TextPainter(
          text: textSpan,
          textAlign: TextAlign.center,
          textDirection: ui.TextDirection.ltr,
        );
        textPainter.layout();

        // Determine label position to avoid going outside canvas
        double finalLabelX = labelX;
        double finalLabelY = labelY;
        
        // Adjust if label goes outside bounds
        if (labelX < textPainter.width / 2 + 4) {
          finalLabelX = textPainter.width / 2 + 4;
        } else if (labelX > size.width - textPainter.width / 2 - 4) {
          finalLabelX = size.width - textPainter.width / 2 - 4;
        }
        
        if (labelY < textPainter.height / 2 + 4) {
          finalLabelY = textPainter.height / 2 + 4;
        } else if (labelY > size.height - textPainter.height / 2 - 4) {
          finalLabelY = size.height - textPainter.height / 2 - 4;
        }

        // Draw background rectangle with same color as slice
        final bgRect = Rect.fromCenter(
          center: Offset(finalLabelX, finalLabelY),
          width: textPainter.width + 6,
          height: textPainter.height + 4,
        );
        final bgPaint = Paint()
          ..color = colors[i % colors.length].withOpacity(0.9)
          ..style = PaintingStyle.fill;
        canvas.drawRRect(
          RRect.fromRectAndRadius(bgRect, const Radius.circular(4)),
          bgPaint,
        );

        // Draw border
        final borderPaint = Paint()
          ..color = Colors.white
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1;
        canvas.drawRRect(
          RRect.fromRectAndRadius(bgRect, const Radius.circular(4)),
          borderPaint,
        );

        // Draw text
        textPainter.paint(
          canvas,
          Offset(finalLabelX - textPainter.width / 2, finalLabelY - textPainter.height / 2),
        );
      }

      startAngle += sweepAngle;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// Modal for Outlet Daily Revenue Detail
class _OutletDailyRevenueModal extends StatefulWidget {
  final String outletCode;
  final String outletName;
  final String selectedDate;
  final String dateFrom;
  final String dateTo;
  final SalesOutletDashboardService service;

  const _OutletDailyRevenueModal({
    required this.outletCode,
    required this.outletName,
    required this.selectedDate,
    required this.dateFrom,
    required this.dateTo,
    required this.service,
  });

  @override
  State<_OutletDailyRevenueModal> createState() => _OutletDailyRevenueModalState();
}

class _OutletDailyRevenueModalState extends State<_OutletDailyRevenueModal> {
  Map<String, dynamic>? _data;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final result = await widget.service.getOutletDailyRevenue(
        outletCode: widget.outletCode,
        dateFrom: widget.dateFrom,
        dateTo: widget.dateTo,
      );

      if (result['success'] == true) {
        setState(() {
          _data = result['data'];
          _isLoading = false;
        });
      } else {
        setState(() {
          _error = result['error'] ?? 'Gagal memuat data';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  String _formatCurrency(double amount) {
    return 'Rp ${NumberFormat('#,###', 'id_ID').format(amount)}';
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.all(16),
      child: Container(
        constraints: const BoxConstraints(maxHeight: 600),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF6366F1),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Revenue Harian Outlet',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          widget.outletName,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 14,
                          ),
                        ),
                        if (_data != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            '${_data!['date_range']?['from_formatted']} - ${_data!['date_range']?['to_formatted']}',
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            // Content
            Flexible(
              child: _isLoading
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(32),
                        child: CircularProgressIndicator(),
                      ),
                    )
                  : _error != null
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(32),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.error_outline, size: 64, color: Colors.grey.shade400),
                                const SizedBox(height: 16),
                                Text(
                                  _error!,
                                  style: TextStyle(color: Colors.grey.shade600),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 16),
                                ElevatedButton(
                                  onPressed: _loadData,
                                  child: const Text('Coba Lagi'),
                                ),
                              ],
                            ),
                          ),
                        )
                      : _data == null
                          ? const Center(
                              child: Padding(
                                padding: EdgeInsets.all(32),
                                child: Text('Tidak ada data'),
                              ),
                            )
                          : SingleChildScrollView(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Summary Cards
                                  if (_data!['summary'] != null) ...[
                                    GridView.count(
                                      crossAxisCount: 2,
                                      shrinkWrap: true,
                                      physics: const NeverScrollableScrollPhysics(),
                                      crossAxisSpacing: 12,
                                      mainAxisSpacing: 12,
                                      childAspectRatio: 1.5,
                                      children: [
                                        _buildSummaryCard(
                                          'Total Hari',
                                          '${_data!['summary']['total_days']}',
                                          Icons.calendar_today,
                                          Colors.blue,
                                        ),
                                        _buildSummaryCard(
                                          'Total Revenue',
                                          _data!['summary']['total_revenue_formatted'] ?? _formatCurrency(_data!['summary']['total_revenue']?.toDouble() ?? 0.0),
                                          Icons.attach_money,
                                          Colors.green,
                                        ),
                                        _buildSummaryCard(
                                          'Total Orders',
                                          '${_data!['summary']['total_orders']}',
                                          Icons.receipt,
                                          Colors.orange,
                                        ),
                                        _buildSummaryCard(
                                          'Rata-rata Harian',
                                          _data!['summary']['avg_daily_revenue_formatted'] ?? _formatCurrency(_data!['summary']['avg_daily_revenue']?.toDouble() ?? 0.0),
                                          Icons.trending_up,
                                          Colors.purple,
                                        ),
                                        _buildSummaryCard(
                                          'Average Order',
                                          _data!['summary']['avg_order_value_formatted'] ?? _formatCurrency(
                                            () {
                                              final totalOrders = _data!['summary']['total_orders'];
                                              final totalRevenue = _data!['summary']['total_revenue'];
                                              if (totalOrders != null && totalRevenue != null) {
                                                final orders = totalOrders is int ? totalOrders : (totalOrders is num ? totalOrders.toInt() : 0);
                                                final revenue = totalRevenue is num ? totalRevenue.toDouble() : (totalRevenue is String ? double.tryParse(totalRevenue) ?? 0.0 : 0.0);
                                                return orders > 0 ? revenue / orders : 0.0;
                                              }
                                              return 0.0;
                                            }()
                                          ),
                                          Icons.shopping_cart,
                                          Colors.teal,
                                        ),
                                        _buildSummaryCard(
                                          'Average Check per Pax',
                                          _data!['summary']['avg_check_formatted'] ?? _formatCurrency(
                                            () {
                                              final totalCustomers = _data!['summary']['total_customers'];
                                              final totalRevenue = _data!['summary']['total_revenue'];
                                              if (totalCustomers != null && totalRevenue != null) {
                                                final customers = totalCustomers is int ? totalCustomers : (totalCustomers is num ? totalCustomers.toInt() : 0);
                                                final revenue = totalRevenue is num ? totalRevenue.toDouble() : (totalRevenue is String ? double.tryParse(totalRevenue) ?? 0.0 : 0.0);
                                                return customers > 0 ? revenue / customers : 0.0;
                                              }
                                              return 0.0;
                                            }()
                                          ),
                                          Icons.person,
                                          Colors.indigo,
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 24),
                                  ],
                                  // Daily Details Table
                                  const Text(
                                    'Detail per Hari',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  if (_data!['daily_data'] != null && (_data!['daily_data'] as List).isNotEmpty)
                                    ...(_data!['daily_data'] as List).map((day) {
                                      return Card(
                                        margin: const EdgeInsets.only(bottom: 8),
                                        child: Padding(
                                          padding: const EdgeInsets.all(12),
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                day['date_formatted'] ?? day['date'] ?? '',
                                                style: const TextStyle(
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                              const SizedBox(height: 8),
                                              Row(
                                                children: [
                                                  Expanded(
                                                    child: _buildDetailItem('Orders', '${day['orders'] ?? 0}'),
                                                  ),
                                                  Expanded(
                                                    child: _buildDetailItem('Revenue', day['revenue_formatted'] ?? _formatCurrency(day['revenue']?.toDouble() ?? 0.0)),
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 4),
                                              Row(
                                                children: [
                                                  Expanded(
                                                    child: _buildDetailItem('Customers', '${day['customers'] ?? 0}'),
                                                  ),
                                                  Expanded(
                                                    child: _buildDetailItem('Avg Order', day['avg_order_value_formatted'] ?? _formatCurrency(day['avg_order_value']?.toDouble() ?? 0.0)),
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 4),
                                              Row(
                                                children: [
                                                  Expanded(
                                                    child: _buildDetailItem(
                                                      'Avg Check per Pax',
                                                      day['cover_formatted'] ?? _formatCurrency(
                                                        () {
                                                          final cover = day['cover'];
                                                          if (cover == null) return 0.0;
                                                          if (cover is num) return cover.toDouble();
                                                          if (cover is String) return double.tryParse(cover) ?? 0.0;
                                                          return 0.0;
                                                        }()
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ),
                                      );
                                    }).toList()
                                  else
                                    const Padding(
                                      padding: EdgeInsets.all(32),
                                      child: Center(
                                        child: Text('Tidak ada data untuk periode ini'),
                                      ),
                                    ),
                                ],
                              ),
                            ),
            ),
            // Footer
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(12)),
              ),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.grey.shade600,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Tutup'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailItem(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: Colors.grey.shade600,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}


