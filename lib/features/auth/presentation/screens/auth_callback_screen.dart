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
  String? _statusMessage;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _completeCallback());
  }

  Future<void> _completeCallback() async {
    if (!mounted) {
      return;
    }
    setState(() => _statusMessage = 'Oturum doğrulanıyor...');

    try {
      if (!SourceBaseAuthBackend.isConfigured ||
          SourceBaseAuthBackend.initializationError != null) {
        throw SourceBaseAuthBackend.initializationError ?? Object();
      }

      await SourceBaseAuthBackend.completeCallback(Uri.base);
      if (!mounted) {
        return;
      }
      Navigator.pushNamedAndRemoveUntil(context, _route, (_) => false);
    } catch (error) {
      if (!mounted) {
        return;
      }
      Navigator.pushNamedAndRemoveUntil(
        context,
        LoginScreen.route,
        (_) => false,
        arguments: SourceBaseAuthBackend.friendlyError(error),
      );
    }
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
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(),
                const SizedBox(height: 18),
                Text(
                  _statusMessage ?? 'Oturum hazırlanıyor...',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
