import 'dart:async';
import 'package:flutter/material.dart';
import '../../services/user_role_service.dart';
import '../../models/user_role_models.dart';
import '../../widgets/app_loading_indicator.dart';

class UserRoleSettingsScreen extends StatefulWidget {
  const UserRoleSettingsScreen({super.key});

  @override
  State<UserRoleSettingsScreen> createState() => _UserRoleSettingsScreenState();
}

class _UserRoleSettingsScreenState extends State<UserRoleSettingsScreen> with SingleTickerProviderStateMixin {
  final UserRoleService _userRoleService = UserRoleService();
  List<UserRole> _users = [];
  List<Role> _roles = [];
  List<FilterOption> _outlets = [];
  List<FilterOption> _divisions = [];
  
  bool _isLoading = true;
  bool _isRefreshing = false;
  String? _errorMessage;
  
  // Filters
  int? _selectedOutletId;
  int? _selectedDivisionId;
  int? _selectedRoleId;
  String _searchQuery = '';
  
  // Selection for bulk assign
  Set<int> _selectedUserIds = {};
  bool _isSelectMode = false;
  
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();
  late AnimationController _animationController;
  Timer? _searchDebounce;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _loadData();
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _scrollController.dispose();
    _searchController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _loadData({bool refresh = false}) async {
    if (refresh) {
      setState(() {
        _isRefreshing = true;
        _errorMessage = null;
      });
    } else {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }

    try {
      final result = await _userRoleService.getUsers(
        outletId: _selectedOutletId,
        divisionId: _selectedDivisionId,
        roleId: _selectedRoleId,
        search: _searchQuery.isNotEmpty ? _searchQuery : null,
      );

      if (result['success'] == true && mounted) {
        final data = result['data']['data'];
        if (data != null) {
          final usersData = data['users'] as List<dynamic>? ?? [];
          final rolesData = data['roles'] as List<dynamic>? ?? [];
          final outletsData = data['outlets'] as List<dynamic>? ?? [];
          final divisionsData = data['divisions'] as List<dynamic>? ?? [];

          setState(() {
            _users = usersData.map((json) => UserRole.fromJson(json)).toList();
            _roles = rolesData.map((json) => Role.fromJson(json)).toList();
            _outlets = outletsData.map((json) => FilterOption.fromJson(json)).toList();
            _divisions = divisionsData.map((json) => FilterOption.fromJson(json)).toList();
            _errorMessage = null;
          });
          
          _animationController.forward();
        }
      } else if (mounted) {
        setState(() {
          _errorMessage = result['message'] ?? 'Failed to load data';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Error: ${e.toString()}';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isRefreshing = false;
        });
      }
    }
  }

  void _applyFilters() {
    _loadData();
  }

  void _clearFilters() {
    setState(() {
      _selectedOutletId = null;
      _selectedDivisionId = null;
      _selectedRoleId = null;
      _searchQuery = '';
      _searchController.clear();
    });
    _loadData();
  }

  Future<void> _updateUserRole(int userId, int roleId) async {
    try {
      final result = await _userRoleService.updateUserRole(userId, roleId);
      
      if (result['success'] == true && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message'] ?? 'Role updated successfully'),
            backgroundColor: Colors.green,
          ),
        );
        _loadData(refresh: true);
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message'] ?? 'Failed to update role'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _bulkAssignRole() async {
    if (_selectedUserIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select at least one user'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // Show bottom sheet to select role
    final selectedRole = await _showRoleSelectionBottomSheetForBulk();

    if (selectedRole != null) {
      try {
        final result = await _userRoleService.bulkAssignRole(
          _selectedUserIds.toList(),
          selectedRole.id,
        );

        if (result['success'] == true && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result['message'] ?? 'Roles assigned successfully'),
              backgroundColor: Colors.green,
            ),
          );
          setState(() {
            _selectedUserIds.clear();
            _isSelectMode = false;
          });
          _loadData(refresh: true);
        } else if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result['message'] ?? 'Failed to assign roles'),
              backgroundColor: Colors.red,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error: ${e.toString()}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<Role?> _showRoleSelectionBottomSheetForBulk() async {
    final searchController = TextEditingController();
    List<Role> filteredRoles = List.from(_roles);
    Role? selectedRole;
    
    return await showModalBottomSheet<Role>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          return Container(
            height: MediaQuery.of(context).size.height * 0.7,
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Column(
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(color: Colors.grey.shade200),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Select Role',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                ),
                // Search
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: TextField(
                    controller: searchController,
                    decoration: InputDecoration(
                      hintText: 'Search role...',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: searchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                searchController.clear();
                                setModalState(() {
                                  filteredRoles = List.from(_roles);
                                });
                              },
                            )
                          : null,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      filled: true,
                      fillColor: Colors.grey.shade50,
                    ),
                    onChanged: (value) {
                      setModalState(() {
                        if (value.isEmpty) {
                          filteredRoles = List.from(_roles);
                        } else {
                          filteredRoles = _roles.where((role) {
                            return role.name.toLowerCase().contains(value.toLowerCase()) ||
                                   (role.description != null && role.description!.toLowerCase().contains(value.toLowerCase()));
                          }).toList();
                        }
                      });
                    },
                  ),
                ),
                // List
                Expanded(
                  child: ListView.builder(
                    itemCount: filteredRoles.length,
                    itemBuilder: (context, index) {
                      final role = filteredRoles[index];
                      final isSelected = selectedRole?.id == role.id;
                      
                      return ListTile(
                        title: Text(
                          role.name,
                          style: TextStyle(
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            color: isSelected ? const Color(0xFF6366F1) : Colors.black,
                          ),
                        ),
                        subtitle: role.description != null ? Text(role.description!) : null,
                        trailing: isSelected
                            ? const Icon(Icons.check, color: Color(0xFF6366F1))
                            : null,
                        onTap: () {
                          setModalState(() {
                            selectedRole = role;
                          });
                          Navigator.pop(context, role);
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _showRoleSelectionBottomSheet(UserRole user) async {
    final searchController = TextEditingController();
    List<Role> filteredRoles = List.from(_roles);
    
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          return Container(
            height: MediaQuery.of(context).size.height * 0.7,
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Column(
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(color: Colors.grey.shade200),
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Select Role',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              'For: ${user.namaLengkap}',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade600,
                              ),
                            ),
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
                // Search
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: TextField(
                    controller: searchController,
                    decoration: InputDecoration(
                      hintText: 'Search role...',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: searchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                searchController.clear();
                                setModalState(() {
                                  filteredRoles = List.from(_roles);
                                });
                              },
                            )
                          : null,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      filled: true,
                      fillColor: Colors.grey.shade50,
                    ),
                    onChanged: (value) {
                      setModalState(() {
                        if (value.isEmpty) {
                          filteredRoles = List.from(_roles);
                        } else {
                          filteredRoles = _roles.where((role) {
                            return role.name.toLowerCase().contains(value.toLowerCase()) ||
                                   (role.description != null && role.description!.toLowerCase().contains(value.toLowerCase()));
                          }).toList();
                        }
                      });
                    },
                  ),
                ),
                // List
                Expanded(
                  child: ListView.builder(
                    itemCount: filteredRoles.length + 1, // +1 for "No Role"
                    itemBuilder: (context, index) {
                      if (index == 0) {
                        final isSelected = user.roleId == null;
                        return ListTile(
                          title: Text(
                            'No Role',
                            style: TextStyle(
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                              color: isSelected ? const Color(0xFF6366F1) : Colors.black,
                            ),
                          ),
                          trailing: isSelected
                              ? const Icon(Icons.check, color: Color(0xFF6366F1))
                              : null,
                          onTap: () {
                            Navigator.pop(context);
                            // Remove role
                            if (user.roleId != null) {
                              // You might want to add a method to remove role
                              // For now, we'll just close
                            }
                          },
                        );
                      }
                      
                      final role = filteredRoles[index - 1];
                      final isSelected = user.roleId == role.id;
                      
                      return ListTile(
                        title: Text(
                          role.name,
                          style: TextStyle(
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            color: isSelected ? const Color(0xFF6366F1) : Colors.black,
                          ),
                        ),
                        subtitle: role.description != null ? Text(role.description!) : null,
                        trailing: isSelected
                            ? const Icon(Icons.check, color: Color(0xFF6366F1))
                            : null,
                        onTap: () {
                          Navigator.pop(context);
                          _updateUserRole(user.id, role.id);
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _toggleSelectMode() {
    setState(() {
      _isSelectMode = !_isSelectMode;
      if (!_isSelectMode) {
        _selectedUserIds.clear();
      }
    });
  }

  void _toggleUserSelection(int userId) {
    setState(() {
      if (_selectedUserIds.contains(userId)) {
        _selectedUserIds.remove(userId);
      } else {
        _selectedUserIds.add(userId);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const Expanded(
                    child: Text(
                      'User Role Settings',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                  if (_isSelectMode && _selectedUserIds.isNotEmpty)
                    TextButton(
                      onPressed: _bulkAssignRole,
                      child: const Text(
                        'Assign',
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                  IconButton(
                    icon: Icon(
                      _isSelectMode ? Icons.close : Icons.checklist,
                      color: Colors.white,
                    ),
                    onPressed: _toggleSelectMode,
                    tooltip: _isSelectMode ? 'Cancel Selection' : 'Select Mode',
                  ),
                  IconButton(
                    icon: _isRefreshing
                        ? SizedBox(
                            width: 20,
                            height: 20,
                            child: AppLoadingIndicator(size: 24, color: Colors.white, strokeWidth: 2),
                          )
                        : const Icon(Icons.refresh, color: Colors.white),
                    onPressed: _isRefreshing ? null : () => _loadData(refresh: true),
                  ),
                ],
              ),
            ),

            // Filters Section
            Container(
              padding: const EdgeInsets.all(16),
              color: Colors.white,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Search Field
                  TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Search by name or email...',
                      hintStyle: TextStyle(color: Colors.grey.shade400),
                      prefixIcon: Icon(Icons.search, color: Colors.grey.shade600),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: Icon(Icons.clear, color: Colors.grey.shade600),
                              onPressed: () {
                                _searchController.clear();
                                setState(() {
                                  _searchQuery = '';
                                });
                                _applyFilters();
                              },
                            )
                          : null,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFF6366F1), width: 2),
                      ),
                      filled: true,
                      fillColor: Colors.grey.shade50,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                    onChanged: (value) {
                      setState(() {
                        _searchQuery = value;
                      });
                      // Debounce search
                      _searchDebounce?.cancel();
                      _searchDebounce = Timer(const Duration(milliseconds: 500), () {
                        if (_searchQuery == value) {
                          _applyFilters();
                        }
                      });
                    },
                    onSubmitted: (_) => _applyFilters(),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _buildFilterDropdown(
                          value: _selectedOutletId,
                          items: [
                            const DropdownMenuItem(value: null, child: Text('All Outlets')),
                            ..._outlets.map((outlet) => DropdownMenuItem(
                              value: outlet.id,
                              child: Text(outlet.name),
                            )),
                          ],
                          onChanged: (value) {
                            setState(() {
                              _selectedOutletId = value;
                            });
                            _applyFilters();
                          },
                          label: 'Outlet',
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildFilterDropdown(
                          value: _selectedDivisionId,
                          items: [
                            const DropdownMenuItem(value: null, child: Text('All Divisions')),
                            ..._divisions.map((division) => DropdownMenuItem(
                              value: division.id,
                              child: Text(division.name),
                            )),
                          ],
                          onChanged: (value) {
                            setState(() {
                              _selectedDivisionId = value;
                            });
                            _applyFilters();
                          },
                          label: 'Division',
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildFilterDropdown(
                          value: _selectedRoleId,
                          items: [
                            const DropdownMenuItem(value: null, child: Text('All Roles')),
                            ..._roles.map((role) => DropdownMenuItem(
                              value: role.id,
                              child: Text(role.name),
                            )),
                          ],
                          onChanged: (value) {
                            setState(() {
                              _selectedRoleId = value;
                            });
                            _applyFilters();
                          },
                          label: 'Role',
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: IconButton(
                          icon: Icon(Icons.filter_alt_off, color: Colors.grey.shade700),
                          onPressed: _clearFilters,
                          tooltip: 'Clear Filters',
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Error Banner
            if (_errorMessage != null && !_isLoading)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                color: Colors.red.shade50,
                child: Row(
                  children: [
                    Icon(Icons.error_outline, color: Colors.red.shade700, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: TextStyle(
                          color: Colors.red.shade700,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.close, color: Colors.red.shade700, size: 18),
                      onPressed: () {
                        setState(() {
                          _errorMessage = null;
                        });
                      },
                    ),
                  ],
                ),
              ),

            // Users List
            Expanded(
              child: _isLoading
                  ? _buildLoadingState()
                  : _users.isEmpty
                      ? _buildEmptyState()
                      : RefreshIndicator(
                          onRefresh: () => _loadData(refresh: true),
                          child: ListView.builder(
                            controller: _scrollController,
                            padding: const EdgeInsets.all(16),
                            itemCount: _users.length,
                            itemBuilder: (context, index) {
                              return TweenAnimationBuilder<double>(
                                tween: Tween(begin: 0.0, end: 1.0),
                                duration: Duration(milliseconds: 300 + (index * 50)),
                                curve: Curves.easeOut,
                                builder: (context, value, child) {
                                  return Opacity(
                                    opacity: value,
                                    child: Transform.translate(
                                      offset: Offset(0, 20 * (1 - value)),
                                      child: child,
                                    ),
                                  );
                                },
                                child: _buildUserCard(_users[index]),
                              );
                            },
                          ),
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterDropdown({
    required int? value,
    required List<DropdownMenuItem<int?>> items,
    required ValueChanged<int?> onChanged,
    required String label,
  }) {
    String selectedText = label;
    if (value != null) {
      try {
        final selectedItem = items.firstWhere((item) => item.value == value);
        if (selectedItem.child is Text) {
          selectedText = (selectedItem.child as Text).data ?? label;
        }
      } catch (e) {
        selectedText = label;
      }
    }
    
    return InkWell(
      onTap: () => _showFilterBottomSheet(
        title: label,
        items: items,
        selectedValue: value,
        onSelected: onChanged,
      ),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                selectedText,
                style: TextStyle(
                  color: value == null ? Colors.grey.shade600 : Colors.grey.shade800,
                  fontSize: 14,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Icon(Icons.arrow_drop_down, color: Colors.grey.shade600, size: 20),
          ],
        ),
      ),
    );
  }

  Future<void> _showFilterBottomSheet({
    required String title,
    required List<DropdownMenuItem<int?>> items,
    required int? selectedValue,
    required ValueChanged<int?> onSelected,
  }) async {
    final searchController = TextEditingController();
    List<DropdownMenuItem<int?>> filteredItems = List.from(items);
    
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          String getItemText(DropdownMenuItem<int?> item) {
            if (item.child is Text) {
              return (item.child as Text).data ?? '';
            }
            return item.child.toString();
          }
          
          return Container(
            height: MediaQuery.of(context).size.height * 0.7,
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Column(
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(color: Colors.grey.shade200),
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Select $title',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                ),
                // Search
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: TextField(
                    controller: searchController,
                    decoration: InputDecoration(
                      hintText: 'Search...',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: searchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                searchController.clear();
                                setModalState(() {
                                  filteredItems = List.from(items);
                                });
                              },
                            )
                          : null,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      filled: true,
                      fillColor: Colors.grey.shade50,
                    ),
                    onChanged: (value) {
                      setModalState(() {
                        if (value.isEmpty) {
                          filteredItems = List.from(items);
                        } else {
                          filteredItems = items.where((item) {
                            final text = getItemText(item).toLowerCase();
                            return text.contains(value.toLowerCase());
                          }).toList();
                        }
                      });
                    },
                  ),
                ),
                // List
                Expanded(
                  child: ListView.builder(
                    itemCount: filteredItems.length,
                    itemBuilder: (context, index) {
                      final item = filteredItems[index];
                      final isSelected = item.value == selectedValue;
                      
                      return ListTile(
                        title: Text(
                          getItemText(item),
                          style: TextStyle(
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            color: isSelected ? const Color(0xFF6366F1) : Colors.black,
                          ),
                        ),
                        trailing: isSelected
                            ? const Icon(Icons.check, color: Color(0xFF6366F1))
                            : null,
                        onTap: () {
                          onSelected(item.value);
                          Navigator.pop(context);
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildLoadingState() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: 5,
      itemBuilder: (context, index) {
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 120,
                    height: 16,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const Spacer(),
                  Container(
                    width: 60,
                    height: 20,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                height: 12,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.people_outline,
              size: 64,
              color: Colors.grey.shade400,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'No users found',
            style: TextStyle(
              color: Colors.grey.shade600,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Try adjusting your filters',
            style: TextStyle(
              color: Colors.grey.shade500,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserCard(UserRole user) {
    final isSelected = _selectedUserIds.contains(user.id);
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: _isSelectMode && isSelected
            ? Border.all(color: const Color(0xFF6366F1), width: 2)
            : null,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _isSelectMode
              ? () => _toggleUserSelection(user.id)
              : null,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                if (_isSelectMode)
                  Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: Icon(
                      isSelected ? Icons.check_circle : Icons.circle_outlined,
                      color: isSelected ? const Color(0xFF6366F1) : Colors.grey.shade400,
                      size: 24,
                    ),
                  ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user.namaLengkap,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1F2937),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 12,
                        runSpacing: 4,
                        children: [
                          if (user.namaOutlet != null)
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.store, size: 14, color: Colors.grey.shade600),
                                const SizedBox(width: 4),
                                Flexible(
                                  child: Text(
                                    user.namaOutlet!,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey.shade600,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          if (user.namaDivisi != null)
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.business, size: 14, color: Colors.grey.shade600),
                                const SizedBox(width: 4),
                                Flexible(
                                  child: Text(
                                    user.namaDivisi!,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey.shade600,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          if (user.namaJabatan != null)
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.person, size: 14, color: Colors.grey.shade600),
                                const SizedBox(width: 4),
                                Flexible(
                                  child: Text(
                                    user.namaJabatan!,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey.shade600,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                        ],
                      ),
                      if (user.roleName != null) ...[
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFF6366F1).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFF6366F1), width: 1),
                          ),
                          child: Text(
                            user.roleName!,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF6366F1),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (!_isSelectMode)
                  InkWell(
                    onTap: () => _showRoleSelectionBottomSheet(user),
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            user.roleName ?? 'No Role',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: user.roleId != null
                                  ? const Color(0xFF6366F1)
                                  : Colors.grey.shade600,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Icon(Icons.arrow_drop_down, color: Colors.grey.shade600, size: 18),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

