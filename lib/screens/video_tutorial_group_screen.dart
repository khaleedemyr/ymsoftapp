import 'package:flutter/material.dart';
import '../models/video_tutorial_model.dart';
import '../services/video_tutorial_service.dart';
import '../widgets/app_loading_indicator.dart';
import '../widgets/app_scaffold.dart';
import 'video_tutorial_gallery_screen.dart';

class VideoTutorialGroupScreen extends StatefulWidget {
  const VideoTutorialGroupScreen({super.key});

  @override
  State<VideoTutorialGroupScreen> createState() =>
      _VideoTutorialGroupScreenState();
}

class _VideoTutorialGroupScreenState extends State<VideoTutorialGroupScreen> {
  final VideoTutorialService _service = VideoTutorialService();
  final TextEditingController _searchController = TextEditingController();

  bool _loading = true;
  String? _error;
  List<VideoTutorialGroup> _allGroups = [];
  List<VideoTutorialGroup> _filteredGroups = [];

  @override
  void initState() {
    super.initState();
    _loadGroups();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadGroups() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    final result = await _service.getGallery(page: 1);
    if (!mounted) return;

    if (result['success'] != true) {
      setState(() {
        _loading = false;
        _error =
            result['error']?.toString() ?? 'Gagal memuat group video tutorial';
      });
      return;
    }

    final groups = (result['groups'] as List<VideoTutorialGroup>? ??
        <VideoTutorialGroup>[]);
    setState(() {
      _loading = false;
      _allGroups = groups;
      _filteredGroups = groups;
    });
  }

  void _onSearchChanged(String value) {
    final key = value.trim().toLowerCase();
    setState(() {
      if (key.isEmpty) {
        _filteredGroups = List.of(_allGroups);
      } else {
        _filteredGroups = _allGroups
            .where((g) => g.name.toLowerCase().contains(key))
            .toList();
      }
    });
  }

  void _openGroup(VideoTutorialGroup group) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => VideoTutorialGalleryScreen(
          initialGroupId: group.id,
          initialTitle: 'Video Tutorial - ${group.name}',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Group Video Tutorial',
      body: _loading
          ? const Center(child: AppLoadingIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.error_outline,
                            size: 56, color: Colors.redAccent),
                        const SizedBox(height: 12),
                        Text(_error!, textAlign: TextAlign.center),
                        const SizedBox(height: 16),
                        FilledButton(
                          onPressed: _loadGroups,
                          child: const Text('Coba Lagi'),
                        ),
                      ],
                    ),
                  ),
                )
              : Column(
                  children: [
                    Container(
                      color: Colors.white,
                      padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
                      child: TextField(
                        controller: _searchController,
                        onChanged: _onSearchChanged,
                        decoration: InputDecoration(
                          hintText: 'Cari group video tutorial...',
                          prefixIcon: const Icon(Icons.search),
                          suffixIcon: _searchController.text.isEmpty
                              ? null
                              : IconButton(
                                  onPressed: () {
                                    _searchController.clear();
                                    _onSearchChanged('');
                                  },
                                  icon: const Icon(Icons.close),
                                ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: _filteredGroups.isEmpty
                          ? const Center(
                              child: Text('Tidak ada group ditemukan'))
                          : RefreshIndicator(
                              onRefresh: _loadGroups,
                              child: ListView.builder(
                                padding:
                                    const EdgeInsets.fromLTRB(16, 8, 16, 16),
                                itemCount: _filteredGroups.length,
                                itemBuilder: (context, index) {
                                  final group = _filteredGroups[index];
                                  return Card(
                                    margin: const EdgeInsets.only(bottom: 10),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                    child: ListTile(
                                      leading: Container(
                                        width: 40,
                                        height: 40,
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFE0E7FF),
                                          borderRadius:
                                              BorderRadius.circular(10),
                                        ),
                                        child: const Icon(
                                          Icons.folder_open_rounded,
                                          color: Color(0xFF4338CA),
                                        ),
                                      ),
                                      title: Text(
                                        group.name,
                                        style: const TextStyle(
                                            fontWeight: FontWeight.w700),
                                      ),
                                      trailing: const Icon(Icons.chevron_right),
                                      onTap: () => _openGroup(group),
                                    ),
                                  );
                                },
                              ),
                            ),
                    ),
                  ],
                ),
    );
  }
}
