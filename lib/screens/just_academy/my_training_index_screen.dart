import 'package:flutter/material.dart';
import '../../models/just_academy_models.dart';
import '../../services/just_academy_service.dart';
import '../../widgets/app_loading_indicator.dart';
import '../../widgets/app_scaffold.dart';
import 'just_academy_ui.dart';
import 'my_training_show_screen.dart';

class MyTrainingIndexScreen extends StatefulWidget {
  const MyTrainingIndexScreen({super.key});

  @override
  State<MyTrainingIndexScreen> createState() => _MyTrainingIndexScreenState();
}

class _MyTrainingIndexScreenState extends State<MyTrainingIndexScreen>
    with SingleTickerProviderStateMixin {
  final _service = JustAcademyService();
  late final TabController _tabController;

  bool _loading = true;
  bool _loadingMore = false;
  int _page = 1;
  int _lastPage = 1;
  List<JaScheduleListItem> _records = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        _load(reset: true);
      }
    });
    _load(reset: true);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  String get _tab => _tabController.index == 0 ? 'upcoming' : 'past';

  Future<void> _load({bool reset = true}) async {
    if (reset) {
      _page = 1;
      if (!_loading) setState(() => _loading = true);
    } else {
      if (_loadingMore || _page >= _lastPage) return;
      setState(() => _loadingMore = true);
      _page += 1;
    }

    final res = await _service.fetchMySchedules(tab: _tab, page: _page);
    if (!mounted) return;

    if (res == null || res['success'] != true) {
      setState(() {
        _loading = false;
        _loadingMore = false;
      });
      return;
    }

    final pagination = res['data'] as Map? ?? {};
    final rows = (pagination['data'] as List? ?? [])
        .map((e) => JaScheduleListItem.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();

    setState(() {
      if (reset) {
        _records = rows;
      } else {
        _records = [..._records, ...rows];
      }
      _lastPage = pagination['last_page'] as int? ?? 1;
      _loading = false;
      _loadingMore = false;
    });
  }

  Widget _buildCard(JaScheduleListItem item) {
    final card = item.card;
    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: JustAcademyUi.primary.withOpacity(0.15)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => MyTrainingShowScreen(scheduleId: item.id),
            ),
          );
          if (mounted) _load(reset: true);
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      item.title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: JustAcademyUi.statusColor(card.statusLabel).withOpacity(0.12),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      card.statusLabel,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: JustAcademyUi.statusColor(card.statusLabel),
                      ),
                    ),
                  ),
                ],
              ),
              if (item.programTitle != null && item.programTitle!.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  item.programTitle!,
                  style: const TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                ),
              ],
              const SizedBox(height: 10),
              Row(
                children: [
                  const Icon(Icons.calendar_today, size: 14, color: Color(0xFF94A3B8)),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      JustAcademyUi.formatDateTime(item.startAt),
                      style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                    ),
                  ),
                ],
              ),
              if (card.trainerNames.isNotEmpty) ...[
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(Icons.person_outline, size: 14, color: Color(0xFF94A3B8)),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        card.trainerNames.join(', '),
                        style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                      ),
                    ),
                  ],
                ),
              ],
              if (card.stepsTotal > 0) ...[
                const SizedBox(height: 14),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Progress ${card.stepsCompleted}/${card.stepsTotal}',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                    Text(
                      '${card.progressPercent}%',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: JustAcademyUi.primary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                JustAcademyUi.progressBar(card.progressPercent),
              ],
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    card.actionLabel,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: JustAcademyUi.primary,
                    ),
                  ),
                  const Icon(Icons.chevron_right, color: JustAcademyUi.primary),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'My Training',
      body: Column(
        children: [
          Container(
            color: Colors.white,
            child: TabBar(
              controller: _tabController,
              labelColor: JustAcademyUi.primary,
              unselectedLabelColor: const Color(0xFF94A3B8),
              indicatorColor: JustAcademyUi.primary,
              tabs: const [
                Tab(text: 'Mendatang'),
                Tab(text: 'Riwayat'),
              ],
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () => _load(reset: true),
              child: _loading && _records.isEmpty
                  ? const Center(child: AppLoadingIndicator())
                  : NotificationListener<ScrollNotification>(
                      onNotification: (n) {
                        if (n.metrics.pixels >= n.metrics.maxScrollExtent - 120 &&
                            !_loading &&
                            !_loadingMore) {
                          _load(reset: false);
                        }
                        return false;
                      },
                      child: _records.isEmpty
                          ? ListView(
                              physics: const AlwaysScrollableScrollPhysics(),
                              children: const [
                                SizedBox(height: 80),
                                Center(
                                  child: Text(
                                    'Belum ada jadwal training',
                                    style: TextStyle(color: Color(0xFF94A3B8)),
                                  ),
                                ),
                              ],
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                              itemCount: _records.length + (_loadingMore ? 1 : 0),
                              itemBuilder: (context, index) {
                                if (index >= _records.length) {
                                  return const Padding(
                                    padding: EdgeInsets.all(16),
                                    child: Center(child: AppLoadingIndicator()),
                                  );
                                }
                                return _buildCard(_records[index]);
                              },
                            ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
