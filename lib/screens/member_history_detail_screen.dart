import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/member_history_models.dart';
import '../services/member_history_service.dart';
import 'member_order_detail_screen.dart';

class MemberHistoryDetailScreen extends StatefulWidget {
  final MemberHistoryModels member;

  const MemberHistoryDetailScreen({
    Key? key,
    required this.member,
  }) : super(key: key);

  @override
  State<MemberHistoryDetailScreen> createState() =>
      _MemberHistoryDetailScreenState();
}

class _MemberHistoryDetailScreenState extends State<MemberHistoryDetailScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _memberHistoryService = MemberHistoryService();

  // Modern color palette
  static const primaryColor = Color(0xFF6C63FF);
  static const secondaryColor = Color(0xFF4CAF50);
  static const accentColor = Color(0xFFFF6B6B);
  static const backgroundColor = Color(0xFFF8F9FA);
  static const cardColor = Colors.white;
  static const textPrimary = Color(0xFF2D3436);
  static const textSecondary = Color(0xFF636E72);

  bool _isLoadingHistory = false;
  bool _isLoadingPreferences = false;
  String? _errorHistory;
  String? _errorPreferences;

  List<OrderHistoryModel> _orders = [];
  int _totalCount = 0;
  double _totalSpending = 0.0;
  String _totalSpendingFormatted = 'Rp 0';

  MemberPreferencesModel? _preferences;

  bool _isLoadingVouchers = false;
  bool _isLoadingChallenges = false;
  String? _errorVouchers;
  String? _errorChallenges;
  List<Map<String, dynamic>> _vouchers = [];
  List<Map<String, dynamic>> _challenges = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    _loadMemberHistory();
    _loadMemberPreferences();
    _loadMemberVouchers();
    _loadMemberChallenges();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadMemberHistory() async {
    setState(() {
      _isLoadingHistory = true;
      _errorHistory = null;
    });

    try {
      final result = await _memberHistoryService.getMemberHistory(
        memberId: widget.member.memberId,
        limit: 50,
        offset: 0,
      );

      if (!mounted) return;

      if (result['success'] == true) {
        setState(() {
          _orders = (result['orders'] as List<dynamic>?)
                  ?.cast<OrderHistoryModel>() ??
              [];
          _totalCount = result['total_count'] ?? 0;
          _totalSpending = (result['total_spending'] is num)
              ? (result['total_spending'] as num).toDouble()
              : 0.0;
          _totalSpendingFormatted =
              result['total_spending_formatted']?.toString() ?? 'Rp 0';
        });
      } else {
        setState(() {
          _errorHistory = result['message']?.toString() ?? 'Gagal memuat data history';
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorHistory = 'Error: ${e.toString()}';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingHistory = false;
        });
      }
    }
  }

  Future<void> _loadMemberVouchers() async {
    setState(() {
      _isLoadingVouchers = true;
      _errorVouchers = null;
    });

    try {
      final result = await _memberHistoryService.getMemberVouchers(
        memberId: widget.member.memberId,
      );

      if (!mounted) return;

      if (result['success'] == true) {
        setState(() {
          _vouchers = (result['vouchers'] as List<dynamic>)
              .map((v) => v as Map<String, dynamic>)
              .toList();
        });
      } else {
        setState(() {
          _errorVouchers = result['message']?.toString() ?? 'Gagal memuat voucher';
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorVouchers = 'Error: ${e.toString()}';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingVouchers = false;
        });
      }
    }
  }

  Future<void> _loadMemberChallenges() async {
    setState(() {
      _isLoadingChallenges = true;
      _errorChallenges = null;
    });

    try {
      final result = await _memberHistoryService.getMemberChallenges(
        memberId: widget.member.memberId,
      );

      if (!mounted) return;

      if (result['success'] == true) {
        setState(() {
          _challenges = (result['challenges'] as List<dynamic>)
              .map((c) => c as Map<String, dynamic>)
              .toList();
        });
      } else {
        setState(() {
          _errorChallenges = result['message']?.toString() ?? 'Gagal memuat challenge';
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorChallenges = 'Error: ${e.toString()}';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingChallenges = false;
        });
      }
    }
  }

  Future<void> _loadMemberPreferences() async {
    setState(() {
      _isLoadingPreferences = true;
      _errorPreferences = null;
    });

    try {
      final result = await _memberHistoryService.getMemberPreferences(
        memberId: widget.member.memberId,
        limit: 10,
      );

      if (!mounted) return;

      if (result['success'] == true) {
        setState(() {
          _preferences = result['preferences'] as MemberPreferencesModel?;
        });
      } else {
        setState(() {
          _errorPreferences =
              result['message']?.toString() ?? 'Gagal memuat data preferensi';
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorPreferences = 'Error: ${e.toString()}';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingPreferences = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) {
          return [
            SliverAppBar(
              expandedHeight: 200,
              floating: false,
              pinned: true,
              backgroundColor: primaryColor,
              elevation: 0,
              flexibleSpace: FlexibleSpaceBar(
                background: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        primaryColor,
                        primaryColor.withOpacity(0.8),
                      ],
                    ),
                  ),
                  child: SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 50, 16, 20),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(3),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.1),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: CircleAvatar(
                              radius: 30,
                              backgroundColor: Colors.grey.shade200,
                              child: widget.member.photo != null
                                  ? ClipOval(
                                      child: Image.network(
                                        widget.member.photo!,
                                        width: 60,
                                        height: 60,
                                        fit: BoxFit.cover,
                                        errorBuilder: (context, error, stackTrace) {
                                          return Icon(Icons.person,
                                              size: 30, color: primaryColor);
                                        },
                                      ),
                                    )
                                  : Icon(Icons.person, size: 30, color: primaryColor),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  widget.member.namaLengkap,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 6),
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withOpacity(0.25),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        widget.member.memberLevel.toUpperCase(),
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFFFD700).withOpacity(0.9),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(Icons.stars, color: Colors.white, size: 12),
                                          const SizedBox(width: 4),
                                          Text(
                                            '${widget.member.justPoints} pts',
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 11,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              bottom: PreferredSize(
                preferredSize: const Size.fromHeight(48),
                child: Container(
                  color: Colors.white,
                  child: TabBar(
                    controller: _tabController,
                    indicatorColor: primaryColor,
                    indicatorWeight: 3,
                    labelColor: primaryColor,
                    unselectedLabelColor: textSecondary,
                    labelStyle: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                    tabs: const [
                      Tab(text: 'Info', icon: Icon(Icons.person_outline, size: 18)),
                      Tab(text: 'History', icon: Icon(Icons.receipt_long, size: 18)),
                      Tab(text: 'Preferences', icon: Icon(Icons.favorite_border, size: 18)),
                      Tab(text: 'Voucher', icon: Icon(Icons.card_giftcard, size: 18)),
                      Tab(text: 'Challenge', icon: Icon(Icons.emoji_events, size: 18)),
                    ],
                  ),
                ),
              ),
            ),
          ];
        },
        body: TabBarView(
          controller: _tabController,
          children: [
            _buildMemberInfoTab(),
            _buildHistoryTab(),
            _buildPreferencesTab(),
            _buildVoucherTab(),
            _buildChallengeTab(),
          ],
        ),
      ),
    );
  }

  Widget _buildMemberInfoTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildStatsCards(),
          const SizedBox(height: 24),
          _buildInfoSection('Informasi Pribadi', [
            _buildModernInfoCard('Email', widget.member.email, Icons.email_outlined),
            _buildModernInfoCard('No HP', widget.member.mobilePhone, Icons.phone_outlined),
            _buildModernInfoCard('Member ID', widget.member.memberId, Icons.badge_outlined),
          ]),
          const SizedBox(height: 16),
          _buildInfoSection('Informasi Tambahan', [
            if (widget.member.tanggalLahir != null)
              _buildModernInfoCard('Tanggal Lahir', _formatDate(widget.member.tanggalLahir!), Icons.cake_outlined),
            if (widget.member.jenisKelamin != null)
              _buildModernInfoCard('Jenis Kelamin', widget.member.jenisKelamin!, Icons.person_outline),
            if (widget.member.pekerjaan != null)
              _buildModernInfoCard('Pekerjaan', widget.member.pekerjaan!, Icons.work_outline),
          ]),
        ],
      ),
    );
  }

  Widget _buildStatsCards() {
    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            'Points',
            widget.member.justPoints.toString(),
            Icons.stars_rounded,
            const Color(0xFFFFD700),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            'Total Spending',
            'Rp ${(widget.member.totalSpending / 1000).toStringAsFixed(0)}K',
            Icons.payments_rounded,
            secondaryColor,
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(height: 12),
          Text(
            label,
            style: TextStyle(
              color: textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              color: textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            color: textPrimary,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(children: children),
        ),
      ],
    );
  }

  String _formatDate(String dateString) {
    try {
      final date = DateTime.parse(dateString);
      return DateFormat('yyyy-MMM-dd').format(date);
    } catch (e) {
      return dateString;
    }
  }

  Widget _buildModernInfoCard(String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: Colors.grey.shade100,
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: primaryColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: primaryColor, size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: TextStyle(
                    color: textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryTab() {
    if (_isLoadingHistory) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorHistory != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 64, color: Colors.red.shade300),
              const SizedBox(height: 16),
              Text(
                _errorHistory!,
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.red.shade700),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _loadMemberHistory,
                child: const Text('Coba Lagi'),
              ),
            ],
          ),
        ),
      );
    }

    if (_orders.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.receipt_long, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(
              'Belum ada history transaksi',
              style: TextStyle(color: Colors.grey.shade600),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [primaryColor, primaryColor.withOpacity(0.8)],
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: primaryColor.withOpacity(0.3),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  children: [
                    const Text(
                      'Total Transaksi',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$_totalCount',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 24,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                width: 1,
                height: 40,
                color: Colors.white30,
              ),
              Expanded(
                child: Column(
                  children: [
                    const Text(
                      'Total Spending',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _totalSpendingFormatted,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: _orders.length,
            itemBuilder: (context, index) {
              final order = _orders[index];
              return TweenAnimationBuilder(
                duration: Duration(milliseconds: 300 + (index * 50)),
                tween: Tween<double>(begin: 0, end: 1),
                builder: (context, double value, child) {
                  return Opacity(
                    opacity: value,
                    child: Transform.translate(
                      offset: Offset(0, 20 * (1 - value)),
                      child: child,
                    ),
                  );
                },
                child: Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: cardColor,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                MemberOrderDetailScreen(orderId: order.id),
                          ),
                        );
                      },
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: secondaryColor.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Icon(Icons.store,
                                      color: secondaryColor, size: 20),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        order.outletName,
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 15,
                                          color: textPrimary,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        order.createdAtFormatted,
                                        style: TextStyle(
                                          color: textSecondary,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Text(
                                  order.grandTotalFormatted,
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                    color: secondaryColor,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                if (order.pointsEarned > 0)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFFFD700).withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Row(
                                      children: [
                                        const Icon(Icons.stars_rounded,
                                            size: 14, color: Color(0xFFFFD700)),
                                        const SizedBox(width: 4),
                                        Text(
                                          '+${order.pointsEarned}',
                                          style: const TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                            color: Color(0xFFFFD700),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                const Spacer(),
                                Icon(Icons.chevron_right,
                                    color: textSecondary, size: 20),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildPreferencesTab() {
    if (_isLoadingPreferences) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorPreferences != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 64, color: Colors.red.shade300),
              const SizedBox(height: 16),
              Text(
                _errorPreferences!,
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.red.shade700),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _loadMemberPreferences,
                child: const Text('Coba Lagi'),
              ),
            ],
          ),
        ),
      );
    }

    if (_preferences == null ||
        (_preferences!.favoriteItems.isEmpty &&
            _preferences!.favoriteOutlet == null)) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.favorite_border, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(
              'Belum ada data preferensi',
              style: TextStyle(color: Colors.grey.shade600),
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_preferences!.favoriteOutlet != null) ...[
            Text(
              'Outlet Favorit',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: textPrimary,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [secondaryColor, secondaryColor.withOpacity(0.8)],
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: secondaryColor.withOpacity(0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.store, color: Colors.white, size: 28),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _preferences!.favoriteOutlet!.namaOutlet,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                '${_preferences!.favoriteOutlet!.visitCount}x kunjungan',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              _preferences!.favoriteOutlet!.totalSpentFormatted,
                              style: const TextStyle(
                                fontSize: 14,
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
          ],
          Text(
            'Menu Favorit',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          if (_preferences!.favoriteItems.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Text(
                  'Belum ada menu favorit',
                  style: TextStyle(color: Colors.grey.shade600),
                ),
              ),
            )
          else
            ...List.generate(_preferences!.favoriteItems.length, (index) {
              final item = _preferences!.favoriteItems[index];
              return TweenAnimationBuilder(
                duration: Duration(milliseconds: 300 + (index * 50)),
                tween: Tween<double>(begin: 0, end: 1),
                builder: (context, double value, child) {
                  return Opacity(
                    opacity: value,
                    child: Transform.translate(
                      offset: Offset(0, 20 * (1 - value)),
                      child: child,
                    ),
                  );
                },
                child: Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: cardColor,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                accentColor.withOpacity(0.8),
                                accentColor,
                              ],
                            ),
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: accentColor.withOpacity(0.3),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Center(
                            child: Text(
                              '${index + 1}',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.itemName,
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                  color: textPrimary,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 8,
                                runSpacing: 4,
                                children: [
                                  _buildSmallChip(
                                    '${item.orderCount}x dipesan',
                                    Icons.repeat,
                                    primaryColor,
                                  ),
                                  _buildSmallChip(
                                    '${item.totalQuantity} porsi',
                                    Icons.shopping_basket_outlined,
                                    secondaryColor,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                item.avgPriceFormatted,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: textSecondary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              if (item.popularModifiers != null &&
                                  item.popularModifiers!.isNotEmpty) ...[
                                const SizedBox(height: 8),
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: backgroundColor,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Pilihan Populer:',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                          color: primaryColor,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      ...item.popularModifiers!.map(
                                        (mod) => Padding(
                                          padding: const EdgeInsets.only(top: 2),
                                          child: Row(
                                            children: [
                                              Container(
                                                width: 4,
                                                height: 4,
                                                decoration: BoxDecoration(
                                                  color: primaryColor,
                                                  shape: BoxShape.circle,
                                                ),
                                              ),
                                              const SizedBox(width: 6),
                                              Expanded(
                                                child: Text(
                                                  '${mod.category}: ${mod.choice} (${mod.frequency}x)',
                                                  style: TextStyle(
                                                    fontSize: 11,
                                                    color: textSecondary,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _buildSmallChip(String label, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVoucherTab() {
    if (_isLoadingVouchers) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorVouchers != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.red),
            const SizedBox(height: 16),
            Text(_errorVouchers!, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadMemberVouchers,
              child: const Text('Coba Lagi'),
            ),
          ],
        ),
      );
    }

    final activeVouchers = _vouchers.where((v) => v['status'] != 'expired' && v['status'] != 'used').toList();
    final expiredVouchers = _vouchers.where((v) => v['status'] == 'expired' || v['status'] == 'used').toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Stats Card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [primaryColor.withOpacity(0.8), primaryColor],
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: primaryColor.withOpacity(0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.card_giftcard, color: Colors.white, size: 32),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${activeVouchers.length} Voucher Aktif',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Gunakan sebelum expired',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Active Vouchers
          if (activeVouchers.isNotEmpty) ...[
            Text(
              'Voucher Tersedia',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: textPrimary,
              ),
            ),
            const SizedBox(height: 12),
            ...activeVouchers.map((voucher) => _buildVoucherCard(voucher)).toList(),
          ],

          // Expired Vouchers
          if (expiredVouchers.isNotEmpty) ...[
            const SizedBox(height: 24),
            Text(
              'Voucher Kadaluarsa',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: textSecondary,
              ),
            ),
            const SizedBox(height: 12),
            ...expiredVouchers.map((voucher) => _buildVoucherCard(voucher)).toList(),
          ],
        ],
      ),
    );
  }

  Widget _buildVoucherCard(Map<String, dynamic> voucher) {
    final isExpired = voucher['status'] == 'expired' || voucher['status'] == 'used';
    final isExpiringSoon = voucher['status'] == 'expiring_soon';
    final daysLeft = (voucher['days_left'] ?? 0).toInt();

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isExpired ? Colors.grey.shade100 : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isExpiringSoon
              ? Colors.orange.withOpacity(0.5)
              : isExpired
                  ? Colors.grey.shade300
                  : primaryColor.withOpacity(0.2),
          width: 2,
        ),
        boxShadow: isExpired
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
      ),
      child: Row(
        children: [
          // Left side - Voucher code
          Container(
            width: 100,
            padding: const EdgeInsets.symmetric(vertical: 20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: isExpired
                    ? [Colors.grey.shade400, Colors.grey.shade500]
                    : isExpiringSoon
                        ? [Colors.orange.shade400, Colors.orange.shade600]
                        : [primaryColor.withOpacity(0.8), primaryColor],
              ),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(14),
                bottomLeft: Radius.circular(14),
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  isExpired ? Icons.block : Icons.local_offer,
                  color: Colors.white,
                  size: 28,
                ),
                const SizedBox(height: 8),
                Text(
                  voucher['code'] as String,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),

          // Right side - Details
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          voucher['title'] as String,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: isExpired ? textSecondary : textPrimary,
                          ),
                        ),
                      ),
                      if (isExpiringSoon)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.orange.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text(
                            'Segera Expired',
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.orange,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      if (isExpired)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.grey.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text(
                            'Expired',
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.grey,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    voucher['description'] as String,
                    style: TextStyle(
                      fontSize: 12,
                      color: textSecondary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(
                        Icons.access_time,
                        size: 14,
                        color: isExpiringSoon ? Colors.orange : textSecondary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        isExpired
                            ? 'Expired ${voucher['expiryDate']}'
                            : 'Berlaku ${daysLeft} hari lagi',
                        style: TextStyle(
                          fontSize: 11,
                          color: isExpiringSoon ? Colors.orange : textSecondary,
                          fontWeight: isExpiringSoon ? FontWeight.w600 : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChallengeTab() {
    if (_isLoadingChallenges) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorChallenges != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.red),
            const SizedBox(height: 16),
            Text(_errorChallenges!, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadMemberChallenges,
              child: const Text('Coba Lagi'),
            ),
          ],
        ),
      );
    }

    final activeCount = _challenges.where((c) => c['status'] != 'completed').length;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Stats Card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [secondaryColor.withOpacity(0.8), secondaryColor],
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: secondaryColor.withOpacity(0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.emoji_events, color: Colors.white, size: 32),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '$activeCount Challenge Aktif',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Selesaikan untuk reward',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          Text(
            'Challenge Kamu',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: textPrimary,
            ),
          ),
          const SizedBox(height: 12),

          ..._challenges.map((challenge) => _buildChallengeCard(challenge)).toList(),
        ],
      ),
    );
  }

  Widget _buildChallengeCard(Map<String, dynamic> challenge) {
    final progress = challenge['progress'] as num;
    final target = challenge['target'] as num;
    final progressPercent = (progress / target).clamp(0.0, 1.0);
    final isCompleted = challenge['status'] == 'completed' || progress >= target;
    final daysLeft = ((challenge['days_left'] ?? 0) as num).toInt();
    final rewardClaimed = challenge['reward_claimed'] as bool? ?? false;
    final rewardExpired = challenge['reward_expired'] as bool? ?? false;
    final rewardDaysLeft = challenge['reward_days_left'] as int?;
    final rewardExpiresAt = challenge['reward_expires_at'] as String?;

    Color getTypeColor(String type) {
      switch (type) {
        case 'transaction':
          return Colors.blue;
        case 'spending':
          return Colors.green;
        case 'referral':
          return Colors.purple;
        case 'streak':
          return Colors.orange;
        default:
          return primaryColor;
      }
    }

    final typeColor = getTypeColor(challenge['type'] as String);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [typeColor.withOpacity(0.7), typeColor],
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    _getChallengeIcon(challenge['type'] as String),
                    color: Colors.white,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        challenge['title'] as String,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        challenge['description'] as String,
                        style: TextStyle(
                          fontSize: 12,
                          color: textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                Row(
                  children: [
                    if (rewardExpired)
                      Container(
                        margin: const EdgeInsets.only(right: 4),
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: accentColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.timer_off,
                              color: accentColor,
                              size: 14,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Expired',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: accentColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                    if (isCompleted && !rewardExpired)
                      Container(
                        margin: const EdgeInsets.only(right: 4),
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: rewardClaimed 
                              ? Colors.orange.withOpacity(0.1)
                              : secondaryColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              rewardClaimed ? Icons.card_giftcard : Icons.redeem,
                              color: rewardClaimed ? Colors.orange : secondaryColor,
                              size: 14,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              rewardClaimed ? 'Claimed' : 'Unclaimed',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: rewardClaimed ? Colors.orange : secondaryColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                    if (isCompleted)
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: secondaryColor.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.check_circle,
                          color: secondaryColor,
                          size: 24,
                        ),
                      ),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Reward expiry info for completed challenges
            if (isCompleted && rewardExpiresAt != null)
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: rewardExpired 
                      ? accentColor.withOpacity(0.05)
                      : (rewardClaimed ? Colors.orange.withOpacity(0.05) : secondaryColor.withOpacity(0.05)),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: rewardExpired 
                        ? accentColor.withOpacity(0.2)
                        : (rewardClaimed ? Colors.orange.withOpacity(0.2) : secondaryColor.withOpacity(0.2)),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      rewardExpired ? Icons.warning_amber_rounded : Icons.info_outline,
                      color: rewardExpired ? accentColor : (rewardClaimed ? Colors.orange : secondaryColor),
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            rewardExpired 
                                ? 'Reward sudah expired'
                                : (rewardClaimed 
                                    ? 'Reward sudah di-redeem'
                                    : 'Reward siap di-redeem'),
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: rewardExpired ? accentColor : (rewardClaimed ? Colors.orange : secondaryColor),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            rewardExpired
                                ? 'Expired pada ${_formatDate(rewardExpiresAt)}'
                                : (rewardClaimed
                                    ? 'Claimed pada ${_formatDate(challenge["reward_claimed_at"] as String? ?? rewardExpiresAt)}'
                                    : 'Expires ${rewardDaysLeft != null ? "dalam $rewardDaysLeft hari" : "segera"} - ${_formatDate(rewardExpiresAt)}'),
                            style: TextStyle(
                              fontSize: 11,
                              color: textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

            // Progress Bar
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      challenge['type'] == 'spending'
                          ? 'Rp ${progress.toInt()} / Rp ${target.toInt()}'
                          : '$progress / $target',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: textPrimary,
                      ),
                    ),
                    Text(
                      '${(progressPercent * 100).toInt()}%',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: typeColor,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: LinearProgressIndicator(
                    value: progressPercent,
                    minHeight: 8,
                    backgroundColor: Colors.grey.shade200,
                    valueColor: AlwaysStoppedAnimation<Color>(typeColor),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Footer
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: backgroundColor,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.card_giftcard, size: 16, color: typeColor),
                  const SizedBox(width: 6),
                  Text(
                    'Reward: ${challenge['reward']}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: textPrimary,
                    ),
                  ),
                  const Spacer(),
                  Icon(Icons.access_time, size: 14, color: textSecondary),
                  const SizedBox(width: 4),
                  Text(
                    '$daysLeft hari lagi',
                    style: TextStyle(
                      fontSize: 11,
                      color: textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _getChallengeIcon(String type) {
    switch (type) {
      case 'transaction':
        return Icons.shopping_cart;
      case 'spending':
        return Icons.payments;
      case 'referral':
        return Icons.people;
      case 'streak':
        return Icons.local_fire_department;
      default:
        return Icons.emoji_events;
    }
  }

  Widget _buildInfoCard(String label, String value, IconData icon) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.blue.shade700),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
