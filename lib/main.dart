import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'core/api/api_client.dart';
import 'features/auth/bloc/auth_bloc.dart';
import 'features/auth/screen/login_screen.dart';
import 'features/stylist/bloc/stylist_bloc.dart';
import 'features/wardrobe/bloc/wardrobe_bloc.dart';
import 'features/navigation/presentation/main_navigation_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // Instantiate ApiClient once before starting the widget tree
  final apiClient = ApiClient();

  runApp(SmartWardrobeApp(apiClient: apiClient));
}

class SmartWardrobeApp extends StatelessWidget {
  final ApiClient apiClient;

  const SmartWardrobeApp({super.key, required this.apiClient});

  @override
  Widget build(BuildContext context) {
    return RepositoryProvider<ApiClient>.value(
      value: apiClient,
      child: MultiBlocProvider(
        providers: [
          BlocProvider<AuthBloc>(
            create: (context) {
              final bloc = AuthBloc(apiClient);
              apiClient.onUnauthorized = () {
                bloc.add(LogoutRequested());
              };
              return bloc..add(AppStarted());
            },
          ),
          BlocProvider<WardrobeBloc>(
            create: (context) => WardrobeBloc(apiClient),
          ),
          BlocProvider<StylistBloc>(
            create: (context) => StylistBloc(apiClient), // Triggered by Gateway listener after Auth
          ),
        ],
        child: MaterialApp(
          title: 'Aura Wardrobe',
          debugShowCheckedModeBanner: false,
          theme: ThemeData(
            useMaterial3: true,
            scaffoldBackgroundColor: const Color(0xFFF8F9FA),
            colorScheme: ColorScheme.fromSeed(
              seedColor: const Color(0xFF1E293B),
            ),
          ),
          home: const AuthenticationGateway(),
        ),
      ),
    );
  }
}

class AuthenticationGateway extends StatelessWidget {
  const AuthenticationGateway({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<AuthBloc, AuthState>(
      listenWhen: (previous, current) =>
      current is Authenticated && previous is! Authenticated,
      listener: (context, state) {
        if (state is Authenticated) {
          // Trigger feature data loading safely after successful authentication
          context.read<WardrobeBloc>().add(FetchWardrobeItems());
          context.read<StylistBloc>().add(FetchRecommendations());
        }
      },
      builder: (context, state) {
        if (state is Authenticated) {
          return const MainNavigationScreen();
        } else if (state is Unauthenticated || state is AuthError) {
          return const LoginScreen();
        }

        return const Scaffold(
          body: Center(
            child: CircularProgressIndicator(color: Color(0xFF1E293B)),
          ),
        );
      },
    );
  }
}