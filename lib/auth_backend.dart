import 'package:supabase_flutter/supabase_flutter.dart';

class CardStationAuthConfig {
  static const appCode = 'cardstation';
  static const supabaseUrl = String.fromEnvironment('CARDSTATION_SUPABASE_URL');
  static const supabaseAnonKey = String.fromEnvironment(
    'CARDSTATION_SUPABASE_ANON_KEY',
  );
  static const publicUrl = String.fromEnvironment(
    'CARDSTATION_PUBLIC_URL',
    defaultValue: 'http://localhost:8088',
  );

  static bool get isConfigured =>
      supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;

  static String get authRedirectTo {
    final normalized = publicUrl.endsWith('/')
        ? publicUrl.substring(0, publicUrl.length - 1)
        : publicUrl;
    return '$normalized/auth/callback';
  }
}

class AuthActionResult {
  const AuthActionResult.success(this.message) : error = null;
  const AuthActionResult.failure(this.error) : message = null;

  final String? message;
  final String? error;

  bool get ok => error == null;
}

class CardStationAuthBackend {
  static bool _initialized = false;

  static bool get isConfigured => CardStationAuthConfig.isConfigured;
  static bool get isInitialized => _initialized;

  static SupabaseClient? get client {
    if (!_initialized) {
      return null;
    }
    return Supabase.instance.client;
  }

  static User? get currentUser => client?.auth.currentUser;

  static Future<void> initialize() async {
    if (!isConfigured || _initialized) {
      return;
    }

    await Supabase.initialize(
      url: CardStationAuthConfig.supabaseUrl,
      anonKey: CardStationAuthConfig.supabaseAnonKey,
      authOptions: const FlutterAuthClientOptions(
        authFlowType: AuthFlowType.pkce,
      ),
    );
    _initialized = true;
  }

  static Future<AuthActionResult> signIn({
    required String email,
    required String password,
  }) async {
    final auth = _authOrThrow();
    await auth.signInWithPassword(email: email.trim(), password: password);
    return const AuthActionResult.success('Giriş başarılı.');
  }

  static Future<AuthActionResult> signUp({
    required String fullName,
    required String email,
    required String password,
  }) async {
    final auth = _authOrThrow();
    await auth.signUp(
      email: email.trim(),
      password: password,
      emailRedirectTo: CardStationAuthConfig.authRedirectTo,
      data: {
        'app_code': CardStationAuthConfig.appCode,
        'display_name': fullName.trim(),
        'signup_source': CardStationAuthConfig.appCode,
        'ecosystem': 'medasi',
      },
    );
    return const AuthActionResult.success(
      'Doğrulama e-postası CardStation bağlantısıyla gönderildi.',
    );
  }

  static Future<AuthActionResult> resendSignupEmail(String email) async {
    final auth = _authOrThrow();
    await auth.resend(
      email: email.trim(),
      type: OtpType.signup,
      emailRedirectTo: CardStationAuthConfig.authRedirectTo,
    );
    return const AuthActionResult.success(
      'Doğrulama e-postası yeniden gönderildi.',
    );
  }

  static Future<AuthActionResult> sendPasswordReset(String email) async {
    final auth = _authOrThrow();
    await auth.resetPasswordForEmail(
      email.trim(),
      redirectTo: CardStationAuthConfig.authRedirectTo,
    );
    return const AuthActionResult.success(
      'Şifre sıfırlama e-postası CardStation bağlantısıyla gönderildi.',
    );
  }

  static Future<AuthActionResult> updatePassword(String password) async {
    final auth = _authOrThrow();
    await auth.updateUser(UserAttributes(password: password));
    return const AuthActionResult.success('Şifren güncellendi.');
  }

  static Future<void> signOut() async {
    final auth = client?.auth;
    if (auth == null) {
      return;
    }
    await auth.signOut();
  }

  static GoTrueClient _authOrThrow() {
    final auth = client?.auth;
    if (auth == null) {
      throw const AuthException(
        'CardStation Supabase bağlantısı yapılandırılmamış.',
      );
    }
    return auth;
  }

  static String friendlyError(Object error) {
    if (error is AuthException) {
      return error.message;
    }
    return 'İşlem tamamlanamadı. Lütfen bilgileri kontrol edip tekrar dene.';
  }
}
