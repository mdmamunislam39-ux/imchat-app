import 'package:flutter/material.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
class YoutubeSelectionSheet extends StatefulWidget {
  final Function(String videoId) onVideoSelected;

  const YoutubeSelectionSheet({
    super.key,
    required this.onVideoSelected,
  }) ;

  @override
  State<YoutubeSelectionSheet> createState() => _YoutubeSelectionSheetState();
}

class _YoutubeSelectionSheetState extends State<YoutubeSelectionSheet> {
  final TextEditingController _searchController = TextEditingController();
  final YoutubeExplode _yt = YoutubeExplode();
  
  bool _isLoading = false;
  List<Video> _searchResults = [];
  
  // Hardcoded trending/default videos for fallback or initial state
  final List<String> _trendingVideoIds = [
    'dQw4w9WgXcQ', // Example placeholders
    'kJQP7kiw5Fk',
    'JGwWNGJdvx8',
  ];

  @override
  void dispose() {
    _searchController.dispose();
    _yt.close();
    super.dispose();
  }

  Future<void> _searchVideos(String query) async {
    if (query.isEmpty) return;
    
    // Check if it's a direct URL
    final regex = RegExp(r'(?:youtube\.com\/(?:[^\/]+\/.+\/|(?:v|e(?:mbed)?)\/|.*[?&]v=)|youtu\.be\/)([^"&?\/\s]{11})', caseSensitive: false);
    final match = regex.firstMatch(query);
    final videoId = match?.group(1);
    
    if (videoId != null) {
      widget.onVideoSelected(videoId);
      Navigator.pop(context);
      return;
    }
    
    setState(() {
      _isLoading = true;
    });
    
    try {
      final searchList = await _yt.search.search(query);
      setState(() {
        _searchResults = searchList.take(15).toList();
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error searching videos: $e')),
        );
      }
    }
  }

  Widget _buildVideoTile(String title, String author, String thumbnail, String videoId) {
    return ListTile(
      leading: Image.network(
        thumbnail,
        width: 80,
        height: 60,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => Container(width: 80, height: 60, color: Colors.grey[800]),
      ),
      title: Text(
        title,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontSize: 14, color: Colors.white),
      ),
      subtitle: Text(
        author,
        style: TextStyle(fontSize: 12, color: Colors.grey[400]),
      ),
      onTap: () {
        widget.onVideoSelected(videoId);
        Navigator.pop(context);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFF1E1E2C),
      borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.7,
        child: DefaultTabController(
        length: 2,
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: Colors.white12)),
              ),
              child: const TabBar(
                indicatorColor: Colors.red,
                labelColor: Colors.white,
                unselectedLabelColor: Colors.grey,
                tabs: [
                  Tab(text: 'Trending'),
                  Tab(text: 'Search'),
                ],
              ),
            ),
            Expanded(
              child: TabBarView(
                children: [
                  // Trending Tab
                  ListView.builder(
                    padding: const EdgeInsets.all(8),
                    itemCount: _trendingVideoIds.length,
                    itemBuilder: (context, index) {
                      final vid = _trendingVideoIds[index];
                      // Just using a generic placeholder since loading 15 full video objects takes time
                      return _buildVideoTile(
                        'Trending Video ${index + 1}',
                        'Popular Channel',
                        'https://img.youtube.com/vi/$vid/0.jpg',
                        vid,
                      );
                    },
                  ),
                  
                  // Search Tab
                  Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _searchController,
                                style: const TextStyle(color: Colors.white),
                                decoration: InputDecoration(
                                  hintText: 'Paste YouTube link or search...',
                                  hintStyle: TextStyle(color: Colors.grey[500]),
                                  filled: true,
                                  fillColor: Colors.grey[850],
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(30),
                                    borderSide: BorderSide.none,
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                                ),
                                onSubmitted: _searchVideos,
                              ),
                            ),
                            const SizedBox(width: 8),
                            IconButton(
                              icon: const Icon(Icons.search, color: Colors.red),
                              onPressed: () => _searchVideos(_searchController.text),
                            ),
                          ],
                        ),
                      ),
                      if (_isLoading)
                        const Padding(
                          padding: EdgeInsets.all(20.0),
                          child: CircularProgressIndicator(color: Colors.red),
                        )
                      else
                        Expanded(
                          child: _searchResults.isEmpty
                              ? Center(
                                  child: Text(
                                    'No results',
                                    style: TextStyle(color: Colors.grey[500]),
                                  ),
                                )
                              : ListView.builder(
                                  padding: const EdgeInsets.all(8),
                                  itemCount: _searchResults.length,
                                  itemBuilder: (context, index) {
                                    final video = _searchResults[index];
                                    return _buildVideoTile(
                                      video.title,
                                      video.author,
                                      video.thumbnails.mediumResUrl,
                                      video.id.value,
                                    );
                                  },
                                ),
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
    );
  }
}
