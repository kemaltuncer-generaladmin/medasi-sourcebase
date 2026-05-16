import 'package:flutter/material.dart';
import 'package:responsive_builder/responsive_builder.dart';

import '../core/theme/app_theme.dart';
import '../features/auth/data/sourcebase_auth_backend.dart';
import '../features/auth/presentation/screens/auth_callback_screen.dart';
import '../features/auth/presentation/screens/forgot_password_screen.dart';
import '../features/auth/presentation/screens/login_screen.dart';
import '../features/auth/presentation/screens/profile_setup_screen.dart';
import '../features/auth/presentation/screens/register_screen.dart';
import '../features/auth/presentation/screens/verify_email_screen.dart';
import '../features/drive/presentation/screens/drive_workspace_screen.dart';

class SourceBaseApp extends StatelessWidget {
  const SourceBaseApp({super.key});

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

  String get _initialRoute {
    if (!SourceBaseAuthBackend.isConfigured) {
      return LoginScreen.route;
    }
    if (SourceBaseAuthBackend.currentUser == null) {
      return LoginScreen.route;
    }
    if (SourceBaseAuthBackend.currentUserNeedsSourceBaseProfile) {
      return ProfileSetupScreen.route;
    }
    return DriveWorkspaceScreen.route;
  }
}
