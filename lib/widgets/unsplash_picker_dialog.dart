import 'package:flutter/material.dart';
import '../services/unsplash_service.dart';
import '../services/google_places_service.dart';

/// A dialog that lets users search Unsplash and pick a photo,
/// and optionally browse Google Places photos for the restaurant.
///
/// Returns:
/// - An Unsplash image URL (regular size), or
/// - A `'gphoto:<photoName>'` string when a Google photo is selected.
/// - `null` if cancelled.
class UnsplashPickerDialog extends StatefulWidget {
  final String initialQuery;
  final List<String>? googlePhotoNames;
  final GooglePlacesService? googlePlacesService;

  const UnsplashPickerDialog({
    super.key,
    required this.initialQuery,
    this.googlePhotoNames,
    this.googlePlacesService,
  });

  /// Convenience method: shows the dialog and returns the chosen URL/token or null.
  static Future<String?> show(
    BuildContext context, {
    String initialQuery = 'restaurant food',
    List<String>? googlePhotoNames,
    GooglePlacesService? googlePlacesService,
  }) {
    return showDialog<String>(
      context: context,
      builder: (_) => UnsplashPickerDialog(
        initialQuery: initialQuery,
        googlePhotoNames: googlePhotoNames,
        googlePlacesService: googlePlacesService,
      ),
    );
  }

  @override
  State<UnsplashPickerDialog> createState() => _UnsplashPickerDialogState();
}

class _UnsplashPickerDialogState extends State<UnsplashPickerDialog>
    with SingleTickerProviderStateMixin {
  late final TextEditingController _searchController;
  late final TabController _tabController;

  // Unsplash tab state
  List<Map<String, String>> _photos = [];
  bool _loadingUnsplash = false;
  String? _unsplashError;

  // Google tab state
  List<String?> _googleUris = []; // null = loading placeholder
  bool _googleLoaded = false;

  String? _selectedUrl; // unsplash URL
  String? _selectedGoogleName; // google photo name

  bool get _hasGoogleTab =>
      widget.googlePhotoNames != null &&
      widget.googlePhotoNames!.isNotEmpty &&
      widget.googlePlacesService != null;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
        length: _hasGoogleTab ? 2 : 1, vsync: this);
    _searchController = TextEditingController(text: widget.initialQuery);
    _searchUnsplash(widget.initialQuery);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _searchUnsplash(String query) async {
    if (query.trim().isEmpty) return;
    setState(() { _loadingUnsplash = true; _unsplashError = null; });
    try {
      final results = await UnsplashService.searchImages(query.trim(), count: 12);
      if (mounted) {
        setState(() {
          _photos = results;
          _loadingUnsplash = false;
          if (results.isEmpty) _unsplashError = 'No results. Try a different search term.';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loadingUnsplash = false;
          _unsplashError = 'Failed to load photos: $e';
        });
      }
    }
  }

  Future<void> _loadGooglePhotos() async {
    if (_googleLoaded) return;
    final names = widget.googlePhotoNames!;
    setState(() {
      _googleUris = List.filled(names.length, null);
    });
    final uris = await Future.wait(
      names.map((n) => widget.googlePlacesService!.getPhotoUri(n)),
    );
    if (mounted) {
      setState(() {
        _googleUris = uris;
        _googleLoaded = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 780, maxHeight: 640),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.fromLTRB(20, 16, 8, 0),
              decoration: const BoxDecoration(
                color: Color(0xFF7C3AED),
                borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.image_search, color: Colors.white),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Text(
                          'Choose a Photo',
                          style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  if (_hasGoogleTab)
                    TabBar(
                      controller: _tabController,
                      labelColor: Colors.white,
                      unselectedLabelColor: Colors.white54,
                      indicatorColor: Colors.white,
                      onTap: (i) {
                        if (i == 1 && !_googleLoaded) _loadGooglePhotos();
                      },
                      tabs: const [
                        Tab(text: 'Unsplash'),
                        Tab(text: 'Google Photos'),
                      ],
                    ),
                ],
              ),
            ),

            // Body
            Expanded(
              child: _hasGoogleTab
                  ? TabBarView(
                      controller: _tabController,
                      children: [
                        _buildUnsplashTab(),
                        _buildGoogleTab(),
                      ],
                    )
                  : _buildUnsplashTab(),
            ),

            // Footer
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
              child: Row(
                children: [
                  Text(
                    'Photos by Unsplash & Google',
                    style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: (_selectedUrl == null && _selectedGoogleName == null)
                        ? null
                        : () {
                            if (_selectedGoogleName != null) {
                              Navigator.pop(context, 'gphoto:$_selectedGoogleName');
                            } else {
                              Navigator.pop(context, _selectedUrl);
                            }
                          },
                    icon: const Icon(Icons.check),
                    label: const Text('Use this photo'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF7C3AED),
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUnsplashTab() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search photos…',
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    isDense: true,
                  ),
                  onSubmitted: _searchUnsplash,
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: () => _searchUnsplash(_searchController.text),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF7C3AED),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
                child: const Text('Search'),
              ),
            ],
          ),
        ),
        Expanded(
          child: _loadingUnsplash
              ? const Center(child: CircularProgressIndicator(color: Color(0xFF7C3AED)))
              : _unsplashError != null
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.image_not_supported_outlined, size: 48, color: Colors.grey[400]),
                            const SizedBox(height: 12),
                            Text(_unsplashError!, textAlign: TextAlign.center, style: TextStyle(color: Colors.grey[600])),
                            const SizedBox(height: 12),
                            ElevatedButton(
                              onPressed: () => _searchUnsplash(_searchController.text),
                              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF7C3AED), foregroundColor: Colors.white),
                              child: const Text('Retry'),
                            ),
                          ],
                        ),
                      ),
                    )
                  : _buildPhotoGrid(
                      photos: _photos.map((p) => _GridPhoto(url: p['url']!, thumbUrl: p['thumbUrl']!, label: p['photographer'] ?? '')).toList(),
                      selectedUrl: _selectedUrl,
                      onTap: (photo) => setState(() {
                        _selectedUrl = photo.url;
                        _selectedGoogleName = null;
                      }),
                    ),
        ),
      ],
    );
  }

  Widget _buildGoogleTab() {
    if (!_googleLoaded && _googleUris.isEmpty) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFF7C3AED)));
    }
    final names = widget.googlePhotoNames!;
    final photos = List.generate(_googleUris.length, (i) {
      final uri = _googleUris[i];
      return _GridPhoto(
        url: names[i],
        thumbUrl: uri ?? '',
        label: 'Google photo ${i + 1}',
        loading: uri == null,
      );
    });
    return _buildPhotoGrid(
      photos: photos,
      selectedUrl: _selectedGoogleName,
      onTap: (photo) {
        if (photo.loading) return;
        setState(() {
          _selectedGoogleName = photo.url; // photo.url is the photo name
          _selectedUrl = null;
        });
      },
    );
  }

  Widget _buildPhotoGrid({
    required List<_GridPhoto> photos,
    required String? selectedUrl,
    required void Function(_GridPhoto) onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
      child: GridView.builder(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 4,
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
          childAspectRatio: 1.5,
        ),
        itemCount: photos.length,
        itemBuilder: (context, index) {
          final photo = photos[index];
          final isSelected = selectedUrl == photo.url;
          return GestureDetector(
            onTap: () => onTap(photo),
            child: Stack(
              fit: StackFit.expand,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: photo.loading
                      ? Container(color: Colors.grey[200], child: const Center(child: CircularProgressIndicator(strokeWidth: 2)))
                      : photo.thumbUrl.isEmpty
                          ? Container(color: Colors.grey[200], child: const Icon(Icons.broken_image, color: Colors.grey))
                          : Image.network(
                              photo.thumbUrl,
                              fit: BoxFit.cover,
                              loadingBuilder: (_, child, progress) =>
                                  progress == null ? child : Container(color: Colors.grey[200]),
                              errorBuilder: (_, __, ___) => Container(
                                color: Colors.grey[200],
                                child: const Icon(Icons.broken_image, color: Colors.grey),
                              ),
                            ),
                ),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: isSelected ? const Color(0xFF7C3AED) : Colors.transparent,
                      width: 3,
                    ),
                    color: isSelected ? const Color(0xFF7C3AED).withOpacity(0.15) : Colors.transparent,
                  ),
                ),
                if (isSelected)
                  Positioned(
                    top: 4,
                    right: 4,
                    child: Container(
                      decoration: const BoxDecoration(
                        color: Color(0xFF7C3AED),
                        shape: BoxShape.circle,
                      ),
                      padding: const EdgeInsets.all(2),
                      child: const Icon(Icons.check, color: Colors.white, size: 14),
                    ),
                  ),
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                    decoration: BoxDecoration(
                      borderRadius: const BorderRadius.vertical(bottom: Radius.circular(6)),
                      gradient: LinearGradient(
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                        colors: [Colors.black.withOpacity(0.6), Colors.transparent],
                      ),
                    ),
                    child: Text(
                      photo.label,
                      style: const TextStyle(color: Colors.white, fontSize: 8),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _GridPhoto {
  final String url;
  final String thumbUrl;
  final String label;
  final bool loading;
  const _GridPhoto({required this.url, required this.thumbUrl, required this.label, this.loading = false});
}
