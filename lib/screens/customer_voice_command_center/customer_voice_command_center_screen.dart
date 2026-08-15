import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/customer_voice_command_center_models.dart';
import '../../services/customer_voice_command_center_service.dart';
import '../../widgets/app_loading_indicator.dart';
import '../../widgets/customer_voice/customer_voice_case_index_card.dart';
import 'customer_voice_archive_sheet.dart';
import 'customer_voice_case_detail_sheet.dart';

class CustomerVoiceCommandCenterScreen extends StatefulWidget {
  const CustomerVoiceCommandCenterScreen({
    super.key,
    this.initialOpenCaseId,
    this.initialShowAll = false,
  });

  /// Buka detail case setelah dashboard load (deep link dari Home).
  final int? initialOpenCaseId;

  /// Set filter show_all seperti web `?show_all=1`.
  final bool initialShowAll;

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
  bool _didOpenInitialCase = false;

  String _statusFilter = 'all';
  String _followUpStatusFilter = 'all';
  String _severityFilter = 'all';
  String _sourceFilter = 'all';
  int? _outletFilter;
  bool _overdueOnly = false;
  bool _showAll = false;
  DateTime? _dateFrom;
  DateTime? _dateTo;
  int _currentPage = 1;

  /// Opsi filter courtesy status.
  static const List<_FilterOption> _statusOptions = [
    _FilterOption('all', 'Semua Courtesy Status'),
    _FilterOption('new', 'New'),
    _FilterOption('internal_follow_up', 'Internal Follow Up'),
    _FilterOption('courtesy_done', 'Courtesy Done'),
  ];

  static const List<_FilterOption> _followUpStatusOptions = [
    _FilterOption('all', 'Semua Follow Up Status'),
    _FilterOption('new', 'New'),
    _FilterOption('on_progress', 'On Progress'),
    _FilterOption('done', 'Done'),
  ];

  static const List<_FilterOption> _severityOptions = [
    _FilterOption('all', 'Semua severity'),
    _FilterOption('critical', 'Critical'),
    _FilterOption('major', 'Major'),
    _FilterOption('minor', 'Minor'),
    _FilterOption('severe', 'Critical (arsip)'),
    _FilterOption('negative', 'Major (arsip)'),
    _FilterOption('mild_negative', 'Minor (arsip)'),
    _FilterOption('neutral', 'Neutral'),
    _FilterOption('positive', 'Positive'),
  ];

  static const List<_FilterOption> _sourceOptions = [
    _FilterOption('all', 'Semua source'),
    _FilterOption('google_review', 'Google Review'),
    _FilterOption('instagram_comment', 'Instagram Comment'),
    _FilterOption('guest_comment', 'Guest Comment'),
  ];

  @override
  void initState() {
    super.initState();
    if (widget.initialShowAll) {
      _showAll = true;
    }
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
        followUpStatus: _followUpStatusFilter,
        severity: _severityFilter,
        sourceType: _sourceFilter,
        outletId: _outletFilter,
        search: _searchController.text,
        overdueOnly: _overdueOnly,
        showAll: _showAll,
        dateFrom: _formatApiDate(_dateFrom),
        dateTo: _formatApiDate(_dateTo),
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
        _showAll = dashboard.filters.showAll;
        final echoFrom = dashboard.filters.dateFrom;
        final echoTo = dashboard.filters.dateTo;
        _dateFrom = echoFrom != null && echoFrom.isNotEmpty
            ? DateTime.tryParse(echoFrom)
            : null;
        _dateTo =
            echoTo != null && echoTo.isNotEmpty ? DateTime.tryParse(echoTo) : null;
      });

      await _maybeOpenInitialCase();
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

  Future<void> _maybeOpenInitialCase() async {
    final caseId = widget.initialOpenCaseId;
    if (caseId == null || _didOpenInitialCase || !mounted) {
      return;
    }
    _didOpenInitialCase = true;

    final dashboard = _dashboard;
    if (dashboard == null) {
      return;
    }

    CustomerVoiceCaseItem? item;
    for (final c in dashboard.cases) {
      if (c.id == caseId) {
        item = c;
        break;
      }
    }

    if (item == null) {
      try {
        final brief = await _service.getCaseBrief(caseId);
        item = CustomerVoiceCaseItem.fromJson(brief);
      } catch (_) {
        return;
      }
    }

    if (!mounted || item == null) {
      return;
    }

    await _openCaseSheet(item);
  }

  void _openArchiveSheet() {
    final d = _dashboard;
    if (d == null) {
      return;
    }
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => CustomerVoiceArchiveSheet(
        service: _service,
        outlets: d.outlets,
        assignees: d.assignees,
        mainFilters: CustomerVoiceListFiltersSync(
          search: _searchController.text,
          status: _statusFilter,
          severity: _severityFilter,
          sourceType: _sourceFilter,
          outletId: _outletFilter,
          dateFrom: _formatApiDate(_dateFrom),
          dateTo: _formatApiDate(_dateTo),
          overdueOnly: _overdueOnly,
        ),
        onOpenDetail: (item) {
          Navigator.pop(ctx);
          _openCaseSheet(item);
        },
      ),
    );
  }

  Future<void> _openExportPdf() async {
    final from = _formatApiDate(_dateFrom);
    final to = _formatApiDate(_dateTo);
    if (from == null || to == null) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Pilih rentang tanggal event (dari & sampai) — sama seperti di web ERP.',
          ),
        ),
      );
      return;
    }

    final uri = _service.buildExportPdfWebUri(
      status: _statusFilter,
      severity: _severityFilter,
      sourceType: _sourceFilter,
      outletId: _outletFilter,
      search: _searchController.text,
      overdueOnly: _overdueOnly,
      showAll: _showAll,
      dateFrom: from,
      dateTo: to,
    );

    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!mounted) {
      return;
    }
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tidak bisa membuka browser.')),
      );
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
    String localFollowUpStatus = _followUpStatusFilter;
    String localSeverity = _severityFilter;
    String localSource = _sourceFilter;
    int? localOutlet = _outletFilter;
    bool localOverdue = _overdueOnly;
    bool localShowAll = _showAll;
    DateTime? localDateFrom = _dateFrom;
    DateTime? localDateTo = _dateTo;

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
                      label: 'Courtesy Status',
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
                      label: 'Follow Up Status',
                      value: localFollowUpStatus,
                      items: _followUpStatusOptions
                          .map(
                            (option) => DropdownMenuItem<String>(
                              value: option.value,
                              child: Text(option.label),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        setModalState(() => localFollowUpStatus = value ?? 'all');
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
                    SwitchListTile.adaptive(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Tampilkan semua kasus'),
                      subtitle: const Text(
                        'Matikan mode antrian kerja (open + severity selain positif/netral).',
                      ),
                      value: localShowAll,
                      onChanged: (value) {
                        setModalState(() => localShowAll = value);
                      },
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Event date range',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Colors.grey.shade800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () async {
                              final picked = await showDatePicker(
                                context: context,
                                initialDate: localDateFrom ?? DateTime.now(),
                                firstDate: DateTime(2020),
                                lastDate:
                                    DateTime.now().add(const Duration(days: 730)),
                              );
                              if (picked != null) {
                                setModalState(() => localDateFrom = picked);
                              }
                            },
                            child: Text(
                              localDateFrom == null
                                  ? 'Dari tanggal'
                                  : _formatApiDate(localDateFrom)!,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () async {
                              final picked = await showDatePicker(
                                context: context,
                                initialDate: localDateTo ?? DateTime.now(),
                                firstDate: DateTime(2020),
                                lastDate:
                                    DateTime.now().add(const Duration(days: 730)),
                              );
                              if (picked != null) {
                                setModalState(() => localDateTo = picked);
                              }
                            },
                            child: Text(
                              localDateTo == null
                                  ? 'Sampai tanggal'
                                  : _formatApiDate(localDateTo)!,
                            ),
                          ),
                        ),
                      ],
                    ),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: () {
                          setModalState(() {
                            localDateFrom = null;
                            localDateTo = null;
                          });
                        },
                        child: const Text('Hapus tanggal'),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () {
                              setState(() {
                                _statusFilter = 'all';
                                _followUpStatusFilter = 'all';
                                _severityFilter = 'all';
                                _sourceFilter = 'all';
                                _outletFilter = null;
                                _overdueOnly = false;
                                _showAll = false;
                                _dateFrom = null;
                                _dateTo = null;
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
                                _followUpStatusFilter = localFollowUpStatus;
                                _severityFilter = localSeverity;
                                _sourceFilter = localSource;
                                _outletFilter = localOutlet;
                                _overdueOnly = localOverdue;
                                _showAll = localShowAll;
                                _dateFrom = localDateFrom;
                                _dateTo = localDateTo;
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

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => CustomerVoiceCaseDetailSheet(
        item: item,
        dashboard: dashboard,
        service: _service,
        onCaseUpdated: () async {
          await _loadDashboard(refresh: true);
        },
      ),
    );
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
                              _buildArchiveShortcutRow(),
                              _buildExportPdfRow(),
                              const SizedBox(height: 18),
                              if (_dashboard != null)
                                _buildCaseSection(_dashboard!),
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
              hintText:
                  'Cari author / ringkasan / komentar / outlet',
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
          label: 'Follow Up',
          isActive: _statusFilter == 'internal_follow_up',
          onTap: () => _applyQuickFilter(status: 'internal_follow_up'),
        ),
        _buildQuickChip(
          label: 'Critical',
          isActive: _severityFilter == 'critical',
          onTap: () => _applyQuickFilter(severity: 'critical'),
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
              _followUpStatusFilter = 'all';
              _severityFilter = 'all';
              _sourceFilter = 'all';
              _outletFilter = null;
              _overdueOnly = false;
              _showAll = false;
              _dateFrom = null;
              _dateTo = null;
              _currentPage = 1;
              _searchController.clear();
            });
            _loadDashboard(page: 1);
          },
        ),
      ],
    );
  }

  Widget _buildArchiveShortcutRow() {
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Align(
        alignment: Alignment.centerLeft,
        child: OutlinedButton.icon(
          onPressed: _dashboard == null ? null : _openArchiveSheet,
          icon: const Icon(Icons.inventory_2_outlined, size: 20),
          label: const Text('Arsip: Done & positif'),
          style: OutlinedButton.styleFrom(
            foregroundColor: const Color(0xFF334155),
          ),
        ),
      ),
    );
  }

  Widget _buildExportPdfRow() {
    final hasRange = _dateFrom != null && _dateTo != null;
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Align(
        alignment: Alignment.centerLeft,
        child: TextButton.icon(
          onPressed: _openExportPdf,
          icon: Icon(
            Icons.picture_as_pdf_outlined,
            size: 20,
            color: hasRange ? const Color(0xFF0F766E) : Colors.grey,
          ),
          label: Text(
            hasRange
                ? 'Export PDF (buka di browser — sesi web)'
                : 'Export PDF — set tanggal di filter',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: hasRange ? const Color(0xFF0F766E) : const Color(0xFF94A3B8),
            ),
          ),
        ),
      ),
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
            ...dashboard.cases.map(
              (c) => CustomerVoiceCaseIndexCard(
                dashboard: dashboard,
                item: c,
                service: _service,
                onRefresh: () => _loadDashboard(refresh: true),
                onOpenDetail: _openCaseSheet,
              ),
            ),
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
        _followUpStatusFilter != 'all' ||
        _severityFilter != 'all' ||
        _sourceFilter != 'all' ||
        _outletFilter != null ||
        _overdueOnly ||
        _showAll ||
        _dateFrom != null ||
        _dateTo != null;
  }

  /// Format `yyyy-MM-dd` untuk query API (sama dengan input date web).
  String? _formatApiDate(DateTime? dateTime) {
    if (dateTime == null) {
      return null;
    }
    return DateFormat('yyyy-MM-dd').format(dateTime);
  }

}

class _FilterOption {
  final String value;
  final String label;

  const _FilterOption(this.value, this.label);
}