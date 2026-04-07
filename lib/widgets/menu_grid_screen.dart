import 'package:flutter/material.dart';
import '../screens/packing_list/packing_list_index_screen.dart';

/// Alternative menu screen using grid layout
/// Useful when you have many menu items that need to be displayed
class MenuGridScreen extends StatelessWidget {
  const MenuGridScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Menu',
          style: TextStyle(
            color: Color(0xFF1A1A1A),
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Menu Group: Main
            _buildMenuGroup(
              context,
              'Menu Utama',
              [
                _MenuGridItem(
                  icon: Icons.home,
                  title: 'Home',
                  color: const Color(0xFF6366F1),
                  onTap: () {
                    Navigator.pop(context);
                  },
                ),
                _MenuGridItem(
                  icon: Icons.approval,
                  title: 'Approvals',
                  color: Colors.green,
                  onTap: () {
                    Navigator.pop(context);
                  },
                ),
              ],
            ),
            
            const SizedBox(height: 24),
            
            // Menu Group: Approvals
            _buildMenuGroup(
              context,
              'Approval',
              [
                _MenuGridItem(
                  icon: Icons.shopping_cart,
                  title: 'Purchase\nRequisition',
                  color: Colors.green,
                ),
                _MenuGridItem(
                  icon: Icons.receipt_long,
                  title: 'Purchase\nOrder Ops',
                  color: Colors.orange,
                ),
                _MenuGridItem(
                  icon: Icons.event_available,
                  title: 'Leave',
                  color: Colors.blue,
                ),
                _MenuGridItem(
                  icon: Icons.business_center,
                  title: 'HRD',
                  color: Colors.purple,
                ),
                _MenuGridItem(
                  icon: Icons.category,
                  title: 'Category\nCost',
                  color: Colors.cyan,
                ),
                _MenuGridItem(
                  icon: Icons.inventory,
                  title: 'Stock\nAdjustment',
                  color: Colors.teal,
                ),
                _MenuGridItem(
                  icon: Icons.account_balance_wallet,
                  title: 'Contra Bon',
                  color: Colors.indigo,
                ),
                _MenuGridItem(
                  icon: Icons.swap_horiz,
                  title: 'Employee\nMovement',
                  color: Colors.green,
                ),
                _MenuGridItem(
                  icon: Icons.school,
                  title: 'Coaching',
                  color: Colors.blue,
                ),
                _MenuGridItem(
                  icon: Icons.edit,
                  title: 'Correction',
                  color: Colors.orange,
                ),
                _MenuGridItem(
                  icon: Icons.restaurant,
                  title: 'Food\nPayment',
                  color: Colors.pink,
                ),
                _MenuGridItem(
                  icon: Icons.shopping_bag,
                  title: 'Non Food\nPayment',
                  color: Colors.deepPurple,
                ),
                _MenuGridItem(
                  icon: Icons.fastfood,
                  title: 'PR Food',
                  color: Colors.amber,
                ),
                _MenuGridItem(
                  icon: Icons.local_dining,
                  title: 'PO Food',
                  color: Colors.brown,
                ),
                _MenuGridItem(
                  icon: Icons.store,
                  title: 'RO Khusus',
                  color: Colors.deepOrange,
                ),
                _MenuGridItem(
                  icon: Icons.person_off,
                  title: 'Employee\nResignation',
                  color: Colors.red,
                ),
              ],
            ),
            
            const SizedBox(height: 24),
            
            // Menu Group: Gudang (mirip Warehouse Management di ymsofterp)
            _buildMenuGroup(
              context,
              'Gudang',
              [
                _MenuGridItem(
                  icon: Icons.inventory_2,
                  title: 'Packing\nList',
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
              ],
            ),
            
            const SizedBox(height: 24),
            
            // Menu Group: Settings
            _buildMenuGroup(
              context,
              'Pengaturan',
              [
                _MenuGridItem(
                  icon: Icons.settings,
                  title: 'Settings',
                  color: Colors.grey,
                ),
                _MenuGridItem(
                  icon: Icons.info,
                  title: 'About',
                  color: Colors.grey,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuGroup(BuildContext context, String title, List<_MenuGridItem> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Text(
            title,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade700,
            ),
          ),
        ),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 0.9,
          ),
          itemCount: items.length,
          itemBuilder: (context, index) {
            final item = items[index];
            return _buildMenuCard(item);
          },
        ),
      ],
    );
  }

  Widget _buildMenuCard(_MenuGridItem item) {
    return InkWell(
      onTap: item.onTap ?? () {},
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: item.color.withOpacity(0.2),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: item.color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                item.icon,
                color: item.color,
                size: 24,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              item.title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade800,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

class _MenuGridItem {
  final IconData icon;
  final String title;
  final Color color;
  final VoidCallback? onTap;

  _MenuGridItem({
    required this.icon,
    required this.title,
    required this.color,
    this.onTap,
  });
}

