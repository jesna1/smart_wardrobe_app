import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../../core/api/api_client.dart';

// --- Events ---
abstract class AuthEvent extends Equatable {
  @override
  List<Object?> get props => [];
}

class AppStarted extends AuthEvent {}

class LoginRequested extends AuthEvent {
  final String email;
  final String password;
  LoginRequested(this.email, this.password);

  @override
  List<Object?> get props => [email, password];
}

class LogoutRequested extends AuthEvent {}

// --- States ---
abstract class AuthState extends Equatable {
  @override
  List<Object?> get props => [];
}

class AuthInitial extends AuthState {}
class AuthLoading extends AuthState {}
class Authenticated extends AuthState {
  final String email;
  Authenticated(this.email);

  @override
  List<Object?> get props => [email];
}
class Unauthenticated extends AuthState {}
class AuthError extends AuthState {
  final String message;
  AuthError(this.message);

  @override
  List<Object?> get props => [message];
}

// --- BLoC ---
class AuthBloc extends Bloc<AuthEvent, AuthState> {
  final ApiClient apiClient;
  final _storage = const FlutterSecureStorage();

  AuthBloc(this.apiClient) : super(AuthInitial()) {
    on<AppStarted>(_onAppStarted);
    on<LoginRequested>(_onLoginRequested);
    on<LogoutRequested>(_onLogoutRequested);
  }

  Future<void> _onAppStarted(AppStarted event, Emitter<AuthState> emit) async {
    emit(AuthLoading());
    final token = await _storage.read(key: 'jwt_token');

    if (token == null) {
      emit(Unauthenticated());
      return;
    }

    try {
      // Validate existing JWT with the backend profile endpoint
      final response = await apiClient.dio.get('/auth/me');
      final email = response.data['email'] as String;
      emit(Authenticated(email));
    } on DioException catch (e) {
      // If token is expired (401) or server unreachable, clear storage
      await _storage.delete(key: 'jwt_token');
      emit(Unauthenticated());
    } catch (_) {
      await _storage.delete(key: 'jwt_token');
      emit(Unauthenticated());
    }
  }

  Future<void> _onLoginRequested(LoginRequested event, Emitter<AuthState> emit) async {
    emit(AuthLoading());
    try {
      final response = await apiClient.dio.post(
        '/auth/login',
        data: {
          'username': event.email,
          'password': event.password,
        },
        options: Options(contentType: Headers.formUrlEncodedContentType),
      );

      final token = response.data['access_token'] as String;
      await _storage.write(key: 'jwt_token', value: token);
      emit(Authenticated(event.email));
    } catch (e) {
      emit(AuthError("Invalid credentials or server unavailable."));
    }
  }

  Future<void> _onLogoutRequested(LogoutRequested event, Emitter<AuthState> emit) async {
    await _storage.delete(key: 'jwt_token');
    emit(Unauthenticated());
  }
}