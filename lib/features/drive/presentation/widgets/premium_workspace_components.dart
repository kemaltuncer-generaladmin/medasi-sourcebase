import 'package:flutter/material.dart';

import '../../../../core/design_system/components/sourcebase_card.dart';
import '../../../../core/theme/app_colors.dart';
import '../../data/drive_models.dart';
import 'drive_ui.dart';

class PremiumPageScaffold extends StatelessWidget {
  const PremiumPageScaffold({
    required this.children,
    this.onRefresh,
    super.key,
  });

  final List<Widget> children;
  final RefreshCallback? onRefresh;

  @override
  Widget build(BuildContext context) {
    return WorkspaceScroll(onRefresh: onRefresh, children: children);
  }
}

class MetricPillData {
  const MetricPillData({
    required this.label,
    required this.value,
    this.tint = AppColors.blue,
    this.icon,
  });

  final String label;
  final String value;
  final Color tint;
  final IconData? icon;
}

class MetricPill extends StatelessWidget {
  const MetricPill({
    required this.label,
    required this.value,
    this.tint = AppColors.blue,
    this.icon,
    super.key,
  });

  final String label;
  final String value;
  final Color tint;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: tint.withValues(alpha: .08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: tint.withValues(alpha: .16)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, color: tint, size: 16),
            const SizedBox(width: 8),
          ],
          Text(
            value,
            style: TextStyle(
              color: tint,
              fontSize: 15,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: AppColors.navy,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

enum PremiumStatus {
  ready,
  processing,
  failed,
  draft,
  selected,
  eligible,
  ineligible,
  fresh,
  recommended,
}

class StatusBadge extends StatelessWidget {
  const StatusBadge({
    required this.label,
    required this.status,
    this.compact = false,
    super.key,
  });

  final String label;
  final PremiumStatus status;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final tone = _statusTone(status);
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 9 : 10,
        vertical: compact ? 5 : 6,
      ),
      decoration: BoxDecoration(
        color: tone.background,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: tone.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(tone.icon, color: tone.foreground, size: compact ? 13 : 14),
          SizedBox(width: compact ? 4 : 6),
          Text(
            label,
            style: TextStyle(
              color: tone.foreground,
              fontSize: compact ? 11 : 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class PremiumHeroCard extends StatelessWidget {
  const PremiumHeroCard({
    required this.eyebrow,
    required this.title,
    required this.description,
    this.metrics = const [],
    this.actions = const [],
    this.anchorIcon = Icons.auto_awesome_rounded,
    this.anchorLabel,
    this.tint = AppColors.blue,
    super.key,
  });

  final String eyebrow;
  final String title;
  final String description;
  final List<MetricPillData> metrics;
  final List<Widget> actions;
  final IconData anchorIcon;
  final String? anchorLabel;
  final Color tint;

  @override
  Widget build(BuildContext context) {
    return SourceBaseCard(
      radius: 24,
      padding: const EdgeInsets.fromLTRB(22, 22, 22, 20),
      backgroundColor: const Color(0xFFFFFEFE),
      borderColor: AppColors.line.withValues(alpha: .9),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 620;
          final text = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: tint.withValues(alpha: .08),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: tint.withValues(alpha: .12)),
                ),
                child: Text(
                  eyebrow,
                  style: TextStyle(
                    color: tint,
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                title,
                style: TextStyle(
                  color: AppColors.navy,
                  fontSize: compact ? 29 : 34,
                  fontWeight: FontWeight.w900,
                  height: 1.06,
                ),
              ),
              const SizedBox(height: 10),
              ConstrainedBox(
                constraints: BoxConstraints(maxWidth: compact ? 520 : 560),
                child: Text(
                  description,
                  style: TextStyle(
                    color: AppColors.muted,
                    fontSize: compact ? 15 : 16,
                    height: 1.4,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (metrics.isNotEmpty) ...[
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final metric in metrics)
                      MetricPill(
                        label: metric.label,
                        value: metric.value,
                        tint: metric.tint,
                        icon: metric.icon,
                      ),
                  ],
                ),
              ],
              if (actions.isNotEmpty) ...[
                const SizedBox(height: 18),
                Wrap(spacing: 10, runSpacing: 10, children: actions),
              ],
            ],
          );

          final anchor = _HeroAnchor(
            tint: tint,
            icon: anchorIcon,
            label: anchorLabel,
          );

          if (compact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                text,
                const SizedBox(height: 18),
                Align(alignment: Alignment.centerRight, child: anchor),
              ],
            );
          }

          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: text),
              const SizedBox(width: 16),
              anchor,
            ],
          );
        },
      ),
    );
  }
}

class DenseFeatureCard extends StatelessWidget {
  const DenseFeatureCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.primaryMetric,
    required this.ctaLabel,
    required this.onTap,
    this.tags = const [],
    this.secondaryMetric,
    this.trailingNote,
    this.tint = AppColors.blue,
    super.key,
  });

  final IconData icon;
  final String title;
  final String description;
  final String primaryMetric;
  final String ctaLabel;
  final VoidCallback onTap;
  final List<String> tags;
  final String? secondaryMetric;
  final String? trailingNote;
  final Color tint;

  @override
  Widget build(BuildContext context) {
    return SourceBaseCard(
      radius: 18,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: tint.withValues(alpha: .10),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: tint, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.navy,
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                        height: 1.1,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      description,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.muted,
                        fontSize: 13,
                        height: 1.4,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (tags.isNotEmpty)
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final tag in tags.take(3))
                  _MiniTag(label: tag, tint: tint),
              ],
            ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _DenseMetric(label: 'Çıktı', value: primaryMetric),
              ),
              if (secondaryMetric != null) ...[
                const SizedBox(width: 10),
                Expanded(
                  child: _DenseMetric(label: 'Not', value: secondaryMetric!),
                ),
              ],
            ],
          ),
          if (trailingNote != null) ...[
            const SizedBox(height: 12),
            Text(
              trailingNote!,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppColors.muted,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
          const SizedBox(height: 14),
          SBPrimaryButton(
            label: ctaLabel,
            icon: Icons.arrow_forward_rounded,
            onPressed: onTap,
            size: SBButtonSize.small,
            fullWidth: true,
          ),
        ],
      ),
    );
  }
}

class SourcePreviewCard extends StatelessWidget {
  const SourcePreviewCard({
    required this.file,
    required this.onTap,
    this.ctaLabel = 'Aç',
    this.trailing,
    super.key,
  });

  final DriveFile file;
  final VoidCallback onTap;
  final String ctaLabel;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final status = driveStatusInfo(file.status);
    return SourceBaseCard(
      radius: 18,
      padding: const EdgeInsets.all(16),
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              FileKindBadge(kind: file.kind, plain: true),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      file.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.navy,
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        height: 1.12,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        StatusBadge(
                          label: status.label,
                          status: _premiumStatusForDrive(file.status),
                          compact: true,
                        ),
                        _MiniTag(
                          label: FileKindBadge.kindLabel(file.kind),
                          tint: FileKindBadge.kindColor(file.kind),
                        ),
                        if ((file.tag ?? '').trim().isNotEmpty)
                          _MiniTag(label: file.tag!, tint: AppColors.purple),
                      ],
                    ),
                  ],
                ),
              ),
              ...switch (trailing) {
                final Widget widget => [widget],
                _ => const <Widget>[],
              },
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _InlineMeta(
                icon: Icons.menu_book_rounded,
                text: file.courseTitle,
              ),
              _InlineMeta(icon: Icons.folder_outlined, text: file.sectionTitle),
              _InlineMeta(
                icon: Icons.description_outlined,
                text: file.pageLabel,
              ),
              _InlineMeta(
                icon: Icons.data_object_rounded,
                text: file.sizeLabel,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            driveFriendlyStatusDescription(file),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppColors.muted,
              fontSize: 13,
              height: 1.35,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Güncellendi: ${file.updatedLabel}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.softText,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                ctaLabel,
                style: const TextStyle(
                  color: AppColors.blue,
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class PremiumEmptyState extends StatelessWidget {
  const PremiumEmptyState({
    required this.icon,
    required this.title,
    required this.message,
    this.badges = const [],
    this.actionLabel,
    this.onAction,
    this.secondaryLabel,
    this.onSecondaryAction,
    super.key,
  });

  final IconData icon;
  final String title;
  final String message;
  final List<String> badges;
  final String? actionLabel;
  final VoidCallback? onAction;
  final String? secondaryLabel;
  final VoidCallback? onSecondaryAction;

  @override
  Widget build(BuildContext context) {
    return SourceBaseCard(
      radius: 22,
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              color: AppColors.selectedBlue,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Icon(icon, color: AppColors.blue, size: 30),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: const TextStyle(
              color: AppColors.navy,
              fontSize: 22,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            message,
            style: const TextStyle(
              color: AppColors.muted,
              fontSize: 15,
              height: 1.4,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (badges.isNotEmpty) ...[
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final badge in badges)
                  _MiniTag(label: badge, tint: AppColors.blue),
              ],
            ),
          ],
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: 18),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                SBPrimaryButton(
                  label: actionLabel!,
                  icon: Icons.arrow_forward_rounded,
                  onPressed: onAction,
                  size: SBButtonSize.small,
                  fullWidth: false,
                ),
                if (secondaryLabel != null && onSecondaryAction != null)
                  SBSecondaryButton(
                    label: secondaryLabel!,
                    icon: Icons.open_in_new_rounded,
                    onPressed: onSecondaryAction,
                    size: SBButtonSize.small,
                    fullWidth: false,
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class ProcessingCard extends StatelessWidget {
  const ProcessingCard({
    required this.title,
    required this.message,
    this.progressLabel,
    this.tags = const [],
    super.key,
  });

  final String title;
  final String message;
  final String? progressLabel;
  final List<String> tags;

  @override
  Widget build(BuildContext context) {
    return SourceBaseCard(
      radius: 20,
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.selectedBlue,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Padding(
                  padding: EdgeInsets.all(10),
                  child: CircularProgressIndicator(
                    strokeWidth: 2.6,
                    color: AppColors.blue,
                  ),
                ),
              ),
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
                    if (progressLabel != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        progressLabel!,
                        style: const TextStyle(
                          color: AppColors.blue,
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            message,
            style: const TextStyle(
              color: AppColors.muted,
              fontSize: 14,
              height: 1.4,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (tags.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final tag in tags)
                  _MiniTag(label: tag, tint: AppColors.blue),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class ResultPreviewCard extends StatelessWidget {
  const ResultPreviewCard({
    required this.icon,
    required this.title,
    required this.source,
    required this.createdAt,
    required this.preview,
    required this.primaryActionLabel,
    required this.onPrimaryAction,
    this.statusLabel,
    this.onSecondaryAction,
    this.secondaryActionLabel,
    this.tint = AppColors.blue,
    super.key,
  });

  final IconData icon;
  final String title;
  final String source;
  final String createdAt;
  final String preview;
  final String primaryActionLabel;
  final VoidCallback onPrimaryAction;
  final String? statusLabel;
  final VoidCallback? onSecondaryAction;
  final String? secondaryActionLabel;
  final Color tint;

  @override
  Widget build(BuildContext context) {
    return SourceBaseCard(
      radius: 18,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: tint.withValues(alpha: .10),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: tint),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.navy,
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      source,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.muted,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              if (statusLabel != null)
                StatusBadge(
                  label: statusLabel!,
                  status: PremiumStatus.ready,
                  compact: true,
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            preview,
            maxLines: 4,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppColors.navy,
              fontSize: 13,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            createdAt,
            style: const TextStyle(
              color: AppColors.softText,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              SBPrimaryButton(
                label: primaryActionLabel,
                icon: Icons.open_in_new_rounded,
                onPressed: onPrimaryAction,
                size: SBButtonSize.small,
                fullWidth: false,
              ),
              if (secondaryActionLabel != null && onSecondaryAction != null)
                SBSecondaryButton(
                  label: secondaryActionLabel!,
                  icon: Icons.refresh_rounded,
                  onPressed: onSecondaryAction,
                  size: SBButtonSize.small,
                  fullWidth: false,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class WalletMiniCard extends StatelessWidget {
  const WalletMiniCard({
    required this.balanceLabel,
    required this.rightsLabel,
    required this.onOpenStore,
    this.title = 'MC Bakiyesi',
    this.actionLabel = 'Store',
    this.loadFailed = false,
    super.key,
  });

  final String balanceLabel;
  final String rightsLabel;
  final VoidCallback onOpenStore;
  final String title;
  final String actionLabel;
  final bool loadFailed;

  @override
  Widget build(BuildContext context) {
    return SourceBaseCard(
      radius: 20,
      padding: const EdgeInsets.all(18),
      borderColor: AppColors.blue.withValues(alpha: .14),
      child: Row(
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              gradient: AppColors.brandGradient,
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Icon(
              Icons.account_balance_wallet_rounded,
              color: Colors.white,
              size: 28,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: AppColors.muted,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  balanceLabel,
                  style: TextStyle(
                    color: loadFailed ? AppColors.red : AppColors.navy,
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  rightsLabel,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.muted,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          SBSecondaryButton(
            label: actionLabel,
            icon: Icons.storefront_rounded,
            onPressed: onOpenStore,
            size: SBButtonSize.small,
            fullWidth: false,
          ),
        ],
      ),
    );
  }
}

class _HeroAnchor extends StatelessWidget {
  const _HeroAnchor({required this.tint, required this.icon, this.label});

  final Color tint;
  final IconData icon;
  final String? label;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 144,
      height: 140,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            top: 12,
            right: 8,
            child: Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                color: tint.withValues(alpha: .08),
                borderRadius: BorderRadius.circular(26),
              ),
            ),
          ),
          Positioned(
            left: 0,
            bottom: 0,
            child: Container(
              width: 110,
              height: 110,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    tint.withValues(alpha: .96),
                    tint.withValues(alpha: .68),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(28),
                boxShadow: [
                  BoxShadow(
                    color: tint.withValues(alpha: .20),
                    blurRadius: 24,
                    offset: const Offset(0, 12),
                  ),
                ],
              ),
              child: Icon(icon, color: Colors.white, size: 46),
            ),
          ),
          if (label != null)
            Positioned(
              right: 0,
              bottom: 18,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: AppColors.softLine),
                ),
                child: Text(
                  label!,
                  style: const TextStyle(
                    color: AppColors.navy,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _DenseMetric extends StatelessWidget {
  const _DenseMetric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.page,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.softLine),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: AppColors.muted,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            value,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppColors.navy,
              fontSize: 13,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _InlineMeta extends StatelessWidget {
  const _InlineMeta({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: AppColors.page,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.softLine),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: AppColors.muted, size: 14),
          const SizedBox(width: 6),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 164),
            child: Text(
              text,
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

class _MiniTag extends StatelessWidget {
  const _MiniTag({required this.label, required this.tint});

  final String label;
  final Color tint;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: tint.withValues(alpha: .08),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: tint,
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _StatusTone {
  const _StatusTone(this.foreground, this.background, this.border, this.icon);

  final Color foreground;
  final Color background;
  final Color border;
  final IconData icon;
}

_StatusTone _statusTone(PremiumStatus status) {
  return switch (status) {
    PremiumStatus.ready => _StatusTone(
      AppColors.green,
      AppColors.greenBg,
      AppColors.green.withValues(alpha: .16),
      Icons.check_circle_rounded,
    ),
    PremiumStatus.processing => _StatusTone(
      AppColors.blue,
      AppColors.selectedBlue,
      AppColors.blue.withValues(alpha: .14),
      Icons.hourglass_top_rounded,
    ),
    PremiumStatus.failed => _StatusTone(
      AppColors.red,
      AppColors.redBg,
      AppColors.red.withValues(alpha: .14),
      Icons.error_outline_rounded,
    ),
    PremiumStatus.draft => _StatusTone(
      AppColors.warning,
      AppColors.warningBg,
      AppColors.warning.withValues(alpha: .14),
      Icons.edit_note_rounded,
    ),
    PremiumStatus.selected => _StatusTone(
      AppColors.blue,
      AppColors.selectedBlue,
      AppColors.blue.withValues(alpha: .14),
      Icons.done_all_rounded,
    ),
    PremiumStatus.eligible => _StatusTone(
      AppColors.green,
      AppColors.greenBg,
      AppColors.green.withValues(alpha: .14),
      Icons.verified_rounded,
    ),
    PremiumStatus.ineligible => _StatusTone(
      AppColors.red,
      AppColors.redBg,
      AppColors.red.withValues(alpha: .14),
      Icons.block_rounded,
    ),
    PremiumStatus.fresh => _StatusTone(
      AppColors.cyan,
      AppColors.cyan.withValues(alpha: .10),
      AppColors.cyan.withValues(alpha: .14),
      Icons.fiber_new_rounded,
    ),
    PremiumStatus.recommended => _StatusTone(
      AppColors.purple,
      AppColors.purple.withValues(alpha: .10),
      AppColors.purple.withValues(alpha: .14),
      Icons.workspace_premium_rounded,
    ),
  };
}

PremiumStatus _premiumStatusForDrive(DriveItemStatus status) {
  return switch (status) {
    DriveItemStatus.completed => PremiumStatus.ready,
    DriveItemStatus.processing ||
    DriveItemStatus.uploading => PremiumStatus.processing,
    DriveItemStatus.failed => PremiumStatus.failed,
    DriveItemStatus.draft => PremiumStatus.draft,
  };
}
