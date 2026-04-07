import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import '../../services/activity_log_service.dart';
import '../../models/activity_log_models.dart';
import '../../widgets/app_footer.dart';
import '../../widgets/app_loading_indicator.dart';
import 'activity_log_detail_screen.dart';

class ActivityLogReportScreen extends StatefulWidget {
  const ActivityLogReportScreen({super.key});

  @override
  State<ActivityLogReportScreen> createState() => _ActivityLogReportScreenState();
}

class _ActivityLogReportScreenState extends State<ActivityLogReportScreen> {
  final ActivityLogService _service = ActivityLogService();
  ActivityLogPagination? _pagination;
  List<ActivityLog> _logs = [];
  List<Map<String, dynamic>> _users = [];
  List<String> _activityTypes = [];
  List<String> _modules = [];
  
  bool _isLoading = true;
  bool _isRefreshing = false;
  String? _errorMessage;
  
  // Filters
  final TextEditingController _searchController = TextEditingController();
  int? _selectedUserId;
  String? _selectedActivityType;
  String? _selectedModule;
  String? _dateFrom;
  String? _dateTo;
  int _perPage = 25;
  int _currentPage = 1;
  
  Timer? _searchDebounce;
  bool _showFilters = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
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
      final result = await _service.getActivityLogs(
        search: _searchController.text.isNotEmpty ? _searchController.text : null,
        userId: _selectedUserId,
        activityType: _selectedActivityType,
        module: _selectedModule,
        dateFrom: _dateFrom,
        dateTo: _dateTo,
        perPage: _perPage,
        page: _currentPage,
      );

      if (result['success'] == true && mounted) {
        final data = result['data'];
        print('Activity Log - Result success: ${result['success']}');
        print('Activity Log - Data type: ${data.runtimeType}');
        print('Activity Log - Data keys: ${data is Map ? (data as Map).keys.toList() : 'Not a Map'}');
        
        if (data != null && data is Map) {
          // Handle logsData - Laravel pagination object
          dynamic logsData = data['logs'];
          print('Activity Log - Logs Data Type: ${logsData.runtimeType}');
          print('Activity Log - Logs Data is null: ${logsData == null}');
          
          Map<String, dynamic>? logsDataMap;
          
          if (logsData == null) {
            print('Activity Log - logsData is null, checking if data has direct pagination fields');
            // Maybe logs data is directly in data, not nested
            if (data.containsKey('current_page') || data.containsKey('data')) {
              logsDataMap = data as Map<String, dynamic>;
              print('Activity Log - Using data directly as pagination');
            } else {
              print('Activity Log - No logs data found in response');
              logsDataMap = null;
            }
          } else if (logsData is Map<String, dynamic>) {
            logsDataMap = logsData;
            print('Activity Log - logsData is Map with keys: ${logsData.keys.toList()}');
          } else if (logsData is String) {
            try {
              logsDataMap = jsonDecode(logsData) as Map<String, dynamic>?;
              print('Activity Log - Parsed logsData from String');
            } catch (e) {
              print('Error parsing logsData as JSON: $e');
              logsDataMap = null;
            }
          } else if (logsData != null) {
            // Try to convert to Map
            try {
              logsDataMap = Map<String, dynamic>.from(logsData);
              print('Activity Log - Converted logsData to Map');
            } catch (e) {
              print('Error converting logsData to Map: $e');
              logsDataMap = null;
            }
          }

          // Handle users - could be List or Collection
          List<dynamic> usersData = [];
          if (data['users'] != null) {
            if (data['users'] is List) {
              usersData = data['users'] as List<dynamic>;
            } else {
              try {
                usersData = List<dynamic>.from(data['users']);
              } catch (e) {
                print('Error converting users to List: $e');
                usersData = [];
              }
            }
          }

          // Handle activityTypes - could be List or Collection
          List<dynamic> activityTypesData = [];
          if (data['activityTypes'] != null) {
            if (data['activityTypes'] is List) {
              activityTypesData = data['activityTypes'] as List<dynamic>;
            } else {
              try {
                activityTypesData = List<dynamic>.from(data['activityTypes']);
              } catch (e) {
                print('Error converting activityTypes to List: $e');
                activityTypesData = [];
              }
            }
          }

          // Handle modules - could be List or Collection
          List<dynamic> modulesData = [];
          if (data['modules'] != null) {
            if (data['modules'] is List) {
              modulesData = data['modules'] as List<dynamic>;
            } else {
              try {
                modulesData = List<dynamic>.from(data['modules']);
              } catch (e) {
                print('Error converting modules to List: $e');
                modulesData = [];
              }
            }
          }

          setState(() {
            if (logsDataMap != null) {
              try {
                print('Activity Log - Creating pagination from: ${logsDataMap.keys.toList()}');
                _pagination = ActivityLogPagination.fromJson(logsDataMap);
                _logs = _pagination?.data ?? [];
                print('Activity Log - Parsed ${_logs.length} logs');
                if (_logs.isNotEmpty) {
                  print('Activity Log - First log: ${_logs.first.id} - ${_logs.first.description}');
                }
              } catch (e, stackTrace) {
                print('Error creating ActivityLogPagination: $e');
                print('Stack trace: $stackTrace');
                _pagination = null;
                _logs = [];
              }
            } else {
              print('Activity Log - logsDataMap is null');
              _pagination = null;
              _logs = [];
            }
            
            _users = usersData.map((u) {
              if (u is Map<String, dynamic>) {
                return {
                  'id': u['id'],
                  'nama_lengkap': u['nama_lengkap'] ?? u['name'] ?? '',
                };
              }
              return {'id': null, 'nama_lengkap': ''};
            }).toList();
            
            _activityTypes = activityTypesData.map((t) => t.toString()).toList();
            _modules = modulesData.map((m) => m.toString()).toList();
            _errorMessage = null;
          });
        }
      } else if (mounted) {
        final errorMsg = result['message'] ?? 'Failed to load activity logs';
        print('Activity Log - Error: $errorMsg');
        setState(() {
          _errorMessage = errorMsg;
        });
      }
    } catch (e, stackTrace) {
      print('Activity Log - Exception: $e');
      print('Activity Log - Stack trace: $stackTrace');
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

  void _onSearchChanged(String value) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 500), () {
      setState(() {
        _currentPage = 1;
      });
      _loadData();
    });
  }

  void _applyFilters() {
    setState(() {
      _currentPage = 1;
      _showFilters = false;
    });
    _loadData();
  }

  void _resetFilters() {
    setState(() {
      _searchController.clear();
      _selectedUserId = null;
      _selectedActivityType = null;
      _selectedModule = null;
      _dateFrom = null;
      _dateTo = null;
      _perPage = 25;
      _currentPage = 1;
      _showFilters = false;
    });
    _loadData();
  }

  Color _getActivityTypeColor(String type) {
    switch (type.toLowerCase()) {
      case 'create':
        return Colors.green;
      case 'update':
        return Colors.blue;
      case 'delete':
        return Colors.red;
      case 'approve':
        return Colors.orange;
      case 'reject':
        return Colors.deepOrange;
      case 'login':
        return Colors.purple;
      case 'logout':
        return Colors.grey;
      default:
        return Colors.grey;
    }
  }

  String _formatDateTime(String dateTime) {
    if (dateTime.isEmpty) return '-';
    try {
      final date = DateTime.parse(dateTime);
      return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}:${date.second.toString().padLeft(2, '0')}';
    } catch (e) {
      return dateTime;
    }
  }

  Widget _buildSummaryCard(String title, String value, IconData icon, Color color) {
    return Card(
      elevation: 2,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border(left: BorderSide(color: color, width: 4)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    value,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey.shade800,
                    ),
                  ),
                ],
              ),
            ),
            Icon(icon, color: color, size: 32),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Activity Log Report'),
        backgroundColor: Colors.blue.shade700,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: Icon(_showFilters ? Icons.filter_list : Icons.filter_list_off),
            onPressed: () {
              setState(() {
                _showFilters = !_showFilters;
              });
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Search Bar
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.white,
            child: TextField(
              controller: _searchController,
              onChanged: _onSearchChanged,
              decoration: InputDecoration(
                hintText: 'Search (Description, Module, User, IP)...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: Colors.grey.shade50,
              ),
            ),
          ),
          // Filters
          if (_showFilters)
            Container(
              padding: const EdgeInsets.all(16),
              color: Colors.grey.shade50,
              child: Column(
                children: [
                  // User Filter
                  DropdownButtonFormField<int?>(
                    value: _selectedUserId,
                    decoration: InputDecoration(
                      labelText: 'User',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      filled: true,
                      fillColor: Colors.white,
                    ),
                    items: [
                      const DropdownMenuItem<int?>(value: null, child: Text('All Users')),
                      ..._users.map((user) => DropdownMenuItem<int?>(
                            value: user['id'] as int,
                            child: Text(user['nama_lengkap'] as String),
                          )),
                    ],
                    onChanged: (value) {
                      setState(() {
                        _selectedUserId = value;
                      });
                    },
                  ),
                  const SizedBox(height: 12),
                  // Activity Type Filter
                  DropdownButtonFormField<String?>(
                    value: _selectedActivityType,
                    decoration: InputDecoration(
                      labelText: 'Activity Type',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      filled: true,
                      fillColor: Colors.white,
                    ),
                    items: [
                      const DropdownMenuItem<String?>(value: null, child: Text('All Types')),
                      ..._activityTypes.map((type) => DropdownMenuItem<String?>(
                            value: type,
                            child: Text(type),
                          )),
                    ],
                    onChanged: (value) {
                      setState(() {
                        _selectedActivityType = value;
                      });
                    },
                  ),
                  const SizedBox(height: 12),
                  // Module Filter
                  DropdownButtonFormField<String?>(
                    value: _selectedModule,
                    decoration: InputDecoration(
                      labelText: 'Module',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      filled: true,
                      fillColor: Colors.white,
                    ),
                    items: [
                      const DropdownMenuItem<String?>(value: null, child: Text('All Modules')),
                      ..._modules.map((module) => DropdownMenuItem<String?>(
                            value: module,
                            child: Text(module),
                          )),
                    ],
                    onChanged: (value) {
                      setState(() {
                        _selectedModule = value;
                      });
                    },
                  ),
                  const SizedBox(height: 12),
                  // Date Range
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: TextEditingController(text: _dateFrom),
                          decoration: InputDecoration(
                            labelText: 'Date From',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            filled: true,
                            fillColor: Colors.white,
                            suffixIcon: const Icon(Icons.calendar_today),
                          ),
                          readOnly: true,
                          onTap: () async {
                            final date = await showDatePicker(
                              context: context,
                              initialDate: DateTime.now(),
                              firstDate: DateTime(2020),
                              lastDate: DateTime.now(),
                            );
                            if (date != null) {
                              setState(() {
                                _dateFrom = date.toIso8601String().split('T')[0];
                              });
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: TextEditingController(text: _dateTo),
                          decoration: InputDecoration(
                            labelText: 'Date To',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            filled: true,
                            fillColor: Colors.white,
                            suffixIcon: const Icon(Icons.calendar_today),
                          ),
                          readOnly: true,
                          onTap: () async {
                            final date = await showDatePicker(
                              context: context,
                              initialDate: DateTime.now(),
                              firstDate: DateTime(2020),
                              lastDate: DateTime.now(),
                            );
                            if (date != null) {
                              setState(() {
                                _dateTo = date.toIso8601String().split('T')[0];
                              });
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Per Page
                  DropdownButtonFormField<int>(
                    value: _perPage,
                    decoration: InputDecoration(
                      labelText: 'Per Page',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      filled: true,
                      fillColor: Colors.white,
                    ),
                    items: const [
                      DropdownMenuItem<int>(value: 10, child: Text('10')),
                      DropdownMenuItem<int>(value: 25, child: Text('25')),
                      DropdownMenuItem<int>(value: 50, child: Text('50')),
                      DropdownMenuItem<int>(value: 100, child: Text('100')),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        setState(() {
                          _perPage = value;
                          _currentPage = 1;
                        });
                        _loadData();
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                  // Action Buttons
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _resetFilters,
                          icon: const Icon(Icons.refresh),
                          label: const Text('Reset'),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: ElevatedButton.icon(
                          onPressed: _applyFilters,
                          icon: const Icon(Icons.search),
                          label: const Text('Apply Filters'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue.shade700,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          // Error Banner
          if (_errorMessage != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              color: Colors.red.shade50,
              child: Row(
                children: [
                  Icon(Icons.error, color: Colors.red.shade700),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _errorMessage!,
                      style: TextStyle(color: Colors.red.shade700),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () {
                      setState(() {
                        _errorMessage = null;
                      });
                    },
                  ),
                ],
              ),
            ),
          // Summary Cards
          if (!_isLoading && _pagination != null)
            Container(
              padding: const EdgeInsets.all(16),
              color: Colors.white,
              child: Row(
                children: [
                  Expanded(
                    child: _buildSummaryCard(
                      'Total Logs',
                      '${_pagination!.total}',
                      Icons.list_alt,
                      Colors.blue,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildSummaryCard(
                      'Showing',
                      '${_pagination!.from}-${_pagination!.to}',
                      Icons.visibility,
                      Colors.green,
                    ),
                  ),
                ],
              ),
            ),
          // Content
          Expanded(
            child: _isLoading
                ? Center(child: AppLoadingIndicator())
                : RefreshIndicator(
                    onRefresh: () => _loadData(refresh: true),
                    child: _logs.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.inbox,
                                  size: 64,
                                  color: Colors.grey.shade400,
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'No activity logs found',
                                  style: TextStyle(color: Colors.grey.shade600),
                                ),
                              ],
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                            itemCount: _logs.length,
                            itemBuilder: (context, index) {
                              final log = _logs[index];
                              return TweenAnimationBuilder<double>(
                                tween: Tween(begin: 0.0, end: 1.0),
                                duration: Duration(milliseconds: 300 + (index * 50)),
                                builder: (context, value, child) {
                                  return Opacity(
                                    opacity: value,
                                    child: Transform.translate(
                                      offset: Offset(0, 20 * (1 - value)),
                                      child: child,
                                    ),
                                  );
                                },
                                child: Card(
                                  margin: const EdgeInsets.only(bottom: 12),
                                  elevation: 2,
                                  child: InkWell(
                                    onTap: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) => ActivityLogDetailScreen(log: log),
                                        ),
                                      );
                                    },
                                    child: Padding(
                                      padding: const EdgeInsets.all(12),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Expanded(
                                                child: Text(
                                                  log.description ?? '-',
                                                  style: const TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 14,
                                                  ),
                                                  maxLines: 2,
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              ),
                                              Container(
                                                padding: const EdgeInsets.symmetric(
                                                  horizontal: 8,
                                                  vertical: 4,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: _getActivityTypeColor(log.activityType)
                                                      .withOpacity(0.1),
                                                  borderRadius: BorderRadius.circular(12),
                                                ),
                                                child: Text(
                                                  log.activityType.toUpperCase(),
                                                  style: TextStyle(
                                                    fontSize: 10,
                                                    fontWeight: FontWeight.bold,
                                                    color: _getActivityTypeColor(log.activityType),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 8),
                                          Row(
                                            children: [
                                              Icon(Icons.person, size: 14, color: Colors.grey.shade600),
                                              const SizedBox(width: 4),
                                              Text(
                                                log.userName ?? 'Unknown',
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  color: Colors.grey.shade600,
                                                ),
                                              ),
                                              const SizedBox(width: 16),
                                              Icon(Icons.category, size: 14, color: Colors.grey.shade600),
                                              const SizedBox(width: 4),
                                              Text(
                                                log.module ?? '-',
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  color: Colors.grey.shade600,
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 4),
                                          Row(
                                            children: [
                                              Icon(Icons.access_time, size: 14, color: Colors.grey.shade600),
                                              const SizedBox(width: 4),
                                              Text(
                                                _formatDateTime(log.createdAt),
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  color: Colors.grey.shade600,
                                                ),
                                              ),
                                              const Spacer(),
                                              Icon(Icons.chevron_right, size: 16, color: Colors.grey.shade400),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
              ),
          // Pagination
          if (!_isLoading && _pagination != null && _logs.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              color: Colors.grey.shade50,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Showing ${_pagination!.from} to ${_pagination!.to} of ${_pagination!.total}',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                  Row(
                    children: [
                      if (_pagination!.prevPageUrl != null)
                        TextButton(
                          onPressed: () {
                            setState(() {
                              _currentPage--;
                            });
                            _loadData();
                          },
                          child: const Text('Previous'),
                        ),
                      if (_pagination!.nextPageUrl != null)
                        TextButton(
                          onPressed: () {
                            setState(() {
                              _currentPage++;
                            });
                            _loadData();
                          },
                          child: const Text('Next'),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          // Footer
          const AppFooter(),
        ],
      ),
    );
  }
}

