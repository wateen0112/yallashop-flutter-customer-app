import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:yallashop_core/yallashop_core.dart';

import '../../core/bloc/auth_bloc.dart';
import '../../core/bloc/auth_event.dart';
import '../../core/bloc/auth_state.dart';
import '../../widgets/location_selector.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _obscurePassword = true;
  bool _obscureConfirm = true;

  // Location fields
  String? _governorate;
  String? _city;
  String? _area;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _onLocationSelected(String gov, String city, String area) {
    setState(() {
      _governorate = gov;
      _city = city;
      _area = area;
    });
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
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: AppDimensions.lg),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: AppDimensions.xxl * 1.5),
                  const Icon(
                    Icons.shopping_bag_outlined,
                    size: 72,
                    color: CustomerAppColors.primary,
                  ),
                  const SizedBox(height: AppDimensions.md),
                  Text(
                    loc.getText('appName'),
                    textAlign: TextAlign.center,
                    style: AppTypography.display28.copyWith(
                      color: CustomerAppColors.primary,
                    ),
                  ),
                  const SizedBox(height: AppDimensions.xs),
                  Text(
                    loc.getText('createAccount'),
                    textAlign: TextAlign.center,
                    style: AppTypography.h1_22.copyWith(
                      color: CustomerAppColors.secondary,
                    ),
                  ),
                  const SizedBox(height: AppDimensions.xxl),
                  TextFormField(
                    controller: _nameController,
                    textInputAction: TextInputAction.next,
                    decoration: InputDecoration(
                      labelText: loc.getText('name'),
                      prefixIcon: const Icon(Icons.person_outlined),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return loc.getText('name');
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: AppDimensions.md),
                  TextFormField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    decoration: InputDecoration(
                      labelText: loc.getText('email'),
                      prefixIcon: const Icon(Icons.email_outlined),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return loc.getText('email');
                      }
                      if (!value.contains('@')) {
                        return loc.getText('email');
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: AppDimensions.md),
                  TextFormField(
                    controller: _phoneController,
                    keyboardType: TextInputType.phone,
                    textInputAction: TextInputAction.next,
                    decoration: InputDecoration(
                      labelText: loc.getText('phone'),
                      prefixIcon: const Icon(Icons.phone_outlined),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return loc.getText('phone');
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: AppDimensions.md),
                  TextFormField(
                    controller: _passwordController,
                    obscureText: _obscurePassword,
                    textInputAction: TextInputAction.next,
                    decoration: InputDecoration(
                      labelText: loc.getText('password'),
                      prefixIcon: const Icon(Icons.lock_outlined),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                        ),
                        onPressed: () {
                          setState(() => _obscurePassword = !_obscurePassword);
                        },
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return loc.getText('password');
                      }
                      if (value.length < 8) {
                        return loc.getText('password');
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: AppDimensions.md),
                  TextFormField(
                    controller: _confirmPasswordController,
                    obscureText: _obscureConfirm,
                    textInputAction: TextInputAction.next,
                    decoration: InputDecoration(
                      labelText: loc.getText('confirmPassword'),
                      prefixIcon: const Icon(Icons.lock_outlined),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscureConfirm
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                        ),
                        onPressed: () {
                          setState(() => _obscureConfirm = !_obscureConfirm);
                        },
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return loc.getText('confirmPassword');
                      }
                      if (value != _passwordController.text) {
                        return loc.getText('passwordsDoNotMatch');
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: AppDimensions.lg),

                  // Location Selection
                  Container(
                    padding: const EdgeInsets.all(AppDimensions.md),
                    decoration: BoxDecoration(
                      color: CustomerAppColors.surfaceAlt,
                      borderRadius:
                          BorderRadius.circular(AppDimensions.radiusXl),
                      border: Border.all(color: CustomerAppColors.border),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(
                              Icons.location_on_outlined,
                              color: CustomerAppColors.primary,
                            ),
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
                  BlocBuilder<AuthBloc, AuthState>(
                    builder: (context, state) {
                      final isLoading = state is AuthLoading;
                      return ElevatedButton(
                        onPressed: isLoading ? null : _onRegister,
                        child: isLoading
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : Text(
                                loc.getText('register'),
                                style: const TextStyle(fontSize: 16),
                              ),
                      );
                    },
                  ),
                  const SizedBox(height: AppDimensions.md),
                  TextButton(
                    onPressed: () => context.go('/login'),
                    child: Text(
                      loc.getText('alreadyHaveAccount'),
                      style: AppTypography.body14.copyWith(
                        color: CustomerAppColors.primary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
