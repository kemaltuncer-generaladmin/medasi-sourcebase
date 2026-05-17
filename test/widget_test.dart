import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sourcebase/app/sourcebase_app.dart';
import 'package:sourcebase/features/auth/presentation/screens/profile_setup_screen.dart';
import 'package:sourcebase/features/auth/presentation/screens/register_screen.dart';
import 'package:sourcebase/features/drive/presentation/screens/drive_workspace_screen.dart';

void main() {
  testWidgets('shows SourceBase login flow entry', (tester) async {
    await tester.pumpWidget(const SourceBaseApp());

    expect(find.text('Hoş geldin'), findsOneWidget);
    expect(find.text('Giriş Yap'), findsOneWidget);
    expect(find.text('Hesap Oluştur'), findsOneWidget);
    expect(find.text('Şifremi unuttum'), findsOneWidget);
  });

  testWidgets('registration shows SourceBase account form', (tester) async {
    await tester.pumpWidget(const AppShellForTest(child: RegisterScreen()));

    expect(find.text('Hesap oluştur'), findsOneWidget);
    expect(find.text('Ad Soyad'), findsOneWidget);
    expect(find.text('E-posta'), findsOneWidget);
    expect(find.text('Kayıt Ol'), findsOneWidget);
  });

  testWidgets('profile setup page collects missing SourceBase fields', (
    tester,
  ) async {
    await tester.pumpWidget(const AppShellForTest(child: ProfileSetupScreen()));

    expect(find.text('Bilgilerini\ntamamla'), findsOneWidget);
    expect(find.text('Fakülte / Üniversite'), findsOneWidget);
    expect(find.text('Devam Et'), findsOneWidget);
  });

  testWidgets('drive workspace shows error without backend', (tester) async {
    await tester.pumpWidget(
      const AppShellForTest(child: DriveWorkspaceScreen()),
    );
    await tester.pumpAndSettle();

    expect(find.text('Bir Sorun Oluştu'), findsOneWidget);
    expect(find.text('Tekrar Dene'), findsOneWidget);
  });

  testWidgets('bottom nav visible in mobile layout', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const AppShellForTest(child: DriveWorkspaceScreen()),
    );
    await tester.pumpAndSettle();

    expect(find.text('Merkezi AI'), findsOneWidget);
    expect(find.text('BaseForce'), findsOneWidget);
    expect(find.text('SourceLab'), findsOneWidget);
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
