import 'package:flutter/material.dart';
import 'package:responsive_builder/responsive_builder.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../baseforce/presentation/screens/baseforce_screen.dart';
import '../../../sourcelab/presentation/screens/source_lab_screen.dart';
import '../../data/drive_models.dart';
import '../../data/drive_repository.dart';
import '../../data/drive_upload_service.dart';
import '../widgets/drive_ui.dart';
import '../widgets/sourcebase_bottom_nav.dart';
import '../widgets/sourcebase_nav_rail.dart';
import 'collections_screen.dart';
import 'course_detail_screen.dart';
import 'drive_home_screen.dart';
import 'drive_search_screen.dart';
import 'file_detail_screen.dart';
import 'folder_screen.dart';
import 'uploads_screen.dart';
import '../../../central_ai/presentation/screens/central_ai_screen.dart';
import '../../../profile/presentation/screens/profile_screen.dart';

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
  store,
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
  DriveWorkspaceData data = DriveWorkspaceData.empty;
  WorkspaceRouteKey route = WorkspaceRouteKey.home;
  WorkspaceRouteKey searchReturnRoute = WorkspaceRouteKey.home;
  String? selectedCourseId;
  String? selectedSectionId;
  String? selectedFileId;
  bool loading = true;
  bool busy = false;
  String? errorMessage;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      loading = true;
      errorMessage = null;
    });
    try {
      final loaded = await repository.loadWorkspace();
      if (!mounted) return;
      setState(() {
        data = loaded;
        _syncSelection(loaded);
        loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        errorMessage = e.toString();
        loading = false;
      });
    }
  }

  void _go(WorkspaceRouteKey next) {
    setState(() => route = next);
  }

  void _syncSelection(DriveWorkspaceData workspace) {
    if (selectedCourseId != null &&
        !workspace.courses.any((course) => course.id == selectedCourseId)) {
      selectedCourseId = null;
      selectedSectionId = null;
      selectedFileId = null;
    }
    selectedCourseId ??= workspace.primaryCourse?.id;

    final course = _courseById(selectedCourseId, workspace);
    if (selectedSectionId != null &&
        !(course?.sections.any((section) => section.id == selectedSectionId) ??
            false)) {
      selectedSectionId = null;
      selectedFileId = null;
    }
    selectedSectionId ??= course?.sections.firstOrNull?.id;

    final section = _sectionById(selectedSectionId, workspace);
    if (selectedFileId != null &&
        !(section?.files.any((file) => file.id == selectedFileId) ?? false)) {
      selectedFileId = null;
    }
    selectedFileId ??= section?.files.firstOrNull?.id;
  }

  void _openCourse(DriveCourse course) {
    setState(() {
      selectedCourseId = course.id;
      selectedSectionId = course.sections.firstOrNull?.id;
      selectedFileId = course.sections.firstOrNull?.files.firstOrNull?.id;
      route = WorkspaceRouteKey.course;
    });
  }

  void _openSection(DriveSection section) {
    setState(() {
      selectedSectionId = section.id;
      selectedFileId = section.files.firstOrNull?.id;
      route = WorkspaceRouteKey.folder;
    });
  }

  void _openFile(DriveFile file) {
    setState(() {
      selectedFileId = file.id;
      route = WorkspaceRouteKey.fileDetail;
    });
  }

  void _openGlobalFileSearch() {
    setState(() {
      if (route != WorkspaceRouteKey.search) {
        searchReturnRoute = route;
      }
      route = WorkspaceRouteKey.search;
    });
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
        selectedCourseId = course.id;
        selectedSectionId = null;
        selectedFileId = null;
        data = data.copyWith(courses: [course, ...data.courses]);
        route = WorkspaceRouteKey.course;
      });
      _showSnack('${course.title} oluşturuldu.');
    });
  }

  Future<void> _createSection() async {
    final course = _primaryCourse;
    if (course == null) {
      _showSnack('Bölüm eklemek için önce bir ders oluşturun.');
      return;
    }
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
      selectedCourseId = course.id;
      selectedSectionId = section.id;
      selectedFileId = null;
      _replaceCourse(course.copyWith(sections: [section, ...course.sections]));
      setState(() => route = WorkspaceRouteKey.folder);
      _showSnack('${section.title} bölümü eklendi.');
    });
  }

  Future<void> _uploadFile() async {
    final target = await _ensureUploadTarget();
    if (target == null) return;
    final (:course, :section) = target;
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
      selectedCourseId = course.id;
      selectedSectionId = section.id;
      selectedFileId = uploaded.id;
      _addFileToSection(uploaded);
      setState(() => route = WorkspaceRouteKey.uploads);
      _showSnack('${picked.name} Drive alanına yüklendi.');
    });
  }

  Future<void> _generateFromFile(GeneratedKind kind) async {
    final file = _primaryFile;
    if (file == null) {
      _showSnack('Üretim için önce Drive’dan bir dosya seçin.');
      return;
    }
    await _runAction('Üretim başlatılıyor...', () async {
      final output = await repository.createGeneratedOutput(
        file: file,
        kind: kind,
      );
      _replaceFile(file.copyWith(generated: [output, ...file.generated]));
      _showSnack('${output.title} oluşturuldu.');
    });
  }

  Future<({DriveCourse course, DriveSection section})?>
  _ensureUploadTarget() async {
    var course = _primaryCourse;
    if (course == null) {
      final title = await _textDialog(
        title: 'Ders Oluştur',
        label: 'Ders adı',
        initialValue: 'Yeni Ders',
      );
      if (title == null || title.trim().isEmpty) return null;
      try {
        course = await repository.createCourse(title.trim());
      } catch (error) {
        _showSnack(error.toString().replaceFirst('Exception: ', ''));
        return null;
      }
      setState(() {
        selectedCourseId = course!.id;
        data = data.copyWith(courses: [course, ...data.courses]);
      });
    }

    var section = _primarySection;
    if (section == null || selectedCourseId != course.id) {
      section = course.sections.firstOrNull;
    }
    if (section == null) {
      final title = await _textDialog(
        title: 'Bölüm Ekle',
        label: 'Bölüm adı',
        initialValue: 'Yeni Bölüm',
      );
      if (title == null || title.trim().isEmpty) return null;
      try {
        section = await repository.createSection(
          courseId: course.id,
          title: title.trim(),
        );
      } catch (error) {
        _showSnack(error.toString().replaceFirst('Exception: ', ''));
        return null;
      }
      final updatedCourse = course.copyWith(
        sections: [section, ...course.sections],
      );
      setState(() {
        selectedCourseId = course!.id;
        selectedSectionId = section!.id;
        data = data.copyWith(
          courses: [
            for (final item in data.courses)
              if (item.id == updatedCourse.id) updatedCourse else item,
          ],
        );
      });
      course = updatedCourse;
    }

    selectedCourseId = course.id;
    selectedSectionId = section.id;
    return (course: course, section: section);
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
    final course = _primaryCourse;
    final section = _primarySection;
    if (course == null || section == null) return;
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
      WorkspaceRouteKey.store => 4,
      _ => 1,
    };
  }

  DriveWorkspaceData get _workspaceData {
    return data;
  }

  DriveCourse? get _primaryCourse =>
      _courseById(selectedCourseId, _workspaceData) ??
      _workspaceData.primaryCourse;

  DriveSection? get _primarySection =>
      _sectionById(selectedSectionId, _workspaceData) ??
      _primaryCourse?.sections.firstOrNull;

  DriveFile? get _primaryFile =>
      _fileById(selectedFileId, _workspaceData) ??
      _primarySection?.files.firstOrNull;

  DriveCourse? _courseById(String? id, [DriveWorkspaceData? workspace]) {
    if (id == null) return null;
    for (final course in (workspace ?? _workspaceData).courses) {
      if (course.id == id) return course;
    }
    return null;
  }

  DriveSection? _sectionById(String? id, [DriveWorkspaceData? workspace]) {
    if (id == null) return null;
    for (final course in (workspace ?? _workspaceData).courses) {
      for (final section in course.sections) {
        if (section.id == id) return section;
      }
    }
    return null;
  }

  DriveFile? _fileById(String? id, [DriveWorkspaceData? workspace]) {
    if (id == null) return null;
    for (final course in (workspace ?? _workspaceData).courses) {
      for (final section in course.sections) {
        for (final file in section.files) {
          if (file.id == id) return file;
        }
      }
    }
    return null;
  }

  List<DriveFile> get _allFiles {
    final workspace = _workspaceData;
    return [
      for (final course in workspace.courses)
        for (final section in course.sections) ...section.files,
    ];
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
    return ScreenTypeLayout.builder(
      mobile: (context) => _MobileLayout(screen: _buildScreen(), state: this),
      tablet: (context) => _TabletLayout(screen: _buildScreen(), state: this),
      desktop: (context) => _DesktopLayout(screen: _buildScreen(), state: this),
    );
  }

  Widget _buildScreen() {
    final workspace = _workspaceData;
    final course = _primaryCourse;
    final section = _primarySection;
    final file = _primaryFile;

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 180),
      child: loading
          ? const Center(child: CircularProgressIndicator())
          : errorMessage != null
          ? _ErrorState(
              message: 'Bir Sorun Oluştu',
              subtitle: errorMessage!,
              onRetry: _load,
            )
          : KeyedSubtree(
              key: ValueKey(route),
              child: switch (route) {
                WorkspaceRouteKey.home => DriveHomeScreen(
                  data: workspace,
                  onSearch: _openGlobalFileSearch,
                  onOpenCourse: _openCourse,
                  onOpenFile: _openFile,
                  onCreateCourse: _createCourse,
                  onOpenUploads: _uploadFile,
                  onOpenUploadsPage: () => _go(WorkspaceRouteKey.uploads),
                  onOpenCollections: () => _go(WorkspaceRouteKey.collections),
                  onRefresh: _load,
                ),
                WorkspaceRouteKey.course =>
                  course == null
                      ? const _ErrorPlaceholder()
                      : CourseDetailScreen(
                          course: course,
                          onSearch: _openGlobalFileSearch,
                          onBack: () => _go(WorkspaceRouteKey.home),
                          onOpenSection: _openSection,
                          onCreateSection: _createSection,
                          onOpenUploads: _uploadFile,
                        ),
                WorkspaceRouteKey.folder =>
                  (course == null || section == null)
                      ? const _ErrorPlaceholder()
                      : FolderScreen(
                          course: course,
                          section: section,
                          onSearch: _openGlobalFileSearch,
                          onBack: () => _go(WorkspaceRouteKey.course),
                          onOpenFile: _openFile,
                          onOpenUploads: _uploadFile,
                          onOpenCollections: () =>
                              _go(WorkspaceRouteKey.collections),
                        ),
                WorkspaceRouteKey.fileDetail =>
                  file == null
                      ? const _ErrorPlaceholder()
                      : FileDetailScreen(
                          file: file,
                          onSearch: _openGlobalFileSearch,
                          onBack: () => _go(WorkspaceRouteKey.folder),
                          onGenerate: _generateFromFile,
                        ),
                WorkspaceRouteKey.search => DriveSearchScreen(
                  files: _allFiles,
                  onBack: () => _go(searchReturnRoute),
                  onOpenFile: _openFile,
                ),
                WorkspaceRouteKey.uploads => UploadsScreen(
                  uploads: workspace.uploads,
                  onSearch: _openGlobalFileSearch,
                  onBack: () => _go(WorkspaceRouteKey.home),
                  onNewFile: _uploadFile,
                ),
                WorkspaceRouteKey.collections => CollectionsScreen(
                  data: workspace,
                  onSearch: _openGlobalFileSearch,
                  onBackToDrive: () => _go(WorkspaceRouteKey.home),
                ),
                WorkspaceRouteKey.baseForce => BaseForceScreen(
                  data: workspace,
                  onSearch: _openGlobalFileSearch,
                ),
                WorkspaceRouteKey.centralAi => CentralAiScreen(
                  onSearch: _openGlobalFileSearch,
                ),
                WorkspaceRouteKey.sourceLab => SourceLabScreen(
                  data: workspace,
                  onSearch: _openGlobalFileSearch,
                ),
                WorkspaceRouteKey.profile => ProfileScreen(
                  onSearch: _openGlobalFileSearch,
                  onOpenStore: () => _go(WorkspaceRouteKey.store),
                ),
                WorkspaceRouteKey.store => MedasiCoinStoreScreen(
                  onSearch: _openGlobalFileSearch,
                  onBack: () => _go(WorkspaceRouteKey.profile),
                ),
              },
            ),
    );
  }
}

class _MobileLayout extends StatelessWidget {
  const _MobileLayout({required this.screen, required this.state});

  final Widget screen;
  final _DriveWorkspaceScreenState state;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          screen,
          SourceBaseBottomNav(
            selectedIndex: state._selectedNavIndex,
            onChanged: state._onNavChanged,
          ),
          if (state.busy)
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

class _TabletLayout extends StatelessWidget {
  const _TabletLayout({required this.screen, required this.state});

  final Widget screen;
  final _DriveWorkspaceScreenState state;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          SourceBaseNavRail(
            selectedIndex: state._selectedNavIndex,
            onChanged: state._onNavChanged,
            extended: false,
          ),
          Expanded(
            child: Stack(
              children: [
                screen,
                if (state.busy)
                  const Positioned(
                    left: 0,
                    right: 0,
                    top: 0,
                    child: LinearProgressIndicator(minHeight: 3),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DesktopLayout extends StatelessWidget {
  const _DesktopLayout({required this.screen, required this.state});

  final Widget screen;
  final _DriveWorkspaceScreenState state;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          SourceBaseNavRail(
            selectedIndex: state._selectedNavIndex,
            onChanged: state._onNavChanged,
            extended: true,
          ),
          Expanded(
            child: Stack(
              children: [
                screen,
                if (state.busy)
                  const Positioned(
                    left: 0,
                    right: 0,
                    top: 0,
                    child: LinearProgressIndicator(minHeight: 3),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorPlaceholder extends StatelessWidget {
  const _ErrorPlaceholder();

  @override
  Widget build(BuildContext context) {
    return const PlaceholderWorkspaceScreen(
      title: 'İçerik Bulunamadı',
      subtitle: 'Seçili öğe Drive alanınızda mevcut değil veya silinmiş.',
      icon: Icons.error_outline_rounded,
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

class _ErrorState extends StatelessWidget {
  const _ErrorState({
    required this.message,
    required this.subtitle,
    required this.onRetry,
  });

  final String message;
  final String subtitle;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.cloud_off_rounded, size: 64, color: AppColors.red),
            const SizedBox(height: 18),
            Text(
              message,
              style: const TextStyle(
                color: AppColors.navy,
                fontSize: 24,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.muted, fontSize: 16),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: 160,
              child: SBPrimaryButton(
                label: 'Tekrar Dene',
                icon: Icons.refresh_rounded,
                onPressed: onRetry,
                size: SBButtonSize.medium,
                fullWidth: false,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
