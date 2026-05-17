import 'package:flutter/material.dart';
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

  Future<void> _signOut(BuildContext context) async {
    if (_signingOut) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Çıkış Yap'),
        content: const Text('Hesabından çıkış yapmak istediğine emin misin?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.red),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Çıkış Yap'),
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
            content: Text('Çıkış yapılırken bir sorun oluştu.'),
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
        Padding(
          padding: const EdgeInsets.only(bottom: 24),
          child: Row(
            children: [
              const SourceBaseBrand(compact: true),
              const _TopDivider(),
              const Expanded(
                child: Text(
                  'Profil',
                  style: TextStyle(
                    color: AppColors.blue,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              SBIconButton(
                icon: Icons.search_rounded,
                onPressed: widget.onSearch,
                tooltip: 'Ara',
              ),
            ],
          ),
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
                _ProfileHeader(
                  profile: current,
                  onEdit: () {
                    if (current.isComplete) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Profil düzenleme özelliği yakında aktif olacak.',
                          ),
                          behavior: SnackBarBehavior.floating,
                          duration: Duration(seconds: 2),
                        ),
                      );
                      return;
                    }
                    Navigator.of(context).pushNamed(ProfileSetupScreen.route);
                  },
                ),
                if (!current.isComplete) ...[
                  const SizedBox(height: 12),
                  _ProfileCompletionPanel(
                    onComplete: () => Navigator.of(
                      context,
                    ).pushNamed(ProfileSetupScreen.route),
                  ),
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
                const _SettingsGroup(
                  items: [
                    _SettingsItem(
                      icon: Icons.person_outline_rounded,
                      title: 'Profil Bilgileri',
                      description:
                          'Fakülte, bölüm ve sınıf bilgileri profil tamamlama ekranından yönetilir.',
                      enabled: false,
                      onTap: null,
                    ),
                    _SettingsItem(
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
                          'Şifre işlemleri mevcut auth akışlarından yapılır.',
                      enabled: false,
                      onTap: null,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const SectionTitle(title: 'Uygulama'),
                const _SettingsGroup(
                  items: [
                    _SettingsItem(
                      icon: Icons.dark_mode_outlined,
                      title: 'Görünüm',
                      description:
                          'Tema seçimi bu sürümde sabit aydınlık modda.',
                      enabled: false,
                      onTap: null,
                    ),
                    _SettingsItem(
                      icon: Icons.language_rounded,
                      title: 'Dil',
                      description:
                          'SourceBase şu anda Türkçe arayüzle çalışır.',
                      enabled: false,
                      onTap: null,
                    ),
                    _SettingsItem(
                      icon: Icons.info_outline_rounded,
                      title: 'SourceBase Hakkında',
                      description:
                          'Sürüm ve yasal metin bağlantıları henüz yayınlanmadı.',
                      enabled: false,
                      onTap: null,
                    ),
                  ],
                ),
                const SizedBox(height: 32),
                SBPrimaryButton(
                  label: _signingOut ? 'Çıkış Yapılıyor...' : 'Çıkış Yap',
                  icon: Icons.logout_rounded,
                  onPressed: _signingOut ? null : () => _signOut(context),
                  loading: _signingOut,
                  size: SBButtonSize.medium,
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
    final user = SourceBaseAuthBackend.currentUser;
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
            .maybeSingle();
        if (row != null) {
          profileRow = Map<String, dynamic>.from(row);
        }
      } catch (_) {
        profileLoadFailed = true;
      }
    }

    _UserStats stats = _UserStats.empty;
    var statsLoadFailed = false;
    try {
      final workspace = await const DriveRepository().loadWorkspace();
      stats = _UserStats.fromWorkspace(workspace);
    } catch (_) {
      statsLoadFailed = true;
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
    final user = SourceBaseAuthBackend.currentUser;
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
  if (normalized.contains('cancel')) {
    return 'Satın alma iptal edildi.';
  }
  if (normalized.contains('auth') || normalized.contains('session')) {
    return 'Satın alma için yeniden giriş yapman gerekiyor.';
  }
  return 'Ödeme başlatılamadı. Lütfen tekrar deneyin.';
}

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({required this.profile, required this.onEdit});
  final _ProfileSnapshot profile;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      padding: const EdgeInsets.all(24),
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
                style: const TextStyle(
                  color: AppColors.navy,
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  height: 1.08,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                profile.email,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: AppColors.muted, fontSize: 15),
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
    return Container(
      constraints: const BoxConstraints(maxWidth: 260),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: AppColors.selectedBlue,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.softLine),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: AppColors.blue, size: 16),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppColors.navy,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CompletionBadge extends StatelessWidget {
  const _CompletionBadge({required this.completed});

  final bool completed;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: completed ? AppColors.greenBg : AppColors.redBg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        completed ? 'Profil tamamlandı' : 'Profil bilgileri eksik',
        style: TextStyle(
          color: completed ? AppColors.green : AppColors.red,
          fontSize: 12,
          fontWeight: FontWeight.w800,
        ),
      ),
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
                icon: Icons.auto_awesome_outlined,
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
      button: true,
      label: 'MedAsiCoin cüzdanı, ${balance.label}. Mağazaya git.',
      child: InkWell(
        onTap: onOpenStore,
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
                      'MedAsiCoin',
                      style: TextStyle(
                        color: AppColors.muted,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      balance.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.navy,
                        fontSize: 30,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    if (loadFailed) ...[
                      const SizedBox(height: 6),
                      const Text(
                        'Bakiye yüklenemedi, güvenli yedek değer gösteriliyor.',
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
  const _MedasiWalletBalance(this.amount);

  final double amount;

  String get label => '${_formatAmount(amount)} MC';

  static _MedasiWalletBalance fromProfileRow(Map<String, dynamic> row) {
    return _MedasiWalletBalance(
      _safeDouble(
        row['wallet_balance'] ??
            row['medasicoin_balance'] ??
            row['medasi_coin_balance'] ??
            row['coin_balance'] ??
            row['credits'] ??
            row['credit_balance'],
      ),
    );
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

  @override
  void initState() {
    super.initState();
    _packagesFuture = _MedasiCoinPackage.loadStoreProducts();
  }

  Future<void> _refreshPackages() async {
    setState(() => _packagesFuture = _MedasiCoinPackage.loadStoreProducts());
    await _packagesFuture;
  }

  @override
  Widget build(BuildContext context) {
    return WorkspaceScroll(
      onRefresh: _refreshPackages,
      children: [
        DriveTopBar(
          title: 'MedAsiCoin Mağazası',
          onSearch: widget.onSearch,
          onBack: widget.onBack,
          showBrand: false,
        ),
        GlassPanel(
          padding: const EdgeInsets.all(22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  gradient: AppColors.brandGradient,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: const Icon(
                  Icons.monetization_on_rounded,
                  color: Colors.white,
                  size: 34,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'MedAsiCoin Paketleri',
                style: TextStyle(
                  color: AppColors.navy,
                  fontSize: 26,
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
                title: 'Mağaza yüklenemedi',
                message: 'Paketler şu anda alınamadı. Lütfen tekrar dene.',
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
                title: 'Aktif paket yok',
                message:
                    'Satın alınabilir paket bulunamadı. Paketler aktif edildiğinde burada görünecek.',
              );
            }
            return Column(
              children: [
                for (final item in packages) ...[
                  _StorePackageTile(package: item),
                  const SizedBox(height: 12),
                ],
              ],
            );
          },
        ),
      ],
    );
  }
}

class _StorePackageTile extends StatefulWidget {
  const _StorePackageTile({required this.package});

  final _MedasiCoinPackage package;

  @override
  State<_StorePackageTile> createState() => _StorePackageTileState();
}

class _StorePackageTileState extends State<_StorePackageTile> {
  bool _buying = false;
  String? _buyError;
  String? _buyInfo;

  Future<void> _purchase() async {
    if (_buying) return;
    if (!widget.package.canPurchase) {
      setState(() {
        _buyError = 'Bu paket için fiyat veya ürün bilgisi eksik.';
        _buyInfo = null;
      });
      return;
    }
    setState(() {
      _buying = true;
      _buyError = null;
      _buyInfo = null;
    });
    try {
      final client = SourceBaseAuthBackend.client;
      if (client == null) {
        setState(() => _buyError = 'Satın alma için giriş yapman gerekiyor.');
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
        setState(() => _buyError = 'Ödeme cevabı okunamadı.');
        return;
      }
      final data = json['data'];
      final checkoutUrl = data is Map ? _safeText(data['url']) : '';
      if (json['ok'] == true && checkoutUrl.isNotEmpty) {
        if (!mounted) return;
        setState(
          () => _buyInfo =
              'Ödeme sayfası hazırlandı. Uygulama içi ödeme yönlendirmesi henüz bağlı değil; bakiye onaylı ödeme sonrası güncellenir.',
        );
      } else if (json['ok'] == true) {
        if (!mounted) return;
        setState(
          () => _buyInfo =
              'Ödeme işlemi başlatıldı. Bakiye yalnızca backend onayı sonrası güncellenir.',
        );
      } else {
        final error = json['error'];
        final message = error is Map ? _safeText(error['message']) : '';
        setState(() => _buyError = _friendlyPurchaseError(message));
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _buyError = 'Ödeme başlatılamadı. Lütfen tekrar deneyin.',
        );
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
          final compact = constraints.maxWidth < 430;
          final leading = Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: AppColors.selectedBlue,
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.toll_rounded,
              color: AppColors.blue,
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
            ],
          );
          final price = Text(
            widget.package.priceLabel,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: widget.package.hasPrice ? AppColors.blue : AppColors.muted,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          );
          final button = SizedBox(
            width: compact ? double.infinity : 124,
            height: 42,
            child: FilledButton(
              onPressed: _buying || !widget.package.canPurchase
                  ? null
                  : _purchase,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.blue,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
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
                        'Satın Al',
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
                Row(
                  children: [
                    Expanded(child: price),
                    const SizedBox(width: 12),
                  ],
                ),
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
                  'Bu paket satışa hazır değil.',
                  style: TextStyle(
                    color: AppColors.muted,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
              if (_buyInfo != null) ...[
                const SizedBox(height: 8),
                Text(
                  _buyInfo!,
                  style: const TextStyle(
                    color: AppColors.blue,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    height: 1.3,
                  ),
                ),
              ],
              if (_buyError != null) ...[
                const SizedBox(height: 8),
                Text(
                  _buyError!,
                  style: const TextStyle(
                    color: AppColors.red,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    height: 1.3,
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _MedasiCoinPackage {
  const _MedasiCoinPackage({
    required this.code,
    required this.coin,
    required this.priceCents,
    required this.title,
    required this.description,
    required this.currency,
  });

  final String code;
  final int coin;
  final int? priceCents;
  final String title;
  final String description;
  final String currency;

  bool get hasPrice => priceCents != null && priceCents! > 0;
  bool get canPurchase => code.isNotEmpty && coin > 0 && hasPrice;
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

    final rows = await client
        .from('store_products')
        .select()
        .eq('is_active', true)
        .order('sort_order');
    return rows
        .map((row) {
          final data = Map<String, dynamic>.from(row);
          final coin = _safeInt(
            data['coin_amount'] ?? data['coins'] ?? data['medasicoin_amount'],
          );
          final title = _firstText([
            data['title'],
            data['name'],
          ], fallback: coin > 0 ? '$coin MC Paketi' : 'MedAsiCoin Paketi');
          return _MedasiCoinPackage(
            code: _safeText(data['code'] ?? data['product_code']),
            coin: coin,
            priceCents: _nullablePositiveInt(
              data['price_cents'] ?? data['amount_cents'],
            ),
            title: title,
            description: _firstText(
              [data['description'], data['subtitle']],
              fallback: coin > 0
                  ? '$coin MedAsiCoin hesabına onaylı ödeme sonrası eklenir.'
                  : 'Paket hakkı onaylı ödeme sonrası hesaba eklenir.',
            ),
            currency: _safeText(data['currency'], fallback: 'TL').toUpperCase(),
          );
        })
        .where((item) => item.code.isNotEmpty && item.coin > 0)
        .toList();
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
    return GlassPanel(
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          loading
              ? const SizedBox(
                  width: 28,
                  height: 28,
                  child: CircularProgressIndicator(strokeWidth: 2.5),
                )
              : Icon(icon, color: AppColors.blue, size: 30),
          const SizedBox(height: 14),
          Text(
            title,
            style: const TextStyle(
              color: AppColors.navy,
              fontSize: 20,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            message,
            style: const TextStyle(
              color: AppColors.muted,
              fontSize: 14,
              height: 1.35,
            ),
          ),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: 16),
            SizedBox(
              height: 42,
              child: FilledButton(
                onPressed: onAction,
                child: Text(actionLabel!),
              ),
            ),
          ],
        ],
      ),
    );
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
    return GlassPanel(
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
                  SizedBox(
                    height: 38,
                    child: FilledButton(
                      onPressed: onAction,
                      child: Text(actionLabel!),
                    ),
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
    return GlassPanel(
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
    );
  }
}

class _TopDivider extends StatelessWidget {
  const _TopDivider();
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 24,
      margin: const EdgeInsets.symmetric(horizontal: 18),
      color: const Color(0xFFE2E8F0),
    );
  }
}
