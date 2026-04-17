import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:async';
import 'dart:io';
import '../services/attendance_service.dart';
import '../services/auth_service.dart';
import 'app_loading_indicator.dart';

class LeaveRequestModal extends StatefulWidget {
  final List<Map<String, dynamic>> leaveTypes;
  final VoidCallback onSubmitted;
  final int? leaveBalance; // Saldo cuti dari user
  final int? extraOffBalance; // Saldo extra off
  final int? phBalance; // Saldo PH

  const LeaveRequestModal({
    super.key,
    required this.leaveTypes,
    required this.onSubmitted,
    this.leaveBalance,
    this.extraOffBalance,
    this.phBalance,
  });

  @override
  State<LeaveRequestModal> createState() => _LeaveRequestModalState();
}

class _LeaveRequestModalState extends State<LeaveRequestModal> {
  final _formKey = GlobalKey<FormState>();
  final AttendanceService _attendanceService = AttendanceService();
  final AuthService _authService = AuthService();
  
  int? _selectedLeaveTypeId;
  DateTime? _dateFrom;
  DateTime? _dateTo;
  final TextEditingController _reasonController = TextEditingController();
  List<int> _selectedApprovers = [];
  List<Map<String, dynamic>> _availableApprovers = [];
  bool _isLoadingApprovers = false;
  bool _isSubmitting = false;
  final TextEditingController _approverSearchController = TextEditingController();
  Timer? _approverSearchDebounce;
  int? _userLeaveBalance; // Saldo cuti user
  int? _extraOffBalance; // Saldo extra off user
  int? _phBalance; // Saldo PH user
  List<File> _selectedDocuments = []; // Files untuk upload
  final ImagePicker _imagePicker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _userLeaveBalance = widget.leaveBalance;
    _extraOffBalance = widget.extraOffBalance;
    _phBalance = widget.phBalance;
    _loadApprovers();
    _loadUserLeaveBalance();
  }

  Future<void> _loadUserLeaveBalance() async {
    try {
      final userData = await _authService.getUserData();
      if (userData != null && userData['cuti'] != null) {
        setState(() {
          _userLeaveBalance = userData['cuti'] as int?;
        });
      }
    } catch (e) {
      print('Error loading user leave balance: $e');
    }
  }

  // Check if selected leave type is Annual Leave
  bool get _isAnnualLeave {
    if (_selectedLeaveTypeId == null) return false;
    final selectedType = widget.leaveTypes.firstWhere(
      (type) => type['id'] == _selectedLeaveTypeId,
      orElse: () => {},
    );
    final typeName = selectedType['name']?.toString().toLowerCase() ?? '';
    return typeName.contains('annual leave') || typeName.contains('cuti tahunan');
  }

  bool get _isExtraOff {
    if (_selectedLeaveTypeId == null) return false;
    final selectedType = widget.leaveTypes.firstWhere(
      (type) => type['id'] == _selectedLeaveTypeId,
      orElse: () => {},
    );
    final typeName = selectedType['name']?.toString().toLowerCase() ?? '';
    final typeDescription = selectedType['description']?.toString().toLowerCase() ?? '';
    final combined = '$typeName $typeDescription';
    return combined.contains('extra off');
  }

  bool get _isPHLeave {
    if (_selectedLeaveTypeId == null) return false;
    final selectedType = widget.leaveTypes.firstWhere(
      (type) => type['id'] == _selectedLeaveTypeId,
      orElse: () => {},
    );
    final typeName = selectedType['name']?.toString().toLowerCase() ?? '';
    final typeDescription = selectedType['description']?.toString().toLowerCase() ?? '';
    final combined = '$typeName $typeDescription';

    // Match explicit PH type names and common variants.
    if (RegExp(r'(^|\W)ph($|\W)', caseSensitive: false).hasMatch(combined)) {
      return true;
    }
    return combined.contains('public holiday') || combined.contains('hari libur');
  }

  bool get _isRestrictedByBalanceType => _isAnnualLeave || _isExtraOff || _isPHLeave;

  int _currentSelectedBalance() {
    if (_isAnnualLeave) return _userLeaveBalance ?? 0;
    if (_isExtraOff) return _extraOffBalance ?? 0;
    if (_isPHLeave) return _phBalance ?? 0;
    return 0;
  }

  DateTime _effectiveMaxDateFromBalance(DateTime fromDate) {
    // Default upper bound: 1 year ahead.
    DateTime maxDate = DateTime.now().add(const Duration(days: 365));

    // For leave types that consume balance, cap selectable range by balance.
    if (_isRestrictedByBalanceType) {
      final balance = _currentSelectedBalance();
      if (balance > 0) {
        final maxByBalance = fromDate.add(Duration(days: balance - 1));
        if (maxByBalance.isBefore(maxDate)) {
          maxDate = maxByBalance;
        }
      }
    }

    return maxDate;
  }

  String _currentSelectedTypeLabel() {
    if (_isAnnualLeave) return 'Cuti Tahunan';
    if (_isExtraOff) return 'Extra Off';
    if (_isPHLeave) return 'PH';
    return 'izin/cuti ini';
  }

  bool _canPickDateForSelectedType() {
    if (!_isRestrictedByBalanceType) return true;
    final balance = _currentSelectedBalance();
    if (balance > 0) return true;

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Saldo ${_currentSelectedTypeLabel()} Anda 0, tidak bisa mengajukan'),
          backgroundColor: Colors.red,
        ),
      );
    }
    return false;
  }

  // Check if selected leave type requires document
  bool get _requiresDocument {
    if (_selectedLeaveTypeId == null) return false;
    final selectedType = widget.leaveTypes.firstWhere(
      (type) => type['id'] == _selectedLeaveTypeId,
      orElse: () => {},
    );
    return selectedType['requires_document'] == true || selectedType['requires_document'] == 1;
  }

  // Get selected leave type
  Map<String, dynamic>? get _selectedLeaveType {
    if (_selectedLeaveTypeId == null) return null;
    try {
      return widget.leaveTypes.firstWhere(
        (type) => type['id'] == _selectedLeaveTypeId,
      );
    } catch (e) {
      return null;
    }
  }

  // Check if selected leave type has max_days (fixed duration)
  bool get _hasMaxDays {
    final type = _selectedLeaveType;
    if (type == null) return false;
    final maxDays = type['max_days'];
    return maxDays != null && maxDays is int && maxDays > 0;
  }

  // Get max days for selected leave type
  int? get _maxDays {
    final type = _selectedLeaveType;
    if (type == null) return null;
    final maxDays = type['max_days'];
    return maxDays is int ? maxDays : null;
  }

  // Calculate end date based on start date and max_days
  DateTime? _calculateEndDate(DateTime startDate, int maxDays) {
    return startDate.add(Duration(days: maxDays - 1));
  }

  // Calculate number of days between dateFrom and dateTo
  int _calculateDays() {
    if (_dateFrom == null || _dateTo == null) return 0;
    return _dateTo!.difference(_dateFrom!).inDays + 1; // +1 to include both start and end date
  }

  // Check if selected days exceed leave balance
  bool get _isExceedingBalance {
    if (!_isAnnualLeave || _userLeaveBalance == null) return false;
    final days = _calculateDays();
    return days > _userLeaveBalance!;
  }

  int? _coerceUserId(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v.toString());
  }

  @override
  void dispose() {
    _approverSearchDebounce?.cancel();
    _approverSearchController.dispose();
    _reasonController.dispose();
    super.dispose();
  }

  Future<void> _loadApprovers() async {
    setState(() {
      _isLoadingApprovers = true;
    });

    try {
      final q = _approverSearchController.text.trim();
      final approvers = await _attendanceService.getApprovers(
        search: q.isEmpty ? null : q,
      );
      setState(() {
        _availableApprovers = approvers;
        _isLoadingApprovers = false;
      });
    } catch (e) {
      setState(() {
        _isLoadingApprovers = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal memuat daftar approver: $e')),
        );
      }
    }
  }

  Future<void> _submitRequest() async {
    print('🟡 _submitRequest called');
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_selectedLeaveTypeId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pilih jenis izin/cuti terlebih dahulu')),
      );
      return;
    }

    if (_dateFrom == null || _dateTo == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pilih tanggal terlebih dahulu')),
      );
      return;
    }

    if (_selectedApprovers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pilih minimal satu approver')),
      );
      return;
    }

    // Validate document requirement
    if (_requiresDocument && _selectedDocuments.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Dokumen pendukung wajib diupload untuk jenis izin/cuti ini'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Validate annual leave balance
    if (_isAnnualLeave) {
      if (_userLeaveBalance == null || _userLeaveBalance == 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Anda tidak memiliki saldo cuti tahunan yang tersedia'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      final days = _calculateDays();
      if (days > _userLeaveBalance!) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Jumlah hari cuti ($days hari) melebihi saldo cuti yang tersedia ($_userLeaveBalance hari)'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
    }

    // Validate extra off balance
    if (_isExtraOff) {
      if (_extraOffBalance == null || _extraOffBalance == 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Saldo Extra Off Anda 0, tidak bisa mengajukan'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
    }

    // Validate PH balance
    if (_isPHLeave) {
      if (_phBalance == null || _phBalance == 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Saldo PH Anda 0, tidak bisa mengajukan'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
    }

    setState(() {
      _isSubmitting = true;
    });

    print('🟢 Submitting leave request...');
    print('🟢 Leave Type ID: $_selectedLeaveTypeId');
    print('🟢 Date From: ${DateFormat('yyyy-MM-dd').format(_dateFrom!)}');
    print('🟢 Date To: ${DateFormat('yyyy-MM-dd').format(_dateTo!)}');
    print('🟢 Approvers: $_selectedApprovers');
    print('🟢 Documents count: ${_selectedDocuments.length}');

    try {
      final result = await _attendanceService.submitAbsentRequest(
        leaveTypeId: _selectedLeaveTypeId!,
        dateFrom: DateFormat('yyyy-MM-dd').format(_dateFrom!),
        dateTo: DateFormat('yyyy-MM-dd').format(_dateTo!),
        reason: _reasonController.text,
        approvers: _selectedApprovers,
        documents: _selectedDocuments.isNotEmpty ? _selectedDocuments : null,
      );

      print('🟢 API Response: $result');

      if (mounted) {
        if (result['success'] == true) {
          print('✅ Request submitted successfully');
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Permohonan izin/cuti berhasil dikirim'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 2),
            ),
          );
          // Wait a bit before closing to show success message
          await Future.delayed(const Duration(milliseconds: 500));
          widget.onSubmitted();
          if (mounted) {
            Navigator.pop(context);
          }
        } else {
          print('❌ Request failed: ${result['message']}');
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result['message'] ?? 'Gagal mengirim permohonan'),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 3),
            ),
          );
        }
      }
    } catch (e, stackTrace) {
      print('❌ Exception submitting request: $e');
      print('❌ Stack trace: $stackTrace');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  Future<void> _selectDateFrom() async {
    if (!_canPickDateForSelectedType()) return;
    final maxDate = _effectiveMaxDateFromBalance(DateTime.now());
    
    final picked = await showDatePicker(
      context: context,
      initialDate: _dateFrom ?? DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: maxDate,
    );
    if (picked != null) {
      setState(() {
        _dateFrom = picked;
        // If max_days is set, auto-calculate date_to
        if (_hasMaxDays && _maxDays != null) {
          _dateTo = _calculateEndDate(_dateFrom!, _maxDays!);
        } else {
          // Reset dateTo if it's before dateFrom
          if (_dateTo != null && _dateTo!.isBefore(_dateFrom!)) {
            _dateTo = null;
          }
          // If type is balance-based and dateTo is set, ensure it doesn't exceed balance.
          if (_isRestrictedByBalanceType && _dateTo != null) {
            final balance = _currentSelectedBalance();
            final days = _dateTo!.difference(_dateFrom!).inDays + 1;
            if (balance > 0 && days > balance) {
              _dateTo = _dateFrom!.add(Duration(days: balance - 1));
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Tanggal selesai disesuaikan sesuai saldo ${_currentSelectedTypeLabel()} ($balance hari)'),
                    backgroundColor: Colors.orange,
                    duration: const Duration(seconds: 2),
                  ),
                );
              }
            }
          }
        }
      });
    }
  }

  Future<void> _pickDocuments() async {
    try {
      // Only allow camera capture, not from gallery
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.camera,
        imageQuality: 85,
      );
      
      if (image != null) {
        setState(() {
          _selectedDocuments.add(File(image.path));
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error mengambil foto: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _selectDateTo() async {
    if (!_canPickDateForSelectedType()) return;
    final baseDate = _dateFrom ?? DateTime.now();
    final maxDate = _effectiveMaxDateFromBalance(baseDate);
    
    final picked = await showDatePicker(
      context: context,
      initialDate: _dateTo ?? _dateFrom ?? DateTime.now(),
      firstDate: _dateFrom ?? DateTime.now(),
      lastDate: maxDate,
    );
    if (picked != null) {
      setState(() {
        _dateTo = picked;
      });
      
      // Show warning if exceeding annual leave balance
      if (_isAnnualLeave && _isExceedingBalance) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Jumlah hari cuti melebihi saldo cuti yang tersedia ($_userLeaveBalance hari)'),
              backgroundColor: Colors.orange,
              duration: const Duration(seconds: 3),
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.9,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(25)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 20,
                offset: const Offset(0, -5),
              ),
            ],
          ),
          child: Column(
            children: [
              // Handle bar
              Container(
                margin: const EdgeInsets.only(top: 12, bottom: 8),
                width: 50,
                height: 5,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              // Header with gradient
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.purple.shade400, Colors.pink.shade400],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(25)),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.calendar_today, color: Colors.white, size: 24),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'Ajukan Izin/Cuti',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () => Navigator.pop(context),
                        borderRadius: BorderRadius.circular(20),
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.close, color: Colors.white, size: 20),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // Form
              Expanded(
                child: Form(
                  key: _formKey,
                  child: ListView(
                    controller: scrollController,
                    padding: const EdgeInsets.all(20),
                    children: [
                      // Leave Type
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: DropdownButtonFormField<int>(
                          value: _selectedLeaveTypeId,
                          decoration: InputDecoration(
                            labelText: 'Jenis Izin/Cuti *',
                            labelStyle: TextStyle(
                              color: Colors.grey[700],
                              fontWeight: FontWeight.w500,
                            ),
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                            prefixIcon: Icon(Icons.event_note, color: Colors.purple.shade400),
                          ),
                          dropdownColor: Colors.white,
                          style: const TextStyle(
                            fontSize: 15,
                            color: Colors.black87,
                          ),
                          items: widget.leaveTypes.map((type) {
                            final requiresDoc = type['requires_document'] == true || type['requires_document'] == 1;
                            final maxDays = type['max_days'];
                            final hasMaxDays = maxDays != null && maxDays is int && maxDays > 0;
                            return DropdownMenuItem<int>(
                              value: type['id'],
                              child: Text.rich(
                                TextSpan(
                                  children: [
                                    TextSpan(
                                      text: type['name'] ?? '',
                                      style: const TextStyle(fontSize: 15),
                                    ),
                                    if (hasMaxDays)
                                      TextSpan(
                                        text: ' (${maxDays} hari)',
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: Colors.blue.shade700,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    if (requiresDoc)
                                      TextSpan(
                                        text: ' 📎',
                                        style: TextStyle(
                                          fontSize: 15,
                                          color: Colors.orange.shade700,
                                        ),
                                      ),
                                  ],
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            );
                          }).toList(),
                          onChanged: (value) {
                            setState(() {
                              _selectedLeaveTypeId = value;
                              // Reset documents when leave type changes
                              _selectedDocuments = [];
                              // Auto-set date_to if max_days is set
                              if (_hasMaxDays && _dateFrom != null && _maxDays != null) {
                                _dateTo = _calculateEndDate(_dateFrom!, _maxDays!);
                              } else if (_isRestrictedByBalanceType && _dateFrom != null && _dateTo != null) {
                                // Re-validate dates if switching to balance-based leave type.
                                final balance = _currentSelectedBalance();
                                final days = _calculateDays();
                                if (balance > 0 && days > balance) {
                                  _dateTo = _dateFrom!.add(Duration(days: balance - 1));
                                }
                              } else {
                                // Reset date_to if switching to type without max_days
                                if (_hasMaxDays == false) {
                                  _dateTo = null;
                                }
                              }
                            });
                          },
                          validator: (value) {
                            if (value == null) {
                              return 'Pilih jenis izin/cuti';
                            }
                            return null;
                          },
                        ),
                      ),
                      // Show leave balance for Annual Leave
                      if (_isAnnualLeave && _userLeaveBalance != null) ...[
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Colors.green.shade50,
                                Colors.green.shade100,
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Colors.green.shade300,
                              width: 1.5,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.info_outline, color: Colors.green.shade700, size: 20),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Saldo Cuti Tahunan',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.green.shade900,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Saldo Tersedia',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey[700],
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        '$_userLeaveBalance Hari',
                                        style: TextStyle(
                                          fontSize: 24,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.green.shade700,
                                        ),
                                      ),
                                    ],
                                  ),
                                  if (_dateFrom != null && _dateTo != null) ...[
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.end,
                                      children: [
                                        Text(
                                          'Hari Dipilih',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey[700],
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          '${_calculateDays()} Hari',
                                          style: TextStyle(
                                            fontSize: 24,
                                            fontWeight: FontWeight.bold,
                                            color: _isExceedingBalance 
                                                ? Colors.red.shade700 
                                                : Colors.blue.shade700,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ],
                              ),
                              if (_dateFrom != null && _dateTo != null && _isExceedingBalance) ...[
                                const SizedBox(height: 12),
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.red.shade50,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: Colors.red.shade300,
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(Icons.warning, color: Colors.red.shade700, size: 20),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          'Jumlah hari cuti melebihi saldo yang tersedia',
                                          style: TextStyle(
                                            fontSize: 13,
                                            color: Colors.red.shade900,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ] else if (_dateFrom != null && _dateTo != null && !_isExceedingBalance) ...[
                                const SizedBox(height: 12),
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.blue.shade50,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: Colors.blue.shade300,
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(Icons.check_circle, color: Colors.blue.shade700, size: 20),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          'Sisa saldo: ${_userLeaveBalance! - _calculateDays()} hari',
                                          style: TextStyle(
                                            fontSize: 13,
                                            color: Colors.blue.shade900,
                                            fontWeight: FontWeight.w600,
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
                      const SizedBox(height: 20),
                      // Date From
                      InkWell(
                        onTap: _selectDateFrom,
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade50,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.grey.shade200),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.calendar_today, color: Colors.purple.shade400, size: 22),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Tanggal Mulai *',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey[600],
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      _dateFrom != null
                                          ? DateFormat('dd MMMM yyyy', 'id_ID').format(_dateFrom!)
                                          : 'Pilih tanggal',
                                      style: TextStyle(
                                        fontSize: 15,
                                        color: _dateFrom != null ? Colors.black87 : Colors.grey,
                                        fontWeight: _dateFrom != null ? FontWeight.w500 : FontWeight.normal,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey[400]),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      // Date To
                      InkWell(
                        onTap: _hasMaxDays ? null : _selectDateTo,
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                          decoration: BoxDecoration(
                            color: _hasMaxDays ? Colors.grey.shade200 : Colors.grey.shade50,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.grey.shade200),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.calendar_today, 
                                color: _hasMaxDays ? Colors.grey.shade400 : Colors.purple.shade400, 
                                size: 22,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Tanggal Selesai *',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey[600],
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      _dateTo != null
                                          ? DateFormat('dd MMMM yyyy', 'id_ID').format(_dateTo!)
                                          : 'Pilih tanggal',
                                      style: TextStyle(
                                        fontSize: 15,
                                        color: _dateTo != null 
                                            ? (_hasMaxDays ? Colors.grey[700] : Colors.black87)
                                            : Colors.grey,
                                        fontWeight: _dateTo != null ? FontWeight.w500 : FontWeight.normal,
                                      ),
                                    ),
                                    if (_hasMaxDays && _maxDays != null) ...[
                                      const SizedBox(height: 4),
                                      Text(
                                        'Otomatis berdasarkan durasi maksimal ($_maxDays hari)',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: Colors.grey[600],
                                          fontStyle: FontStyle.italic,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              if (!_hasMaxDays)
                                Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey[400]),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      // Reason
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: TextFormField(
                          controller: _reasonController,
                          decoration: InputDecoration(
                            labelText: 'Alasan *',
                            labelStyle: TextStyle(
                              color: Colors.grey[700],
                              fontWeight: FontWeight.w500,
                            ),
                            hintText: 'Masukkan alasan izin/cuti',
                            hintStyle: TextStyle(color: Colors.grey[400]),
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.all(16),
                            prefixIcon: Icon(Icons.description, color: Colors.purple.shade400),
                          ),
                          style: const TextStyle(fontSize: 15),
                          maxLines: 4,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Masukkan alasan izin/cuti';
                            }
                            return null;
                          },
                        ),
                      ),
                      // Document upload section (if required)
                      if (_requiresDocument) ...[
                        const SizedBox(height: 20),
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.orange.shade50,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Colors.orange.shade300,
                              width: 1.5,
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.warning_amber_rounded, color: Colors.orange.shade700, size: 20),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Jenis izin/cuti ini wajib melampirkan dokumen pendukung',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.orange.shade900,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Icon(Icons.attach_file, color: Colors.purple.shade400, size: 20),
                            const SizedBox(width: 8),
                            const Text(
                              'Dokumen Pendukung *',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        // Upload button
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.grey.shade300),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.grey.withOpacity(0.1),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: _pickDocuments,
                              borderRadius: BorderRadius.circular(12),
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.camera_alt, color: Colors.purple.shade400, size: 24),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Ambil Foto dengan Kamera',
                                      style: TextStyle(
                                        fontSize: 15,
                                        color: Colors.purple.shade600,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Klik untuk membuka kamera dan ambil foto dokumen pendukung',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey[600],
                          ),
                          textAlign: TextAlign.center,
                        ),
                        // Show selected documents
                        if (_selectedDocuments.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade50,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.grey.shade200),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Dokumen Terpilih (${_selectedDocuments.length})',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.grey[700],
                                  ),
                                ),
                                const SizedBox(height: 8),
                                ..._selectedDocuments.asMap().entries.map((entry) {
                                  final index = entry.key;
                                  final file = entry.value;
                                  return Container(
                                    margin: const EdgeInsets.only(bottom: 8),
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: Colors.grey.shade300),
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(Icons.insert_drive_file, color: Colors.purple.shade400, size: 20),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            file.path.split('/').last,
                                            style: const TextStyle(
                                              fontSize: 13,
                                              color: Colors.black87,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        IconButton(
                                          icon: Icon(Icons.close, color: Colors.red.shade400, size: 20),
                                          onPressed: () {
                                            setState(() {
                                              _selectedDocuments.removeAt(index);
                                            });
                                          },
                                        ),
                                      ],
                                    ),
                                  );
                                }).toList(),
                              ],
                            ),
                          ),
                          // Add More Photos Button
                          const SizedBox(height: 12),
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.grey.shade300),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.grey.withOpacity(0.1),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: _pickDocuments,
                                borderRadius: BorderRadius.circular(12),
                                child: Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.add_circle_outline, color: Colors.purple.shade400, size: 20),
                                      const SizedBox(width: 8),
                                      Text(
                                        'Tambah Foto Lainnya',
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: Colors.purple.shade600,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ],
                      const SizedBox(height: 24),
                      // Approvers
                      Row(
                        children: [
                          Icon(Icons.person_search, color: Colors.purple.shade400, size: 20),
                          const SizedBox(width: 8),
                          const Text(
                            'Approver *',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      // Search approvers
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey.shade300),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.grey.withOpacity(0.1),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: TextField(
                          controller: _approverSearchController,
                          decoration: InputDecoration(
                            hintText: 'Cari approver...',
                            hintStyle: TextStyle(color: Colors.grey[400]),
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                            prefixIcon: Icon(Icons.search, color: Colors.purple.shade400),
                            suffixIcon: _approverSearchController.text.isNotEmpty
                                ? IconButton(
                                    icon: Icon(Icons.clear, color: Colors.grey[600]),
                                    onPressed: () {
                                      _approverSearchDebounce?.cancel();
                                      _approverSearchController.clear();
                                      setState(() {});
                                      _loadApprovers();
                                    },
                                  )
                                : null,
                          ),
                          style: const TextStyle(fontSize: 15),
                          onChanged: (_) {
                            setState(() {});
                            _approverSearchDebounce?.cancel();
                            _approverSearchDebounce = Timer(
                              const Duration(milliseconds: 400),
                              () {
                                if (mounted) _loadApprovers();
                              },
                            );
                          },
                          onSubmitted: (_) {
                            _approverSearchDebounce?.cancel();
                            _loadApprovers();
                          },
                        ),
                      ),
                      const SizedBox(height: 12),
                      // Approver list
                      if (_isLoadingApprovers)
                        Container(
                          padding: const EdgeInsets.all(20),
                          child: Center(child: AppLoadingIndicator()),
                        )
                      else if (_availableApprovers.isEmpty)
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade50,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.grey.shade200),
                          ),
                          child: Center(
                            child: Text(
                              'Tidak ada approver tersedia',
                              style: TextStyle(color: Colors.grey[600]),
                            ),
                          ),
                        )
                      else
                        Container(
                          constraints: const BoxConstraints(maxHeight: 250),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.grey.shade200),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.grey.withOpacity(0.1),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: ListView.builder(
                            shrinkWrap: true,
                            itemCount: _availableApprovers.length,
                            itemBuilder: (context, index) {
                              final approver = _availableApprovers[index];
                              final approverId = _coerceUserId(approver['id']);
                              if (approverId == null) {
                                return const SizedBox.shrink();
                              }
                              final isSelected = _selectedApprovers.contains(approverId);
                              return Container(
                                decoration: BoxDecoration(
                                  color: isSelected ? Colors.purple.shade50 : Colors.transparent,
                                  border: Border(
                                    bottom: BorderSide(
                                      color: Colors.grey.shade200,
                                      width: index < _availableApprovers.length - 1 ? 1 : 0,
                                    ),
                                  ),
                                ),
                                child: CheckboxListTile(
                                  title: Text(
                                    approver['nama_lengkap'] ?? '',
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w500,
                                      color: isSelected ? Colors.purple.shade700 : Colors.black87,
                                    ),
                                  ),
                                  subtitle: approver['jabatan'] != null
                                      ? Text(
                                          approver['jabatan'] ?? '',
                                          style: TextStyle(
                                            fontSize: 13,
                                            color: Colors.grey[600],
                                          ),
                                        )
                                      : null,
                                  value: isSelected,
                                  activeColor: Colors.purple.shade600,
                                  checkColor: Colors.white,
                                  onChanged: (value) {
                                    setState(() {
                                      if (value == true) {
                                        _selectedApprovers.add(approverId);
                                      } else {
                                        _selectedApprovers.remove(approverId);
                                      }
                                    });
                                  },
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                ),
                              );
                            },
                          ),
                        ),
                      // Show selected approvers
                      if (_selectedApprovers.isNotEmpty) ...[
                        const SizedBox(height: 24),
                        Row(
                          children: [
                            Icon(Icons.people, color: Colors.purple.shade400, size: 20),
                            const SizedBox(width: 8),
                            const Text(
                              'Approver Terpilih',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.purple.shade50,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Colors.purple.shade200,
                              width: 1.5,
                            ),
                          ),
                          child: Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: _selectedApprovers.map((approverId) {
                              final approver = _availableApprovers.firstWhere(
                                (a) => _coerceUserId(a['id']) == approverId,
                                orElse: () => {},
                              );
                              final approverName = approver['nama_lengkap'] ?? 'Unknown';
                              final approverJabatan = approver['jabatan'] ?? '';
                              
                              return Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      Colors.purple.shade600,
                                      Colors.purple.shade800,
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(20),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.purple.withOpacity(0.3),
                                      blurRadius: 4,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.person,
                                      color: Colors.white,
                                      size: 16,
                                    ),
                                    const SizedBox(width: 6),
                                    Flexible(
                                      child: Text(
                                        approverName,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    if (approverJabatan.isNotEmpty) ...[
                                      const SizedBox(width: 4),
                                      Text(
                                        '($approverJabatan)',
                                        style: TextStyle(
                                          color: Colors.white.withOpacity(0.9),
                                          fontSize: 11,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                    const SizedBox(width: 6),
                                    GestureDetector(
                                      onTap: () {
                                        setState(() {
                                          _selectedApprovers.remove(approverId);
                                        });
                                      },
                                      child: Container(
                                        padding: const EdgeInsets.all(2),
                                        decoration: BoxDecoration(
                                          color: Colors.white.withOpacity(0.3),
                                          shape: BoxShape.circle,
                                        ),
                                        child: Icon(
                                          Icons.close,
                                          color: Colors.white,
                                          size: 14,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                      ],
                      const SizedBox(height: 24),
                      // Submit button
                      Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Colors.purple.shade600, Colors.purple.shade800],
                          ),
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.purple.withOpacity(0.3),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: _isSubmitting ? null : _submitRequest,
                            borderRadius: BorderRadius.circular(14),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 18),
                              alignment: Alignment.center,
                              child: _isSubmitting
                                  ? const SizedBox(
                                      height: 24,
                                      width: 24,
                                      child: AppLoadingIndicator(
                                        size: 24,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(Icons.send, color: Colors.white, size: 20),
                                        SizedBox(width: 8),
                                        Text(
                                          'Kirim Permohonan',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                            letterSpacing: 0.5,
                                          ),
                                        ),
                                      ],
                                    ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

