import 'package:flutter/material.dart';

import '../../../drive/presentation/screens/drive_workspace_screen.dart';
import '../../data/sourcebase_auth_backend.dart';
import 'login_screen.dart';
import 'profile_setup_screen.dart';

class AuthCallbackScreen extends StatefulWidget {
  const AuthCallbackScreen({super.key});

  static const route = '/auth/callback';

  @override
  State<AuthCallbackScreen> createState() => _AuthCallbackScreenState();
}

class _AuthCallbackScreenState extends State<AuthCallbackScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      Navigator.pushNamedAndRemoveUntil(context, _route, (_) => false);
    });
  }

  String get _route {
    if (SourceBaseAuthBackend.currentUser == null) {
      return LoginScreen.route;
    }
    if (SourceBaseAuthBackend.currentUserNeedsSourceBaseProfile) {
      return ProfileSetupScreen.route;
    }
    return DriveWorkspaceScreen.route;
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}
