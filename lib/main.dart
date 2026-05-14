import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'auth_backend.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await CardStationAuthBackend.initialize();
  runApp(const CardStationApp());
}

class CardStationApp extends StatelessWidget {
  const CardStationApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CardStation',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: AppColors.page,
        fontFamily: 'SF Pro Display',
        textSelectionTheme: const TextSelectionThemeData(
          cursorColor: AppColors.blue,
        ),
      ),
      initialRoute: CardStationAuthBackend.currentUser == null
          ? LoginScreen.route
          : HomeScreen.route,
      routes: {
        LoginScreen.route: (_) => const LoginScreen(),
        RegisterScreen.route: (_) => const RegisterScreen(),
        ForgotPasswordScreen.route: (_) => const ForgotPasswordScreen(),
        ResetCodeScreen.route: (_) => const ResetCodeScreen(),
        NewPasswordScreen.route: (_) => const NewPasswordScreen(),
        PasswordUpdatedScreen.route: (_) => const PasswordUpdatedScreen(),
        VerifyEmailScreen.route: (_) => const VerifyEmailScreen(),
        EmailVerifiedScreen.route: (_) => const EmailVerifiedScreen(),
        EmailTemplateScreen.route: (_) => const EmailTemplateScreen(),
        AuthCallbackScreen.route: (_) => const AuthCallbackScreen(),
        HomeScreen.route: (_) => const HomeScreen(),
      },
    );
  }
}

class AppColors {
  static const page = Color(0xFFF8FBFF);
  static const navy = Color(0xFF091946);
  static const muted = Color(0xFF66779D);
  static const blue = Color(0xFF075FFF);
  static const deepBlue = Color(0xFF2449F4);
  static const cyan = Color(0xFF09C7D0);
  static const line = Color(0xFFC7D5EC);
  static const panel = Color(0xFFFFFFFF);
  static const softBlue = Color(0xFFEAF4FF);
}

class AppGradients {
  static const primary = LinearGradient(
    colors: [AppColors.deepBlue, Color(0xFF0589F7), AppColors.cyan],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );
  static const mark = LinearGradient(
    colors: [Color(0xFF13D0D6), Color(0xFF1266F4), Color(0xFF162AC7)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}

enum HeroKind {
  login,
  register,
  forgot,
  resetCode,
  verifyEmail,
  emailVerified,
  newPassword,
  passwordUpdated,
  emailTemplate,
}

class AuthShell extends StatelessWidget {
  const AuthShell({
    required this.children,
    this.maxContentWidth = 430,
    super.key,
  });

  final List<Widget> children;
  final double maxContentWidth;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CustomPaint(
        painter: BackgroundPatternPainter(),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final horizontalInset = constraints.maxWidth > 700 ? 24.0 : 0.0;
              return Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: maxContentWidth),
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: EdgeInsets.fromLTRB(
                      horizontalInset,
                      24,
                      horizontalInset,
                      28,
                    ),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minHeight: constraints.maxHeight,
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [const BrandHeader(), ...children],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class BrandHeader extends StatelessWidget {
  const BrandHeader({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(
              width: 66,
              height: 54,
              child: CustomPaint(painter: LogoMarkPainter()),
            ),
            const SizedBox(width: 12),
            RichText(
              text: const TextSpan(
                style: TextStyle(
                  fontSize: 34,
                  height: 1,
                  letterSpacing: 0,
                  fontWeight: FontWeight.w700,
                  fontFamily: 'SF Pro Display',
                ),
                children: [
                  TextSpan(
                    text: 'Card',
                    style: TextStyle(color: Color(0xFF111DB2)),
                  ),
                  TextSpan(
                    text: 'Station',
                    style: TextStyle(color: Color(0xFF12B9CB)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

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
    setState(() {
      loading = true;
      errorMessage = null;
    });
    try {
      await CardStationAuthBackend.signIn(
        email: emailController.text,
        password: passwordController.text,
      );
      if (!mounted) {
        return;
      }
      Navigator.pushNamedAndRemoveUntil(
        context,
        HomeScreen.route,
        (_) => false,
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(
        () => errorMessage = CardStationAuthBackend.friendlyError(error),
      );
    } finally {
      if (mounted) {
        setState(() => loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthShell(
      children: [
        const SizedBox(height: 30),
        const HeroArt(kind: HeroKind.login),
        const SizedBox(height: 24),
        const ScreenTitle(
          title: 'Tekrar etmeye kaldığın\nyerden devam et',
          subtitle:
              'Akıllı tekrar sistemi ve AI destekli kartlarla\nbilgini kalıcı hale getir.',
        ),
        const SizedBox(height: 18),
        FormPanel(
          children: [
            const FieldLabel('E-posta'),
            CsTextField(
              icon: Icons.mail_outline_rounded,
              hint: 'ornek@medasi.com',
              controller: emailController,
              keyboardType: TextInputType.emailAddress,
              autofillHints: const [AutofillHints.email],
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 16),
            const FieldLabel('Şifre'),
            CsTextField(
              icon: Icons.lock_outline_rounded,
              hint: '••••••••••••',
              controller: passwordController,
              obscureText: obscure,
              autofillHints: const [AutofillHints.password],
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _signIn(),
              trailing: IconButton(
                onPressed: () => setState(() => obscure = !obscure),
                icon: Icon(
                  obscure
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                ),
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                CsCheckbox(
                  value: remember,
                  onTap: () => setState(() => remember = !remember),
                ),
                const SizedBox(width: 9),
                const Expanded(
                  child: Text(
                    'Beni hatırla',
                    style: TextStyle(color: AppColors.muted, fontSize: 16),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                TextButton(
                  onPressed: () =>
                      Navigator.pushNamed(context, ForgotPasswordScreen.route),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.blue,
                    padding: EdgeInsets.zero,
                    minimumSize: const Size(0, 36),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Text(
                    'Şifremi unuttum?',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (errorMessage != null) ...[
              StatusMessageBox(
                icon: Icons.error_outline_rounded,
                text: errorMessage!,
                isError: true,
              ),
              const SizedBox(height: 12),
            ],
            GradientButton(
              label: loading ? 'Giriş yapılıyor...' : 'Giriş Yap',
              onPressed: loading ? () {} : _signIn,
            ),
            const SizedBox(height: 12),
            OutlineCsButton(
              label: 'Kayıt Ol',
              onPressed: () =>
                  Navigator.pushNamed(context, RegisterScreen.route),
            ),
          ],
        ),
        const SizedBox(height: 32),
        const EcoFooter(),
      ],
    );
  }
}

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
      setState(
        () => errorMessage =
            'Devam etmek için kullanım koşullarını kabul etmelisin.',
      );
      return;
    }
    if (passwordController.text != repeatPasswordController.text) {
      setState(() => errorMessage = 'Şifreler birbiriyle eşleşmiyor.');
      return;
    }
    setState(() {
      loading = true;
      errorMessage = null;
    });
    try {
      await CardStationAuthBackend.signUp(
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
      if (!mounted) {
        return;
      }
      setState(
        () => errorMessage = CardStationAuthBackend.friendlyError(error),
      );
    } finally {
      if (mounted) {
        setState(() => loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthShell(
      children: [
        const SizedBox(height: 28),
        const HeroArt(kind: HeroKind.register),
        const SizedBox(height: 18),
        const ScreenTitle(
          title: 'Kendi öğrenme istasyonunu oluştur',
          subtitle:
              'Hesabını oluştur, AI destekli kartlarınla\ndaha akıllı ve verimli öğrenmeye hemen başla.',
          titleSize: 23,
        ),
        const SizedBox(height: 18),
        FormPanel(
          children: [
            const FieldLabel('Ad Soyad'),
            CsTextField(
              icon: Icons.person_outline_rounded,
              hint: 'Adınızı ve soyadınızı girin',
              controller: nameController,
              autofillHints: const [AutofillHints.name],
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 13),
            const FieldLabel('E-posta'),
            CsTextField(
              icon: Icons.mail_outline_rounded,
              hint: 'ornek@medasi.com',
              controller: emailController,
              keyboardType: TextInputType.emailAddress,
              autofillHints: const [AutofillHints.email],
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 13),
            const FieldLabel('Şifre'),
            CsTextField(
              icon: Icons.lock_outline_rounded,
              hint: '••••••••••',
              controller: passwordController,
              obscureText: obscureOne,
              autofillHints: const [AutofillHints.newPassword],
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
            const FieldLabel('Şifre Tekrar'),
            CsTextField(
              icon: Icons.lock_outline_rounded,
              hint: '••••••••••',
              controller: repeatPasswordController,
              obscureText: obscureTwo,
              autofillHints: const [AutofillHints.newPassword],
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
            const SizedBox(height: 13),
            Row(
              children: [
                CsCheckbox(
                  value: terms,
                  onTap: () => setState(() => terms = !terms),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: RichText(
                    text: const TextSpan(
                      style: TextStyle(
                        fontSize: 13.5,
                        color: AppColors.muted,
                        fontFamily: 'SF Pro Display',
                      ),
                      children: [
                        TextSpan(
                          text: 'Kullanım koşullarını',
                          style: TextStyle(
                            color: AppColors.blue,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        TextSpan(text: ' ve '),
                        TextSpan(
                          text: 'gizlilik politikasını',
                          style: TextStyle(
                            color: AppColors.blue,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        TextSpan(text: ' kabul ediyorum'),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            if (errorMessage != null) ...[
              StatusMessageBox(
                icon: Icons.error_outline_rounded,
                text: errorMessage!,
                isError: true,
              ),
              const SizedBox(height: 12),
            ],
            GradientButton(
              label: loading ? 'Hesap oluşturuluyor...' : 'Kayıt Ol',
              onPressed: loading ? () {} : _signUp,
            ),
            const SizedBox(height: 12),
            OutlineCsButton(
              label: 'Zaten hesabın var mı? Giriş Yap',
              onPressed: () => Navigator.pushNamed(context, LoginScreen.route),
              fontSize: 16,
            ),
          ],
        ),
        const SizedBox(height: 28),
        const EcoFooter(),
      ],
    );
  }
}

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

  @override
  void dispose() {
    emailController.dispose();
    super.dispose();
  }

  Future<void> _sendReset() async {
    setState(() {
      loading = true;
      errorMessage = null;
    });
    try {
      await CardStationAuthBackend.sendPasswordReset(emailController.text);
      if (!mounted) {
        return;
      }
      Navigator.pushNamed(
        context,
        ResetCodeScreen.route,
        arguments: emailController.text.trim(),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(
        () => errorMessage = CardStationAuthBackend.friendlyError(error),
      );
    } finally {
      if (mounted) {
        setState(() => loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthShell(
      children: [
        const SizedBox(height: 30),
        const HeroArt(kind: HeroKind.forgot),
        const SizedBox(height: 22),
        const ScreenTitle(
          title: 'Şifreni mi unuttun?',
          subtitle:
              'E-posta adresini gir, şifreni sıfırlaman için\nsana 6 haneli bir kod gönderelim.',
        ),
        const SizedBox(height: 22),
        FormPanel(
          children: [
            const FieldLabel('E-posta'),
            CsTextField(
              icon: Icons.mail_outline_rounded,
              hint: 'ornek@medasi.com',
              controller: emailController,
              keyboardType: TextInputType.emailAddress,
              autofillHints: const [AutofillHints.email],
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _sendReset(),
            ),
            const SizedBox(height: 20),
            const InfoBox(
              icon: Icons.info_outline_rounded,
              text: 'Sıfırlama kodunu kayıtlı e-posta\nadresine göndereceğiz.',
            ),
            const SizedBox(height: 22),
            if (errorMessage != null) ...[
              StatusMessageBox(
                icon: Icons.error_outline_rounded,
                text: errorMessage!,
                isError: true,
              ),
              const SizedBox(height: 12),
            ],
            GradientButton(
              label: loading ? 'Gönderiliyor...' : 'Kod Gönder',
              onPressed: loading ? () {} : _sendReset,
            ),
          ],
        ),
        const SizedBox(height: 20),
        TextLink(
          label: 'Girişe Dön',
          onPressed: () => Navigator.pushNamed(context, LoginScreen.route),
        ),
        const SizedBox(height: 36),
        const EcoFooter(),
      ],
    );
  }
}

class ResetCodeScreen extends StatelessWidget {
  const ResetCodeScreen({super.key});

  static const route = '/reset-code';

  @override
  Widget build(BuildContext context) {
    final email = ModalRoute.of(context)?.settings.arguments as String?;
    return AuthShell(
      children: [
        const SizedBox(height: 28),
        const HeroArt(kind: HeroKind.resetCode),
        const SizedBox(height: 20),
        const ScreenTitle(
          title: 'Sıfırlama e-postanı kontrol et',
          subtitle:
              'Şifreni yenilemek için e-postana\ngönderdiğimiz CardStation bağlantısını aç.',
        ),
        const SizedBox(height: 22),
        SentToEmailBox(icon: Icons.mail_outline_rounded, email: email),
        const SizedBox(height: 20),
        const InfoBox(
          icon: Icons.link_rounded,
          text:
              'E-postadaki bağlantı bu uygulamaya döner ve yeni şifre ekranını açar.',
        ),
        const SizedBox(height: 24),
        GradientButton(
          label: 'Yeni şifre ekranına git',
          onPressed: () =>
              Navigator.pushNamed(context, NewPasswordScreen.route),
        ),
        const SizedBox(height: 12),
        OutlineCsButton(
          label: 'E-postayı değiştir',
          onPressed: () =>
              Navigator.pushNamed(context, ForgotPasswordScreen.route),
        ),
        const SizedBox(height: 32),
        const EcoFooter(),
      ],
    );
  }
}

class NewPasswordScreen extends StatefulWidget {
  const NewPasswordScreen({super.key});

  static const route = '/new-password';

  @override
  State<NewPasswordScreen> createState() => _NewPasswordScreenState();
}

class _NewPasswordScreenState extends State<NewPasswordScreen> {
  final passwordController = TextEditingController();
  final repeatPasswordController = TextEditingController();
  bool first = true;
  bool second = true;
  bool loading = false;
  String? errorMessage;

  @override
  void dispose() {
    passwordController.dispose();
    repeatPasswordController.dispose();
    super.dispose();
  }

  Future<void> _updatePassword() async {
    if (passwordController.text != repeatPasswordController.text) {
      setState(() => errorMessage = 'Şifreler birbiriyle eşleşmiyor.');
      return;
    }
    setState(() {
      loading = true;
      errorMessage = null;
    });
    try {
      await CardStationAuthBackend.updatePassword(passwordController.text);
      if (!mounted) {
        return;
      }
      Navigator.pushNamedAndRemoveUntil(
        context,
        PasswordUpdatedScreen.route,
        (_) => false,
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(
        () => errorMessage = CardStationAuthBackend.friendlyError(error),
      );
    } finally {
      if (mounted) {
        setState(() => loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthShell(
      children: [
        const SizedBox(height: 28),
        const HeroArt(kind: HeroKind.newPassword),
        const SizedBox(height: 18),
        const ScreenTitle(
          title: 'Yeni şifre oluştur',
          subtitle: 'Hesabının güvenliği için güçlü bir şifre belirleyin.',
        ),
        const SizedBox(height: 24),
        FormPanel(
          children: [
            const FieldLabel('Yeni Şifre'),
            CsTextField(
              icon: Icons.lock_outline_rounded,
              hint: '••••••••••••',
              controller: passwordController,
              obscureText: first,
              autofillHints: const [AutofillHints.newPassword],
              textInputAction: TextInputAction.next,
              trailing: IconButton(
                onPressed: () => setState(() => first = !first),
                icon: Icon(
                  first
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                ),
              ),
            ),
            const SizedBox(height: 18),
            const FieldLabel('Yeni Şifre Tekrar'),
            CsTextField(
              icon: Icons.lock_outline_rounded,
              hint: '••••••••••••',
              controller: repeatPasswordController,
              obscureText: second,
              autofillHints: const [AutofillHints.newPassword],
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _updatePassword(),
              trailing: IconButton(
                onPressed: () => setState(() => second = !second),
                icon: Icon(
                  second
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                ),
              ),
            ),
            const SizedBox(height: 20),
            const RequirementBox(),
            const SizedBox(height: 22),
            if (errorMessage != null) ...[
              StatusMessageBox(
                icon: Icons.error_outline_rounded,
                text: errorMessage!,
                isError: true,
              ),
              const SizedBox(height: 12),
            ],
            GradientButton(
              label: loading ? 'Güncelleniyor...' : 'Şifreyi Güncelle',
              onPressed: loading ? () {} : _updatePassword,
            ),
            const SizedBox(height: 14),
            TextLink(
              label: 'Girişe Dön',
              onPressed: () => Navigator.pushNamed(context, LoginScreen.route),
            ),
          ],
        ),
        const SizedBox(height: 28),
        const EcoFooter(),
      ],
    );
  }
}

class PasswordUpdatedScreen extends StatelessWidget {
  const PasswordUpdatedScreen({super.key});

  static const route = '/password-updated';

  @override
  Widget build(BuildContext context) {
    return AuthShell(
      children: [
        const SizedBox(height: 34),
        const HeroArt(kind: HeroKind.passwordUpdated),
        const SizedBox(height: 26),
        const ScreenTitle(
          title: 'Şifren güncellendi',
          subtitle: 'Artık yeni şifrenle güvenle giriş yapabilirsin.',
        ),
        const SizedBox(height: 28),
        const NextStepCard(
          icon: Icons.flag_outlined,
          title: 'Bir sonraki adım:',
          text: 'hesabına giriş yap ve kaldığın\nyerden devam et.',
        ),
        const SizedBox(height: 28),
        GradientButton(
          label: 'Giriş Yap',
          onPressed: () => Navigator.pushNamedAndRemoveUntil(
            context,
            LoginScreen.route,
            (_) => false,
          ),
        ),
        const SizedBox(height: 12),
        OutlineCsButton(
          label: 'Giriş Ekranına Dön',
          onPressed: () => Navigator.pushNamedAndRemoveUntil(
            context,
            LoginScreen.route,
            (_) => false,
          ),
        ),
        const SizedBox(height: 42),
        const EcoFooter(),
      ],
    );
  }
}

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
    setState(() {
      loading = true;
      message = null;
      errorMessage = null;
    });
    try {
      final result = await CardStationAuthBackend.resendSignupEmail(email);
      if (!mounted) {
        return;
      }
      setState(() => message = result.message);
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(
        () => errorMessage = CardStationAuthBackend.friendlyError(error),
      );
    } finally {
      if (mounted) {
        setState(() => loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final email = ModalRoute.of(context)?.settings.arguments as String?;
    return AuthShell(
      children: [
        const SizedBox(height: 28),
        const HeroArt(kind: HeroKind.verifyEmail),
        const SizedBox(height: 22),
        const ScreenTitle(
          title: 'E-posta kodunu doğrula',
          subtitle:
              'E-posta adresine gönderdiğimiz\n6 haneli doğrulama kodunu gir.',
        ),
        const SizedBox(height: 20),
        SentToEmailBox(icon: Icons.info_outline_rounded, email: email),
        const SizedBox(height: 22),
        const OtpBoxes(active: 0, values: ['|', '-', '-', '-', '-', '-']),
        const SizedBox(height: 20),
        const TimerLine(),
        const SizedBox(height: 8),
        ResendLine(
          label: loading
              ? 'Gönderiliyor...'
              : 'Doğrulama e-postasını tekrar gönder',
          onPressed: email == null || loading ? () {} : () => _resend(email),
        ),
        if (message != null || errorMessage != null) ...[
          const SizedBox(height: 12),
          StatusMessageBox(
            icon: errorMessage == null
                ? Icons.check_circle_outline_rounded
                : Icons.error_outline_rounded,
            text: message ?? errorMessage!,
            isError: errorMessage != null,
          ),
        ],
        const SizedBox(height: 24),
        GradientButton(
          label: 'Doğrula',
          onPressed: () =>
              Navigator.pushNamed(context, EmailVerifiedScreen.route),
        ),
        const SizedBox(height: 16),
        TextLink(
          label: 'E-posta adresini değiştir',
          onPressed: () => Navigator.pushNamed(context, RegisterScreen.route),
        ),
        const SizedBox(height: 34),
        const EcoFooter(),
      ],
    );
  }
}

class EmailVerifiedScreen extends StatelessWidget {
  const EmailVerifiedScreen({super.key});

  static const route = '/email-verified';

  @override
  Widget build(BuildContext context) {
    return AuthShell(
      children: [
        const SizedBox(height: 34),
        const HeroArt(kind: HeroKind.emailVerified),
        const SizedBox(height: 28),
        const ScreenTitle(
          title: 'E-posta doğrulandı',
          subtitle:
              'Tebrikler! Hesabın başarıyla aktifleştirildi.\nArtık CardStation ile öğrenmeye başlayabilirsin.',
        ),
        const SizedBox(height: 30),
        const NextStepCard(
          icon: Icons.school_outlined,
          title: 'Sırada ne var?',
          text: 'İlk desteni oluştur veya\nönerilen kartlarla başla.',
          trailing: Icons.chevron_right_rounded,
        ),
        const SizedBox(height: 28),
        GradientButton(
          label: 'Devam Et',
          onPressed: () => Navigator.pushNamedAndRemoveUntil(
            context,
            LoginScreen.route,
            (_) => false,
          ),
        ),
        const SizedBox(height: 12),
        OutlineCsButton(
          label: 'Giriş Ekranına Dön',
          onPressed: () => Navigator.pushNamedAndRemoveUntil(
            context,
            LoginScreen.route,
            (_) => false,
          ),
        ),
        const SizedBox(height: 36),
        const EcoFooter(),
      ],
    );
  }
}

class EmailTemplateScreen extends StatelessWidget {
  const EmailTemplateScreen({super.key});

  static const route = '/email-template';

  @override
  Widget build(BuildContext context) {
    return AuthShell(
      maxContentWidth: 620,
      children: [
        const SizedBox(height: 58),
        const HeroArt(kind: HeroKind.emailTemplate, large: true),
        const SizedBox(height: 34),
        const ScreenTitle(
          title: 'Doğrulama Kodun',
          subtitle:
              'Merhaba Kemal,\n\nCardStation hesabını doğrulamak için\naşağıdaki 6 haneli kodu gir.',
          richSubtitleWord: 'Kemal,',
        ),
        const SizedBox(height: 24),
        const CodeDigits(digits: ['4', '8', '2', '9', '1', '3']),
        const SizedBox(height: 22),
        const TimerLine(
          text: 'Kodun geçerlilik süresi',
          value: '10 dakikadır.',
        ),
        const SizedBox(height: 24),
        const InfoBox(
          icon: Icons.verified_user_outlined,
          text: 'Bu isteği sen yapmadıysan\nbu e-postayı dikkate alma.',
        ),
        const SizedBox(height: 26),
        GradientButton(
          label: 'Uygulamaya Dön',
          onPressed: () => Navigator.pushNamedAndRemoveUntil(
            context,
            LoginScreen.route,
            (_) => false,
          ),
        ),
        const SizedBox(height: 34),
        const EmailFooter(),
      ],
    );
  }
}

class AuthCallbackScreen extends StatelessWidget {
  const AuthCallbackScreen({super.key});

  static const route = '/auth/callback';

  @override
  Widget build(BuildContext context) {
    return AuthShell(
      children: [
        const SizedBox(height: 34),
        const HeroArt(kind: HeroKind.emailVerified),
        const SizedBox(height: 26),
        const ScreenTitle(
          title: 'CardStation bağlantısı açıldı',
          subtitle:
              'E-posta bağlantın doğrulandıysa oturumun bu uygulamada açılır.',
        ),
        const SizedBox(height: 26),
        GradientButton(
          label: 'Devam Et',
          onPressed: () {
            final route = CardStationAuthBackend.currentUser == null
                ? LoginScreen.route
                : HomeScreen.route;
            Navigator.pushNamedAndRemoveUntil(context, route, (_) => false);
          },
        ),
        const SizedBox(height: 12),
        OutlineCsButton(
          label: 'Yeni şifre oluştur',
          onPressed: () =>
              Navigator.pushNamed(context, NewPasswordScreen.route),
          fontSize: 17,
        ),
        const SizedBox(height: 34),
        const EcoFooter(),
      ],
    );
  }
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  static const route = '/home';

  @override
  Widget build(BuildContext context) {
    final email = CardStationAuthBackend.currentUser?.email ?? 'MedAsi hesabı';
    return AuthShell(
      children: [
        const SizedBox(height: 34),
        const HeroArt(kind: HeroKind.login),
        const SizedBox(height: 26),
        ScreenTitle(
          title: 'CardStation hazır',
          subtitle:
              '$email ile ortak MedAsi hesabına bağlısın.\nQlinik Auth havuzu değişmeden aynı kimlik kullanılır.',
          titleSize: 28,
        ),
        const SizedBox(height: 28),
        const NextStepCard(
          icon: Icons.style_outlined,
          title: 'İlk bağlantı tamam',
          text: 'Sıradaki adım kaynak ekleme ve deste oluşturma akışı.',
        ),
        const SizedBox(height: 28),
        OutlineCsButton(
          label: 'Çıkış Yap',
          onPressed: () async {
            await CardStationAuthBackend.signOut();
            if (!context.mounted) {
              return;
            }
            Navigator.pushNamedAndRemoveUntil(
              context,
              LoginScreen.route,
              (_) => false,
            );
          },
        ),
        const SizedBox(height: 36),
        const EcoFooter(),
      ],
    );
  }
}

class ScreenTitle extends StatelessWidget {
  const ScreenTitle({
    required this.title,
    this.subtitle,
    this.titleSize = 31,
    this.richSubtitleWord,
    super.key,
  });

  final String title;
  final String? subtitle;
  final double titleSize;
  final String? richSubtitleWord;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          title,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: AppColors.navy,
            fontSize: titleSize,
            height: 1.14,
            letterSpacing: 0,
            fontWeight: FontWeight.w800,
          ),
        ),
        if (subtitle != null) ...[const SizedBox(height: 12), _subtitle()],
      ],
    );
  }

  Widget _subtitle() {
    if (richSubtitleWord == null) {
      return Text(
        subtitle!,
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: AppColors.muted,
          fontSize: 18,
          height: 1.35,
          letterSpacing: 0,
          fontWeight: FontWeight.w400,
        ),
      );
    }
    final parts = subtitle!.split(richSubtitleWord!);
    return RichText(
      textAlign: TextAlign.center,
      text: TextSpan(
        style: const TextStyle(
          color: AppColors.muted,
          fontSize: 18,
          height: 1.35,
          letterSpacing: 0,
          fontFamily: 'SF Pro Display',
        ),
        children: [
          TextSpan(text: parts.first),
          TextSpan(
            text: richSubtitleWord,
            style: const TextStyle(
              color: AppColors.blue,
              fontWeight: FontWeight.w800,
            ),
          ),
          if (parts.length > 1) TextSpan(text: parts.last),
        ],
      ),
    );
  }
}

class FormPanel extends StatelessWidget {
  const FormPanel({required this.children, super.key});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 20, 18, 18),
      decoration: BoxDecoration(
        color: AppColors.panel,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF2154A8).withValues(alpha: .08),
            blurRadius: 30,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }
}

class FieldLabel extends StatelessWidget {
  const FieldLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 2, bottom: 8),
      child: Text(
        text,
        style: const TextStyle(
          color: AppColors.navy,
          fontSize: 16,
          fontWeight: FontWeight.w800,
          letterSpacing: 0,
        ),
      ),
    );
  }
}

class CsTextField extends StatelessWidget {
  const CsTextField({
    required this.icon,
    required this.hint,
    this.controller,
    this.trailing,
    this.obscureText = false,
    this.keyboardType,
    this.autofillHints,
    this.textInputAction,
    this.onSubmitted,
    super.key,
  });

  final IconData icon;
  final String hint;
  final TextEditingController? controller;
  final Widget? trailing;
  final bool obscureText;
  final TextInputType? keyboardType;
  final Iterable<String>? autofillHints;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onSubmitted;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 54,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.line, width: 1),
      ),
      child: Row(
        children: [
          const SizedBox(width: 15),
          Icon(icon, size: 22, color: AppColors.muted),
          const SizedBox(width: 14),
          Expanded(
            child: TextField(
              controller: controller,
              obscureText: obscureText,
              keyboardType: keyboardType,
              autofillHints: autofillHints,
              textInputAction: textInputAction,
              onSubmitted: onSubmitted,
              cursorColor: AppColors.blue,
              decoration: InputDecoration(
                isDense: true,
                border: InputBorder.none,
                hintText: hint,
                hintStyle: const TextStyle(
                  color: Color(0xFF7A89A8),
                  fontSize: 17,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0,
                ),
              ),
              style: const TextStyle(
                color: AppColors.navy,
                fontSize: 17,
                fontWeight: FontWeight.w600,
                letterSpacing: 0,
              ),
            ),
          ),
          if (trailing != null)
            IconTheme(
              data: const IconThemeData(color: AppColors.muted, size: 22),
              child: trailing!,
            ),
          const SizedBox(width: 8),
        ],
      ),
    );
  }
}

class GradientButton extends StatelessWidget {
  const GradientButton({
    required this.label,
    required this.onPressed,
    this.height = 58,
    super.key,
  });

  final String label;
  final VoidCallback onPressed;
  final double height;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: height,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: AppGradients.primary,
          borderRadius: BorderRadius.circular(10),
          boxShadow: [
            BoxShadow(
              color: AppColors.blue.withValues(alpha: .22),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: ElevatedButton(
          onPressed: onPressed,
          style: ElevatedButton.styleFrom(
            elevation: 0,
            shadowColor: Colors.transparent,
            backgroundColor: Colors.transparent,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            textStyle: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              letterSpacing: 0,
            ),
          ),
          child: Text(label),
        ),
      ),
    );
  }
}

class OutlineCsButton extends StatelessWidget {
  const OutlineCsButton({
    required this.label,
    required this.onPressed,
    this.fontSize = 20,
    super.key,
  });

  final String label;
  final VoidCallback onPressed;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.blue,
          side: const BorderSide(color: AppColors.blue, width: 1.2),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          textStyle: TextStyle(
            fontSize: fontSize,
            fontWeight: FontWeight.w800,
            letterSpacing: 0,
          ),
        ),
        child: Text(label),
      ),
    );
  }
}

class TextLink extends StatelessWidget {
  const TextLink({required this.label, required this.onPressed, super.key});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: TextButton(
        onPressed: onPressed,
        style: TextButton.styleFrom(
          foregroundColor: AppColors.blue,
          textStyle: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            letterSpacing: 0,
          ),
        ),
        child: Text(label),
      ),
    );
  }
}

class CsCheckbox extends StatelessWidget {
  const CsCheckbox({required this.value, required this.onTap, super.key});

  final bool value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        width: 22,
        height: 22,
        decoration: BoxDecoration(
          color: value ? AppColors.blue : Colors.white,
          borderRadius: BorderRadius.circular(5),
          border: Border.all(color: AppColors.blue, width: 1.2),
        ),
        child: value
            ? const Icon(Icons.check_rounded, size: 17, color: Colors.white)
            : null,
      ),
    );
  }
}

class InfoBox extends StatelessWidget {
  const InfoBox({required this.icon, required this.text, super.key});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.softBlue.withValues(alpha: .72),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            color: Color.lerp(AppColors.blue, AppColors.muted, .25),
            size: 34,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: AppColors.muted,
                fontSize: 16.5,
                height: 1.32,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class StatusMessageBox extends StatelessWidget {
  const StatusMessageBox({
    required this.icon,
    required this.text,
    this.isError = false,
    super.key,
  });

  final IconData icon;
  final String text;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    final color = isError ? const Color(0xFFC33B4A) : AppColors.blue;
    final background = isError
        ? const Color(0xFFFFF1F3)
        : AppColors.softBlue.withValues(alpha: .72);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: isError ? color : AppColors.muted,
                fontSize: 14.5,
                height: 1.25,
                fontWeight: isError ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class SentToEmailBox extends StatelessWidget {
  const SentToEmailBox({required this.icon, this.email, super.key});

  final IconData icon;
  final String? email;

  @override
  Widget build(BuildContext context) {
    final visibleEmail = email?.isNotEmpty == true ? email! : 'e-posta adresin';
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .92),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF2B5699).withValues(alpha: .05),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: AppColors.softBlue,
            child: Icon(icon, color: AppColors.muted, size: 23),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: const TextStyle(
                  color: AppColors.muted,
                  fontSize: 15.8,
                  height: 1.25,
                  fontFamily: 'SF Pro Display',
                ),
                children: [
                  const TextSpan(text: 'E-posta şu adrese gönderildi: '),
                  TextSpan(
                    text: visibleEmail,
                    style: const TextStyle(
                      color: AppColors.blue,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class OtpBoxes extends StatelessWidget {
  const OtpBoxes({required this.values, this.active = 0, super.key});

  final List<String> values;
  final int active;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: List.generate(values.length, (index) {
        final isActive = index == active;
        return Container(
          width: 52,
          height: 60,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isActive ? AppColors.blue : AppColors.line,
              width: isActive ? 1.4 : 1,
            ),
            boxShadow: isActive
                ? [
                    BoxShadow(
                      color: AppColors.blue.withValues(alpha: .12),
                      blurRadius: 14,
                      offset: const Offset(0, 8),
                    ),
                  ]
                : null,
          ),
          child: Text(
            values[index],
            style: TextStyle(
              color: isActive ? AppColors.blue : AppColors.muted,
              fontSize: values[index] == '|' ? 30 : 24,
              fontWeight: FontWeight.w600,
            ),
          ),
        );
      }),
    );
  }
}

class CodeDigits extends StatelessWidget {
  const CodeDigits({required this.digits, super.key});

  final List<String> digits;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (final digit in digits) ...[
          Container(
            width: 58,
            height: 66,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF2154A8).withValues(alpha: .15),
                  blurRadius: 14,
                  offset: const Offset(0, 7),
                ),
              ],
            ),
            child: Text(
              digit,
              style: const TextStyle(
                color: AppColors.blue,
                fontSize: 34,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          if (digit != digits.last) const SizedBox(width: 9),
        ],
      ],
    );
  }
}

class TimerLine extends StatelessWidget {
  const TimerLine({
    this.text = 'Kodun geçerlilik süresi:',
    this.value = '10:00',
    super.key,
  });

  final String text;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.schedule_rounded, color: AppColors.muted, size: 22),
        const SizedBox(width: 8),
        Text(
          text,
          style: const TextStyle(color: AppColors.muted, fontSize: 16),
        ),
        const SizedBox(width: 4),
        Text(
          value,
          style: const TextStyle(
            color: AppColors.blue,
            fontSize: 16,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

class ResendLine extends StatelessWidget {
  const ResendLine({
    required this.onPressed,
    this.label = 'Kodu tekrar gönder (00:45)',
    super.key,
  });

  final VoidCallback onPressed;
  final String label;

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      onPressed: onPressed,
      style: TextButton.styleFrom(foregroundColor: AppColors.blue),
      icon: const Icon(Icons.refresh_rounded, size: 22),
      label: Text(
        label,
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      ),
    );
  }
}

class RequirementBox extends StatelessWidget {
  const RequirementBox({super.key});

  @override
  Widget build(BuildContext context) {
    const items = ['En az 8 karakter', 'Bir büyük harf', 'Bir rakam'];
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      decoration: BoxDecoration(
        color: const Color(0xFFF4F9FF),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final item in items) ...[
            Row(
              children: [
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.blue, width: 1.4),
                  ),
                  child: const Icon(
                    Icons.check_rounded,
                    size: 17,
                    color: AppColors.blue,
                  ),
                ),
                const SizedBox(width: 14),
                Text(
                  item,
                  style: const TextStyle(color: AppColors.navy, fontSize: 16.5),
                ),
              ],
            ),
            if (item != items.last) const SizedBox(height: 13),
          ],
        ],
      ),
    );
  }
}

class NextStepCard extends StatelessWidget {
  const NextStepCard({
    required this.icon,
    required this.title,
    required this.text,
    this.trailing,
    super.key,
  });

  final IconData icon;
  final String title;
  final String text;
  final IconData? trailing;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 14),
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1C3E78).withValues(alpha: .07),
            blurRadius: 28,
            offset: const Offset(0, 13),
          ),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 35,
            backgroundColor: AppColors.softBlue,
            child: Icon(icon, size: 36, color: AppColors.blue),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: AppColors.navy,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  text,
                  style: const TextStyle(
                    color: AppColors.muted,
                    fontSize: 17,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
          if (trailing != null) Icon(trailing, color: AppColors.blue, size: 32),
        ],
      ),
    );
  }
}

class EcoFooter extends StatelessWidget {
  const EcoFooter({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Expanded(child: Divider(color: Color(0xFFD9E4F2), endIndent: 18)),
        const Icon(
          Icons.verified_user_outlined,
          color: AppColors.blue,
          size: 23,
        ),
        const SizedBox(width: 10),
        const Flexible(
          child: Text(
            'MedAsi ekosisteminin bir parçası',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.muted, fontSize: 15.5),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const Expanded(child: Divider(color: Color(0xFFD9E4F2), indent: 18)),
      ],
    );
  }
}

class EmailFooter extends StatelessWidget {
  const EmailFooter({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            const Expanded(
              child: Divider(color: Color(0xFFD9E4F2), endIndent: 22),
            ),
            const SizedBox(
              width: 40,
              height: 34,
              child: CustomPaint(painter: LogoMarkPainter(compact: true)),
            ),
            const Expanded(
              child: Divider(color: Color(0xFFD9E4F2), indent: 22),
            ),
          ],
        ),
        const SizedBox(height: 18),
        const Text(
          'Akıllı tekrar sistemi ve yapay zeka destekli kartlarla\nbilgini kalıcı hale getir.',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppColors.muted, height: 1.4, fontSize: 14),
        ),
        const SizedBox(height: 18),
        const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.language_rounded, color: AppColors.blue, size: 22),
            SizedBox(width: 24),
            Icon(Icons.camera_alt_outlined, color: AppColors.blue, size: 22),
            SizedBox(width: 24),
            Icon(
              Icons.business_center_outlined,
              color: AppColors.blue,
              size: 22,
            ),
          ],
        ),
        const SizedBox(height: 20),
        RichText(
          text: const TextSpan(
            style: TextStyle(
              color: AppColors.muted,
              fontSize: 13.5,
              fontFamily: 'SF Pro Display',
            ),
            children: [
              TextSpan(text: '© 2024 '),
              TextSpan(
                text: 'CardStation.',
                style: TextStyle(
                  color: AppColors.blue,
                  fontWeight: FontWeight.w800,
                ),
              ),
              TextSpan(text: '  Tüm hakları saklıdır.'),
            ],
          ),
        ),
      ],
    );
  }
}

class HeroArt extends StatelessWidget {
  const HeroArt({required this.kind, this.large = false, super.key});

  final HeroKind kind;
  final bool large;

  @override
  Widget build(BuildContext context) {
    final size = large ? const Size(300, 220) : const Size(286, 210);
    return SizedBox(
      width: size.width,
      height: size.height,
      child: CustomPaint(painter: HeroArtPainter(kind)),
    );
  }
}

class BackgroundPatternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final linePaint = Paint()
      ..color = const Color(0xFFB7D5FA).withValues(alpha: .65)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    final dotPaint = Paint()
      ..color = const Color(0xFF88BDF6).withValues(alpha: .36);

    final leftPath = Path()
      ..moveTo(0, size.height * .42)
      ..cubicTo(
        size.width * .15,
        size.height * .36,
        size.width * .1,
        size.height * .23,
        size.width * .34,
        size.height * .20,
      )
      ..cubicTo(
        size.width * .48,
        size.height * .18,
        size.width * .44,
        size.height * .08,
        size.width * .64,
        size.height * .10,
      );
    canvas.drawPath(leftPath, linePaint);

    final rightPath = Path()
      ..moveTo(size.width, size.height * .09)
      ..cubicTo(
        size.width * .86,
        size.height * .12,
        size.width * .86,
        size.height * .24,
        size.width * .82,
        size.height * .33,
      )
      ..cubicTo(
        size.width * .76,
        size.height * .48,
        size.width * .95,
        size.height * .55,
        size.width,
        size.height * .64,
      );
    canvas.drawPath(rightPath, linePaint);

    void dots(double x, double y) {
      for (var row = 0; row < 8; row++) {
        for (var col = 0; col < 6; col++) {
          canvas.drawCircle(Offset(x + col * 12, y + row * 12), 1.6, dotPaint);
        }
      }
    }

    dots(18, size.height * .17);
    dots(size.width - 92, size.height * .18);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class LogoMarkPainter extends CustomPainter {
  const LogoMarkPainter({this.compact = false});

  final bool compact;

  @override
  void paint(Canvas canvas, Size size) {
    final scale = math.min(size.width / 66, size.height / 54);
    canvas.save();
    canvas.scale(scale);
    canvas.translate(
      (size.width / scale - 66) / 2,
      (size.height / scale - 54) / 2,
    );

    final shadow = Paint()
      ..color = Colors.black.withValues(alpha: .08)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
    final cyan = Paint()
      ..shader = const LinearGradient(
        colors: [Color(0xFF11D2D4), Color(0xFF1481F5)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ).createShader(const Rect.fromLTWH(0, 0, 66, 54));
    final blue = Paint()
      ..shader = AppGradients.mark.createShader(
        const Rect.fromLTWH(0, 0, 66, 54),
      );

    RRect card(double x, double y, double w, double h, double r) =>
        RRect.fromRectAndRadius(Rect.fromLTWH(x, y, w, h), Radius.circular(r));

    canvas.drawRRect(card(4, 12, 35, 36, 9), cyan);
    canvas.drawRRect(card(14, 7, 36, 40, 9), cyan);
    canvas.drawRRect(card(25, 2, 38, 46, 10).shift(const Offset(1, 3)), shadow);
    canvas.drawRRect(card(25, 2, 38, 46, 10), blue);

    final white = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = compact ? 2 : 2.3
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final brain = Path()
      ..moveTo(43, 17)
      ..cubicTo(38, 14, 34, 17, 34, 22)
      ..cubicTo(30, 24, 31, 30, 36, 31)
      ..cubicTo(37, 35, 42, 35, 44, 32)
      ..cubicTo(49, 33, 54, 30, 53, 25)
      ..cubicTo(57, 20, 51, 14, 47, 17)
      ..cubicTo(46, 15, 44, 15, 43, 17);
    canvas.drawPath(brain, white);
    canvas.drawLine(const Offset(38, 37), const Offset(52, 37), white);
    canvas.drawLine(const Offset(36, 42), const Offset(48, 42), white);
    canvas.drawLine(const Offset(35, 47), const Offset(43, 47), white);

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant LogoMarkPainter oldDelegate) =>
      oldDelegate.compact != compact;
}

class HeroArtPainter extends CustomPainter {
  HeroArtPainter(this.kind);

  final HeroKind kind;

  @override
  void paint(Canvas canvas, Size size) {
    final s = math.min(size.width / 300, size.height / 220);
    canvas.save();
    canvas.scale(s);
    canvas.translate((size.width / s - 300) / 2, (size.height / s - 220) / 2);

    _softBlob(canvas, const Offset(150, 122), 93);
    switch (kind) {
      case HeroKind.login:
        _cardStack(canvas, const Offset(150, 82), true);
      case HeroKind.register:
        _cardStack(canvas, const Offset(150, 72), false, withBadge: true);
      case HeroKind.forgot:
        _envelope(canvas, const Offset(150, 99), lock: true, cardBehind: true);
      case HeroKind.resetCode:
        _envelope(canvas, const Offset(150, 98), lock: true, code: true);
      case HeroKind.verifyEmail:
        _envelope(canvas, const Offset(150, 98), shield: true, sideCards: true);
      case HeroKind.emailVerified:
        _envelope(
          canvas,
          const Offset(150, 98),
          checkCard: true,
          aiTiles: true,
        );
      case HeroKind.newPassword:
        _shield(canvas, const Offset(150, 96), lock: true, sideCards: true);
      case HeroKind.passwordUpdated:
        _shield(
          canvas,
          const Offset(150, 96),
          lock: true,
          sideCards: true,
          checkBadge: true,
        );
      case HeroKind.emailTemplate:
        _envelope(
          canvas,
          const Offset(150, 98),
          shield: true,
          checkBadge: true,
        );
    }
    _floatingDots(canvas);
    canvas.restore();
  }

  void _softBlob(Canvas canvas, Offset center, double radius) {
    final paint = Paint()
      ..color = const Color(0xFFDBECFF).withValues(alpha: .62)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1);
    canvas.drawCircle(center, radius, paint);
  }

  void _cardStack(
    Canvas canvas,
    Offset center,
    bool answer, {
    bool withBadge = false,
  }) {
    final shadow = Paint()
      ..color = const Color(0xFF2350A7).withValues(alpha: .14)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14);
    final blue = Paint()
      ..shader = AppGradients.mark.createShader(
        Rect.fromCircle(center: center, radius: 95),
      );
    final cyan = Paint()..color = AppColors.cyan;
    final white = Paint()..color = Colors.white;

    for (var i = 2; i >= 0; i--) {
      final rect = Rect.fromCenter(
        center: center + Offset(i * 11.0, i * -3.0 + 22),
        width: 150,
        height: 92,
      );
      canvas.save();
      canvas.translate(rect.center.dx, rect.center.dy);
      canvas.rotate((-9 + i * 7) * math.pi / 180);
      final r = RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset.zero,
          width: rect.width,
          height: rect.height,
        ),
        const Radius.circular(16),
      );
      canvas.drawRRect(r.shift(const Offset(0, 10)), shadow);
      canvas.drawRRect(r, i == 0 ? white : (i == 1 ? cyan : blue));
      if (i == 0) {
        _textLine(
          canvas,
          const Offset(-48, -26),
          answer ? 'Farmakoloji' : 'Tıp Fakültesi',
          11,
          AppColors.blue,
          true,
        );
        _textLine(
          canvas,
          const Offset(-48, -4),
          'ACE inhibitörlerinin',
          10,
          AppColors.navy,
          false,
        );
        _textLine(
          canvas,
          const Offset(-48, 12),
          'başlıca etkisi nedir?',
          10,
          AppColors.navy,
          false,
        );
        if (answer) {
          _textLine(
            canvas,
            const Offset(-48, 33),
            'Cevap: Vazodilatasyon',
            9,
            AppColors.cyan,
            true,
          );
        }
      }
      canvas.restore();
    }
    _aiBadge(canvas, center + const Offset(88, 48));
    if (withBadge) _tinyTile(canvas, center + const Offset(-96, 52), 'AI');
  }

  void _envelope(
    Canvas canvas,
    Offset center, {
    bool lock = false,
    bool code = false,
    bool shield = false,
    bool sideCards = false,
    bool checkCard = false,
    bool aiTiles = false,
    bool cardBehind = false,
    bool checkBadge = false,
  }) {
    final shadow = Paint()
      ..color = const Color(0xFF2A5CB3).withValues(alpha: .16)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 18);
    final white = Paint()..color = Colors.white;
    final flap = Paint()..color = const Color(0xFFF2F8FF);
    final blue = Paint()
      ..shader = AppGradients.mark.createShader(
        Rect.fromCenter(center: center, width: 160, height: 130),
      );
    final border = Paint()
      ..color = const Color(0xFFD1DEF0)
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    if (cardBehind || sideCards) {
      _smallSubjectCard(canvas, center + const Offset(-84, 18), 'Fizik');
      _smallSubjectCard(
        canvas,
        center + const Offset(90, 12),
        'ACE inhibitörleri',
      );
    }
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: center + const Offset(0, 24),
          width: 150,
          height: 95,
        ),
        const Radius.circular(16),
      ).shift(const Offset(0, 12)),
      shadow,
    );
    if (checkCard || shield || lock) {
      final topRect = Rect.fromCenter(
        center: center + const Offset(0, -8),
        width: 110,
        height: 112,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(topRect, const Radius.circular(16)),
        white,
      );
      if (shield) {
        _shieldShape(canvas, topRect.center, 34, blue, check: true);
      }
      if (lock) {
        _lock(canvas, topRect.center + const Offset(0, -10), blue: true);
        if (code) {
          _textLine(
            canvas,
            topRect.center + const Offset(-22, 22),
            '*****',
            22,
            AppColors.muted,
            true,
          );
        }
      }
      if (checkCard) _bigCheck(canvas, topRect.center, 40);
    }

    final body = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: center + const Offset(0, 34),
        width: 176,
        height: 92,
      ),
      const Radius.circular(14),
    );
    canvas.drawRRect(body, white);
    final p1 = Path()
      ..moveTo(body.left, body.top + 8)
      ..lineTo(center.dx, body.center.dy + 28)
      ..lineTo(body.right, body.top + 8);
    canvas.drawPath(p1, flap);
    canvas.drawRRect(body, border);
    final p2 = Path()
      ..moveTo(body.left + 4, body.bottom - 4)
      ..lineTo(center.dx, body.center.dy + 24)
      ..lineTo(body.right - 4, body.bottom - 4);
    canvas.drawPath(p2, border);

    if (aiTiles) {
      _tinyTile(canvas, center + const Offset(-102, 16), 'AI');
      _tinyTile(canvas, center + const Offset(104, 16), '◎');
    }
    if (checkBadge) {
      _checkBadge(canvas, center + const Offset(86, 40));
    } else {
      _aiBadge(canvas, center + const Offset(92, 50));
    }
  }

  void _shield(
    Canvas canvas,
    Offset center, {
    bool lock = false,
    bool sideCards = false,
    bool checkBadge = false,
  }) {
    if (sideCards) {
      _smallSubjectCard(canvas, center + const Offset(-86, 35), 'Farmakoloji');
      _smallSubjectCard(canvas, center + const Offset(88, 35), 'Mikrobiyoloji');
    }
    final shadow = Paint()
      ..color = AppColors.blue.withValues(alpha: .18)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 16);
    final blue = Paint()
      ..shader = AppGradients.mark.createShader(
        Rect.fromCircle(center: center, radius: 70),
      );
    _shieldShape(
      canvas,
      center + const Offset(0, 12),
      74,
      shadow,
      shadowOffset: const Offset(0, 10),
    );
    _shieldShape(canvas, center + const Offset(0, 12), 74, blue, lock: lock);
    if (checkBadge) _checkBadge(canvas, center + const Offset(78, 60));
  }

  void _smallSubjectCard(Canvas canvas, Offset center, String title) {
    final paint = Paint()..color = Colors.white.withValues(alpha: .88);
    final border = Paint()
      ..color = AppColors.line
      ..style = PaintingStyle.stroke;
    final rect = Rect.fromCenter(center: center, width: 76, height: 72);
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate((center.dx < 150 ? -10 : 10) * math.pi / 180);
    final r = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset.zero,
        width: rect.width,
        height: rect.height,
      ),
      const Radius.circular(12),
    );
    canvas.drawRRect(r, paint);
    canvas.drawRRect(r, border);
    _textLine(canvas, const Offset(-27, -22), title, 9.5, AppColors.blue, true);
    _textLine(canvas, const Offset(-27, -2), '────', 10, AppColors.line, false);
    _textLine(canvas, const Offset(-27, 12), '────', 10, AppColors.line, false);
    canvas.restore();
  }

  void _shieldShape(
    Canvas canvas,
    Offset center,
    double radius,
    Paint paint, {
    bool lock = false,
    bool check = false,
    Offset shadowOffset = Offset.zero,
  }) {
    final path = Path()
      ..moveTo(center.dx, center.dy - radius + shadowOffset.dy)
      ..cubicTo(
        center.dx - radius * .46,
        center.dy - radius * .55 + shadowOffset.dy,
        center.dx - radius * .82,
        center.dy - radius * .54 + shadowOffset.dy,
        center.dx - radius * .82,
        center.dy - radius * .13 + shadowOffset.dy,
      )
      ..cubicTo(
        center.dx - radius * .78,
        center.dy + radius * .50 + shadowOffset.dy,
        center.dx - radius * .38,
        center.dy + radius * .73 + shadowOffset.dy,
        center.dx,
        center.dy + radius + shadowOffset.dy,
      )
      ..cubicTo(
        center.dx + radius * .38,
        center.dy + radius * .73 + shadowOffset.dy,
        center.dx + radius * .78,
        center.dy + radius * .50 + shadowOffset.dy,
        center.dx + radius * .82,
        center.dy - radius * .13 + shadowOffset.dy,
      )
      ..cubicTo(
        center.dx + radius * .82,
        center.dy - radius * .54 + shadowOffset.dy,
        center.dx + radius * .46,
        center.dy - radius * .55 + shadowOffset.dy,
        center.dx,
        center.dy - radius + shadowOffset.dy,
      )
      ..close();
    canvas.drawPath(path, paint);
    if (lock) _lock(canvas, center + const Offset(0, 3));
    if (check) _check(canvas, center + const Offset(0, 2), 30, Colors.white);
  }

  void _lock(Canvas canvas, Offset center, {bool blue = false}) {
    final color = blue ? AppColors.blue : Colors.white;
    final p = Paint()
      ..color = color
      ..strokeWidth = 7
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(
      Rect.fromCenter(
        center: center + const Offset(0, -15),
        width: 42,
        height: 48,
      ),
      math.pi,
      math.pi,
      false,
      p,
    );
    final body = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: center + const Offset(0, 10),
        width: 58,
        height: 48,
      ),
      const Radius.circular(10),
    );
    canvas.drawRRect(body, Paint()..color = color);
    _check(
      canvas,
      center + const Offset(0, 10),
      25,
      blue ? Colors.white : AppColors.blue,
    );
  }

  void _bigCheck(Canvas canvas, Offset center, double radius) {
    canvas.drawCircle(center, radius, Paint()..color = Colors.white);
    _check(canvas, center, radius * .68, AppColors.cyan);
  }

  void _checkBadge(Canvas canvas, Offset center) {
    final p = Paint()
      ..shader = AppGradients.mark.createShader(
        Rect.fromCircle(center: center, radius: 42),
      );
    canvas.drawCircle(
      center,
      42,
      Paint()..color = Colors.white.withValues(alpha: .72),
    );
    canvas.drawCircle(center, 32, p);
    _check(canvas, center, 27, Colors.white);
  }

  void _aiBadge(Canvas canvas, Offset center) {
    final p = Paint()
      ..shader = AppGradients.mark.createShader(
        Rect.fromCircle(center: center, radius: 42),
      );
    canvas.drawCircle(
      center,
      42,
      Paint()..color = Colors.white.withValues(alpha: .8),
    );
    canvas.drawCircle(center, 32, p);
    final white = Paint()
      ..color = Colors.white
      ..strokeWidth = 2.3
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    canvas.drawCircle(center, 14, white);
    canvas.drawLine(
      center + const Offset(-9, 2),
      center + const Offset(9, 2),
      white,
    );
    canvas.drawLine(
      center + const Offset(0, -11),
      center + const Offset(0, 11),
      white,
    );
  }

  void _tinyTile(Canvas canvas, Offset center, String label) {
    final rect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: center, width: 54, height: 48),
      const Radius.circular(10),
    );
    canvas.drawRRect(
      rect,
      Paint()..color = Colors.white.withValues(alpha: .92),
    );
    canvas.drawRRect(
      rect,
      Paint()
        ..style = PaintingStyle.stroke
        ..color = AppColors.line,
    );
    _textLine(
      canvas,
      center + const Offset(-16, 7),
      label,
      21,
      AppColors.blue,
      true,
    );
  }

  void _check(Canvas canvas, Offset center, double size, Color color) {
    final p = Paint()
      ..color = color
      ..strokeWidth = size * .15
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;
    final path = Path()
      ..moveTo(center.dx - size * .45, center.dy)
      ..lineTo(center.dx - size * .12, center.dy + size * .32)
      ..lineTo(center.dx + size * .46, center.dy - size * .38);
    canvas.drawPath(path, p);
  }

  void _textLine(
    Canvas canvas,
    Offset offset,
    String text,
    double size,
    Color color,
    bool bold,
  ) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: color,
          fontSize: size,
          fontWeight: bold ? FontWeight.w800 : FontWeight.w500,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(canvas, offset);
  }

  void _floatingDots(Canvas canvas) {
    final p = Paint()..color = const Color(0xFF3BA6F6).withValues(alpha: .75);
    for (final o in const [
      Offset(38, 108),
      Offset(256, 92),
      Offset(238, 62),
      Offset(50, 138),
      Offset(222, 136),
    ]) {
      canvas.drawCircle(o, 3, p);
    }
    _spark(canvas, const Offset(58, 82), 12);
    _spark(canvas, const Offset(236, 82), 9);
  }

  void _spark(Canvas canvas, Offset c, double r) {
    final p = Paint()..color = const Color(0xFF4D9CF4).withValues(alpha: .7);
    final path = Path()
      ..moveTo(c.dx, c.dy - r)
      ..lineTo(c.dx + r * .24, c.dy - r * .24)
      ..lineTo(c.dx + r, c.dy)
      ..lineTo(c.dx + r * .24, c.dy + r * .24)
      ..lineTo(c.dx, c.dy + r)
      ..lineTo(c.dx - r * .24, c.dy + r * .24)
      ..lineTo(c.dx - r, c.dy)
      ..lineTo(c.dx - r * .24, c.dy - r * .24)
      ..close();
    canvas.drawPath(path, p);
  }

  @override
  bool shouldRepaint(covariant HeroArtPainter oldDelegate) =>
      oldDelegate.kind != kind;
}
