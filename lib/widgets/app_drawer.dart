import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../screens/login_screen.dart';
import '../screens/packing_list/packing_list_index_screen.dart';
import '../screens/member_history_search_screen.dart';
import '../screens/categories/category_index_screen.dart';
import '../screens/sub_categories/sub_category_index_screen.dart';
import '../screens/units/unit_index_screen.dart';
import '../screens/items/item_index_screen.dart';

class AppDrawer extends StatelessWidget {
  const AppDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: Column(
        children: [
          // Drawer Header
          Container(
            height: 200,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Color(0xFF6366F1),
                  Color(0xFF8B5CF6),
                  Color(0xFFEC4899),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Menu',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Pilih menu yang ingin Anda akses',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.9),
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          
          // Menu Items
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                // Menu Group: Main
                _buildMenuGroup(
                  context,
                  'Menu Utama',
                  [
                    _buildMenuItem(
                      context,
                      icon: Icons.home,
                      title: 'Home',
                      subtitle: 'Dashboard utama',
                      onTap: () {
                        Navigator.pop(context);
                        // Already on home, just close drawer
                      },
                    ),
                    _buildMenuItem(
                      context,
                      icon: Icons.approval,
                      title: 'Approvals',
                      subtitle: 'Semua approval',
                      onTap: () {
                        Navigator.pop(context);
                        // Navigate to approvals screen if exists
                      },
                    ),
                    _buildMenuItem(
                      context,
                      icon: Icons.inventory_2,
                      title: 'Packing List',
                      subtitle: 'Packing list gudang',
                      color: const Color(0xFF0891B2),
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const PackingListIndexScreen(),
                          ),
                        );
                      },
                    ),
                    _buildMenuItem(
                      context,
                      icon: Icons.history,
                      title: 'Member History',
                      subtitle: 'History & preferensi member',
                      color: const Color(0xFF10B981),
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const MemberHistorySearchScreen(),
                          ),
                        );
                      },
                    ),
                  ],
                ),

                const Divider(height: 32),

                // Menu Group: Master Data
                _buildMenuGroup(
                  context,
                  'Master Data',
                  [
                    _buildMenuItem(
                      context,
                      icon: Icons.category,
                      title: 'Categories',
                      subtitle: 'Kategori master data',
                      color: const Color(0xFF0EA5E9),
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const CategoryIndexScreen(),
                          ),
                        );
                      },
                    ),
                    _buildMenuItem(
                      context,
                      icon: Icons.label,
                      title: 'Sub Categories',
                      subtitle: 'Sub kategori master data',
                      color: const Color(0xFF06B6D4),
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const SubCategoryIndexScreen(),
                          ),
                        );
                      },
                    ),
                    _buildMenuItem(
                      context,
                      icon: Icons.straighten,
                      title: 'Units',
                      subtitle: 'Satuan unit master data',
                      color: const Color(0xFF8B5CF6),
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const UnitIndexScreen(),
                          ),
                        );
                      },
                    ),
                    _buildMenuItem(
                      context,
                      icon: Icons.inventory_2_outlined,
                      title: 'Items',
                      subtitle: 'Master data item / produk',
                      color: const Color(0xFF2563EB),
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const ItemIndexScreen(),
                          ),
                        );
                      },
                    ),
                  ],
                ),

                const Divider(height: 32),

                // Menu Group: Approvals
                _buildMenuGroup(
                  context,
                  'Approval',
                  [
                    _buildMenuItem(
                      context,
                      icon: Icons.shopping_cart,
                      title: 'Purchase Requisition',
                      subtitle: 'PR approvals',
                      color: Colors.green,
                    ),
                    _buildMenuItem(
                      context,
                      icon: Icons.receipt_long,
                      title: 'Purchase Order Ops',
                      subtitle: 'PO Ops approvals',
                      color: Colors.orange,
                    ),
                    _buildMenuItem(
                      context,
                      icon: Icons.event_available,
                      title: 'Leave',
                      subtitle: 'Leave approvals',
                      color: Colors.blue,
                    ),
                    _buildMenuItem(
                      context,
                      icon: Icons.business_center,
                      title: 'HRD',
                      subtitle: 'HRD approvals',
                      color: Colors.purple,
                    ),
                    _buildMenuItem(
                      context,
                      icon: Icons.category,
                      title: 'Category Cost',
                      subtitle: 'Category cost approvals',
                      color: Colors.cyan,
                    ),
                    _buildMenuItem(
                      context,
                      icon: Icons.inventory,
                      title: 'Stock Adjustment',
                      subtitle: 'Stock adjustment approvals',
                      color: Colors.teal,
                    ),
                    _buildMenuItem(
                      context,
                      icon: Icons.account_balance_wallet,
                      title: 'Contra Bon',
                      subtitle: 'Contra bon approvals',
                      color: Colors.indigo,
                    ),
                    _buildMenuItem(
                      context,
                      icon: Icons.swap_horiz,
                      title: 'Employee Movement',
                      subtitle: 'Movement approvals',
                      color: Colors.green,
                    ),
                    _buildMenuItem(
                      context,
                      icon: Icons.school,
                      title: 'Coaching',
                      subtitle: 'Coaching approvals',
                      color: Colors.blue,
                    ),
                    _buildMenuItem(
                      context,
                      icon: Icons.edit,
                      title: 'Correction',
                      subtitle: 'Correction approvals',
                      color: Colors.orange,
                    ),
                    _buildMenuItem(
                      context,
                      icon: Icons.restaurant,
                      title: 'Food Payment',
                      subtitle: 'Food payment approvals',
                      color: Colors.pink,
                    ),
                    _buildMenuItem(
                      context,
                      icon: Icons.shopping_bag,
                      title: 'Non Food Payment',
                      subtitle: 'Non food payment approvals',
                      color: Colors.deepPurple,
                    ),
                    _buildMenuItem(
                      context,
                      icon: Icons.fastfood,
                      title: 'PR Food',
                      subtitle: 'PR Food approvals',
                      color: Colors.amber,
                    ),
                    _buildMenuItem(
                      context,
                      icon: Icons.local_dining,
                      title: 'PO Food',
                      subtitle: 'PO Food approvals',
                      color: Colors.brown,
                    ),
                    _buildMenuItem(
                      context,
                      icon: Icons.store,
                      title: 'RO Khusus',
                      subtitle: 'RO Khusus approvals',
                      color: Colors.deepOrange,
                    ),
                    _buildMenuItem(
                      context,
                      icon: Icons.person_off,
                      title: 'Employee Resignation',
                      subtitle: 'Resignation approvals',
                      color: Colors.red,
                    ),
                  ],
                ),
                
                const Divider(height: 32),
                
                // Menu Group: Settings
                _buildMenuGroup(
                  context,
                  'Pengaturan',
                  [
                    _buildMenuItem(
                      context,
                      icon: Icons.settings,
                      title: 'Settings',
                      subtitle: 'Pengaturan aplikasi',
                      onTap: () {
                        Navigator.pop(context);
                        // Navigate to settings if exists
                      },
                    ),
                    _buildMenuItem(
                      context,
                      icon: Icons.info,
                      title: 'About',
                      subtitle: 'Tentang aplikasi',
                      onTap: () {
                        Navigator.pop(context);
                        // Show about dialog
                        showAboutDialog(
                          context: context,
                          applicationName: 'YM Soft Approval',
                          applicationVersion: '1.0.0',
                          applicationIcon: const Icon(
                            Icons.check_circle,
                            color: Color(0xFF6366F1),
                            size: 48,
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
          
          // Logout Button
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(
                  color: Colors.grey.shade300,
                  width: 1,
                ),
              ),
            ),
            child: _buildMenuItem(
              context,
              icon: Icons.logout,
              title: 'Logout',
              subtitle: 'Keluar dari aplikasi',
              color: Colors.red,
              onTap: () async {
                Navigator.pop(context);
                final authProvider = Provider.of<AuthProvider>(context, listen: false);
                await authProvider.logout();
                if (context.mounted) {
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (context) => const LoginScreen()),
                    (route) => false,
                  );
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuGroup(BuildContext context, String title, List<Widget> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text(
            title,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade600,
              letterSpacing: 0.5,
            ),
          ),
        ),
        ...items,
      ],
    );
  }

  Widget _buildMenuItem(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    Color? color,
    VoidCallback? onTap,
  }) {
    final itemColor = color ?? const Color(0xFF6366F1);
    
    return ListTile(
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: itemColor.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(
          icon,
          color: itemColor,
          size: 20,
        ),
      ),
      title: Text(
        title,
        style: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: Color(0xFF1A1A1A),
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(
          fontSize: 12,
          color: Colors.grey.shade600,
        ),
      ),
      trailing: Icon(
        Icons.chevron_right,
        color: Colors.grey.shade400,
      ),
      onTap: onTap ?? () {
        // Default action: just close drawer
        Navigator.pop(context);
      },
    );
  }
}

