import 'package:flutter/material.dart';

import '../../../../core/design_system/design_system.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../drive/presentation/screens/drive_workspace_screen.dart';
import '../../data/sourcebase_auth_backend.dart';
import '../widgets/auth_widgets.dart';
import 'forgot_password_screen.dart';
import 'profile_setup_screen.dart';
import 'register_screen.dart';
import 'verify_email_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  static const route = '/login';

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  bool obscure = true;
  bool loading = false;
  String? errorMessage;
  String? successMessage;
  bool _readRouteMessage = false;

  static final _emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_readRouteMessage) {
      return;
    }
    _readRouteMessage = true;
    final arguments = ModalRoute.of(context)?.settings.arguments;
    if (arguments is String && arguments.trim().isNotEmpty) {
      errorMessage = arguments.trim();
    } else if (arguments is Map) {
      final error = arguments['error'];
      final success = arguments['success'];
      if (error is String && error.trim().isNotEmpty) {
        errorMessage = error.trim();
      }
      if (success is String && success.trim().isNotEmpty) {
        successMessage = success.trim();
      }
    }
  }

  String? _validateEmail(String value) {
    final email = value.trim();
    if (email.isEmpty) {
      return 'E-posta adresini girmelisin.';
    }
    if (!_emailPattern.hasMatch(email)) {
      return 'Geçerli bir e-posta adresi gir.';
    }
    return null;
  }

  String? _validateSignInForm() {
    final emailError = _validateEmail(emailController.text);
    if (emailError != null) {
      return emailError;
    }
    if (passwordController.text.isEmpty) {
      return 'Şifreni girmelisin.';
    }
    if (!SourceBaseAuthBackend.isConfigured ||
        SourceBaseAuthBackend.initializationError != null) {
      return SourceBaseAuthBackend.friendlyError(
        SourceBaseAuthBackend.initializationError ?? Object(),
      );
    }
    return null;
  }

  String get _postLoginRoute {
    if (!SourceBaseAuthBackend.currentUserHasVerifiedEmail) {
      return VerifyEmailScreen.route;
    }
    if (SourceBaseAuthBackend.currentUserNeedsSourceBaseProfile) {
      return ProfileSetupScreen.route;
    }
    return DriveWorkspaceScreen.route;
  }

  Future<void> _signIn() async {
    if (loading || _socialLoading) {
      return;
    }
    final validationError = _validateSignInForm();
    if (validationError != null) {
      setState(() {
        errorMessage = validationError;
        successMessage = null;
      });
      return;
    }
    setState(() {
      loading = true;
      errorMessage = null;
      successMessage = null;
    });
    try {
      await SourceBaseAuthBackend.signIn(
        email: emailController.text,
        password: passwordController.text,
      );
      if (!mounted) {
        return;
      }
      Navigator.pushNamedAndRemoveUntil(
        context,
        _postLoginRoute,
        (_) => false,
      );
    } catch (error) {
      if (mounted) {
        setState(
          () => errorMessage = SourceBaseAuthBackend.friendlyError(error),
        );
      }
    } finally {
      if (mounted) {
        setState(() => loading = false);
      }
    }
  }

  bool _socialLoading = false;

  Future<void> _signInWithGoogle() async {
    if (loading || _socialLoading) {
      return;
    }
    if (!SourceBaseAuthBackend.isConfigured ||
        SourceBaseAuthBackend.initializationError != null) {
      setState(() {
        errorMessage = SourceBaseAuthBackend.friendlyError(
          SourceBaseAuthBackend.initializationError ?? Object(),
        );
        successMessage = null;
      });
      return;
    }
    setState(() {
      _socialLoading = true;
      errorMessage = null;
      successMessage = null;
    });
    try {
      await SourceBaseAuthBackend.signInWithGoogle();
    } catch (error) {
      if (mounted) {
        setState(
          () => errorMessage = SourceBaseAuthBackend.friendlyError(error),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _socialLoading = false);
      }
    }
  }

  Future<void> _signInWithApple() async {
    if (loading || _socialLoading) {
      return;
    }
    if (!SourceBaseAuthBackend.isConfigured ||
        SourceBaseAuthBackend.initializationError != null) {
      setState(() {
        errorMessage = SourceBaseAuthBackend.friendlyError(
          SourceBaseAuthBackend.initializationError ?? Object(),
        );
        successMessage = null;
      });
      return;
    }
    setState(() {
      _socialLoading = true;
      errorMessage = null;
      successMessage = null;
    });
    try {
      await SourceBaseAuthBackend.signInWithApple();
    } catch (error) {
      if (mounted) {
        setState(
          () => errorMessage = SourceBaseAuthBackend.friendlyError(error),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _socialLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthScreenFrame(
      children: [
        const AuthHeader(
          title: 'Hoş geldin',
          subtitle: 'Kaynaklarını akıllı öğrenme\naraçlarına dönüştür.',
          art: AuthArtType.login,
        ),
        const SizedBox(height: 38),
        AuthTextField(
          icon: Icons.mail_outline_rounded,
          hint: 'E-posta',
          controller: emailController,
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.next,
          autofillHints: const [AutofillHints.email],
        ),
        const SizedBox(height: 18),
        AuthTextField(
          icon: Icons.lock_outline_rounded,
          hint: 'Şifre',
          controller: passwordController,
          obscureText: obscure,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _signIn(),
          autofillHints: const [AutofillHints.password],
          trailing: IconButton(
            tooltip: obscure ? 'Şifreyi göster' : 'Şifreyi gizle',
            onPressed: () => setState(() => obscure = !obscure),
            icon: Icon(
              obscure
                  ? Icons.visibility_outlined
                  : Icons.visibility_off_outlined,
            ),
          ),
        ),
        const SizedBox(height: 18),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: loading || _socialLoading
                ? null
                : () => Navigator.pushNamed(
                      context,
                      ForgotPasswordScreen.route,
                    ),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.blue,
              padding: const EdgeInsets.symmetric(horizontal: 4),
            ),
            child: const FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                'Şifremi unuttum',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ),
        if (errorMessage != null) ...[
          const SizedBox(height: 10),
          AuthStatusBox(message: errorMessage!),
        ],
        if (successMessage != null) ...[
          const SizedBox(height: 10),
          AuthStatusBox(message: successMessage!, error: false),
        ],
        const SizedBox(height: 18),
        SBPrimaryButton(
          label: 'Giriş Yap',
          onPressed: loading || _socialLoading ? null : _signIn,
          loading: loading,
          size: SBButtonSize.large,
        ),
        const SizedBox(height: 22),
        const DividerLabel('veya'),
        const SizedBox(height: 14),
        SocialAuthButton(
          label: 'Google ile devam et',
          icon: const GoogleGlyph(),
          onPressed: _socialLoading || loading ? null : _signInWithGoogle,
        ),
        const SizedBox(height: 12),
        SocialAuthButton(
          label: 'Apple ile devam et',
          icon: const Icon(
            Icons.apple,
            size: 26,
            color: AppColors.navy,
          ),
          onPressed: _socialLoading || loading ? null : _signInWithApple,
        ),
        const SizedBox(height: 22),
        SBSecondaryButton(
          label: 'Hesap Oluştur',
          onPressed: loading || _socialLoading
              ? null
              : () => Navigator.pushNamed(context, RegisterScreen.route),
          size: SBButtonSize.large,
        ),
        const SizedBox(height: 28),
        Center(
          child: TextButton(
            onPressed: loading || _socialLoading
                ? null
                : () => Navigator.pushNamed(context, RegisterScreen.route),
            style: TextButton.styleFrom(foregroundColor: AppColors.blue),
            child: const Text.rich(
              TextSpan(
                text: 'Hesabın yok mu? ',
                style: TextStyle(
                  color: AppColors.muted,
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                ),
                children: [
                  TextSpan(
                    text: 'Kayıt ol',
                    style: TextStyle(
                      color: AppColors.blue,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
