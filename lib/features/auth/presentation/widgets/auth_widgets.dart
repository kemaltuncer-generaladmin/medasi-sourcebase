import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/sourcebase_brand.dart';

class AuthScreenFrame extends StatelessWidget {
  const AuthScreenFrame({required this.children, super.key});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final viewInsets = MediaQuery.viewInsetsOf(context);
    final screenWidth = MediaQuery.sizeOf(context).width;
    final horizontalPadding = screenWidth < 380 ? 22.0 : 36.0;
    return Scaffold(
      body: Semantics(
        container: true,
        explicitChildNodes: true,
        label: 'Kimlik doğrulama ekranı',
        child: CustomPaint(
          painter: const AuthBackgroundPainter(),
          child: SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 480),
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      padding: EdgeInsets.fromLTRB(
                        horizontalPadding,
                        28,
                        horizontalPadding,
                        44 + viewInsets.bottom,
                      ),
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          minHeight: constraints.maxHeight > 72
                              ? constraints.maxHeight - 72
                              : 0,
                        ),
                        child: Semantics(
                          container: true,
                          explicitChildNodes: true,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: children,
                          ),
                        ),
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
    final screenWidth = MediaQuery.sizeOf(context).width;
    final compact = screenWidth < 380;
    return Semantics(
      container: true,
      explicitChildNodes: true,
      label: '$title. $subtitle',
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Align(
            alignment: Alignment.topRight,
            child: SizedBox(
              width: 210,
              height: 210,
              child: CustomPaint(painter: AuthArtPainter(art)),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SourceBaseBrand(),
              SizedBox(height: compact ? 62 : 88),
              Text(
                title,
                style: TextStyle(
                  color: AppColors.navy,
                  fontSize: compact ? 38 : 46,
                  height: 1.08,
                  letterSpacing: 0,
                  fontWeight: FontWeight.w800,
                ),
              ),
              SizedBox(height: compact ? 14 : 18),
              Text(
                subtitle,
                style: TextStyle(
                  color: AppColors.muted,
                  fontSize: compact ? 18 : 21,
                  height: 1.34,
                  letterSpacing: 0,
                  fontWeight: FontWeight.w400,
                ),
              ),
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
    return Container(
      height: 58,
      decoration: BoxDecoration(
        color: AppColors.white.withValues(alpha: .96),
        borderRadius: BorderRadius.circular(11),
        border: Border.all(color: AppColors.line),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF234B86).withValues(alpha: .05),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          const SizedBox(width: 17),
          Icon(icon, color: AppColors.blue, size: 26),
          const SizedBox(width: 17),
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
                isDense: true,
                hintText: hint,
                hintStyle: const TextStyle(
                  color: Color(0xFF9DA8C0),
                  fontSize: 21,
                  fontWeight: FontWeight.w500,
                ),
              ),
              style: const TextStyle(
                color: AppColors.navy,
                fontSize: 19,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          if (trailing != null)
            IconTheme(
              data: const IconThemeData(color: Color(0xFF7C89A6), size: 26),
              child: trailing!,
            ),
          const SizedBox(width: 12),
        ],
      ),
    );
  }
}

class GradientActionButton extends StatelessWidget {
  const GradientActionButton({
    required this.label,
    required this.onPressed,
    this.height = 64,
    super.key,
  });

  final String label;
  final VoidCallback? onPressed;
  final double height;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    return SizedBox(
      width: double.infinity,
      height: height,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: enabled ? AppColors.primaryGradient : null,
          color: enabled ? null : const Color(0xFFE2E8F3),
          borderRadius: BorderRadius.circular(10),
          boxShadow: [
            BoxShadow(
              color: enabled
                  ? AppColors.blue.withValues(alpha: .24)
                  : Colors.transparent,
              blurRadius: 18,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: ElevatedButton(
          onPressed: onPressed,
          style: ElevatedButton.styleFrom(
            elevation: 0,
            backgroundColor: Colors.transparent,
            shadowColor: Colors.transparent,
            disabledForegroundColor: AppColors.muted,
            foregroundColor: AppColors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            textStyle: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              letterSpacing: 0,
            ),
          ),
          child: FittedBox(fit: BoxFit.scaleDown, child: Text(label)),
        ),
      ),
    );
  }
}

class OutlineActionButton extends StatelessWidget {
  const OutlineActionButton({
    required this.label,
    required this.onPressed,
    this.height = 58,
    super.key,
  });

  final String label;
  final VoidCallback? onPressed;
  final double height;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: height,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.blue,
          side: const BorderSide(color: AppColors.blue, width: 1.2),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          textStyle: const TextStyle(
            fontSize: 21,
            fontWeight: FontWeight.w700,
            letterSpacing: 0,
          ),
        ),
        child: FittedBox(fit: BoxFit.scaleDown, child: Text(label)),
      ),
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
      height: 54,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.navy,
          backgroundColor: AppColors.white.withValues(alpha: .94),
          side: const BorderSide(color: AppColors.softLine),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          textStyle: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            letterSpacing: 0,
          ),
        ),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [icon, const SizedBox(width: 18), Text(label)],
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
    this.label = 'Seçili',
    super.key,
  });

  final bool value;
  final VoidCallback? onTap;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      enabled: onTap != null,
      toggled: value,
      label: label,
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
        const Expanded(child: Divider(color: AppColors.line)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            label,
            style: const TextStyle(color: AppColors.muted, fontSize: 18),
          ),
        ),
        const Expanded(child: Divider(color: AppColors.line)),
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
    final color = error ? AppColors.red : AppColors.green;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: error ? AppColors.redBg : AppColors.greenBg,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(
            error ? Icons.error_outline_rounded : Icons.check_circle_rounded,
            color: color,
            size: 22,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: color,
                fontSize: 14.5,
                fontWeight: FontWeight.w700,
                height: 1.25,
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
    final blueWash = Paint()
      ..shader =
          RadialGradient(
            colors: [
              const Color(0xFFD9EAFF).withValues(alpha: .58),
              Colors.transparent,
            ],
          ).createShader(
            Rect.fromCircle(
              center: Offset(size.width * .88, size.height * .09),
              radius: size.width * .55,
            ),
          );
    canvas.drawRect(Offset.zero & size, Paint()..color = AppColors.page);
    canvas.drawRect(Offset.zero & size, blueWash);

    final dotPaint = Paint()
      ..color = const Color(0xFFBFD8F6).withValues(alpha: .38);
    for (var row = 0; row < 7; row++) {
      for (var col = 0; col < 7; col++) {
        canvas.drawCircle(
          Offset(size.width - 110 + col * 13, 320 + row * 13),
          2,
          dotPaint,
        );
      }
    }
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
