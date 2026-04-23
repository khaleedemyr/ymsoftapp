import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/customer_voice_command_center_models.dart';
import '../../services/customer_voice_command_center_service.dart';
import '../../widgets/app_loading_indicator.dart';

class CustomerVoiceCommandCenterScreen extends StatefulWidget {
  const CustomerVoiceCommandCenterScreen({super.key});

  @override
  State<CustomerVoiceCommandCenterScreen> createState() =>
      _CustomerVoiceCommandCenterScreenState();
}

class _CustomerVoiceCommandCenterScreenState
    extends State<CustomerVoiceCommandCenterScreen> {
  final CustomerVoiceCommandCenterService _service =
      CustomerVoiceCommandCenterService();
  final TextEditingController _searchController = TextEditingController();

  CustomerVoiceDashboard? _dashboard;
  bool _isLoading = true;
  bool _isSyncing = false;
  String? _errorMessage;

  String _statusFilter = 'all';
  String _severityFilter = 'all';
  String _sourceFilter = 'all';
  int? _outletFilter;
  bool _overdueOnly = false;
  int _currentPage = 1;

  static const List<_FilterOption> _statusOptions = [
    _FilterOption('all', 'Semua Status'),
    _FilterOption('new', 'New'),
    _FilterOption('in_progress', 'In Progress'),
    _FilterOption('resolved', 'Resolved'),
    _FilterOption('ignored', 'Ignored'),
  ];

  static const List<_FilterOption> _severityOptions = [
    _FilterOption('all', 'Semua Severity'),
    _FilterOption('neutral', 'Neutral'),
    _FilterOption('mild_negative', 'Mild Negative'),
    _FilterOption('negative', 'Negative'),
    _FilterOption('severe', 'Severe'),
    _FilterOption('positive', 'Positive'),
  ];

  static const List<_FilterOption> _sourceOptions = [
    _FilterOption('all', 'Semua Source'),
    _FilterOption('google_review', 'Google Review'),
    _FilterOption('instagram_comment', 'Instagram Comment'),
    _FilterOption('guest_comment', 'Guest Comment'),
    _FilterOption('other', 'Other'),
  ];

  @override
  void initState() {
    super.initState();
    _loadDashboard();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadDashboard({bool refresh = false, int? page}) async {
    final targetPage = page ?? _currentPage;

    if (refresh) {
      setState(() {
        _errorMessage = null;
      });
    } else {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }

    try {
      final dashboard = await _service.getDashboard(
        status: _statusFilter,
        severity: _severityFilter,
        sourceType: _sourceFilter,
        outletId: _outletFilter,
        search: _searchController.text,
        overdueOnly: _overdueOnly,
        page: targetPage,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _dashboard = dashboard;
        _currentPage = dashboard.pagination.currentPage;
        _isLoading = false;
        _errorMessage = null;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isLoading = false;
        _errorMessage = error.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  Future<void> _syncData() async {
    setState(() => _isSyncing = true);
    try {
      final message = await _service.syncData();
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
      await _loadDashboard(refresh: true, page: 1);
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.toString().replaceFirst('Exception: ', '')),
          backgroundColor: const Color(0xFFB91C1C),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isSyncing = false);
      }
    }
  }

  void _applyQuickFilter({
    String? status,
    String? severity,
    bool? overdueOnly,
  }) {
    setState(() {
      if (status != null) {
        _statusFilter = status;
      }
      if (severity != null) {
        _severityFilter = severity;
      }
      if (overdueOnly != null) {
        _overdueOnly = overdueOnly;
      }
      _currentPage = 1;
    });
    _loadDashboard(page: 1);
  }

  Future<void> _openFilterSheet() async {
    final dashboard = _dashboard;
    if (dashboard == null) {
      return;
    }

    String localStatus = _statusFilter;
    String localSeverity = _severityFilter;
    String localSource = _sourceFilter;
    int? localOutlet = _outletFilter;
    bool localOverdue = _overdueOnly;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
              ),
              padding: EdgeInsets.fromLTRB(
                20,
                18,
                20,
                20 + MediaQuery.of(context).viewInsets.bottom,
              ),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Center(
                      child: Container(
                        width: 44,
                        height: 5,
                        decoration: BoxDecoration(
                          color: const Color(0xFFE2E8F0),
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    const Text(
                      'Filter Case',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 18),
                    _buildDropdownField<String>(
                      label: 'Status',
                      value: localStatus,
                      items: _statusOptions
                          .map(
                            (option) => DropdownMenuItem<String>(
                              value: option.value,
                              child: Text(option.label),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        setModalState(() => localStatus = value ?? 'all');
                      },
                    ),
                    const SizedBox(height: 14),
                    _buildDropdownField<String>(
                      label: 'Severity',
                      value: localSeverity,
                      items: _severityOptions
                          .map(
                            (option) => DropdownMenuItem<String>(
                              value: option.value,
                              child: Text(option.label),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        setModalState(() => localSeverity = value ?? 'all');
                      },
                    ),
                    const SizedBox(height: 14),
                    _buildDropdownField<String>(
                      label: 'Source',
                      value: localSource,
                      items: _sourceOptions
                          .map(
                            (option) => DropdownMenuItem<String>(
                              value: option.value,
                              child: Text(option.label),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        setModalState(() => localSource = value ?? 'all');
                      },
                    ),
                    const SizedBox(height: 14),
                    _buildDropdownField<int?>(
                      label: 'Outlet',
                      value: localOutlet,
                      items: [
                        const DropdownMenuItem<int?>(
                          value: null,
                          child: Text('Semua Outlet'),
                        ),
                        ...dashboard.outlets.map(
                          (option) => DropdownMenuItem<int?>(
                            value: option.id,
                            child: Text(option.label),
                          ),
                        ),
                      ],
                      onChanged: (value) {
                        setModalState(() => localOutlet = value);
                      },
                    ),
                    const SizedBox(height: 8),
                    SwitchListTile.adaptive(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Hanya yang overdue'),
                      subtitle: const Text('Tampilkan case open yang melewati due date'),
                      value: localOverdue,
                      onChanged: (value) {
                        setModalState(() => localOverdue = value);
                      },
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () {
                              setState(() {
                                _statusFilter = 'all';
                                _severityFilter = 'all';
                                _sourceFilter = 'all';
                                _outletFilter = null;
                                _overdueOnly = false;
                                _currentPage = 1;
                              });
                              Navigator.pop(context);
                              _loadDashboard(page: 1);
                            },
                            style: OutlinedButton.styleFrom(
                              minimumSize: const Size.fromHeight(52),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            child: const Text('Reset'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () {
                              setState(() {
                                _statusFilter = localStatus;
                                _severityFilter = localSeverity;
                                _sourceFilter = localSource;
                                _outletFilter = localOutlet;
                                _overdueOnly = localOverdue;
                                _currentPage = 1;
                              });
                              Navigator.pop(context);
                              _loadDashboard(page: 1);
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF0F766E),
                              foregroundColor: Colors.white,
                              minimumSize: const Size.fromHeight(52),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            child: const Text('Terapkan'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _openCaseSheet(CustomerVoiceCaseItem item) async {
    final dashboard = _dashboard;
    if (dashboard == null) {
      return;
    }

    String localStatus = item.status;
    int? localAssignee = item.assignedTo;
    bool isSaving = false;
    final activities = dashboard.activities[item.id] ?? const <CustomerVoiceActivity>[];

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.92,
              ),
              decoration: const BoxDecoration(
                color: Color(0xFFF8FAFC),
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
              ),
              child: SafeArea(
                top: false,
                child: Column(
                  children: [
                    const SizedBox(height: 12),
                    Container(
                      width: 44,
                      height: 5,
                      decoration: BoxDecoration(
                        color: const Color(0xFFCBD5E1),
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        item.headline,
                                        style: const TextStyle(
                                          fontSize: 20,
                                          fontWeight: FontWeight.w800,
                                          color: Color(0xFF0F172A),
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Wrap(
                                        spacing: 8,
                                        runSpacing: 8,
                                        children: [
                                          _buildBadge(
                                            label: _statusLabel(item.status),
                                            backgroundColor: _statusColor(item.status),
                                          ),
                                          _buildBadge(
                                            label: _severityLabel(item.severity),
                                            backgroundColor: _severityColor(item.severity),
                                          ),
                                          _buildBadge(
                                            label: _sourceLabel(item.sourceType),
                                            backgroundColor: const Color(0xFF475569),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  onPressed: () => Navigator.pop(context),
                                  icon: const Icon(Icons.close),
                                ),
                              ],
                            ),
                            const SizedBox(height: 18),
                            _buildInfoPanel(item),
                            const SizedBox(height: 18),
                            Container(
                              padding: const EdgeInsets.all(18),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(22),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Update Case',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w800,
                                      color: Color(0xFF0F172A),
                                    ),
                                  ),
                                  const SizedBox(height: 14),
                                  _buildDropdownField<String>(
                                    label: 'Status',
                                    value: localStatus,
                                    items: _statusOptions
                                        .where((option) => option.value != 'all')
                                        .map(
                                          (option) => DropdownMenuItem<String>(
                                            value: option.value,
                                            child: Text(option.label),
                                          ),
                                        )
                                        .toList(),
                                    onChanged: (value) {
                                      setModalState(
                                        () => localStatus = value ?? localStatus,
                                      );
                                    },
                                  ),
                                  const SizedBox(height: 14),
                                  _buildDropdownField<int?>(
                                    label: 'PIC',
                                    value: localAssignee,
                                    items: [
                                      const DropdownMenuItem<int?>(
                                        value: null,
                                        child: Text('Belum di-assign'),
                                      ),
                                      ...dashboard.assignees.map(
                                        (option) => DropdownMenuItem<int?>(
                                          value: option.id,
                                          child: Text(option.label),
                                        ),
                                      ),
                                    ],
                                    onChanged: (value) {
                                      setModalState(() => localAssignee = value);
                                    },
                                  ),
                                  const SizedBox(height: 16),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: OutlinedButton.icon(
                                          onPressed: isSaving
                                              ? null
                                              : () async {
                                                  final modalNavigator = Navigator.of(context);
                                                  final added = await _openAddNoteDialog(item.id);
                                                  if (added == true) {
                                                    if (!mounted) {
                                                      return;
                                                    }
                                                    modalNavigator.pop();
                                                    await _loadDashboard(refresh: true);
                                                  }
                                                },
                                          icon: const Icon(Icons.note_add_outlined),
                                          label: const Text('Catatan'),
                                          style: OutlinedButton.styleFrom(
                                            minimumSize: const Size.fromHeight(52),
                                            shape: RoundedRectangleBorder(
                                              borderRadius: BorderRadius.circular(16),
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: ElevatedButton(
                                          onPressed: isSaving
                                              ? null
                                              : () async {
                                                  final modalNavigator = Navigator.of(context);
                                                  final messenger = ScaffoldMessenger.of(this.context);
                                                  setModalState(() => isSaving = true);
                                                  try {
                                                    final message = await _service.updateCase(
                                                      caseId: item.id,
                                                      status: localStatus,
                                                      assignedTo: localAssignee,
                                                    );
                                                    if (!mounted) {
                                                      return;
                                                    }
                                                    modalNavigator.pop();
                                                    messenger.showSnackBar(
                                                      SnackBar(content: Text(message)),
                                                    );
                                                    await _loadDashboard(refresh: true);
                                                  } catch (error) {
                                                    if (!mounted) {
                                                      return;
                                                    }
                                                    messenger.showSnackBar(
                                                      SnackBar(
                                                        content: Text(
                                                          error
                                                              .toString()
                                                              .replaceFirst('Exception: ', ''),
                                                        ),
                                                        backgroundColor: const Color(0xFFB91C1C),
                                                      ),
                                                    );
                                                  } finally {
                                                    if (mounted) {
                                                      setModalState(() => isSaving = false);
                                                    }
                                                  }
                                                },
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: const Color(0xFF0F766E),
                                            foregroundColor: Colors.white,
                                            minimumSize: const Size.fromHeight(52),
                                            shape: RoundedRectangleBorder(
                                              borderRadius: BorderRadius.circular(16),
                                            ),
                                          ),
                                          child: isSaving
                                              ? const SizedBox(
                                                  width: 20,
                                                  height: 20,
                                                  child: AppLoadingIndicator(
                                                    size: 20,
                                                    color: Colors.white,
                                                    strokeWidth: 2,
                                                  ),
                                                )
                                              : const Text('Simpan'),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 18),
                            Container(
                              padding: const EdgeInsets.all(18),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(22),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Timeline',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w800,
                                      color: Color(0xFF0F172A),
                                    ),
                                  ),
                                  const SizedBox(height: 14),
                                  if (activities.isEmpty)
                                    const Text(
                                      'Belum ada aktivitas untuk case ini.',
                                      style: TextStyle(color: Color(0xFF64748B)),
                                    )
                                  else
                                    ...activities.map(_buildActivityTile),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<bool?> _openAddNoteDialog(int caseId) {
    final controller = TextEditingController();
    bool isSaving = false;
    final messenger = ScaffoldMessenger.of(context);

    return showDialog<bool>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Tambah Catatan'),
              content: TextField(
                controller: controller,
                maxLines: 5,
                decoration: const InputDecoration(
                  hintText: 'Tulis catatan tindak lanjut atau konteks tambahan',
                  border: OutlineInputBorder(),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isSaving ? null : () => Navigator.pop(context, false),
                  child: const Text('Batal'),
                ),
                ElevatedButton(
                  onPressed: isSaving
                      ? null
                      : () async {
                          final dialogNavigator = Navigator.of(context);
                          final note = controller.text.trim();
                          if (note.isEmpty) {
                            return;
                          }

                          setDialogState(() => isSaving = true);
                          try {
                            final message = await _service.addNote(
                              caseId: caseId,
                              note: note,
                            );
                            if (!mounted) {
                              return;
                            }
                            dialogNavigator.pop(true);
                            messenger.showSnackBar(
                              SnackBar(content: Text(message)),
                            );
                          } catch (error) {
                            if (!mounted) {
                              return;
                            }
                            messenger.showSnackBar(
                              SnackBar(
                                content: Text(
                                  error.toString().replaceFirst('Exception: ', ''),
                                ),
                                backgroundColor: const Color(0xFFB91C1C),
                              ),
                            );
                          } finally {
                            if (mounted) {
                              setDialogState(() => isSaving = false);
                            }
                          }
                        },
                  child: isSaving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: AppLoadingIndicator(size: 18, strokeWidth: 2),
                        )
                      : const Text('Simpan'),
                ),
              ],
            );
          },
        );
      },
    ).whenComplete(controller.dispose);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F6F5),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: _isLoading
                  ? const Center(child: AppLoadingIndicator())
                  : _errorMessage != null
                      ? _buildErrorState()
                      : RefreshIndicator(
                          onRefresh: () => _loadDashboard(refresh: true),
                          color: const Color(0xFF0F766E),
                          child: ListView(
                            padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
                            children: [
                              _buildSearchRow(),
                              const SizedBox(height: 16),
                              _buildQuickActions(),
                              const SizedBox(height: 18),
                              if (_dashboard != null) ...[
                                _buildSummarySection(_dashboard!),
                                const SizedBox(height: 18),
                                _buildKpiSection(_dashboard!),
                                const SizedBox(height: 18),
                                _buildTrendSection(_dashboard!),
                                const SizedBox(height: 18),
                                _buildPerformanceSection(_dashboard!),
                                const SizedBox(height: 18),
                                _buildCaseSection(_dashboard!),
                              ],
                            ],
                          ),
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 18),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF134E4A), Color(0xFF0F766E), Color(0xFF14B8A6)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.arrow_back, color: Colors.white),
          ),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Customer Voice',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Command Center',
                  style: TextStyle(
                    color: Color(0xFFCCFBF1),
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Sinkronisasi data',
            onPressed: _isSyncing ? null : _syncData,
            icon: _isSyncing
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: AppLoadingIndicator(
                      size: 22,
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                : const Icon(Icons.sync_rounded, color: Colors.white),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchRow() {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: _searchController,
            textInputAction: TextInputAction.search,
            onSubmitted: (_) {
              setState(() => _currentPage = 1);
              _loadDashboard(page: 1);
            },
            decoration: InputDecoration(
              hintText: 'Cari author, outlet, summary, atau isi case',
              prefixIcon: const Icon(Icons.search),
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          child: InkWell(
            onTap: _openFilterSheet,
            borderRadius: BorderRadius.circular(18),
            child: Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: const Color(0xFFD7E3E1)),
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  const Icon(Icons.tune_rounded, color: Color(0xFF0F766E)),
                  if (_hasActiveFilters)
                    Positioned(
                      right: 12,
                      top: 12,
                      child: Container(
                        width: 10,
                        height: 10,
                        decoration: const BoxDecoration(
                          color: Color(0xFFEF4444),
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildQuickActions() {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        _buildQuickChip(
          label: 'Open',
          isActive: _statusFilter == 'in_progress' || _statusFilter == 'new',
          onTap: () => _applyQuickFilter(status: 'in_progress'),
        ),
        _buildQuickChip(
          label: 'Severe',
          isActive: _severityFilter == 'severe',
          onTap: () => _applyQuickFilter(severity: 'severe'),
        ),
        _buildQuickChip(
          label: 'Overdue',
          isActive: _overdueOnly,
          onTap: () => _applyQuickFilter(overdueOnly: !_overdueOnly),
        ),
        _buildQuickChip(
          label: 'Reset',
          isActive: false,
          onTap: () {
            setState(() {
              _statusFilter = 'all';
              _severityFilter = 'all';
              _sourceFilter = 'all';
              _outletFilter = null;
              _overdueOnly = false;
              _currentPage = 1;
              _searchController.clear();
            });
            _loadDashboard(page: 1);
          },
        ),
      ],
    );
  }

  Widget _buildSummarySection(CustomerVoiceDashboard dashboard) {
    final items = [
      _SummaryCardData(
        'Total Case',
        '${dashboard.summary.totalCases}',
        const Color(0xFF0F766E),
        Icons.all_inbox_rounded,
      ),
      _SummaryCardData(
        'Open',
        '${dashboard.summary.openCases}',
        const Color(0xFFF59E0B),
        Icons.pending_actions_rounded,
      ),
      _SummaryCardData(
        'Severe Open',
        '${dashboard.summary.severeOpen}',
        const Color(0xFFDC2626),
        Icons.warning_amber_rounded,
      ),
      _SummaryCardData(
        'Overdue',
        '${dashboard.summary.overdueOpen}',
        const Color(0xFF7C3AED),
        Icons.timelapse_rounded,
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Ringkasan Hari Ini',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: Color(0xFF0F172A),
          ),
        ),
        const SizedBox(height: 12),
        GridView.builder(
          itemCount: items.length,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1.35,
          ),
          itemBuilder: (context, index) {
            final item = items[index];
            return Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: item.color.withValues(alpha: 0.12),
                    blurRadius: 18,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: item.color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(item.icon, color: item.color),
                  ),
                  const Spacer(),
                  Text(
                    item.value,
                    style: const TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    item.label,
                    style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFF64748B),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildKpiSection(CustomerVoiceDashboard dashboard) {
    final items = [
      _KpiCardData('Median First Response', _formatMinutes(dashboard.kpis.firstResponseMedianMinutes)),
      _KpiCardData('Avg First Response', _formatMinutes(dashboard.kpis.firstResponseAvgMinutes)),
      _KpiCardData('Avg Resolution', _formatMinutes(dashboard.kpis.resolutionAvgMinutes)),
      _KpiCardData('SLA Compliance', _formatPercent(dashboard.kpis.slaCompliancePct)),
      _KpiCardData(
        'Repeat Issue ${dashboard.kpis.repeatIssueWindowDays}D',
        _formatPercent(dashboard.kpis.repeatIssueRatePct),
      ),
      _KpiCardData(
        'Top Negative Outlet',
        dashboard.kpis.negativeTopOutlet30d == null
            ? '-'
            : '${dashboard.kpis.negativeTopOutlet30d!.namaOutlet} (${dashboard.kpis.negativeTopOutlet30d!.total})',
      ),
    ];

    return _buildSectionCard(
      title: 'KPI Operasional',
      subtitle: 'Ambil sinyal utama sebelum masuk ke detail case.',
      child: Column(
        children: items
            .map(
              (item) => Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        item.label,
                        style: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFF475569),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Flexible(
                      child: Text(
                        item.value,
                        textAlign: TextAlign.right,
                        style: const TextStyle(
                          fontSize: 14,
                          color: Color(0xFF0F172A),
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            )
            .toList(),
      ),
    );
  }

  Widget _buildTrendSection(CustomerVoiceDashboard dashboard) {
    final maxValue = dashboard.trend.fold<int>(1, (current, item) {
      final localMax = item.totalCases > item.negativeCases
          ? item.totalCases
          : item.negativeCases;
      return localMax > current ? localMax : current;
    });

    return _buildSectionCard(
      title: 'Trend 14 Hari',
      subtitle: 'Perbandingan total case dan case negatif per hari.',
      child: Column(
        children: dashboard.trend.map((item) {
          final totalFactor = item.totalCases / maxValue;
          final negativeFactor = item.negativeCases / maxValue;
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      _formatShortDate(item.date),
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF475569),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '${item.totalCases} total / ${item.negativeCases} negative',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF64748B),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: SizedBox(
                    height: 10,
                    child: Stack(
                      children: [
                        Container(color: const Color(0xFFE2E8F0)),
                        FractionallySizedBox(
                          widthFactor: totalFactor.clamp(0.0, 1.0),
                          child: Container(color: const Color(0xFF14B8A6)),
                        ),
                        FractionallySizedBox(
                          widthFactor: negativeFactor.clamp(0.0, 1.0),
                          child: Container(color: const Color(0xFFF97316)),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildPerformanceSection(CustomerVoiceDashboard dashboard) {
    return Column(
      children: [
        _buildSectionCard(
          title: 'PIC Performance',
          subtitle: 'Top PIC dalam ${dashboard.perfWindowDays} hari terakhir.',
          child: Column(
            children: dashboard.picPerformance
                .map(
                  (item) => _buildPerformanceTile(
                    title: item.assigneeName,
                    subtitle:
                        '${item.resolvedCases} resolved • ${item.openCases} open • ${item.totalCases} total',
                    trailing: 'SLA ${_formatPercent(item.slaCompliancePct)}',
                    caption:
                        'Avg response ${_formatMinutes(item.avgFirstResponseMinutes)}',
                    accent: const Color(0xFF0F766E),
                  ),
                )
                .toList(),
          ),
        ),
        const SizedBox(height: 18),
        _buildSectionCard(
          title: 'Outlet Performance',
          subtitle: 'Outlet dengan tekanan tertinggi dalam ${dashboard.perfWindowDays} hari terakhir.',
          child: Column(
            children: dashboard.outletPerformance
                .map(
                  (item) => _buildPerformanceTile(
                    title: item.outletName,
                    subtitle:
                        '${item.negativeCases} negative • ${item.openCases} open • ${item.resolvedCases} resolved',
                    trailing: 'Neg ${_formatPercent(item.negativeRatePct)}',
                    caption: 'SLA ${_formatPercent(item.slaCompliancePct)}',
                    accent: const Color(0xFFF97316),
                  ),
                )
                .toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildCaseSection(CustomerVoiceDashboard dashboard) {
    return _buildSectionCard(
      title: 'Cases',
      subtitle:
          'Halaman ${dashboard.pagination.currentPage} dari ${dashboard.pagination.lastPage} • ${dashboard.pagination.total} total case',
      child: Column(
        children: [
          if (dashboard.cases.isEmpty)
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(18),
              ),
              child: const Text(
                'Tidak ada case yang cocok dengan filter saat ini.',
                style: TextStyle(color: Color(0xFF64748B)),
              ),
            )
          else
            ...dashboard.cases.map(_buildCaseCard),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: dashboard.pagination.currentPage > 1
                      ? () => _loadDashboard(page: dashboard.pagination.currentPage - 1)
                      : null,
                  icon: const Icon(Icons.chevron_left_rounded),
                  label: const Text('Sebelumnya'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: dashboard.pagination.currentPage <
                          dashboard.pagination.lastPage
                      ? () => _loadDashboard(page: dashboard.pagination.currentPage + 1)
                      : null,
                  icon: const Icon(Icons.chevron_right_rounded),
                  label: const Text('Berikutnya'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0F766E),
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCaseCard(CustomerVoiceCaseItem item) {
    final isOverdue = item.dueAt != null &&
        item.dueAt!.isBefore(DateTime.now()) &&
        (item.status == 'new' || item.status == 'in_progress');

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 16,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.headline,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _buildBadge(
                          label: _statusLabel(item.status),
                          backgroundColor: _statusColor(item.status),
                        ),
                        _buildBadge(
                          label: _severityLabel(item.severity),
                          backgroundColor: _severityColor(item.severity),
                        ),
                        if (isOverdue)
                          _buildBadge(
                            label: 'Overdue',
                            backgroundColor: const Color(0xFFB91C1C),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFFECFEFF),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(
                  item.riskScore == null
                      ? '-'
                      : item.riskScore!.toStringAsFixed(1),
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0F766E),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _buildMetaRow(Icons.storefront_outlined, item.outletName),
          _buildMetaRow(Icons.person_outline_rounded, item.authorName),
          _buildMetaRow(
            Icons.assignment_ind_outlined,
            item.assignedToName?.isNotEmpty == true
                ? item.assignedToName!
                : 'Belum di-assign',
          ),
          _buildMetaRow(
            Icons.access_time_rounded,
            item.eventAt != null ? _formatDateTime(item.eventAt!) : '-',
          ),
          if (item.dueAt != null)
            _buildMetaRow(
              Icons.event_busy_outlined,
              'Due ${_formatDateTime(item.dueAt!)}',
            ),
          const SizedBox(height: 14),
          Text(
            item.rawText.trim().isEmpty ? '-' : item.rawText.trim(),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 13,
              height: 1.5,
              color: Color(0xFF475569),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _openCaseSheet(item),
                  icon: const Icon(Icons.visibility_outlined),
                  label: const Text('Detail'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(46),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _openCaseSheet(item),
                  icon: const Icon(Icons.edit_note_rounded),
                  label: const Text('Tindak Lanjut'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0F766E),
                    foregroundColor: Colors.white,
                    minimumSize: const Size.fromHeight(46),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoPanel(CustomerVoiceCaseItem item) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Informasi Case',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 14),
          _buildInfoRow('Outlet', item.outletName),
          _buildInfoRow('Author', item.authorName),
          _buildInfoRow('Kontak', item.customerContact?.trim().isNotEmpty == true ? item.customerContact! : '-'),
          _buildInfoRow('Source', _sourceLabel(item.sourceType)),
          _buildInfoRow('Event', item.eventAt != null ? _formatDateTime(item.eventAt!) : '-'),
          _buildInfoRow('Due', item.dueAt != null ? _formatDateTime(item.dueAt!) : '-'),
          _buildInfoRow('Resolved', item.resolvedAt != null ? _formatDateTime(item.resolvedAt!) : '-'),
          _buildInfoRow('Summary ID', item.summaryId?.trim().isNotEmpty == true ? item.summaryId! : '-'),
          const SizedBox(height: 12),
          const Text(
            'Voice of Customer',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: Color(0xFF334155),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            item.rawText.trim().isEmpty ? '-' : item.rawText.trim(),
            style: const TextStyle(
              fontSize: 14,
              height: 1.55,
              color: Color(0xFF475569),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActivityTile(CustomerVoiceActivity activity) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 12,
            height: 12,
            margin: const EdgeInsets.only(top: 4),
            decoration: BoxDecoration(
              color: _activityColor(activity.activityType),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _activityLabel(activity),
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${activity.actorName?.trim().isNotEmpty == true ? activity.actorName! : 'System'} • ${activity.createdAt != null ? _formatDateTime(activity.createdAt!) : '-'}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF64748B),
                  ),
                ),
                if (activity.note?.trim().isNotEmpty == true) ...[
                  const SizedBox(height: 6),
                  Text(
                    activity.note!.trim(),
                    style: const TextStyle(
                      fontSize: 13,
                      height: 1.45,
                      color: Color(0xFF475569),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPerformanceTile({
    required String title,
    required String subtitle,
    required String trailing,
    required String caption,
    required Color accent,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Container(
            width: 10,
            height: 54,
            decoration: BoxDecoration(
              color: accent,
              borderRadius: BorderRadius.circular(999),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF475569),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  caption,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Text(
            trailing,
            textAlign: TextAlign.right,
            style: TextStyle(
              fontSize: 12,
              color: accent,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionCard({
    required String title,
    required String subtitle,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: const TextStyle(
              fontSize: 13,
              height: 1.45,
              color: Color(0xFF64748B),
            ),
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline_rounded,
              size: 54,
              color: Color(0xFFB91C1C),
            ),
            const SizedBox(height: 16),
            Text(
              _errorMessage ?? 'Terjadi kesalahan.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 15,
                color: Color(0xFF334155),
                height: 1.5,
              ),
            ),
            const SizedBox(height: 18),
            ElevatedButton(
              onPressed: () => _loadDashboard(),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0F766E),
                foregroundColor: Colors.white,
              ),
              child: const Text('Coba Lagi'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetaRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, size: 16, color: const Color(0xFF64748B)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 13,
                color: Color(0xFF475569),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 86,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                color: Color(0xFF64748B),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 13,
                color: Color(0xFF0F172A),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBadge({
    required String label,
    required Color backgroundColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.2,
        ),
      ),
    );
  }

  Widget _buildQuickChip({
    required String label,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isActive ? const Color(0xFF0F766E) : Colors.white,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: isActive ? const Color(0xFF0F766E) : const Color(0xFFD7E3E1),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isActive ? Colors.white : const Color(0xFF0F172A),
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }

  Widget _buildDropdownField<T>({
    required String label,
    required T value,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T?> onChanged,
  }) {
    return DropdownButtonFormField<T>(
      initialValue: value,
      items: items,
      onChanged: onChanged,
      decoration: InputDecoration(
        labelText: label,
        filled: true,
        fillColor: const Color(0xFFF8FAFC),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }

  bool get _hasActiveFilters {
    return _statusFilter != 'all' ||
        _severityFilter != 'all' ||
        _sourceFilter != 'all' ||
        _outletFilter != null ||
        _overdueOnly;
  }

  String _formatDateTime(DateTime dateTime) {
    return DateFormat('dd MMM yyyy, HH:mm', 'id_ID').format(dateTime);
  }

  String _formatShortDate(String isoDate) {
    final parsed = DateTime.tryParse(isoDate);
    if (parsed == null) {
      return isoDate;
    }
    return DateFormat('dd MMM', 'id_ID').format(parsed);
  }

  String _formatMinutes(double? minutes) {
    if (minutes == null) {
      return '-';
    }
    if (minutes >= 1440) {
      return '${(minutes / 1440).toStringAsFixed(1)} hari';
    }
    if (minutes >= 60) {
      return '${(minutes / 60).toStringAsFixed(1)} jam';
    }
    return '${minutes.toStringAsFixed(0)} menit';
  }

  String _formatPercent(double? value) {
    if (value == null) {
      return '-';
    }
    return '${value.toStringAsFixed(1)}%';
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'new':
        return 'New';
      case 'in_progress':
        return 'In Progress';
      case 'resolved':
        return 'Resolved';
      case 'ignored':
        return 'Ignored';
      default:
        return status;
    }
  }

  String _severityLabel(String severity) {
    switch (severity) {
      case 'mild_negative':
        return 'Mild Negative';
      case 'negative':
        return 'Negative';
      case 'severe':
        return 'Severe';
      case 'positive':
        return 'Positive';
      case 'neutral':
        return 'Neutral';
      default:
        return severity;
    }
  }

  String _sourceLabel(String source) {
    switch (source) {
      case 'google_review':
        return 'Google Review';
      case 'instagram_comment':
        return 'Instagram Comment';
      case 'guest_comment':
        return 'Guest Comment';
      default:
        return source.replaceAll('_', ' ');
    }
  }

  String _activityLabel(CustomerVoiceActivity activity) {
    switch (activity.activityType) {
      case 'status_changed':
        return 'Status ${_statusLabel(activity.fromStatus ?? '-')} -> ${_statusLabel(activity.toStatus ?? '-')}';
      case 'assigned':
        return 'Perubahan PIC';
      case 'note':
        return 'Catatan baru';
      default:
        return activity.activityType.replaceAll('_', ' ');
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'new':
        return const Color(0xFF2563EB);
      case 'in_progress':
        return const Color(0xFFF59E0B);
      case 'resolved':
        return const Color(0xFF16A34A);
      case 'ignored':
        return const Color(0xFF64748B);
      default:
        return const Color(0xFF475569);
    }
  }

  Color _severityColor(String severity) {
    switch (severity) {
      case 'severe':
        return const Color(0xFFB91C1C);
      case 'negative':
        return const Color(0xFFEA580C);
      case 'mild_negative':
        return const Color(0xFFF59E0B);
      case 'positive':
        return const Color(0xFF15803D);
      case 'neutral':
        return const Color(0xFF475569);
      default:
        return const Color(0xFF64748B);
    }
  }

  Color _activityColor(String type) {
    switch (type) {
      case 'status_changed':
        return const Color(0xFF2563EB);
      case 'assigned':
        return const Color(0xFF0F766E);
      case 'note':
        return const Color(0xFFF97316);
      default:
        return const Color(0xFF64748B);
    }
  }
}

class _SummaryCardData {
  final String label;
  final String value;
  final Color color;
  final IconData icon;

  _SummaryCardData(this.label, this.value, this.color, this.icon);
}

class _KpiCardData {
  final String label;
  final String value;

  _KpiCardData(this.label, this.value);
}

class _FilterOption {
  final String value;
  final String label;

  const _FilterOption(this.value, this.label);
}