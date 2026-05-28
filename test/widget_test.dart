import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sourcebase/app/sourcebase_app.dart';
import 'package:sourcebase/features/auth/presentation/screens/profile_setup_screen.dart';
import 'package:sourcebase/features/auth/presentation/screens/register_screen.dart';
import 'package:sourcebase/features/baseforce/presentation/screens/baseforce_screen.dart';
import 'package:sourcebase/features/central_ai/presentation/screens/central_ai_screen.dart';
import 'package:sourcebase/features/drive/data/drive_models.dart';
import 'package:sourcebase/features/drive/data/drive_repository.dart';
import 'package:sourcebase/features/drive/data/seed_drive_data.dart';
import 'package:sourcebase/features/drive/data/sourcebase_drive_api.dart';
import 'package:sourcebase/features/drive/presentation/screens/course_detail_screen.dart';
import 'package:sourcebase/features/drive/presentation/screens/drive_workspace_screen.dart';
import 'package:sourcebase/features/drive/presentation/screens/file_detail_screen.dart';
import 'package:sourcebase/features/drive/presentation/screens/folder_screen.dart';
import 'package:sourcebase/features/drive/presentation/screens/uploads_screen.dart';
import 'package:sourcebase/features/profile/presentation/screens/profile_screen.dart';
import 'package:sourcebase/features/sourcelab/presentation/screens/source_lab_screen.dart';

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

    expect(find.text('Profilini tamamla'), findsOneWidget);
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

    expect(find.text('Sohbet'), findsOneWidget);
    expect(find.text('BaseForce'), findsOneWidget);
    expect(find.text('SourceLab'), findsOneWidget);
  });

  testWidgets('bottom nav keeps compact phones from cramping labels', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(375, 667);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const AppShellForTest(child: DriveWorkspaceScreen()),
    );
    await tester.pumpAndSettle();

    expect(find.text('Drive'), findsWidgets);
    expect(find.text('Sohbet'), findsNothing);
    expect(find.text('BaseForce'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('central ai selects ready source and sends a prompt', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      AppShellForTest(
        child: CentralAiScreen(
          onSearch: () {},
          repository: FakeCentralRepository(_centralAiWorkspace()),
          api: const FakeCentralApi(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Sohbet'), findsOneWidget);
    expect(find.text('Henüz kaynak seçilmedi'), findsOneWidget);

    await tester.tap(find.byTooltip('Kaynak seç').first);
    await tester.pumpAndSettle();

    expect(find.text('Kaynak seçimi'), findsOneWidget);
    expect(find.text('Akut Koroner Sendrom.pdf'), findsOneWidget);
    await tester.tap(find.text('Tümü'));
    await tester.pump(const Duration(milliseconds: 250));
    expect(find.text('Farmakoloji Slaytları.pptx'), findsOneWidget);

    await tester.tap(find.text('Akut Koroner Sendrom.pdf'));
    await tester.pump();
    await tester.tap(find.text('1 kaynak uygula'));
    await tester.pumpAndSettle();

    expect(find.text('1 kaynak seçildi'), findsOneWidget);

    await tester.enterText(
      find.byType(TextField).last,
      'Bu kaynaktaki klinik yaklaşımı özetle.',
    );
    await tester.pump();
    await tester.tap(find.byTooltip('Gönder'));
    await tester.pumpAndSettle();

    expect(find.text('Yanıt hazır'), findsOneWidget);
    expect(find.text('3 MC'), findsOneWidget);
    expect(find.text('12/24 token'), findsOneWidget);
  });

  for (final viewport in const [
    MapEntry('iPhone SE', Size(375, 667)),
    MapEntry('Android gesture', Size(412, 915)),
  ]) {
    testWidgets('central ai mobile layout fits ${viewport.key}', (
      tester,
    ) async {
      tester.view.physicalSize = viewport.value;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        AppShellForTest(
          child: CentralAiScreen(
            onSearch: () {},
            repository: FakeCentralRepository(_centralAiWorkspace()),
            api: const FakeCentralApi(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Sohbet'), findsOneWidget);
      expect(find.text('Henüz kaynak seçilmedi'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('drive home and uploads fit iPhone SE with seeded data', (
    tester,
  ) async {
    final workspace = SeedDriveData.workspace();
    tester.view.physicalSize = const Size(375, 667);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      AppShellForTest(
        child: DriveWorkspaceScreen(repository: FakeDriveRepository(workspace)),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Drive'), findsWidgets);
    expect(find.text('Kaynaklarını Drive’a ekle'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Derslerim'),
      420,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Derslerim'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(
      AppShellForTest(
        child: Scaffold(
          body: UploadsScreen(
            uploads: workspace.uploads,
            onSearch: () {},
            onBack: () {},
            onNewFile: () {},
            onRetryUpload: (_) {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Yüklemeler'), findsWidgets);
    expect(find.text('Dosya seç'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Aktif'),
      420,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Aktif'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('drive course folder and file detail fit iPhone SE', (
    tester,
  ) async {
    final workspace = SeedDriveData.workspace();
    final course = workspace.courses.first;
    final section = course.sections.first;
    final file = section.files.first;
    tester.view.physicalSize = const Size(375, 667);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      AppShellForTest(
        child: Scaffold(
          body: CourseDetailScreen(
            course: course,
            onSearch: () {},
            onBack: () {},
            onOpenSection: (_) {},
            onOpenFile: (_) {},
            onCreateSection: () {},
            onOpenUploads: () {},
            onUploadToSection: (_) {},
            onRenameCourse: () {},
            onDeleteCourse: () {},
            onRenameSection: (_) {},
            onDeleteSection: (_) {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('Bölümler'),
      420,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Bölümler'), findsOneWidget);
    expect(find.text('Dosyalar'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(
      AppShellForTest(
        child: Scaffold(
          body: FolderScreen(
            course: course,
            section: section,
            onSearch: () {},
            onBack: () {},
            onOpenFile: (_) {},
            onOpenUploads: () {},
            onOpenCollections: () {},
            onGenerateFromFile: (_, _) {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('Tümünü Seç'),
      420,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Tümünü Seç'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Öneriler'),
      420,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Öneriler'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(
      AppShellForTest(
        child: Scaffold(
          body: FileDetailScreen(
            file: file,
            onSearch: () {},
            onBack: () {},
            onGenerate: (_) {},
            onOpenCollections: () {},
            onOpenBaseForce: () {},
            onOpenSourceLab: () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Dosya Detayı'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Bu dosyadan üret'),
      420,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Bu dosyadan üret'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('baseforce home and source picker fit iPhone SE', (tester) async {
    final workspace = SeedDriveData.workspace();
    tester.view.physicalSize = const Size(375, 667);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      AppShellForTest(
        child: Scaffold(
          body: BaseForceScreen(data: workspace, onSearch: () {}),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('BaseForce'), findsWidgets);
    expect(find.text('Flashcard Factory'), findsOneWidget);
    expect(find.text('Soru Fabrikası'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('Kaynak seç').first);
    await tester.pumpAndSettle();

    expect(find.text('Kaynak Seç'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Aritmiler Final.pdf'),
      420,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Aritmiler Final.pdf'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('baseforce factory buttons fit iPhone SE', (tester) async {
    final workspace = SeedDriveData.workspace();
    tester.view.physicalSize = const Size(375, 667);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    Future<void> openFactory(
      String key,
      String buttonLabel,
      String expectedTitle, {
      bool expectsSourcePrompt = true,
    }) async {
      await tester.pumpWidget(
        AppShellForTest(
          child: Scaffold(
            body: BaseForceScreen(
              key: ValueKey('baseforce-test-$key'),
              data: workspace,
              onSearch: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final target = find.byKey(ValueKey(key));
      await tester.scrollUntilVisible(
        target,
        180,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      expect(find.text(buttonLabel), findsWidgets);
      await tester.tap(target);
      await tester.pumpAndSettle();

      expect(find.text(expectedTitle), findsWidgets);
      if (expectsSourcePrompt) {
        expect(find.textContaining('Kaynak'), findsWidgets);
      }
      expect(tester.takeException(), isNull);
    }

    await openFactory(
      'baseforce-factory-flashcard',
      'Flashcard Factory',
      'Flashcard Factory',
    );
    await openFactory(
      'baseforce-factory-question',
      'Soru Fabrikası',
      'Soru Fabrikası',
    );
    await openFactory(
      'baseforce-factory-summary',
      'Sınav Sabahı Özeti',
      'Sınav Sabahı Özeti',
    );
    await openFactory(
      'baseforce-factory-algorithm',
      'Akış Şeması / Algoritma',
      'Akış Şeması / Algoritma',
    );
    await openFactory(
      'baseforce-factory-comparison',
      'Karşılaştırma Tablosu',
      'Karşılaştırma Tablosu',
    );
    await openFactory(
      'baseforce-queue',
      'Üretim\nKuyruğu',
      'Üretim Kuyruğu',
      expectsSourcePrompt: false,
    );
  });

  testWidgets('sourcelab home and source picker fit iPhone SE', (tester) async {
    final workspace = SeedDriveData.workspace();
    tester.view.physicalSize = const Size(375, 667);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      AppShellForTest(
        child: Scaffold(
          body: SourceLabScreen(
            data: workspace,
            onSearch: () {},
            onOpenDrive: () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('SourceLab'), findsWidgets);
    for (final entry in const [
      MapEntry('sourcelab-tool-exam-morning', 'Sınav Sabahı Özeti'),
      MapEntry('sourcelab-tool-clinical', 'Klinik Senaryo'),
      MapEntry('sourcelab-tool-plan', 'Öğrenme Planı'),
      MapEntry('sourcelab-tool-mind-map', 'Zihin Haritası'),
    ]) {
      await tester.scrollUntilVisible(
        find.byKey(ValueKey(entry.key)),
        260,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text(entry.value), findsOneWidget);
    }
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('Kaynak seç').first);
    await tester.pumpAndSettle();

    expect(find.text('Drive Kaynakları'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Aritmiler Final.pdf'),
      420,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.text('Aritmiler Final.pdf'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('sourcelab tool buttons fit iPhone SE', (tester) async {
    final workspace = SeedDriveData.workspace();
    tester.view.physicalSize = const Size(375, 667);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    Future<void> openTool(
      String key,
      String expectedTitle,
      String expectedCta,
    ) async {
      await tester.pumpWidget(
        AppShellForTest(
          child: Scaffold(
            body: SourceLabScreen(
              key: ValueKey('sourcelab-test-$key'),
              data: workspace,
              onSearch: () {},
              onOpenDrive: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final target = find.byKey(ValueKey(key));
      await tester.scrollUntilVisible(
        target,
        240,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await tester.tap(target);
      await tester.pumpAndSettle();

      expect(find.text(expectedTitle), findsWidgets);
      await tester.scrollUntilVisible(
        find.text(expectedCta),
        420,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text(expectedCta), findsOneWidget);
      expect(find.text('Önce kaynak seç'), findsWidgets);
      expect(tester.takeException(), isNull);
    }

    await openTool(
      'sourcelab-tool-exam-morning',
      'Sınav Sabahı Özeti',
      'Kaynak seç',
    );
    await openTool('sourcelab-tool-clinical', 'Klinik Senaryo', 'Kaynak seç');
    await openTool('sourcelab-tool-plan', 'Öğrenme Planı', 'Kaynak seç');
    await openTool('sourcelab-tool-podcast', 'Podcast Özeti', 'Kaynak seç');
    await openTool('sourcelab-tool-infographic', 'İnfografik', 'Kaynak seç');
    await openTool('sourcelab-tool-mind-map', 'Zihin Haritası', 'Kaynak seç');
  });

  testWidgets('profile mobile actions and wallet fit iPhone SE', (
    tester,
  ) async {
    var storeOpened = false;
    tester.view.physicalSize = const Size(375, 667);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      AppShellForTest(
        child: Scaffold(
          body: ProfileScreen(
            onSearch: () {},
            onOpenStore: () => storeOpened = true,
          ),
        ),
      ),
    );
    await tester.pump(const Duration(seconds: 6));
    await tester.pumpAndSettle();

    expect(find.text('Profil'), findsWidgets);
    final packagesAction = find.bySemanticsLabel('Paketler');
    await tester.scrollUntilVisible(
      packagesAction,
      160,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(packagesAction);
    await tester.pumpAndSettle();
    expect(packagesAction, findsOneWidget);
    expect(find.bySemanticsLabel('Düzenle'), findsOneWidget);
    expect(find.text('Çıkış'), findsOneWidget);

    await tester.tap(packagesAction);
    await tester.pump();
    expect(storeOpened, isTrue);

    await tester.scrollUntilVisible(
      find.text('Cüzdan'),
      420,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Mevcut MC'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('profile store fallback states fit iPhone SE', (tester) async {
    var wentBack = false;
    tester.view.physicalSize = const Size(375, 667);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      AppShellForTest(
        child: Scaffold(
          body: MedasiCoinStoreScreen(
            onSearch: () {},
            onBack: () => wentBack = true,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Paketler'), findsWidgets);
    expect(find.text('MC Paketleri'), findsOneWidget);
    expect(find.text('Bakiye alınamadı'), findsOneWidget);
    expect(find.text('Paketler yüklenemedi'), findsOneWidget);

    await tester.tap(find.byTooltip('Geri dön'));
    await tester.pump();
    expect(wentBack, isTrue);
    expect(tester.takeException(), isNull);
  });
}

DriveWorkspaceData _centralAiWorkspace() {
  const readyFile = DriveFile(
    id: 'ready-file',
    title: 'Akut Koroner Sendrom.pdf',
    kind: DriveFileKind.pdf,
    sizeLabel: '2.1 MB',
    pageLabel: '18 sayfa',
    updatedLabel: 'Bugün',
    courseTitle: 'Kardiyoloji',
    sectionTitle: 'Acil Yaklaşım',
    status: DriveItemStatus.completed,
  );
  const processingFile = DriveFile(
    id: 'processing-file',
    title: 'Farmakoloji Slaytları.pptx',
    kind: DriveFileKind.pptx,
    sizeLabel: '4.8 MB',
    pageLabel: '42 slayt',
    updatedLabel: 'Dün',
    courseTitle: 'Farmakoloji',
    sectionTitle: 'Kardiyak İlaçlar',
    status: DriveItemStatus.processing,
  );
  return const DriveWorkspaceData(
    courses: [
      DriveCourse(
        id: 'course-cardiology',
        title: 'Kardiyoloji',
        icon: Icons.favorite_outline,
        iconColor: Colors.red,
        iconBackground: Color(0xFFFFEFEF),
        status: DriveItemStatus.completed,
        updatedLabel: 'Bugün',
        description: 'Klinik kardiyoloji kaynakları',
        sections: [
          DriveSection(
            id: 'section-acute',
            title: 'Acil Yaklaşım',
            status: DriveItemStatus.completed,
            files: [readyFile, processingFile],
          ),
        ],
      ),
    ],
    recentFiles: [readyFile, processingFile],
    uploads: [],
    collections: [],
  );
}

class FakeCentralRepository extends DriveRepository {
  const FakeCentralRepository(this.workspace);

  final DriveWorkspaceData workspace;

  @override
  Future<DriveWorkspaceData> loadWorkspace() async => workspace;
}

class FakeDriveRepository extends DriveRepository {
  const FakeDriveRepository(this.workspace);

  final DriveWorkspaceData workspace;

  @override
  Future<DriveWorkspaceData> loadWorkspace() async => workspace;
}

class FakeCentralApi extends SourceBaseDriveApi {
  const FakeCentralApi();

  @override
  Future<Map<String, dynamic>> centralAiChat(
    String message, {
    String? context,
    List<String>? fileIds,
  }) async {
    return {
      'data': {
        'message': 'Yanıt hazır',
        'inputTokens': 12,
        'outputTokens': 24,
        'amount_units': 3,
        'modelRoute': {
          'provider': 'vertex',
          'model': 'gemini',
          'fallbackUsed': false,
        },
      },
    };
  }
}

class AppShellForTest extends StatelessWidget {
  const AppShellForTest({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: child,
      routes: {
        '/login': (_) =>
            const Scaffold(body: Center(child: Text('Login test placeholder'))),
        '/drive': (_) =>
            const Scaffold(body: Center(child: Text('Drive test placeholder'))),
        '/profile-setup': (_) => const Scaffold(
          body: Center(child: Text('Profile setup test placeholder')),
        ),
      },
    );
  }
}
