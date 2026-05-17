import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/sourcebase_brand.dart';
import '../../../auth/data/sourcebase_auth_backend.dart';
import '../../../drive/presentation/widgets/drive_ui.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({
    required this.onSearch,
    required this.onOpenStore,
    super.key,
  });

  final VoidCallback onSearch;
  final VoidCallback onOpenStore;

  Future<void> _signOut(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cikis Yap'),
        content: const Text('Hesabindan cikis yapmak istedigine emin misin?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Vazgec'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.red),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Cikis Yap'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    try {
      await SourceBaseAuthBackend.signOut();
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Cikis yapilirken bir sorun olustu.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = SourceBaseAuthBackend.currentUser;
    final displayName = user?.userMetadata?['display_name'] ?? 'Kullanıcı';
    final email = user?.email ?? 'E-posta tanımlı değil';

    return WorkspaceScroll(
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
                onPressed: onSearch,
                tooltip: 'Ara',
              ),
            ],
          ),
        ),
        _ProfileHeader(
          displayName: displayName,
          email: email,
          onEdit: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Profil düzenleme özelliği yakında aktif olacak.'),
                behavior: SnackBarBehavior.floating,
                duration: Duration(seconds: 2),
              ),
            );
          },
        ),
        const SizedBox(height: 24),
        const SectionTitle(title: 'Cüzdan'),
        _WalletPanel(onOpenStore: onOpenStore),
        const SizedBox(height: 12),
        const SectionTitle(title: 'Hesap Ayarları'),
        _SettingsGroup(
          items: [
            _SettingsItem(
              icon: Icons.person_outline_rounded,
              title: 'Profil Bilgileri',
              enabled: false,
              onTap: null,
            ),
            _SettingsItem(
              icon: Icons.notifications_none_rounded,
              title: 'Bildirim Tercihleri',
              enabled: false,
              onTap: null,
            ),
            _SettingsItem(
              icon: Icons.security_rounded,
              title: 'Güvenlik ve Şifre',
              enabled: false,
              onTap: null,
            ),
          ],
        ),
        const SizedBox(height: 12),
        const SectionTitle(title: 'Uygulama'),
        _SettingsGroup(
          items: [
            _SettingsItem(
              icon: Icons.dark_mode_outlined,
              title: 'Görünüm (Aydınlık)',
              enabled: false,
              onTap: null,
            ),
            _SettingsItem(
              icon: Icons.language_rounded,
              title: 'Dil (Türkçe)',
              enabled: false,
              onTap: null,
            ),
            _SettingsItem(
              icon: Icons.info_outline_rounded,
              title: 'SourceBase Hakkında',
              enabled: false,
              onTap: null,
            ),
          ],
        ),
        const SizedBox(height: 32),
        SBPrimaryButton(
          label: 'Çıkış Yap',
          icon: Icons.logout_rounded,
          onPressed: () => _signOut(context),
          size: SBButtonSize.medium,
        ),
      ],
    );
  }
}

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({
    required this.displayName,
    required this.email,
    required this.onEdit,
  });
  final String displayName;
  final String email;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      padding: const EdgeInsets.all(24),
      child: Row(
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: const BoxDecoration(
              gradient: AppColors.primaryGradient,
              shape: BoxShape.circle,
            ),
            child: const Center(
              child: Icon(Icons.person_rounded, color: Colors.white, size: 40),
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  displayName,
                  style: const TextStyle(
                    color: AppColors.navy,
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  email,
                  style: const TextStyle(color: AppColors.muted, fontSize: 16),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: onEdit,
            tooltip: 'Profili düzenle',
            icon: const Icon(Icons.edit_outlined, color: AppColors.blue),
          ),
        ],
      ),
    );
  }
}

class _WalletPanel extends StatelessWidget {
  const _WalletPanel({required this.onOpenStore});

  final VoidCallback onOpenStore;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_MedasiWalletBalance>(
      future: _MedasiWalletBalance.load(),
      builder: (context, snapshot) {
        final balance = snapshot.data ?? const _MedasiWalletBalance(0);
        final loading = snapshot.connectionState == ConnectionState.waiting;
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
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 160),
                          child: Text(
                            loading ? '...' : balance.label,
                            key: ValueKey(loading ? 'loading' : balance.label),
                            style: const TextStyle(
                              color: AppColors.navy,
                              fontSize: 30,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
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
      },
    );
  }
}

class _MedasiWalletBalance {
  const _MedasiWalletBalance(this.amount);

  final double amount;

  String get label => '${_formatAmount(amount)} MC';

  static Future<_MedasiWalletBalance> load() async {
    final client = SourceBaseAuthBackend.client;
    final userId = SourceBaseAuthBackend.currentUser?.id;
    if (client == null || userId == null) {
      return const _MedasiWalletBalance(0);
    }

    try {
      final row = await client
          .from('profiles')
          .select('wallet_balance')
          .eq('id', userId)
          .maybeSingle();
      return _MedasiWalletBalance(_parse(row?['wallet_balance']) ?? 0);
    } catch (_) {
      return const _MedasiWalletBalance(0);
    }
  }

  static double? _parse(Object? raw) {
    if (raw is num) return raw.toDouble();
    if (raw is String) return double.tryParse(raw.trim());
    return null;
  }

  static String _formatAmount(double value) {
    if (value == value.roundToDouble()) {
      return value.toStringAsFixed(0);
    }
    return value.toStringAsFixed(2).replaceFirst(RegExp(r'0+$'), '');
  }
}

class MedasiCoinStoreScreen extends StatelessWidget {
  const MedasiCoinStoreScreen({
    required this.onSearch,
    required this.onBack,
    super.key,
  });

  final VoidCallback onSearch;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return WorkspaceScroll(
      children: [
        DriveTopBar(
          title: 'MedAsiCoin Mağazası',
          onSearch: onSearch,
          onBack: onBack,
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
                'Qlinik bakiyen SourceBase cüzdanında da kullanılır.',
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
          future: _MedasiCoinPackage.loadStoreProducts(),
          builder: (context, snapshot) {
            final packages = snapshot.data ?? _MedasiCoinPackage.fallback;
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

  Future<void> _purchase() async {
    setState(() {
      _buying = true;
      _buyError = null;
    });
    try {
      final client = SourceBaseAuthBackend.client;
      if (client == null) {
        setState(() => _buyError = 'Giris yapmaniz gerekiyor.');
        return;
      }
      final result = await client.functions.invoke(
        'sourcebase',
        body: {
          'action': 'purchase_medasicoin',
          'payload': {
            'product_code': widget.package.code,
            'success_url': '${SourceBaseAuthConfig.publicUrl}/home',
            'cancel_url':
                '${SourceBaseAuthConfig.publicUrl}/home?cancelled=1',
          },
        },
      );
      final json = result.data as Map<String, dynamic>;
      if (json['ok'] == true && json['data']?['url'] != null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Odeme sayfasina yonlendiriliyorsunuz...'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      } else {
        setState(
          () => _buyError = json['error']?['message'] ?? 'Odeme baslatilamadi.',
        );
      }
    } catch (_) {
      if (mounted) {
        setState(() => _buyError = 'Odeme baslatilamadi. Lutfen tekrar deneyin.');
      }
    } finally {
      if (mounted) setState(() => _buying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      child: Column(
        children: [
          Row(
            children: [
              Container(
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
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  '${widget.package.coin} MC',
                  style: const TextStyle(
                    color: AppColors.navy,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              Text(
                '${widget.package.priceTl} TL',
                style: const TextStyle(
                  color: AppColors.blue,
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                height: 40,
                child: FilledButton(
                  onPressed: _buying ? null : _purchase,
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
                      : const Text(
                          'Satın Al',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                ),
              ),
            ],
          ),
          if (_buyError != null) ...[
            const SizedBox(height: 8),
            Text(
              _buyError!,
              style: const TextStyle(
                color: AppColors.red,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _MedasiCoinPackage {
  const _MedasiCoinPackage({
    required this.code,
    required this.coin,
    required this.priceCents,
  });

  static const fallback = [
    _MedasiCoinPackage(code: 'mc_10', coin: 10, priceCents: 4000),
    _MedasiCoinPackage(code: 'mc_20', coin: 20, priceCents: 6500),
    _MedasiCoinPackage(code: 'mc_50', coin: 50, priceCents: 18000),
  ];

  static const _codes = ['mc_10', 'mc_20', 'mc_50'];

  final String code;
  final int coin;
  final int priceCents;

  int get priceTl => priceCents ~/ 100;

  static Future<List<_MedasiCoinPackage>> loadStoreProducts() async {
    final client = SourceBaseAuthBackend.client;
    if (client == null) {
      return fallback;
    }

    try {
      final rows = await client
          .from('store_products')
          .select('code, coin_amount, price_cents, sort_order')
          .inFilter('code', _codes)
          .eq('is_active', true)
          .order('sort_order');
      final packages = rows
          .map(
            (row) => _MedasiCoinPackage(
              code: row['code']?.toString() ?? '',
              coin: _intFrom(row['coin_amount']),
              priceCents: _intFrom(row['price_cents']),
            ),
          )
          .where((item) => _codes.contains(item.code) && item.coin > 0)
          .toList();
      return packages.isEmpty ? fallback : packages;
    } catch (_) {
      return fallback;
    }
  }

  static int _intFrom(Object? raw) {
    if (raw is int) return raw;
    if (raw is num) return raw.round();
    if (raw is String) return double.tryParse(raw)?.round() ?? 0;
    return 0;
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
    this.enabled = true,
  });
  final IconData icon;
  final String title;
  final VoidCallback? onTap;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: enabled ? 1.0 : 0.45,
      child: ListTile(
        leading: Icon(icon, color: AppColors.navy),
        title: Row(
          children: [
            Text(
              title,
              style: const TextStyle(
                color: AppColors.navy,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (!enabled) ...[
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.softBlue,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  'Yakında',
                  style: TextStyle(
                    color: AppColors.blue,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
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
