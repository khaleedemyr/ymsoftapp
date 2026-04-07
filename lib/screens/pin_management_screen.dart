import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/auth_service.dart';
import '../widgets/app_scaffold.dart';
import '../widgets/app_loading_indicator.dart';

class PinManagementScreen extends StatefulWidget {
  const PinManagementScreen({super.key});

  @override
  State<PinManagementScreen> createState() => _PinManagementScreenState();
}

class _PinManagementScreenState extends State<PinManagementScreen> {
  final AuthService _authService = AuthService();
  List<Map<String, dynamic>> _userPins = [];
  List<Map<String, dynamic>> _outlets = [];
  bool _isLoading = true;
  bool _isLoadingPins = false;
  bool _isSaving = false;

  final _formKey = GlobalKey<FormState>();
  final _pinController = TextEditingController();
  String? _selectedOutletId;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _pinController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      await Future.wait([
        _loadOutlets(),
        _loadUserPins(),
      ]);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading data: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _loadOutlets() async {
    try {
      print('Loading outlets...');
      final outlets = await _authService.getOutlets();
      print('Loaded outlets: ${outlets.length}');
      print('Outlets data: $outlets');
      
      if (mounted) {
        setState(() {
          _outlets = outlets;
        });
        
        if (outlets.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Tidak ada outlet tersedia. Pastikan Anda memiliki akses ke outlet.'),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 3),
            ),
          );
        }
      }
    } catch (e) {
      print('Error loading outlets: $e');
      if (mounted) {
        setState(() {
          _outlets = [];
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading outlets: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  Future<void> _loadUserPins() async {
    setState(() {
      _isLoadingPins = true;
    });

    try {
      print('Loading user pins...');
      final pins = await _authService.getUserPins();
      print('Loaded user pins: ${pins.length}');
      print('User pins data: $pins');
      
      if (mounted) {
        setState(() {
          _userPins = pins;
          _isLoadingPins = false;
        });
        
        if (pins.isEmpty) {
          print('No user pins found');
          // Show info message if no pins (might be because endpoint doesn't exist)
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Belum ada PIN yang dibuat. Silakan tambah PIN baru.'),
                backgroundColor: Colors.blue,
                duration: Duration(seconds: 2),
              ),
            );
          }
        }
      }
    } catch (e) {
      print('Error in _loadUserPins: $e');
      if (mounted) {
        setState(() {
          _isLoadingPins = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading PINs: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  Future<void> _addPin() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      if (_selectedOutletId == null || _selectedOutletId!.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Pilih outlet terlebih dahulu'),
            backgroundColor: Colors.orange,
          ),
        );
        setState(() {
          _isSaving = false;
        });
        return;
      }

      final result = await _authService.addUserPin(
        outletId: int.parse(_selectedOutletId!),
        pin: _pinController.text,
      );

      if (mounted) {
        if (result['success'] == true) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('PIN berhasil ditambahkan'),
              backgroundColor: Colors.green,
            ),
          );
          setState(() {
            _selectedOutletId = null;
          });
          _pinController.clear();
          await _loadUserPins();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result['message'] ?? 'Gagal menambahkan PIN'),
              backgroundColor: Colors.red,
            ),
          );
        }
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

  Future<void> _deletePin(int pinId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: const Row(
          children: [
            Icon(Icons.delete, color: Colors.red, size: 24),
            SizedBox(width: 8),
            Text(
              'Hapus PIN',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        content: const Text(
          'Apakah Anda yakin ingin menghapus PIN ini?',
          style: TextStyle(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final result = await _authService.deleteUserPin(pinId);

      if (mounted) {
        if (result['success'] == true) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('PIN berhasil dihapus'),
              backgroundColor: Colors.green,
            ),
          );
          await _loadUserPins();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result['message'] ?? 'Gagal menghapus PIN'),
              backgroundColor: Colors.red,
            ),
          );
        }
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

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Kelola PIN Outlet',
      body: _isLoading
          ? const Center(
              child: AppLoadingIndicator(),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Add PIN Form
                  Container(
                    padding: const EdgeInsets.all(20),
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
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.add_circle,
                                color: const Color(0xFF6366F1),
                                size: 24,
                              ),
                              const SizedBox(width: 8),
                              const Text(
                                'Tambah PIN Baru',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF1A1A1A),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          _outlets.isEmpty
                              ? Column(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(16),
                                      decoration: BoxDecoration(
                                        color: Colors.orange.shade50,
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(color: Colors.orange.shade200),
                                      ),
                                      child: Row(
                                        children: [
                                          Icon(Icons.warning, color: Colors.orange.shade700),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              'Tidak ada outlet tersedia.',
                                              style: TextStyle(color: Colors.orange.shade700),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    ElevatedButton.icon(
                                      onPressed: () => _loadOutlets(),
                                      icon: const Icon(Icons.refresh),
                                      label: const Text('Refresh'),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(0xFF6366F1),
                                        foregroundColor: Colors.white,
                                      ),
                                    ),
                                  ],
                                )
                              : LayoutBuilder(
                                  builder: (context, constraints) {
                                    return DropdownButtonFormField<String>(
                                      value: _selectedOutletId,
                                      isExpanded: true,
                                      decoration: InputDecoration(
                                        labelText: 'Pilih Outlet *',
                                        prefixIcon: const Icon(
                                          Icons.store,
                                          color: Color(0xFF6366F1),
                                        ),
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        filled: true,
                                        fillColor: Colors.white,
                                        contentPadding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 16,
                                        ),
                                      ),
                                      items: [
                                        const DropdownMenuItem<String>(
                                          value: null,
                                          child: Text(
                                            'Pilih Outlet',
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        ..._outlets.map((outlet) {
                                          final id = outlet['id_outlet']?.toString() ?? 
                                                     outlet['id']?.toString() ?? 
                                                     '';
                                          final name = outlet['nama_outlet'] ?? 
                                                       outlet['name'] ?? 
                                                       outlet['outlet_name'] ?? 
                                                       'Unknown';
                                          if (id.isEmpty) {
                                            print('Warning: Outlet with empty ID: $outlet');
                                            return null;
                                          }
                                          return DropdownMenuItem<String>(
                                            value: id,
                                            child: Text(
                                              name,
                                              overflow: TextOverflow.ellipsis,
                                              maxLines: 1,
                                            ),
                                          );
                                        }).whereType<DropdownMenuItem<String>>().toList(),
                                      ],
                                      onChanged: (value) {
                                        setState(() {
                                          _selectedOutletId = value;
                                        });
                                      },
                                      validator: (value) {
                                        if (value == null || value.isEmpty) {
                                          return 'Outlet harus dipilih';
                                        }
                                        return null;
                                      },
                                    );
                                  },
                                ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _pinController,
                            decoration: InputDecoration(
                              labelText: 'PIN *',
                              prefixIcon: const Icon(
                                Icons.lock,
                                color: Color(0xFF6366F1),
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              filled: true,
                              fillColor: Colors.white,
                            ),
                            maxLength: 10,
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(RegExp(r'[0-9]')),
                            ],
                            keyboardType: TextInputType.number,
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'PIN harus diisi';
                              }
                              if (value.length < 1) {
                                return 'PIN minimal 1 karakter';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 20),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: _isSaving ? null : _addPin,
                              icon: _isSaving
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: AppLoadingIndicator(size: 24, color: Colors.white, strokeWidth: 2),
                                    )
                                  : const Icon(Icons.add),
                              label: const Text('Tambah PIN'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF6366F1),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Existing PINs List
                  Container(
                    padding: const EdgeInsets.all(20),
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
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.list,
                              color: const Color(0xFF6366F1),
                              size: 24,
                            ),
                            const SizedBox(width: 8),
                            const Text(
                              'PIN yang Sudah Ada',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF1A1A1A),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        if (_isLoadingPins)
                          const Center(
                            child: Padding(
                              padding: EdgeInsets.all(32.0),
                              child: AppLoadingIndicator(),
                            ),
                          )
                        else if (_userPins.isEmpty)
                          Center(
                            child: Padding(
                              padding: const EdgeInsets.all(32.0),
                              child: Column(
                                children: [
                                  Icon(
                                    Icons.key,
                                    size: 64,
                                    color: Colors.grey.shade300,
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    'Belum ada PIN yang dibuat',
                                    style: TextStyle(
                                      color: Colors.grey.shade600,
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )
                        else
                          ListView.separated(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: _userPins.length,
                            separatorBuilder: (context, index) => const Divider(),
                            itemBuilder: (context, index) {
                              final pin = _userPins[index];
                              return ListTile(
                                leading: Container(
                                  width: 40,
                                  height: 40,
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
                                  pin['outlet']?['nama_outlet'] ?? 
                                  pin['outlet']?['name'] ?? 
                                  pin['outlet_name'] ?? 
                                  pin['nama_outlet'] ?? 
                                  pin['outlet']?['outlet_name'] ??
                                  'Unknown Outlet',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'PIN: ${pin['pin'] ?? 'N/A'}',
                                      style: TextStyle(
                                        color: Colors.grey.shade600,
                                        fontFamily: 'monospace',
                                        fontSize: 14,
                                      ),
                                    ),
                                    if (pin['is_active'] != null)
                                      Container(
                                        margin: const EdgeInsets.only(top: 4),
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: pin['is_active'] == true
                                              ? Colors.green.shade100
                                              : Colors.grey.shade200,
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: Text(
                                          pin['is_active'] == true ? 'Aktif' : 'Tidak Aktif',
                                          style: TextStyle(
                                            color: pin['is_active'] == true
                                                ? Colors.green.shade800
                                                : Colors.grey.shade600,
                                            fontSize: 10,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                                trailing: IconButton(
                                  icon: const Icon(
                                    Icons.delete,
                                    color: Colors.red,
                                  ),
                                  onPressed: () => _deletePin(pin['id']),
                                ),
                              );
                            },
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
