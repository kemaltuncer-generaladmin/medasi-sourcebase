import 'package:flutter/material.dart';
import 'package:responsive_builder/responsive_builder.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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
      final tokenExpired = event.event == AuthChangeEvent.tokenRefreshed &&
          event.session == null;
      if ((isSignedOut || tokenExpired) && mounted) {
        Navigator.of(context).pushNamedAndRemoveUntil(
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
                DriveWorkspaceScreen.route: (_) => const DriveWorkspaceScreen(),
              },
            ));
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
