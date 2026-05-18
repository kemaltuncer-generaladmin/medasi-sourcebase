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
  bool terms = false;
  bool obscureOne = true;
  bool obscureTwo = true;
  bool loading = false;
  String? errorMessage;
  static final _emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  @override
  void dispose() {
    nameController.dispose();
    emailController.dispose();
    passwordController.dispose();
    repeatPasswordController.dispose();
    super.dispose();
  }

  String? _validateForm() {
    final name = nameController.text.trim();
    final email = emailController.text.trim();
    final password = passwordController.text;
    final repeatedPassword = repeatPasswordController.text;

    if (name.isEmpty) {
      return 'Ad soyad bilgisini doldurmalısın.';
    }
    if (email.isEmpty) {
      return 'E-posta adresini girmelisin.';
    }
    if (!_emailPattern.hasMatch(email)) {
      return 'Geçerli bir e-posta adresi gir.';
    }
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
    if (!terms) {
      return 'Kullanım koşullarını kabul etmelisin.';
    }
    if (!SourceBaseAuthBackend.isConfigured ||
        SourceBaseAuthBackend.initializationError != null) {
      return SourceBaseAuthBackend.friendlyError(
        SourceBaseAuthBackend.initializationError ?? Object(),
      );
    }
    return null;
  }

  Future<void> _signUp() async {
    if (loading) {
      return;
    }
    final validationError = _validateForm();
    if (validationError != null) {
      setState(() => errorMessage = validationError);
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
              onTap: loading ? null : () => setState(() => terms = !terms),
              label: 'Kullanım koşullarını kabul ediyorum',
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
          onPressed: loading
              ? null
              : () => Navigator.pushNamed(context, LoginScreen.route),
          size: SBButtonSize.large,
        ),
        const SizedBox(height: 24),
        Center(
          child: TextButton(
            onPressed: loading
                ? null
                : () => Navigator.pushNamed(context, LoginScreen.route),
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
