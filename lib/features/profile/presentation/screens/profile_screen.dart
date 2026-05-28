import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show User;
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/design_system/components/sourcebase_button.dart';
import '../../../../core/design_system/components/sourcebase_card.dart';
import '../../../../core/design_system/components/sourcebase_state.dart';
import '../../../../core/design_system/constants/sb_dimensions.dart';
import '../../../../core/design_system/layout/sourcebase_mobile_metrics.dart';
import '../../../../core/design_system/layout/sourcebase_page_header.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/sourcebase_brand.dart';
import '../../../auth/data/sourcebase_auth_backend.dart';
import '../../../auth/presentation/screens/login_screen.dart';
import '../../../auth/presentation/screens/profile_setup_screen.dart';
import '../../../drive/data/drive_models.dart';
import '../../../drive/data/drive_repository.dart';
import '../../../drive/presentation/widgets/drive_ui.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({
    required this.onSearch,
    required this.onOpenStore,
    super.key,
  });

  final VoidCallback onSearch;
  final VoidCallback onOpenStore;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late Future<_ProfileSnapshot> _profileFuture;
  bool _signingOut = false;

  @override
  void initState() {
    super.initState();
    _profileFuture = _ProfileSnapshot.load();
  }

  Future<void> _refreshProfile() async {
    setState(() => _profileFuture = _ProfileSnapshot.load());
    await _profileFuture;
  }

  void _openProfileSetup() {
    Navigator.of(context).pushNamed(ProfileSetupScreen.route).then((_) {
      if (mounted) {
        setState(() => _profileFuture = _ProfileSnapshot.load());
      }
    });
  }

  void _showSettingsInfo({
    required String title,
    required String message,
    IconData icon = Icons.info_outline_rounded,
  }) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        scrollable: true,
        title: Row(
          children: [
            Icon(icon, color: AppColors.blue),
            const SizedBox(width: 10),
            Expanded(child: Text(title)),
          ],
        ),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Tamam'),
          ),
        ],
      ),
    );
  }

  Future<void> _signOut(BuildContext context) async {
    if (_signingOut) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Oturumu kapat'),
        content: const Text(
          'Oturumunu kapatmak istediğine emin misin? Tekrar devam etmek için giriş yapman gerekir.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.clinicalError,
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Oturumu kapat'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    setState(() => _signingOut = true);
    try {
      await SourceBaseAuthBackend.signOut();
      if (!context.mounted) return;
      Navigator.of(
        context,
      ).pushNamedAndRemoveUntil(LoginScreen.route, (_) => false);
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Oturum kapatılamadı. Lütfen tekrar dene.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _signingOut = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return WorkspaceScroll(
      onRefresh: _refreshProfile,
      children: [
        SourceBasePageHeader(
          title: 'Profil',
          subtitle:
              'Hesap bilgilerini ve kullanım durumunu buradan takip edebilirsin.',
          leading: SourceBaseMobileMetrics.isPhone(context)
              ? const SourceBaseMark(size: 30)
              : const SourceBaseBrand(compact: true),
          actions: [
            SBIconButton(
              icon: Icons.search_rounded,
              onPressed: widget.onSearch,
              tooltip: 'Ara',
            ),
          ],
        ),
        FutureBuilder<_ProfileSnapshot>(
          future: _profileFuture,
          builder: (context, snapshot) {
            final loading = snapshot.connectionState == ConnectionState.waiting;
            final profile = snapshot.data;
            if (loading && profile == null) {
              return const _StatePanel(
                icon: Icons.person_search_rounded,
                title: 'Profil yükleniyor',
                message: 'Hesap ve cüzdan bilgilerin hazırlanıyor.',
                loading: true,
              );
            }
            if (snapshot.hasError && profile == null) {
              return _StatePanel(
                icon: Icons.error_outline_rounded,
                title: 'Profil bilgileri alınamadı',
                message: _friendlyProfileError(snapshot.error),
                actionLabel: 'Tekrar Dene',
                onAction: () {
                  setState(() => _profileFuture = _ProfileSnapshot.load());
                },
              );
            }
            final current = profile ?? _ProfileSnapshot.fromCurrentUser();
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _ProfileHeader(profile: current, onEdit: _openProfileSetup),
                const SizedBox(height: 14),
                _ProfileActionStrip(
                  signingOut: _signingOut,
                  onOpenStore: widget.onOpenStore,
                  onEditProfile: _openProfileSetup,
                  onSignOut: () => _signOut(context),
                ),
                if (!current.isComplete) ...[
                  const SizedBox(height: 12),
                  _ProfileCompletionPanel(onComplete: _openProfileSetup),
                ],
                if (current.profileLoadFailed) ...[
                  const SizedBox(height: 12),
                  const _InlineNotice(
                    icon: Icons.info_outline_rounded,
                    message:
                        'Profil tablosu okunamadı. Auth bilgilerindeki güvenli yedekler gösteriliyor.',
                  ),
                ],
                const SizedBox(height: 24),
                const SectionTitle(title: 'Kullanıcı İstatistikleri'),
                _StatsPanel(snapshot: current),
                const SizedBox(height: 24),
                const SectionTitle(title: 'Cüzdan'),
                _WalletPanel(
                  balance: current.wallet,
                  loadFailed: current.profileLoadFailed,
                  onOpenStore: widget.onOpenStore,
                ),
                const SizedBox(height: 12),
                const SectionTitle(title: 'Hesap Ayarları'),
                _SettingsGroup(
                  items: [
                    _SettingsItem(
                      icon: Icons.person_outline_rounded,
                      title: 'Profil Bilgileri',
                      description:
                          'Fakülte, bölüm ve sınıf bilgileri profil tamamlama ekranından yönetilir.',
                      onTap: _openProfileSetup,
                    ),
                    const _SettingsItem(
                      icon: Icons.notifications_none_rounded,
                      title: 'Bildirim Tercihleri',
                      description:
                          'Bildirim kanalları henüz backend ile bağlanmadı.',
                      enabled: false,
                      onTap: null,
                    ),
                    _SettingsItem(
                      icon: Icons.security_rounded,
                      title: 'Güvenlik ve Şifre',
                      description:
                          'Şifre sıfırlama ve oturum güvenliği mevcut auth akışlarıyla yönetilir.',
                      onTap: () => _showSettingsInfo(
                        title: 'Güvenlik ve Şifre',
                        message:
                            'Şifre yenileme işlemi giriş ekranındaki şifremi unuttum akışından yapılır. Aktif oturumu sonlandırmak için bu ekrandaki Oturumu kapat butonunu kullanabilirsin.',
                        icon: Icons.security_rounded,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const SectionTitle(title: 'Uygulama'),
                _SettingsGroup(
                  items: [
                    const _SettingsItem(
                      icon: Icons.dark_mode_outlined,
                      title: 'Görünüm',
                      description:
                          'Tema seçimi bu sürümde sabit aydınlık modda.',
                      enabled: false,
                      onTap: null,
                    ),
                    const _SettingsItem(
                      icon: Icons.language_rounded,
                      title: 'Dil',
                      description:
                          'SourceBase şu anda Türkçe arayüzle çalışır.',
                      enabled: false,
                      onTap: null,
                    ),
                    _SettingsItem(
                      icon: Icons.privacy_tip_outlined,
                      title: 'Gizlilik ve Destek',
                      description:
                          'Veri güvenliği, ödeme doğrulama ve destek kanalı bilgilerini gösterir.',
                      onTap: () => _showSettingsInfo(
                        title: 'Gizlilik ve Destek',
                        message:
                            'SourceBase hesap, profil, dosya ve cüzdan verilerini sadece oturum sahibi kullanıcı için gösterir. Ödeme ve bakiye güncellemeleri backend doğrulaması olmadan client tarafında yapılmaz. Destek için uygulama içi resmi destek kanalı yayınlandığında bu alana bağlanacaktır.',
                        icon: Icons.privacy_tip_outlined,
                      ),
                    ),
                    _SettingsItem(
                      icon: Icons.delete_outline_rounded,
                      title: 'Hesap Silme',
                      description:
                          'Hesap silme talebi için mevcut release durumunu gösterir.',
                      onTap: () => _showSettingsInfo(
                        title: 'Hesap Silme',
                        message:
                            'Uygulama içinde otomatik hesap silme akışı henüz backend ile bağlı değil. App Store release için hesap silme veya resmi destek talebi akışının Auth/Backend tarafında tamamlanması gerekir.',
                        icon: Icons.delete_outline_rounded,
                      ),
                    ),
                    _SettingsItem(
                      icon: Icons.info_outline_rounded,
                      title: 'SourceBase Hakkında',
                      description:
                          'SourceBase amacı, hesap ve mağaza gerçeklik durumunu gösterir.',
                      onTap: () => _showSettingsInfo(
                        title: 'SourceBase Hakkında',
                        message:
                            'SourceBase, öğrencinin kendi kaynaklarını Drive’da düzenleyip bu kaynaklardan öğrenme çıktıları üretmesi için tasarlanmıştır. Profil ve mağaza ekranı kimlik, profil tamamlama, cüzdan, paket ve çıkış yönetimini sağlar.',
                        icon: Icons.info_outline_rounded,
                      ),
                    ),
                  ],
                ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _ProfileSnapshot {
  const _ProfileSnapshot({
    required this.displayName,
    required this.email,
    required this.faculty,
    required this.department,
    required this.classLabel,
    required this.wallet,
    required this.stats,
    required this.profileLoadFailed,
    required this.statsLoadFailed,
  });

  final String displayName;
  final String email;
  final String faculty;
  final String department;
  final String classLabel;
  final _MedasiWalletBalance wallet;
  final _UserStats stats;
  final bool profileLoadFailed;
  final bool statsLoadFailed;

  bool get isComplete => faculty.isNotEmpty && department.isNotEmpty;

  static Future<_ProfileSnapshot> load() async {
    try {
      return await _loadFromSources();
    } catch (_) {
      return fromCurrentUser();
    }
  }

  static Future<_ProfileSnapshot> _loadFromSources() async {
    final user = _safeCurrentUser();
    final metadata = user?.userMetadata ?? const <String, dynamic>{};
    Map<String, dynamic> profileRow = const {};
    var profileLoadFailed = false;

    final client = SourceBaseAuthBackend.client;
    if (client != null && user != null) {
      try {
        final row = await client
            .from('profiles')
            .select()
            .eq('id', user.id)
            .maybeSingle()
            .timeout(const Duration(seconds: 5));
        if (row != null) {
          profileRow = Map<String, dynamic>.from(row);
        }
      } catch (_) {
        profileLoadFailed = true;
      }
    }

    _UserStats stats = _UserStats.empty;
    var statsLoadFailed = false;
    if (user == null) {
      statsLoadFailed = true;
    } else {
      try {
        final workspace = await const DriveRepository().loadWorkspace().timeout(
          const Duration(seconds: 5),
        );
        stats = _UserStats.fromWorkspace(workspace);
      } catch (_) {
        statsLoadFailed = true;
      }
    }

    return _ProfileSnapshot(
      displayName: _firstText([
        profileRow['display_name'],
        profileRow['full_name'],
        metadata['display_name'],
        metadata['full_name'],
        user?.email?.split('@').first,
      ], fallback: 'Kullanıcı'),
      email: _safeText(user?.email, fallback: 'E-posta tanımlı değil'),
      faculty: _firstText([
        profileRow['faculty'],
        profileRow['sourcebase_faculty'],
        metadata['sourcebase_faculty'],
        metadata['faculty'],
      ]),
      department: _firstText([
        profileRow['department'],
        profileRow['sourcebase_department'],
        metadata['sourcebase_department'],
        metadata['department'],
      ]),
      classLabel: _firstText([
        profileRow['class_year'],
        profileRow['grade'],
        profileRow['year'],
        metadata['sourcebase_class_year'],
        metadata['class_year'],
      ]),
      wallet: _MedasiWalletBalance.fromProfileRow(profileRow),
      stats: stats,
      profileLoadFailed: profileLoadFailed,
      statsLoadFailed: statsLoadFailed,
    );
  }

  static _ProfileSnapshot fromCurrentUser() {
    final user = _safeCurrentUser();
    final metadata = user?.userMetadata ?? const <String, dynamic>{};
    return _ProfileSnapshot(
      displayName: _firstText([
        metadata['display_name'],
        metadata['full_name'],
        user?.email?.split('@').first,
      ], fallback: 'Kullanıcı'),
      email: _safeText(user?.email, fallback: 'E-posta tanımlı değil'),
      faculty: _firstText([
        metadata['sourcebase_faculty'],
        metadata['faculty'],
      ]),
      department: _firstText([
        metadata['sourcebase_department'],
        metadata['department'],
      ]),
      classLabel: _firstText([
        metadata['sourcebase_class_year'],
        metadata['class_year'],
      ]),
      wallet: const _MedasiWalletBalance(0),
      stats: _UserStats.empty,
      profileLoadFailed: true,
      statsLoadFailed: true,
    );
  }
}

class _UserStats {
  const _UserStats({
    required this.courseCount,
    required this.fileCount,
    required this.generatedCount,
    required this.collectionCount,
  });

  static const empty = _UserStats(
    courseCount: 0,
    fileCount: 0,
    generatedCount: 0,
    collectionCount: 0,
  );

  final int courseCount;
  final int fileCount;
  final int generatedCount;
  final int collectionCount;

  bool get hasData =>
      courseCount > 0 ||
      fileCount > 0 ||
      generatedCount > 0 ||
      collectionCount > 0;

  static _UserStats fromWorkspace(DriveWorkspaceData workspace) {
    final files = workspace.courses
        .expand((course) => course.sections)
        .expand((section) => section.files)
        .toList();
    return _UserStats(
      courseCount: workspace.courses.length,
      fileCount: files.length,
      generatedCount: files.fold<int>(
        0,
        (total, file) => total + file.generated.length,
      ),
      collectionCount: workspace.collections.length,
    );
  }
}

String _friendlyProfileError(Object? error) {
  return 'Profil bilgileri şu anda yüklenemiyor. Lütfen tekrar dene.';
}

User? _safeCurrentUser() {
  try {
    return SourceBaseAuthBackend.currentUser;
  } catch (_) {
    return null;
  }
}

String _firstText(List<Object?> values, {String fallback = ''}) {
  for (final value in values) {
    final text = _safeText(value);
    if (text.isNotEmpty) return text;
  }
  return fallback;
}

String _safeText(Object? value, {String fallback = ''}) {
  final text = value?.toString().trim() ?? '';
  if (text.isEmpty || text.toLowerCase() == 'null') return fallback;
  return text;
}

int _safeInt(Object? raw) {
  if (raw is int) return raw < 0 ? 0 : raw;
  if (raw is num) {
    return raw.isFinite ? raw.round().clamp(0, 1 << 31).toInt() : 0;
  }
  if (raw is String) {
    final parsed = double.tryParse(raw.trim());
    if (parsed == null || !parsed.isFinite) return 0;
    return parsed.round().clamp(0, 1 << 31).toInt();
  }
  return 0;
}

int? _nullablePositiveInt(Object? raw) {
  final value = _safeInt(raw);
  return value > 0 ? value : null;
}

double _safeDouble(Object? raw) {
  if (raw is num) return raw.isFinite && raw > 0 ? raw.toDouble() : 0;
  if (raw is String) {
    final parsed = double.tryParse(raw.trim());
    return parsed != null && parsed.isFinite && parsed > 0 ? parsed : 0;
  }
  return 0;
}

String _friendlyPurchaseError(String message) {
  final normalized = message.toLowerCase();
  if (normalized.contains('unknown_action') ||
      normalized.contains('sourcebase işlemi bulunamadı') ||
      normalized.contains('purchase_medasicoin')) {
    return 'Paket bilgileri doğrulanamadı. Lütfen tekrar dene.';
  }
  if (normalized.contains('400') ||
      normalized.contains('bad request') ||
      normalized.contains('invalid')) {
    return 'Paket bilgileri doğrulanamadı. Lütfen tekrar dene.';
  }
  if (normalized.contains('cancel')) {
    return 'Ödeme işlemi iptal edildi.';
  }
  if (normalized.contains('auth') ||
      normalized.contains('session') ||
      normalized.contains('oturum') ||
      normalized.contains('unauthorized')) {
    return 'Oturum süren dolmuş olabilir. Devam etmek için tekrar giriş yap.';
  }
  if (normalized.contains('network') ||
      normalized.contains('socket') ||
      normalized.contains('xmlhttprequest')) {
    return 'Paketler yüklenemedi. Bağlantını kontrol edip tekrar deneyebilirsin.';
  }
  return 'Ödeme başlatılamadı. Paket bilgileri doğrulanamadı. Lütfen tekrar dene.';
}

class _ProfileActionStrip extends StatelessWidget {
  const _ProfileActionStrip({
    required this.signingOut,
    required this.onOpenStore,
    required this.onEditProfile,
    required this.onSignOut,
  });

  final bool signingOut;
  final VoidCallback onOpenStore;
  final VoidCallback onEditProfile;
  final VoidCallback onSignOut;

  @override
  Widget build(BuildContext context) {
    return SourceBaseCard(
      padding: const EdgeInsets.all(12),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final tight = constraints.maxWidth < 340;
          final storeButton = SBPrimaryButton(
            label: 'Paketler',
            icon: Icons.storefront_rounded,
            onPressed: onOpenStore,
            size: SBButtonSize.small,
          );
          final editButton = SBSecondaryButton(
            label: 'Düzenle',
            icon: Icons.edit_outlined,
            onPressed: onEditProfile,
            size: SBButtonSize.small,
          );
          final signOutButton = _DangerOutlineButton(
            label: signingOut ? 'Kapatılıyor...' : 'Çıkış',
            icon: Icons.logout_rounded,
            onPressed: signingOut ? null : onSignOut,
            loading: signingOut,
            height: 44,
          );

          if (constraints.maxWidth >= 620) {
            return Row(
              children: [
                Expanded(child: storeButton),
                const SizedBox(width: 10),
                Expanded(child: editButton),
                const SizedBox(width: 10),
                Expanded(child: signOutButton),
              ],
            );
          }

          if (tight) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                storeButton,
                const SizedBox(height: 8),
                editButton,
                const SizedBox(height: 8),
                signOutButton,
              ],
            );
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              storeButton,
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(child: editButton),
                  const SizedBox(width: 8),
                  Expanded(child: signOutButton),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

class _DangerOutlineButton extends StatelessWidget {
  const _DangerOutlineButton({
    required this.label,
    required this.icon,
    required this.onPressed,
    this.loading = false,
    this.height = 52,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onPressed;
  final bool loading;
  final double height;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: loading ? null : onPressed,
        icon: loading
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.clinicalError,
                ),
              )
            : Icon(icon, size: 20),
        label: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.clinicalError,
          side: BorderSide(
            color: AppColors.clinicalError.withValues(alpha: .24),
          ),
          backgroundColor: AppColors.clinicalErrorBg.withValues(alpha: .65),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(SBDimensions.buttonRadius),
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.w900),
        ),
      ),
    );
  }
}

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({required this.profile, required this.onEdit});
  final _ProfileSnapshot profile;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    return SourceBaseCard(
      padding: const EdgeInsets.all(SBDimensions.cardPadding),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 430;
          final avatar = Container(
            width: compact ? 64 : 80,
            height: compact ? 64 : 80,
            decoration: const BoxDecoration(
              gradient: AppColors.primaryGradient,
              shape: BoxShape.circle,
            ),
            child: const Center(
              child: Icon(Icons.person_rounded, color: Colors.white, size: 40),
            ),
          );
          final details = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                profile.displayName,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: AppColors.navy,
                  fontSize: compact ? 21 : 24,
                  fontWeight: FontWeight.w900,
                  height: 1.08,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                profile.email,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: AppColors.muted,
                  fontSize: compact ? 13 : 15,
                ),
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _InfoChip(
                    icon: Icons.account_balance_outlined,
                    label: profile.faculty.isEmpty
                        ? 'Fakülte eksik'
                        : profile.faculty,
                  ),
                  _InfoChip(
                    icon: Icons.school_outlined,
                    label: profile.department.isEmpty
                        ? 'Bölüm eksik'
                        : profile.department,
                  ),
                  if (profile.classLabel.isNotEmpty)
                    _InfoChip(
                      icon: Icons.event_note_outlined,
                      label: profile.classLabel,
                    ),
                ],
              ),
              const SizedBox(height: 12),
              _CompletionBadge(completed: profile.isComplete),
            ],
          );

          if (compact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    avatar,
                    const Spacer(),
                    IconButton(
                      onPressed: onEdit,
                      tooltip: 'Profili düzenle',
                      icon: const Icon(
                        Icons.edit_outlined,
                        color: AppColors.blue,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                details,
              ],
            );
          }

          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              avatar,
              const SizedBox(width: 20),
              Expanded(child: details),
              IconButton(
                onPressed: onEdit,
                tooltip: 'Profili düzenle',
                icon: const Icon(Icons.edit_outlined, color: AppColors.blue),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 260),
      child: SourceBaseChip(
        label: label,
        icon: icon,
        selected: true,
        foregroundColor: AppColors.clinicalActive,
      ),
    );
  }
}

class _CompletionBadge extends StatelessWidget {
  const _CompletionBadge({required this.completed});

  final bool completed;

  @override
  Widget build(BuildContext context) {
    return SourceBaseChip(
      label: completed ? 'Profil tamamlandı' : 'Profil bilgileri eksik',
      selected: true,
      foregroundColor: completed ? AppColors.green : AppColors.clinicalError,
      backgroundColor: completed
          ? AppColors.greenBg
          : AppColors.clinicalErrorBg,
    );
  }
}

class _ProfileCompletionPanel extends StatelessWidget {
  const _ProfileCompletionPanel({required this.onComplete});

  final VoidCallback onComplete;

  @override
  Widget build(BuildContext context) {
    return _InlineActionPanel(
      icon: Icons.assignment_ind_outlined,
      title: 'Profilini tamamla',
      message:
          'Fakülte ve bölüm bilgilerin eksik. SourceBase deneyiminin doğru kişiselleşmesi için bilgilerini tamamla.',
      actionLabel: 'Tamamla',
      onAction: onComplete,
    );
  }
}

class _StatsPanel extends StatelessWidget {
  const _StatsPanel({required this.snapshot});

  final _ProfileSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    if (snapshot.statsLoadFailed) {
      return const _InlineActionPanel(
        icon: Icons.query_stats_rounded,
        title: 'İstatistikler yüklenemedi',
        message:
            'Drive verileri şu anda alınamadı. Gerçek veri gelmeden tahmini istatistik gösterilmiyor.',
      );
    }

    if (!snapshot.stats.hasData) {
      return const _InlineActionPanel(
        icon: Icons.insights_rounded,
        title: 'Henüz istatistik yok',
        message:
            'Dosya veya üretim oluşturduğunda istatistiklerin burada görünecek.',
      );
    }

    return GlassPanel(
      padding: const EdgeInsets.all(16),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final twoColumns = constraints.maxWidth >= 420;
          final width = twoColumns
              ? (constraints.maxWidth - 12) / 2
              : constraints.maxWidth;
          return Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _StatTile(
                width: width,
                icon: Icons.folder_copy_outlined,
                label: 'Ders',
                value: snapshot.stats.courseCount.toString(),
              ),
              _StatTile(
                width: width,
                icon: Icons.description_outlined,
                label: 'Dosya',
                value: snapshot.stats.fileCount.toString(),
              ),
              _StatTile(
                width: width,
                icon: Icons.fact_check_outlined,
                label: 'Üretim',
                value: snapshot.stats.generatedCount.toString(),
              ),
              _StatTile(
                width: width,
                icon: Icons.collections_bookmark_outlined,
                label: 'Koleksiyon',
                value: snapshot.stats.collectionCount.toString(),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.width,
    required this.icon,
    required this.label,
    required this.value,
  });

  final double width;
  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.selectedBlue,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.softLine),
        ),
        child: Row(
          children: [
            Icon(icon, color: AppColors.blue, size: 24),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppColors.muted,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Text(
              value,
              style: const TextStyle(
                color: AppColors.navy,
                fontSize: 20,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WalletPanel extends StatelessWidget {
  const _WalletPanel({
    required this.balance,
    required this.loadFailed,
    required this.onOpenStore,
  });

  final _MedasiWalletBalance balance;
  final bool loadFailed;
  final VoidCallback onOpenStore;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: !loadFailed,
      label: loadFailed
          ? 'MC bakiyesi yüklenemedi.'
          : 'MC cüzdanı, ${balance.label}, ${balance.rightsLabel}. Paketlere git.',
      child: InkWell(
        onTap: loadFailed ? null : onOpenStore,
        borderRadius: BorderRadius.circular(16),
        child: GlassPanel(
          padding: const EdgeInsets.all(20),
          borderColor: AppColors.blue.withValues(alpha: .18),
          child: Row(
            children: [
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  gradient: AppColors.brandGradient,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  Icons.account_balance_wallet_rounded,
                  color: Colors.white,
                  size: 30,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Mevcut MC',
                      style: TextStyle(
                        color: AppColors.muted,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      loadFailed ? 'Yüklenemedi' : balance.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: loadFailed ? AppColors.red : AppColors.navy,
                        fontSize: 30,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      loadFailed
                          ? 'Bakiye bilgisi şu anda alınamadı.'
                          : balance.rightsLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.muted,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (!loadFailed &&
                        balance.amount <= 0 &&
                        balance.rights <= 0) ...[
                      const SizedBox(height: 6),
                      const Text(
                        'Yeni çıktı oluşturmak için paket satın alman gerekebilir.',
                        style: TextStyle(
                          color: AppColors.muted,
                          fontSize: 12,
                          height: 1.25,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: AppColors.selectedBlue,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.storefront_rounded,
                  color: AppColors.blue,
                  size: 22,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MedasiWalletBalance {
  const _MedasiWalletBalance(this.amount, {this.rights = 0});

  final double amount;
  final int rights;

  String get label => '${_formatAmount(amount)} MC';
  String get rightsLabel =>
      rights > 0 ? '$rights kullanım hakkı' : 'Ek hak yok';

  static Future<_MedasiWalletBalance> loadCurrent() async {
    final client = SourceBaseAuthBackend.client;
    final userId = SourceBaseAuthBackend.currentUser?.id;
    if (client == null || userId == null) {
      throw StateError('Oturum gerekli.');
    }
    _MedasiWalletBalance? profileBalance;
    try {
      final row = await client
          .from('profiles')
          .select()
          .eq('id', userId)
          .maybeSingle();
      if (row != null) {
        profileBalance = _MedasiWalletBalance.fromProfileRow(
          Map<String, dynamic>.from(row),
        );
      }
    } catch (_) {
      profileBalance = null;
    }

    try {
      final rows = await client
          .from('wallet_transactions')
          .select('amount_units')
          .eq('user_id', userId);
      final units = rows.fold<int>(
        0,
        (total, row) =>
            total + _safeInt(Map<String, dynamic>.from(row)['amount_units']),
      );
      return _MedasiWalletBalance(
        units / 100,
        rights: profileBalance?.rights ?? 0,
      );
    } catch (_) {
      if (profileBalance != null) return profileBalance;
      throw StateError('Bakiye yüklenemedi.');
    }
  }

  static _MedasiWalletBalance fromProfileRow(Map<String, dynamic> row) {
    final amount = _safeDouble(
      row['wallet_balance'] ??
          row['medasicoin_balance'] ??
          row['medasi_coin_balance'] ??
          row['coin_balance'] ??
          row['credit_balance'],
    );
    final rights = _safeInt(
      row['remaining_rights'] ??
          row['usage_rights'] ??
          row['generation_rights'] ??
          row['remaining_credits'] ??
          row['credits'],
    );
    return _MedasiWalletBalance(amount, rights: rights);
  }

  static String _formatAmount(double value) {
    if (value == value.roundToDouble()) {
      return value.toStringAsFixed(0);
    }
    return value.toStringAsFixed(2).replaceFirst(RegExp(r'0+$'), '');
  }
}

class MedasiCoinStoreScreen extends StatefulWidget {
  const MedasiCoinStoreScreen({
    required this.onSearch,
    required this.onBack,
    super.key,
  });

  final VoidCallback onSearch;
  final VoidCallback onBack;

  @override
  State<MedasiCoinStoreScreen> createState() => _MedasiCoinStoreScreenState();
}

class _MedasiCoinStoreScreenState extends State<MedasiCoinStoreScreen> {
  late Future<List<_MedasiCoinPackage>> _packagesFuture;
  late Future<_MedasiWalletBalance> _walletFuture;

  @override
  void initState() {
    super.initState();
    _packagesFuture = _MedasiCoinPackage.loadStoreProducts();
    _walletFuture = _MedasiWalletBalance.loadCurrent();
  }

  Future<void> _refreshStoreData() async {
    setState(() {
      _packagesFuture = _MedasiCoinPackage.loadStoreProducts();
      _walletFuture = _MedasiWalletBalance.loadCurrent();
    });
    try {
      await Future.wait([_packagesFuture, _walletFuture]);
    } catch (_) {
      // FutureBuilder panels surface the user-facing error states.
    }
  }

  void _refreshWallet() {
    setState(() => _walletFuture = _MedasiWalletBalance.loadCurrent());
  }

  @override
  Widget build(BuildContext context) {
    return WorkspaceScroll(
      onRefresh: _refreshStoreData,
      children: [
        SourceBasePageHeader(
          title: 'Paketler',
          subtitle: 'MC bakiyeni ve mevcut paketleri yönet.',
          leading: SBIconButton(
            icon: Icons.arrow_back_rounded,
            onPressed: widget.onBack,
            tooltip: 'Geri dön',
          ),
          actions: [
            SBIconButton(
              icon: Icons.search_rounded,
              onPressed: widget.onSearch,
              tooltip: 'Ara',
            ),
          ],
        ),
        GlassPanel(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  gradient: AppColors.brandGradient,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.monetization_on_rounded,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'MC Paketleri',
                style: TextStyle(
                  color: AppColors.navy,
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Paketler gerçek mağaza verisinden yüklenir. Bakiye yalnızca onaylı ödeme sonrası güncellenir.',
                style: TextStyle(
                  color: AppColors.muted,
                  fontSize: 15,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        _StoreWalletSummary(future: _walletFuture, onRefresh: _refreshWallet),
        const SizedBox(height: 14),
        FutureBuilder<List<_MedasiCoinPackage>>(
          future: _packagesFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const _StatePanel(
                icon: Icons.storefront_rounded,
                title: 'Paketler yükleniyor',
                message: 'Mağaza paketleri hazırlanıyor.',
                loading: true,
              );
            }
            if (snapshot.hasError) {
              return _StatePanel(
                icon: Icons.error_outline_rounded,
                title: 'Paketler yüklenemedi',
                message: 'Bağlantını kontrol edip tekrar deneyebilirsin.',
                actionLabel: 'Tekrar Dene',
                onAction: () {
                  setState(
                    () => _packagesFuture =
                        _MedasiCoinPackage.loadStoreProducts(),
                  );
                },
              );
            }
            final packages = snapshot.data ?? const <_MedasiCoinPackage>[];
            if (packages.isEmpty) {
              return const _StatePanel(
                icon: Icons.inventory_2_outlined,
                title: 'Paket bulunamadı',
                message:
                    'Satın alınabilir gerçek paket bulunamadı. Paketler aktif edildiğinde burada görünecek.',
              );
            }
            return LayoutBuilder(
              builder: (context, constraints) {
                final columns = constraints.maxWidth >= 980
                    ? 3
                    : constraints.maxWidth >= 650
                    ? 2
                    : 1;
                final gap = columns == 1 ? 0.0 : 12.0;
                final itemWidth =
                    (constraints.maxWidth - gap * (columns - 1)) / columns;
                return Wrap(
                  spacing: gap,
                  runSpacing: 12,
                  children: [
                    for (final item in packages)
                      SizedBox(
                        width: itemWidth,
                        child: _StorePackageTile(
                          package: item,
                          onPurchaseStateChanged: _refreshWallet,
                        ),
                      ),
                  ],
                );
              },
            );
          },
        ),
      ],
    );
  }
}

class _StorePackageTile extends StatefulWidget {
  const _StorePackageTile({
    required this.package,
    required this.onPurchaseStateChanged,
  });

  final _MedasiCoinPackage package;
  final VoidCallback onPurchaseStateChanged;

  @override
  State<_StorePackageTile> createState() => _StorePackageTileState();
}

final bool _storePaymentsEnabled = true;

enum _PurchaseUiState { pending, success, failed, cancelled, unknown }

class _StorePackageTileState extends State<_StorePackageTile> {
  bool _buying = false;
  String? _buyError;
  String? _buyInfo;
  String? _checkoutUrl;
  _PurchaseUiState? _purchaseState;

  Future<void> _purchase() async {
    if (_buying) return;
    if (!widget.package.canPurchase) {
      setState(() {
        _buyError = 'Paket bilgileri doğrulanamadı. Lütfen tekrar dene.';
        _buyInfo = null;
        _purchaseState = _PurchaseUiState.failed;
      });
      return;
    }
    setState(() {
      _buying = true;
      _buyError = null;
      _buyInfo = null;
      _checkoutUrl = null;
      _purchaseState = _PurchaseUiState.pending;
    });
    try {
      final client = SourceBaseAuthBackend.client;
      if (client == null) {
        setState(() {
          _buyError =
              'Oturum süren dolmuş olabilir. Devam etmek için tekrar giriş yap.';
          _purchaseState = _PurchaseUiState.failed;
        });
        return;
      }
      final result = await client.functions.invoke(
        'sourcebase',
        body: {
          'action': 'purchase_medasicoin',
          'payload': {
            'product_code': widget.package.code,
            'success_url': '${SourceBaseAuthConfig.publicUrl}/home',
            'cancel_url': '${SourceBaseAuthConfig.publicUrl}/home?cancelled=1',
          },
        },
      );
      final raw = result.data;
      final json = raw is Map ? Map<String, dynamic>.from(raw) : null;
      if (json == null) {
        setState(() {
          _buyError = 'Ödeme durumu doğrulanamadı.';
          _purchaseState = _PurchaseUiState.unknown;
        });
        return;
      }
      final data = json['data'];
      final purchaseData = data is Map ? Map<String, dynamic>.from(data) : null;
      final checkoutUrl = _safeText(
        purchaseData?['url'] ?? purchaseData?['checkout_url'],
      );
      final status = _safeText(
        purchaseData?['status'] ?? purchaseData?['payment_status'],
      ).toLowerCase();
      if (json['ok'] == true && _isPaidStatus(status)) {
        if (!mounted) return;
        setState(() {
          _buyInfo = 'Paket hesabına tanımlandı. Bakiye yenileniyor.';
          _purchaseState = _PurchaseUiState.success;
        });
        widget.onPurchaseStateChanged();
      } else if (json['ok'] == true && _isCancelledStatus(status)) {
        if (!mounted) return;
        setState(() {
          _buyError = 'Ödeme işlemi iptal edildi.';
          _purchaseState = _PurchaseUiState.cancelled;
        });
      } else if (json['ok'] == true && _isFailedStatus(status)) {
        if (!mounted) return;
        setState(() {
          _buyError =
              'Satın alma tamamlanamadı. Ödeme sağlayıcısından yanıt alınamadı.';
          _purchaseState = _PurchaseUiState.failed;
        });
      } else if (json['ok'] == true && checkoutUrl.isNotEmpty) {
        if (!mounted) return;
        setState(() {
          _buyInfo =
              'Ödeme sonucu bekleniyor. Linki kopyalayıp güvenli ödeme sayfasında işlemi tamamlayabilirsin.';
          _purchaseState = _PurchaseUiState.pending;
        });
        setState(() => _checkoutUrl = checkoutUrl);
      } else if (json['ok'] == true) {
        if (!mounted) return;
        setState(() {
          _buyError = 'Ödeme durumu doğrulanamadı.';
          _purchaseState = _PurchaseUiState.unknown;
        });
      } else {
        final error = json['error'];
        final message = error is Map ? _safeText(error['message']) : '';
        final code = error is Map ? _safeText(error['code']) : '';
        setState(() {
          _buyError = _friendlyPurchaseError('$code $message');
          _purchaseState = _PurchaseUiState.failed;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _buyError = _friendlyPurchaseError(error.toString());
          _purchaseState = _PurchaseUiState.failed;
        });
      }
    } finally {
      if (mounted) setState(() => _buying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact =
              SourceBaseMobileMetrics.isPhone(context) ||
              constraints.maxWidth < 560;
          final paymentsDisabled = !_storePaymentsEnabled;
          final leading = Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: AppColors.clinicalActiveBg,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.clinicalBorder),
            ),
            child: const Icon(
              Icons.toll_rounded,
              color: AppColors.clinicalActive,
              size: 26,
            ),
          );
          final details = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.package.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppColors.navy,
                  fontSize: 21,
                  fontWeight: FontWeight.w900,
                  height: 1.1,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                widget.package.description,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppColors.muted,
                  fontSize: 13,
                  height: 1.3,
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _StorePackagePill(
                    icon: widget.package.kind == _StorePackageKind.subscription
                        ? Icons.verified_outlined
                        : Icons.toll_rounded,
                    label: widget.package.kind == _StorePackageKind.subscription
                        ? 'Üyelik'
                        : '${widget.package.coin} MC',
                  ),
                  _StorePackagePill(
                    icon: widget.package.hasPrice
                        ? Icons.lock_outline_rounded
                        : Icons.info_outline_rounded,
                    label: widget.package.hasPrice
                        ? 'Backend onaylı'
                        : 'Fiyat bekliyor',
                  ),
                ],
              ),
            ],
          );
          final price = Text(
            widget.package.priceLabel,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: widget.package.hasPrice
                  ? AppColors.clinicalActive
                  : AppColors.muted,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          );
          final button = SizedBox(
            width: compact ? double.infinity : 138,
            height: compact ? 48 : 42,
            child: FilledButton(
              onPressed:
                  _buying || !widget.package.canPurchase || paymentsDisabled
                  ? null
                  : _purchase,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.clinicalActive,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: _buying
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        'Ödeme başlat',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
            ),
          );

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (compact) ...[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    leading,
                    const SizedBox(width: 12),
                    Expanded(child: details),
                  ],
                ),
                const SizedBox(height: 14),
                Row(children: [Expanded(child: price)]),
                const SizedBox(height: 10),
                button,
              ] else
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    leading,
                    const SizedBox(width: 14),
                    Expanded(child: details),
                    const SizedBox(width: 12),
                    Flexible(child: price),
                    const SizedBox(width: 12),
                    button,
                  ],
                ),
              if (!widget.package.canPurchase) ...[
                const SizedBox(height: 8),
                const Text(
                  'Paket bilgileri doğrulanamadığı için satın alma kapalı.',
                  style: TextStyle(
                    color: AppColors.muted,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
              if (paymentsDisabled && widget.package.canPurchase) ...[
                const SizedBox(height: 8),
                const Text(
                  'Ödeme yakında aktif olacak.',
                  style: TextStyle(
                    color: AppColors.muted,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    height: 1.3,
                  ),
                ),
              ],
              if (_buying) ...[
                const SizedBox(height: 8),
                const _PaymentStateNotice(
                  state: _PurchaseUiState.pending,
                  message: 'Ödeme hazırlanıyor.',
                ),
              ],
              if (!_buying && _buyInfo != null && _purchaseState != null) ...[
                const SizedBox(height: 8),
                _PaymentStateNotice(state: _purchaseState!, message: _buyInfo!),
              ],
              if (_checkoutUrl != null) ...[
                const SizedBox(height: 10),
                _CheckoutLinkActions(url: _checkoutUrl!),
              ],
              if (!_buying && _buyError != null && _purchaseState != null) ...[
                const SizedBox(height: 8),
                _PaymentStateNotice(
                  state: _purchaseState!,
                  message: _buyError!,
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _PaymentStateNotice extends StatelessWidget {
  const _PaymentStateNotice({required this.state, required this.message});

  final _PurchaseUiState state;
  final String message;

  @override
  Widget build(BuildContext context) {
    final (icon, title, color) = switch (state) {
      _PurchaseUiState.pending => (
        Icons.hourglass_top_rounded,
        'Ödeme sonucu bekleniyor',
        AppColors.blue,
      ),
      _PurchaseUiState.success => (
        Icons.check_circle_outline_rounded,
        'Paket hesabına tanımlandı',
        AppColors.green,
      ),
      _PurchaseUiState.failed => (
        Icons.error_outline_rounded,
        'Ödeme tamamlanamadı',
        AppColors.red,
      ),
      _PurchaseUiState.cancelled => (
        Icons.cancel_outlined,
        'Ödeme işlemi iptal edildi',
        AppColors.muted,
      ),
      _PurchaseUiState.unknown => (
        Icons.help_outline_rounded,
        'Ödeme durumu doğrulanamadı',
        AppColors.orange,
      ),
    };
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: .18)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: color,
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  message,
                  style: const TextStyle(
                    color: AppColors.navy,
                    fontSize: 13,
                    height: 1.3,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StorePackagePill extends StatelessWidget {
  const _StorePackagePill({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 180),
      child: SourceBaseChip(
        label: label,
        icon: icon,
        selected: true,
        foregroundColor: AppColors.clinicalActive,
      ),
    );
  }
}

bool _isPaidStatus(String status) {
  return status == 'paid' ||
      status == 'success' ||
      status == 'succeeded' ||
      status == 'completed';
}

bool _isCancelledStatus(String status) {
  return status == 'cancel' || status == 'canceled' || status == 'cancelled';
}

bool _isFailedStatus(String status) {
  return status == 'failed' || status == 'failure' || status == 'declined';
}

class _StoreWalletSummary extends StatelessWidget {
  const _StoreWalletSummary({required this.future, required this.onRefresh});

  final Future<_MedasiWalletBalance> future;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_MedasiWalletBalance>(
      future: future,
      builder: (context, snapshot) {
        final loading = snapshot.connectionState == ConnectionState.waiting;
        final balance = snapshot.data ?? const _MedasiWalletBalance(0);
        return GlassPanel(
          padding: const EdgeInsets.all(18),
          borderColor: AppColors.blue.withValues(alpha: .16),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: AppColors.selectedBlue,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.account_balance_wallet_rounded,
                  color: AppColors.blue,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Mevcut Bakiye',
                      style: TextStyle(
                        color: AppColors.muted,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      loading
                          ? 'Bakiye yükleniyor'
                          : snapshot.hasError
                          ? 'Bakiye alınamadı'
                          : balance.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: snapshot.hasError
                            ? AppColors.red
                            : AppColors.navy,
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    if (!loading && !snapshot.hasError) ...[
                      const SizedBox(height: 2),
                      Text(
                        balance.rightsLabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.muted,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Bakiyeyi yenile',
                onPressed: onRefresh,
                icon: const Icon(Icons.refresh_rounded, color: AppColors.blue),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _CheckoutLinkActions extends StatelessWidget {
  const _CheckoutLinkActions({required this.url});

  final String url;

  Future<void> _openUrl(BuildContext context) async {
    final uri = Uri.tryParse(url);
    if (uri == null || !(uri.isScheme('https') || uri.isScheme('http'))) {
      await _copyToClipboard(
        context,
        message: 'Ödeme bağlantısı geçerli değil.',
      );
      return;
    }
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (opened || !context.mounted) return;
    await _copyToClipboard(
      context,
      message:
          'Ödeme sayfası açılamadı. Bağlantı kopyalandı; tarayıcıya yapıştırarak devam edebilirsin.',
    );
  }

  Future<void> _copyToClipboard(
    BuildContext context, {
    String message = 'Ödeme bağlantısı kopyalandı.',
  }) async {
    await Clipboard.setData(ClipboardData(text: url));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
      );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.selectedBlue,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.softLine),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final text = Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              Icon(Icons.link_rounded, color: AppColors.blue, size: 20),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Ödeme linki hazır. İşlemi tamamladıktan sonra bakiyeyi yenile.',
                  style: TextStyle(
                    color: AppColors.navy,
                    fontSize: 12,
                    height: 1.25,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          );
          final actions = Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              FilledButton.icon(
                onPressed: () => _openUrl(context),
                icon: const Icon(Icons.open_in_new_rounded, size: 18),
                label: const Text('Ödemeye git'),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.clinicalActive,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              TextButton(
                onPressed: () => _copyToClipboard(context),
                child: const Text('Kopyala'),
              ),
            ],
          );

          if (constraints.maxWidth < 430) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                text,
                const SizedBox(height: 10),
                Wrap(spacing: 8, runSpacing: 8, children: [actions]),
              ],
            );
          }

          return Row(
            children: [
              Expanded(child: text),
              const SizedBox(width: 10),
              actions,
            ],
          );
        },
      ),
    );
  }
}

enum _StorePackageKind { coin, subscription }

class _MedasiCoinPackage {
  const _MedasiCoinPackage({
    required this.code,
    required this.coin,
    required this.priceCents,
    required this.title,
    required this.description,
    required this.currency,
    this.kind = _StorePackageKind.coin,
    this.sortOrder = 0,
  });

  final String code;
  final int coin;
  final int? priceCents;
  final String title;
  final String description;
  final String currency;
  final _StorePackageKind kind;
  final int sortOrder;

  bool get hasPrice => priceCents != null && priceCents! > 0;
  bool get canPurchase => code.isNotEmpty && hasPrice;
  String get priceLabel {
    if (!hasPrice) return 'Fiyat yok';
    final major = priceCents! / 100;
    final formatted = major == major.roundToDouble()
        ? major.toStringAsFixed(0)
        : major.toStringAsFixed(2);
    return '$formatted ${currency.isEmpty ? 'TL' : currency}';
  }

  static Future<List<_MedasiCoinPackage>> loadStoreProducts() async {
    final client = SourceBaseAuthBackend.client;
    if (client == null) {
      throw StateError('SourceBase bağlantısı hazır değil.');
    }

    final rows = await _loadBackendRows(client);
    final backendPackages = rows
        .map(_fromBackendRow)
        .where((item) => item.code.isNotEmpty && item.hasPrice)
        .toList();
    backendPackages.sort((a, b) {
      final order = a.sortOrder.compareTo(b.sortOrder);
      if (order != 0) return order;
      return (a.priceCents ?? 0).compareTo(b.priceCents ?? 0);
    });
    return backendPackages;
  }

  static Future<List<Map<String, dynamic>>> _loadBackendRows(
    dynamic client,
  ) async {
    try {
      final rows = await client
          .from('store_products')
          .select()
          .eq('is_active', true);
      return rows.map<Map<String, dynamic>>(Map<String, dynamic>.from).toList();
    } catch (_) {
      try {
        final rows = await client
            .from('products')
            .select()
            .eq('status', 'published');
        return rows
            .map<Map<String, dynamic>>(Map<String, dynamic>.from)
            .toList();
      } catch (_) {
        return const <Map<String, dynamic>>[];
      }
    }
  }

  static _MedasiCoinPackage _fromBackendRow(Map<String, dynamic> data) {
    final metadata = data['metadata'] is Map
        ? Map<String, dynamic>.from(data['metadata'] as Map)
        : const <String, dynamic>{};
    final coin = _safeInt(
      data['coin_amount'] ??
          data['coins'] ??
          data['medasicoin_amount'] ??
          metadata['coin_amount'] ??
          metadata['coins'] ??
          metadata['medasicoin_amount'],
    );
    final code = _safeText(
      data['code'] ?? data['product_code'] ?? data['slug'] ?? metadata['code'],
    );
    final kindText = _safeText(
      data['kind'] ?? data['type'] ?? metadata['kind'],
    );
    final kind = kindText.toLowerCase().contains('subscription') || coin == 0
        ? _StorePackageKind.subscription
        : _StorePackageKind.coin;
    final title = _firstText([
      data['title'],
      data['name'],
      metadata['title'],
    ], fallback: coin > 0 ? '$coin MC Paketi' : 'SourceBase Üyelik');
    return _MedasiCoinPackage(
      code: code,
      coin: coin,
      priceCents: _nullablePositiveInt(
        data['price_cents'] ?? data['amount_cents'] ?? metadata['price_cents'],
      ),
      title: title,
      description: _firstText(
        [data['description'], data['subtitle'], metadata['description']],
        fallback: coin > 0
            ? '$coin MC onaylı ödeme sonrası hesabına eklenir.'
            : 'Üyelik hakkı onaylı ödeme sonrası hesaba eklenir.',
      ),
      currency: _safeText(
        data['currency'] ?? metadata['currency'],
        fallback: 'TRY',
      ).toUpperCase(),
      kind: kind,
      sortOrder: _safeInt(data['sort_order'] ?? metadata['sort_order']),
    );
  }
}

class _StatePanel extends StatelessWidget {
  const _StatePanel({
    required this.icon,
    required this.title,
    required this.message,
    this.loading = false,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String message;
  final bool loading;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return SourceBaseLoadingState(icon: icon, title: title, message: message);
    }
    if (actionLabel != null && onAction != null) {
      return SourceBaseErrorState(
        icon: icon,
        title: title,
        message: message,
        actionLabel: actionLabel,
        onAction: onAction,
      );
    }
    return SourceBaseEmptyState(icon: icon, title: title, message: message);
  }
}

class _InlineActionPanel extends StatelessWidget {
  const _InlineActionPanel({
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return SourceBaseCard(
      padding: const EdgeInsets.all(18),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppColors.blue, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: AppColors.navy,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  message,
                  style: const TextStyle(
                    color: AppColors.muted,
                    fontSize: 13,
                    height: 1.35,
                  ),
                ),
                if (actionLabel != null && onAction != null) ...[
                  const SizedBox(height: 12),
                  SourceBaseButton(
                    label: actionLabel!,
                    onPressed: onAction,
                    variant: SourceBaseButtonVariant.secondary,
                    size: SBButtonSize.small,
                    fullWidth: false,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InlineNotice extends StatelessWidget {
  const _InlineNotice({required this.icon, required this.message});

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.selectedBlue,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.softLine),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppColors.blue, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: AppColors.muted,
                fontSize: 12,
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingsGroup extends StatelessWidget {
  const _SettingsGroup({required this.items});
  final List<_SettingsItem> items;

  @override
  Widget build(BuildContext context) {
    return SourceBaseCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          for (var i = 0; i < items.length; i++) ...[
            items[i],
            if (i < items.length - 1)
              const Divider(height: 1, indent: 56, color: AppColors.line),
          ],
        ],
      ),
    );
  }
}

class _SettingsItem extends StatelessWidget {
  const _SettingsItem({
    required this.icon,
    required this.title,
    required this.onTap,
    required this.description,
    this.enabled = true,
  });
  final IconData icon;
  final String title;
  final String description;
  final VoidCallback? onTap;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: enabled ? 1.0 : 0.45,
      child: Material(
        color: Colors.transparent,
        child: ListTile(
          leading: Icon(icon, color: AppColors.navy),
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 8,
                runSpacing: 4,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: AppColors.navy,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (!enabled)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.softBlue,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text(
                        'Bağlı değil',
                        style: TextStyle(
                          color: AppColors.blue,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                description,
                style: const TextStyle(
                  color: AppColors.muted,
                  fontSize: 12,
                  height: 1.25,
                ),
              ),
            ],
          ),
          trailing: enabled
              ? const Icon(Icons.chevron_right_rounded, color: AppColors.muted)
              : null,
          onTap: onTap,
        ),
      ),
    );
  }
}
