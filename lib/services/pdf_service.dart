import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../models/restaurant.dart';
import '../models/menu_item.dart';

class PdfService {
  // Natural sort comparison for item numbers (handles "1", "2", "10", "1a", "2b" etc.)
  static int _compareItemNumbers(String? a, String? b) {
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

  static Future<void> generateMenuPdf(
    Restaurant restaurant,
    List<Category> categories,
  ) async {
    // Load a Unicode-compatible font
    final fontRegular = await PdfGoogleFonts.notoSansRegular();
    final fontBold = await PdfGoogleFonts.notoSansBold();
    
    final pdf = pw.Document();
    
    // Define theme with Unicode-compatible fonts
    final theme = pw.ThemeData.withFont(
      base: fontRegular,
      bold: fontBold,
    );

    // Add pages to the PDF
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(16),
        theme: theme,
        build: (pw.Context context) {
          return [
            // Header with restaurant name
            _buildHeader(restaurant),
            pw.SizedBox(height: 8),

            // Restaurant details
            _buildRestaurantInfo(restaurant),
            pw.SizedBox(height: 12),

            // Menu categories and items
            ..._buildMenuContent(categories),
          ];
        },
        footer: (pw.Context context) {
          return _buildFooter(context, restaurant);
        },
      ),
    );

    // Open print dialog or save PDF
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name: '${restaurant.name}_menu.pdf',
    );
  }

  static pw.Widget _buildHeader(Restaurant restaurant) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          restaurant.name,
          style: pw.TextStyle(
            fontSize: 22,
            fontWeight: pw.FontWeight.bold,
            color: PdfColors.teal700,
          ),
        ),
        pw.Divider(thickness: 1.5, color: PdfColors.teal700),
      ],
    );
  }

  static pw.Widget _buildRestaurantInfo(Restaurant restaurant) {
    final infoItems = <pw.Widget>[];

    if (restaurant.description != null) {
      infoItems.add(
        pw.Text(
          restaurant.description!,
          style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
        ),
      );
      infoItems.add(pw.SizedBox(height: 4));
    }

    infoItems.add(
      pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Container(
            width: 50,
            child: pw.Text(
              'Address:',
              style: pw.TextStyle(
                fontSize: 8,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.grey700,
              ),
            ),
          ),
          pw.Expanded(
            child: pw.Text(
              restaurant.address,
              style: const pw.TextStyle(fontSize: 8),
            ),
          ),
        ],
      ),
    );

    if (restaurant.phone != null) {
      infoItems.add(pw.SizedBox(height: 2));
      infoItems.add(
        pw.Row(
          children: [
            pw.Container(
              width: 50,
              child: pw.Text(
                'Phone:',
                style: pw.TextStyle(
                  fontSize: 8,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.grey700,
                ),
              ),
            ),
            pw.Text(
              restaurant.phone!,
              style: const pw.TextStyle(fontSize: 8),
            ),
          ],
        ),
      );
    }

    if (restaurant.email != null) {
      infoItems.add(pw.SizedBox(height: 2));
      infoItems.add(
        pw.Row(
          children: [
            pw.Container(
              width: 50,
              child: pw.Text(
                'Email:',
                style: pw.TextStyle(
                  fontSize: 8,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.grey700,
                ),
              ),
            ),
            pw.Text(
              restaurant.email!,
              style: const pw.TextStyle(fontSize: 8),
            ),
          ],
        ),
      );
    }

    // Add cuisine type and delivery info
    final badges = <String>[];
    if (restaurant.cuisineType != null) {
      badges.add(restaurant.cuisineType!);
    }
    if (restaurant.delivers) {
      badges.add('Delivery Available');
    }

    if (badges.isNotEmpty) {
      infoItems.add(pw.SizedBox(height: 4));
      infoItems.add(
        pw.Wrap(
          spacing: 4,
          runSpacing: 2,
          children: badges.map((badge) {
            return pw.Container(
              padding: const pw.EdgeInsets.symmetric(
                horizontal: 6,
                vertical: 2,
              ),
              decoration: pw.BoxDecoration(
                color: PdfColors.teal50,
                borderRadius: pw.BorderRadius.circular(3),
                border: pw.Border.all(color: PdfColors.teal300, width: 0.5),
              ),
              child: pw.Text(
                badge,
                style: pw.TextStyle(
                  fontSize: 7,
                  color: PdfColors.teal700,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            );
          }).toList(),
        ),
      );
    }

    return pw.Container(
      padding: const pw.EdgeInsets.all(8),
      decoration: pw.BoxDecoration(
        color: PdfColors.grey100,
        borderRadius: pw.BorderRadius.circular(4),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: infoItems,
      ),
    );
  }

  static List<pw.Widget> _buildMenuContent(List<Category> categories) {
    final widgets = <pw.Widget>[];

    // Filter out categories with no available items
    final nonEmptyCategories = categories.where((category) {
      return category.items.any((item) => item.available);
    }).toList();

    // Sort categories by minimum item_number
    nonEmptyCategories.sort((a, b) {
      final aItems = a.items.where((item) => item.available).toList();
      final bItems = b.items.where((item) => item.available).toList();
      
      // Sort items within categories first
      aItems.sort((x, y) => _compareItemNumbers(x.itemNumber, y.itemNumber));
      bItems.sort((x, y) => _compareItemNumbers(x.itemNumber, y.itemNumber));

      final aMinNum = aItems.isNotEmpty ? aItems.first.itemNumber : null;
      final bMinNum = bItems.isNotEmpty ? bItems.first.itemNumber : null;
      return _compareItemNumbers(aMinNum, bMinNum);
    });

    for (final category in nonEmptyCategories) {
      // Sort items by item_number
      final sortedItems = category.items.where((item) => item.available).toList();
      sortedItems.sort((a, b) => _compareItemNumbers(a.itemNumber, b.itemNumber));

      // Category header
      widgets.add(
        pw.Container(
          margin: const pw.EdgeInsets.only(top: 10, bottom: 6),
          padding: const pw.EdgeInsets.symmetric(vertical: 4, horizontal: 8),
          decoration: pw.BoxDecoration(
            color: PdfColors.teal700,
            borderRadius: pw.BorderRadius.circular(3),
          ),
          child: pw.Text(
            category.name,
            style: pw.TextStyle(
              fontSize: 12,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.white,
            ),
          ),
        ),
      );

      // Menu items in this category
      for (final item in sortedItems) {

        widgets.add(
          pw.Container(
            margin: const pw.EdgeInsets.only(bottom: 4),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // Item name and price
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Expanded(
                      child: pw.Row(
                        children: [
                          if (item.itemNumber != null && item.itemNumber!.isNotEmpty) ...[
                            pw.Container(
                              padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              margin: const pw.EdgeInsets.only(right: 6),
                              decoration: pw.BoxDecoration(
                                color: PdfColors.teal50,
                                borderRadius: pw.BorderRadius.circular(3),
                                border: pw.Border.all(color: PdfColors.teal200),
                              ),
                              child: pw.Text(
                                item.itemNumber!,
                                style: pw.TextStyle(
                                  fontSize: 10,
                                  fontWeight: pw.FontWeight.bold,
                                  color: PdfColors.teal700,
                                ),
                              ),
                            ),
                          ],
                          pw.Expanded(
                            child: pw.Text(
                              item.name,
                              style: pw.TextStyle(
                                fontSize: 13,
                                fontWeight: pw.FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (!item.hasVariants && item.price != null)
                      pw.Text(
                        '€${item.price!.toStringAsFixed(2)}',
                        style: pw.TextStyle(
                          fontSize: 10,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.teal700,
                        ),
                      ),
                  ],
                ),

                // Item description
                if (item.description != null && item.description!.isNotEmpty)
                  pw.Padding(
                    padding: const pw.EdgeInsets.only(top: 1, left: 12),
                    child: pw.Text(
                      item.description!,
                      style: const pw.TextStyle(
                        fontSize: 8,
                        color: PdfColors.grey700,
                      ),
                    ),
                  ),

                // Variants
                if (item.hasVariants && item.variants.isNotEmpty)
                  pw.Padding(
                    padding: const pw.EdgeInsets.only(top: 2, left: 12),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: item.variants.map((variant) {
                        return pw.Padding(
                          padding: const pw.EdgeInsets.only(bottom: 1),
                          child: pw.Row(
                            mainAxisAlignment:
                                pw.MainAxisAlignment.spaceBetween,
                            children: [
                              pw.Text(
                                '• ${variant.name}',
                                style: const pw.TextStyle(
                                  fontSize: 8,
                                  color: PdfColors.grey800,
                                ),
                              ),
                              pw.Text(
                                '€${variant.price.toStringAsFixed(2)}',
                                style: pw.TextStyle(
                                  fontSize: 8,
                                  color: PdfColors.teal600,
                                  fontWeight: pw.FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ),

                // Divider
                pw.Padding(
                  padding: const pw.EdgeInsets.only(top: 3),
                  child: pw.Divider(color: PdfColors.grey300, height: 0.5),
                ),
              ],
            ),
          ),
        );
      }
    }

    return widgets;
  }

  static pw.Widget _buildFooter(pw.Context context, Restaurant restaurant) {
    return pw.Container(
      alignment: pw.Alignment.centerRight,
      margin: const pw.EdgeInsets.only(top: 16),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.end,
        children: [
          pw.Text(
            'Page ${context.pageNumber} of ${context.pagesCount}',
            style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey600),
          ),
          pw.Text(
            'Generated on ${_formatDate(DateTime.now())}',
            style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey500),
          ),
        ],
      ),
    );
  }

  static String _formatDate(DateTime date) {
    final months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December'
    ];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }
}
