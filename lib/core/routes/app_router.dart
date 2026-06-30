import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../features/auth/bloc/auth_bloc.dart';
import '../../features/auth/presentation/onboarding_screen.dart';
import '../../features/auth/presentation/setup_password_screen.dart';
import '../../features/auth/presentation/login_screen.dart';
import '../../features/vault/presentation/home_dashboard.dart';
import '../../features/vault/presentation/add_edit_password_screen.dart';
import '../../features/vault/data/vault_repository.dart';
import '../../features/settings/presentation/settings_screen.dart';
import '../../features/premium/presentation/paywall_screen.dart';

/// Helper to convert a Stream into a Listenable for GoRouter's refreshListenable
class GoRouterRefreshStream extends ChangeNotifier {
  GoRouterRefreshStream(Stream<dynamic> stream) {
    notifyListeners();
    _subscription = stream.asBroadcastStream().listen((_) => notifyListeners());
  }

  late final StreamSubscription<dynamic> _subscription;

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}

class AppRouter {
  final AuthBloc authBloc;

  AppRouter(this.authBloc);

  late final GoRouter router = GoRouter(
    initialLocation: '/',
    refreshListenable: GoRouterRefreshStream(authBloc.stream),
    redirect: (BuildContext context, GoRouterState state) {
      final authState = authBloc.state;
      
      final bool isGoingToOnboarding = state.matchedLocation == '/onboarding';
      final bool isGoingToSetup = state.matchedLocation == '/setup-password';
      final bool isGoingToLogin = state.matchedLocation == '/login';

      if (authState is AuthInitial || authState is AuthLoading) {
        // App is still checking status, show a splash or stay put (handled by root route)
        if (state.matchedLocation == '/') return null;
        return '/';
      }

      if (authState is AuthNeedsSetup) {
        if (!isGoingToOnboarding && !isGoingToSetup) {
          return '/onboarding';
        }
      } else if (authState is AuthLocked || authState is AuthError) {
        // AuthError implies they are trying to log in but failed, keep them on login
        if (!isGoingToLogin) {
          return '/login';
        }
      } else if (authState is AuthUnlocked) {
        if (isGoingToLogin || isGoingToOnboarding || isGoingToSetup || state.matchedLocation == '/') {
          return '/home';
        }
      }

      return null;
    },
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => const Scaffold(
          body: Center(child: CircularProgressIndicator(color: Colors.teal)),
        ),
      ),
      GoRoute(
        path: '/onboarding',
        builder: (context, state) => const OnboardingScreen(),
      ),
      GoRoute(
        path: '/setup-password',
        builder: (context, state) => const SetupPasswordScreen(),
      ),
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/home',
        builder: (context, state) => const HomeDashboard(),
      ),
      GoRoute(
        path: '/add-password',
        builder: (context, state) => const AddEditPasswordScreen(),
      ),
      GoRoute(
        path: '/edit-password',
        builder: (context, state) {
          final entry = state.extra as PasswordEntry;
          return AddEditPasswordScreen(existingEntry: entry);
        },
      ),
      GoRoute(
        path: '/settings',
        builder: (context, state) => const SettingsScreen(),
      ),
      GoRoute(
        path: '/paywall',
        builder: (context, state) => const PaywallScreen(),
      ),
    ],
  );
}
