import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:yallashop_core/yallashop_core.dart';

import 'src/config/router.dart';
import 'src/core/bloc/auth_bloc.dart';
import 'src/core/bloc/auth_state.dart';
import 'src/core/bloc/cart_bloc.dart';
import 'src/core/cubit/currency_cubit.dart';
import 'src/core/cubit/notifications_cubit.dart';
import 'src/config/api_config.dart';
import 'src/services/fcm_service.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
    await FcmService.init();
  } catch (e) {
    debugPrint('Firebase init failed (expected in dev without config): $e');
  }
  runApp(const YallaShopCustomerApp());
}

class YallaShopCustomerApp extends StatefulWidget {
  const YallaShopCustomerApp({super.key});

  @override
  State<YallaShopCustomerApp> createState() => _YallaShopCustomerAppState();
}

class _YallaShopCustomerAppState extends State<YallaShopCustomerApp> {
  Locale _locale = const Locale('ar');

  late final ApiClient _apiClient;
  late final AuthBloc _authBloc;
  late final CartBloc _cartBloc;
  late final CurrencyCubit _currencyCubit;
  late final NotificationsCubit _notificationsCubit;

  @override
  void initState() {
    super.initState();
    _apiClient = ApiClient(baseUrl: CustomerApiConfig.baseUrl);
    _authBloc = AuthBloc(apiClient: _apiClient);
    _cartBloc = CartBloc(apiClient: _apiClient);
    _currencyCubit = CurrencyCubit(apiClient: _apiClient)..loadCurrencies();
    _notificationsCubit = NotificationsCubit(apiClient: _apiClient, authBloc: _authBloc);
    FcmService.onForegroundMessage = _notificationsCubit.refresh;
    _authBloc.stream.listen(_handleAuthState);
  }

  void _handleAuthState(AuthState state) {
    // Register the device push token whenever the user signs in (or is
    // restored from a stored session); stop reporting it on logout.
    if (state is Authenticated) {
      FcmService.registerCurrentToken();
    } else if (state is Unauthenticated) {
      FcmService.unregisterCurrentToken();
    }
  }

  @override
  void dispose() {
    _authBloc.close();
    _cartBloc.close();
    _currencyCubit.close();
    _notificationsCubit.close();
    super.dispose();
  }

  void _setLocale(Locale locale) {
    setState(() => _locale = locale);
  }

  @override
  Widget build(BuildContext context) {
    return LocaleProvider(
      locale: _locale,
      onLocaleChanged: _setLocale,
      child: MultiBlocProvider(
        providers: [
          BlocProvider<AuthBloc>.value(value: _authBloc),
          BlocProvider<CartBloc>.value(value: _cartBloc),
          BlocProvider<CurrencyCubit>.value(value: _currencyCubit),
          BlocProvider<NotificationsCubit>.value(value: _notificationsCubit),
        ],
        child: MaterialApp.router(
          title: 'YallaShop',
          locale: _locale,
          debugShowCheckedModeBanner: false,
          supportedLocales: AppLocalization.supportedLocales,
          localizationsDelegates: [
            ...AppLocalization.localizationsDelegates,
            GlobalMaterialLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
          ],
          localeResolutionCallback: (locale, supportedLocales) {
            for (final supported in supportedLocales) {
              if (supported.languageCode == locale?.languageCode) {
                return supported;
              }
            }
            return const Locale('ar');
          },
          builder: (context, child) => Directionality(
            textDirection: AppLocalization.isRtl(_locale.languageCode)
                ? TextDirection.rtl
                : TextDirection.ltr,
            child: child!,
          ),
          theme: ThemeData(
            primaryColor: CustomerAppColors.primary,
            colorScheme: ColorScheme.fromSeed(
              seedColor: CustomerAppColors.primary,
              primary: CustomerAppColors.primary,
              secondary: CustomerAppColors.accentGold,
              error: CustomerAppColors.error,
              surface: CustomerAppColors.background,
            ),
            scaffoldBackgroundColor: CustomerAppColors.background,
            fontFamily: 'Tajawal',
            textTheme: const TextTheme(
              displayLarge: AppTypography.display28,
              headlineLarge: AppTypography.h1_22,
              headlineMedium: AppTypography.h2_18,
              bodyMedium: AppTypography.body14,
              bodySmall: AppTypography.caption12,
            ),
            appBarTheme: const AppBarTheme(
              backgroundColor: CustomerAppColors.background,
              foregroundColor: CustomerAppColors.secondary,
              elevation: 0,
              centerTitle: true,
            ),
            elevatedButtonTheme: ElevatedButtonThemeData(
              style: ElevatedButton.styleFrom(
                backgroundColor: CustomerAppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                ),
                padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
              ),
            ),
            inputDecorationTheme: InputDecorationTheme(
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                borderSide: const BorderSide(color: CustomerAppColors.border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                borderSide: const BorderSide(color: CustomerAppColors.primary),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            ),
          ),
          routerConfig: appRouter,
        ),
      ),
    );
  }
}
