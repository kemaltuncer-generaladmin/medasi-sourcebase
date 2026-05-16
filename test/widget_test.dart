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
    expect(find.text('Apple ile devam et'), findsOneWidget);
    expect(find.text('Google ile devam et'), findsOneWidget);
  });

  testWidgets('registration shows SourceBase account form', (tester) async {
    await tester.pumpWidget(const AppShellForTest(child: RegisterScreen()));

    expect(find.text('Hesap oluştur'), findsOneWidget);
    expect(find.text('Ad Soyad'), findsOneWidget);
    expect(find.text('E-posta'), findsOneWidget);
    expect(find.text('Apple ile devam et'), findsOneWidget);
    expect(find.text('Google ile devam et'), findsOneWidget);
  });

  testWidgets('profile setup page collects missing SourceBase fields', (
    tester,
  ) async {
    await tester.pumpWidget(const AppShellForTest(child: ProfileSetupScreen()));

    expect(find.text('Bilgilerini\ntamamla'), findsOneWidget);
    expect(find.text('Fakülte / Üniversite'), findsOneWidget);
    expect(find.text('Devam Et'), findsOneWidget);
  });

  testWidgets('bottom nav BaseForce opens BaseForce instead of collections', (
    tester,
  ) async {
    await tester.pumpWidget(
      const AppShellForTest(child: DriveWorkspaceScreen()),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('BaseForce'));
    await tester.pumpAndSettle();

    expect(find.text('Üretim Merkezleri'), findsOneWidget);
    expect(find.text('Materyallerinden üretilen çıktılar'), findsNothing);
  });

  testWidgets('Drive collections button keeps collections as a separate page', (
    tester,
  ) async {
    await tester.pumpWidget(
      const AppShellForTest(child: DriveWorkspaceScreen()),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Koleksiyonlar'));
    await tester.pumpAndSettle();

    expect(find.text('Materyallerinden üretilen çıktılar'), findsOneWidget);
    expect(find.text('Üretim Merkezleri'), findsNothing);
  });

  testWidgets(
    'BaseForce source and generation buttons navigate the main flow',
    (tester) async {
      await tester.pumpWidget(
        const AppShellForTest(child: DriveWorkspaceScreen()),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('BaseForce'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Drive’dan Seç').first);
      await tester.pumpAndSettle();

      expect(find.text('Kaynak Seç'), findsOneWidget);
      await tester.scrollUntilVisible(find.text('Drive’daki Dosyalar'), 500);
      expect(find.text('Drive’daki Dosyalar'), findsOneWidget);

      await tester.scrollUntilVisible(find.text('Devam Et'), 500);
      await tester.tap(find.text('Devam Et'));
      await tester.pumpAndSettle();
      expect(find.text('Flashcard Fabrikası'), findsWidgets);

      await tester.scrollUntilVisible(find.text('Flashcard Üret'), 500);
      await tester.drag(find.byType(Scrollable).first, const Offset(0, -240));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Flashcard Üret'));
      await tester.pumpAndSettle();

      expect(find.text('Üretim Kuyruğu'), findsOneWidget);
    },
  );

  testWidgets('BaseForce search opens global Drive file search', (
    tester,
  ) async {
    await tester.pumpWidget(
      const AppShellForTest(child: DriveWorkspaceScreen()),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('BaseForce'));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.search_rounded).first);
    await tester.pumpAndSettle();

    expect(find.text('Dosya Arama'), findsOneWidget);
    expect(find.text('13 sonuç bulundu'), findsOneWidget);
    expect(find.text('Filtreler'), findsOneWidget);
  });

  testWidgets('SourceLab search opens global Drive file search', (
    tester,
  ) async {
    await tester.pumpWidget(
      const AppShellForTest(child: DriveWorkspaceScreen()),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('SourceLab'));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.search_rounded).first);
    await tester.pumpAndSettle();

    expect(find.text('Dosya Arama'), findsOneWidget);
    expect(find.text('Filtreler'), findsOneWidget);
  });

  testWidgets('BaseForce remains usable on a phone viewport', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const AppShellForTest(child: DriveWorkspaceScreen()),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('BaseForce'));
    await tester.pumpAndSettle();
    expect(find.text('Üretim Merkezleri'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.search_rounded).first);
    await tester.pumpAndSettle();
    expect(find.text('Dosya Arama'), findsOneWidget);
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
