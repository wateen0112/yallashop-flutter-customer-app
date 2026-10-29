import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:yallashop_core/yallashop_core.dart';

import '../../core/bloc/auth_bloc.dart';
import '../../core/bloc/auth_event.dart';
import '../../core/bloc/auth_state.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _onLogin() {
    if (_formKey.currentState?.validate() ?? false) {
      context.read<AuthBloc>().add(LoginRequested(
            email: _emailController.text.trim(),
            password: _passwordController.text,
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
                      onPressed: () => context.go('/'),
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
                        const SizedBox(height: AppDimensions.md),
                        Container(
                          width: 72,
                          height: 72,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.shopping_bag_outlined,
                            size: 40,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: AppDimensions.xs),
                        Text(
                          loc.getText('appName'),
                          textAlign: TextAlign.center,
                          style: AppTypography.display28.copyWith(color: Colors.white),
                        ),
                        const SizedBox(height: AppDimensions.xs),
                        Text(
                          loc.getText('login'),
                          textAlign: TextAlign.center,
                          style: AppTypography.h1_22.copyWith(color: Colors.white.withOpacity(0.9)),
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
                          padding: const EdgeInsets.all(AppDimensions.md),
                          child: Form(
                            key: _formKey,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                TextFormField(
                                  controller: _emailController,
                                  keyboardType: TextInputType.emailAddress,
                                  textInputAction: TextInputAction.next,
                                  decoration: _inputDecoration(loc.getText('email'), Icons.email_outlined),
                                  validator: (value) {
                                    if (value == null || value.trim().isEmpty) return loc.getText('emailRequired');
                                    if (!value.contains('@') || !value.contains('.')) return loc.getText('emailInvalid');
                                    return null;
                                  },
                                ),
                                const SizedBox(height: AppDimensions.sm),
                                TextFormField(
                                  controller: _passwordController,
                                  obscureText: _obscurePassword,
                                  textInputAction: TextInputAction.done,
                                  onFieldSubmitted: (_) => _onLogin(),
                                  decoration: _inputDecoration(loc.getText('password'), Icons.lock_outlined).copyWith(
                                    suffixIcon: IconButton(
                                      icon: Icon(_obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                                      onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                                    ),
                                  ),
                                  validator: (value) {
                                    if (value == null || value.isEmpty) return loc.getText('passwordRequired');
                                    if (value.length < 6) return loc.getText('passwordMinLength');
                                    return null;
                                  },
                                ),
                                const SizedBox(height: AppDimensions.md),
                                BlocBuilder<AuthBloc, AuthState>(
                                  builder: (context, state) {
                                    final isLoading = state is AuthLoading;
                                    return SizedBox(
                                      height: 52,
                                      child: ElevatedButton(
                                        onPressed: isLoading ? null : _onLogin,
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
                                            : Text(loc.getText('login'), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                                      ),
                                    );
                                  },
                                ),
                                const SizedBox(height: AppDimensions.sm),
                                _buildLink(loc.getText('dontHaveAccount'), () => context.go('/register')),
                                const SizedBox(height: AppDimensions.sm),
                                Wrap(
                                  spacing: 6,
                                  runSpacing: 6,
                                  alignment: WrapAlignment.center,
                                  children: [
                                    _buildGridLink(loc.getText('registerAsCourier'), () => context.go('/register/courier')),
                                    _buildGridLink(loc.getText('registerAsVendor'), () => context.go('/register/vendor')),
                                    _buildGridLink(loc.getText('skip'), () => context.go('/')),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: AppDimensions.lg),
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

  InputDecoration _inputDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon),
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
      contentPadding: const EdgeInsets.symmetric(horizontal: AppDimensions.md, vertical: AppDimensions.sm),
    );
  }

  Widget _buildLink(String text, VoidCallback onTap, [bool isSecondary = false]) {
    return TextButton(
      onPressed: onTap,
      child: Text(
        text,
        style: AppTypography.body14.copyWith(
          color: isSecondary ? CustomerAppColors.secondary : CustomerAppColors.primary,
          fontWeight: isSecondary ? FontWeight.w400 : FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildGridLink(String text, VoidCallback onTap) {
    return OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        foregroundColor: CustomerAppColors.primary,
        side: const BorderSide(color: CustomerAppColors.primary, width: 1),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 0),
        minimumSize: const Size(0, 36),
        visualDensity: VisualDensity.compact,
      ),
      child: Text(
        text,
        style: AppTypography.body12.copyWith(
          color: CustomerAppColors.primary,
          fontWeight: FontWeight.w500,
        ),
        textAlign: TextAlign.center,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}
