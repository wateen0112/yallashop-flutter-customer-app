import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:yallashop_core/yallashop_core.dart';

import '../../core/bloc/auth_bloc.dart';
import '../../core/bloc/auth_event.dart';
import '../../core/bloc/auth_state.dart';
import '../../config/api_config.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  late TextEditingController _nameController;
  late TextEditingController _emailController;
  late TextEditingController _phoneController;
  late ApiClient _apiClient;
  bool _isLoading = false;
  String? _avatarUrl;
  String? _coverPhotoUrl;
  File? _pickedImage;
  File? _pickedCover;

  // Vendor working hours
  bool _isVendor = false;
  Map<String, Map<String, dynamic>> _workingHours = {};

  static const _days = ['monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday', 'sunday'];

  @override
  void initState() {
    super.initState();
    _apiClient = ApiClient(baseUrl: CustomerApiConfig.baseUrl);
    final state = context.read<AuthBloc>().state;
    if (state is Authenticated) {
      _nameController = TextEditingController(text: state.user.name);
      _emailController = TextEditingController(text: state.user.email ?? '');
      _phoneController = TextEditingController(text: state.user.phone);
      _avatarUrl = state.user.avatar;
      _coverPhotoUrl = state.user.coverPhoto;
      _isVendor = state.user.role == 'vendor';

      // Initialize default working hours
      for (final day in _days) {
        _workingHours[day] = {
          'day': day,
          'open_time': '09:00',
          'close_time': '22:00',
          'is_closed': day == 'friday',
        };
      }
    } else {
      _nameController = TextEditingController();
      _emailController = TextEditingController();
      _phoneController = TextEditingController();
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _pickImage({bool isCover = false}) async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: CustomerAppColors.background,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(width: 40, height: 4,
              decoration: BoxDecoration(color: CustomerAppColors.border, borderRadius: BorderRadius.circular(2)),
            ),
            const SizedBox(height: 20),
            ListTile(
              leading: const Icon(Icons.camera_alt, color: CustomerAppColors.primary),
              title: const Text('Camera'),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library, color: CustomerAppColors.primary),
              title: const Text('Gallery'),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );

    if (source == null) return;

    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: source,
      maxWidth: isCover ? 1200 : 512,
      maxHeight: isCover ? 600 : 512,
      imageQuality: 80,
    );
    if (picked == null) return;

    setState(() {
      if (isCover) {
        _pickedCover = File(picked.path);
      } else {
        _pickedImage = File(picked.path);
      }
    });
  }

  Future<String?> _uploadImage(File file, String folder) async {
    try {
      final storage = const FlutterSecureStorage();
      final token = await storage.read(key: 'auth_token');

      final dio = Dio(BaseOptions(
        baseUrl: CustomerApiConfig.baseUrl,
        connectTimeout: const Duration(seconds: 30),
        receiveTimeout: const Duration(seconds: 30),
      ));

      final fileName = file.path.split(Platform.pathSeparator).last;
      final formData = FormData.fromMap({
        'file': await MultipartFile.fromFile(file.path, filename: fileName),
        'folder': folder,
      });

      final response = await dio.post(
        '/profile/upload',
        data: formData,
        options: Options(
          headers: {
            if (token != null) 'Authorization': 'Bearer $token',
            'Content-Type': 'multipart/form-data',
          },
        ),
      );

      if (response.statusCode == 201) {
        return response.data['data']['url'] as String?;
      }
    } catch (e) {
      debugPrint('Upload error: $e');
    }
    return null;
  }

  Future<void> _saveProfile() async {
    setState(() => _isLoading = true);

    try {
      String? avatarUrl = _avatarUrl;
      String? coverUrl = _coverPhotoUrl;

      if (_pickedImage != null) {
        avatarUrl = await _uploadImage(_pickedImage!, 'avatars');
      }
      if (_pickedCover != null) {
        coverUrl = await _uploadImage(_pickedCover!, 'covers');
      }

      final data = <String, dynamic>{
        'name': _nameController.text.trim(),
        'email': _emailController.text.trim(),
        'phone': _phoneController.text.trim(),
        if (avatarUrl != null) 'avatar': avatarUrl,
      };

      if (_isVendor) {
        if (coverUrl != null) data['cover_photo'] = coverUrl;
        data['working_hours'] = _workingHours.values.toList();
      }

      final result = await _apiClient.patch<Map<String, dynamic>>('/profile', data: data);

      if (result is Success<Map<String, dynamic>>) {
        final user = User.fromJson(result.data);
        if (mounted) {
          context.read<AuthBloc>().add(ProfileUpdated(user: user));
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Profile updated'), backgroundColor: Colors.green),
          );
          context.pop();
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
          SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _pickTime({required String day, required bool isOpen}) async {
    final current = isOpen
        ? (_workingHours[day]?['open_time'] ?? '09:00')
        : (_workingHours[day]?['close_time'] ?? '22:00');

    final parts = current.split(':');
    final initial = TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));

    final picked = await showTimePicker(
      context: context,
      initialTime: initial,
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
          child: child!,
        );
      },
    );

    if (picked != null) {
      final timeStr = '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
      setState(() {
        if (isOpen) {
          _workingHours[day]!['open_time'] = timeStr;
        } else {
          _workingHours[day]!['close_time'] = timeStr;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: CustomerAppColors.background,
      appBar: AppBar(
        backgroundColor: CustomerAppColors.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: CustomerAppColors.secondary),
          onPressed: () => context.pop(),
        ),
        title: Text(
          'Edit Profile',
          style: AppTypography.h2_18.copyWith(fontWeight: FontWeight.w600, color: CustomerAppColors.onSurface),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Cover photo + avatar stacked (vendor only)
            if (_isVendor) ...[
              _buildCoverPhotoWithAvatar(),
              const SizedBox(height: 24),
            ],
            // Avatar (non-vendor)
            if (!_isVendor) ...[
              Center(child: _buildAvatar()),
              const SizedBox(height: 24),
            ],
            // Form fields
            _buildField('Name', _nameController, Icons.person_outline),
            const SizedBox(height: 16),
            _buildField('Email', _emailController, Icons.email_outlined, keyboardType: TextInputType.emailAddress),
            const SizedBox(height: 16),
            _buildField('Phone', _phoneController, Icons.phone_outlined, keyboardType: TextInputType.phone),

            // Working hours (vendor only)
            if (_isVendor) ...[
              const SizedBox(height: 24),
              Text('Working Hours', style: AppTypography.h2_18.copyWith(fontWeight: FontWeight.w600, color: CustomerAppColors.onSurface)),
              const SizedBox(height: 12),
              _buildWorkingHours(),
            ],

            const SizedBox(height: 32),
            // Save button
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _saveProfile,
                style: ElevatedButton.styleFrom(
                  backgroundColor: CustomerAppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                ),
                child: _isLoading
                    ? const SizedBox(width: 22, height: 22,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : Text('Save Changes', style: AppTypography.body14.copyWith(fontWeight: FontWeight.w600, color: Colors.white)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCoverPhotoWithAvatar() {
    return SizedBox(
      height: 220,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          // Cover photo
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: GestureDetector(
              onTap: () => _pickImage(isCover: true),
              child: Container(
                height: 160,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: CustomerAppColors.surfaceAlt,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: CustomerAppColors.border),
                ),
                clipBehavior: Clip.antiAlias,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (_pickedCover != null)
                      Image.file(_pickedCover!, fit: BoxFit.cover)
                    else if (_coverPhotoUrl != null && _coverPhotoUrl!.isNotEmpty)
                      Image.network(_coverPhotoUrl!, fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => _buildCoverPlaceholder())
                    else
                      _buildCoverPlaceholder(),
                    Positioned(
                      bottom: 12,
                      right: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.camera_alt, size: 16, color: Colors.white),
                            SizedBox(width: 6),
                            Text('Cover Photo', style: TextStyle(color: Colors.white, fontSize: 12)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          // Avatar overlapping the bottom of cover
          Positioned(
            bottom: 0,
            child: _buildAvatar(),
          ),
        ],
      ),
    );
  }

  Widget _buildCoverPhoto() {
    return GestureDetector(
      onTap: () => _pickImage(isCover: true),
      child: Container(
        height: 160,
        width: double.infinity,
        decoration: BoxDecoration(
          color: CustomerAppColors.surfaceAlt,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: CustomerAppColors.border),
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (_pickedCover != null)
              Image.file(_pickedCover!, fit: BoxFit.cover)
            else if (_coverPhotoUrl != null && _coverPhotoUrl!.isNotEmpty)
              Image.network(_coverPhotoUrl!, fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _buildCoverPlaceholder())
            else
              _buildCoverPlaceholder(),
            Positioned(
              bottom: 12,
              right: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.camera_alt, size: 16, color: Colors.white),
                    SizedBox(width: 6),
                    Text('Cover Photo', style: TextStyle(color: Colors.white, fontSize: 12)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCoverPlaceholder() {
    return Container(
      color: CustomerAppColors.surfaceAlt,
      child: const Center(
        child: Icon(Icons.image_outlined, size: 48, color: CustomerAppColors.textSecondary),
      ),
    );
  }

  Widget _buildAvatar() {
    return GestureDetector(
      onTap: () => _pickImage(isCover: false),
      child: Stack(
        alignment: Alignment.bottomRight,
        children: [
          Container(
            width: 100, height: 100,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: CustomerAppColors.primary, width: 3),
            ),
            child: ClipOval(
              child: _pickedImage != null
                  ? Image.file(_pickedImage!, fit: BoxFit.cover)
                  : _avatarUrl != null && _avatarUrl!.isNotEmpty
                      ? Image.network(_avatarUrl!, fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => _buildDefaultAvatar())
                      : _buildDefaultAvatar(),
            ),
          ),
          Container(
            width: 32, height: 32,
            decoration: BoxDecoration(
              color: CustomerAppColors.primary,
              shape: BoxShape.circle,
              border: Border.all(color: CustomerAppColors.background, width: 2),
            ),
            child: const Icon(Icons.camera_alt, size: 16, color: Colors.white),
          ),
        ],
      ),
    );
  }

  Widget _buildDefaultAvatar() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [CustomerAppColors.primary, CustomerAppColors.accentGold],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: const Center(child: Icon(Icons.person, size: 44, color: Colors.white)),
    );
  }

  Widget _buildField(String label, TextEditingController controller, IconData icon, {TextInputType? keyboardType}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: CustomerAppColors.border),
      ),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        style: AppTypography.body14.copyWith(color: CustomerAppColors.onSurface),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: AppTypography.body14.copyWith(color: CustomerAppColors.textSecondary),
          prefixIcon: Icon(icon, color: CustomerAppColors.primary, size: 22),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        ),
      ),
    );
  }

  Widget _buildWorkingHours() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: CustomerAppColors.border),
      ),
      child: Column(
        children: _days.map((day) {
          final hours = _workingHours[day]!;
          final isClosed = hours['is_closed'] as bool;

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: Text(
                        day[0].toUpperCase() + day.substring(1),
                        style: AppTypography.body14.copyWith(
                          fontWeight: FontWeight.w600,
                          color: CustomerAppColors.onSurface,
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 3,
                      child: isClosed
                          ? Text('Closed', style: AppTypography.body14.copyWith(color: CustomerAppColors.textSecondary))
                          : Row(
                              children: [
                                _buildTimeButton(day, true),
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 6),
                                  child: Text('to', style: AppTypography.caption12.copyWith(color: CustomerAppColors.textSecondary)),
                                ),
                                _buildTimeButton(day, false),
                              ],
                            ),
                    ),
                    Switch(
                      value: !isClosed,
                      onChanged: (val) => setState(() => hours['is_closed'] = !val),
                      activeColor: CustomerAppColors.primary,
                    ),
                  ],
                ),
              ),
              if (day != 'sunday')
                Divider(height: 1, indent: 16, endIndent: 16, color: CustomerAppColors.border),
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget _buildTimeButton(String day, bool isOpen) {
    final hours = _workingHours[day]!;
    final time = isOpen ? hours['open_time'] : hours['close_time'];

    return GestureDetector(
      onTap: () => _pickTime(day: day, isOpen: isOpen),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: CustomerAppColors.surfaceAlt,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          time,
          style: AppTypography.body14.copyWith(
            color: CustomerAppColors.onSurface,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}
