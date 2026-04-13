import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../l10n/app_localizations.dart';
import '../models/cart.dart';
import '../utils/payment_utils.dart';
import '../models/deal.dart';
import '../models/menu_item.dart';
import '../models/restaurant.dart';
import '../services/html_menu_service.dart';
import '../services/unsplash_service.dart';
import '../services/google_places_service.dart';

class MenuPage extends StatefulWidget {
  final Restaurant restaurant;

  const MenuPage({super.key, required this.restaurant});

  @override
  State<MenuPage> createState() => _MenuPageState();
}

class _MenuPageState extends State<MenuPage> {
  List<Category> categories = [];
  List<Deal> _activeDeals = []; // today-filtered (for price discounts)
  List<Deal> _allDeals = [];   // all active=true (for display banner)
  bool loading = true;
  String? errorMessage;
  late final Cart cart;

  // Google Places photos — fetched lazily from the edge function
  final GooglePlacesService _googlePlacesService = GooglePlacesService();
  List<String> _googlePhotoUris = [];
  bool _googlePhotosLoaded = false;

  @override
  void initState() {
    super.initState();
    cart = CartManager().getCartForRestaurant(widget.restaurant.id);
    _loadMenu();
    if (widget.restaurant.googlePlaceId != null &&
        widget.restaurant.googleData['photo_names'] != null) {
      _loadGooglePhotos();
    }
  }

  // Natural sort comparison for item numbers (handles "1", "2", "10", "1a", "2b" etc.)
  int _compareItemNumbers(String? a, String? b) {
    if (a == null && b == null) return 0;
    if (a == null) return 1;
    if (b == null) return -1;

    // Extract numeric prefix and suffix
    final aMatch = RegExp(r'^(\d+)(.*)$').firstMatch(a);
    final bMatch = RegExp(r'^(\d+)(.*)$').firstMatch(b);

    if (aMatch != null && bMatch != null) {
      final aNum = int.parse(aMatch.group(1)!);
      final bNum = int.parse(bMatch.group(1)!);
      
      if (aNum != bNum) {
        return aNum.compareTo(bNum);
      }
      
      // If numbers are equal, compare suffixes
      final aSuffix = aMatch.group(2) ?? '';
      final bSuffix = bMatch.group(2) ?? '';
      return aSuffix.compareTo(bSuffix);
    }

    // Fallback to string comparison
    return a.compareTo(b);
  }

  Future<void> _loadMenu() async {
    try {
      final response = await Supabase.instance.client
          .from('categories')
          .select(
              'id, name, display_order, image_url, translations, items(id, name, item_number, price, description, available, has_variants, translations, item_variants(id, name, price, display_order))')
          .eq('restaurant_id', widget.restaurant.id)
          .order('display_order');

      if (response is List) {
        final cats = response.map((c) {
          final items = (c['items'] as List?)?.map((i) {
                final variants = (i['item_variants'] as List?)
                        ?.map((v) =>
                            ItemVariant.fromJson(v as Map<String, dynamic>))
                        .toList() ??
                    [];
                variants
                    .sort((a, b) => a.displayOrder.compareTo(b.displayOrder));
                return MenuItem.fromJson(i as Map<String, dynamic>, variants);
              }).toList() ??
              [];
          // Sort items by item_number
          items.sort((a, b) => _compareItemNumbers(a.itemNumber, b.itemNumber));
          return Category(
            id: c['id'] as int,
            name: c['name'] as String,
            items: items,
            imageUrl: c['image_url'] as String?,
            translations: (c['translations'] as Map?)?.cast<String, dynamic>() ?? {},
          );
        }).toList();

        // Filter out empty categories
        final nonEmptyCats = cats.where((cat) => cat.items.isNotEmpty).toList();

        // Sort categories by the minimum item_number in each category
        nonEmptyCats.sort((a, b) {
          // Get first (minimum) item number from each category
          final aMinNum = a.items.isNotEmpty ? a.items.first.itemNumber : null;
          final bMinNum = b.items.isNotEmpty ? b.items.first.itemNumber : null;
          return _compareItemNumbers(aMinNum, bMinNum);
        });

        // Load today's active deals
        final dealsData = await Supabase.instance.client
            .from('deals')
            .select(
                'id, restaurant_id, title, description, discount_type, discount_value, applies_to, day_of_week, valid_from, valid_until, active, deal_categories(category_id), deal_items(item_id)')
            .eq('restaurant_id', widget.restaurant.id)
            .eq('active', true);
        final allDeals = (dealsData as List)
            .map((d) => Deal.fromJson(d as Map<String, dynamic>))
            .toList();
        final todayDeals = allDeals.where((d) => d.isActiveToday).toList();

        setState(() {
          categories = nonEmptyCats;
          _allDeals = allDeals;
          _activeDeals = todayDeals;
          loading = false;
        });
        _loadCategoryImages();
      }
    } catch (e) {
      setState(() {
        errorMessage = AppLocalizations.of(context)!.errorLoadingMenu(e.toString());
        loading = false;
      });
    }
  }

  // One solid accent color per category
  static const List<Color> _kCategoryColors = [
    Color(0xFF7C3AED), // violet
    Color(0xFF6D28D9), // deep violet
    Color(0xFF8B5CF6), // light violet
    Color(0xFF9333EA), // purple
    Color(0xFF4F46E5), // indigo
    Color(0xFFA855F7), // lavender
    Color(0xFF5B21B6), // dark violet
    Color(0xFF6366F1), // indigo-blue
  ];

  Future<void> _loadCategoryImages() async {
    // Only fetch from Unsplash for categories that have no image_url from the DB
    final needsImage = categories.where((c) => c.imageUrl == null || c.imageUrl!.isEmpty).toList();
    if (needsImage.isEmpty) return;
    final updated = await Future.wait(
      categories.map((cat) async {
        if (cat.imageUrl != null && cat.imageUrl!.isNotEmpty) return cat;
        final img = await UnsplashService.getCategoryImage(cat.name);
        return cat.copyWith(imageUrl: img);
      }),
    );
    if (mounted) setState(() => categories = updated);
  }

  /// Returns the first active deal that applies to [itemId] in [categoryId],
  /// or null if no deal applies today.
  Deal? _dealForItem(int itemId, int categoryId) {
    for (final deal in _activeDeals) {
      if (deal.appliesToItem(itemId, categoryId)) return deal;
    }
    return null;
  }

  String _dayLabel(int day) {
    final l10n = AppLocalizations.of(context)!;
    switch (day) {
      case 1: return l10n.dayMonday;
      case 2: return l10n.dayTuesday;
      case 3: return l10n.dayWednesday;
      case 4: return l10n.dayThursday;
      case 5: return l10n.dayFriday;
      case 6: return l10n.daySaturday;
      case 7: return l10n.daySunday;
      default: return '';
    }
  }

  Future<void> _loadGooglePhotos() async {
    final photoNames = widget.restaurant.googleData['photo_names'];
    if (photoNames == null) return;
    final names = List<String>.from(photoNames as List);
    final uris = await Future.wait(
      names.map((n) => _googlePlacesService.getPhotoUri(n)),
    );
    if (mounted) {
      setState(() {
        _googlePhotoUris = uris.whereType<String>().toList();
        _googlePhotosLoaded = true;
      });
    }
  }

  Widget _buildGoogleSection() {
    final data = widget.restaurant.googleData;
    final rating = data['rating'] != null ? (data['rating'] as num).toDouble() : null;
    final reviewCount = data['user_rating_count'] as int?;
    final mapsUri = data['google_maps_uri'] as String?;
    final reviews = (data['reviews'] as List?)
            ?.map((r) => (r as Map).cast<String, dynamic>())
            .toList() ??
        [];

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row
          Row(
            children: [
              const Text(
                'G',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF4285F4),
                ),
              ),
              const SizedBox(width: 6),
              if (rating != null) ...[
                _buildStars(rating),
                const SizedBox(width: 6),
                Text(
                  rating.toStringAsFixed(1),
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
                if (reviewCount != null) ...[
                  const SizedBox(width: 4),
                  Text(
                    '($reviewCount)',
                    style: const TextStyle(color: Colors.black54, fontSize: 13),
                  ),
                ],
              ],
              const Spacer(),
              if (mapsUri != null)
                TextButton.icon(
                  onPressed: () => launchUrl(Uri.parse(mapsUri)),
                  icon: const Icon(Icons.open_in_new, size: 14),
                  label: const Text('Google Maps', style: TextStyle(fontSize: 13)),
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFF4285F4),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  ),
                ),
            ],
          ),

          // Photo strip
          if (_googlePhotosLoaded && _googlePhotoUris.isNotEmpty) ...[
            const SizedBox(height: 8),
            SizedBox(
              height: 110,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _googlePhotoUris.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, i) => ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    _googlePhotoUris[i],
                    width: 150,
                    height: 110,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                  ),
                ),
              ),
            ),
          ] else if (!_googlePhotosLoaded &&
              widget.restaurant.googleData['photo_names'] != null) ...[
            const SizedBox(height: 8),
            const SizedBox(
              height: 110,
              child: Center(
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            ),
          ],

          // Reviews
          if (reviews.isNotEmpty) ...[
            const SizedBox(height: 8),
            ...reviews.take(3).map((r) => _buildReviewCard(r)),
          ],
        ],
      ),
    );
  }

  Widget _buildStars(double rating) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (i) {
        if (rating >= i + 1) return const Icon(Icons.star, color: Colors.amber, size: 16);
        if (rating >= i + 0.5) return const Icon(Icons.star_half, color: Colors.amber, size: 16);
        return const Icon(Icons.star_border, color: Colors.amber, size: 16);
      }),
    );
  }

  Widget _buildReviewCard(Map<String, dynamic> review) {
    final rating = (review['rating'] as num?)?.toInt() ?? 0;
    final text = review['text'] as String? ?? '';
    final author = review['author_name'] as String? ?? '';
    final time = review['relative_publish_time_description'] as String? ?? '';
    final photoUri = review['author_photo_uri'] as String?;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (photoUri != null)
                  CircleAvatar(
                    radius: 12,
                    backgroundImage: NetworkImage(photoUri),
                    onBackgroundImageError: (_, __) {},
                  )
                else
                  const CircleAvatar(
                    radius: 12,
                    child: Icon(Icons.person, size: 14),
                  ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(author,
                          style: const TextStyle(
                              fontWeight: FontWeight.w500, fontSize: 13)),
                      Text(time,
                          style: const TextStyle(
                              color: Colors.black54, fontSize: 11)),
                    ],
                  ),
                ),
                _buildStars(rating.toDouble()),
              ],
            ),
            if (text.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                text,
                style: const TextStyle(fontSize: 13, color: Colors.black87),
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDealsSection() {
    final l10n = AppLocalizations.of(context)!;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(Icons.local_offer, color: Color(0xFF7C3AED), size: 20),
            const SizedBox(width: 8),
            Text(l10n.dealsTab,
                style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF7C3AED))),
          ]),
          const SizedBox(height: 8),
          SizedBox(
            height: 108,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _allDeals.length,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (context, i) => _buildDealChip(_allDeals[i]),
            ),
          ),
          const SizedBox(height: 4),
          const Divider(),
        ],
      ),
    );
  }

  Widget _buildDealChip(Deal deal) {
    final l10n = AppLocalizations.of(context)!;
    final isToday = deal.isActiveToday;
    final dayText = (deal.dayOfWeek == null || deal.dayOfWeek!.isEmpty)
        ? l10n.dealEveryDay
        : deal.dayOfWeek!.map(_dayLabel).join(', ');

    return Container(
      width: 180,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isToday ? const Color(0xFF7C3AED) : Colors.white,
        border: Border.all(
            color: isToday ? const Color(0xFF7C3AED) : Colors.grey.shade300),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 4,
              offset: const Offset(0, 2))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Expanded(
              child: Text(
                deal.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: isToday ? Colors.white : Colors.black87),
              ),
            ),
            if (isToday)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.25),
                    borderRadius: BorderRadius.circular(6)),
                child: Text('Now',
                    style: const TextStyle(
                        fontSize: 9,
                        color: Colors.white,
                        fontWeight: FontWeight.bold)),
              ),
          ]),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: isToday
                  ? Colors.white.withOpacity(0.25)
                  : Colors.orange.shade50,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              deal.discountLabel,
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: isToday ? Colors.white : Colors.orange.shade800),
            ),
          ),
          const SizedBox(height: 6),
          Row(children: [
            Icon(Icons.calendar_today,
                size: 11,
                color: isToday ? Colors.white70 : Colors.grey),
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                dayText,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    fontSize: 11,
                    color: isToday ? Colors.white70 : Colors.grey[600]),
              ),
            ),
          ]),
        ],
      ),
    );
  }

  Widget _buildCategoryTile(Category cat, int idx) {
    final Color color = _kCategoryColors[idx % _kCategoryColors.length];
    final availableItems = cat.items.where((i) => i.available).toList();
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      elevation: 2,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: idx == 0,
          tilePadding: EdgeInsets.zero,
          iconColor: Colors.white,
          collapsedIconColor: Colors.white,
          title: _buildCategoryHeader(cat, color, availableItems.length),
          children: availableItems.map((item) => _buildItemTile(item, color, cat.id)).toList(),
        ),
      ),
    );
  }

  Widget _buildCategoryHeader(Category cat, Color color, int count) {
    return SizedBox(
      height: 90,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (cat.imageUrl != null)
            Image.network(
              cat.imageUrl!,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(color: color),
            )
          else
            Container(color: color),
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.transparent, Colors.black.withOpacity(0.55)],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 52, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(
                  cat.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    shadows: [Shadow(blurRadius: 4, color: Colors.black38)],
                  ),
                ),
                const SizedBox(height: 3),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.25),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.white.withOpacity(0.5), width: 0.5),
                  ),
                  child: Text(AppLocalizations.of(context)!.itemCount(count),
                      style: const TextStyle(color: Colors.white, fontSize: 11)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildItemTile(MenuItem item, Color catColor, int categoryId) {
    if (item.hasVariants && item.variants.isNotEmpty) {
      return _buildVariantItem(item, catColor, categoryId);
    }
    return _buildSimpleItem(item, catColor, categoryId);
  }

  Widget _buildSimpleItem(MenuItem item, Color catColor, int categoryId) {
    final locale = Localizations.localeOf(context).languageCode;
    final deal = _dealForItem(item.id, categoryId);
    final discountedPrice =
        deal != null && item.price != null
            ? deal.computeDiscountedPrice(item.price!)
            : null;
    final effectivePrice = discountedPrice ?? item.price;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
      title: Row(children: [
        if (item.itemNumber != null && item.itemNumber!.isNotEmpty) ...[  
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
            margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              color: catColor,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(item.itemNumber!,
                style: const TextStyle(
                    fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white)),
          ),
        ],
        Expanded(
            child: Text(item.localizedName(locale),
                style: const TextStyle(fontWeight: FontWeight.w500))),
      ]),
      subtitle: item.localizedDescription(locale)?.isNotEmpty == true
          ? Text(item.localizedDescription(locale)!)
          : null,
      trailing: effectivePrice != null
          ? Row(mainAxisSize: MainAxisSize.min, children: [
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (discountedPrice != null)
                    Text(
                      '\u20ac${item.price!.toStringAsFixed(2)}',
                      style: const TextStyle(
                          fontSize: 11,
                          decoration: TextDecoration.lineThrough,
                          color: Colors.grey),
                    ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: discountedPrice != null
                          ? Colors.green[700]
                          : const Color(0xFF7C3AED),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text('\u20ac${effectivePrice.toStringAsFixed(2)}',
                        style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.white)),
                  ),
                  if (discountedPrice != null && deal != null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 5, vertical: 1),
                      decoration: BoxDecoration(
                        color: Colors.orange[700],
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(deal.discountLabel,
                          style: const TextStyle(
                              fontSize: 10,
                              color: Colors.white,
                              fontWeight: FontWeight.bold)),
                    ),
                ],
              ),
              const SizedBox(width: 6),
              IconButton(
                icon: Icon(Icons.add_shopping_cart, color: catColor),
                onPressed: () {
                  setState(() {
                    cart.addItem(CartItem(
                      itemId: item.id,
                      itemName: item.name,
                      itemNumber: item.itemNumber,
                      variantId: null,
                      variantName: null,
                      price: effectivePrice,
                      quantity: 1,
                    ));
                  });
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text(AppLocalizations.of(context)!.addedToCart(item.name)),
                    duration: const Duration(seconds: 1),
                  ));
                },
              ),
            ])
          : null,
    );
  }

  Widget _buildVariantItem(MenuItem item, Color catColor, int categoryId) {
    final locale = Localizations.localeOf(context).languageCode;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                if (item.itemNumber != null && item.itemNumber!.isNotEmpty) ...[  
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    margin: const EdgeInsets.only(right: 8),
                    decoration: BoxDecoration(
                        color: catColor, borderRadius: BorderRadius.circular(6)),
                    child: Text(item.itemNumber!,
                        style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: Colors.white)),
                  ),
                ],
                Expanded(
                    child: Text(item.localizedName(locale),
                        style: const TextStyle(
                            fontWeight: FontWeight.w500, fontSize: 15))),
              ]),
              if (item.localizedDescription(locale)?.isNotEmpty == true)
                Padding(
                  padding: const EdgeInsets.only(top: 3),
                  child: Text(item.localizedDescription(locale)!,
                      style: TextStyle(color: Colors.grey[600], fontSize: 13)),
                ),
            ],
          ),
        ),
        ...item.variants.map((variant) {
              final variantDeal = _dealForItem(item.id, categoryId);
              final discounted = variantDeal != null
                  ? variantDeal.computeDiscountedPrice(variant.price)
                  : null;
              final effectivePrice = discounted ?? variant.price;
              return ListTile(
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 40, vertical: 2),
              title: Text(variant.name, style: const TextStyle(fontSize: 14)),
              trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    if (discounted != null)
                      Text(
                        '\u20ac${variant.price.toStringAsFixed(2)}',
                        style: const TextStyle(
                            fontSize: 10,
                            decoration: TextDecoration.lineThrough,
                            color: Colors.grey),
                      ),
                    Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: discounted != null
                        ? Colors.green[700]
                        : const Color(0xFF7C3AED),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text('\u20ac${effectivePrice.toStringAsFixed(2)}',
                      style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: Colors.white)),
                ),
                  ],
                ),
                const SizedBox(width: 6),
                IconButton(
                  icon:
                      Icon(Icons.add_shopping_cart, color: catColor, size: 20),
                  onPressed: () {
                    setState(() {
                      cart.addItem(CartItem(
                        itemId: item.id,
                        itemName: item.name,
                        itemNumber: item.itemNumber,
                        variantId: variant.id,
                        variantName: variant.name,
                        price: effectivePrice,
                        quantity: 1,
                      ));
                    });
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content:
                          Text(AppLocalizations.of(context)!.addedToCartWithVariant(item.name, variant.name)),
                      duration: const Duration(seconds: 1),
                    ));
                  },
                ),
              ]),
            );
        }),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 24),
          child: Divider(),
        ),
      ],
    );
  }

  void _showRestaurantInfo(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(widget.restaurant.name),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.restaurant.description != null) ...[
                Text(widget.restaurant.description!,
                    style: const TextStyle(fontSize: 14)),
                const SizedBox(height: 16),
              ],
              _buildInfoRow(
                  Icons.location_on, AppLocalizations.of(context)!.addressLabel, widget.restaurant.address),
              if (widget.restaurant.phone != null)
                _buildInfoRow(Icons.phone, AppLocalizations.of(context)!.phoneLabel, widget.restaurant.phone!),
              if (widget.restaurant.email != null)
                _buildInfoRow(Icons.email, AppLocalizations.of(context)!.emailLabel, widget.restaurant.email!),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.delivery_dining,
                      size: 20, color: Colors.grey),
                  const SizedBox(width: 8),
                  Text(
                    widget.restaurant.delivers
                        ? AppLocalizations.of(context)!.deliveryAvailable
                        : AppLocalizations.of(context)!.noDelivery,
                    style: TextStyle(
                      color: widget.restaurant.delivers
                          ? const Color(0xFF7C3AED)
                          : Colors.grey,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              if (widget.restaurant.openingHours != null) ...[
                const SizedBox(height: 16),
                Text(AppLocalizations.of(context)!.openingHoursTitle,
                    style:
                        const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 8),
                ..._buildOpeningHours(),
              ],
              if (widget.restaurant.paymentMethods != null &&
                  widget.restaurant.paymentMethods!.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text(AppLocalizations.of(context)!.paymentMethodsTitle,
                    style:
                        const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: widget.restaurant.paymentMethods!.map((method) {
                    return Chip(
                      label: Text(localizePaymentMethod(method, AppLocalizations.of(context)!)),
                      backgroundColor: const Color(0xFFEDE9FE),
                    );
                  }).toList(),
                ),
              ],
              if (widget.restaurant.menuUpdatedAt != null ||
                  widget.restaurant.updatedAt != null) ...[
                const SizedBox(height: 16),
                Row(
                  children: [
                    const Icon(Icons.update, size: 20, color: Colors.grey),
                    const SizedBox(width: 8),
                    Text(
                      AppLocalizations.of(context)!.menuLastUpdated(
                        DateFormat.yMMMd(
                          Localizations.localeOf(context).languageCode,
                        ).format(
                          (widget.restaurant.menuUpdatedAt ??
                                  widget.restaurant.updatedAt)!
                              .toLocal(),
                        ),
                      ),
                      style: const TextStyle(fontSize: 14, color: Colors.grey),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(AppLocalizations.of(context)!.close),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: Colors.grey),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: const TextStyle(fontSize: 12, color: Colors.grey)),
                Text(value, style: const TextStyle(fontSize: 14)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildOpeningHours() {
    if (widget.restaurant.openingHours == null) return [];
    final l10n = AppLocalizations.of(context)!;

    final days = [
      {'label': l10n.dayMonday, 'key': 'monday'},
      {'label': l10n.dayTuesday, 'key': 'tuesday'},
      {'label': l10n.dayWednesday, 'key': 'wednesday'},
      {'label': l10n.dayThursday, 'key': 'thursday'},
      {'label': l10n.dayFriday, 'key': 'friday'},
      {'label': l10n.daySaturday, 'key': 'saturday'},
      {'label': l10n.daySunday, 'key': 'sunday'},
    ];

    final todayIndex = DateTime.now().weekday - 1;

    return days.asMap().entries.map((entry) {
      final index = entry.key;
      final dayLabel = entry.value['label']!;
      final dayKey = entry.value['key']!;
      final hours = widget.restaurant.openingHours![dayKey];
      final isToday = index == todayIndex;

      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          children: [
            SizedBox(
              width: 90,
              child: Text(
                dayLabel,
                style: TextStyle(
                  fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
                  color: isToday ? const Color(0xFF7C3AED) : Colors.black87,
                ),
              ),
            ),
            Text(
              hours?.toString() ?? AppLocalizations.of(context)!.closed,
              style: TextStyle(
                fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
                color: isToday
                    ? const Color(0xFF7C3AED)
                    : (hours == null ? Colors.red : Colors.black87),
              ),
            ),
          ],
        ),
      );
    }).toList();
  }

  void _showCart(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          return DraggableScrollableSheet(
            initialChildSize: 0.7,
            minChildSize: 0.5,
            maxChildSize: 0.95,
            expand: false,
            builder: (context, scrollController) {
              return Container(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          AppLocalizations.of(context)!.yourCart,
                          style: const TextStyle(
                              fontSize: 24, fontWeight: FontWeight.bold),
                        ),
                        if (cart.items.isNotEmpty)
                          TextButton(
                            onPressed: () {
                              setModalState(() {
                                setState(() {
                                  cart.clear();
                                });
                              });
                            },
                            child: Text(AppLocalizations.of(context)!.clearAll),
                          ),
                      ],
                    ),
                    const Divider(),
                    Expanded(
                      child: cart.items.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.shopping_cart_outlined,
                                      size: 64, color: Colors.grey),
                                  const SizedBox(height: 16),
                                  Text(AppLocalizations.of(context)!.cartEmpty,
                                      style: const TextStyle(
                                          fontSize: 16, color: Colors.grey)),
                                ],
                              ),
                            )
                          : ListView.builder(
                              controller: scrollController,
                              itemCount: cart.items.length,
                              itemBuilder: (context, index) {
                                final cartItem = cart.items[index];
                                return Card(
                                  margin:
                                      const EdgeInsets.symmetric(vertical: 4),
                                  child: Padding(
                                    padding: const EdgeInsets.all(12),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                children: [
                                                  if (cartItem.itemNumber != null && cartItem.itemNumber!.isNotEmpty)
                                                    Container(
                                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                                      margin: const EdgeInsets.only(right: 6),
                                                      decoration: BoxDecoration(
                                                        gradient: LinearGradient(
                                                          colors: [Colors.purple.shade400, Colors.deepPurple.shade500],
                                                        ),
                                                        borderRadius: BorderRadius.circular(6),
                                                      ),
                                                      child: Text(
                                                        cartItem.itemNumber!,
                                                        style: const TextStyle(
                                                          fontSize: 11,
                                                          fontWeight: FontWeight.w700,
                                                          color: Colors.white,
                                                        ),
                                                      ),
                                                    ),
                                                  Expanded(
                                                    child: Text(
                                                      cartItem.itemName,
                                                      style: const TextStyle(
                                                          fontWeight: FontWeight.bold,
                                                          fontSize: 16),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              if (cartItem.variantName != null)
                                                Text(
                                                  cartItem.variantName!,
                                                  style: TextStyle(
                                                      color: Colors.grey[600],
                                                      fontSize: 14),
                                                ),
                                              const SizedBox(height: 4),
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                                decoration: BoxDecoration(
                                                  gradient: LinearGradient(
                                                    colors: [const Color(0xFF8B5CF6), const Color(0xFF7C3AED)],
                                                  ),
                                                  borderRadius: BorderRadius.circular(8),
                                                ),
                                                child: Text(
                                                  '€${cartItem.price.toStringAsFixed(2)}',
                                                  style: const TextStyle(
                                                      color: Colors.white,
                                                      fontWeight:
                                                          FontWeight.bold),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        Row(
                                          children: [
                                            IconButton(
                                              icon: const Icon(
                                                  Icons.remove_circle_outline),
                                              onPressed: () {
                                                setModalState(() {
                                                  setState(() {
                                                    cart.decreaseQuantity(
                                                        cartItem);
                                                  });
                                                });
                                              },
                                            ),
                                            Text(
                                              '${cartItem.quantity}',
                                              style: const TextStyle(
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.bold),
                                            ),
                                            IconButton(
                                              icon: const Icon(
                                                  Icons.add_circle_outline),
                                              onPressed: () {
                                                setModalState(() {
                                                  setState(() {
                                                    cart.increaseQuantity(
                                                        cartItem);
                                                  });
                                                });
                                              },
                                            ),
                                            IconButton(
                                              icon: const Icon(
                                                  Icons.delete_outline,
                                                  color: Colors.red),
                                              onPressed: () {
                                                setModalState(() {
                                                  setState(() {
                                                    cart.removeItem(cartItem);
                                                  });
                                                });
                                              },
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                    ),
                    if (cart.items.isNotEmpty) ...[
                      const Divider(),
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              AppLocalizations.of(context)!.total,
                              style: const TextStyle(
                                  fontSize: 20, fontWeight: FontWeight.bold),
                            ),
                            Text(
                              '€${cart.total.toStringAsFixed(2)}',
                              style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  foreground: Paint()
                                    ..shader = LinearGradient(
                                      colors: [const Color(0xFF7C3AED), const Color(0xFF6D28D9)],
                                    ).createShader(const Rect.fromLTWH(0.0, 0.0, 200.0, 70.0))),
                            ),
                          ],
                        ),
                      ),
                      const Divider(),
                      Padding(
                        padding: const EdgeInsets.only(top: 8, bottom: 4),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              AppLocalizations.of(context)!.orderSectionTitle,
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              AppLocalizations.of(context)!.orderSectionSubtitle,
                              style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      if (widget.restaurant.phone == null && widget.restaurant.email == null)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Text(
                            AppLocalizations.of(context)!.noContactAvailable,
                            style: TextStyle(color: Colors.grey[600], fontSize: 14),
                          ),
                        ),
                      if (widget.restaurant.phone != null) ...[
                        SizedBox(
                          width: double.infinity,
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [Colors.deepPurple.shade400, Colors.purple.shade500],
                              ),
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.purple.withOpacity(0.3),
                                  blurRadius: 8,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: ElevatedButton.icon(
                              onPressed: () async {
                                final uri = Uri(scheme: 'tel', path: widget.restaurant.phone);
                                if (await canLaunchUrl(uri)) {
                                  await launchUrl(uri);
                                }
                              },
                              icon: const Icon(Icons.phone, color: Colors.white),
                              label: Text(
                                '${AppLocalizations.of(context)!.callToOrder}  •  ${widget.restaurant.phone}',
                                style: const TextStyle(fontSize: 15, color: Colors.white, fontWeight: FontWeight.bold),
                              ),
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                backgroundColor: Colors.transparent,
                                shadowColor: Colors.transparent,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                      ],
                      if (widget.restaurant.email != null) ...[
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: () async {
                              final subject = Uri.encodeComponent(
                                AppLocalizations.of(context)!.emailOrderSubject,
                              );
                              final body = Uri.encodeComponent(
                                cart.items.map((item) {
                                  final variant = item.variantName != null ? ' (${item.variantName})' : '';
                                  final num = item.itemNumber != null ? '${item.itemNumber}. ' : '';
                                  return '${item.quantity}x  $num${item.itemName}$variant  –  €${(item.price * item.quantity).toStringAsFixed(2)}';
                                }).join('\n') +
                                '\n\n${AppLocalizations.of(context)!.total} €${cart.total.toStringAsFixed(2)}',
                              );
                              final uri = Uri.parse('mailto:${widget.restaurant.email}?subject=$subject&body=$body');
                              if (await canLaunchUrl(uri)) {
                                await launchUrl(uri);
                              }
                            },
                            icon: const Icon(Icons.email_outlined),
                            label: Text(
                              '${AppLocalizations.of(context)!.emailToOrder}  •  ${widget.restaurant.email}',
                              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                            ),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              side: BorderSide(color: Colors.deepPurple.shade300, width: 1.5),
                              foregroundColor: Colors.deepPurple,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                      ],
                    ],
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [const Color(0xFF6D28D9), const Color(0xFF7C3AED), const Color(0xFF8B5CF6)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: SafeArea(
            child: Center(
              child: Container(
                constraints: const BoxConstraints(maxWidth: 1200),
                child: Row(
                  children: [
                    const BackButton(color: Colors.white),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            widget.restaurant.name,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            widget.restaurant.address,
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.white70,
                            ),
                          ),
                        ],
                      ),
                    ),
    // Designed menu: open saved HTML as a blob so the browser renders it
                    if (widget.restaurant.menuHtmlUrl != null)
                      IconButton(
                        icon: const Icon(Icons.auto_awesome, color: Colors.white),
                        tooltip: AppLocalizations.of(context)!.viewDesignedMenu,
                        onPressed: () async {
                          try {
                            final locale = Localizations.localeOf(context).languageCode;
                            await HtmlMenuService.openStoredHtml(
                                widget.restaurant.menuHtmlUrl!, locale);
                          } catch (e) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Error opening menu: $e'),
                                  backgroundColor: Colors.red,
                                ),
                              );
                            }
                          }
                        },
                      ),
                    IconButton(
                      icon: const Icon(Icons.info_outline, color: Colors.white),
                      onPressed: () {
                        _showRestaurantInfo(context);
                      },
                    ),
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.shopping_cart, color: Colors.white),
                          onPressed: () {
                            _showCart(context);
                          },
                        ),
                        if (cart.itemCount > 0)
                          Positioned(
                            right: 8,
                            top: 8,
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: const BoxDecoration(
                              color: const Color(0xFF7C3AED),
                                shape: BoxShape.circle,
                              ),
                              constraints: const BoxConstraints(
                                minWidth: 20,
                                minHeight: 20,
                              ),
                              child: Text(
                                '${cart.itemCount}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        automaticallyImplyLeading: false,
      ),
      body: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 1200),
          color: const Color(0xFFF5F7FA),
          child: loading
              ? const Center(child: CircularProgressIndicator())
              : errorMessage != null
                  ? Center(
                      child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Text(errorMessage!, textAlign: TextAlign.center),
                    ))
                  : categories.isEmpty
                      ? Center(child: Text(AppLocalizations.of(context)!.noMenuItemsFound))
                      : CustomScrollView(
                          slivers: [
                            if (_allDeals.isNotEmpty)
                              SliverToBoxAdapter(
                                child: _buildDealsSection(),
                              ),
                            if (widget.restaurant.googlePlaceId != null &&
                                widget.restaurant.googleData.isNotEmpty)
                              SliverToBoxAdapter(
                                child: _buildGoogleSection(),
                              ),
                            SliverPadding(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              sliver: SliverList(
                                delegate: SliverChildBuilderDelegate(
                                  (context, idx) =>
                                      _buildCategoryTile(categories[idx], idx),
                                  childCount: categories.length,
                                ),
                              ),
                            ),
                          ],
                        ),
        ),
      ),
    );
  }
}
