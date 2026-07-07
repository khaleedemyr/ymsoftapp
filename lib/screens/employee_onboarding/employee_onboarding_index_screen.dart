import 'package:flutter/material.dart';
import '../../models/employee_onboarding_models.dart';
import '../../services/employee_onboarding_service.dart';
import '../../widgets/app_loading_indicator.dart';
import '../../widgets/app_scaffold.dart';
import 'employee_onboarding_show_screen.dart';
import 'employee_onboarding_ui.dart';

class EmployeeOnboardingIndexScreen extends StatefulWidget {
  const EmployeeOnboardingIndexScreen({super.key});

  @override
  State<EmployeeOnboardingIndexScreen> createState() => _EmployeeOnboardingIndexScreenState();
}

class _EmployeeOnboardingIndexScreenState extends State<EmployeeOnboardingIndexScreen> {
  final _service = EmployeeOnboardingService();
  bool _loading = true;
  List<EoListItem> _records = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final rows = await _service.fetchMyTasks();
    if (!mounted) return;
    setState(() {
      _records = rows;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'My Onboarding Tasks',
      body: RefreshIndicator(
        onRefresh: _load,
        child: _loading
            ? const Center(child: AppLoadingIndicator())
            : _records.isEmpty
                ? ListView(
                    children: const [
                      SizedBox(height: 120),
                      Center(child: Text('Tidak ada task onboarding.', style: TextStyle(color: EmployeeOnboardingUi.textMuted))),
                    ],
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _records.length,
                    itemBuilder: (context, index) {
                      final row = _records[index];
                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: EmployeeOnboardingUi.cardDecoration,
                        child: ListTile(
                          title: Text(row.number, style: const TextStyle(fontWeight: FontWeight.w700)),
                          subtitle: Text('${row.employeeName ?? '-'} · Minggu ${row.unlockedWeek}/${row.totalWeeks}'),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => EmployeeOnboardingShowScreen(recordId: row.id)),
                            ).then((_) => _load());
                          },
                        ),
                      );
                    },
                  ),
      ),
    );
  }
}
