import 'package:flutter/material.dart';
import '../../../../core/design_system/design_system.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/sourcebase_brand.dart';
import '../../../auth/data/sourcebase_auth_backend.dart';
import '../../../drive/data/drive_models.dart';
import '../../../drive/presentation/widgets/drive_ui.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({
    required this.data,
    required this.onSearch,
    super.key,
  });

  final DriveWorkspaceData data;
  final VoidCallback onSearch;

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
        _ProfileHeader(displayName: displayName, email: email),
        const SizedBox(height: 24),
        const SectionTitle(title: 'İstatistikler'),
        _StatsGrid(data: data),
        const SizedBox(height: 12),
        const SectionTitle(title: 'Hesap Ayarları'),
        _SettingsGroup(
          items: [
            _SettingsItem(
              icon: Icons.person_outline_rounded,
              title: 'Profil Bilgileri',
              onTap: () {},
            ),
            _SettingsItem(
              icon: Icons.notifications_none_rounded,
              title: 'Bildirim Tercihleri',
              onTap: () {},
            ),
            _SettingsItem(
              icon: Icons.security_rounded,
              title: 'Güvenlik ve Şifre',
              onTap: () {},
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
              onTap: () {},
            ),
            _SettingsItem(
              icon: Icons.language_rounded,
              title: 'Dil (Türkçe)',
              onTap: () {},
            ),
            _SettingsItem(
              icon: Icons.info_outline_rounded,
              title: 'SourceBase Hakkında',
              onTap: () {},
            ),
          ],
        ),
        const SizedBox(height: 32),
        SBPrimaryButton(
          label: 'Çıkış Yap',
          icon: Icons.logout_rounded,
          onPressed: () async {
            await SourceBaseAuthBackend.signOut();
          },
          size: SBButtonSize.medium,
        ),
      ],
    );
  }
}

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({required this.displayName, required this.email});
  final String displayName;
  final String email;

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
            onPressed: () {},
            icon: const Icon(Icons.edit_outlined, color: AppColors.blue),
          ),
        ],
      ),
    );
  }
}

class _StatsGrid extends StatelessWidget {
  const _StatsGrid({required this.data});
  final DriveWorkspaceData data;

  @override
  Widget build(BuildContext context) {
    final fileCount = data.recentFiles.length;
    final collectionCount = data.collections.length;
    return Row(
      children: [
        Expanded(
          child: _StatCard(
            label: 'Toplam Dosya',
            value: fileCount.toString(),
            icon: Icons.description_outlined,
            color: AppColors.blue,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _StatCard(
            label: 'Koleksiyonlar',
            value: collectionCount.toString(),
            icon: Icons.layers_outlined,
            color: AppColors.purple,
          ),
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 14),
          Text(
            value,
            style: const TextStyle(
              color: AppColors.navy,
              fontSize: 28,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(color: AppColors.muted, fontSize: 14),
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
  });
  final IconData icon;
  final String title;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: AppColors.navy),
      title: Text(
        title,
        style: const TextStyle(
          color: AppColors.navy,
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
      ),
      trailing: const Icon(Icons.chevron_right_rounded, color: AppColors.muted),
      onTap: onTap,
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

