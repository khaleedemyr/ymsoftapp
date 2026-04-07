import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../services/attendance_service.dart';
import '../services/auth_service.dart';
import '../widgets/app_scaffold.dart';
import '../widgets/leave_request_modal.dart';
import '../widgets/app_loading_indicator.dart';

class MyAttendanceScreen extends StatefulWidget {
  const MyAttendanceScreen({super.key});

  @override
  State<MyAttendanceScreen> createState() => _MyAttendanceScreenState();
}

class _MyAttendanceScreenState extends State<MyAttendanceScreen> {
  final AttendanceService _attendanceService = AttendanceService();
  
  // Filter
  int _selectedMonth = DateTime.now().month;
  int _selectedYear = DateTime.now().year;
  
  // Data
  Map<String, dynamic>? _attendanceData;
  bool _isLoading = true;
  
  // Calendar
  Map<String, List<dynamic>> _calendarData = {};
  
  // Summary
  Map<String, dynamic> _summary = {
    'total_days': 0,
    'present_days': 0,
    'total_late_minutes': 0,
    'absent_days': 0,
    'total_lembur_hours': 0,
    'percentage': 0,
  };
  
  // Holidays
  List<Map<String, dynamic>> _holidays = [];
  
  // Approved absents
  List<Map<String, dynamic>> _approvedAbsents = [];
  
  // User leave requests
  List<Map<String, dynamic>> _userLeaveRequests = [];
  
  // Leave types
  List<Map<String, dynamic>> _leaveTypes = [];
  
  // PH Data
  Map<String, dynamic>? _phData;
  
  // Extra Off Data
  Map<String, dynamic>? _extraOffData;
  
  // Correction requests
  List<Map<String, dynamic>> _correctionRequests = [];
  
  // User data
  Map<String, dynamic>? _userData;

  @override
  void initState() {
    super.initState();
    _loadAttendanceData();
  }

  Future<void> _loadAttendanceData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      print('🔄 Loading attendance data for bulan: $_selectedMonth, tahun: $_selectedYear');
      
      // Load attendance data from API
      final data = await _attendanceService.getAttendanceData(
        bulan: _selectedMonth,
        tahun: _selectedYear,
      );
      
      print('📥 API Response received: ${data != null}');
      if (data != null) {
        print('📥 Success: ${data['success']}');
        print('📥 Keys: ${data.keys.toList()}');
      } else {
        print('❌ No data received or API error');
        // Show error message to user
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Gagal memuat data attendance. Silakan coba lagi atau login ulang.'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
      
      if (data != null && data['success'] == true) {
        print('✅ Attendance data loaded: ${data.keys}');
        print('📊 Summary: ${data['attendanceSummary']}');
        print('📅 Calendar keys count: ${data['calendar'] is Map ? (data['calendar'] as Map).length : 0}');
        if (data['calendar'] is Map) {
          final calendar = data['calendar'] as Map;
          print('📅 First 3 calendar dates: ${calendar.keys.take(3).toList()}');
        }
        
        setState(() {
          // Parse calendar data - structure: calendar[date] = [schedule1, schedule2, ...]
          if (data['calendar'] != null) {
            final calendar = data['calendar'];
            _calendarData = {};
            
            if (calendar is Map) {
              calendar.forEach((dateKey, dateValue) {
                final dateStr = dateKey.toString();
                List<dynamic> schedules = [];
                
                if (dateValue is List) {
                  schedules = dateValue;
                } else {
                  schedules = [dateValue];
                }
                
                _calendarData[dateStr] = schedules;
              });
            }
            print('✅ Parsed calendar: ${_calendarData.length} dates');
            if (_calendarData.isNotEmpty) {
              final firstDate = _calendarData.keys.first;
              print('📅 Sample date $firstDate: ${_calendarData[firstDate]?.length ?? 0} schedules');
            }
          }
          
          // Parse summary - JSON decode returns Map
          if (data['attendanceSummary'] != null) {
            final summary = data['attendanceSummary'] as Map<String, dynamic>;
            _summary = {
              'total_days': summary['total_days'] ?? 0,
              'present_days': summary['present_days'] ?? 0,
              'total_late_minutes': summary['total_late_minutes'] ?? 0,
              'absent_days': summary['absent_days'] ?? 0,
              'total_lembur_hours': summary['total_lembur_hours'] ?? 0,
              'percentage': (summary['percentage'] ?? 0).toDouble(),
            };
            print('✅ Parsed summary: $_summary');
          } else {
            _summary = {
              'total_days': 0,
              'present_days': 0,
              'total_late_minutes': 0,
              'absent_days': 0,
              'total_lembur_hours': 0,
              'percentage': 0,
            };
          }
          
          // Parse holidays
          if (data['holidays'] != null) {
            _holidays = List<Map<String, dynamic>>.from(
              data['holidays'].map((h) => Map<String, dynamic>.from(h)),
            );
          }
          
          // Parse approved absents
          if (data['approvedAbsents'] != null) {
            _approvedAbsents = List<Map<String, dynamic>>.from(
              data['approvedAbsents'].map((a) => Map<String, dynamic>.from(a)),
            );
          }
          
          // Parse user leave requests
          if (data['userLeaveRequests'] != null) {
            _userLeaveRequests = List<Map<String, dynamic>>.from(
              data['userLeaveRequests'].map((r) => Map<String, dynamic>.from(r)),
            );
          }
          
          // Parse leave types
          if (data['leaveTypes'] != null) {
            _leaveTypes = List<Map<String, dynamic>>.from(
              data['leaveTypes'].map((t) => Map<String, dynamic>.from(t)),
            );
          }
          
          // Parse PH data
          if (data['phData'] != null) {
            _phData = Map<String, dynamic>.from(data['phData']);
          }
          
          // Parse Extra Off data
          if (data['extraOffData'] != null) {
            _extraOffData = Map<String, dynamic>.from(data['extraOffData']);
          }
          
          // Parse correction requests
          if (data['correctionRequests'] != null) {
            _correctionRequests = List<Map<String, dynamic>>.from(
              data['correctionRequests'].map((c) => Map<String, dynamic>.from(c)),
            );
          }
          
          // Parse user data
          if (data['user'] != null) {
            _userData = Map<String, dynamic>.from(data['user']);
          }
        });
      }
      
      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading attendance data: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }


  // Helper to get value from object or map
  dynamic _getValue(dynamic obj, String key) {
    if (obj is Map) {
      return obj[key] ?? 0;
    }
    // Try to access as property (for JSON decoded objects)
    try {
      return obj[key] ?? 0;
    } catch (e) {
      return 0;
    }
  }

  // Calculate payroll period dates
  DateTime _getStartDate() {
    return DateTime(_selectedYear, _selectedMonth - 1, 26);
  }

  DateTime _getEndDate() {
    return DateTime(_selectedYear, _selectedMonth, 25);
  }

  void _showLeaveRequestModal(BuildContext context) {
    print('🔵 _showLeaveRequestModal called');
    print('🔵 _leaveTypes length: ${_leaveTypes.length}');
    
    if (_leaveTypes.isEmpty) {
      print('❌ Leave types is empty');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Data jenis izin/cuti belum tersedia. Silakan refresh halaman.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    try {
      print('✅ Opening modal bottom sheet');
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        enableDrag: true,
        isDismissible: true,
        builder: (context) {
          print('✅ Modal builder called');
          return LeaveRequestModal(
            leaveTypes: _leaveTypes,
            leaveBalance: _userData?['cuti'] as int?,
            onSubmitted: () {
              print('✅ onSubmitted callback called');
              _loadAttendanceData();
            },
          );
        },
      ).then((value) {
        print('🔵 Modal closed with value: $value');
      }).catchError((error) {
        print('❌ Error showing modal: $error');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error membuka form: $error'),
              backgroundColor: Colors.red,
            ),
          );
        }
      });
    } catch (e, stackTrace) {
      print('❌ Exception in _showLeaveRequestModal: $e');
      print('❌ Stack trace: $stackTrace');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error membuka form: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }


  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'My Attendance',
      body: _isLoading
          ? Center(child: AppLoadingIndicator())
          : RefreshIndicator(
              onRefresh: _loadAttendanceData,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Filter Section
                    _buildFilterSection(),
                    const SizedBox(height: 16),
                    
                    // Summary Cards
                    _buildSummarySection(),
                    const SizedBox(height: 16),
                    
                    // Calendar
                    _buildCalendarSection(),
                    const SizedBox(height: 16),
                    
                    // Leave Requests
                    _buildLeaveRequestsSection(),
                    const SizedBox(height: 16),
                    
                    // PH & Extra Off
                    _buildPHAndExtraOffSection(),
                    const SizedBox(height: 16),
                    
                    // Correction Requests
                    if (_correctionRequests.isNotEmpty)
                      _buildCorrectionRequestsSection(),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildFilterSection() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.purple.shade50, Colors.blue.shade50],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.purple.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.7),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.calendar_month, color: Colors.purple),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Periode',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: DropdownButton<int>(
                          value: _selectedMonth,
                          underline: const SizedBox(),
                          isDense: true,
                          items: List.generate(12, (index) {
                            final month = index + 1;
                            return DropdownMenuItem(
                              value: month,
                              child: Text(
                                _getMonthName(month),
                                style: const TextStyle(fontSize: 14),
                              ),
                            );
                          }),
                          onChanged: (value) {
                            if (value != null) {
                              setState(() {
                                _selectedMonth = value;
                              });
                              _loadAttendanceData();
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: DropdownButton<int>(
                          value: _selectedYear,
                          underline: const SizedBox(),
                          isDense: true,
                          items: List.generate(5, (index) {
                            final year = DateTime.now().year - 2 + index;
                            return DropdownMenuItem(
                              value: year,
                              child: Text(
                                year.toString(),
                                style: const TextStyle(fontSize: 14),
                              ),
                            );
                          }),
                          onChanged: (value) {
                            if (value != null) {
                              setState(() {
                                _selectedYear = value;
                              });
                              _loadAttendanceData();
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Material(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              child: InkWell(
                onTap: () {
                  final now = DateTime.now();
                  setState(() {
                    _selectedMonth = now.month;
                    _selectedYear = now.year;
                  });
                  _loadAttendanceData();
                },
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.all(10),
                  child: Icon(Icons.refresh, color: Colors.purple.shade700),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getMonthName(int month) {
    const months = [
      'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni',
      'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember'
    ];
    return months[month - 1];
  }

  Widget _buildSummarySection() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.purple.shade400, Colors.blue.shade400],
                    ),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.analytics, color: Colors.white, size: 20),
                ),
                const SizedBox(width: 12),
                const Text(
                  'Ringkasan Kehadiran',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Row 1: Hadir, Terlambat, Tidak Hadir
            Row(
              children: [
                Expanded(
                  child: _buildSummaryCard(
                    'Hadir',
                    '${_summary['present_days'] ?? 0}',
                    'Hari',
                    Colors.green,
                    Icons.check_circle,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildSummaryCard(
                    'Terlambat',
                    '${_summary['total_late_minutes'] ?? 0}',
                    'Menit',
                    Colors.orange,
                    Icons.access_time,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildSummaryCard(
                    'Tidak Hadir',
                    '${_summary['absent_days'] ?? 0}',
                    'Hari',
                    Colors.red,
                    Icons.cancel,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            // Row 2: Lembur, Persentase
            Row(
              children: [
                Expanded(
                  child: _buildSummaryCard(
                    'Lembur',
                    '${_summary['total_lembur_hours'] ?? 0}',
                    'Jam',
                    Colors.blue,
                    Icons.hourglass_empty,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildSummaryCard(
                    'Persentase',
                    '${(_summary['percentage'] ?? 0).toStringAsFixed(1)}',
                    '%',
                    Colors.purple,
                    Icons.percent,
                  ),
                ),
                const Spacer(),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCard(
    String title,
    String value,
    String unit,
    Color color,
    IconData icon,
  ) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            color.withOpacity(0.15),
            color.withOpacity(0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: color.withOpacity(0.2),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(height: 10),
            Text(
              title,
              style: TextStyle(
                fontSize: 11,
                color: Colors.grey[700],
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 6),
            Text(
              value,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: color,
                height: 1.2,
              ),
            ),
            Text(
              unit,
              style: TextStyle(
                fontSize: 10,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCalendarSection() {
    // Get only days in payroll period
    final startDate = _getStartDate();
    final endDate = _getEndDate();
    final payrollDays = <Map<String, dynamic>>[];
    
    print('📅 Building calendar section');
    print('📅 Period: ${DateFormat('yyyy-MM-dd').format(startDate)} to ${DateFormat('yyyy-MM-dd').format(endDate)}');
    print('📅 Calendar data keys: ${_calendarData.length}');
    if (_calendarData.isNotEmpty) {
      print('📅 First 5 calendar keys: ${_calendarData.keys.take(5).toList()}');
    }
    
    for (var date = startDate; !date.isAfter(endDate); date = date.add(const Duration(days: 1))) {
      final dateStr = DateFormat('yyyy-MM-dd').format(date);
      
      // Get schedules for this date
      List<dynamic> schedules = [];
      if (_calendarData.containsKey(dateStr)) {
        final dateData = _calendarData[dateStr];
        if (dateData is List) {
          schedules = dateData;
        } else {
          schedules = [dateData];
        }
        print('📅 Found ${schedules.length} schedules for $dateStr');
      }
      
      // Find holiday
      final holidayIndex = _holidays.indexWhere((h) => h['date'] == dateStr);
      final holiday = holidayIndex >= 0 ? _holidays[holidayIndex] : null;
      
      // Find approved leave/absent for this date
      Map<String, dynamic>? approvedLeave;
      final currentDate = DateTime.parse(dateStr);
      for (var absent in _approvedAbsents) {
        final dateFrom = absent['date_from'] as String?;
        final dateTo = absent['date_to'] as String?;
        if (dateFrom != null && dateTo != null) {
          final fromDate = DateTime.parse(dateFrom);
          final toDate = DateTime.parse(dateTo);
          // Check if current date is within the leave period (inclusive)
          // Compare only the date part (year, month, day) ignoring time
          final currentDateOnly = DateTime(currentDate.year, currentDate.month, currentDate.day);
          final fromDateOnly = DateTime(fromDate.year, fromDate.month, fromDate.day);
          final toDateOnly = DateTime(toDate.year, toDate.month, toDate.day);
          
          if (currentDateOnly.isAtSameMomentAs(fromDateOnly) ||
              currentDateOnly.isAtSameMomentAs(toDateOnly) ||
              (currentDateOnly.isAfter(fromDateOnly) && currentDateOnly.isBefore(toDateOnly))) {
            approvedLeave = absent;
            break;
          }
        }
      }
      
      payrollDays.add({
        'date': dateStr,
        'day': date.day,
        'schedules': schedules,
        'holiday': holiday,
        'approvedLeave': approvedLeave,
        'isToday': dateStr == DateFormat('yyyy-MM-dd').format(DateTime.now()),
      });
    }
    
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.blue.shade400, Colors.cyan.shade400],
                    ),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.calendar_today, color: Colors.white, size: 20),
                ),
                const SizedBox(width: 12),
                const Text(
                  'Jadwal Kerja & Attendance',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            // List view instead of grid to prevent overflow
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: payrollDays.length,
              itemBuilder: (context, index) {
                final day = payrollDays[index];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _buildDayCard(day),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDayCard(Map<String, dynamic> day) {
    final dateStr = day['date'] as String;
    final dayNumber = day['day'] as int;
    final isToday = day['isToday'] as bool;
    final holiday = day['holiday'] as Map<String, dynamic>?;
    final approvedLeave = day['approvedLeave'] as Map<String, dynamic>?;
    final schedulesList = day['schedules'];
    final schedules = schedulesList is List ? schedulesList : (schedulesList != null ? [schedulesList] : []);
    
    // Get day name
    final date = DateTime.parse(dateStr);
    final dayName = DateFormat('EEEE', 'id_ID').format(date);
    
    // Determine if this date has approved leave
    final hasApprovedLeave = approvedLeave != null;
    
    return Container(
      decoration: BoxDecoration(
        gradient: isToday
            ? LinearGradient(
                colors: [Colors.blue.shade50, Colors.blue.shade100],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : holiday != null
                ? LinearGradient(
                    colors: [Colors.red.shade50, Colors.red.shade100],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                : hasApprovedLeave
                    ? LinearGradient(
                        colors: [Colors.purple.shade50, Colors.purple.shade100],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      )
                    : LinearGradient(
                        colors: [Colors.white, Colors.grey.shade50],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
        border: Border.all(
          color: isToday
              ? Colors.blue.shade300
              : holiday != null
                  ? Colors.red.shade300
                  : hasApprovedLeave
                      ? Colors.purple.shade300
                      : Colors.grey.shade200,
          width: isToday || holiday != null || hasApprovedLeave ? 2 : 1,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: (isToday 
                ? Colors.blue 
                : holiday != null 
                    ? Colors.red 
                    : hasApprovedLeave
                        ? Colors.purple
                        : Colors.grey)
                .withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Date header
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    gradient: isToday
                        ? LinearGradient(
                            colors: [Colors.blue.shade400, Colors.blue.shade600],
                          )
                        : holiday != null
                            ? LinearGradient(
                                colors: [Colors.red.shade400, Colors.red.shade600],
                              )
                            : hasApprovedLeave
                                ? LinearGradient(
                                    colors: [Colors.purple.shade400, Colors.purple.shade600],
                                  )
                                : LinearGradient(
                                    colors: [Colors.grey.shade300, Colors.grey.shade400],
                                  ),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: (isToday 
                            ? Colors.blue 
                            : holiday != null 
                                ? Colors.red 
                                : hasApprovedLeave
                                    ? Colors.purple
                                    : Colors.grey)
                            .withOpacity(0.3),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Text(
                      '$dayNumber',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      dayName,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: isToday ? Colors.blue[900] : Colors.black87,
                      ),
                    ),
                    Text(
                      DateFormat('dd MMMM yyyy', 'id_ID').format(date),
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                    if (holiday != null)
                      Container(
                        margin: const EdgeInsets.only(top: 4),
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.red[100],
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          holiday['name'] ?? 'Hari Libur',
                          style: const TextStyle(
                            fontSize: 11,
                            color: Colors.red,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    if (hasApprovedLeave)
                      Container(
                        margin: const EdgeInsets.only(top: 4),
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.purple[100],
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.event_available, size: 12, color: Colors.purple[700]),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                approvedLeave!['leave_type_name'] ?? 'Izin/Cuti',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.purple[700],
                                  fontWeight: FontWeight.bold,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              ],
            ),
          // Schedules
          if (schedules.isNotEmpty) ...[
            const SizedBox(height: 12),
            const Divider(),
            const SizedBox(height: 8),
            ...schedules.map((schedule) {
              // Ensure schedule is a Map
              final scheduleMap = schedule is Map<String, dynamic> 
                  ? schedule 
                  : Map<String, dynamic>.from(schedule as Map);
              return _buildScheduleCard(scheduleMap);
            }).toList(),
          ] else ...[
            const SizedBox(height: 12),
            const Divider(),
            const SizedBox(height: 8),
            if (hasApprovedLeave)
              Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.purple.shade50, Colors.purple.shade100],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  border: Border.all(
                    color: Colors.purple.shade300,
                    width: 1.5,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.event_available, size: 18, color: Colors.purple[700]),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            approvedLeave!['leave_type_name'] ?? 'Izin/Cuti',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Colors.purple[700],
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (approvedLeave['reason'] != null && approvedLeave['reason'].toString().isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        approvedLeave['reason'],
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.purple[600],
                        ),
                      ),
                    ],
                  ],
                ),
              )
            else
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.event_busy, size: 20, color: Colors.grey[600]),
                    const SizedBox(width: 8),
                    Text(
                      'Tidak ada jadwal',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ],
      ),
      ),
    );
  }

  Widget _buildScheduleCard(Map<String, dynamic> schedule) {
    final shiftName = schedule['shift_name'] ?? 'OFF';
    final hasAttendance = schedule['has_attendance'] ?? false;
    final firstIn = schedule['first_in'] ?? schedule['check_in_time'];
    final lastOut = schedule['last_out'] ?? schedule['check_out_time'];
    final telat = schedule['telat'] ?? 0;
    final lembur = schedule['lembur'] ?? 0;
    final timeStart = schedule['time_start'] ?? schedule['start_time'];
    final timeEnd = schedule['time_end'] ?? schedule['end_time'];
    final hasNoCheckout = schedule['has_no_checkout'] ?? false;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        gradient: hasAttendance
            ? LinearGradient(
                colors: [Colors.green.shade50, Colors.green.shade100],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : LinearGradient(
                colors: [Colors.grey.shade50, Colors.grey.shade100],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
        border: Border.all(
          color: hasAttendance ? Colors.green.shade300 : Colors.grey.shade300,
          width: 1.5,
        ),
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: (hasAttendance ? Colors.green : Colors.grey).withOpacity(0.1),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Shift name and time
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    gradient: hasAttendance
                        ? LinearGradient(
                            colors: [Colors.green.shade600, Colors.green.shade800],
                          )
                        : LinearGradient(
                            colors: [Colors.grey.shade500, Colors.grey.shade700],
                          ),
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: [
                      BoxShadow(
                        color: (hasAttendance ? Colors.green : Colors.grey).withOpacity(0.3),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Text(
                    shiftName,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              const SizedBox(width: 8),
              if (timeStart != null && timeEnd != null)
                Text(
                  '$timeStart - $timeEnd',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
            // Attendance info
          if (hasAttendance) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.check_circle, size: 16, color: Colors.green[700]),
                const SizedBox(width: 4),
                const Text(
                  'Hadir',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.green,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (firstIn != null || lastOut != null)
              Row(
                children: [
                  if (firstIn != null) ...[
                    Icon(Icons.login, size: 14, color: Colors.blue[700]),
                    const SizedBox(width: 4),
                    Text(
                      'Masuk: ${firstIn is String ? firstIn : firstIn.toString().substring(0, 5)}',
                      style: TextStyle(fontSize: 11, color: Colors.grey[700]),
                    ),
                  ],
                  if (lastOut != null) ...[
                    const SizedBox(width: 16),
                    Icon(Icons.logout, size: 14, color: Colors.red[700]),
                    const SizedBox(width: 4),
                    Text(
                      'Keluar: ${lastOut is String ? lastOut : lastOut.toString().substring(0, 5)}',
                      style: TextStyle(fontSize: 11, color: Colors.grey[700]),
                    ),
                  ],
                  if (hasNoCheckout) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.red[100],
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        '⚠️ No Checkout',
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.red,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            if (telat > 0 || lembur > 0) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  if (telat > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.orange[100],
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.access_time, size: 12, color: Colors.orange[900]),
                          const SizedBox(width: 4),
                          Text(
                            'Telat: $telat menit',
                            style: TextStyle(fontSize: 10, color: Colors.orange[900]),
                          ),
                        ],
                      ),
                    ),
                  if (lembur > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.blue[100],
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.hourglass_empty, size: 12, color: Colors.blue[900]),
                          const SizedBox(width: 4),
                          Text(
                            'Lembur: $lembur jam',
                            style: TextStyle(fontSize: 10, color: Colors.blue[900]),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ],
          ] else ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.cancel, size: 16, color: Colors.grey[600]),
                const SizedBox(width: 4),
                Text(
                  'Tidak hadir',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
      ),
    );
  }

  Widget _buildLeaveRequestsSection() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.purple.shade400, Colors.pink.shade400],
                    ),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.calendar_today, color: Colors.white, size: 20),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Permohonan Izin/Cuti',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: () {
                    if (_leaveTypes.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Sedang memuat data jenis izin/cuti. Silakan tunggu sebentar.'),
                          backgroundColor: Colors.orange,
                        ),
                      );
                      return;
                    }
                    _showLeaveRequestModal(context);
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.purple.shade600, Colors.purple.shade800],
                      ),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.purple.withOpacity(0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.add, color: Colors.white, size: 18),
                        SizedBox(width: 6),
                        Text(
                          'Ajukan',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (_userLeaveRequests.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: Text('Tidak ada permohonan izin/cuti'),
                ),
              )
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _userLeaveRequests.length,
                itemBuilder: (context, index) {
                  final request = _userLeaveRequests[index];
                  return _buildLeaveRequestCard(request);
                },
              ),
          ],
        ),
      ),
    );
  }

  bool _canCancelRequest(Map<String, dynamic> request) {
    final status = request['status'] ?? 'pending';
    
    // Can cancel if status is pending, supervisor_approved, or approved
    if (!['pending', 'supervisor_approved', 'approved'].contains(status)) {
      return false;
    }
    
    // Check if date_from has not passed (can cancel until the day of the leave)
    final dateFromStr = request['date_from'] as String?;
    if (dateFromStr == null) return false;
    
    try {
      final startDate = DateTime.parse(dateFromStr);
      final today = DateTime.now();
      
      // Set to start of day for comparison
      final startDateOnly = DateTime(startDate.year, startDate.month, startDate.day);
      final todayOnly = DateTime(today.year, today.month, today.day);
      
      // Can cancel if start date is today or in the future
      return startDateOnly.isAfter(todayOnly) || startDateOnly.isAtSameMomentAs(todayOnly);
    } catch (e) {
      return false;
    }
  }

  String _getStatusText(String status) {
    switch (status) {
      case 'pending':
        return 'Menunggu';
      case 'supervisor_approved':
        return 'Disetujui Atasan';
      case 'approved':
        return 'Disetujui';
      case 'rejected':
        return 'Ditolak';
      case 'cancelled':
        return 'Dibatalkan';
      default:
        return status.toUpperCase();
    }
  }

  Widget _buildLeaveRequestCard(Map<String, dynamic> request) {
    final status = request['status'] ?? 'pending';
    final pendingApprover = request['pending_approver'] as String?;
    final canCancel = _canCancelRequest(request);
    final leaveTypeName = request['leave_type_name'] ?? '';
    final dateFrom = request['date_from'] ?? '';
    final dateTo = request['date_to'] ?? '';
    final reason = request['reason'] ?? '';
    
    // Determine colors based on status
    MaterialColor statusColor;
    Color gradientStart;
    Color gradientEnd;
    IconData statusIcon;
    
    if (status == 'supervisor_approved' || status == 'approved') {
      statusColor = Colors.green;
      gradientStart = Colors.green.shade50;
      gradientEnd = Colors.green.shade100;
      statusIcon = Icons.check_circle;
    } else if (status == 'rejected' || status == 'cancelled') {
      statusColor = Colors.red;
      gradientStart = Colors.red.shade50;
      gradientEnd = Colors.red.shade100;
      statusIcon = Icons.cancel;
    } else {
      statusColor = Colors.orange;
      gradientStart = Colors.orange.shade50;
      gradientEnd = Colors.orange.shade100;
      statusIcon = Icons.pending;
    }
    
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [gradientStart, gradientEnd],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: statusColor.withOpacity(0.3),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: statusColor.withOpacity(0.2),
            blurRadius: 12,
            offset: const Offset(0, 4),
            spreadRadius: 0,
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with icon and status
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: statusColor.withOpacity(0.4),
                      width: 1.5,
                    ),
                  ),
                  child: Icon(
                    Icons.event_note,
                    color: statusColor.shade700,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        leaveTypeName,
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: statusColor.shade900,
                          letterSpacing: 0.3,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            Icons.calendar_today,
                            size: 14,
                            color: Colors.grey[700],
                          ),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              '$dateFrom - $dateTo',
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey[700],
                                fontWeight: FontWeight.w500,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [statusColor.shade600, statusColor.shade800],
                      ),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: statusColor.withOpacity(0.4),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          statusIcon,
                          size: 14,
                          color: Colors.white,
                        ),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            _getStatusText(status),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                            ),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            
            // Reason section
            if (reason.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.7),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.5),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.description,
                      size: 16,
                      color: Colors.grey[700],
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        reason,
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey[800],
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            
            // Pending Approver Info
            if (pendingApprover != null && (status == 'pending' || status == 'supervisor_approved')) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: pendingApprover == 'HRD'
                        ? [Colors.blue.shade100, Colors.blue.shade200]
                        : [Colors.orange.shade100, Colors.orange.shade200],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: (pendingApprover == 'HRD' ? Colors.blue : Colors.orange).shade300,
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: (pendingApprover == 'HRD' ? Colors.blue : Colors.orange).withOpacity(0.2),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: (pendingApprover == 'HRD' ? Colors.blue : Colors.orange).shade700,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.access_time,
                        size: 16,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Menunggu Persetujuan',
                            style: TextStyle(
                              fontSize: 11,
                              color: (pendingApprover == 'HRD' ? Colors.blue : Colors.orange).shade900,
                              fontWeight: FontWeight.w600,
                            ),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            pendingApprover == 'HRD' ? 'HRD' : pendingApprover,
                            style: TextStyle(
                              fontSize: 13,
                              color: (pendingApprover == 'HRD' ? Colors.blue : Colors.orange).shade900,
                              fontWeight: FontWeight.bold,
                            ),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
            
            // Cancel Button
            if (canCancel) ...[
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.red.shade600, Colors.red.shade800],
                    ),
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.red.withOpacity(0.3),
                        blurRadius: 6,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () => _showCancelDialog(request),
                      borderRadius: BorderRadius.circular(10),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: const [
                            Icon(
                              Icons.cancel_outlined,
                              color: Colors.white,
                              size: 18,
                            ),
                            SizedBox(width: 6),
                            Text(
                              'Batalkan',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 13,
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
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _showCancelDialog(Map<String, dynamic> request) async {
    final reasonController = TextEditingController();
    
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Batalkan Permohonan Izin/Cuti'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Jenis: ${request['leave_type_name'] ?? ''}',
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Periode: ${request['date_from']} - ${request['date_to']}',
                      style: const TextStyle(fontSize: 13),
                    ),
                    if (request['reason'] != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Alasan: ${request['reason']}',
                        style: const TextStyle(fontSize: 13),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Alasan Pembatalan (Opsional)',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: reasonController,
                decoration: const InputDecoration(
                  hintText: 'Masukkan alasan pembatalan (opsional)',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Ya, Batalkan'),
          ),
        ],
      ),
    );

    if (result == true) {
      await _cancelLeaveRequest(request['id'] as int, reasonController.text);
    }
  }

  Future<void> _cancelLeaveRequest(int requestId, String reason) async {
    try {
      final result = await _attendanceService.cancelLeaveRequest(
        id: requestId,
        reason: reason.isEmpty ? null : reason,
      );

      if (mounted) {
        if (result['success'] == true) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Permohonan izin/cuti berhasil dibatalkan'),
              backgroundColor: Colors.green,
            ),
          );
          // Reload data
          _loadAttendanceData();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result['message'] ?? 'Gagal membatalkan permohonan'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Widget _buildPHAndExtraOffSection() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.star, color: Colors.blue, size: 20),
                          const SizedBox(width: 6),
                          const Flexible(
                            child: Text(
                              'Public Holiday (PH)',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildStatItem(
                            'Total Hari',
                            '${_phData?['total_days'] ?? 0}',
                            Colors.blue,
                          ),
                          const SizedBox(height: 8),
                          _buildStatItem(
                            'Total Bonus',
                            'Rp ${NumberFormat('#,###').format(_phData?['total_bonus'] ?? 0)}',
                            Colors.green,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.event, color: Colors.purple, size: 20),
                          const SizedBox(width: 6),
                          const Flexible(
                            child: Text(
                              'Extra Off',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildStatItem(
                            'Saldo',
                            '${_extraOffData?['current_balance'] ?? 0}',
                            Colors.purple,
                          ),
                          const SizedBox(height: 8),
                          _buildStatItem(
                            'Net Bulan Ini',
                            '${_extraOffData?['period_net'] ?? 0}',
                            Colors.orange,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    const Icon(Icons.beach_access, color: Colors.teal, size: 20),
                    const SizedBox(width: 6),
                    const Flexible(
                      child: Text(
                        'Saldo Cuti',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _buildStatItem(
                  'Saldo',
                  '${_userData?['cuti'] ?? 0}',
                  Colors.teal,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStatItem(String label, String value, Color color) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: color,
                  height: 1.2,
                ),
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCorrectionRequestsSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.edit, color: Colors.blue),
                const SizedBox(width: 8),
                const Text(
                  'Status Pengajuan Koreksi',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _correctionRequests.length,
              itemBuilder: (context, index) {
                final request = _correctionRequests[index];
                return _buildCorrectionRequestCard(request);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCorrectionRequestCard(Map<String, dynamic> request) {
    final status = request['status'] ?? 'pending';
    Color statusColor = Colors.orange;
    if (status == 'approved') {
      statusColor = Colors.green;
    } else if (status == 'rejected') {
      statusColor = Colors.red;
    }
    
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        title: Text('${request['type']} - ${request['tanggal']}'),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Sebelum: ${request['old_value']}'),
            Text('Sesudah: ${request['new_value']}'),
            Text('Alasan: ${request['reason']}'),
          ],
        ),
        trailing: Chip(
          label: Text(status.toUpperCase()),
          backgroundColor: statusColor,
          labelStyle: const TextStyle(color: Colors.white, fontSize: 10),
        ),
      ),
    );
  }
}


