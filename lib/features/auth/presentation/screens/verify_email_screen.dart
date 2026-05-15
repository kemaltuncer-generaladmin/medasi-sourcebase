import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../drive/presentation/screens/drive_workspace_screen.dart';
import '../../data/sourcebase_auth_backend.dart';
import '../widgets/auth_widgets.dart';
import 'register_screen.dart';

class VerifyEmailScreen extends StatefulWidget {
  const VerifyEmailScreen({super.key});

  static const route = '/verify-email';

  @override
  State<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends State<VerifyEmailScreen> {
  bool loading = false;
  String? message;
  String? errorMessage;

  Future<void> _resend(String email) async {
    if (!SourceBaseAuthBackend.isConfigured) {
      setState(() => message = 'Doğrulama kodu tekrar gönderildi.');
      return;
    }
    setState(() {
      loading = true;
      message = null;
      errorMessage = null;
    });
    try {
      final result = await SourceBaseAuthBackend.resendSignupEmail(email);
      if (mounted) {
        setState(() => message = result.message);
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
    final email =
        ModalRoute.of(context)?.settings.arguments as String? ??
        'ornek@universite.edu.tr';
    return AuthScreenFrame(
      children: [
        const AuthHeader(
          title: 'E-postanı\ndoğrula',
          subtitle: 'Sana gönderdiğimiz 6 haneli\ndoğrulama kodunu gir.',
          art: AuthArtType.verify,
        ),
        const SizedBox(height: 50),
        Text(
          email,
          style: const TextStyle(
            color: AppColors.navy,
            fontSize: 20,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 24),
        const _OtpRow(digits: ['4', '7', '2', '9', '1', '3']),
        const SizedBox(height: 30),
        Container(
          height: 58,
          padding: const EdgeInsets.symmetric(horizontal: 18),
          decoration: BoxDecoration(
            color: AppColors.white.withValues(alpha: .92),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.line),
          ),
          child: Row(
            children: [
              const Text(
                'Kod gelmedi mi?',
                style: TextStyle(color: AppColors.muted, fontSize: 18),
              ),
              const Spacer(),
              TextButton(
                onPressed: loading ? () {} : () => _resend(email),
                style: TextButton.styleFrom(foregroundColor: AppColors.blue),
                child: Text(
                  loading ? 'Gönderiliyor...' : 'Tekrar gönder',
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Container(width: 1, height: 24, color: AppColors.line),
              const SizedBox(width: 16),
              const Text(
                '00:42',
                style: TextStyle(color: AppColors.muted, fontSize: 18),
              ),
            ],
          ),
        ),
        if (message != null || errorMessage != null) ...[
          const SizedBox(height: 14),
          AuthStatusBox(
            message: message ?? errorMessage!,
            error: errorMessage != null,
          ),
        ],
        const SizedBox(height: 38),
        GradientActionButton(
          label: 'Doğrula',
          onPressed: () => Navigator.pushNamedAndRemoveUntil(
            context,
            DriveWorkspaceScreen.route,
            (_) => false,
          ),
        ),
        const SizedBox(height: 22),
        Center(
          child: TextButton(
            onPressed: () => Navigator.pushNamed(context, RegisterScreen.route),
            style: TextButton.styleFrom(foregroundColor: AppColors.blue),
            child: const Text(
              'E-postayı değiştir',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
            ),
          ),
        ),
      ],
    );
  }
}

class _OtpRow extends StatelessWidget {
  const _OtpRow({required this.digits});

  final List<String> digits;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: digits
          .map(
            (digit) => Container(
              width: 50,
              height: 64,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.white.withValues(alpha: .96),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.line),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF244E94).withValues(alpha: .06),
                    blurRadius: 14,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Text(
                digit,
                style: const TextStyle(
                  color: AppColors.blue,
                  fontSize: 27,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          )
          .toList(),
    );
  }
}
