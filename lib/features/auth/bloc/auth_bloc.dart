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

// Added Registration Event
class RegisterRequested extends AuthEvent {
  final String name;
  final String email;
  final String password;
  final String location;

  RegisterRequested({
    required this.name,
    required this.email,
    required this.password,
    required this.location,
  });

  @override
  List<Object?> get props => [name, email, password, location];
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
    on<RegisterRequested>(_onRegisterRequested);
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
      // Set token on Dio header so subsequent calls work
      apiClient.dio.options.headers['Authorization'] = 'Bearer $token';

      final response = await apiClient.dio.get('/auth/me');
      if (response.statusCode == 200) {
        final email = response.data['email']?.toString() ?? 'user@aura.com';
        emit(Authenticated(email));
      } else {
        await _storage.delete(key: 'jwt_token');
        emit(Unauthenticated());
      }
    } catch (e) {
      // If token verification fails, clear storage and show login
      await _storage.delete(key: 'jwt_token');
      emit(Unauthenticated());
    }
  }

  Future<void> _onLoginRequested(LoginRequested event, Emitter<AuthState> emit) async {
    emit(AuthLoading());
    try {
      // Use FormData because FastAPI backend expects OAuth2PasswordRequestForm
      final formData = FormData.fromMap({
        'username': event.email, // FastAPI OAuth2 form expects 'username'
        'password': event.password,
      });

      final response = await apiClient.dio.post(
        '/auth/login',
        data: formData,
        options: Options(
          contentType: Headers.formUrlEncodedContentType,
        ),
      );

      final token = response.data['access_token'] ?? response.data['token'];
      if (token != null) {
        await _storage.write(key: 'jwt_token', value: token);
        apiClient.dio.options.headers['Authorization'] = 'Bearer $token';

        emit(Authenticated(event.email));
      } else {
        emit(AuthError('Token not found in login response'));
      }
    } catch (e) {
      emit(AuthError('Invalid email or password. Please try again.'));
    }
  }
  // Added Registration Handler communicating with FastAPI backend
  Future<void> _onRegisterRequested(RegisterRequested event, Emitter<AuthState> emit) async {
    emit(AuthLoading());
    try {
      // 1. Call registration endpoint
      await apiClient.dio.post(
        '/auth/register',
        data: {
          'name': event.name,
          'email': event.email,
          'password': event.password,
        },
      );

      // 2. Automatically log them in right after successful registration
      final loginResponse = await apiClient.dio.post(
        '/auth/login',
        data: {
          'username': event.email,
          'password': event.password,
        },
        options: Options(contentType: Headers.formUrlEncodedContentType),
      );

      final token = loginResponse.data['access_token'] as String;

      // 3. CRITICAL: Save token AND attach it to Dio headers immediately
      await _storage.write(key: 'jwt_token', value: token);
      apiClient.dio.options.headers['Authorization'] = 'Bearer $token';

      emit(Authenticated(event.email));
    } catch (e) {
      emit(AuthError("Registration failed. Email might already be in use."));
    }
  }

  Future<void> _onLogoutRequested(LogoutRequested event, Emitter<AuthState> emit) async {
    await _storage.delete(key: 'jwt_token');
    emit(Unauthenticated());
  }
}