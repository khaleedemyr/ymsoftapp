import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:video_player/video_player.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/video_tutorial_model.dart';
import '../services/video_tutorial_service.dart';
import '../widgets/app_scaffold.dart';
import '../widgets/app_loading_indicator.dart';

class VideoTutorialGalleryScreen extends StatefulWidget {
  final int? initialGroupId;
  final String? initialTitle;

  const VideoTutorialGalleryScreen({
    super.key,
    this.initialGroupId,
    this.initialTitle,
  });

  @override
  State<VideoTutorialGalleryScreen> createState() =>
      _VideoTutorialGalleryScreenState();
}

class _VideoTutorialGalleryScreenState
    extends State<VideoTutorialGalleryScreen> {
  final VideoTutorialService _service = VideoTutorialService();
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  List<VideoTutorial> _videos = [];
  List<VideoTutorialGroup> _groups = [];
  Map<String, dynamic>? _stats;
  bool _isLoading = true;
  String? _error;

  String? _selectedGroupId;
  String _sortBy = 'newest';
  int _currentPage = 1;
  int? _lastPage;
  bool _isLoadingMore = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialGroupId != null) {
      _selectedGroupId = widget.initialGroupId!.toString();
    }
    _loadVideos();
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      if (!_isLoadingMore && (_lastPage == null || _currentPage < _lastPage!)) {
        _loadVideos(loadMore: true);
      }
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadVideos({bool loadMore = false}) async {
    if (loadMore) {
      if (_isLoadingMore || (_lastPage != null && _currentPage >= _lastPage!)) {
        return;
      }
      setState(() {
        _isLoadingMore = true;
        _currentPage++;
      });
    } else {
      setState(() {
        _isLoading = true;
        _error = null;
        _currentPage = 1;
      });
    }

    try {
      final result = await _service.getGallery(
        search: _searchController.text.isEmpty ? null : _searchController.text,
        groupId:
            _selectedGroupId != null ? int.tryParse(_selectedGroupId!) : null,
        sort: _sortBy,
        page: _currentPage,
      );

      if (result['success'] == true) {
        setState(() {
          if (loadMore) {
            _videos.addAll(result['videos'] as List<VideoTutorial>);
          } else {
            _videos = result['videos'] as List<VideoTutorial>;
          }
          _groups = result['groups'] as List<VideoTutorialGroup>;
          _stats = result['stats'] as Map<String, dynamic>;

          final pagination = result['pagination'] as Map<String, dynamic>;
          _lastPage = pagination['last_page'] as int?;

          _isLoading = false;
          _isLoadingMore = false;
        });
      } else {
        setState(() {
          _error = result['error'] ?? 'Gagal memuat video tutorial';
          _isLoading = false;
          _isLoadingMore = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Error: $e';
        _isLoading = false;
        _isLoadingMore = false;
      });
    }
  }

  void _onSearchChanged() {
    _loadVideos();
  }

  void _showVideoPlayer(VideoTutorial video) {
    showDialog(
      context: context,
      barrierColor: Colors.black87,
      builder: (context) => _VideoPlayerDialog(video: video),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: widget.initialTitle ?? 'Video Tutorial Gallery',
      body: _isLoading && _videos.isEmpty
          ? Center(child: AppLoadingIndicator())
          : _error != null && _videos.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.error_outline,
                        size: 64,
                        color: Colors.grey.shade400,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _error!,
                        style: TextStyle(color: Colors.grey.shade600),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () => _loadVideos(),
                        child: const Text('Coba Lagi'),
                      ),
                    ],
                  ),
                )
              : Column(
                  children: [
                    // Statistics Cards
                    if (_stats != null) _buildStatsSection(),

                    // Search and Filters
                    _buildSearchAndFilters(),

                    // Video List
                    Expanded(
                      child: _videos.isEmpty
                          ? _buildEmptyState()
                          : RefreshIndicator(
                              onRefresh: () => _loadVideos(),
                              child: ListView.builder(
                                controller: _scrollController,
                                physics: const AlwaysScrollableScrollPhysics(),
                                padding: const EdgeInsets.all(8),
                                itemCount:
                                    _videos.length + (_isLoadingMore ? 1 : 0),
                                itemBuilder: (context, index) {
                                  if (index == _videos.length) {
                                    return const Padding(
                                      padding: EdgeInsets.all(16.0),
                                      child: Center(
                                        child: AppLoadingIndicator(),
                                      ),
                                    );
                                  }

                                  final video = _videos[index];
                                  return _buildVideoCard(video);
                                },
                              ),
                            ),
                    ),
                  ],
                ),
    );
  }

  Widget _buildStatsSection() {
    return Container(
      margin: const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(
            child: _buildStatCard(
              'Total Video',
              '${_stats!['total_videos'] ?? 0}',
              Icons.video_library,
              const Color(0xFF6366F1),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildStatCard(
              'Total Group',
              '${_stats!['total_groups'] ?? 0}',
              Icons.folder,
              const Color(0xFF10B981),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(
      String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchAndFilters() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.white,
      child: Column(
        children: [
          // Search Bar
          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Cari video tutorial...',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _searchController.clear();
                        _loadVideos();
                      },
                    )
                  : null,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              filled: true,
              fillColor: Colors.grey.shade50,
            ),
            onChanged: (_) => _onSearchChanged(),
            onSubmitted: (_) => _loadVideos(),
          ),
          const SizedBox(height: 12),
          // Filters Row
          Row(
            children: [
              // Group Filter
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _selectedGroupId,
                      isExpanded: true,
                      hint: const Text('Semua Group'),
                      items: [
                        const DropdownMenuItem<String>(
                          value: null,
                          child: Text('Semua Group'),
                        ),
                        ..._groups.map((group) => DropdownMenuItem<String>(
                              value: group.id.toString(),
                              child: Text(group.name),
                            )),
                      ],
                      onChanged: (value) {
                        setState(() {
                          _selectedGroupId = value;
                        });
                        _loadVideos();
                      },
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Sort Filter
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _sortBy,
                    items: const [
                      DropdownMenuItem(value: 'newest', child: Text('Terbaru')),
                      DropdownMenuItem(value: 'oldest', child: Text('Terlama')),
                      DropdownMenuItem(
                          value: 'title', child: Text('Judul A-Z')),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        setState(() {
                          _sortBy = value;
                        });
                        _loadVideos();
                      }
                    },
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildVideoCard(VideoTutorial video) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _showVideoPlayer(video),
        borderRadius: BorderRadius.circular(12),
        splashColor: Colors.grey.withOpacity(0.1),
        highlightColor: Colors.grey.withOpacity(0.05),
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Thumbnail
              ClipRRect(
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(12),
                  bottomLeft: Radius.circular(12),
                ),
                child: Stack(
                  children: [
                    video.thumbnailUrl != null
                        ? CachedNetworkImage(
                            imageUrl: video.thumbnailUrl!,
                            width: 160,
                            height: 90,
                            fit: BoxFit.cover,
                            placeholder: (context, url) => Container(
                              width: 160,
                              height: 90,
                              color: Colors.grey.shade200,
                              child: const Center(
                                child: SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: AppLoadingIndicator(
                                      size: 24,
                                      color: Colors.white,
                                      strokeWidth: 2),
                                ),
                              ),
                            ),
                            errorWidget: (context, url, error) => Container(
                              width: 160,
                              height: 90,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    const Color(0xFF6366F1).withOpacity(0.3),
                                    const Color(0xFF8B5CF6).withOpacity(0.3),
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                              ),
                              child: const Center(
                                child: Icon(
                                  Icons.video_library,
                                  size: 32,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          )
                        : Container(
                            width: 160,
                            height: 90,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  const Color(0xFF6366F1).withOpacity(0.3),
                                  const Color(0xFF8B5CF6).withOpacity(0.3),
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                            ),
                            child: const Center(
                              child: Icon(
                                Icons.video_library,
                                size: 32,
                                color: Colors.white,
                              ),
                            ),
                          ),
                    // Play Button Overlay
                    Positioned.fill(
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.1),
                        ),
                        child: const Center(
                          child: Icon(
                            Icons.play_circle_filled,
                            size: 40,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                    // Duration Badge
                    if (video.duration != null)
                      Positioned(
                        bottom: 6,
                        right: 6,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.8),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            video.durationFormatted,
                            style: const TextStyle(
                              fontSize: 10,
                              color: Colors.white,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              // Video Info
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        video.title,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF1A1A1A),
                          height: 1.3,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 8),
                      if (video.group?.name != null) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFF6366F1).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            video.group!.name,
                            style: const TextStyle(
                              fontSize: 11,
                              color: Color(0xFF6366F1),
                              fontWeight: FontWeight.w500,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(height: 8),
                      ],
                      if (video.creatorName.isNotEmpty)
                        Row(
                          children: [
                            Icon(
                              Icons.person_outline,
                              size: 14,
                              color: Colors.grey.shade600,
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                video.creatorName,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade600,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.video_library_outlined,
            size: 64,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 16),
          Text(
            'Tidak ada video tutorial ditemukan',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Coba ubah filter pencarian Anda',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade500,
            ),
          ),
        ],
      ),
    );
  }
}

class _VideoPlayerDialog extends StatefulWidget {
  final VideoTutorial video;

  const _VideoPlayerDialog({required this.video});

  @override
  State<_VideoPlayerDialog> createState() => _VideoPlayerDialogState();
}

class _VideoPlayerDialogState extends State<_VideoPlayerDialog> {
  VideoPlayerController? _controller;
  bool _isInitialized = false;
  bool _hasError = false;
  bool _isFullscreen = false;

  @override
  void initState() {
    super.initState();
    _initializePlayer();
  }

  Future<void> _initializePlayer() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');

      final headers = <String, String>{
        'Accept': 'application/json',
      };

      if (token != null) {
        headers['Authorization'] = 'Bearer $token';
      }

      _controller = VideoPlayerController.networkUrl(
        Uri.parse(widget.video.videoUrl),
        httpHeaders: headers,
      );
      await _controller!.initialize();
      if (mounted) {
        setState(() {
          _isInitialized = true;
        });
        _controller!.play();
        _controller!.addListener(_videoListener);
      }
    } catch (e) {
      print('Error initializing video player: $e');
      if (mounted) {
        setState(() {
          _hasError = true;
        });
      }
    }
  }

  void _videoListener() {
    if (mounted && _controller != null) {
      setState(() {});
    }
  }

  void _toggleFullscreen() {
    if (_isFullscreen) {
      // Exit fullscreen
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.manual,
          overlays: SystemUiOverlay.values);
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
      ]);
      Navigator.of(context).pop();
      setState(() {
        _isFullscreen = false;
      });
    } else {
      // Enter fullscreen
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => _FullscreenVideoPlayer(
            controller: _controller!,
            video: widget.video,
            onExit: () {
              SystemChrome.setEnabledSystemUIMode(SystemUiMode.manual,
                  overlays: SystemUiOverlay.values);
              SystemChrome.setPreferredOrientations([
                DeviceOrientation.portraitUp,
                DeviceOrientation.portraitDown,
              ]);
              setState(() {
                _isFullscreen = false;
              });
            },
          ),
        ),
      );
      setState(() {
        _isFullscreen = true;
      });
    }
  }

  @override
  void dispose() {
    _controller?.removeListener(_videoListener);
    if (!_isFullscreen) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.manual,
          overlays: SystemUiOverlay.values);
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
      ]);
    }
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(16),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.black,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: Colors.white24, width: 1),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.video.title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () {
                      SystemChrome.setEnabledSystemUIMode(SystemUiMode.manual,
                          overlays: SystemUiOverlay.values);
                      SystemChrome.setPreferredOrientations([
                        DeviceOrientation.portraitUp,
                        DeviceOrientation.portraitDown,
                      ]);
                      Navigator.of(context).pop();
                    },
                  ),
                ],
              ),
            ),
            // Video Player
            AspectRatio(
              aspectRatio: 16 / 9,
              child: _hasError
                  ? Container(
                      color: Colors.black,
                      child: const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.error_outline,
                                color: Colors.white, size: 48),
                            SizedBox(height: 16),
                            Text(
                              'Gagal memuat video',
                              style: TextStyle(color: Colors.white),
                            ),
                          ],
                        ),
                      ),
                    )
                  : _isInitialized && _controller != null
                      ? Stack(
                          alignment: Alignment.bottomCenter,
                          children: [
                            VideoPlayer(_controller!),
                            // Video Controls Overlay
                            Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.bottomCenter,
                                  end: Alignment.topCenter,
                                  colors: [
                                    Colors.black.withOpacity(0.7),
                                    Colors.transparent,
                                  ],
                                ),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    VideoProgressIndicator(
                                      _controller!,
                                      allowScrubbing: true,
                                      colors: const VideoProgressColors(
                                        playedColor: Color(0xFF6366F1),
                                        bufferedColor: Colors.white24,
                                        backgroundColor: Colors.white12,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        IconButton(
                                          icon: Icon(
                                            _controller!.value.isPlaying
                                                ? Icons.pause
                                                : Icons.play_arrow,
                                            color: Colors.white,
                                            size: 32,
                                          ),
                                          onPressed: () {
                                            setState(() {
                                              if (_controller!
                                                  .value.isPlaying) {
                                                _controller!.pause();
                                              } else {
                                                _controller!.play();
                                              }
                                            });
                                          },
                                        ),
                                        const SizedBox(width: 16),
                                        Text(
                                          _formatVideoDuration(
                                                  _controller!.value.position) +
                                              ' / ' +
                                              _formatVideoDuration(
                                                  _controller!.value.duration),
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 14,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                        const SizedBox(width: 16),
                                        IconButton(
                                          icon: const Icon(
                                            Icons.fullscreen,
                                            color: Colors.white,
                                            size: 28,
                                          ),
                                          onPressed: _toggleFullscreen,
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        )
                      : Container(
                          color: Colors.black,
                          child: const Center(
                            child: AppLoadingIndicator(
                                size: 24, color: Colors.white),
                          ),
                        ),
            ),
            // Video Info
            Container(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildInfoRow('Group', widget.video.group?.name ?? '-'),
                  const SizedBox(height: 8),
                  _buildInfoRow('Ukuran', widget.video.videoSizeFormatted),
                  const SizedBox(height: 8),
                  _buildInfoRow('Dibuat Oleh', widget.video.creatorName),
                  const SizedBox(height: 8),
                  _buildInfoRow(
                    'Tanggal',
                    widget.video.createdAt != null
                        ? DateFormat('dd MMMM yyyy', 'id_ID')
                            .format(widget.video.createdAt!)
                        : '-',
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 100,
          child: Text(
            '$label:',
            style: TextStyle(
              color: Colors.grey.shade400,
              fontSize: 12,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
            ),
          ),
        ),
      ],
    );
  }

  String _formatVideoDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final hours = twoDigits(duration.inHours);
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));

    if (duration.inHours > 0) {
      return '$hours:$minutes:$seconds';
    }
    return '$minutes:$seconds';
  }
}

class _FullscreenVideoPlayer extends StatefulWidget {
  final VideoPlayerController controller;
  final VideoTutorial video;
  final VoidCallback onExit;

  const _FullscreenVideoPlayer({
    required this.controller,
    required this.video,
    required this.onExit,
  });

  @override
  State<_FullscreenVideoPlayer> createState() => _FullscreenVideoPlayerState();
}

class _FullscreenVideoPlayerState extends State<_FullscreenVideoPlayer> {
  bool _showControls = true;
  bool _controlsTimerActive = false;

  @override
  void initState() {
    super.initState();
    _startControlsTimer();
  }

  void _startControlsTimer() {
    if (_controlsTimerActive) return;
    _controlsTimerActive = true;
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted && _controlsTimerActive) {
        setState(() {
          _showControls = false;
          _controlsTimerActive = false;
        });
      }
    });
  }

  void _toggleControls() {
    setState(() {
      _showControls = !_showControls;
      if (_showControls) {
        _startControlsTimer();
      } else {
        _controlsTimerActive = false;
      }
    });
  }

  String _formatVideoDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final hours = twoDigits(duration.inHours);
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));

    if (duration.inHours > 0) {
      return '$hours:$minutes:$seconds';
    }
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTap: _toggleControls,
        child: Stack(
          children: [
            // Video Player
            Center(
              child: AspectRatio(
                aspectRatio: widget.controller.value.aspectRatio,
                child: VideoPlayer(widget.controller),
              ),
            ),
            // Controls Overlay
            if (_showControls)
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withOpacity(0.7),
                      Colors.transparent,
                      Colors.transparent,
                      Colors.black.withOpacity(0.7),
                    ],
                  ),
                ),
                child: SafeArea(
                  child: Column(
                    children: [
                      // Top Bar
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            IconButton(
                              icon: const Icon(Icons.arrow_back,
                                  color: Colors.white),
                              onPressed: () {
                                widget.onExit();
                                Navigator.of(context).pop();
                              },
                            ),
                            Expanded(
                              child: Text(
                                widget.video.title,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Spacer(),
                      // Bottom Controls
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: [
                            VideoProgressIndicator(
                              widget.controller,
                              allowScrubbing: true,
                              colors: const VideoProgressColors(
                                playedColor: Color(0xFF6366F1),
                                bufferedColor: Colors.white24,
                                backgroundColor: Colors.white12,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                IconButton(
                                  icon: Icon(
                                    widget.controller.value.isPlaying
                                        ? Icons.pause
                                        : Icons.play_arrow,
                                    color: Colors.white,
                                    size: 40,
                                  ),
                                  onPressed: () {
                                    setState(() {
                                      if (widget.controller.value.isPlaying) {
                                        widget.controller.pause();
                                      } else {
                                        widget.controller.play();
                                      }
                                    });
                                    _startControlsTimer();
                                  },
                                ),
                                const SizedBox(width: 24),
                                Text(
                                  _formatVideoDuration(
                                          widget.controller.value.position) +
                                      ' / ' +
                                      _formatVideoDuration(
                                          widget.controller.value.duration),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(width: 24),
                                IconButton(
                                  icon: const Icon(
                                    Icons.fullscreen_exit,
                                    color: Colors.white,
                                    size: 32,
                                  ),
                                  onPressed: () {
                                    widget.onExit();
                                    Navigator.of(context).pop();
                                  },
                                ),
                              ],
                            ),
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
  }
}
