import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../baseforce/presentation/screens/baseforce_screen.dart';
import '../../../sourcelab/presentation/screens/source_lab_screen.dart';
import '../../data/drive_models.dart';
import '../../data/drive_repository.dart';
import '../../data/drive_upload_service.dart';
import '../../data/seed_drive_data.dart';
import '../widgets/sourcebase_bottom_nav.dart';
import 'collections_screen.dart';
import 'course_detail_screen.dart';
import 'drive_home_screen.dart';
import 'drive_search_screen.dart';
import 'file_detail_screen.dart';
import 'folder_screen.dart';
import 'uploads_screen.dart';

enum WorkspaceRouteKey {
  home,
  course,
  folder,
  fileDetail,
  search,
  uploads,
  collections,
  baseForce,
  centralAi,
  sourceLab,
  profile,
}

class DriveWorkspaceScreen extends StatefulWidget {
  const DriveWorkspaceScreen({super.key});

  static const route = '/home';

  @override
  State<DriveWorkspaceScreen> createState() => _DriveWorkspaceScreenState();
}

class _DriveWorkspaceScreenState extends State<DriveWorkspaceScreen> {
  final repository = const DriveRepository();
  final uploadService = const DriveUploadService();
  DriveWorkspaceData data = SeedDriveData.workspace();
  WorkspaceRouteKey route = WorkspaceRouteKey.home;
  bool loading = true;
  bool busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final loaded = await repository.loadWorkspace();
    if (!mounted) {
      return;
    }
    setState(() {
      data = loaded;
      loading = false;
    });
  }

  void _go(WorkspaceRouteKey next) {
    setState(() => route = next);
  }

  Future<void> _createCourse() async {
    final title = await _textDialog(
      title: 'Ders Oluştur',
      label: 'Ders adı',
      initialValue: 'Yeni Ders',
    );
    if (title == null || title.trim().isEmpty) return;
    await _runAction('Ders oluşturuluyor...', () async {
      final course = await repository.createCourse(title.trim());
      setState(() {
        data = data.copyWith(courses: [course, ...data.courses]);
        route = WorkspaceRouteKey.course;
      });
      _showSnack('${course.title} oluşturuldu.');
    });
  }

  Future<void> _createSection() async {
    final course = data.primaryCourse;
    final title = await _textDialog(
      title: 'Bölüm Ekle',
      label: 'Bölüm adı',
      initialValue: 'Yeni Bölüm',
    );
    if (title == null || title.trim().isEmpty) return;
    await _runAction('Bölüm ekleniyor...', () async {
      final section = await repository.createSection(
        courseId: course.id,
        title: title.trim(),
      );
      _replaceCourse(course.copyWith(sections: [section, ...course.sections]));
      _showSnack('${section.title} bölümü eklendi.');
    });
  }

  Future<void> _uploadFile() async {
    final course = data.primaryCourse;
    final section = data.primarySection;
    final picked = await uploadService.pickFile();
    if (picked == null) return;
    await _runAction('Dosya yükleniyor...', () async {
      final draft = DriveUploadDraft(
        fileName: picked.name,
        contentType: picked.contentType,
        sizeBytes: picked.sizeBytes,
        courseId: course.id,
        sectionId: section.id,
      );
      final session = await repository.createUploadSession(draft);
      await uploadService.uploadBytes(
        uploadUrl: session.uploadUrl,
        headers: session.headers,
        file: picked,
      );
      final uploaded = await repository.completeUpload(
        file: picked,
        objectName: session.objectName,
        courseId: course.id,
        sectionId: section.id,
        courseTitle: course.title,
        sectionTitle: section.title,
      );
      _addFileToSection(uploaded);
      setState(() => route = WorkspaceRouteKey.uploads);
      _showSnack('${picked.name} Drive alanına yüklendi.');
    });
  }

  Future<void> _generateFromFile(GeneratedKind kind) async {
    final file = data.primaryFile;
    await _runAction('Üretim başlatılıyor...', () async {
      final output = await repository.createGeneratedOutput(
        file: file,
        kind: kind,
      );
      _replaceFile(file.copyWith(generated: [output, ...file.generated]));
      _showSnack('${output.title} oluşturuldu.');
    });
  }

  Future<void> _runAction(String label, Future<void> Function() action) async {
    if (busy) return;
    setState(() => busy = true);
    _showSnack(label);
    try {
      await action();
    } catch (error) {
      _showSnack(error.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  void _replaceCourse(DriveCourse updated) {
    setState(() {
      data = data.copyWith(
        courses: [
          for (final course in data.courses)
            if (course.id == updated.id) updated else course,
        ],
      );
    });
  }

  void _addFileToSection(DriveFile file) {
    final course = data.primaryCourse;
    final section = data.primarySection;
    final updatedSection = section.copyWith(files: [file, ...section.files]);
    final updatedCourse = course.copyWith(
      sections: [
        for (final item in course.sections)
          if (item.id == section.id) updatedSection else item,
      ],
    );
    setState(() {
      data = data.copyWith(
        courses: [
          for (final item in data.courses)
            if (item.id == course.id) updatedCourse else item,
        ],
        recentFiles: [file, ...data.recentFiles],
        uploads: [
          UploadTask(file: file, status: DriveItemStatus.completed),
          ...data.uploads,
        ],
      );
    });
  }

  void _replaceFile(DriveFile updated) {
    final courses = data.courses.map((course) {
      return course.copyWith(
        sections: course.sections.map((section) {
          return section.copyWith(
            files: section.files
                .map((file) => file.id == updated.id ? updated : file)
                .toList(),
          );
        }).toList(),
      );
    }).toList();
    setState(() {
      data = data.copyWith(
        courses: courses,
        recentFiles: data.recentFiles
            .map((file) => file.id == updated.id ? updated : file)
            .toList(),
      );
    });
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  Future<String?> _textDialog({
    required String title,
    required String label,
    required String initialValue,
  }) {
    final controller = TextEditingController(text: initialValue);
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(labelText: label),
          onSubmitted: (value) => Navigator.of(context).pop(value),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Vazgeç'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(controller.text),
            child: const Text('Kaydet'),
          ),
        ],
      ),
    );
  }

  int get _selectedNavIndex {
    return switch (route) {
      WorkspaceRouteKey.baseForce => 2,
      WorkspaceRouteKey.centralAi => 0,
      WorkspaceRouteKey.sourceLab => 3,
      WorkspaceRouteKey.profile => 4,
      _ => 1,
    };
  }

  void _onNavChanged(int index) {
    final next = switch (index) {
      0 => WorkspaceRouteKey.centralAi,
      1 => WorkspaceRouteKey.home,
      2 => WorkspaceRouteKey.baseForce,
      3 => WorkspaceRouteKey.sourceLab,
      4 => WorkspaceRouteKey.profile,
      _ => WorkspaceRouteKey.home,
    };
    _go(next);
  }

  @override
  Widget build(BuildContext context) {
    final course = data.primaryCourse;
    final section = data.primarySection;
    final file = data.primaryFile;
    final screen = switch (route) {
      WorkspaceRouteKey.home => DriveHomeScreen(
        data: data,
        onSearch: () => _go(WorkspaceRouteKey.search),
        onOpenCourse: () => _go(WorkspaceRouteKey.course),
        onCreateCourse: _createCourse,
        onOpenUploads: _uploadFile,
        onOpenUploadsPage: () => _go(WorkspaceRouteKey.uploads),
        onOpenCollections: () => _go(WorkspaceRouteKey.collections),
      ),
      WorkspaceRouteKey.course => CourseDetailScreen(
        course: course,
        onSearch: () => _go(WorkspaceRouteKey.search),
        onBack: () => _go(WorkspaceRouteKey.home),
        onOpenSection: () => _go(WorkspaceRouteKey.folder),
        onCreateSection: _createSection,
        onOpenUploads: _uploadFile,
      ),
      WorkspaceRouteKey.folder => FolderScreen(
        course: course,
        section: section,
        onSearch: () => _go(WorkspaceRouteKey.search),
        onBack: () => _go(WorkspaceRouteKey.course),
        onOpenFile: () => _go(WorkspaceRouteKey.fileDetail),
        onOpenUploads: _uploadFile,
        onOpenCollections: () => _go(WorkspaceRouteKey.collections),
      ),
      WorkspaceRouteKey.fileDetail => FileDetailScreen(
        file: file,
        onSearch: () => _go(WorkspaceRouteKey.search),
        onBack: () => _go(WorkspaceRouteKey.folder),
        onGenerate: _generateFromFile,
      ),
      WorkspaceRouteKey.search => DriveSearchScreen(
        files: section.files,
        onBack: () => _go(WorkspaceRouteKey.folder),
        onOpenFile: () => _go(WorkspaceRouteKey.fileDetail),
      ),
      WorkspaceRouteKey.uploads => UploadsScreen(
        uploads: data.uploads,
        onSearch: () => _go(WorkspaceRouteKey.search),
        onBack: () => _go(WorkspaceRouteKey.home),
        onNewFile: _uploadFile,
      ),
      WorkspaceRouteKey.collections => CollectionsScreen(
        data: data,
        onSearch: () => _go(WorkspaceRouteKey.search),
        onBackToDrive: () => _go(WorkspaceRouteKey.home),
      ),
      WorkspaceRouteKey.baseForce => const BaseForceScreen(),
      WorkspaceRouteKey.centralAi => const PlaceholderWorkspaceScreen(
        title: 'Merkezi AI',
        subtitle: 'AI komut merkezi SourceBase sınırları içinde hazırlanıyor.',
        icon: Icons.psychology_outlined,
      ),
      WorkspaceRouteKey.sourceLab => SourceLabScreen(
        data: data,
        onSearch: () => _go(WorkspaceRouteKey.search),
      ),
      WorkspaceRouteKey.profile => const PlaceholderWorkspaceScreen(
        title: 'Profil ve Ayarlar',
        subtitle: 'Hesap, güvenlik ve SourceBase tercihleri için alan.',
        icon: Icons.manage_accounts_outlined,
      ),
    };

    return Scaffold(
      body: Stack(
        children: [
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 180),
            child: loading
                ? const Center(child: CircularProgressIndicator())
                : KeyedSubtree(key: ValueKey(route), child: screen),
          ),
          SourceBaseBottomNav(
            selectedIndex: _selectedNavIndex,
            onChanged: _onNavChanged,
          ),
          if (busy)
            const Positioned(
              left: 0,
              right: 0,
              top: 0,
              child: LinearProgressIndicator(minHeight: 3),
            ),
        ],
      ),
    );
  }
}

class PlaceholderWorkspaceScreen extends StatelessWidget {
  const PlaceholderWorkspaceScreen({
    required this.title,
    required this.subtitle,
    required this.icon,
    super.key,
  });

  final String title;
  final String subtitle;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(28, 80, 28, 160),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 92,
                height: 92,
                decoration: BoxDecoration(
                  color: AppColors.selectedBlue,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Icon(icon, color: AppColors.blue, size: 48),
              ),
              const SizedBox(height: 22),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppColors.navy,
                  fontSize: 30,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppColors.muted,
                  fontSize: 17,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
