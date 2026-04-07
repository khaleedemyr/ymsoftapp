import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/user_shift_service.dart';
import '../services/auth_service.dart';
import '../models/user_shift_models.dart';
import '../widgets/app_scaffold.dart';
import '../widgets/app_loading_indicator.dart';

class UserShiftInputScreen extends StatefulWidget {
  const UserShiftInputScreen({super.key});

  @override
  State<UserShiftInputScreen> createState() => _UserShiftInputScreenState();
}

class _UserShiftInputScreenState extends State<UserShiftInputScreen> {
  final UserShiftService _service = UserShiftService();
  final AuthService _authService = AuthService();

  // Filter
  int? _selectedOutletId;
  int? _selectedDivisionId;
  DateTime? _startDate;
  final TextEditingController _startDateController = TextEditingController();

  // Data
  List<Map<String, dynamic>> _outlets = [];
  List<Map<String, dynamic>> _divisions = [];
  List<UserShiftUser> _users = [];
  List<Shift> _shifts = [];
  List<String> _dates = [];
  List<UserShift> _userShifts = [];
  List<Holiday> _holidays = [];
  List<ApprovedAbsent> _approvedAbsents = [];

  // Form data: {user_id: {tanggal: shift_id}}
  Map<int, Map<String, int?>> _shiftsData = {};
  // Explicit OFF flags: {user_id: {tanggal: true}}
  Map<int, Map<String, bool>> _explicitOff = {};

  // Initial shifts data (for comparison)
  Map<int, Map<String, int?>> _initialShiftsData = {};

  // Loading
  bool _isLoading = false;
  bool _isLoadingData = false;
  bool _isLoadingOutletsDivisions = false;

  // User outlet restriction
  int? _userOutletId;

  // Bulk input
  bool _showBulkInput = false;
  int? _bulkShiftId;
  List<int> _bulkSelectedUsers = [];
  List<String> _bulkSelectedDates = [];
  bool _bulkApplyToAllUsers = false;
  bool _bulkApplyToAllDates = false;

  final List<String> _days = ['Minggu', 'Senin', 'Selasa', 'Rabu', 'Kamis', 'Jumat', 'Sabtu'];

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _loadOutletsAndDivisions();
  }

  @override
  void dispose() {
    _startDateController.dispose();
    super.dispose();
  }

  // Searchable Dropdown Widget - Exact copy from PR OPS
  Widget _buildSearchableDropdown<T>({
    required String label,
    required T? value,
    required List<Map<String, dynamic>> items,
    required T? Function(Map<String, dynamic>) getValue,
    required String Function(Map<String, dynamic>) getLabel,
    required void Function(T?) onChanged,
    bool isLoading = false,
  }) {
    String displayText = '';
    if (value != null && items.isNotEmpty) {
      try {
        final selectedItem = items.firstWhere(
          (item) => getValue(item) == value,
          orElse: () => <String, dynamic>{},
        );
        if (selectedItem.isNotEmpty) {
          displayText = getLabel(selectedItem);
        }
      } catch (e) {
        displayText = '';
      }
    }
    
    final canTap = !isLoading && items.isNotEmpty;
    
    return InkWell(
      onTap: canTap
          ? () async {
              final selected = await _showSearchableDialog<T>(
                context: context,
                title: label,
                items: items,
                getValue: getValue,
                getLabel: getLabel,
                currentValue: value,
              );
              if (selected != null && selected != value) {
                onChanged(selected);
              }
            }
          : () {
              // Show message when tapped but not ready
              if (isLoading) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Sedang memuat data...'),
                    duration: Duration(seconds: 1),
                  ),
                );
              } else if (items.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Data $label belum tersedia'),
                    duration: const Duration(seconds: 2),
                  ),
                );
              }
            },
      borderRadius: BorderRadius.circular(12),
      child: TextFormField(
        readOnly: true,
        enabled: false,
        controller: TextEditingController(text: displayText),
        decoration: InputDecoration(
          labelText: label,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          filled: true,
          fillColor: canTap ? Colors.white : Colors.grey.shade200,
          hintText: isLoading ? 'Loading...' : (items.isEmpty ? 'Tidak ada data' : 'Tap to search'),
          suffixIcon: const Icon(Icons.search),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        ),
        style: TextStyle(
          color: canTap ? Colors.black87 : Colors.grey.shade600,
          fontSize: 16,
        ),
      ),
    );
  }

  // Show searchable dialog - Same as PR OPS
  Future<T?> _showSearchableDialog<T>({
    required BuildContext context,
    required String title,
    required List<Map<String, dynamic>> items,
    required T? Function(Map<String, dynamic>) getValue,
    required String Function(Map<String, dynamic>) getLabel,
    T? currentValue,
  }) async {
    final searchController = TextEditingController();
    List<Map<String, dynamic>> filteredItems = List.from(items);
    
    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return DraggableScrollableSheet(
              initialChildSize: 0.7,
              minChildSize: 0.5,
              maxChildSize: 0.95,
              expand: false,
              builder: (context, scrollController) {
                return Column(
                  children: [
                    // Header
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E3A5F),
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(20),
                        ),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              title,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close, color: Colors.white),
                            onPressed: () => Navigator.pop(context),
                          ),
                        ],
                      ),
                    ),
                    // Search field
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: TextField(
                        controller: searchController,
                        decoration: InputDecoration(
                          hintText: 'Search...',
                          prefixIcon: const Icon(Icons.search),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          filled: true,
                          fillColor: Colors.grey.shade50,
                        ),
                        onChanged: (query) {
                          setModalState(() {
                            if (query.isEmpty) {
                              filteredItems = List.from(items);
                            } else {
                              final lowerQuery = query.toLowerCase();
                              filteredItems = items.where((item) {
                                final label = getLabel(item).toLowerCase();
                                return label.contains(lowerQuery);
                              }).toList();
                            }
                          });
                        },
                      ),
                    ),
                    // List
                    Expanded(
                      child: filteredItems.isEmpty
                          ? Center(
                              child: Padding(
                                padding: const EdgeInsets.all(32),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.search_off,
                                      size: 64,
                                      color: Colors.grey[400],
                                    ),
                                    const SizedBox(height: 16),
                                    Text(
                                      'No results found',
                                      style: TextStyle(
                                        color: Colors.grey[600],
                                        fontSize: 16,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            )
                          : ListView.builder(
                              controller: scrollController,
                              itemCount: filteredItems.length,
                              itemBuilder: (context, index) {
                                final item = filteredItems[index];
                                final itemValue = getValue(item);
                                final itemLabel = getLabel(item);
                                final isSelected = itemValue == currentValue;

                                return ListTile(
                                  title: Text(itemLabel),
                                  selected: isSelected,
                                  selectedTileColor: Colors.blue.shade50,
                                  onTap: () {
                                    Navigator.of(context).pop(itemValue);
                                  },
                                );
                              },
                            ),
                    ),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }

  Future<void> _loadUserData() async {
    try {
      final userData = await _authService.getUserData();
      if (userData != null) {
        setState(() {
          _userOutletId = userData['id_outlet'];
          // If user is not HO (outlet_id != 1), set outlet automatically
          if (_userOutletId != null && _userOutletId != 1) {
            _selectedOutletId = _userOutletId;
          }
        });
      }
    } catch (e) {
      print('Error loading user data: $e');
    }
  }

  Future<void> _loadOutletsAndDivisions() async {
    setState(() {
      _isLoadingOutletsDivisions = true;
    });

    try {
      // Load outlets and divisions without filters (similar to web)
      final result = await _service.getUserShifts(
        outletId: null,
        divisionId: null,
        startDate: null,
      );

      print('Load outlets/divisions result: ${result['success']}');
      print('Result data keys: ${result['data']?.keys}');

      if (result['success'] == true && mounted) {
        final data = result['data'];
        
        // Parse outlets
        List<Map<String, dynamic>> outlets = [];
        if (data['outlets'] != null) {
          final outletsData = data['outlets'] as List<dynamic>;
          print('Outlets data count: ${outletsData.length}');
          outlets = outletsData.map((o) {
            final outletMap = o is Map<String, dynamic> ? o : Map<String, dynamic>.from(o);
            return {
              'id': outletMap['id'] is int ? outletMap['id'] : (outletMap['id'] is num ? (outletMap['id'] as num).toInt() : 0),
              'name': outletMap['name']?.toString() ?? '',
            };
          }).toList();
        }

        // Parse divisions
        List<Map<String, dynamic>> divisions = [];
        if (data['divisions'] != null) {
          final divisionsData = data['divisions'] as List<dynamic>;
          print('Divisions data count: ${divisionsData.length}');
          divisions = divisionsData.map((d) {
            final divisionMap = d is Map<String, dynamic> ? d : Map<String, dynamic>.from(d);
            return {
              'id': divisionMap['id'] is int ? divisionMap['id'] : (divisionMap['id'] is num ? (divisionMap['id'] as num).toInt() : 0),
              'name': divisionMap['name']?.toString() ?? '',
            };
          }).toList();
        }

        print('Loaded outlets: ${outlets.length}, divisions: ${divisions.length}');

        setState(() {
          _outlets = outlets;
          _divisions = divisions;
          _isLoadingOutletsDivisions = false;
        });
      } else {
        print('Failed to load outlets/divisions: ${result['error']}');
        setState(() {
          _isLoadingOutletsDivisions = false;
        });
        if (mounted && result['error'] != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Gagal memuat data: ${result['error']}'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      }
    } catch (e, stackTrace) {
      print('Error loading outlets and divisions: $e');
      print('Stack trace: $stackTrace');
      if (mounted) {
        setState(() {
          _isLoadingOutletsDivisions = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading outlets and divisions: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _loadData() async {
    if (_selectedOutletId == null || _selectedDivisionId == null || _startDate == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Silakan pilih outlet, divisi, dan tanggal mulai!'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }

    setState(() {
      _isLoadingData = true;
    });

    try {
      final result = await _service.getUserShifts(
        outletId: _selectedOutletId,
        divisionId: _selectedDivisionId,
        startDate: DateFormat('yyyy-MM-dd').format(_startDate!),
      );

      if (result['success'] == true && mounted) {
        final data = result['data'];
        print('User Shift Data: ${data.keys.toList()}');
        
        // Parse outlets
        List<Map<String, dynamic>> outlets = [];
        if (data['outlets'] != null) {
          final outletsData = data['outlets'] as List<dynamic>;
          outlets = outletsData.map((o) {
            final outletMap = o is Map<String, dynamic> ? o : Map<String, dynamic>.from(o);
            return {
              'id': outletMap['id'] is int ? outletMap['id'] : (outletMap['id'] is num ? (outletMap['id'] as num).toInt() : 0),
              'name': outletMap['name']?.toString() ?? '',
            };
          }).toList();
        }

        // Parse divisions
        List<Map<String, dynamic>> divisions = [];
        if (data['divisions'] != null) {
          final divisionsData = data['divisions'] as List<dynamic>;
          divisions = divisionsData.map((d) {
            final divisionMap = d is Map<String, dynamic> ? d : Map<String, dynamic>.from(d);
            return {
              'id': divisionMap['id'] is int ? divisionMap['id'] : (divisionMap['id'] is num ? (divisionMap['id'] as num).toInt() : 0),
              'name': divisionMap['name']?.toString() ?? '',
            };
          }).toList();
        }

        // Parse users
        List<UserShiftUser> users = [];
        if (data['users'] != null) {
          final usersData = data['users'] as List<dynamic>;
          users = usersData.map((u) {
            final userMap = u is Map<String, dynamic> ? u : Map<String, dynamic>.from(u);
            return UserShiftUser.fromJson(userMap);
          }).toList();
        }

        // Parse shifts
        List<Shift> shifts = [];
        if (data['shifts'] != null) {
          final shiftsData = data['shifts'] as List<dynamic>;
          shifts = shiftsData.map((s) {
            final shiftMap = s is Map<String, dynamic> ? s : Map<String, dynamic>.from(s);
            return Shift.fromJson(shiftMap);
          }).toList();
        }

        // Parse dates
        List<String> dates = [];
        if (data['dates'] != null) {
          final datesData = data['dates'] as List<dynamic>;
          dates = datesData.map((d) => d.toString()).toList();
        }

        // Parse user shifts
        List<UserShift> userShifts = [];
        if (data['userShifts'] != null) {
          final userShiftsData = data['userShifts'] as List<dynamic>;
          userShifts = userShiftsData.map((us) {
            final userShiftMap = us is Map<String, dynamic> ? us : Map<String, dynamic>.from(us);
            return UserShift.fromJson(userShiftMap);
          }).toList();
        }

        // Parse holidays
        List<Holiday> holidays = [];
        if (data['holidays'] != null) {
          final holidaysData = data['holidays'] as List<dynamic>;
          holidays = holidaysData.map((h) {
            final holidayMap = h is Map<String, dynamic> ? h : Map<String, dynamic>.from(h);
            return Holiday.fromJson(holidayMap);
          }).toList();
        }

        // Parse approved absents
        List<ApprovedAbsent> approvedAbsents = [];
        if (data['approvedAbsents'] != null) {
          final approvedAbsentsData = data['approvedAbsents'] as List<dynamic>;
          approvedAbsents = approvedAbsentsData.map((a) {
            final absentMap = a is Map<String, dynamic> ? a : Map<String, dynamic>.from(a);
            return ApprovedAbsent.fromJson(absentMap);
          }).toList();
        }

        // Build shifts data map
        Map<int, Map<String, int?>> shiftsData = {};
        Map<int, Map<String, int?>> initialShiftsData = {};
        for (var user in users) {
          shiftsData[user.id] = {};
          initialShiftsData[user.id] = {};
          for (var date in dates) {
            final userShift = userShifts.firstWhere(
              (us) => us.userId == user.id && us.tanggal == date,
              orElse: () => UserShift(
                id: 0,
                userId: user.id,
                shiftId: null,
                tanggal: date,
                outletId: _selectedOutletId!,
                divisionId: _selectedDivisionId!,
              ),
            );
            // Ensure shiftId is properly typed (int? or null)
            final shiftId = userShift.shiftId;
            shiftsData[user.id]![date] = shiftId;
            initialShiftsData[user.id]![date] = shiftId;
          }
        }
        
        print('Loaded shifts data: ${shiftsData.length} users, ${shiftsData.values.fold(0, (sum, dates) => sum + dates.length)} total entries');
        print('Sample shifts data: ${shiftsData.entries.take(2).map((e) => 'User ${e.key}: ${e.value}').join(', ')}');

        setState(() {
          _outlets = outlets;
          _divisions = divisions;
          _users = users;
          _shifts = shifts;
          _dates = dates;
          _userShifts = userShifts;
          _holidays = holidays;
          _approvedAbsents = approvedAbsents;
          _shiftsData = shiftsData;
          _initialShiftsData = initialShiftsData;
          _explicitOff = {};
          _isLoadingData = false;
        });
      } else if (mounted) {
        setState(() {
          _isLoadingData = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['error'] ?? 'Gagal memuat data'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingData = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  String _getDayName(String dateStr) {
    try {
      final date = DateTime.parse(dateStr);
      return _days[date.weekday % 7];
    } catch (e) {
      return '';
    }
  }

  String _formatDateLocal(String dateStr) {
    try {
      final date = DateTime.parse(dateStr);
      return DateFormat('yyyy-MM-dd').format(date);
    } catch (e) {
      return dateStr;
    }
  }

  bool _isHoliday(String date) {
    final key = _formatDateLocal(date);
    return _holidays.any((h) => _formatDateLocal(h.date) == key);
  }

  String? _getHolidayName(String date) {
    final key = _formatDateLocal(date);
    final holiday = _holidays.firstWhere(
      (h) => _formatDateLocal(h.date) == key,
      orElse: () => Holiday(date: '', name: ''),
    );
    return holiday.name.isNotEmpty ? holiday.name : null;
  }

  ApprovedAbsent? _getApprovedAbsentForDate(String date, int userId) {
    try {
      final dateObj = DateTime.parse(date);
      try {
        return _approvedAbsents.firstWhere(
          (absent) {
            if (absent.userId != userId) return false;
            final fromDate = DateTime.parse(absent.dateFrom);
            final toDate = DateTime.parse(absent.dateTo);
            return dateObj.isAfter(fromDate.subtract(const Duration(days: 1))) &&
                   dateObj.isBefore(toDate.add(const Duration(days: 1)));
          },
        );
      } catch (e) {
        // No absent found, return null
        return null;
      }
    } catch (e) {
      return null;
    }
  }

  bool _isPastDate(String date) {
    try {
      final dateObj = DateTime.parse(date);
      final today = DateTime.now();
      return dateObj.isBefore(DateTime(today.year, today.month, today.day));
    } catch (e) {
      return false;
    }
  }

  void _buildExplicitOffFlags() {
    _explicitOff.clear();
    for (var user in _users) {
      _explicitOff[user.id] = {};
      for (var date in _dates) {
        // Only flag if initial had value and current is null
        final initial = _initialShiftsData[user.id]?[date] ?? null;
        final current = _shiftsData[user.id]?[date] ?? null;
        if (initial != null && current == null) {
          _explicitOff[user.id]![date] = true;
        }
      }
      if (_explicitOff[user.id]!.isEmpty) {
        _explicitOff.remove(user.id);
      }
    }
  }

  Future<void> _saveShifts() async {
    if (_selectedOutletId == null || _selectedDivisionId == null || _startDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Silakan pilih outlet, divisi, dan tanggal mulai!'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    _buildExplicitOffFlags();

    setState(() {
      _isLoading = true;
    });

    try {
      final result = await _service.saveUserShifts(
        outletId: _selectedOutletId!,
        divisionId: _selectedDivisionId!,
        startDate: DateFormat('yyyy-MM-dd').format(_startDate!),
        shifts: _shiftsData,
        explicitOff: _explicitOff.isNotEmpty ? _explicitOff : null,
      );

      if (mounted) {
        setState(() {
          _isLoading = false;
        });

        if (result['success'] == true) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result['message'] ?? 'Jadwal shift berhasil disimpan!'),
              backgroundColor: Colors.green,
            ),
          );
          // Reload data to get updated state
          await _loadData();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result['error'] ?? 'Gagal menyimpan jadwal shift'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _applyBulkInput() {
    if (_bulkShiftId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Silakan pilih shift yang akan diterapkan!'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (!_bulkApplyToAllUsers && _bulkSelectedUsers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Silakan pilih karyawan atau centang "Terapkan ke Semua Karyawan"!'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (!_bulkApplyToAllDates && _bulkSelectedDates.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Silakan pilih tanggal atau centang "Terapkan ke Semua Tanggal"!'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final usersToApply = _bulkApplyToAllUsers
        ? _users
        : _users.where((u) => _bulkSelectedUsers.contains(u.id)).toList();
    final datesToApply = _bulkApplyToAllDates
        ? _dates.where((d) => !_isPastDate(d)).toList()
        : _bulkSelectedDates;

    int appliedCount = 0;
    int skippedCount = 0;

    for (var user in usersToApply) {
      for (var date in datesToApply) {
        // Skip if date is past or user has approved absent
        if (_isPastDate(date) || _getApprovedAbsentForDate(date, user.id) != null) {
          skippedCount++;
          continue;
        }

        // Apply shift (convert -1 to null for OFF)
        _shiftsData[user.id]![date] = _bulkShiftId == -1 ? null : _bulkShiftId;
        appliedCount++;
      }
    }

    setState(() {
      _showBulkInput = false;
      _bulkShiftId = null;
      _bulkSelectedUsers = [];
      _bulkSelectedDates = [];
      _bulkApplyToAllUsers = false;
      _bulkApplyToAllDates = false;
    });

    final shiftName = _bulkShiftId == -1
        ? 'OFF (Tidak Masuk Kerja)'
        : _shifts.firstWhere(
            (s) => s.id == _bulkShiftId,
            orElse: () => Shift(
              id: 0,
              divisionId: 0,
              shiftName: 'Shift',
              timeStart: '',
              timeEnd: '',
            ),
          ).shiftName;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Berhasil menerapkan $shiftName ke $appliedCount slot jadwal.${skippedCount > 0 ? ' $skippedCount slot dilewati (tanggal lewat atau ada absen).' : ''}',
        ),
        backgroundColor: Colors.green,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Input Shift Mingguan Karyawan',
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Filter Section
                Card(
                  margin: const EdgeInsets.only(bottom: 16),
                  elevation: 2,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Filter',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),
                        // Outlet Dropdown
                        if (_userOutletId != null && _userOutletId != 1)
                          TextFormField(
                            readOnly: true,
                            controller: TextEditingController(
                              text: _selectedOutletId != null
                                  ? (_outlets.firstWhere(
                                      (item) => item['id'] == _selectedOutletId,
                                      orElse: () => <String, dynamic>{},
                                    )['name'] ?? '') as String
                                  : '',
                            ),
                            decoration: InputDecoration(
                              labelText: 'Outlet',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              filled: true,
                              fillColor: Colors.grey.shade200,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                            ),
                          )
                        else
                          _buildSearchableDropdown<int>(
                            label: 'Outlet',
                            value: _selectedOutletId,
                            items: _outlets,
                            getValue: (item) => item['id'] as int?,
                            getLabel: (item) => item['name'] ?? '',
                            onChanged: (value) {
                              setState(() {
                                _selectedOutletId = value;
                              });
                            },
                            isLoading: _isLoadingOutletsDivisions,
                          ),
                        const SizedBox(height: 16),
                        // Division Dropdown
                        _buildSearchableDropdown<int>(
                          label: 'Divisi',
                          value: _selectedDivisionId,
                          items: _divisions,
                          getValue: (item) => item['id'] as int?,
                          getLabel: (item) => item['name'] ?? '',
                          onChanged: (value) {
                            setState(() {
                              _selectedDivisionId = value;
                            });
                          },
                          isLoading: _isLoadingOutletsDivisions,
                        ),
                        const SizedBox(height: 16),
                        // Date Picker
                        TextFormField(
                          controller: _startDateController,
                          decoration: InputDecoration(
                            labelText: 'Tanggal Mulai (Senin)',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            filled: true,
                            fillColor: Colors.white,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                            suffixIcon: const Icon(Icons.calendar_today),
                          ),
                          readOnly: true,
                          onTap: () async {
                            final date = await showDatePicker(
                              context: context,
                              initialDate: _startDate ?? DateTime.now(),
                              firstDate: DateTime(2020),
                              lastDate: DateTime(2100),
                            );
                            if (date != null) {
                              setState(() {
                                _startDate = date;
                                _startDateController.text = DateFormat('yyyy-MM-dd').format(date);
                              });
                            }
                          },
                        ),
                        const SizedBox(height: 16),
                        // Search Button
                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: ElevatedButton.icon(
                            onPressed: _loadData,
                            icon: const Icon(Icons.search),
                            label: const Text('Tampilkan'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue.shade600,
                              foregroundColor: Colors.white,
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
                const SizedBox(height: 16),
                // Bulk Input Section
                if (_users.isNotEmpty && _dates.isNotEmpty) ...[
                  Card(
                    margin: const EdgeInsets.only(bottom: 16),
                    elevation: 2,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Bulk Input Shift',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              IconButton(
                                icon: Icon(_showBulkInput ? Icons.close : Icons.add),
                                onPressed: () {
                                  setState(() {
                                    _showBulkInput = !_showBulkInput;
                                    if (!_showBulkInput) {
                                      _bulkShiftId = null;
                                      _bulkSelectedUsers = [];
                                      _bulkSelectedDates = [];
                                      _bulkApplyToAllUsers = false;
                                      _bulkApplyToAllDates = false;
                                    }
                                  });
                                },
                              ),
                            ],
                          ),
                          if (_showBulkInput) ...[
                            const SizedBox(height: 16),
                            DropdownButtonFormField<int>(
                              value: _bulkShiftId,
                              decoration: const InputDecoration(
                                labelText: 'Pilih Shift *',
                                border: OutlineInputBorder(),
                                filled: true,
                                fillColor: Colors.white,
                              ),
                              isExpanded: true,
                              items: [
                                const DropdownMenuItem<int>(
                                  value: -1,
                                  child: Text('OFF (Tidak Masuk Kerja)'),
                                ),
                                ..._shifts.map((shift) {
                                  return DropdownMenuItem<int>(
                                    value: shift.id,
                                    child: Text('${shift.shiftName} (${shift.timeStart} - ${shift.timeEnd})'),
                                  );
                                }),
                              ],
                              onChanged: (value) {
                                setState(() {
                                  _bulkShiftId = value;
                                });
                              },
                            ),
                            const SizedBox(height: 16),
                            CheckboxListTile(
                              title: const Text('Terapkan ke Semua Karyawan'),
                              value: _bulkApplyToAllUsers,
                              onChanged: (value) {
                                setState(() {
                                  _bulkApplyToAllUsers = value ?? false;
                                });
                              },
                            ),
                            if (!_bulkApplyToAllUsers) ...[
                              SizedBox(
                                height: 150,
                                child: ListView.builder(
                                  itemCount: _users.length,
                                  itemBuilder: (context, index) {
                                    final user = _users[index];
                                    return CheckboxListTile(
                                      title: Text(user.namaLengkap),
                                      value: _bulkSelectedUsers.contains(user.id),
                                      onChanged: (value) {
                                        setState(() {
                                          if (value == true) {
                                            _bulkSelectedUsers.add(user.id);
                                          } else {
                                            _bulkSelectedUsers.remove(user.id);
                                          }
                                        });
                                      },
                                    );
                                  },
                                ),
                              ),
                            ],
                            const SizedBox(height: 16),
                            CheckboxListTile(
                              title: const Text('Terapkan ke Semua Tanggal (kecuali yang sudah lewat)'),
                              value: _bulkApplyToAllDates,
                              onChanged: (value) {
                                setState(() {
                                  _bulkApplyToAllDates = value ?? false;
                                });
                              },
                            ),
                            if (!_bulkApplyToAllDates) ...[
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: _dates.where((d) => !_isPastDate(d)).map((date) {
                                  return FilterChip(
                                    label: Text('${_getDayName(date)} ($date)'),
                                    selected: _bulkSelectedDates.contains(date),
                                    onSelected: (selected) {
                                      setState(() {
                                        if (selected) {
                                          _bulkSelectedDates.add(date);
                                        } else {
                                          _bulkSelectedDates.remove(date);
                                        }
                                      });
                                    },
                                  );
                                }).toList(),
                              ),
                            ],
                            const SizedBox(height: 16),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                TextButton(
                                  onPressed: () {
                                    setState(() {
                                      _bulkShiftId = null;
                                      _bulkSelectedUsers = [];
                                      _bulkSelectedDates = [];
                                      _bulkApplyToAllUsers = false;
                                      _bulkApplyToAllDates = false;
                                    });
                                  },
                                  child: const Text('Reset'),
                                ),
                                const SizedBox(width: 8),
                                ElevatedButton(
                                  onPressed: _applyBulkInput,
                                  child: const Text('Terapkan'),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                // Table Section
                if (_users.isNotEmpty && _dates.isNotEmpty)
                  Card(
                    margin: const EdgeInsets.only(bottom: 16),
                    elevation: 2,
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: DataTable(
                        dataRowMinHeight: 60,
                        dataRowMaxHeight: 100,
                        // headingRowColor will be overridden by individual column backgrounds
                        headingRowColor: MaterialStateProperty.all(Colors.transparent),
                        headingTextStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                        columns: [
                          const DataColumn(label: Text('Nama Karyawan')),
                          ..._dates.map((date) {
                            final isHoliday = _isHoliday(date);
                            final holidayName = isHoliday ? _getHolidayName(date) : null;
                            // Red background for holiday header (#dc2626 = red-600), blue for normal
                            final headerBgColor = isHoliday ? const Color(0xFFDC2626) : Colors.blue.shade600;
                            return DataColumn(
                              label: Container(
                                constraints: const BoxConstraints(
                                  maxHeight: 80,
                                  minWidth: 100,
                                ),
                                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                                decoration: BoxDecoration(
                                  color: headerBgColor,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    if (holidayName != null)
                                      Flexible(
                                        child: Text(
                                          holidayName,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 9,
                                            fontWeight: FontWeight.bold,
                                          ),
                                          textAlign: TextAlign.center,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    if (holidayName != null) const SizedBox(height: 2),
                                    Flexible(
                                      child: Text(
                                        _getDayName(date),
                                        textAlign: TextAlign.center,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    Flexible(
                                      child: Text(
                                        date,
                                        textAlign: TextAlign.center,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 9,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }),
                        ],
                        rows: _users.map((user) {
                          return DataRow(
                            cells: [
                              DataCell(
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      user.namaLengkap,
                                      style: const TextStyle(fontWeight: FontWeight.bold),
                                    ),
                                    Text(
                                      user.jabatan ?? '-',
                                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                                    ),
                                  ],
                                ),
                              ),
                              ..._dates.map((date) {
                                final isPast = _isPastDate(date);
                                final approvedAbsent = _getApprovedAbsentForDate(date, user.id);
                                final isHoliday = _isHoliday(date);
                                final isDisabled = isPast || approvedAbsent != null;

                                // Get current shift value
                                final currentShiftId = _shiftsData[user.id]?[date];
                                
                                // Red background for holiday cell (#fee2e2 = red-100)
                                final cellBgColor = isHoliday ? const Color(0xFFFEE2E2) : Colors.transparent;
                                final cellBorderColor = isHoliday ? const Color(0xFFFCA5A5) : Colors.transparent;
                                
                                return DataCell(
                                  Container(
                                    constraints: const BoxConstraints(
                                      minWidth: 120,
                                    ),
                                    padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
                                    decoration: BoxDecoration(
                                      color: cellBgColor,
                                      border: isHoliday ? Border.all(color: cellBorderColor, width: 1) : null,
                                      borderRadius: isHoliday ? BorderRadius.circular(4) : null,
                                    ),
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      crossAxisAlignment: CrossAxisAlignment.stretch,
                                      children: [
                                        if (isPast)
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                            margin: const EdgeInsets.only(bottom: 4),
                                            decoration: BoxDecoration(
                                              color: Colors.grey.shade500,
                                              borderRadius: BorderRadius.circular(4),
                                            ),
                                            child: const Text(
                                              'Tanggal Lewat',
                                              style: TextStyle(
                                                color: Colors.white,
                                                fontSize: 9,
                                              ),
                                            ),
                                          )
                                        else if (approvedAbsent != null)
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                            margin: const EdgeInsets.only(bottom: 4),
                                            decoration: BoxDecoration(
                                              color: Colors.green.shade500,
                                              borderRadius: BorderRadius.circular(4),
                                            ),
                                            child: Text(
                                              approvedAbsent.leaveTypeName ?? 'Absen',
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 9,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        DropdownButtonFormField<int?>(
                                          value: currentShiftId,
                                          decoration: InputDecoration(
                                            border: const OutlineInputBorder(),
                                            isDense: true,
                                            contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                            filled: isDisabled || isHoliday,
                                            fillColor: isDisabled 
                                                ? Colors.grey.shade100 
                                                : (isHoliday ? Colors.white : Colors.white),
                                          ),
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: isDisabled 
                                                ? Colors.grey.shade600 
                                                : (isHoliday ? const Color(0xFFB91C1C) : Colors.black87), // Red text for holiday
                                          ),
                                          menuMaxHeight: 200,
                                          isExpanded: true,
                                          items: [
                                            const DropdownMenuItem<int?>(
                                              value: null,
                                              child: Text('OFF', style: TextStyle(fontSize: 12)),
                                            ),
                                            ..._shifts.map((shift) {
                                              return DropdownMenuItem<int?>(
                                                value: shift.id,
                                                child: Text(
                                                  shift.shiftName,
                                                  style: const TextStyle(fontSize: 12),
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              );
                                            }),
                                          ],
                                          onChanged: isDisabled
                                              ? null
                                              : (value) {
                                                  setState(() {
                                                    if (_shiftsData[user.id] == null) {
                                                      _shiftsData[user.id] = {};
                                                    }
                                                    _shiftsData[user.id]![date] = value;
                                                  });
                                                },
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              }),
                            ],
                          );
                        }).toList(),
                      ),
                    ),
                  )
                else if (!_isLoadingData)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(32),
                      child: Text(
                        'Silakan pilih outlet, divisi, dan tanggal mulai minggu (Senin), lalu klik Tampilkan.',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                const SizedBox(height: 16),
                if (_users.isNotEmpty && _dates.isNotEmpty)
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _isLoading ? null : _saveShifts,
                      icon: const Icon(Icons.save),
                      label: const Text('Simpan Jadwal'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        backgroundColor: Colors.blue.shade600,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          if (_isLoading || _isLoadingData)
            Positioned.fill(
              child: Container(
                color: Colors.black.withOpacity(0.3),
                child: const Center(
                  child: AppLoadingIndicator(),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

