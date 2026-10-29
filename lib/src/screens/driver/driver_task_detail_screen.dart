import 'dart:developer' as developer;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:yallashop_core/yallashop_core.dart';
import '../../config/api_config.dart';
import '../../widgets/unified_app_bar.dart';

List<dynamic> _extractList(dynamic payload) {
  if (payload is List) return payload;
  if (payload is Map<String, dynamic> && payload.containsKey('data')) {
    final inner = payload['data'];
    if (inner is List) return inner;
    if (inner is Map<String, dynamic> && inner.containsKey('data') && inner['data'] is List) {
      return inner['data'] as List<dynamic>;
    }
  }
  return [];
}

class DriverTaskDetailScreen extends StatefulWidget {
  final String taskId;
  const DriverTaskDetailScreen({super.key, required this.taskId});

  @override
  State<DriverTaskDetailScreen> createState() => _DriverTaskDetailScreenState();
}

class _DriverTaskDetailScreenState extends State<DriverTaskDetailScreen> {
  final _apiClient = ApiClient(baseUrl: CustomerApiConfig.baseUrl);
  Map<String, dynamic>? _task;
  bool _isLoading = true;
  String? _error;
  String? _actionError;
  final _pickupCodeController = TextEditingController();
  final _deliveryCodeController = TextEditingController();

  // HTML color palette
  static const Color _primary = Color(0xFFba002c);
  static const Color _background = Color(0xFFF9F9FF);
  static const Color _onSurface = Color(0xFF151c27);
  static const Color _onSecondaryContainer = Color(0xFF636467);
  static const Color _surfaceContainerHigh = Color(0xFFE2E8F8);
  static const Color _surfaceContainerLowest = Color(0xFFFFFFFF);
  static const Color _outlineVariant = Color(0xFFE5BDBC);
  static const Color _success = Color(0xFF2E7D32);

  static const _bgImage =
      'https://lh3.googleusercontent.com/aida/AP1WRLuFHvA6DuJAhqv57RGAplxC5T_6PWZYMT6Oab6Lw814WiacRP1SjRb8iRwIHEvtoUyCmzE-un2s8hf7ZmQWOq4pxzk2KJVrzRqhFMj6HU1NLEn8BIrKF9i9lZVNrchZzSRzeaimrwbg8CAVnyQzwneCNip9TShTTk5wXx_rGlTBA9mmAGSCGku_CI1Qwe_ppWNefIePHNrhR2p4RuarhLuowex9KyEqT16Xpkj25vLRijZzPLLcF8VUk7xn';

  @override
  void initState() {
    super.initState();
    _loadTask();
  }

  @override
  void dispose() {
    _pickupCodeController.dispose();
    _deliveryCodeController.dispose();
    super.dispose();
  }

  Future<void> _loadTask() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      Map<String, dynamic>? found;

      final activeResult = await _apiClient.get<dynamic>('/courier/tasks/active');
      if (!mounted) return;
      if (activeResult is Success) {
        final activeTasks = _extractList(activeResult.data);
        for (final t in activeTasks) {
          if ('${(t as Map)['id']}' == widget.taskId) {
            found = t as Map<String, dynamic>;
            break;
          }
        }
      }

      if (found == null) {
        final availableResult = await _apiClient.get<dynamic>('/courier/tasks');
        if (!mounted) return;
        if (availableResult is Success) {
          final availableTasks = _extractList(availableResult.data);
          for (final t in availableTasks) {
            if ('${(t as Map)['id']}' == widget.taskId) {
              found = t as Map<String, dynamic>;
              break;
            }
          }
        }
      }

      if (found != null && mounted) {
        setState(() => _task = found);
      } else if (mounted) {
        final loc = AppLocalization.of(context)!;
        setState(() => _error = loc.getText('taskNotFound'));
      }
    } catch (e, stack) {
      developer.log('Error loading task: $e', name: 'DriverTask', error: e, stackTrace: stack);
      if (mounted) setState(() => _error = e.toString());
    }

    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _acceptTask() async {
    setState(() => _actionError = null);
    final result = await _apiClient.post('/courier/tasks/${widget.taskId}/accept');
    if (result is Success) {
      _loadTask();
    } else if (result is Failure) {
      setState(() => _actionError = result.exception.message);
    }
  }

  Future<void> _rejectTask() async {
    await _apiClient.post('/courier/tasks/${widget.taskId}/reject');
    if (mounted) context.go('/driver');
  }

  Future<void> _verifyPickupCode() async {
    final code = _pickupCodeController.text.trim();
    if (code.length != 6) {
      final loc = AppLocalization.of(context)!;
      setState(() => _actionError = loc.getText('pleaseEnterSixDigitCode'));
      return;
    }
    final result = await _apiClient.post(
      '/courier/tasks/${widget.taskId}/verify-pickup',
      data: {'pickup_code': code},
    );
    if (result is Success) {
      _pickupCodeController.clear();
      setState(() => _actionError = null);
      _loadTask();
    } else if (result is Failure) {
      setState(() => _actionError = result.exception.message);
    }
  }

  Future<void> _verifyDeliveryCode() async {
    final code = _deliveryCodeController.text.trim();
    if (code.length != 6) {
      final loc = AppLocalization.of(context)!;
      setState(() => _actionError = loc.getText('pleaseEnterSixDigitCode'));
      return;
    }
    final result = await _apiClient.post(
      '/courier/tasks/${widget.taskId}/verify-delivery',
      data: {'delivery_code': code},
    );
    if (result is Success) {
      _deliveryCodeController.clear();
      setState(() => _actionError = null);
      _loadTask();
    } else if (result is Failure) {
      setState(() => _actionError = result.exception.message);
    }
  }

  // ═══════════════════════════════════════════════════════════════════
  // BUILD
  // ═══════════════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    final loc = AppLocalization.of(context)!;

    if (_isLoading) {
      return Scaffold(
        backgroundColor: _background,
        body: Center(child: CircularProgressIndicator(color: _primary)),
      );
    }

    if (_error != null) {
      return Scaffold(
        backgroundColor: _background,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 16),
              Text(_error!, style: const TextStyle(color: Colors.red)),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _loadTask,
                style: ElevatedButton.styleFrom(backgroundColor: _primary),
                child: Text(loc.getText('retry'), style: const TextStyle(color: Colors.white)),
              ),
            ],
          ),
        ),
      );
    }

    final task = _task;
    if (task == null) {
      return Scaffold(
        backgroundColor: _background,
        body: Center(child: Text(loc.getText('taskNotFound'))),
      );
    }

    final status = task['status'] as String? ?? 'pending';
    final store = task['store'] as Map<String, dynamic>?;
    final items = task['items'] as List<dynamic>? ?? [];
    final addr = task['delivery_address_snapshot'] as Map<String, dynamic>?;
    final orderId = task['order_id'] ?? '-';
    final deliveryFee = (task['delivery_fee'] ?? '0').toString();
    final currencyMap = task['currency'] as Map<String, dynamic>?;
    final currencySymbol = (currencyMap?['symbol'] ?? 'SAR').toString();
    final totalAmount = (task['total_amount'] ?? '').toString();

    // Extract store address
    final storeAddress = store?['address'] ?? store?['full_address'];
    final storeCity = store?['city'];

    return Scaffold(
      extendBodyBehindAppBar: true,
      extendBody: true,
      backgroundColor: _background,
      appBar: UnifiedAppBar.detail(
        title: loc.getText('taskNumber', params: {'number': widget.taskId}),
        backgroundColor: Colors.transparent,
        opaqueOnScroll: true,
        showBackButton: true,
        showUserAvatar: true,
        onBackPressed: () => context.go('/driver'),
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Background image — full screen
          Image.network(
            _bgImage,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => const SizedBox.shrink(),
          ),

          // Main scrollable content
          SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.fromLTRB(20, MediaQuery.of(context).padding.top + 64 + 16, 20, 100),
            child: Column(
              children: [
                // Error banner
                if (_actionError != null) _buildErrorBanner(),

                // Status header
                _buildStatusHeader(status, orderId, loc),
                const SizedBox(height: 16),

                // Store section (no codes shown to driver)
                _buildStoreSection(store, storeCity, storeAddress, loc),
                const SizedBox(height: 16),

                // Delivery address
                if (addr != null) _buildDeliveryAddress(addr, loc),
                const SizedBox(height: 16),

                // Order items
                _buildOrderItems(items, currencySymbol, loc),
                const SizedBox(height: 16),

                // Price summary
                _buildPriceSummary(items, deliveryFee, currencySymbol, totalAmount, loc),
                const SizedBox(height: 16),

                // Action buttons
                _buildActionButtons(status, loc),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  // ERROR BANNER
  // ═══════════════════════════════════════════════════════════════════
  Widget _buildErrorBanner() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: _glassCard(
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFba1a1a).withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            _actionError!,
            style: const TextStyle(color: Color(0xFFba1a1a)),
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  // STATUS HEADER
  // ═══════════════════════════════════════════════════════════════════
  Widget _buildStatusHeader(String status, dynamic orderId, AppLocalization loc) {
    final statusKey = 'taskStatus${status.split('_').map((s) => s[0].toUpperCase() + s.substring(1)).join('')}';
    final statusText = loc.getText(statusKey);
    
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          loc.getText('taskNumber', params: {'number': orderId.toString()}),
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: _onSurface,
            height: 28 / 20,
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          decoration: BoxDecoration(
            color: _getStatusColor(status),
            borderRadius: BorderRadius.circular(9999),
          ),
          child: Text(
            statusText.toUpperCase(),
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: Colors.white,
              letterSpacing: 1.5,
            ),
          ),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  // STORE SECTION (with codes)
  // ═══════════════════════════════════════════════════════════════════
  Widget _buildStoreSection(
    Map<String, dynamic>? store,
    dynamic storeCity,
    dynamic storeAddress,
    AppLocalization loc,
  ) {
    if (store == null) return const SizedBox.shrink();

    // Extract vendor contact info
    final storePhone = store['phone'] ?? store['contact_phone'];
    final storeEmail = store['email'] ?? store['contact_email'];

    return _glassCard(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Store info header
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      loc.getText('storeLabel'),
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: _onSecondaryContainer,
                        letterSpacing: 1.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      store['name'] ?? loc.getText('defaultStore'),
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                        color: _onSurface,
                        height: 28 / 20,
                      ),
                    ),
                    if (storeCity != null || storeAddress != null) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(Icons.location_on, size: 16, color: _onSecondaryContainer),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              '${storeCity ?? ''}${storeCity != null && storeAddress != null ? ', ' : ''}${storeAddress ?? ''}',
                              style: const TextStyle(
                                fontSize: 14,
                                color: _onSecondaryContainer,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              // Store icon
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.storefront, color: _primary, size: 24),
              ),
            ],
          ),

          // Contact information
          if (storePhone != null || storeEmail != null) ...[
            const SizedBox(height: 20),
            Container(
              height: 1,
              color: _outlineVariant.withValues(alpha: 0.2),
            ),
            const SizedBox(height: 16),
            Text(
              loc.getText('contactInformation'),
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: _onSecondaryContainer,
                letterSpacing: 1.5,
              ),
            ),
            const SizedBox(height: 12),
            if (storePhone != null)
              _buildContactRow(
                icon: Icons.phone,
                label: loc.getText('phone'),
                value: storePhone.toString(),
                onTap: () {},
              ),
            if (storePhone != null && storeEmail != null)
              const SizedBox(height: 8),
            if (storeEmail != null)
              _buildContactRow(
                icon: Icons.email,
                label: loc.getText('email'),
                value: storeEmail.toString(),
                onTap: () {},
              ),
          ],
        ],
      ),
    );
  }

  Widget _buildContactRow({
    required IconData icon,
    required String label,
    required String value,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: _surfaceContainerHigh.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: _primary),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: _onSecondaryContainer,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: _onSurface,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, size: 20, color: _onSecondaryContainer),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  // DELIVERY ADDRESS
  // ═══════════════════════════════════════════════════════════════════
  Widget _buildDeliveryAddress(Map<String, dynamic> addr, AppLocalization loc) {
    return _glassCard(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            loc.getText('deliveryAddressLabel'),
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: _onSecondaryContainer,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _surfaceContainerHigh,
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.location_on, size: 20, color: _onSecondaryContainer),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (addr['area'] != null)
                      Text(
                        addr['area'],
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: _onSurface,
                        ),
                      ),
                    if (addr['full_address'] != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          addr['full_address'],
                          style: const TextStyle(
                            fontSize: 14,
                            color: _onSecondaryContainer,
                            height: 20 / 14,
                          ),
                        ),
                      ),
                    if (addr['floor'] != null || addr['apartment'] != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          [
                            if (addr['floor'] != null) loc.getText('floorLabel', params: {'number': '${addr['floor']}'}),
                            if (addr['apartment'] != null) loc.getText('apartmentLabel', params: {'number': '${addr['apartment']}'}),
                          ].join(', '),
                          style: const TextStyle(
                            fontSize: 14,
                            color: _onSecondaryContainer,
                          ),
                        ),
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

  // ═══════════════════════════════════════════════════════════════════
  // ORDER ITEMS
  // ═══════════════════════════════════════════════════════════════════
  Widget _buildOrderItems(List<dynamic> items, String currencySymbol, AppLocalization loc) {
    return _glassCard(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                loc.getText('orderItemsLabel'),
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: _onSecondaryContainer,
                  letterSpacing: 1.5,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: _surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(4),
                ),
                  child: Text(
                    loc.getText('itemsCount', params: {'count': items.length.toString()}),
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: _onSurface,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...items.asMap().entries.map((entry) {
            final index = entry.key;
            final item = entry.value;
            final itemMap = _parseItem(item);
            final name = _getItemName(itemMap, loc);
            final qty = itemMap['qty'] ?? 1;
            final totalPrice = _getItemPrice(itemMap);
            final imageUrl = _getItemImage(itemMap);
            final isLast = index == items.length - 1;

            return Container(
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: isLast
                  ? null
                  : BoxDecoration(
                      border: Border(
                        bottom: BorderSide(
                          color: _outlineVariant.withValues(alpha: 0.2),
                        ),
                      ),
                    ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: _surfaceContainerHigh,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: imageUrl != null
                            ? Image.network(
                                imageUrl,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => const Icon(Icons.fastfood, size: 24, color: Color(0xFF5a5c5d)),
                              )
                            : const Icon(Icons.fastfood, size: 24, color: Color(0xFF5a5c5d)),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: _onSurface,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            loc.getText('qtyLabel', params: {'qty': qty.toString()}),
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: _onSecondaryContainer,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  Text(
                    '$totalPrice $currencySymbol',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: _onSurface,
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  // Helper to parse item from various formats
  Map<String, dynamic> _parseItem(dynamic item) {
    if (item is Map<String, dynamic>) return item;
    try {
      return item.toJson() as Map<String, dynamic>;
    } catch (_) {
      return {};
    }
  }

  // Helper to extract item name from nested structure
  String _getItemName(Map<String, dynamic> itemMap, AppLocalization loc) {
    // Try direct product name
    if (itemMap['product_name'] != null) return itemMap['product_name'].toString();
    if (itemMap['name'] != null) return itemMap['name'].toString();
    
    // Try variant -> product structure
    final variant = itemMap['variant'];
    if (variant is Map<String, dynamic>) {
      final product = variant['product'];
      if (product is Map<String, dynamic>) {
        return product['title'] ?? product['name'] ?? loc.getText('defaultProduct');
      }
    }
    
    // Try product directly
    final product = itemMap['product'];
    if (product is Map<String, dynamic>) {
      return product['title'] ?? product['name'] ?? loc.getText('defaultProduct');
    }
    
    return loc.getText('defaultProduct');
  }

  // Helper to extract item image from nested structure
  String? _getItemImage(Map<String, dynamic> itemMap) {
    String? firstUrl(List<dynamic>? images) {
      if (images == null || images.isEmpty) return null;
      final img = images.first;
      if (img is Map<String, dynamic>) {
        final url = img['url'];
        return url != null ? url.toString() : null;
      }
      return null;
    }

    final variant = itemMap['variant'];
    if (variant is Map<String, dynamic>) {
      final variantImages = variant['images'] as List<dynamic>?;
      final vimg = firstUrl(variantImages);
      if (vimg != null) return vimg;

      final product = variant['product'];
      if (product is Map<String, dynamic>) {
        final productImages = product['images'] as List<dynamic>?;
        final pimg = firstUrl(productImages);
        if (pimg != null) return pimg;
      }
    }

    final images = itemMap['images'] as List<dynamic>?;
    return firstUrl(images);
  }

  // Helper to extract item price from nested structure
  double _getItemPrice(Map<String, dynamic> itemMap) {
    // Try various price fields
    final priceFields = ['total_price', 'price', 'unit_price', 'subtotal'];
    for (final field in priceFields) {
      if (itemMap[field] != null) {
        final val = itemMap[field];
        if (val is num) return val.toDouble();
        if (val is String) return double.tryParse(val) ?? 0.0;
      }
    }
    
    // Try variant price
    final variant = itemMap['variant'];
    if (variant is Map<String, dynamic>) {
      if (variant['price'] != null) {
        final val = variant['price'];
        if (val is num) return val.toDouble();
        if (val is String) return double.tryParse(val) ?? 0.0;
      }
    }
    
    return 0.0;
  }

  // ═══════════════════════════════════════════════════════════════════
  // PRICE SUMMARY
  // ═══════════════════════════════════════════════════════════════════
  Widget _buildPriceSummary(List<dynamic> items, String deliveryFee, String currencySymbol, String totalAmount, AppLocalization loc) {
    // Calculate subtotal using helper function
    final subtotal = items.fold(0.0, (double sum, item) {
      final m = _parseItem(item);
      return sum + _getItemPrice(m);
    });
    
    final fee = double.tryParse(deliveryFee) ?? 0;
    final total = subtotal + fee;

    return _glassCard(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            loc.getText('paymentDetails'),
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: _onSecondaryContainer,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 16),
          _buildSummaryRow(loc.getText('subtotal'), '${subtotal.toStringAsFixed(2)} $currencySymbol'),
          const SizedBox(height: 12),
          _buildSummaryRow(loc.getText('deliveryFee'), '${fee.toStringAsFixed(2)} $currencySymbol'),
          const SizedBox(height: 16),
          Container(
            height: 1,
            color: _outlineVariant.withValues(alpha: 0.3),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                loc.getText('total'),
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: _onSurface,
                  height: 28 / 20,
                ),
              ),
              Text(
                '${total.toStringAsFixed(2)} $currencySymbol',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: _primary,
                  height: 28 / 20,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            color: _onSecondaryContainer,
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: _onSurface,
          ),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  // ACTION BUTTONS
  // ═══════════════════════════════════════════════════════════════════
  Widget _buildActionButtons(String status, AppLocalization loc) {
    if (status == 'ready_for_pickup') {
      return Row(
        children: [
          Expanded(
            child: ElevatedButton(
              onPressed: _acceptTask,
              style: ElevatedButton.styleFrom(
                backgroundColor: _success,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: Text(loc.getText('acceptTask')),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: OutlinedButton(
              onPressed: _rejectTask,
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFFba1a1a),
                side: const BorderSide(color: Color(0xFFba1a1a)),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: Text(loc.getText('reject')),
            ),
          ),
        ],
      );
    }

    if (status == 'waiting_for_driver') {
      return _buildCodeVerificationCard(
        icon: Icons.vpn_key,
        title: loc.getText('enterPickupCode'),
        controller: _pickupCodeController,
        onPressed: _verifyPickupCode,
        buttonColor: _primary,
        loc: loc,
      );
    }

    if (status == 'with_driver') {
      return _buildCodeVerificationCard(
        icon: Icons.check_circle,
        title: loc.getText('enterDeliveryCode'),
        controller: _deliveryCodeController,
        onPressed: _verifyDeliveryCode,
        buttonColor: _success,
        loc: loc,
      );
    }

    if (status == 'delivered') {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: _success.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            const Icon(Icons.check_circle, size: 48, color: _success),
            const SizedBox(height: 12),
            Text(
              loc.getText('completed'),
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: _success,
              ),
            ),
          ],
        ),
      );
    }

    return const SizedBox.shrink();
  }

  Widget _buildCodeVerificationCard({
    required IconData icon,
    required String title,
    required TextEditingController controller,
    required VoidCallback onPressed,
    required Color buttonColor,
    required AppLocalization loc,
  }) {
    return _glassCard(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: buttonColor, size: 24),
              const SizedBox(width: 12),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: _onSurface,
                  height: 28 / 20,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            maxLength: 6,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 24,
              letterSpacing: 8,
              fontWeight: FontWeight.w700,
            ),
            decoration: InputDecoration(
              hintText: '------',
              counterText: '',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: onPressed,
              style: ElevatedButton.styleFrom(
                backgroundColor: buttonColor,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: Text(title.contains('Pickup') || title.contains('استلام') ? loc.getText('verifyPickup') : loc.getText('verifyDelivery')),
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  // GLASS CARD
  // ═══════════════════════════════════════════════════════════════════
  Widget _glassCard({required Widget child, EdgeInsetsGeometry? padding}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          padding: padding ?? const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _surfaceContainerLowest.withValues(alpha: 0.75),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withValues(alpha: 0.4)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  // HELPERS
  // ═══════════════════════════════════════════════════════════════════
  Color _getStatusColor(String s) {
    switch (s) {
      case 'ready_for_pickup':
        return const Color(0xFF3B82F6);
      case 'waiting_for_driver':
        return CustomerAppColors.warning;
      case 'waiting_for_pickup':
        return _primary;
      case 'with_driver':
        return _primary;
      case 'delivered':
        return _success;
      default:
        return CustomerAppColors.textSecondary;
    }
  }
}
