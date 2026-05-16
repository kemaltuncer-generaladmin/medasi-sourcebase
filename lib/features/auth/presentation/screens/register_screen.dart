import 'package:flutter/material.dart';

import '../../../../core/design_system/design_system.dart';
import '../../../../core/theme/app_colors.dart';
import '../../data/sourcebase_auth_backend.dart';
import '../widgets/auth_widgets.dart';
import 'login_screen.dart';
import 'verify_email_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  static const route = '/register';

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final nameController = TextEditingController();
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final repeatPasswordController = TextEditingController();
  bool terms = true;
  bool obscureOne = true;
  bool obscureTwo = true;
  bool loading = false;
  String? errorMessage;

  @override
  void dispose() {
    nameController.dispose();
    emailController.dispose();
    passwordController.dispose();
    repeatPasswordController.dispose();
    super.dispose();
  }

  Future<void> _signUp() async {
    if (!terms) {
      setState(() => errorMessage = 'Kullanım koşullarını kabul etmelisin.');
      return;
    }
    if (passwordController.text != repeatPasswordController.text) {
      setState(() => errorMessage = 'Şifreler birbiriyle eşleşmiyor.');
      return;
    }
    if (!SourceBaseAuthBackend.isConfigured) {
      Navigator.pushNamed(
        context,
        VerifyEmailScreen.route,
        arguments: emailController.text.trim().isEmpty
            ? 'ornek@universite.edu.tr'
            : emailController.text.trim(),
      );
      return;
    }

    setState(() {
      loading = true;
      errorMessage = null;
    });
    try {
      await SourceBaseAuthBackend.signUp(
        fullName: nameController.text,
        email: emailController.text,
        password: passwordController.text,
      );
      if (!mounted) {
        return;
      }
      Navigator.pushNamed(
        context,
        VerifyEmailScreen.route,
        arguments: emailController.text.trim(),
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
          title: 'Hesap oluştur',
          subtitle: 'Kaynağını yükle, öğrenme\nsistemini oluştur.',
          art: AuthArtType.register,
        ),
        const SizedBox(height: 34),
        AuthTextField(
          icon: Icons.person_outline_rounded,
          hint: 'Ad Soyad',
          controller: nameController,
          textInputAction: TextInputAction.next,
        ),
        const SizedBox(height: 13),
        AuthTextField(
          icon: Icons.mail_outline_rounded,
          hint: 'E-posta',
          controller: emailController,
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.next,
        ),
        const SizedBox(height: 13),
        AuthTextField(
          icon: Icons.lock_outline_rounded,
          hint: 'Şifre',
          controller: passwordController,
          obscureText: obscureOne,
          textInputAction: TextInputAction.next,
          trailing: IconButton(
            onPressed: () => setState(() => obscureOne = !obscureOne),
            icon: Icon(
              obscureOne
                  ? Icons.visibility_outlined
                  : Icons.visibility_off_outlined,
            ),
          ),
        ),
        const SizedBox(height: 13),
        AuthTextField(
          icon: Icons.lock_outline_rounded,
          hint: 'Şifre Tekrar',
          controller: repeatPasswordController,
          obscureText: obscureTwo,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _signUp(),
          trailing: IconButton(
            onPressed: () => setState(() => obscureTwo = !obscureTwo),
            icon: Icon(
              obscureTwo
                  ? Icons.visibility_outlined
                  : Icons.visibility_off_outlined,
            ),
          ),
        ),
        const SizedBox(height: 18),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AuthCheck(
              value: terms,
              onTap: () => setState(() => terms = !terms),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: RichText(
                text: const TextSpan(
                  style: TextStyle(
                    fontFamily: 'SF Pro Display',
                    color: AppColors.navy,
                    fontSize: 18,
                    height: 1.34,
                  ),
                  children: [
                    TextSpan(
                      text: 'Kullanım koşullarını',
                      style: TextStyle(color: AppColors.blue),
                    ),
                    TextSpan(text: ' ve '),
                    TextSpan(
                      text: 'gizlilik politikasını',
                      style: TextStyle(color: AppColors.blue),
                    ),
                    TextSpan(text: '\nkabul ediyorum.'),
                  ],
                ),
              ),
            ),
          ],
        ),
        if (errorMessage != null) ...[
          const SizedBox(height: 12),
          AuthStatusBox(message: errorMessage!),
        ],
        const SizedBox(height: 22),
        SBPrimaryButton(
          label: 'Kayıt Ol',
          onPressed: loading ? null : _signUp,
          loading: loading,
          size: SBButtonSize.large,
        ),
        const SizedBox(height: 16),
        SBSecondaryButton(
          label: 'Giriş Yap',
          onPressed: () => Navigator.pushNamed(context, LoginScreen.route),
          size: SBButtonSize.large,
        ),
        const SizedBox(height: 24),
        Center(
          child: TextButton(
            onPressed: () => Navigator.pushNamed(context, LoginScreen.route),
            style: TextButton.styleFrom(foregroundColor: AppColors.blue),
            child: const Text.rich(
              TextSpan(
                text: 'Zaten hesabın var mı? ',
                style: TextStyle(color: AppColors.muted, fontSize: 17),
                children: [
                  TextSpan(
                    text: 'Giriş yap',
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
