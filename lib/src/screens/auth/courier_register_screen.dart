import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:yallashop_core/yallashop_core.dart';

import '../../core/bloc/auth_bloc.dart';
import '../../core/bloc/auth_event.dart';
import '../../core/bloc/auth_state.dart';
import '../../widgets/location_selector.dart';

class CourierRegisterScreen extends StatefulWidget {
  const CourierRegisterScreen({super.key});

  @override
  State<CourierRegisterScreen> createState() => _CourierRegisterScreenState();
}

class _CourierRegisterScreenState extends State<CourierRegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  String _vehicleType = 'motorcycle';
  bool _obscurePassword = true;
  bool _obscureConfirm = true;

  // Location fields
  String? _governorate;
  String? _city;
  String? _area;

  void _onLocationSelected(String gov, String city, String area) {
    setState(() {
      _governorate = gov;
      _city = city;
      _area = area;
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _onRegister() {
    if (_formKey.currentState?.validate() ?? false) {
      if (_governorate == null || _city == null || _area == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please select your location'),
            backgroundColor: CustomerAppColors.error,
          ),
        );
        return;
      }

      context.read<AuthBloc>().add(RegisterRequested(
            name: _nameController.text.trim(),
            email: _emailController.text.trim(),
            phone: _phoneController.text.trim(),
            password: _passwordController.text,
            governorate: _governorate!,
            city: _city!,
            area: _area!,
            role: 'courier',
          ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalization.of(context)!;

    return BlocListener<AuthBloc, AuthState>(
      listener: (context, state) {
        if (state is Authenticated) {
          context.go('/');
        } else if (state is AuthError) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.message),
              backgroundColor: CustomerAppColors.error,
            ),
          );
        }
      },
      child: Scaffold(
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                CustomerAppColors.primary,
                Color(0xFFD6203F),
              ],
            ),
          ),
          child: SafeArea(
            child: Column(
              children: [
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: Padding(
                    padding: const EdgeInsets.all(AppDimensions.sm),
                    child: IconButton(
                      onPressed: () => context.go('/login'),
                      icon: const Icon(
                        Icons.arrow_back,
                        color: CustomerAppColors.secondary,
                        size: 20,
                      ),
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppDimensions.radiusFull),
                        ),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: AppDimensions.lg),
                    child: Column(
                      children: [
                        const SizedBox(height: AppDimensions.xxl),
                        Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.delivery_dining,
                            size: 40,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: AppDimensions.md),
                        Text(
                          loc.getText('joinAsCourier'),
                          textAlign: TextAlign.center,
                          style: AppTypography.display28.copyWith(color: Colors.white),
                        ),
                        const SizedBox(height: AppDimensions.xs),
                        Text(
                          loc.getText('deliverWithYallaShop'),
                          textAlign: TextAlign.center,
                          style: AppTypography.body14.copyWith(color: Colors.white.withOpacity(0.9)),
                        ),
                        const SizedBox(height: AppDimensions.lg),
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.95),
                            borderRadius: BorderRadius.circular(AppDimensions.radiusXl),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.1),
                                blurRadius: 20,
                                offset: const Offset(0, 10),
                              ),
                            ],
                          ),
                          padding: const EdgeInsets.all(AppDimensions.lg),
                          child: Form(
                            key: _formKey,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                _buildTextField(
                                  controller: _nameController,
                                  label: loc.getText('fullName'),
                                  icon: Icons.person_outlined,
                                  textInputAction: TextInputAction.next,
                                  validator: (value) {
                                    if (value == null || value.trim().isEmpty) return loc.getText('nameRequired');
                                    if (value.trim().length < 2) return loc.getText('nameMinLength');
                                    return null;
                                  },
                                ),
                                const SizedBox(height: AppDimensions.md),
                                _buildTextField(
                                  controller: _emailController,
                                  label: loc.getText('email'),
                                  icon: Icons.email_outlined,
                                  keyboardType: TextInputType.emailAddress,
                                  textInputAction: TextInputAction.next,
                                  validator: (value) {
                                    if (value == null || value.trim().isEmpty) return loc.getText('emailRequired');
                                    if (!value.contains('@') || !value.contains('.')) return loc.getText('emailInvalid');
                                    return null;
                                  },
                                ),
                                const SizedBox(height: AppDimensions.md),
                                _buildTextField(
                                  controller: _phoneController,
                                  label: loc.getText('phone'),
                                  icon: Icons.phone_outlined,
                                  keyboardType: TextInputType.phone,
                                  textInputAction: TextInputAction.next,
                                  validator: (value) {
                                    if (value == null || value.trim().isEmpty) return loc.getText('phoneRequired');
                                    if (value.trim().length < 8) return loc.getText('phoneInvalid');
                                    return null;
                                  },
                                ),
                                const SizedBox(height: AppDimensions.md),
                                DropdownButtonFormField<String>(
                                  value: _vehicleType,
                                  decoration: InputDecoration(
                                    labelText: loc.getText('vehicleType'),
                                    prefixIcon: const Icon(Icons.directions_car_outlined),
                                    filled: true,
                                    fillColor: CustomerAppColors.surfaceContainerLow,
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(AppDimensions.radiusFull),
                                      borderSide: BorderSide.none,
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(AppDimensions.radiusFull),
                                      borderSide: BorderSide.none,
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(AppDimensions.radiusFull),
                                      borderSide: const BorderSide(color: CustomerAppColors.primary, width: 2),
                                    ),
                                    contentPadding: const EdgeInsets.symmetric(horizontal: AppDimensions.md, vertical: AppDimensions.md),
                                  ),
                                  items: [
                                    DropdownMenuItem(value: 'motorcycle', child: Text(loc.getText('motorcycle'))),
                                    DropdownMenuItem(value: 'car', child: Text(loc.getText('car'))),
                                    DropdownMenuItem(value: 'bicycle', child: Text(loc.getText('bicycle'))),
                                  ],
                                  onChanged: (value) {
                                    if (value != null) setState(() => _vehicleType = value);
                                  },
                                ),
                                const SizedBox(height: AppDimensions.lg),

                                // Location Selection
                                Container(
                                  padding: const EdgeInsets.all(AppDimensions.md),
                                  decoration: BoxDecoration(
                                    color: CustomerAppColors.surfaceAlt,
                                    borderRadius: BorderRadius.circular(AppDimensions.radiusXl),
                                    border: Border.all(color: CustomerAppColors.border),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          const Icon(Icons.location_on_outlined, color: CustomerAppColors.primary),
                                          const SizedBox(width: AppDimensions.sm),
                                          Text(
                                            'Location',
                                            style: AppTypography.h2_18.copyWith(
                                              fontWeight: FontWeight.w600,
                                              color: CustomerAppColors.onSurface,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: AppDimensions.md),
                                      LocationSelector(
                                        onLocationNamesSelected: _onLocationSelected,
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: AppDimensions.lg),
                                _buildTextField(
                                  controller: _passwordController,
                                  label: loc.getText('password'),
                                  icon: Icons.lock_outlined,
                                  obscureText: _obscurePassword,
                                  textInputAction: TextInputAction.next,
                                  suffixIcon: IconButton(
                                    icon: Icon(_obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                                    onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                                  ),
                                  validator: (value) {
                                    if (value == null || value.isEmpty) return loc.getText('passwordRequired');
                                    if (value.length < 8) return loc.getText('passwordMinLength');
                                    return null;
                                  },
                                ),
                                const SizedBox(height: AppDimensions.md),
                                _buildTextField(
                                  controller: _confirmPasswordController,
                                  label: loc.getText('confirmPassword'),
                                  icon: Icons.lock_outlined,
                                  obscureText: _obscureConfirm,
                                  textInputAction: TextInputAction.done,
                                  onFieldSubmitted: (_) => _onRegister(),
                                  suffixIcon: IconButton(
                                    icon: Icon(_obscureConfirm ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                                    onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
                                  ),
                                  validator: (value) {
                                    if (value == null || value.isEmpty) return loc.getText('confirmPasswordRequired');
                                    if (value != _passwordController.text) return loc.getText('passwordsDoNotMatch');
                                    return null;
                                  },
                                ),
                                const SizedBox(height: AppDimensions.lg),
                                BlocBuilder<AuthBloc, AuthState>(
                                  builder: (context, state) {
                                    final isLoading = state is AuthLoading;
                                    return SizedBox(
                                      height: 52,
                                      child: ElevatedButton(
                                        onPressed: isLoading ? null : _onRegister,
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: CustomerAppColors.primary,
                                          foregroundColor: Colors.white,
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(AppDimensions.radiusFull),
                                          ),
                                          elevation: 0,
                                        ),
                                        child: isLoading
                                            ? const SizedBox(
                                                height: 20, width: 20,
                                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                              )
                                            : Text(loc.getText('register'), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                                      ),
                                    );
                                  },
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: AppDimensions.lg),
                        TextButton(
                          onPressed: () => context.go('/login'),
                          child: Text(
                            loc.getText('alreadyHaveAccount'),
                            style: AppTypography.body14.copyWith(color: Colors.white, fontWeight: FontWeight.w500),
                          ),
                        ),
                        const SizedBox(height: AppDimensions.xl),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
    TextInputAction? textInputAction,
    bool obscureText = false,
    Widget? suffixIcon,
    String? Function(String?)? validator,
    ValueChanged<String?>? onFieldSubmitted,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      obscureText: obscureText,
      onFieldSubmitted: onFieldSubmitted,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: CustomerAppColors.surfaceContainerLow,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppDimensions.radiusFull),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppDimensions.radiusFull),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppDimensions.radiusFull),
          borderSide: const BorderSide(color: CustomerAppColors.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppDimensions.radiusFull),
          borderSide: const BorderSide(color: CustomerAppColors.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppDimensions.radiusFull),
          borderSide: const BorderSide(color: CustomerAppColors.error, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: AppDimensions.md, vertical: AppDimensions.md),
      ),
      validator: validator,
    );
  }
}
