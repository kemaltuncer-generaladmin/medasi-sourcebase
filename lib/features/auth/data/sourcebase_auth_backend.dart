import 'package:supabase_flutter/supabase_flutter.dart';

class SourceBaseAuthConfig {
  const SourceBaseAuthConfig._();

  static const appCode = 'sourcebase';
  static const supabaseUrl = String.fromEnvironment('SOURCEBASE_SUPABASE_URL');
  static const _supabaseAnonKey = String.fromEnvironment(
    'SOURCEBASE_SUPABASE_ANON_KEY',
  );
  static const _supabasePublicToken = String.fromEnvironment(
    'SOURCEBASE_SUPABASE_PUBLIC_TOKEN',
  );
  static const publicUrl = String.fromEnvironment(
    'SOURCEBASE_PUBLIC_URL',
    defaultValue: 'http://localhost:8088',
  );

  static String get supabaseAnonKey =>
      _supabaseAnonKey.isNotEmpty ? _supabaseAnonKey : _supabasePublicToken;

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

class AuthCallbackResult {
  const AuthCallbackResult({this.redirectType});

  final String? redirectType;

  bool get isPasswordRecovery =>
      redirectType == 'recovery' || redirectType == 'passwordRecovery';
}

class SourceBaseProfile {
  const SourceBaseProfile({required this.faculty, required this.department});

  final String faculty;
  final String department;

  Map<String, dynamic> toMetadata() {
    return {
      'sourcebase_faculty': faculty.trim(),
      'sourcebase_department': department.trim(),
      'sourcebase_profile_completed': true,
      'sourcebase_profile_completed_at': DateTime.now().toIso8601String(),
    };
  }
}

class SourceBaseAuthBackend {
  const SourceBaseAuthBackend._();

  static bool _initialized = false;
  static String? _initializationError;

  static bool get isConfigured => SourceBaseAuthConfig.isConfigured;
  static bool get isInitialized => _initialized;
  static String? get initializationError => _initializationError;

  static SupabaseClient? get client {
    if (!_initialized) {
      return null;
    }
    return Supabase.instance.client;
  }

  static User? get currentUser => client?.auth.currentUser;

  static bool get currentUserNeedsSourceBaseProfile =>
      userNeedsSourceBaseProfile(currentUser);

  static bool get currentUserHasVerifiedEmail {
    final user = currentUser;
    if (user == null) {
      return false;
    }
    return user.emailConfirmedAt != null;
  }

  static bool userNeedsSourceBaseProfile(User? user) {
    if (user == null) {
      return false;
    }
    final metadata = user.userMetadata ?? {};
    final faculty = metadata['sourcebase_faculty']?.toString().trim() ?? '';
    final department =
        metadata['sourcebase_department']?.toString().trim() ?? '';
    return faculty.isEmpty || department.isEmpty;
  }

  static Future<void> initialize() async {
    if (!isConfigured || _initialized) {
      return;
    }

    try {
      await Supabase.initialize(
        url: SourceBaseAuthConfig.supabaseUrl,
        anonKey: SourceBaseAuthConfig.supabaseAnonKey,
        authOptions: const FlutterAuthClientOptions(
          authFlowType: AuthFlowType.pkce,
        ),
      );
      _initialized = true;
      _initializationError = null;
    } catch (_) {
      _initialized = false;
      _initializationError =
          'Kimlik doğrulama yapılandırması başlatılamadı. Lütfen daha sonra tekrar dene.';
    }
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
    SourceBaseProfile? profile,
  }) async {
    final auth = _authOrThrow();
    await auth.signUp(
      email: email.trim(),
      password: password,
      emailRedirectTo: SourceBaseAuthConfig.authRedirectTo,
      data: {
        'app_code': SourceBaseAuthConfig.appCode,
        'display_name': fullName.trim(),
        'full_name': fullName.trim(),
        'signup_source': SourceBaseAuthConfig.appCode,
        'ecosystem': 'medasi',
        if (profile != null) ...profile.toMetadata(),
      },
    );
    return const AuthActionResult.success(
      'Doğrulama e-postası SourceBase bağlantısıyla gönderildi.',
    );
  }

  static Future<AuthActionResult> signInWithGoogle() async {
    final auth = _authOrThrow();
    await auth.signInWithOAuth(
      OAuthProvider.google,
      redirectTo: SourceBaseAuthConfig.authRedirectTo,
    );
    return const AuthActionResult.success('Google girişi başlatıldı.');
  }

  static Future<AuthActionResult> signInWithApple() async {
    final auth = _authOrThrow();
    await auth.signInWithOAuth(
      OAuthProvider.apple,
      redirectTo: SourceBaseAuthConfig.authRedirectTo,
    );
    return const AuthActionResult.success('Apple girişi başlatıldı.');
  }

  static Future<AuthActionResult> updateSourceBaseProfile(
    SourceBaseProfile profile,
  ) async {
    final auth = _authOrThrow();
    if (auth.currentUser == null) {
      throw const AuthException('Oturum bulunamadı.');
    }
    final currentMetadata = auth.currentUser?.userMetadata ?? {};
    await auth.updateUser(
      UserAttributes(data: {...currentMetadata, ...profile.toMetadata()}),
    );
    return const AuthActionResult.success('SourceBase bilgilerin tamamlandı.');
  }

  static Future<AuthActionResult> resendSignupEmail(String email) async {
    final auth = _authOrThrow();
    await auth.resend(
      email: email.trim(),
      type: OtpType.signup,
      emailRedirectTo: SourceBaseAuthConfig.authRedirectTo,
    );
    return const AuthActionResult.success(
      'Doğrulama e-postası yeniden gönderildi.',
    );
  }

  static Future<AuthActionResult> sendPasswordReset(String email) async {
    final auth = _authOrThrow();
    await auth.resetPasswordForEmail(
      email.trim(),
      redirectTo: SourceBaseAuthConfig.authRedirectTo,
    );
    return const AuthActionResult.success(
      'Şifre sıfırlama e-postası SourceBase bağlantısıyla gönderildi.',
    );
  }

  static Future<AuthActionResult> updatePassword(String password) async {
    final auth = _authOrThrow();
    await auth.updateUser(UserAttributes(password: password));
    return const AuthActionResult.success('Şifren güncellendi.');
  }

  static Future<AuthActionResult> verifyEmailOtp({
    required String email,
    required String token,
  }) async {
    final auth = _authOrThrow();
    await auth.verifyOTP(
      email: email.trim(),
      token: token.trim(),
      type: OtpType.signup,
    );
    return const AuthActionResult.success('E-posta doğrulaması tamamlandı.');
  }

  static Future<AuthCallbackResult> completeCallback(Uri uri) async {
    final auth = _authOrThrow();
    final fragmentParameters = _fragmentParameters(uri);
    String? redirectType;
    final errorDescription = uri.queryParameters['error_description'] ??
        fragmentParameters['error_description'];
    final error = uri.queryParameters['error'] ?? fragmentParameters['error'];
    if (errorDescription != null || error != null) {
      throw AuthException(errorDescription ?? error ?? 'Auth callback failed.');
    }

    final code = uri.queryParameters['code'] ?? fragmentParameters['code'];
    if (code != null && code.trim().isNotEmpty) {
      final response = await auth.exchangeCodeForSession(code);
      redirectType = response.redirectType;
    } else if (uri.queryParameters.containsKey('access_token')) {
      final response = await auth.getSessionFromUrl(uri);
      redirectType = response.redirectType;
    } else if (fragmentParameters.containsKey('access_token')) {
      final response = await auth.getSessionFromUrl(
        uri.replace(queryParameters: fragmentParameters, fragment: ''),
      );
      redirectType = response.redirectType;
    }

    if (auth.currentUser == null) {
      throw const AuthException('Oturum bulunamadı.');
    }

    return AuthCallbackResult(redirectType: redirectType);
  }

  static Map<String, String> _fragmentParameters(Uri uri) {
    final fragment = uri.fragment;
    if (fragment.isEmpty) {
      return const {};
    }
    final queryStart = fragment.indexOf('?');
    final query = queryStart >= 0
        ? fragment.substring(queryStart + 1)
        : fragment;
    if (!query.contains('=')) {
      return const {};
    }
    return Uri.splitQueryString(query);
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
        'SourceBase Supabase bağlantısı yapılandırılmamış.',
      );
    }
    return auth;
  }

  static String friendlyError(Object error) {
    if (!isConfigured || _initializationError != null) {
      return 'Kimlik doğrulama yapılandırması eksik. Lütfen daha sonra tekrar dene.';
    }
    if (error is AuthException) {
      final message = error.message.toLowerCase();
      final code = error.code?.toLowerCase() ?? '';

      if (message.contains('invalid login') ||
          message.contains('invalid credentials') ||
          code.contains('invalid_credentials')) {
        return 'E-posta veya şifre hatalı.';
      }
      if (message.contains('email not confirmed') ||
          message.contains('email not verified')) {
        return 'E-postanı doğruladıktan sonra giriş yapabilirsin.';
      }
      if (message.contains('already registered') ||
          message.contains('user already') ||
          code.contains('user_already_exists')) {
        return 'Bu e-posta ile zaten bir hesap var.';
      }
      if (message.contains('weak password') ||
          message.contains('password should') ||
          code.contains('weak_password')) {
        return 'Şifre daha güçlü olmalı. En az 8 karakter kullan.';
      }
      if (message.contains('rate limit') ||
          message.contains('too many') ||
          code.contains('over_email_send_rate_limit')) {
        return 'Çok fazla deneme yapıldı. Lütfen biraz bekleyip tekrar dene.';
      }
      if (message.contains('otp') ||
          message.contains('token') ||
          code.contains('otp_expired')) {
        return 'Doğrulama kodu geçersiz veya süresi dolmuş.';
      }
      if (message.contains('no code detected') ||
          message.contains('no access_token') ||
          message.contains('session') ||
          message.contains('oturum bulunamad')) {
        return 'Oturum doğrulanamadı. Lütfen tekrar giriş yap.';
      }
      if (message.contains('network') ||
          message.contains('socket') ||
          message.contains('connection')) {
        return 'Bağlantı kurulamadı. İnternetini kontrol edip tekrar dene.';
      }
      return 'İşlem tamamlanamadı. Lütfen bilgileri kontrol edip tekrar dene.';
    }
    return 'İşlem tamamlanamadı. Lütfen bilgileri kontrol edip tekrar dene.';
  }
}
