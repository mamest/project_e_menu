import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/ai_menu_parser.dart';

class AdminUploadPage extends StatefulWidget {
  const AdminUploadPage({super.key});

  @override
  State<AdminUploadPage> createState() => _AdminUploadPageState();
}

class _AdminUploadPageState extends State<AdminUploadPage> {
  Uint8List? _pdfBytes;
  String? _fileName;
  bool _isProcessing = false;
  bool _isUploading = false;
  MenuData? _extractedData;
  String? _errorMessage;

  Future<void> _pickPdfFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
        withData: true,
      );

      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        setState(() {
          _pdfBytes = file.bytes;
          _fileName = file.name;
          _extractedData = null;
          _errorMessage = null;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error picking file: $e';
      });
    }
  }

  Future<void> _processWithAI() async {
    if (_pdfBytes == null) return;

    setState(() {
      _isProcessing = true;
      _errorMessage = null;
    });

    try {
      final parser = AiMenuParser();
      final menuData = await parser.parseMenuPdf(_pdfBytes!, _fileName!);
      
      setState(() {
        _extractedData = menuData;
        _isProcessing = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Menu extracted successfully! Review and save to database.'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error processing menu: $e';
        _isProcessing = false;
      });
    }
  }

  Future<void> _saveToDatabase() async {
    if (_extractedData == null) return;

    setState(() {
      _isUploading = true;
      _errorMessage = null;
    });

    try {
      final supabase = Supabase.instance.client;

      // Insert restaurant
      final restaurantResponse = await supabase
          .from('restaurants')
          .insert({
            'name': _extractedData!.restaurant.name,
            'address': _extractedData!.restaurant.address,
            'phone': _extractedData!.restaurant.phone,
            'email': _extractedData!.restaurant.email,
            'description': _extractedData!.restaurant.description,
            'cuisine_type': _extractedData!.restaurant.cuisineType,
            'delivers': _extractedData!.restaurant.delivers,
            'opening_hours': _extractedData!.restaurant.openingHours,
            'payment_methods': _extractedData!.restaurant.paymentMethods,
          })
          .select('id')
          .single();

      final restaurantId = restaurantResponse['id'] as int;

      // Insert categories and items
      for (final category in _extractedData!.categories) {
        final categoryResponse = await supabase
            .from('categories')
            .insert({
              'restaurant_id': restaurantId,
              'name': category.name,
              'display_order': category.displayOrder,
            })
            .select('id')
            .single();

        final categoryId = categoryResponse['id'] as int;

        // Insert items
        for (final item in category.items) {
          final itemResponse = await supabase
              .from('items')
              .insert({
                'category_id': categoryId,
                'name': item.name,
                'price': item.price,
                'description': item.description,
                'available': true,
                'has_variants': item.hasVariants,
              })
              .select('id')
              .single();

          final itemId = itemResponse['id'] as int;

          // Insert variants if present
          if (item.hasVariants && item.variants != null) {
            for (final variant in item.variants!) {
              await supabase.from('item_variants').insert({
                'item_id': itemId,
                'name': variant.name,
                'price': variant.price,
                'display_order': variant.displayOrder,
                'available': true,
              });
            }
          }
        }
      }

      setState(() {
        _isUploading = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Restaurant "${_extractedData!.restaurant.name}" saved successfully!'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
          ),
        );

        // Clear state and go back
        Navigator.pop(context, true);
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error saving to database: $e';
        _isUploading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Upload Menu PDF'),
        backgroundColor: Colors.teal,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Instructions
            Card(
              color: Colors.blue.shade50,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.info_outline, color: Colors.blue.shade700),
                        const SizedBox(width: 8),
                        Text(
                          'How it works',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue.shade700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      '1. Upload a PDF menu\n'
                      '2. AI will extract restaurant info and menu items\n'
                      '3. Review the extracted data\n'
                      '4. Save to database',
                      style: TextStyle(fontSize: 14),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // File picker button
            ElevatedButton.icon(
              onPressed: _isProcessing || _isUploading ? null : _pickPdfFile,
              icon: const Icon(Icons.upload_file),
              label: const Text('Choose PDF Menu'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.all(16),
                backgroundColor: Colors.teal,
                foregroundColor: Colors.white,
              ),
            ),

            if (_fileName != null) ...[
              const SizedBox(height: 16),
              Card(
                child: ListTile(
                  leading: const Icon(Icons.picture_as_pdf, color: Colors.red),
                  title: Text(_fileName!),
                  trailing: IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () {
                      setState(() {
                        _pdfBytes = null;
                        _fileName = null;
                        _extractedData = null;
                      });
                    },
                  ),
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _isProcessing || _isUploading ? null : _processWithAI,
                icon: _isProcessing
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Icon(Icons.auto_awesome),
                label: Text(_isProcessing ? 'Processing with AI...' : 'Extract Menu with AI'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.all(16),
                  backgroundColor: Colors.purple,
                  foregroundColor: Colors.white,
                ),
              ),
            ],

            if (_errorMessage != null) ...[
              const SizedBox(height: 16),
              Card(
                color: Colors.red.shade50,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Icon(Icons.error_outline, color: Colors.red.shade700),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: TextStyle(color: Colors.red.shade700),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],

            if (_extractedData != null) ...[
              const SizedBox(height: 24),
              const Divider(),
              const SizedBox(height: 16),
              Text(
                'Extracted Data Preview',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 16),

              // Restaurant info
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _extractedData!.restaurant.name,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(_extractedData!.restaurant.address),
                      if (_extractedData!.restaurant.phone != null)
                        Text('📞 ${_extractedData!.restaurant.phone}'),
                      if (_extractedData!.restaurant.email != null)
                        Text('📧 ${_extractedData!.restaurant.email}'),
                      if (_extractedData!.restaurant.cuisineType != null)
                        Chip(label: Text(_extractedData!.restaurant.cuisineType!)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Categories and items
              ...(_extractedData!.categories.map((category) {
                return Card(
                  margin: const EdgeInsets.only(bottom: 16),
                  child: ExpansionTile(
                    title: Text(
                      category.name,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text('${category.items.length} items'),
                    children: category.items.map((item) {
                      return ListTile(
                        title: Text(item.name),
                        subtitle: item.description != null
                            ? Text(item.description!)
                            : null,
                        trailing: item.hasVariants && item.variants != null
                            ? Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: item.variants!
                                    .map((v) => Text(
                                          '${v.name}: €${v.price.toStringAsFixed(2)}',
                                          style: const TextStyle(fontSize: 12),
                                        ))
                                    .toList(),
                              )
                            : Text(
                                item.price != null
                                    ? '€${item.price!.toStringAsFixed(2)}'
                                    : '',
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                      );
                    }).toList(),
                  ),
                );
              }).toList()),

              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _isUploading ? null : _saveToDatabase,
                icon: _isUploading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Icon(Icons.save),
                label: Text(_isUploading ? 'Saving...' : 'Save to Database'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.all(16),
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
