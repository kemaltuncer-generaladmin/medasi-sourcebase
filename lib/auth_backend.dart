import 'package:supabase_flutter/supabase_flutter.dart';

class SourceBaseAuthConfig {
  static const appCode = 'sourcebase';
  static const supabaseUrl = String.fromEnvironment('SOURCEBASE_SUPABASE_URL');
  static const supabaseAnonKey = String.fromEnvironment(
    'SOURCEBASE_SUPABASE_ANON_KEY',
  );
  static const publicUrl = String.fromEnvironment(
    'SOURCEBASE_PUBLIC_URL',
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
  static bool _initialized = false;

  static bool get isConfigured => SourceBaseAuthConfig.isConfigured;
  static bool get isInitialized => _initialized;

  static SupabaseClient? get client {
    if (!_initialized) {
      return null;
    }
    return Supabase.instance.client;
  }

  static User? get currentUser => client?.auth.currentUser;

  static bool get currentUserNeedsSourceBaseProfile =>
      userNeedsSourceBaseProfile(currentUser);

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

    await Supabase.initialize(
      url: SourceBaseAuthConfig.supabaseUrl,
      anonKey: SourceBaseAuthConfig.supabaseAnonKey,
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
    required SourceBaseProfile profile,
  }) async {
    final auth = _authOrThrow();
    await auth.signUp(
      email: email.trim(),
      password: password,
      emailRedirectTo: SourceBaseAuthConfig.authRedirectTo,
      data: {
        'app_code': SourceBaseAuthConfig.appCode,
        'display_name': fullName.trim(),
        'signup_source': SourceBaseAuthConfig.appCode,
        'ecosystem': 'medasi',
        ...profile.toMetadata(),
      },
    );
    return const AuthActionResult.success(
      'Doğrulama e-postası SourceBase bağlantısıyla gönderildi.',
    );
  }

  static Future<AuthActionResult> updateSourceBaseProfile(
    SourceBaseProfile profile,
  ) async {
    final auth = _authOrThrow();
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
    if (error is AuthException) {
      return error.message;
    }
    return 'İşlem tamamlanamadı. Lütfen bilgileri kontrol edip tekrar dene.';
  }
}
