import 'dart:async';
import 'package:flutter/material.dart';
import '../services/support_service.dart';
import '../screens/support/support_conversation_list_screen.dart';

class LiveSupportBadge extends StatefulWidget {
  const LiveSupportBadge({super.key});

  @override
  State<LiveSupportBadge> createState() => _LiveSupportBadgeState();
}

class _LiveSupportBadgeState extends State<LiveSupportBadge> {
  final SupportService _service = SupportService();
  int _unreadCount = 0;
  Timer? _pollingTimer;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadUnreadCount();
    _startPolling();
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    super.dispose();
  }

  void _startPolling() {
    // Poll every 30 seconds like notifications
    _pollingTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      _loadUnreadCount();
    });
  }

  Future<void> _loadUnreadCount() async {
    if (_isLoading) return;
    
    setState(() {
      _isLoading = true;
    });

    try {
      final count = await _service.getUnreadConversationsCount();
      if (mounted) {
        setState(() {
          _unreadCount = count;
        });
      }
    } catch (e) {
      // Silently fail, don't show error to user
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _onLiveSupportTap() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const SupportConversationListScreen(),
      ),
    );
    
    // Refresh count after returning from support screen
    if (result == true && mounted) {
      _loadUnreadCount();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        IconButton(
          icon: const Icon(
            Icons.support_agent,
            color: Color(0xFF1A1A1A),
          ),
          onPressed: _onLiveSupportTap,
        ),
        if (_unreadCount > 0)
          Positioned(
            right: 6,
            top: 6,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.orange,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
              ),
              constraints: const BoxConstraints(
                minWidth: 18,
                minHeight: 18,
              ),
              child: Center(
                child: Text(
                  _unreadCount > 99 ? '99+' : '$_unreadCount',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

