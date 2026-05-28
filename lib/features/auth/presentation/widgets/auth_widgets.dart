import 'package:flutter/material.dart';

import '../../../../core/design_system/design_system.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/responsive_layout.dart';
import '../../../../core/widgets/sourcebase_brand.dart';

class AuthScreenFrame extends StatelessWidget {
  const AuthScreenFrame({required this.children, super.key});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final keyboardVisible = MediaQuery.viewInsetsOf(context).bottom > 0;
    return Scaffold(
      backgroundColor: AppColors.page,
      resizeToAvoidBottomInset: true,
      body: Semantics(
        container: true,
        explicitChildNodes: true,
        label: 'Kimlik doğrulama ekranı',
        child: CustomPaint(
          painter: const AuthBackgroundPainter(),
          child: SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final horizontalPadding = constraints.maxWidth < 430
                    ? 24.0
                    : ResponsiveLayout.getHorizontalPadding(context);
                final useCard = constraints.maxWidth >= 760;
                final compactPhone =
                    SourceBaseMobileMetrics.isCompactPhone(context) ||
                    keyboardVisible;
                final topPadding = keyboardVisible
                    ? 10.0
                    : compactPhone
                    ? 22.0
                    : 32.0;
                final bottomPadding =
                    SourceBaseMobileMetrics.keyboardAwareBottomPadding(
                      context,
                      resting: 36,
                    );
                final maxWidth = useCard ? 460.0 : double.infinity;
                final content = Semantics(
                  container: true,
                  explicitChildNodes: true,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: children,
                  ),
                );
                return Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: maxWidth),
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      keyboardDismissBehavior:
                          ScrollViewKeyboardDismissBehavior.onDrag,
                      padding: EdgeInsets.fromLTRB(
                        horizontalPadding,
                        topPadding,
                        horizontalPadding,
                        bottomPadding,
                      ),
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          minHeight: constraints.maxHeight > 72
                              ? constraints.maxHeight - 72
                              : 0,
                        ),
                        child: useCard
                            ? Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 28,
                                  vertical: 30,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.white.withValues(alpha: .88),
                                  borderRadius: BorderRadius.circular(
                                    SBDimensions.cardRadius,
                                  ),
                                  border: Border.all(
                                    color: AppColors.white.withValues(
                                      alpha: .72,
                                    ),
                                  ),
                                  boxShadow: SBShadows.card,
                                ),
                                child: content,
                              )
                            : content,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class AuthHeader extends StatelessWidget {
  const AuthHeader({
    required this.title,
    required this.subtitle,
    required this.art,
    super.key,
  });

  final String title;
  final String subtitle;
  final AuthArtType art;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final width = media.size.width;
    final keyboardVisible = media.viewInsets.bottom > 0;
    final compactLayout =
        width < 390 || media.size.height < 700 || keyboardVisible;
    final artSize = keyboardVisible
        ? 0.0
        : compactLayout
        ? 92.0
        : 150.0;
    final titleStyle = TextStyle(
      color: AppColors.navy,
      fontSize: compactLayout ? 34 : 42,
      fontWeight: FontWeight.w900,
      height: 1.06,
      letterSpacing: 0,
    );
    final subtitleStyle = TextStyle(
      color: AppColors.muted,
      fontWeight: FontWeight.w500,
      fontSize: compactLayout ? 18 : 22,
      height: 1.42,
      letterSpacing: 0,
    );
    final brandGap = keyboardVisible
        ? 20.0
        : compactLayout
        ? 34.0
        : 58.0;

    return Semantics(
      container: true,
      explicitChildNodes: true,
      label: '$title. $subtitle',
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          if (artSize > 0)
            Align(
              alignment: Alignment.topRight,
              child: SizedBox(
                width: artSize,
                height: artSize,
                child: CustomPaint(painter: AuthArtPainter(art)),
              ),
            ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SourceBaseBrand(compact: compactLayout),
              SizedBox(height: brandGap),
              Text(
                title,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: titleStyle,
              ),
              const SizedBox(height: 14),
              Text(subtitle, style: subtitleStyle),
            ],
          ),
        ],
      ),
    );
  }
}

class AuthTextField extends StatelessWidget {
  const AuthTextField({
    required this.icon,
    required this.hint,
    this.controller,
    this.obscureText = false,
    this.keyboardType,
    this.textInputAction,
    this.onSubmitted,
    this.trailing,
    this.autofillHints,
    super.key,
  });

  final IconData icon;
  final String hint;
  final TextEditingController? controller;
  final bool obscureText;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onSubmitted;
  final Widget? trailing;
  final Iterable<String>? autofillHints;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 64),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.white.withValues(alpha: .94),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFD8DFEA), width: 1.2),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF234B86).withValues(alpha: .035),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: [
            const SizedBox(width: 20),
            Icon(icon, color: AppColors.blue, size: 27),
            const SizedBox(width: 18),
            Expanded(
              child: TextField(
                controller: controller,
                obscureText: obscureText,
                keyboardType: keyboardType,
                textInputAction: textInputAction,
                onSubmitted: onSubmitted,
                autofillHints: autofillHints,
                cursorColor: AppColors.blue,
                decoration: InputDecoration(
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  errorBorder: InputBorder.none,
                  disabledBorder: InputBorder.none,
                  focusedErrorBorder: InputBorder.none,
                  filled: false,
                  contentPadding: EdgeInsets.zero,
                  isDense: true,
                  hintText: hint,
                  hintStyle: const TextStyle(
                    color: AppColors.softText,
                    fontSize: 21,
                    fontWeight: FontWeight.w600,
                    height: 1.2,
                    letterSpacing: 0,
                  ),
                ),
                style: const TextStyle(
                  color: AppColors.navy,
                  fontWeight: FontWeight.w600,
                  fontSize: 21,
                  height: 1.2,
                  letterSpacing: 0,
                ),
              ),
            ),
            if (trailing != null)
              IconTheme(
                data: const IconThemeData(color: Color(0xFF7C89A6), size: 29),
                child: trailing!,
              ),
            const SizedBox(width: 14),
          ],
        ),
      ),
    );
  }
}

class GradientActionButton extends StatelessWidget {
  const GradientActionButton({
    required this.label,
    required this.onPressed,
    this.height = 44,
    super.key,
  });

  final String label;
  final VoidCallback? onPressed;
  final double height;

  @override
  Widget build(BuildContext context) {
    return SourceBaseButton(
      label: label,
      onPressed: onPressed,
      size: height >= 48 ? SBButtonSize.large : SBButtonSize.medium,
    );
  }
}

class AuthActionButton extends StatelessWidget {
  const AuthActionButton({
    required this.label,
    required this.onPressed,
    this.loading = false,
    this.outlined = false,
    super.key,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool loading;
  final bool outlined;

  @override
  Widget build(BuildContext context) {
    final disabled = onPressed == null || loading;
    final radius = BorderRadius.circular(10);
    final foreground = outlined
        ? (disabled ? AppColors.muted : AppColors.blue)
        : (disabled ? AppColors.muted : AppColors.white);

    return Semantics(
      button: true,
      enabled: !disabled,
      label: label,
      hint: loading ? 'Yükleniyor' : null,
      excludeSemantics: true,
      child: SizedBox(
        width: double.infinity,
        height: 66,
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: outlined || disabled ? null : AppColors.primaryGradient,
            color: outlined
                ? AppColors.white.withValues(alpha: .70)
                : disabled
                ? AppColors.line
                : null,
            borderRadius: radius,
            border: outlined
                ? Border.all(
                    color: disabled ? AppColors.line : AppColors.blue,
                    width: 1.2,
                  )
                : null,
            boxShadow: outlined || disabled
                ? null
                : [
                    BoxShadow(
                      color: AppColors.blue.withValues(alpha: .22),
                      blurRadius: 18,
                      offset: const Offset(0, 9),
                    ),
                  ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: disabled ? null : onPressed,
              borderRadius: radius,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: loading
                    ? Center(
                        child: SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.4,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              outlined ? AppColors.blue : AppColors.white,
                            ),
                          ),
                        ),
                      )
                    : ExcludeSemantics(
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            Text(
                              label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: foreground,
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                                height: 1,
                                letterSpacing: 0,
                              ),
                            ),
                            Positioned(
                              right: 0,
                              child: Icon(
                                Icons.arrow_forward_rounded,
                                size: 32,
                                color: foreground,
                              ),
                            ),
                          ],
                        ),
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class OutlineActionButton extends StatelessWidget {
  const OutlineActionButton({
    required this.label,
    required this.onPressed,
    this.height = 44,
    super.key,
  });

  final String label;
  final VoidCallback? onPressed;
  final double height;

  @override
  Widget build(BuildContext context) {
    return SourceBaseButton(
      label: label,
      onPressed: onPressed,
      variant: SourceBaseButtonVariant.secondary,
      size: height >= 44 ? SBButtonSize.medium : SBButtonSize.small,
    );
  }
}

class SocialAuthButton extends StatelessWidget {
  const SocialAuthButton({
    required this.label,
    required this.icon,
    required this.onPressed,
    super.key,
  });

  final String label;
  final Widget icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 44,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.navy,
          backgroundColor: AppColors.white.withValues(alpha: .94),
          side: const BorderSide(color: AppColors.softLine),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(SBDimensions.buttonRadius),
          ),
          textStyle: SBTextStyles.labelMedium,
        ),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [icon, const SizedBox(width: 10), Text(label)],
          ),
        ),
      ),
    );
  }
}

class AuthCheck extends StatelessWidget {
  const AuthCheck({
    required this.value,
    required this.onTap,
    this.label,
    super.key,
  });

  final bool value;
  final VoidCallback? onTap;
  final String? label;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      enabled: onTap != null,
      toggled: value,
      label: label ?? 'Beni hatırla',
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: value ? AppColors.blue : AppColors.white,
            borderRadius: BorderRadius.circular(5),
            border: Border.all(color: AppColors.blue, width: 1.2),
          ),
          child: value
              ? const Icon(Icons.check_rounded, size: 19, color: Colors.white)
              : null,
        ),
      ),
    );
  }
}

class DividerLabel extends StatelessWidget {
  const DividerLabel(this.label, {super.key});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Expanded(child: Divider(color: Color(0xFFD8DFEA))),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            label.toUpperCase(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppColors.muted,
              fontSize: 17,
              fontWeight: FontWeight.w700,
              height: 1,
              letterSpacing: 0,
            ),
          ),
        ),
        const Expanded(child: Divider(color: Color(0xFFD8DFEA))),
      ],
    );
  }
}

class AuthStatusBox extends StatelessWidget {
  const AuthStatusBox({required this.message, this.error = true, super.key});

  final String message;
  final bool error;

  @override
  Widget build(BuildContext context) {
    final color = error ? AppColors.clinicalError : AppColors.green;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: error ? AppColors.clinicalErrorBg : AppColors.greenBg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: error
              ? AppColors.clinicalError.withValues(alpha: .12)
              : AppColors.green.withValues(alpha: .14),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.white.withValues(alpha: .92),
              shape: BoxShape.circle,
            ),
            child: Icon(
              error ? Icons.error_outline_rounded : Icons.check_rounded,
              color: color,
              size: 26,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: color,
                fontSize: 17,
                fontWeight: FontWeight.w700,
                height: 1.36,
                letterSpacing: 0,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class GoogleGlyph extends StatelessWidget {
  const GoogleGlyph({super.key});

  @override
  Widget build(BuildContext context) {
    return const Text(
      'G',
      style: TextStyle(
        color: Color(0xFF4285F4),
        fontSize: 24,
        fontWeight: FontWeight.w900,
      ),
    );
  }
}

enum AuthArtType { login, register, forgot, verify }

class AuthBackgroundPainter extends CustomPainter {
  const AuthBackgroundPainter();

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = Colors.white);

    final blueWash = Paint()
      ..shader = LinearGradient(
        colors: [
          const Color(0xFFE8F0FF).withValues(alpha: .68),
          Colors.white.withValues(alpha: .0),
        ],
        begin: Alignment.topRight,
        end: Alignment.centerLeft,
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height * .45));
    canvas.drawRect(Offset.zero & size, blueWash);

    final waveOne = Path()
      ..moveTo(0, size.height - 90)
      ..cubicTo(
        size.width * .28,
        size.height - 104,
        size.width * .34,
        size.height - 18,
        size.width * .63,
        size.height - 58,
      )
      ..cubicTo(
        size.width * .80,
        size.height - 82,
        size.width * .92,
        size.height - 80,
        size.width,
        size.height - 52,
      )
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(
      waveOne,
      Paint()..color = const Color(0xFFEAF1FF).withValues(alpha: .78),
    );

    final waveTwo = Path()
      ..moveTo(0, size.height - 52)
      ..cubicTo(
        size.width * .26,
        size.height + 36,
        size.width * .48,
        size.height - 38,
        size.width * .72,
        size.height - 16,
      )
      ..cubicTo(
        size.width * .86,
        size.height - 4,
        size.width * .94,
        size.height - 18,
        size.width,
        size.height - 44,
      )
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(
      waveTwo,
      Paint()..color = const Color(0xFFDDE8FF).withValues(alpha: .38),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class AuthArtPainter extends CustomPainter {
  const AuthArtPainter(this.type);

  final AuthArtType type;

  @override
  void paint(Canvas canvas, Size size) {
    final cardPaint = Paint()..color = Colors.white.withValues(alpha: .82);
    final bluePaint = Paint()
      ..shader = AppColors.primaryGradient.createShader(Offset.zero & size);
    final linePaint = Paint()
      ..color = const Color(0xFFC8DBF4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    final shadow = Paint()
      ..color = AppColors.blue.withValues(alpha: .11)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 16);

    canvas.save();
    canvas.translate(size.width * .15, size.height * .10);
    canvas.rotate(-0.12);
    for (var i = 0; i < 3; i++) {
      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(i * 19, 92 - i * 22, 142, 78),
        const Radius.circular(16),
      );
      canvas.drawRRect(rect.shift(const Offset(0, 9)), shadow);
      canvas.drawRRect(rect, Paint()..color = const Color(0xFFE7F2FF));
      canvas.drawRRect(rect, linePaint);
    }
    canvas.restore();

    final envelope = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(size.width * .62, size.height * .48),
        width: 138,
        height: 96,
      ),
      const Radius.circular(18),
    );
    canvas.drawRRect(envelope.shift(const Offset(0, 12)), shadow);
    canvas.drawRRect(envelope, cardPaint);
    canvas.drawRRect(envelope, linePaint);

    final center = envelope.outerRect.center;
    final flap = Path()
      ..moveTo(envelope.left + 8, envelope.top + 10)
      ..lineTo(center.dx, envelope.bottom - 22)
      ..lineTo(envelope.right - 8, envelope.top + 10);
    canvas.drawPath(flap, linePaint);

    final badgeCenter = Offset(envelope.right - 6, envelope.bottom - 4);
    canvas.drawCircle(
      badgeCenter,
      40,
      Paint()..color = Colors.white.withValues(alpha: .78),
    );
    canvas.drawCircle(badgeCenter, 30, bluePaint);
    final white = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    if (type == AuthArtType.forgot) {
      canvas.drawArc(
        Rect.fromCenter(
          center: badgeCenter.translate(0, -5),
          width: 28,
          height: 28,
        ),
        3.15,
        3.1,
        false,
        white,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: badgeCenter.translate(0, 8),
            width: 34,
            height: 26,
          ),
          const Radius.circular(5),
        ),
        Paint()..color = Colors.white,
      );
    } else {
      final check = Path()
        ..moveTo(badgeCenter.dx - 13, badgeCenter.dy)
        ..lineTo(badgeCenter.dx - 3, badgeCenter.dy + 11)
        ..lineTo(badgeCenter.dx + 15, badgeCenter.dy - 14);
      canvas.drawPath(check, white);
    }

    final spark = Paint()
      ..color = const Color(0xFF7EAFFF).withValues(alpha: .75);
    canvas.drawCircle(Offset(size.width * .18, size.height * .65), 5, spark);
    canvas.drawCircle(Offset(size.width * .92, size.height * .28), 3.5, spark);
  }

  @override
  bool shouldRepaint(covariant AuthArtPainter oldDelegate) =>
      oldDelegate.type != type;
}
