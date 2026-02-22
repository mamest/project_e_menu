import 'package:flutter/material.dart';
import '../services/unsplash_service.dart';

/// A dialog that lets users search Unsplash and pick a photo.
/// Returns the selected regular-size image URL, or null if cancelled.
class UnsplashPickerDialog extends StatefulWidget {
  final String initialQuery;

  const UnsplashPickerDialog({super.key, required this.initialQuery});

  /// Convenience method: shows the dialog and returns the chosen URL or null.
  static Future<String?> show(BuildContext context, {String initialQuery = 'restaurant food'}) {
    return showDialog<String>(
      context: context,
      builder: (_) => UnsplashPickerDialog(initialQuery: initialQuery),
    );
  }

  @override
  State<UnsplashPickerDialog> createState() => _UnsplashPickerDialogState();
}

class _UnsplashPickerDialogState extends State<UnsplashPickerDialog> {
  late final TextEditingController _searchController;
  List<Map<String, String>> _photos = [];
  bool _loading = false;
  String? _selectedUrl;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController(text: widget.initialQuery);
    _search(widget.initialQuery);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _search(String query) async {
    if (query.trim().isEmpty) return;
    setState(() => _loading = true);
    final results = await UnsplashService.searchImages(query.trim(), count: 12);
    if (mounted) setState(() { _photos = results; _loading = false; });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 780, maxHeight: 620),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.fromLTRB(20, 16, 8, 12),
              decoration: const BoxDecoration(
                color: Colors.teal,
                borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.image_search, color: Colors.white),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'Choose a Photo from Unsplash',
                      style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),

            // Search bar
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
                      onSubmitted: _search,
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () => _search(_searchController.text),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.teal,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                    child: const Text('Search'),
                  ),
                ],
              ),
            ),

            // Photo grid
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator(color: Colors.teal))
                  : _photos.isEmpty
                      ? Center(
                          child: Text(
                            'No results. Try a different search.',
                            style: TextStyle(color: Colors.grey[600]),
                          ),
                        )
                      : Padding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
                          child: GridView.builder(
                            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 4,
                              crossAxisSpacing: 8,
                              mainAxisSpacing: 8,
                              childAspectRatio: 1.5,
                            ),
                            itemCount: _photos.length,
                            itemBuilder: (context, index) {
                              final photo = _photos[index];
                              final isSelected = _selectedUrl == photo['url'];
                              return GestureDetector(
                                onTap: () => setState(() => _selectedUrl = photo['url']),
                                child: Stack(
                                  fit: StackFit.expand,
                                  children: [
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(6),
                                      child: Image.network(
                                        photo['thumbUrl']!,
                                        fit: BoxFit.cover,
                                        loadingBuilder: (_, child, progress) =>
                                            progress == null ? child : Container(color: Colors.grey[200]),
                                        errorBuilder: (_, __, ___) => Container(
                                          color: Colors.grey[200],
                                          child: const Icon(Icons.broken_image, color: Colors.grey),
                                        ),
                                      ),
                                    ),
                                    // selection highlight
                                    AnimatedContainer(
                                      duration: const Duration(milliseconds: 150),
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(
                                          color: isSelected ? Colors.teal : Colors.transparent,
                                          width: 3,
                                        ),
                                        color: isSelected ? Colors.teal.withOpacity(0.15) : Colors.transparent,
                                      ),
                                    ),
                                    if (isSelected)
                                      Positioned(
                                        top: 4,
                                        right: 4,
                                        child: Container(
                                          decoration: const BoxDecoration(
                                            color: Colors.teal,
                                            shape: BoxShape.circle,
                                          ),
                                          padding: const EdgeInsets.all(2),
                                          child: const Icon(Icons.check, color: Colors.white, size: 14),
                                        ),
                                      ),
                                    // photographer credit
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
                                          photo['photographer'] ?? '',
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
                        ),
            ),

            // Footer: attribution + actions
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
              child: Row(
                children: [
                  Text(
                    'Photos by Unsplash',
                    style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: _selectedUrl == null ? null : () => Navigator.pop(context, _selectedUrl),
                    icon: const Icon(Icons.check),
                    label: const Text('Use this photo'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.teal,
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
}
