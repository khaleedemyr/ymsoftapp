import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../providers/auth_provider.dart';
import '../screens/login_screen.dart';
import '../services/auth_service.dart';

class UserProfileMenu extends StatelessWidget {
  final Map<String, dynamic>? userData;
  final VoidCallback? onProfileTap;
  final VoidCallback? onSignatureTap;
  final VoidCallback? onPinManagementTap;

  const UserProfileMenu({
    super.key,
    this.userData,
    this.onProfileTap,
    this.onSignatureTap,
    this.onPinManagementTap,
  });

  String _getInitials(String? name) {
    if (name == null || name.isEmpty) return 'U';
    final parts = name.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name[0].toUpperCase();
  }

  String _getAvatarUrl() {
    if (userData?['avatar'] != null) {
      return '${AuthService.storageUrl}/storage/${userData!['avatar']}';
    }
    return '';
  }

  String _getJabatan() {
    return userData?['jabatan_name'] ?? 
           userData?['jabatan']?['nama_jabatan'] ?? 
           'N/A';
  }

  String _getLevel() {
    // Handle if level is an object
    final levelObj = userData?['jabatan']?['level'];
    
    if (levelObj != null) {
      // If it's a Map/object, extract the values
      if (levelObj is Map) {
        final namaLevel = levelObj['nama_level'] ?? '';
        final nilaiLevel = levelObj['nilai_level'];
        
        if (namaLevel.isNotEmpty) {
          // Format: "nilai_level - nama_level" or just "nama_level" if nilai_level is null
          if (nilaiLevel != null) {
            return '$nilaiLevel - $namaLevel';
          }
          return namaLevel;
        }
      }
    }
    
    // Fallback to string values
    final level = userData?['jabatan']?['level_name'] ?? 
                  userData?['level_name'] ?? 
                  'N/A';
    
    // If level is still an object (stringified), try to parse it
    if (level is Map) {
      final namaLevel = level['nama_level'] ?? '';
      final nilaiLevel = level['nilai_level'];
      if (namaLevel.isNotEmpty) {
        if (nilaiLevel != null) {
          return '$nilaiLevel - $namaLevel';
        }
        return namaLevel;
      }
    }
    
    return level.toString();
  }

  String _getDivisi() {
    final divisionName = userData?['division_name'] ?? 
                        userData?['division']?['nama_divisi'] ?? 
                        'N/A';
    final divisionCode = userData?['division']?['kode_divisi'] ?? '';
    return divisionCode != '' ? '$divisionCode - $divisionName' : divisionName;
  }

  String _getOutlet() {
    return userData?['outlet_name'] ?? 
           userData?['outlet']?['nama_outlet'] ?? 
           'N/A';
  }

  void _handleMenuAction(BuildContext context, String value) async {
    switch (value) {
      case 'profile':
        onProfileTap?.call();
        // TODO: Navigate to profile screen
        break;
      case 'signature':
        onSignatureTap?.call();
        // TODO: Navigate to signature screen
        break;
      case 'pin':
        onPinManagementTap?.call();
        // TODO: Navigate to PIN management screen
        break;
      case 'logout':
        final confirm = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: const Row(
              children: [
                Icon(Icons.logout, color: Color(0xFF2563EB), size: 24),
                SizedBox(width: 8),
                Text(
                  'Logout',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            content: const Text(
              'Are you sure you want to logout?',
              style: TextStyle(fontSize: 14),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFF6B7280),
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
                child: const Text(
                  'Cancel',
                  style: TextStyle(fontWeight: FontWeight.w500),
                ),
              ),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2563EB),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  elevation: 0,
                ),
                child: const Text(
                  'Logout',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        );

        if (confirm == true && context.mounted) {
          final authProvider = Provider.of<AuthProvider>(context, listen: false);
          await authProvider.logout();

          if (context.mounted) {
            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(builder: (context) => const LoginScreen()),
              (route) => false,
            );
          }
        }
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Builder(
      builder: (builderContext) {
        return PopupMenuButton<String>(
          offset: const Offset(0, 50),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Container(
            margin: const EdgeInsets.only(right: 8),
            child: ClipOval(
              child: _getAvatarUrl().isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: _getAvatarUrl(),
                      width: 36,
                      height: 36,
                      fit: BoxFit.cover,
                      placeholder: (context, url) => Container(
                        width: 36,
                        height: 36,
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Color(0xFF6366F1),
                              Color(0xFF8B5CF6),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                        ),
                        child: Center(
                          child: Text(
                            _getInitials(userData?['nama_lengkap']),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      errorWidget: (context, url, error) => Container(
                        width: 36,
                        height: 36,
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Color(0xFF6366F1),
                              Color(0xFF8B5CF6),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                        ),
                        child: Center(
                          child: Text(
                            _getInitials(userData?['nama_lengkap']),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    )
                  : Container(
                      width: 36,
                      height: 36,
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Color(0xFF6366F1),
                            Color(0xFF8B5CF6),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                      child: Center(
                        child: Text(
                          _getInitials(userData?['nama_lengkap']),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
            ),
          ),
          itemBuilder: (context) => [
            PopupMenuItem<String>(
              enabled: false,
              child: _buildUserInfoCard(),
            ),
            const PopupMenuDivider(),
            PopupMenuItem<String>(
              value: 'profile',
              child: _buildMenuItem(
                icon: Icons.person,
                title: 'Profil',
              ),
            ),
            PopupMenuItem<String>(
              value: 'signature',
              child: _buildMenuItem(
                icon: Icons.edit,
                title: 'Tanda Tangan',
              ),
            ),
            PopupMenuItem<String>(
              value: 'pin',
              child: _buildMenuItem(
                icon: Icons.vpn_key,
                title: 'Kelola PIN Outlet',
              ),
            ),
            const PopupMenuDivider(),
            PopupMenuItem<String>(
              value: 'logout',
              child: _buildMenuItem(
                icon: Icons.logout,
                title: 'Keluar',
                isDestructive: true,
              ),
            ),
          ],
          onSelected: (value) => _handleMenuAction(builderContext, value),
        );
      },
    );
  }

  Widget _buildUserInfoCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Avatar and Name
          Row(
            children: [
              ClipOval(
                child: _getAvatarUrl().isNotEmpty
                    ? CachedNetworkImage(
                        imageUrl: _getAvatarUrl(),
                        width: 48,
                        height: 48,
                        fit: BoxFit.cover,
                        placeholder: (context, url) => Container(
                          width: 48,
                          height: 48,
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Color(0xFF6366F1),
                                Color(0xFF8B5CF6),
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                          ),
                          child: Center(
                            child: Text(
                              _getInitials(userData?['nama_lengkap']),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                        errorWidget: (context, url, error) => Container(
                          width: 48,
                          height: 48,
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Color(0xFF6366F1),
                                Color(0xFF8B5CF6),
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                          ),
                          child: Center(
                            child: Text(
                              _getInitials(userData?['nama_lengkap']),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      )
                    : Container(
                        width: 48,
                        height: 48,
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Color(0xFF6366F1),
                              Color(0xFF8B5CF6),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                        ),
                        child: Center(
                          child: Text(
                            _getInitials(userData?['nama_lengkap']),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  userData?['nama_lengkap'] ?? 'User',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1A1A1A),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // User Details
          _buildInfoRow('Jabatan', _getJabatan()),
          const SizedBox(height: 8),
          _buildInfoRow('Level', _getLevel()),
          const SizedBox(height: 8),
          _buildInfoRow('Divisi', _getDivisi()),
          const SizedBox(height: 8),
          _buildInfoRow('Outlet', _getOutlet()),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 80,
          child: Text(
            '$label:',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade600,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: Color(0xFF1A1A1A),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMenuItem({
    required IconData icon,
    required String title,
    bool isDestructive = false,
  }) {
    return Row(
      children: [
        Icon(
          icon,
          size: 20,
          color: isDestructive ? Colors.red : const Color(0xFF1A1A1A),
        ),
        const SizedBox(width: 12),
        Text(
          title,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: isDestructive ? Colors.red : const Color(0xFF1A1A1A),
          ),
        ),
      ],
    );
  }
}

