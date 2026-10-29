import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:yallashop_core/yallashop_core.dart';

import '../../config/api_config.dart';
import '../../core/bloc/auth_bloc.dart';
import '../../core/bloc/auth_state.dart';

class VendorProductFormScreen extends StatefulWidget {
  final int? productId;

  const VendorProductFormScreen({super.key, this.productId});

  bool get isEditing => productId != null;

  @override
  State<VendorProductFormScreen> createState() => _VendorProductFormScreenState();
}

class _VendorProductFormScreenState extends State<VendorProductFormScreen> {
  final _apiClient = ApiClient(baseUrl: CustomerApiConfig.baseUrl);
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _priceController = TextEditingController(text: '0');
  final _picker = ImagePicker();

  List<Category> _categories = [];
  List<Currency> _currencies = [];
  List<CategoryAttribute> _categoryAttributes = [];
  List<_MediaItem> _mediaItems = [];
  List<_VariantItem> _variants = [];
  List<_ExistingMediaItem> _existingImages = [];

  int? _selectedCategoryId;
  int? _selectedCurrencyId;
  String _status = 'active';
  String? _originalStatus;

  bool _isLoading = false;
  bool _isSaving = false;
  bool _isLoadingProduct = false;
  String? _error;

  int get _totalMediaCount => _mediaItems.length + _existingImages.length;
  bool get _hasVideo =>
      _mediaItems.any((m) => m.type == 'video') || _existingImages.any((m) => m.type == 'video');

  @override
  void initState() {
    super.initState();
    _loadInitialData();
    if (widget.isEditing) {
      _loadProduct();
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    for (final m in _mediaItems) {
      m.dispose();
    }
    for (final v in _variants) {
      v.dispose();
    }
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    setState(() => _isLoading = true);
    try {
      final results = await Future.wait([
        _apiClient.get<List<dynamic>>('/catalog/categories'),
        _apiClient.get<List<dynamic>>('/currencies'),
      ]);
      if (results[0] is Success<List<dynamic>>) {
        _categories = (results[0] as Success<List<dynamic>>).data
            .map((e) => Category.fromJson(e as Map<String, dynamic>))
            .toList();
      }
      if (results[1] is Success<List<dynamic>>) {
        _currencies = (results[1] as Success<List<dynamic>>).data
            .map((e) => Currency.fromJson(e as Map<String, dynamic>))
            .toList();
      }
    } catch (_) {}
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _loadProduct() async {
    setState(() => _isLoadingProduct = true);
    try {
      final result = await _apiClient.get<Map<String, dynamic>>(
        '/vendor/products/${widget.productId}',
      );
      if (result is Success<Map<String, dynamic>>) {
        final data = result.data;
        _titleController.text = data['title'] ?? '';
        _descriptionController.text = data['description'] ?? '';
        _priceController.text = (data['base_price'] ?? 0).toString();
        _selectedCategoryId = data['category_id'];
        _selectedCurrencyId = data['currency_id'];
        _status = data['status'] ?? 'active';
        _originalStatus = data['status'] as String?;

        if (data['images'] != null) {
          _existingImages = (data['images'] as List)
              .map((img) => _ExistingMediaItem(
                    url: img['url'] ?? '',
                    type: img['type'] ?? 'image',
                  ))
              .toList();
        }

        if (data['variants'] != null) {
          for (final v in data['variants'] as List) {
            final variant = ProductVariant.fromJson(v as Map<String, dynamic>);
            _variants.add(_VariantItem.fromExisting(variant));
          }
        }

        if (_selectedCategoryId != null) {
          await _loadCategoryAttributes(_selectedCategoryId!);
        }
      }
    } catch (_) {
      if (mounted) context.pop();
    }
    if (mounted) setState(() => _isLoadingProduct = false);
  }

  Future<void> _loadCategoryAttributes(int categoryId) async {
    try {
      final result = await _apiClient.get<List<dynamic>>(
        '/vendor/categories/$categoryId/attributes',
      );
      if (result is Success<List<dynamic>>) {
        _categoryAttributes = (result.data as List)
            .map((e) => CategoryAttribute.fromJson(e as Map<String, dynamic>))
            .toList();
      }
    } catch (_) {}
    if (mounted) setState(() {});
  }

  void _addVariant() {
    final basePrice = double.tryParse(_priceController.text) ?? 0;
    final initialAttrs = _categoryAttributes.map((attr) {
      return _VariantAttributeItem(
        attributeId: attr.id,
        attributeName: attr.name,
        isSelect: attr.isSelect,
        isRequired: attr.isRequired,
        options: attr.options ?? [],
      );
    }).toList();
    _variants.add(_VariantItem(
      price: basePrice,
      stockQty: 0,
      sku: '',
      attributes: initialAttrs,
    ));
    setState(() {});
  }

  void _generateVariants() {
    final selectAttrs = _categoryAttributes.where((a) => a.isSelect).toList();
    if (selectAttrs.isEmpty) {
      _addVariant();
      return;
    }

    List<List<_VariantAttributeItem>> combinations = [[]];
    for (final attr in selectAttrs) {
      final newCombinations = <List<_VariantAttributeItem>>[];
      for (final combo in combinations) {
        for (final option in (attr.options ?? [])) {
          newCombinations.add([
            ...combo,
            _VariantAttributeItem(
              attributeId: attr.id,
              attributeName: attr.name,
              isSelect: true,
              isRequired: attr.isRequired,
              options: attr.options ?? [],
              selectedOptionId: option.id,
            ),
          ]);
        }
      }
      combinations = newCombinations;
    }

    final basePrice = double.tryParse(_priceController.text) ?? 0;
    final timestamp = DateTime.now().millisecondsSinceEpoch;

    for (var i = 0; i < combinations.length; i++) {
      _variants.add(_VariantItem(
        price: basePrice,
        stockQty: 0,
        sku: 'VAR-$timestamp-$i',
        attributes: combinations[i],
      ));
    }
    setState(() {});
  }

  void _removeVariant(int index) {
    _variants[index].dispose();
    _variants.removeAt(index);
    setState(() {});
  }

  Future<void> _pickImages() async {
    final remaining = 7 - _totalMediaCount;
    if (remaining <= 0) return;

    final picked = await _picker.pickMultiImage(imageQuality: 80);
    if (picked.isEmpty) return;

    debugPrint('=== IMAGES PICKED: ${picked.length} ===');

    final limited = picked.take(remaining).toList();
    final hasExistingVideo = _hasVideo;

    for (final xFile in limited) {
      final file = File(xFile.path);
      final isVideo = xFile.path.toLowerCase().endsWith('.mp4') ||
          xFile.path.toLowerCase().endsWith('.mov');
      if (isVideo && hasExistingVideo) continue;
      _mediaItems.add(_MediaItem(file: file, type: isVideo ? 'video' : 'image'));
      debugPrint('Added to _mediaItems: ${xFile.path}');
    }
    setState(() {});
    debugPrint('=== TOTAL MEDIA ITEMS: ${_mediaItems.length} ===');
  }

  void _removeNewMedia(int index) {
    _mediaItems[index].dispose();
    _mediaItems.removeAt(index);
    setState(() {});
  }

  void _removeExistingMedia(int index) {
    _existingImages.removeAt(index);
    setState(() {});
  }

  Future<void> _pickVariantImages(int variantIndex) async {
    final variant = _variants[variantIndex];
    final remaining = 7 - variant.totalImageCount;
    if (remaining <= 0) return;

    final picked = await _picker.pickMultiImage(imageQuality: 80);
    if (picked.isEmpty) return;

    final limited = picked.take(remaining).toList();
    final hasExistingVideo = variant.existingImages.any((m) => m.type == 'video');

    for (final xFile in limited) {
      final file = File(xFile.path);
      final isVideo = xFile.path.toLowerCase().endsWith('.mp4') ||
          xFile.path.toLowerCase().endsWith('.mov');
      if (isVideo && hasExistingVideo) continue;
      variant.newImages.add(_VariantMediaItem(file: file, type: isVideo ? 'video' : 'image'));
    }
    setState(() {});
  }

  void _removeNewVariantImage(int variantIndex, int imageIndex) {
    _variants[variantIndex].newImages[imageIndex].dispose();
    _variants[variantIndex].newImages.removeAt(imageIndex);
    setState(() {});
  }

  void _removeExistingVariantImage(int variantIndex, int imageIndex) {
    _variants[variantIndex].existingImages.removeAt(imageIndex);
    setState(() {});
  }

  void _showAddOptionDialog(int attributeId) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Option'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(hintText: 'Enter option value'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              if (controller.text.isNotEmpty) {
                _addAttributeOption(attributeId, controller.text);
              }
              Navigator.pop(ctx);
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  Future<void> _addAttributeOption(int attributeId, String value) async {
    try {
      final result = await _apiClient.post<Map<String, dynamic>>(
        '/vendor/attributes/$attributeId/options',
        data: {'attribute_id': attributeId, 'value': value},
      );
      if (result is Success<Map<String, dynamic>>) {
        final newOption = CategoryAttributeOption.fromJson(result.data);
        setState(() {
          _categoryAttributes = _categoryAttributes.map((attr) {
            if (attr.id == attributeId) {
              return CategoryAttribute(
                id: attr.id,
                categoryId: attr.categoryId,
                name: attr.name,
                type: attr.type,
                isRequired: attr.isRequired,
                sortOrder: attr.sortOrder,
                options: [...(attr.options ?? []), newOption],
              );
            }
            return attr;
          }).toList();
          for (final variant in _variants) {
            for (final va in variant.attributes) {
              if (va.attributeId == attributeId) {
                va.options = [...va.options, newOption];
              }
            }
          }
        });
      }
    } catch (_) {}
  }

  Map<String, String> _validate() {
    final errors = <String, String>{};
    if (_titleController.text.trim().isEmpty) errors['title'] = 'Title is required';
    if (_descriptionController.text.trim().isEmpty) {
      errors['description'] = 'Description is required';
    }
    final price = double.tryParse(_priceController.text) ?? 0;
    if (price <= 0) errors['price'] = 'Price must be greater than 0';
    if (_selectedCategoryId == null) errors['category'] = 'Category is required';
    if (_selectedCurrencyId == null) errors['currency'] = 'Currency is required';
    if (_variants.isEmpty) errors['variants'] = 'At least one variant is required';
    return errors;
  }

  Future<void> _saveProduct() async {
    final errors = _validate();
    if (errors.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(errors.values.first), backgroundColor: Colors.red),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final authState = context.read<AuthBloc>().state;
      if (authState is! Authenticated) return;
      final storeId = authState.user.store?.id;
      if (storeId == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No store found. Please contact support.'), backgroundColor: Colors.red),
          );
        }
        return;
      }

      // Upload new images
      final uploadedImages = <Map<String, dynamic>>[
        ..._existingImages.map((m) => {'url': m.url, 'type': m.type, 'sort_order': 0}),
      ];

      for (var i = 0; i < _mediaItems.length; i++) {
        final media = _mediaItems[i];
        try {
          final file = await MultipartFile.fromFile(
            media.file.path,
            filename: media.file.path.split(RegExp(r'[/\\]')).last,
          );
          final formData = FormData.fromMap({
            'file': file,
            'folder': 'products',
          });
          final result = await _apiClient.postForm<Map<String, dynamic>>(
            '/vendor/upload',
            formData: formData,
          );
          if (result is Success<Map<String, dynamic>>) {
            uploadedImages.add({
              'url': result.data['url'],
              'type': media.type,
              'sort_order': uploadedImages.length,
            });
          } else {
            debugPrint('Image upload failed: ${(result as Failure).exception.message}');
          }
        } catch (e) {
          debugPrint('Image upload error: $e');
        }
      }

      debugPrint('=== PRODUCT IMAGES TO SEND: $uploadedImages');

      // Build variants with images
      final variantsData = <Map<String, dynamic>>[];
      for (final variant in _variants) {
        final attrs = variant.attributes.map((a) {
          if (a.isSelect) {
            return {'attribute_id': a.attributeId, 'option_id': a.selectedOptionId};
          }
          return {'attribute_id': a.attributeId, 'value': a.textController.text};
        }).toList();

        // Upload variant images
        final variantImages = <Map<String, dynamic>>[
          ...variant.existingImages.map((m) => {'url': m.url, 'type': m.type, 'sort_order': 0}),
        ];
        for (var i = 0; i < variant.newImages.length; i++) {
          final media = variant.newImages[i];
          try {
            final file = await MultipartFile.fromFile(
              media.file.path,
              filename: media.file.path.split(RegExp(r'[/\\]')).last,
            );
            final formData = FormData.fromMap({
              'file': file,
              'folder': 'products',
            });
            final result = await _apiClient.postForm<Map<String, dynamic>>(
              '/vendor/upload',
              formData: formData,
            );
            if (result is Success<Map<String, dynamic>>) {
              variantImages.add({
                'url': result.data['url'],
                'type': media.type,
                'sort_order': variantImages.length,
              });
            } else {
              debugPrint('Variant image upload failed: ${(result as Failure).exception.message}');
            }
          } catch (e) {
            debugPrint('Variant image upload error: $e');
          }
        }

        debugPrint('=== VARIANT ${variant.skuController.text} IMAGES TO SEND: $variantImages');

        variantsData.add({
          'sku': variant.skuController.text,
          'price': double.tryParse(variant.priceController.text) ?? 0,
          'stock_qty': int.tryParse(variant.stockController.text) ?? 0,
          'attributes': attrs,
          'images': variantImages,
        });
      }

      final payload = {
        'store_id': storeId,
        'title': _titleController.text.trim(),
        'description': _descriptionController.text.trim(),
        'base_price': double.tryParse(_priceController.text) ?? 0,
        'currency_id': _selectedCurrencyId,
        'category_id': _selectedCategoryId,
        'status': _status,
        'images': uploadedImages,
        'variants': variantsData,
      };

      debugPrint('=== FINAL PRODUCT PAYLOAD ===');
      debugPrint('Images count: ${uploadedImages.length}');
      debugPrint('Variants count: ${variantsData.length}');
      for (var v = 0; v < variantsData.length; v++) {
        debugPrint('Variant $v images: ${(variantsData[v]['images'] as List).length}');
      }

      final result = widget.isEditing
          ? await _apiClient.put('/vendor/products/${widget.productId}', data: payload)
          : await _apiClient.post('/vendor/products', data: payload);

      if (result is Success) {
        if (mounted) {
          final loc = AppLocalization.of(context)!;
          final message = widget.isEditing
              ? (_originalStatus == 'active'
                  ? loc.getText('pendingApprovalNote')
                  : loc.getText('productUpdated'))
              : loc.getText('productCreated');
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(message), backgroundColor: Colors.green),
          );
          context.pop(true);
        }
      } else {
        final err = result as Failure;
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(err.exception.message), backgroundColor: Colors.red),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalization.of(context)!;

    if (_isLoadingProduct) {
      return Scaffold(
        backgroundColor: CustomerAppColors.background,
        appBar: AppBar(backgroundColor: Colors.transparent, elevation: 0),
        body: const Center(child: CircularProgressIndicator(color: CustomerAppColors.primary)),
      );
    }

    return Scaffold(
      backgroundColor: CustomerAppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: CustomerAppColors.onSurface),
          onPressed: () => context.pop(),
        ),
        title: Text(
          widget.isEditing ? loc.getText('editProduct') : loc.getText('addProduct'),
          style: AppTypography.h2_18.copyWith(fontWeight: FontWeight.w600),
        ),
        actions: [
          TextButton.icon(
            onPressed: _isSaving ? null : _saveProduct,
            icon: _isSaving
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2, color: CustomerAppColors.primary),
                  )
                : const Icon(Icons.check, color: CustomerAppColors.primary),
            label: Text(
              _isSaving ? loc.getText('saving') : loc.getText('save'),
              style: AppTypography.body14.copyWith(
                color: CustomerAppColors.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: CustomerAppColors.primary))
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(_error!),
                      const SizedBox(height: 16),
                      ElevatedButton(onPressed: _loadInitialData, child: Text(loc.getText('retry'))),
                    ],
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildGeneralInfoSection(loc),
                        const SizedBox(height: 24),
                        _buildMediaSection(loc),
                        const SizedBox(height: 24),
                        _buildVariantsSection(loc),
                        const SizedBox(height: 100),
                      ],
                    ),
                  ),
                ),
    );
  }

  Widget _buildGeneralInfoSection(AppLocalization loc) {
    return _buildCard(
      title: loc.getText('generalInformation'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildLabel(loc.getText('productTitle')),
          const SizedBox(height: 6),
          TextFormField(
            controller: _titleController,
            decoration: _inputDecoration(hint: loc.getText('enterProductTitle')),
            validator: (v) => (v == null || v.trim().isEmpty) ? loc.getText('titleRequired') : null,
          ),
          const SizedBox(height: 16),
          _buildLabel(loc.getText('description')),
          const SizedBox(height: 6),
          TextFormField(
            controller: _descriptionController,
            maxLines: 4,
            decoration: _inputDecoration(hint: loc.getText('enterDescription')),
            validator: (v) => (v == null || v.trim().isEmpty) ? loc.getText('descriptionRequired') : null,
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildLabel(loc.getText('category')),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<int>(
                      value: _selectedCategoryId,
                      isExpanded: true,
                      decoration: _inputDecoration(),
                      items: _categories
                          .map((c) => DropdownMenuItem(value: c.id, child: Text(c.name)))
                          .toList(),
                      onChanged: (val) {
                        setState(() => _selectedCategoryId = val);
                        if (val != null) _loadCategoryAttributes(val);
                      },
                      validator: (v) => v == null ? loc.getText('categoryIsRequired') : null,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildLabel(loc.getText('currency')),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<int>(
                      value: _selectedCurrencyId,
                      isExpanded: true,
                      decoration: _inputDecoration(),
                      items: _currencies
                          .map((c) => DropdownMenuItem(
                                value: c.id,
                                child: Text('${c.symbol} ${c.name}'),
                              ))
                          .toList(),
                      onChanged: (val) => setState(() => _selectedCurrencyId = val),
                      validator: (v) => v == null ? loc.getText('currencyIsRequired') : null,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildLabel(loc.getText('basePrice')),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _priceController,
                      keyboardType: TextInputType.number,
                      decoration: _inputDecoration(),
                      validator: (v) {
                        final p = double.tryParse(v ?? '') ?? 0;
                        return p <= 0 ? loc.getText('priceMustBeGreaterThanZero') : null;
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildLabel(loc.getText('status')),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<String>(
                      value: _status,
                      isExpanded: true,
                      decoration: _inputDecoration(),
                      items: [
                        DropdownMenuItem(value: 'active', child: Text(loc.getText('active'))),
                        DropdownMenuItem(value: 'draft', child: Text(loc.getText('draft'))),
                      ],
                      onChanged: (val) => setState(() => _status = val ?? 'active'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMediaSection(AppLocalization loc) {
    return _buildCard(
      title: '${loc.getText('productMedia')} ($_totalMediaCount/7)',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (var i = 0; i < _existingImages.length; i++)
                _buildMediaThumbnail(
                  url: _existingImages[i].url,
                  type: _existingImages[i].type,
                  onRemove: () => _removeExistingMedia(i),
                ),
              for (var i = 0; i < _mediaItems.length; i++)
                _buildMediaThumbnail(
                  file: _mediaItems[i].file,
                  type: _mediaItems[i].type,
                  onRemove: () => _removeNewMedia(i),
                ),
              if (_totalMediaCount < 7)
                GestureDetector(
                  onTap: _pickImages,
                  child: Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      border: Border.all(color: CustomerAppColors.border, width: 2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.add_photo_alternate_outlined, color: CustomerAppColors.textSecondary, size: 24),
                        SizedBox(height: 4),
                        Text('Upload', style: TextStyle(fontSize: 10, color: CustomerAppColors.textSecondary)),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildVariantsSection(AppLocalization loc) {
    return _buildCard(
      title: loc.getText('variants'),
      action: _selectedCategoryId != null
          ? Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildSmallButton(loc.getText('generateVariants'), Icons.auto_fix_high, _generateVariants),
                const SizedBox(width: 8),
                _buildSmallButton(loc.getText('addVariant'), Icons.add_circle_outline, _addVariant),
              ],
            )
          : null,
      child: _selectedCategoryId == null
          ? _buildEmptyState(loc.getText('selectCategoryToManageVariants'))
          : _variants.isEmpty
              ? Column(
                  children: [
                    _buildEmptyState(loc.getText('noVariantsAdded')),
                    const SizedBox(height: 12),
                    _buildSmallButton(loc.getText('addFirstVariant'), Icons.add_circle_outline, _addVariant),
                  ],
                )
              : Column(
                  children: [
                    for (var i = 0; i < _variants.length; i++) _buildVariantCard(i, loc),
                  ],
                ),
    );
  }

  Widget _buildVariantCard(int index, AppLocalization loc) {
    final variant = _variants[index];
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: CustomerAppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: CustomerAppColors.surfaceContainerHigh),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Variant ${index + 1}',
                style: AppTypography.body14.copyWith(fontWeight: FontWeight.w600),
              ),
              if (_variants.length > 1)
                IconButton(
                  icon: const Icon(Icons.delete_outline, size: 20, color: CustomerAppColors.error),
                  onPressed: () => _removeVariant(index),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildSmallField(
                  label: loc.getText('variantSku'),
                  controller: variant.skuController,
                  hint: loc.getText('enterSku'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildSmallField(
                  label: loc.getText('variantPrice'),
                  controller: variant.priceController,
                  keyboardType: TextInputType.number,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildSmallField(
                  label: loc.getText('variantStock'),
                  controller: variant.stockController,
                  keyboardType: TextInputType.number,
                ),
              ),
            ],
          ),
          if (variant.attributes.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(loc.getText('variantAttributes'),
                style: AppTypography.caption12.copyWith(color: CustomerAppColors.textSecondary)),
            const SizedBox(height: 8),
            for (var ai = 0; ai < variant.attributes.length; ai++) _buildAttributeRow(index, ai, loc),
          ],
          if (_categoryAttributes.isNotEmpty &&
              variant.attributes.length < _categoryAttributes.length) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: _categoryAttributes
                  .where((ca) => !variant.attributes.any((va) => va.attributeId == ca.id))
                  .map((ca) => ActionChip(
                        label: Text('${loc.getText('add')} ${ca.name}',
                            style: const TextStyle(fontSize: 12)),
                        onPressed: () {
                          variant.attributes.add(_VariantAttributeItem(
                            attributeId: ca.id,
                            attributeName: ca.name,
                            isSelect: ca.isSelect,
                            isRequired: ca.isRequired,
                            options: ca.options ?? [],
                          ));
                          setState(() {});
                        },
                      ))
                  .toList(),
            ),
          ],
          // Variant Images
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: CustomerAppColors.surfaceContainerLowest,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: CustomerAppColors.surfaceContainerHigh),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${loc.getText('variantImages')} (${variant.totalImageCount}/7)',
                      style: AppTypography.caption12.copyWith(color: CustomerAppColors.textSecondary),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (var i = 0; i < variant.existingImages.length; i++)
                      _buildMediaThumbnail(
                        url: variant.existingImages[i].url,
                        type: variant.existingImages[i].type,
                        onRemove: () => _removeExistingVariantImage(index, i),
                      ),
                    for (var i = 0; i < variant.newImages.length; i++)
                      _buildMediaThumbnail(
                        file: variant.newImages[i].file,
                        type: variant.newImages[i].type,
                        onRemove: () => _removeNewVariantImage(index, i),
                      ),
                    if (variant.totalImageCount < 7)
                      GestureDetector(
                        onTap: () => _pickVariantImages(index),
                        child: Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            border: Border.all(color: CustomerAppColors.border, width: 2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.add_photo_alternate_outlined, color: CustomerAppColors.textSecondary, size: 24),
                              SizedBox(height: 4),
                              Text('Upload', style: TextStyle(fontSize: 10, color: CustomerAppColors.textSecondary)),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAttributeRow(int variantIndex, int attrIndex, AppLocalization loc) {
    final attr = _variants[variantIndex].attributes[attrIndex];
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '${attr.attributeName}${attr.isRequired ? ' *' : ''}',
              style: AppTypography.body12.copyWith(color: CustomerAppColors.textSecondary),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: attr.isSelect
                ? DropdownButton<int>(
                    value: attr.selectedOptionId,
                    isExpanded: true,
                    hint: Text(loc.getText('selectOption'), style: const TextStyle(fontSize: 12)),
                    items: attr.options
                        .map((o) => DropdownMenuItem(
                              value: o.id,
                              child: Text(o.value, style: const TextStyle(fontSize: 12)),
                            ))
                        .toList(),
                    onChanged: (val) => setState(() => attr.selectedOptionId = val),
                  )
                : SizedBox(
                    height: 32,
                    child: TextField(
                      controller: attr.textController,
                      style: const TextStyle(fontSize: 12),
                      decoration: InputDecoration(
                        hintText: loc.getText('enterCustomValue'),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                        isDense: true,
                      ),
                    ),
                  ),
          ),
          if (attr.isSelect) ...[
            const SizedBox(width: 4),
            GestureDetector(
              onTap: () => _showAddOptionDialog(attr.attributeId),
              child: const Icon(Icons.add_circle_outline, size: 18, color: CustomerAppColors.primary),
            ),
          ],
          const SizedBox(width: 4),
          GestureDetector(
            onTap: () {
              _variants[variantIndex].attributes.removeAt(attrIndex);
              setState(() {});
            },
            child: const Icon(Icons.close, size: 18, color: CustomerAppColors.error),
          ),
        ],
      ),
    );
  }

  Widget _buildCard({required String title, Widget? action, required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title, style: AppTypography.h2_18.copyWith(fontWeight: FontWeight.w600)),
              if (action != null) action,
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Text(text, style: AppTypography.body14.copyWith(fontWeight: FontWeight.w500));
  }

  InputDecoration _inputDecoration({String? hint}) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: CustomerAppColors.textSecondary.withOpacity(0.5)),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    );
  }

  Widget _buildSmallField({
    required String label,
    required TextEditingController controller,
    String? hint,
    TextInputType? keyboardType,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppTypography.caption12.copyWith(color: CustomerAppColors.textSecondary)),
        const SizedBox(height: 4),
        SizedBox(
          height: 36,
          child: TextField(
            controller: controller,
            keyboardType: keyboardType,
            style: const TextStyle(fontSize: 13),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: TextStyle(color: CustomerAppColors.textSecondary.withOpacity(0.5)),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              isDense: true,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState(String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        border: Border.all(color: CustomerAppColors.border, width: 2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(message, textAlign: TextAlign.center, style: const TextStyle(color: CustomerAppColors.textSecondary)),
    );
  }

  Widget _buildSmallButton(String label, IconData icon, VoidCallback onPressed) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 16),
      label: Text(label, style: const TextStyle(fontSize: 12)),
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  Widget _buildMediaThumbnail({
    String? url,
    File? file,
    required String type,
    required VoidCallback onRemove,
  }) {
    return Stack(
      children: [
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: CustomerAppColors.surfaceContainer,
          ),
          clipBehavior: Clip.antiAlias,
          child: type == 'video'
              ? const Center(child: Icon(Icons.videocam_outlined, color: CustomerAppColors.textSecondary, size: 28))
              : url != null
                  ? Image.network(url, fit: BoxFit.cover)
                  : file != null
                      ? Image.file(file, fit: BoxFit.cover)
                      : const SizedBox(),
        ),
        Positioned(
          top: 4,
          right: 4,
          child: GestureDetector(
            onTap: onRemove,
            child: Container(
              width: 20,
              height: 20,
              decoration: const BoxDecoration(color: CustomerAppColors.error, shape: BoxShape.circle),
              child: const Icon(Icons.close, size: 12, color: Colors.white),
            ),
          ),
        ),
        Positioned(
          bottom: 4,
          left: 4,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.6),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Icon(type == 'video' ? Icons.videocam : Icons.image, size: 10, color: Colors.white),
          ),
        ),
      ],
    );
  }
}

// ── Helper classes ──────────────────────────────────────────────

class _MediaItem {
  final File file;
  final String type;
  _MediaItem({required this.file, required this.type});
  void dispose() {}
}

class _VariantMediaItem {
  final File file;
  final String type;
  _VariantMediaItem({required this.file, required this.type});
  void dispose() {}
}

class _ExistingMediaItem {
  final String url;
  final String type;
  _ExistingMediaItem({required this.url, required this.type});
}

class _VariantItem {
  final TextEditingController skuController;
  final TextEditingController priceController;
  final TextEditingController stockController;
  List<_VariantAttributeItem> attributes;
  List<_VariantMediaItem> newImages;
  List<_ExistingMediaItem> existingImages;

  _VariantItem({
    required double price,
    required int stockQty,
    required String sku,
    List<_VariantAttributeItem>? attributes,
    List<_VariantMediaItem>? newImages,
    List<_ExistingMediaItem>? existingImages,
  })  : skuController = TextEditingController(text: sku),
        priceController = TextEditingController(text: price.toString()),
        stockController = TextEditingController(text: stockQty.toString()),
        attributes = attributes ?? [],
        newImages = newImages ?? [],
        existingImages = existingImages ?? [];

  factory _VariantItem.fromExisting(ProductVariant variant) {
    return _VariantItem(
      price: variant.price ?? 0,
      stockQty: variant.stockQty,
      sku: variant.sku ?? '',
      attributes: variant.attributes
          ?.map((a) => _VariantAttributeItem(
                attributeId: a.attributeId,
                attributeName: a.attribute?.name ?? '',
                isSelect: a.attribute?.isSelect ?? false,
                isRequired: a.attribute?.isRequired ?? false,
                options: a.attribute?.options ?? [],
                selectedOptionId: a.optionId,
                textController: TextEditingController(text: a.value ?? ''),
              ))
          .toList(),
      existingImages: variant.images
          ?.map((img) => _ExistingMediaItem(url: img.url, type: img.type))
          .toList(),
    );
  }

  int get totalImageCount => newImages.length + existingImages.length;

  void dispose() {
    skuController.dispose();
    priceController.dispose();
    stockController.dispose();
    for (final a in attributes) {
      a.dispose();
    }
    for (final m in newImages) {
      m.dispose();
    }
  }
}

class _VariantAttributeItem {
  final int attributeId;
  final String attributeName;
  final bool isSelect;
  final bool isRequired;
  List<CategoryAttributeOption> options;
  int? selectedOptionId;
  final TextEditingController textController;

  _VariantAttributeItem({
    required this.attributeId,
    required this.attributeName,
    required this.isSelect,
    this.isRequired = false,
    required this.options,
    this.selectedOptionId,
    TextEditingController? textController,
  }) : textController = textController ?? TextEditingController();

  void dispose() {
    textController.dispose();
  }
}
