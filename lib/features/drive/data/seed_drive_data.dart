import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import 'drive_models.dart';

class SeedDriveData {
  const SeedDriveData._();

  static final generatedForPdf = <GeneratedOutput>[
    const GeneratedOutput(
      kind: GeneratedKind.flashcard,
      title: 'Flashcard Seti',
      detail: '125 kart',
      updatedLabel: 'Bugün 10:38',
    ),
    const GeneratedOutput(
      kind: GeneratedKind.question,
      title: 'Soru Seti',
      detail: '60 soru',
      updatedLabel: 'Bugün 10:35',
    ),
    const GeneratedOutput(
      kind: GeneratedKind.summary,
      title: 'Özet',
      detail: '4 sayfa',
      updatedLabel: 'Bugün 10:31',
    ),
  ];

  static final aritmilerFiles = <DriveFile>[
    DriveFile(
      id: 'file-aritmiler-final',
      title: 'Aritmiler Final.pdf',
      kind: DriveFileKind.pdf,
      sizeLabel: '2.4 MB',
      pageLabel: '24 sayfa',
      updatedLabel: 'Bugün 10:24',
      courseTitle: 'Kardiyoloji',
      sectionTitle: 'Aritmiler',
      status: DriveItemStatus.completed,
      tag: 'Öne çıkan',
      featured: true,
      selected: true,
      generated: generatedForPdf,
    ),
    const DriveFile(
      id: 'file-antibiyotikler',
      title: 'Antibiyotikler.pptx',
      kind: DriveFileKind.pptx,
      sizeLabel: '8.7 MB',
      pageLabel: '15 sayfa',
      updatedLabel: 'Bugün 09:15',
      courseTitle: 'Kardiyoloji',
      sectionTitle: 'Aritmiler',
      status: DriveItemStatus.completed,
      tag: 'Farmakoloji',
    ),
    const DriveFile(
      id: 'file-kas-dokusu',
      title: 'Kas Dokusu.docx',
      kind: DriveFileKind.docx,
      sizeLabel: '1.3 MB',
      pageLabel: '12 sayfa',
      updatedLabel: 'Dün 16:42',
      courseTitle: 'Kardiyoloji',
      sectionTitle: 'Aritmiler',
      status: DriveItemStatus.completed,
      tag: 'Anatomi',
      selected: true,
    ),
    const DriveFile(
      id: 'file-vaka-seti',
      title: 'Aritmi Vaka Seti.zip',
      kind: DriveFileKind.zip,
      sizeLabel: '45.8 MB',
      pageLabel: '32 dosya',
      updatedLabel: 'Dün 14:07',
      courseTitle: 'Kardiyoloji',
      sectionTitle: 'Aritmiler',
      status: DriveItemStatus.completed,
    ),
  ];

  static DriveWorkspaceData workspace() {
    final cardiology = DriveCourse(
      id: 'course-cardiology',
      title: 'Kardiyoloji',
      icon: Icons.favorite_border_rounded,
      iconColor: const Color(0xFFE82D35),
      iconBackground: const Color(0xFFFFEFEF),
      status: DriveItemStatus.completed,
      updatedLabel: 'Son güncelleme bugün',
      description:
          'Kardiyoloji dersine ait tüm içerikler, bölümler halinde düzenlenmiştir.',
      sections: [
        DriveSection(
          id: 'section-aritmiler',
          title: 'Aritmiler',
          status: DriveItemStatus.completed,
          files: aritmilerFiles,
        ),
        DriveSection(
          id: 'section-heart-failure',
          title: 'Kalp Yetmezliği',
          status: DriveItemStatus.completed,
          files: [
            _smallPdf('Kalp Yetmezliği Ta...'),
            _smallPpt('Tedavi Yaklaşımları...'),
            _smallDocx('NYHA Sınıflaması...'),
            _smallPdf('Akut dekompansasyon'),
          ],
        ),
        DriveSection(
          id: 'section-valves',
          title: 'Kapak Hastalıkları',
          status: DriveItemStatus.draft,
          files: [
            _smallPdf('Aort Kapak Darlığı...'),
            _smallPpt('Mitral Yetmezlik.pptx'),
            _smallDocx('Kapak Hastalıkları...'),
          ],
        ),
        DriveSection(
          id: 'section-acs',
          title: 'AKS',
          status: DriveItemStatus.completed,
          files: [
            _smallPdf('STEMI Yönetimi.pdf'),
            _smallPpt('NSTEMI Yaklaşımı...'),
          ],
        ),
      ],
    );

    final pharmacology = DriveCourse(
      id: 'course-pharma',
      title: 'Farmakoloji',
      icon: Icons.medication_outlined,
      iconColor: AppColors.purple,
      iconBackground: const Color(0xFFF3ECFF),
      status: DriveItemStatus.completed,
      updatedLabel: 'Son güncelleme bugün',
      description: 'İlaç grupları ve mekanizma kaynakları.',
      sections: const [],
    );

    final anatomy = DriveCourse(
      id: 'course-anatomy',
      title: 'Anatomi',
      icon: Icons.airline_seat_flat_angled_outlined,
      iconColor: AppColors.blue,
      iconBackground: const Color(0xFFEAF4FF),
      status: DriveItemStatus.draft,
      updatedLabel: 'Son güncelleme dün',
      description: 'Anatomi kaynakları ve görsel notlar.',
      sections: const [],
    );

    final recent = [
      aritmilerFiles[0].copyWith(status: DriveItemStatus.processing),
      aritmilerFiles[1],
      aritmilerFiles[2].copyWith(status: DriveItemStatus.uploading),
    ];

    return DriveWorkspaceData(
      courses: [cardiology, pharmacology, anatomy],
      recentFiles: recent,
      uploads: [
        UploadTask(
          file: const DriveFile(
            id: 'upload-kardiyak',
            title: 'Kardiyak Aritmiler.pdf',
            kind: DriveFileKind.pdf,
            sizeLabel: '2.4 MB',
            pageLabel: '24 sayfa',
            updatedLabel: 'Bugün 10:24',
            courseTitle: 'Kardiyoloji',
            sectionTitle: 'Aritmiler',
            status: DriveItemStatus.uploading,
          ),
          status: DriveItemStatus.uploading,
          progress: .78,
        ),
        UploadTask(
          file: const DriveFile(
            id: 'upload-antiaritmik',
            title: 'Antiaritmik İlaçlar.pptx',
            kind: DriveFileKind.pptx,
            sizeLabel: '8.7 MB',
            pageLabel: '36 sayfa',
            updatedLabel: 'Bugün 10:21',
            courseTitle: 'Kardiyoloji',
            sectionTitle: 'Aritmiler',
            status: DriveItemStatus.processing,
          ),
          status: DriveItemStatus.processing,
          progress: .45,
        ),
        UploadTask(
          file: const DriveFile(
            id: 'upload-kalp-sesi',
            title: 'Kalp Sesi Notları.docx',
            kind: DriveFileKind.docx,
            sizeLabel: '1.3 MB',
            pageLabel: '12 sayfa',
            updatedLabel: 'Bugün 10:24',
            courseTitle: 'Kardiyoloji',
            sectionTitle: 'Aritmiler',
            status: DriveItemStatus.completed,
          ),
          status: DriveItemStatus.completed,
        ),
        UploadTask(
          file: const DriveFile(
            id: 'upload-ekokardiyo',
            title: 'Ekokardiyografi.doc',
            kind: DriveFileKind.doc,
            sizeLabel: '2.1 MB',
            pageLabel: '18 sayfa',
            updatedLabel: 'Bugün 10:19',
            courseTitle: 'Kardiyoloji',
            sectionTitle: 'Aritmiler',
            status: DriveItemStatus.failed,
          ),
          status: DriveItemStatus.failed,
          errorLabel: 'Bağlantı hatası',
        ),
      ],
      collections: [
        CollectionBundle(
          file: aritmilerFiles[0],
          outputs: const [
            GeneratedOutput(
              kind: GeneratedKind.flashcard,
              title: '28 flashcard',
              detail: '',
              updatedLabel: '',
            ),
            GeneratedOutput(
              kind: GeneratedKind.question,
              title: '14 soru',
              detail: '',
              updatedLabel: '',
            ),
            GeneratedOutput(
              kind: GeneratedKind.summary,
              title: '1 özet',
              detail: '',
              updatedLabel: '',
            ),
          ],
          subject: 'Farmakoloji',
          previewKind: GeneratedKind.flashcard,
        ),
        CollectionBundle(
          file: aritmilerFiles[1],
          outputs: const [
            GeneratedOutput(
              kind: GeneratedKind.question,
              title: '19 soru',
              detail: '',
              updatedLabel: '',
            ),
            GeneratedOutput(
              kind: GeneratedKind.table,
              title: '1 karşılaştırma tablosu',
              detail: '',
              updatedLabel: '',
            ),
            GeneratedOutput(
              kind: GeneratedKind.podcast,
              title: '1 podcast',
              detail: '',
              updatedLabel: '',
            ),
          ],
          subject: 'Farmakoloji',
          previewKind: GeneratedKind.table,
        ),
        CollectionBundle(
          file: aritmilerFiles[2],
          outputs: const [
            GeneratedOutput(
              kind: GeneratedKind.flashcard,
              title: '22 flashcard',
              detail: '',
              updatedLabel: '',
            ),
            GeneratedOutput(
              kind: GeneratedKind.mindMap,
              title: '1 zihin haritası',
              detail: '',
              updatedLabel: '',
            ),
          ],
          subject: 'Anatomi',
          previewKind: GeneratedKind.mindMap,
        ),
      ],
    );
  }

  static DriveFile _smallPdf(String title) => DriveFile(
    id: title,
    title: title,
    kind: DriveFileKind.pdf,
    sizeLabel: '1.2 MB',
    pageLabel: '8 sayfa',
    updatedLabel: 'Bugün',
    courseTitle: 'Kardiyoloji',
    sectionTitle: 'Bölüm',
    status: DriveItemStatus.completed,
  );

  static DriveFile _smallPpt(String title) => DriveFile(
    id: title,
    title: title,
    kind: DriveFileKind.pptx,
    sizeLabel: '2.7 MB',
    pageLabel: '12 sayfa',
    updatedLabel: 'Bugün',
    courseTitle: 'Kardiyoloji',
    sectionTitle: 'Bölüm',
    status: DriveItemStatus.completed,
  );

  static DriveFile _smallDocx(String title) => DriveFile(
    id: title,
    title: title,
    kind: DriveFileKind.docx,
    sizeLabel: '920 KB',
    pageLabel: '6 sayfa',
    updatedLabel: 'Bugün',
    courseTitle: 'Kardiyoloji',
    sectionTitle: 'Bölüm',
    status: DriveItemStatus.completed,
  );
}

extension DriveFileCopy on DriveFile {
  DriveFile copyWith({DriveItemStatus? status, bool? selected, String? tag}) {
    return DriveFile(
      id: id,
      title: title,
      kind: kind,
      sizeLabel: sizeLabel,
      pageLabel: pageLabel,
      updatedLabel: updatedLabel,
      courseTitle: courseTitle,
      sectionTitle: sectionTitle,
      status: status ?? this.status,
      tag: tag ?? this.tag,
      featured: featured,
      selected: selected ?? this.selected,
      generated: generated,
    );
  }
}
