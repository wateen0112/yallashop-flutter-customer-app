import 'package:equatable/equatable.dart';
import 'package:yallashop_core/yallashop_core.dart';

sealed class AuthEvent extends Equatable {
  const AuthEvent();

  @override
  List<Object?> get props => [];
}

final class LoginRequested extends AuthEvent {
  final String email;
  final String password;

  const LoginRequested({required this.email, required this.password});

  @override
  List<Object?> get props => [email, password];
}

final class RegisterRequested extends AuthEvent {
  final String name;
  final String email;
  final String phone;
  final String password;
  final String? role;
  final String governorate;
  final String city;
  final String area;

  const RegisterRequested({
    required this.name,
    required this.email,
    required this.phone,
    required this.password,
    this.role,
    required this.governorate,
    required this.city,
    required this.area,
  });

  @override
  List<Object?> get props =>
      [name, email, phone, password, role, governorate, city, area];
}

final class OtpRequested extends AuthEvent {
  final String phone;

  const OtpRequested({required this.phone});

  @override
  List<Object?> get props => [phone];
}

final class OtpVerified extends AuthEvent {
  final String phone;
  final String otp;

  const OtpVerified({required this.phone, required this.otp});

  @override
  List<Object?> get props => [phone, otp];
}

final class LogoutRequested extends AuthEvent {
  const LogoutRequested();
}

final class ProfileUpdated extends AuthEvent {
  final User user;

  const ProfileUpdated({required this.user});

  @override
  List<Object?> get props => [user];
}
