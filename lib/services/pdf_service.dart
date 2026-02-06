import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../models/restaurant.dart';
import '../models/menu_item.dart';

class PdfService {
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
        margin: const pw.EdgeInsets.all(32),
        theme: theme,
        build: (pw.Context context) {
          return [
            // Header with restaurant name
            _buildHeader(restaurant),
            pw.SizedBox(height: 20),

            // Restaurant details
            _buildRestaurantInfo(restaurant),
            pw.SizedBox(height: 30),

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
            fontSize: 32,
            fontWeight: pw.FontWeight.bold,
            color: PdfColors.teal700,
          ),
        ),
        pw.Divider(thickness: 2, color: PdfColors.teal700),
      ],
    );
  }

  static pw.Widget _buildRestaurantInfo(Restaurant restaurant) {
    final infoItems = <pw.Widget>[];

    if (restaurant.description != null) {
      infoItems.add(
        pw.Text(
          restaurant.description!,
          style: const pw.TextStyle(fontSize: 12, color: PdfColors.grey700),
        ),
      );
      infoItems.add(pw.SizedBox(height: 8));
    }

    infoItems.add(
      pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Container(
            width: 60,
            child: pw.Text(
              'Address:',
              style: pw.TextStyle(
                fontSize: 10,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.grey700,
              ),
            ),
          ),
          pw.Expanded(
            child: pw.Text(
              restaurant.address,
              style: const pw.TextStyle(fontSize: 10),
            ),
          ),
        ],
      ),
    );

    if (restaurant.phone != null) {
      infoItems.add(pw.SizedBox(height: 4));
      infoItems.add(
        pw.Row(
          children: [
            pw.Container(
              width: 60,
              child: pw.Text(
                'Phone:',
                style: pw.TextStyle(
                  fontSize: 10,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.grey700,
                ),
              ),
            ),
            pw.Text(
              restaurant.phone!,
              style: const pw.TextStyle(fontSize: 10),
            ),
          ],
        ),
      );
    }

    if (restaurant.email != null) {
      infoItems.add(pw.SizedBox(height: 4));
      infoItems.add(
        pw.Row(
          children: [
            pw.Container(
              width: 60,
              child: pw.Text(
                'Email:',
                style: pw.TextStyle(
                  fontSize: 10,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.grey700,
                ),
              ),
            ),
            pw.Text(
              restaurant.email!,
              style: const pw.TextStyle(fontSize: 10),
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
      infoItems.add(pw.SizedBox(height: 8));
      infoItems.add(
        pw.Wrap(
          spacing: 8,
          runSpacing: 4,
          children: badges.map((badge) {
            return pw.Container(
              padding: const pw.EdgeInsets.symmetric(
                horizontal: 8,
                vertical: 4,
              ),
              decoration: pw.BoxDecoration(
                color: PdfColors.teal50,
                borderRadius: pw.BorderRadius.circular(4),
                border: pw.Border.all(color: PdfColors.teal300, width: 1),
              ),
              child: pw.Text(
                badge,
                style: pw.TextStyle(
                  fontSize: 9,
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
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        color: PdfColors.grey100,
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: infoItems,
      ),
    );
  }

  static List<pw.Widget> _buildMenuContent(List<Category> categories) {
    final widgets = <pw.Widget>[];

    for (final category in categories) {
      // Category header
      widgets.add(
        pw.Container(
          margin: const pw.EdgeInsets.only(top: 20, bottom: 12),
          padding: const pw.EdgeInsets.symmetric(vertical: 8, horizontal: 12),
          decoration: pw.BoxDecoration(
            color: PdfColors.teal700,
            borderRadius: pw.BorderRadius.circular(4),
          ),
          child: pw.Text(
            category.name,
            style: pw.TextStyle(
              fontSize: 18,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.white,
            ),
          ),
        ),
      );

      // Menu items in this category
      for (final item in category.items) {
        if (!item.available) continue; // Skip unavailable items

        widgets.add(
          pw.Container(
            margin: const pw.EdgeInsets.only(bottom: 12),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // Item name and price
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Expanded(
                      child: pw.Text(
                        item.name,
                        style: pw.TextStyle(
                          fontSize: 13,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                    ),
                    if (!item.hasVariants && item.price != null)
                      pw.Text(
                        '€${item.price!.toStringAsFixed(2)}',
                        style: pw.TextStyle(
                          fontSize: 13,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.teal700,
                        ),
                      ),
                  ],
                ),

                // Item description
                if (item.description != null && item.description!.isNotEmpty)
                  pw.Padding(
                    padding: const pw.EdgeInsets.only(top: 4),
                    child: pw.Text(
                      item.description!,
                      style: const pw.TextStyle(
                        fontSize: 10,
                        color: PdfColors.grey700,
                      ),
                    ),
                  ),

                // Variants
                if (item.hasVariants && item.variants.isNotEmpty)
                  pw.Padding(
                    padding: const pw.EdgeInsets.only(top: 6, left: 12),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: item.variants.map((variant) {
                        return pw.Padding(
                          padding: const pw.EdgeInsets.only(bottom: 2),
                          child: pw.Row(
                            mainAxisAlignment:
                                pw.MainAxisAlignment.spaceBetween,
                            children: [
                              pw.Text(
                                '• ${variant.name}',
                                style: const pw.TextStyle(
                                  fontSize: 11,
                                  color: PdfColors.grey800,
                                ),
                              ),
                              pw.Text(
                                '€${variant.price.toStringAsFixed(2)}',
                                style: pw.TextStyle(
                                  fontSize: 11,
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
                  padding: const pw.EdgeInsets.only(top: 8),
                  child: pw.Divider(color: PdfColors.grey300),
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
