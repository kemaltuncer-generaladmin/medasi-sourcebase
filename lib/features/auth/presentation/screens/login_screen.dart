import 'package:flutter/material.dart';

import '../../../../core/design_system/design_system.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../drive/presentation/screens/drive_workspace_screen.dart';
import '../../data/sourcebase_auth_backend.dart';
import '../widgets/auth_widgets.dart';
import 'forgot_password_screen.dart';
import 'register_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  static const route = '/login';

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  bool remember = true;
  bool obscure = true;
  bool loading = false;
  String? errorMessage;

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    if (!SourceBaseAuthBackend.isConfigured) {
      Navigator.pushNamedAndRemoveUntil(
        context,
        DriveWorkspaceScreen.route,
        (_) => false,
      );
      return;
    }
    setState(() {
      loading = true;
      errorMessage = null;
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
        DriveWorkspaceScreen.route,
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
        Row(
          children: [
            AuthCheck(
              value: remember,
              onTap: () => setState(() => remember = !remember),
            ),
            const SizedBox(width: 12),
            const Text(
              'Beni hatırla',
              style: TextStyle(color: AppColors.navy, fontSize: 18),
            ),
            Expanded(
              child: Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () =>
                      Navigator.pushNamed(context, ForgotPasswordScreen.route),
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
            ),
          ],
        ),
        if (errorMessage != null) ...[
          const SizedBox(height: 10),
          AuthStatusBox(message: errorMessage!),
        ],
        const SizedBox(height: 18),
        SBPrimaryButton(
          label: 'Giriş Yap',
          onPressed: loading ? null : _signIn,
          loading: loading,
          size: SBButtonSize.large,
        ),
        const SizedBox(height: 16),
        SBSecondaryButton(
          label: 'Hesap Oluştur',
          onPressed: () => Navigator.pushNamed(context, RegisterScreen.route),
          size: SBButtonSize.large,
        ),
        const SizedBox(height: 28),
        Center(
          child: TextButton(
            onPressed: () => Navigator.pushNamed(context, RegisterScreen.route),
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
