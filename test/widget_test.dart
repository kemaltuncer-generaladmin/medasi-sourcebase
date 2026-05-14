import 'package:sourcebase/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shows SourceBase login flow entry', (tester) async {
    await tester.pumpWidget(const SourceBaseApp());

    expect(
      find.text('Tekrar etmeye kaldığın\nyerden devam et'),
      findsOneWidget,
    );
    expect(find.text('Giriş Yap'), findsOneWidget);
    expect(find.text('Kayıt Ol'), findsOneWidget);
    expect(find.text('Apple ile devam et'), findsNothing);
    expect(find.text('Google ile devam et'), findsNothing);
  });

  testWidgets('registration asks for SourceBase education profile', (
    tester,
  ) async {
    await tester.pumpWidget(const AppShellForTest(child: RegisterScreen()));

    expect(find.text('Fakülte / Üniversite'), findsOneWidget);
    expect(find.text('Bölüm'), findsOneWidget);
    expect(find.text('Tıp'), findsOneWidget);
    expect(find.text('Apple ile devam et'), findsNothing);
    expect(find.text('Google ile devam et'), findsNothing);
  });

  testWidgets('profile setup page collects missing SourceBase fields', (
    tester,
  ) async {
    await tester.pumpWidget(const AppShellForTest(child: ProfileSetupScreen()));

    expect(find.text('Bilgilerini tamamla'), findsOneWidget);
    expect(find.text('Fakülte / Üniversite'), findsOneWidget);
    expect(find.text('Bölüm'), findsOneWidget);
    expect(find.text('Devam Et'), findsOneWidget);
    expect(find.text('Apple ile devam et'), findsNothing);
    expect(find.text('Google ile devam et'), findsNothing);
  });
}

class AppShellForTest extends StatelessWidget {
  const AppShellForTest({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(home: child);
  }
}
