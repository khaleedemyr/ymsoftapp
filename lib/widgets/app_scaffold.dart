import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../services/auth_service.dart';
import '../screens/profile_edit_screen.dart';
import '../screens/signature_screen.dart';
import '../screens/pin_management_screen.dart';
import 'app_sidebar.dart';
import 'user_profile_menu.dart';
import 'app_footer.dart';
import 'notification_badge.dart';
import 'live_support_badge.dart';

class AppScaffold extends StatefulWidget {
  final String title;
  final Widget body;
  final List<Widget>? actions;
  final bool showDrawer;
  final FloatingActionButton? floatingActionButton;
  final Widget? bottomNavigationBar;

  const AppScaffold({
    super.key,
    required this.title,
    required this.body,
    this.actions,
    this.showDrawer = true,
    this.floatingActionButton,
    this.bottomNavigationBar,
  });

  @override
  State<AppScaffold> createState() => _AppScaffoldState();
}

class _AppScaffoldState extends State<AppScaffold> {
  Map<String, dynamic>? _userData;
  bool _isLoadingUser = true;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final authService = AuthService();
    // Try to refresh from API first, fallback to cached data
    final refreshResult = await authService.refreshUserData();
    if (refreshResult['success'] == true) {
      if (mounted) {
        setState(() {
          _userData = refreshResult['user'];
          _isLoadingUser = false;
        });
      }
    } else {
      // Fallback to cached data
      final userData = await authService.getUserData();
      if (mounted) {
        setState(() {
          _userData = userData;
          _isLoadingUser = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      drawer: widget.showDrawer ? const AppSidebar() : null,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(
          widget.title,
          style: const TextStyle(
            color: Color(0xFF1A1A1A),
            fontWeight: FontWeight.w600,
          ),
        ),
        leading: widget.showDrawer
            ? Builder(
                builder: (context) => IconButton(
                  icon: const Icon(Icons.menu, color: Color(0xFF1A1A1A)),
                  onPressed: () => Scaffold.of(context).openDrawer(),
                ),
              )
            : (Navigator.of(context).canPop()
                ? IconButton(
                    icon: const Icon(Icons.arrow_back, color: Color(0xFF1A1A1A)),
                    onPressed: () => Navigator.of(context).pop(),
                  )
                : null),
        actions: [
          if (widget.actions != null) ...widget.actions!,
          const LiveSupportBadge(),
          const NotificationBadge(),
          if (!_isLoadingUser)
            UserProfileMenu(
              userData: _userData,
              onProfileTap: () async {
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const ProfileEditScreen(),
                  ),
                );
                if (result == true) {
                  // Refresh user data after profile update
                  _loadUserData();
                }
              },
              onSignatureTap: () async {
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const SignatureScreen(),
                  ),
                );
                if (result == true) {
                  // Refresh user data after signature update
                  _loadUserData();
                }
              },
              onPinManagementTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const PinManagementScreen(),
                  ),
                );
              },
            ),
        ],
      ),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Expanded(child: widget.body),
            const AppFooter(),
          ],
        ),
      ),
      floatingActionButton: widget.floatingActionButton,
      bottomNavigationBar: widget.bottomNavigationBar,
    );
  }
}

