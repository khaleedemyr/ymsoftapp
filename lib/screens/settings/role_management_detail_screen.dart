import 'dart:async';
import 'package:flutter/material.dart';
import '../../services/role_management_service.dart';
import '../../models/role_management_models.dart';
import '../../widgets/app_loading_indicator.dart';

class RoleManagementDetailScreen extends StatefulWidget {
  final Role? role; // null for create, not null for edit

  const RoleManagementDetailScreen({super.key, this.role});

  @override
  State<RoleManagementDetailScreen> createState() => _RoleManagementDetailScreenState();
}

class _RoleManagementDetailScreenState extends State<RoleManagementDetailScreen>
    with SingleTickerProviderStateMixin {
  final RoleManagementService _service = RoleManagementService();
  List<Menu> _menus = [];
  bool _isLoading = true;
  String? _errorMessage;
  
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  List<String> _selectedPermissions = [];
  bool _isSaving = false;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    if (widget.role != null) {
      _nameController.text = widget.role!.name;
      _descriptionController.text = widget.role!.description ?? '';
      _selectedPermissions = widget.role!.permissions
          .map((p) => '${p.menuId}-${p.action}')
          .toList();
    }
    _loadMenus();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  List<Menu> get _parentMenus => _menus.where((m) => m.parentId == null).toList();
  List<Menu> _childMenus(int parentId) => _menus.where((m) => m.parentId == parentId).toList();

  Future<void> _loadMenus() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final result = await _service.getRolesAndMenus();
      if (result['success'] == true && mounted) {
        final menusData = result['menus'] as List<dynamic>? ?? [];

        setState(() {
          _menus = menusData.map((json) => Menu.fromJson(json)).toList();
          _errorMessage = null;
        });

        // Initialize TabController after menus are loaded
        if (mounted) {
          setState(() {
            _tabController = TabController(
              length: _parentMenus.length + 1,
              vsync: this,
            );
          });
        }
      } else if (mounted) {
        setState(() {
          _errorMessage = result['message'] ?? 'Failed to load menus';
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
        });
      }
    }
  }

  Future<void> _saveRole() async {
    if (_nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nama role harus diisi')),
      );
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      Map<String, dynamic> result;
      if (widget.role != null) {
        result = await _service.updateRole(
          roleId: widget.role!.id,
          name: _nameController.text.trim(),
          description: _descriptionController.text.trim().isEmpty
              ? null
              : _descriptionController.text.trim(),
          permissions: _selectedPermissions,
        );
      } else {
        result = await _service.createRole(
          name: _nameController.text.trim(),
          description: _descriptionController.text.trim().isEmpty
              ? null
              : _descriptionController.text.trim(),
          permissions: _selectedPermissions,
        );
      }

      if (result['success'] == true && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message'] ?? 'Role berhasil disimpan'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true); // Return true to indicate success
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message'] ?? 'Gagal menyimpan role'),
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
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  List<String> _parentPermissionKeys(int parentId) {
    return _childMenus(parentId)
        .expand((child) => ['view', 'create', 'update', 'delete']
            .map((action) => '${child.id}-$action'))
        .toList();
  }

  bool _isAllParentSelected(int parentId) {
    final keys = _parentPermissionKeys(parentId);
    return keys.isNotEmpty && keys.every((k) => _selectedPermissions.contains(k));
  }

  void _toggleAllParent(int parentId) {
    final keys = _parentPermissionKeys(parentId);
    if (_isAllParentSelected(parentId)) {
      setState(() {
        _selectedPermissions.removeWhere((p) => keys.contains(p));
      });
    } else {
      setState(() {
        _selectedPermissions = [
          ..._selectedPermissions,
          ...keys.where((k) => !_selectedPermissions.contains(k))
        ];
      });
    }
  }

  List<String> _menuPermissionKeys(int menuId) {
    return ['view', 'create', 'update', 'delete']
        .map((action) => '$menuId-$action')
        .toList();
  }

  bool _isAllMenuSelected(int menuId) {
    final keys = _menuPermissionKeys(menuId);
    return keys.every((k) => _selectedPermissions.contains(k));
  }

  void _toggleAllMenu(int menuId) {
    final keys = _menuPermissionKeys(menuId);
    if (_isAllMenuSelected(menuId)) {
      setState(() {
        _selectedPermissions.removeWhere((p) => keys.contains(p));
      });
    } else {
      setState(() {
        _selectedPermissions = [
          ..._selectedPermissions,
          ...keys.where((k) => !_selectedPermissions.contains(k))
        ];
      });
    }
  }

  Widget _buildPermissionTab(int parentIndex) {
    final parent = _parentMenus[parentIndex];
    final children = _childMenus(parent.id);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Select All Parent
          CheckboxListTile(
            title: const Text(
              'Select All',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            value: _isAllParentSelected(parent.id),
            onChanged: (value) => _toggleAllParent(parent.id),
            contentPadding: EdgeInsets.zero,
          ),
          const SizedBox(height: 8),
          // Child Menus
          ...children.map((child) => Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              child.name,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ),
                          Checkbox(
                            value: _isAllMenuSelected(child.id),
                            onChanged: (value) => _toggleAllMenu(child.id),
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            'Select All',
                            style: TextStyle(fontSize: 12),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 16,
                        runSpacing: 12,
                        children: ['view', 'create', 'update', 'delete']
                            .map((action) => SizedBox(
                                  width: 120,
                                  child: CheckboxListTile(
                                    title: Text(
                                      action.toUpperCase(),
                                      style: const TextStyle(fontSize: 14),
                                    ),
                                    value: _selectedPermissions
                                        .contains('${child.id}-$action'),
                                    onChanged: (value) {
                                      setState(() {
                                        final key = '${child.id}-$action';
                                        if (value == true) {
                                          if (!_selectedPermissions.contains(key)) {
                                            _selectedPermissions.add(key);
                                          }
                                        } else {
                                          _selectedPermissions.remove(key);
                                        }
                                      });
                                    },
                                    contentPadding: EdgeInsets.zero,
                                    dense: true,
                                  ),
                                ))
                            .toList(),
                      ),
                    ],
                  ),
                ),
              )),
        ],
      ),
    );
  }

  Widget _buildPreviewTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Preview Role',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          _buildPreviewItem('Name', _nameController.text),
          const SizedBox(height: 12),
          _buildPreviewItem('Description',
              _descriptionController.text.isEmpty ? '-' : _descriptionController.text),
          const SizedBox(height: 12),
          const Text(
            'Permissions:',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          if (_selectedPermissions.isEmpty)
            const Text(
              'No permissions selected.',
              style: TextStyle(fontStyle: FontStyle.italic, color: Colors.grey),
            )
          else
            ..._menus.map((menu) {
              final hasPermission = ['view', 'create', 'update', 'delete']
                  .any((action) => _selectedPermissions.contains('${menu.id}-$action'));
              if (!hasPermission) return const SizedBox.shrink();
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      menu.name,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: ['view', 'create', 'update', 'delete']
                          .where((action) =>
                              _selectedPermissions.contains('${menu.id}-$action'))
                          .map((action) => Chip(
                                label: Text(
                                  action.toUpperCase(),
                                  style: const TextStyle(fontSize: 11),
                                ),
                                backgroundColor: Colors.blue.shade100,
                                labelStyle: TextStyle(color: Colors.blue.shade800),
                              ))
                          .toList(),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _buildPreviewItem(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        Text(value),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.role != null ? 'Edit Role' : 'Create Role'),
        backgroundColor: Colors.blue.shade700,
        foregroundColor: Colors.white,
        actions: [
          if (!_isLoading && _parentMenus.isNotEmpty)
            IconButton(
              icon: _isSaving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: AppLoadingIndicator(size: 24, color: Colors.white, strokeWidth: 2),
                    )
                  : const Icon(Icons.save),
              onPressed: _isSaving ? null : _saveRole,
            ),
        ],
      ),
      body: _isLoading
          ? Center(child: AppLoadingIndicator())
          : _errorMessage != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.error, size: 64, color: Colors.red.shade300),
                      const SizedBox(height: 16),
                      Text(
                        _errorMessage!,
                        style: TextStyle(color: Colors.red.shade700),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loadMenus,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : _parentMenus.isEmpty
                  ? const Center(
                      child: Text('No menus available'),
                    )
                  : Column(
                      children: [
                        // Form Fields
                        Container(
                          padding: const EdgeInsets.all(16),
                          color: Colors.white,
                          child: Column(
                            children: [
                              TextField(
                                controller: _nameController,
                                decoration: const InputDecoration(
                                  labelText: 'Name',
                                  border: OutlineInputBorder(),
                                  prefixIcon: Icon(Icons.person),
                                ),
                              ),
                              const SizedBox(height: 16),
                              TextField(
                                controller: _descriptionController,
                                decoration: const InputDecoration(
                                  labelText: 'Description',
                                  border: OutlineInputBorder(),
                                  prefixIcon: Icon(Icons.description),
                                ),
                                maxLines: 3,
                              ),
                            ],
                          ),
                        ),
                        // TabBar
                        Container(
                          color: Colors.grey.shade100,
                          child: TabBar(
                            controller: _tabController,
                            isScrollable: true,
                            labelColor: Colors.blue.shade700,
                            unselectedLabelColor: Colors.grey,
                            indicatorColor: Colors.blue.shade700,
                            tabs: [
                              ..._parentMenus.asMap().entries.map((entry) => Tab(
                                    text: entry.value.name.length > 15
                                        ? '${entry.value.name.substring(0, 15)}...'
                                        : entry.value.name,
                                  )),
                              const Tab(text: 'Preview'),
                            ],
                          ),
                        ),
                        // TabBarView
                        Expanded(
                          child: TabBarView(
                            controller: _tabController,
                            children: [
                              ..._parentMenus.asMap().entries
                                  .map((entry) => _buildPermissionTab(entry.key)),
                              _buildPreviewTab(),
                            ],
                          ),
                        ),
                      ],
                    ),
    );
  }
}

