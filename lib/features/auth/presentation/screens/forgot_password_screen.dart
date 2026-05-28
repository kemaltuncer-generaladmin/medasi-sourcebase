import 'package:flutter/material.dart';

import '../../../../core/design_system/design_system.dart';
import '../../../../core/theme/app_colors.dart';
import '../../data/sourcebase_auth_backend.dart';
import '../widgets/auth_widgets.dart';
import 'login_screen.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  static const route = '/forgot';

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final emailController = TextEditingController();
  bool loading = false;
  String? errorMessage;
  String? successMessage;
  static final _emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  @override
  void dispose() {
    emailController.dispose();
    super.dispose();
  }

  String? _validateEmail() {
    final email = emailController.text.trim();
    if (email.isEmpty) {
      return 'E-posta adresini girmelisin.';
    }
    if (!_emailPattern.hasMatch(email)) {
      return 'Geçerli bir e-posta adresi gir.';
    }
    if (!SourceBaseAuthBackend.isConfigured ||
        SourceBaseAuthBackend.initializationError != null) {
      return SourceBaseAuthBackend.friendlyError(
        SourceBaseAuthBackend.initializationError ?? Object(),
      );
    }
    return null;
  }

  Future<void> _sendReset() async {
    if (loading) {
      return;
    }
    final validationError = _validateEmail();
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
      final result = await SourceBaseAuthBackend.sendPasswordReset(
        emailController.text,
      );
      if (mounted) {
        setState(() => successMessage = result.message);
      }
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
          title: 'Şifreni yenile',
          subtitle: 'Şifreni yenilemek için kayıtlı e-posta adresini gir.',
          art: AuthArtType.forgot,
        ),
        const SizedBox(height: 16),
        AuthTextField(
          icon: Icons.mail_outline_rounded,
          hint: 'E-posta',
          controller: emailController,
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _sendReset(),
        ),
        const SizedBox(height: 14),
        SourceBaseCard(
          padding: const EdgeInsets.all(14),
          elevated: false,
          backgroundColor: AppColors.selectedBlue,
          borderColor: AppColors.softLine,
          child: Row(
            children: [
              const Icon(
                Icons.info_outline_rounded,
                color: AppColors.blue,
                size: 21,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Bağlantı yalnızca kayıtlı e-posta adresine gönderilir.',
                  style: SBTextStyles.bodySmall.copyWith(
                    color: AppColors.muted,
                  ),
                ),
              ),
            ],
          ),
        ),
        if (errorMessage != null || successMessage != null) ...[
          const SizedBox(height: 14),
          AuthStatusBox(
            message: errorMessage ?? successMessage!,
            error: errorMessage != null,
          ),
        ],
        const SizedBox(height: 16),
        GradientActionButton(
          label: loading ? 'Gönderiliyor...' : 'Sıfırlama bağlantısı gönder',
          onPressed: loading ? null : _sendReset,
        ),
        const SizedBox(height: 18),
        OutlineActionButton(
          label: 'Giriş ekranına dön',
          onPressed: loading
              ? null
              : () => Navigator.pushNamedAndRemoveUntil(
                  context,
                  LoginScreen.route,
                  (_) => false,
                ),
        ),
      ],
    );
  }
}
