import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:yallashop_core/yallashop_core.dart';
import 'auth_event.dart';
import 'auth_state.dart';

class AuthBloc extends Bloc<AuthEvent, AuthState> {
  final ApiClient _apiClient;
  final FlutterSecureStorage _storage;

  AuthBloc({required ApiClient apiClient, FlutterSecureStorage? storage})
      : _apiClient = apiClient,
        _storage = storage ?? const FlutterSecureStorage(),
        super(const AuthInitial()) {
    on<LoginRequested>(_onLoginRequested);
    on<RegisterRequested>(_onRegisterRequested);
    on<OtpRequested>(_onOtpRequested);
    on<OtpVerified>(_onOtpVerified);
    on<LogoutRequested>(_onLogoutRequested);
    on<ProfileUpdated>(_onProfileUpdated);
    _checkAuth();
  }

  Future<void> _checkAuth() async {
    final token = await _storage.read(key: 'auth_token');
    if (token != null) {
      final result = await _apiClient.get<Map<String, dynamic>>('/auth/me');
      if (result is Success<Map<String, dynamic>>) {
        final user = User.fromJson(result.data);
        emit(Authenticated(user: user));
        return;
      }
    }
    emit(const Unauthenticated());
  }

  Future<void> _onLoginRequested(
    LoginRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(const AuthLoading());
    try {
      final result = await _apiClient.post<Map<String, dynamic>>(
        '/auth/login',
        data: {'email': event.email, 'password': event.password},
      );
      if (result is Success<Map<String, dynamic>>) {
        final data = result.data;
        final userMap = data['user'] as Map<String, dynamic>?;
        final token = data['token'] as String?;
        if (userMap == null || token == null) {
          emit(const AuthError(message: 'Invalid response from server'));
          return;
        }
        final user = User.fromJson(userMap);
        await _storage.write(key: 'auth_token', value: token);
        emit(Authenticated(user: user));
      } else {
        final err = result as Failure;
        emit(AuthError(message: err.exception.message));
      }
    } on ApiException catch (e) {
      emit(AuthError(message: e.message));
    } catch (e) {
      emit(AuthError(message: e.toString()));
    }
  }

  Future<void> _onRegisterRequested(
    RegisterRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(const AuthLoading());
    try {
      final result = await _apiClient.post<Map<String, dynamic>>(
        '/auth/register',
        data: {
          'name': event.name,
          'phone': event.phone,
          'email': event.email,
          'password': event.password,
          'role': event.role ?? 'customer',
          'governorate': event.governorate,
          'city': event.city,
          'area': event.area,
        },
      );
      if (result is Success<Map<String, dynamic>>) {
        final data = result.data;
        final userMap = data['user'] as Map<String, dynamic>?;
        final token = data['token'] as String?;
        if (userMap == null || token == null) {
          emit(const AuthError(message: 'Invalid response from server'));
          return;
        }
        final user = User.fromJson(userMap);
        await _storage.write(key: 'auth_token', value: token);
        emit(Authenticated(user: user));
      } else {
        final err = result as Failure;
        emit(AuthError(message: err.exception.message));
      }
    } on ApiException catch (e) {
      emit(AuthError(message: e.message));
    } catch (e) {
      emit(AuthError(message: e.toString()));
    }
  }

  Future<void> _onOtpRequested(
    OtpRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(const AuthLoading());
    try {
      final result = await _apiClient.post<Map<String, dynamic>>(
        '/auth/otp/request',
        data: {'phone': event.phone},
      );
      if (result is Success) {
        emit(const Unauthenticated());
      } else {
        final err = result as Failure;
        emit(AuthError(message: err.exception.message));
      }
    } on ApiException catch (e) {
      emit(AuthError(message: e.message));
    } catch (e) {
      emit(AuthError(message: e.toString()));
    }
  }

  Future<void> _onOtpVerified(
    OtpVerified event,
    Emitter<AuthState> emit,
  ) async {
    emit(const AuthLoading());
    try {
      final verifyResult = await _apiClient.post<Map<String, dynamic>>(
        '/auth/otp/verify',
        data: {'phone': event.phone, 'otp': event.otp},
      );
      if (verifyResult is Success) {
        final loginResult = await _apiClient.post<Map<String, dynamic>>(
          '/auth/login',
          data: {'phone': event.phone},
        );
        if (loginResult is Success<Map<String, dynamic>>) {
          final data = loginResult.data;
          final userMap = data['user'] as Map<String, dynamic>?;
          final token = data['token'] as String?;
          if (userMap == null || token == null) {
            emit(const AuthError(message: 'Invalid response from server'));
            return;
          }
          final user = User.fromJson(userMap);
          await _storage.write(key: 'auth_token', value: token);
          emit(Authenticated(user: user));
        } else {
          final err = loginResult as Failure;
          emit(AuthError(message: err.exception.message));
        }
      } else {
        final err = verifyResult as Failure;
        emit(AuthError(message: err.exception.message));
      }
    } on ApiException catch (e) {
      emit(AuthError(message: e.message));
    } catch (e) {
      emit(AuthError(message: e.toString()));
    }
  }

  Future<void> _onLogoutRequested(
    LogoutRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(const AuthLoading());
    try {
      await _apiClient.post('/auth/logout');
    } catch (_) {}
    await _storage.delete(key: 'auth_token');
    emit(const Unauthenticated());
  }

  void _onProfileUpdated(
    ProfileUpdated event,
    Emitter<AuthState> emit,
  ) {
    emit(Authenticated(user: event.user));
  }
}
