import 'package:flutter/material.dart';

import '../../../drive/presentation/screens/drive_workspace_screen.dart';
import '../../data/sourcebase_auth_backend.dart';
import '../widgets/auth_widgets.dart';
import 'login_screen.dart';
import 'profile_setup_screen.dart';

class AuthCallbackScreen extends StatefulWidget {
  const AuthCallbackScreen({super.key});

  static const route = '/auth/callback';

  @override
  State<AuthCallbackScreen> createState() => _AuthCallbackScreenState();
}

class _AuthCallbackScreenState extends State<AuthCallbackScreen> {
  final _passwordController = TextEditingController();
  final _repeatPasswordController = TextEditingController();
  String? _statusMessage;
  String? _errorMessage;
  bool _checking = true;
  bool _passwordRecovery = false;
  bool _saving = false;
  bool _obscurePassword = true;
  bool _obscureRepeatPassword = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _completeCallback());
  }

  @override
  void dispose() {
    _passwordController.dispose();
    _repeatPasswordController.dispose();
    super.dispose();
  }

  Future<void> _completeCallback() async {
    if (!mounted) {
      return;
    }
    setState(() {
      _checking = true;
      _statusMessage = 'Oturum doğrulanıyor...';
      _errorMessage = null;
    });

    try {
      if (!SourceBaseAuthBackend.isConfigured ||
          SourceBaseAuthBackend.initializationError != null) {
        throw SourceBaseAuthBackend.initializationError ?? Object();
      }

      final result = await SourceBaseAuthBackend.completeCallback(Uri.base);
      if (!mounted) {
        return;
      }
      if (result.isPasswordRecovery) {
        setState(() {
          _checking = false;
          _passwordRecovery = true;
          _statusMessage = null;
        });
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

  String? _validatePassword() {
    final password = _passwordController.text;
    final repeatedPassword = _repeatPasswordController.text;
    if (password.length < 8) {
      return 'Şifre en az 8 karakter olmalı.';
    }
    if (!RegExp(r'[A-Za-z]').hasMatch(password) ||
        !RegExp(r'\d').hasMatch(password)) {
      return 'Şifre en az bir harf ve bir rakam içermeli.';
    }
    if (password != repeatedPassword) {
      return 'Şifreler birbiriyle eşleşmiyor.';
    }
    return null;
  }

  Future<void> _savePassword() async {
    if (_saving) {
      return;
    }
    final validationError = _validatePassword();
    if (validationError != null) {
      setState(() => _errorMessage = validationError);
      return;
    }
    setState(() {
      _saving = true;
      _errorMessage = null;
    });
    try {
      await SourceBaseAuthBackend.updatePassword(_passwordController.text);
      await SourceBaseAuthBackend.signOut();
      if (!mounted) {
        return;
      }
      Navigator.pushNamedAndRemoveUntil(
        context,
        LoginScreen.route,
        (_) => false,
        arguments: const {
          'success': 'Şifren güncellendi. Yeni şifrenle giriş yapabilirsin.',
        },
      );
    } catch (error) {
      if (mounted) {
        setState(
          () => _errorMessage = SourceBaseAuthBackend.friendlyError(error),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  Future<void> _returnToLogin() async {
    if (_saving) {
      return;
    }
    setState(() => _saving = true);
    try {
      await SourceBaseAuthBackend.signOut();
    } finally {
      if (mounted) {
        Navigator.pushNamedAndRemoveUntil(
          context,
          LoginScreen.route,
          (_) => false,
        );
      }
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
    if (_passwordRecovery) {
      return AuthScreenFrame(
        children: [
          const AuthHeader(
            title: 'Yeni şifre\nbelirle',
            subtitle:
                'Hesabına tekrar güvenli şekilde\nerişmek için yeni şifreni gir.',
            art: AuthArtType.forgot,
          ),
          const SizedBox(height: 44),
          AuthTextField(
            icon: Icons.lock_outline_rounded,
            hint: 'Yeni şifre',
            controller: _passwordController,
            obscureText: _obscurePassword,
            textInputAction: TextInputAction.next,
            autofillHints: const [AutofillHints.newPassword],
            trailing: IconButton(
              tooltip: _obscurePassword ? 'Şifreyi göster' : 'Şifreyi gizle',
              onPressed: _saving
                  ? null
                  : () => setState(
                        () => _obscurePassword = !_obscurePassword,
                      ),
              icon: Icon(
                _obscurePassword
                    ? Icons.visibility_outlined
                    : Icons.visibility_off_outlined,
              ),
            ),
          ),
          const SizedBox(height: 14),
          AuthTextField(
            icon: Icons.lock_outline_rounded,
            hint: 'Yeni şifre tekrar',
            controller: _repeatPasswordController,
            obscureText: _obscureRepeatPassword,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _savePassword(),
            autofillHints: const [AutofillHints.newPassword],
            trailing: IconButton(
              tooltip: _obscureRepeatPassword
                  ? 'Şifreyi göster'
                  : 'Şifreyi gizle',
              onPressed: _saving
                  ? null
                  : () => setState(
                        () => _obscureRepeatPassword =
                            !_obscureRepeatPassword,
                      ),
              icon: Icon(
                _obscureRepeatPassword
                    ? Icons.visibility_outlined
                    : Icons.visibility_off_outlined,
              ),
            ),
          ),
          if (_errorMessage != null) ...[
            const SizedBox(height: 14),
            AuthStatusBox(message: _errorMessage!),
          ],
          const SizedBox(height: 30),
          GradientActionButton(
            label: _saving ? 'Kaydediliyor...' : 'Şifreyi güncelle',
            onPressed: _saving ? null : _savePassword,
          ),
          const SizedBox(height: 18),
          OutlineActionButton(
            label: 'Giriş ekranına dön',
            onPressed: _saving ? null : _returnToLogin,
          ),
        ],
      );
    }

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
                  _statusMessage ??
                      (_checking
                          ? 'Oturum hazırlanıyor...'
                          : 'Yönlendiriliyor...'),
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
