import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../drive/presentation/screens/drive_workspace_screen.dart';
import '../../data/sourcebase_auth_backend.dart';
import '../widgets/auth_widgets.dart';
import 'login_screen.dart';
import 'profile_setup_screen.dart';
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
  final List<TextEditingController> _otpControllers = List.generate(
    6,
    (_) => TextEditingController(),
  );
  int _remainingSeconds = 120;
  late Timer _timer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !SourceBaseAuthBackend.currentUserHasVerifiedEmail) {
        return;
      }
      Navigator.pushNamedAndRemoveUntil(context, _routeAfterAuth, (_) => false);
    });
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        if (_remainingSeconds > 0) {
          _remainingSeconds--;
        } else {
          timer.cancel();
        }
      });
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    for (final controller in _otpControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  String get _timerLabel {
    final minutes = _remainingSeconds ~/ 60;
    final seconds = _remainingSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  bool get _canResend => _remainingSeconds == 0;

  String get _enteredCode => _otpControllers.map((c) => c.text).join();

  String get _routeAfterAuth {
    if (SourceBaseAuthBackend.currentUser == null) {
      return LoginScreen.route;
    }
    if (SourceBaseAuthBackend.currentUserNeedsSourceBaseProfile) {
      return ProfileSetupScreen.route;
    }
    return DriveWorkspaceScreen.route;
  }

  Future<void> _verify(String email) async {
    if (loading) return;
    if (email.trim().isEmpty) {
      setState(() => errorMessage = 'E-posta adresi bulunamadı.');
      return;
    }
    final code = _enteredCode;
    if (code.length != 6) {
      setState(() => errorMessage = 'Lütfen 6 haneli doğrulama kodunu gir.');
      return;
    }
    if (!SourceBaseAuthBackend.isConfigured ||
        SourceBaseAuthBackend.initializationError != null) {
      setState(
        () => errorMessage = SourceBaseAuthBackend.friendlyError(
          SourceBaseAuthBackend.initializationError ?? Object(),
        ),
      );
      return;
    }
    setState(() {
      loading = true;
      message = null;
      errorMessage = null;
    });
    try {
      await SourceBaseAuthBackend.verifyEmailOtp(
        email: email,
        token: code,
      );
      if (!mounted) return;
      Navigator.pushNamedAndRemoveUntil(
        context,
        _routeAfterAuth,
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

  Future<void> _resend(String email) async {
    if (loading || !_canResend) {
      return;
    }
    if (email.trim().isEmpty) {
      setState(() => errorMessage = 'E-posta adresi bulunamadı.');
      return;
    }
    if (!SourceBaseAuthBackend.isConfigured ||
        SourceBaseAuthBackend.initializationError != null) {
      setState(
        () => errorMessage = SourceBaseAuthBackend.friendlyError(
          SourceBaseAuthBackend.initializationError ?? Object(),
        ),
      );
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
        setState(() {
          message = result.message;
          _remainingSeconds = 120;
        });
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
        SourceBaseAuthBackend.currentUser?.email ??
        '';
    final screenWidth = MediaQuery.sizeOf(context).width;
    final codeBoxWidth = ((screenWidth - 122) / 6).clamp(38.0, 50.0).toDouble();
    return AuthScreenFrame(
      children: [
        const AuthHeader(
          title: 'E-postanı\ndoğrula',
          subtitle: 'E-postandaki bağlantıyı aç veya\n6 haneli doğrulama kodunu gir.',
          art: AuthArtType.verify,
        ),
        const SizedBox(height: 50),
        if (email.isNotEmpty)
          Text(
            email,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppColors.navy,
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
        const SizedBox(height: 24),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: List.generate(
            6,
            (index) => SizedBox(
              width: codeBoxWidth,
              height: 64,
              child: TextField(
                controller: _otpControllers[index],
                textAlign: TextAlign.center,
                keyboardType: TextInputType.number,
                maxLength: 1,
                style: const TextStyle(
                  color: AppColors.blue,
                  fontSize: 27,
                  fontWeight: FontWeight.w800,
                ),
                decoration: InputDecoration(
                  counterText: '',
                  filled: true,
                  fillColor: AppColors.white.withValues(alpha: .96),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: AppColors.line),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: AppColors.line),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: AppColors.blue, width: 2),
                  ),
                ),
                onChanged: (value) {
                  if (value.isNotEmpty && index < 5) {
                    FocusScope.of(context).nextFocus();
                  }
                },
              ),
            ),
          ),
        ),
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
                onPressed:
                    loading || !_canResend
                        ? null
                        : () => _resend(email),
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
              Text(
                _timerLabel,
                style: TextStyle(
                  color: _canResend ? AppColors.blue : AppColors.muted,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
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
          label: loading ? 'Doğrulanıyor...' : 'Doğrula',
          onPressed: loading ? null : () => _verify(email),
        ),
        const SizedBox(height: 22),
        Center(
          child: TextButton(
            onPressed: loading
                ? null
                : () => Navigator.pushReplacementNamed(
                      context,
                      RegisterScreen.route,
                    ),
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
