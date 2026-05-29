import 'package:flutter/material.dart';
import 'package:responsive_builder/responsive_builder.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_theme.dart';
import '../features/auth/data/sourcebase_auth_backend.dart';
import '../features/auth/presentation/screens/auth_callback_screen.dart';
import '../features/auth/presentation/screens/forgot_password_screen.dart';
import '../features/auth/presentation/screens/login_screen.dart';
import '../features/auth/presentation/screens/profile_setup_screen.dart';
import '../features/auth/presentation/screens/register_screen.dart';
import '../features/auth/presentation/screens/verify_email_screen.dart';
import '../features/drive/presentation/screens/drive_workspace_screen.dart';

class SourceBaseApp extends StatefulWidget {
  const SourceBaseApp({super.key});

  @override
  State<SourceBaseApp> createState() => _SourceBaseAppState();
}

class _SourceBaseAppState extends State<SourceBaseApp> {
  @override
  void initState() {
    super.initState();
    _listenAuthChanges();
  }

  void _listenAuthChanges() {
    final client = SourceBaseAuthBackend.client;
    if (client == null) return;
    client.auth.onAuthStateChange.listen((event) {
      final isSignedOut = event.event == AuthChangeEvent.signedOut;
      final tokenExpired =
          event.event == AuthChangeEvent.tokenRefreshed &&
          event.session == null;
      if ((isSignedOut || tokenExpired) && mounted) {
        _rootNavigatorKey.currentState?.pushNamedAndRemoveUntil(
          LoginScreen.route,
          (_) => false,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return ResponsiveApp(
      builder: (context) => MaterialApp(
        title: 'SourceBase',
        debugShowCheckedModeBanner: false,
        theme: SourceBaseTheme.light(),
        builder: (context, child) {
          return Semantics(
            container: true,
            explicitChildNodes: true,
            label: 'SourceBase uygulaması',
            child: child ?? const SizedBox.shrink(),
          );
        },
        navigatorKey: _rootNavigatorKey,
        initialRoute: _initialRoute,
        routes: {
          LoginScreen.route: (_) => const LoginScreen(),
          RegisterScreen.route: (_) => const RegisterScreen(),
          ForgotPasswordScreen.route: (_) => const ForgotPasswordScreen(),
          VerifyEmailScreen.route: (_) => const VerifyEmailScreen(),
          ProfileSetupScreen.route: (_) => const ProfileSetupScreen(),
          AuthCallbackScreen.route: (_) => const AuthCallbackScreen(),
          DriveWorkspaceScreen.route: (_) =>
              const _AuthProtectedRoute(child: DriveWorkspaceScreen()),
        },
      ),
    );
  }

  static final _rootNavigatorKey = GlobalKey<NavigatorState>();

  String get _initialRoute {
    if (!SourceBaseAuthBackend.isConfigured) {
      return LoginScreen.route;
    }
    if (SourceBaseAuthBackend.currentUser == null) {
      return LoginScreen.route;
    }
    if (!SourceBaseAuthBackend.currentUserHasVerifiedEmail) {
      return VerifyEmailScreen.route;
    }
    if (SourceBaseAuthBackend.currentUserNeedsSourceBaseProfile) {
      return ProfileSetupScreen.route;
    }
    return DriveWorkspaceScreen.route;
  }
}

class _AuthProtectedRoute extends StatelessWidget {
  const _AuthProtectedRoute({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final redirectRoute = _redirectRoute;
    if (redirectRoute == null) {
      return child;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!context.mounted) {
        return;
      }
      Navigator.of(context).pushNamedAndRemoveUntil(
        redirectRoute,
        (_) => false,
        arguments: redirectRoute == LoginScreen.route
            ? const {'error': 'Oturum doğrulanamadı. Lütfen tekrar giriş yap.'}
            : null,
      );
    });

    return const _SourceBaseBootScreen();
  }

  String? get _redirectRoute {
    if (!SourceBaseAuthBackend.isConfigured ||
        SourceBaseAuthBackend.currentUser == null) {
      return LoginScreen.route;
    }
    if (!SourceBaseAuthBackend.currentUserHasVerifiedEmail) {
      return VerifyEmailScreen.route;
    }
    if (SourceBaseAuthBackend.currentUserNeedsSourceBaseProfile) {
      return ProfileSetupScreen.route;
    }
    return null;
  }
}

class _SourceBaseBootScreen extends StatelessWidget {
  const _SourceBaseBootScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.page,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: AppColors.selectedBlue,
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(
                      color: AppColors.blue.withValues(alpha: .18),
                    ),
                  ),
                  child: const Icon(
                    Icons.auto_stories_rounded,
                    color: AppColors.blue,
                    size: 36,
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'SourceBase',
                  style: TextStyle(
                    color: AppColors.navy,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Hesabın hazırlanıyor',
                  style: TextStyle(
                    color: AppColors.muted,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 22),
                const SizedBox(
                  width: 28,
                  height: 28,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: AppColors.blue,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
