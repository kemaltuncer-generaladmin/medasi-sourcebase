import SwiftUI
import SourceBaseBackend
import UniformTypeIdentifiers

struct DriveUploadSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(SourceBaseWorkspaceStore.self) private var workspaceStore

    let initialDestination: DriveDestination?
    let onUploaded: (DriveFile?) -> Void

    @State private var selectedDestination: DriveDestination?
    @State private var showFileImporter = false
    @State private var showCreateCourse = false
    @State private var showCreateSection = false
    @State private var showDestinationChoices = false

    private var destinations: [DriveDestination] {
        workspaceStore.availableDestinations
    }

    private var selectedCourseId: String? {
        selectedDestination?.courseId ?? workspaceStore.selectedCourseId ?? workspaceStore.workspace.primaryCourse?.id
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: SBSpacing.lg) {
                    uploadHero.sbEntrance(0)

                    destinationSection.sbEntrance(1)

                    if workspaceStore.uploadPhase != .idle {
                        SBNotice(
                            icon: workspaceStore.uploadPhase == .error ? "exclamationmark.triangle" : "icloud.and.arrow.up",
                            message: workspaceStore.uploadPhase.message,
                            tint: workspaceStore.uploadPhase == .error ? SBColors.red : SBColors.blue
                        ).sbEntrance(3)
                    }
                }
                .padding(SBSpacing.lg)
                .padding(.bottom, 96)
            }
            .sbPageBackground()
            .navigationTitle("Yükle")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Kapat") { dismiss() }
                }
            }
            .safeAreaInset(edge: .bottom) {
                filePickerBar
            }
        }
        .presentationDetents([.medium, .large])
        .sheet(isPresented: $showCreateCourse) {
            SBCreateNodeSheet(
            heading: "Ders oluştur",
            placeholder: "Örn: Anatomi",
            confirmLabel: "Oluştur"
        ) { title, icon, color in
            Task {
                await workspaceStore.createCourse(title: title, iconName: icon, colorHex: color)
                selectedDestination = workspaceStore.preferredUploadDestination
                showDestinationChoices = false
            }
        }
    }
        .sheet(isPresented: $showCreateSection) {
            SBCreateNodeSheet(
                heading: "Bölüm oluştur",
                placeholder: "Örn: Üst Ekstremite",
            confirmLabel: "Oluştur"
        ) { title, icon, color in
            Task {
                await workspaceStore.createSection(courseId: selectedCourseId, title: title, iconName: icon, colorHex: color)
                selectedDestination = workspaceStore.preferredUploadDestination
                showDestinationChoices = false
            }
        }
    }
    .onAppear {
        selectedDestination = initialDestination
            ?? workspaceStore.preferredUploadDestination
            ?? destinations.first
        showDestinationChoices = selectedDestination == nil
    }
        .fileImporter(
            isPresented: $showFileImporter,
            allowedContentTypes: allowedFileTypes,
            allowsMultipleSelection: false
        ) { result in
            handleFileImport(result)
        }
    }

    private var uploadHero: some View {
        SBSignatureHero(
            eyebrow: "Yükle",
            title: "Dosya seç",
            message: "\(DriveUploadService.supportedExtensionsDisplay) kaynakları ekleyebilirsin.",
            icon: "icloud.and.arrow.up",
            tint: SBColors.blue
        ) {
            EmptyView()
        } footer: {
            EmptyView()
        }
    }

    private var filePickerBar: some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(SBColors.softLine)
                .frame(height: 0.5)

            SBButton(
                "Dosya seç",
                icon: "icloud.and.arrow.up",
                variant: .primary,
                size: .large,
                isLoading: workspaceStore.isBusy,
                fullWidth: true
            ) {
                guard selectedDestination != nil else {
                    workspaceStore.toast("Yükleme için bir ders ve bölüm seç.")
                    return
                }
                showFileImporter = true
            }
            .accessibilityHint("Seçili ders ve bölüme dosya yükler")
            .padding(.horizontal, SBSpacing.lg)
            .padding(.top, SBSpacing.md)
            .padding(.bottom, SBSpacing.sm)
        }
        .background(SBColors.white.opacity(0.96))
    }

    private var destinationSection: some View {
        VStack(alignment: .leading, spacing: SBSpacing.md) {
            SBSectionHeader(title: "Hedef")

            if destinations.isEmpty {
                SBEmptyState(
                    icon: "folder.badge.plus",
                    title: "Önce bir ders alanı oluştur",
                    message: "Kaynakların kaydedileceği bir ders ve bölüm gerekir.",
                    actionLabel: "Ders oluştur",
                    onAction: { showCreateCourse = true }
                )
            } else if let selectedDestination, !showDestinationChoices {
                selectedDestinationSummary(selectedDestination)
            } else {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 180), spacing: SBSpacing.sm)], spacing: SBSpacing.sm) {
                    ForEach(destinations, id: \.sectionId) { destination in
                        destinationButton(destination)
                    }
                }

                HStack(spacing: SBSpacing.sm) {
                    SBButton("Ders ekle", icon: "plus", variant: .secondary, size: .small) {
                        showCreateCourse = true
                    }

                    SBButton("Bölüm ekle", icon: "folder.badge.plus", variant: .secondary, size: .small) {
                        showCreateSection = true
                    }
                }
            }
        }
    }

    private func selectedDestinationSummary(_ destination: DriveDestination) -> some View {
        VStack(alignment: .leading, spacing: SBSpacing.sm) {
            HStack(spacing: SBSpacing.md) {
                Image(systemName: "folder.fill")
                    .sbScaledFont(size: 18, weight: .semibold)
                    .foregroundStyle(SBColors.blue)
                    .frame(width: 38, height: 38)
                    .background(SBColors.selectedBlue)
                    .clipShape(RoundedRectangle(cornerRadius: 11))
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 3) {
                    Text(destination.courseTitle)
                        .font(SBTypography.labelMedium)
                        .foregroundStyle(SBColors.navy)
                        .lineLimit(1)
                    Text(destination.sectionTitle)
                        .font(SBTypography.caption)
                        .foregroundStyle(SBColors.muted)
                        .lineLimit(1)
                }

                Spacer()

                Button("Değiştir") {
                    showDestinationChoices = true
                }
                .font(SBTypography.labelSmall)
                .foregroundStyle(SBColors.blue)
            }
            .padding(SBSpacing.md)
            .background(SBColors.white)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(SBColors.softLine, lineWidth: 1)
            )

            SBButton("Bölüm ekle", icon: "folder.badge.plus", variant: .secondary, size: .small) {
                showCreateSection = true
            }
        }
    }

    private func destinationButton(_ destination: DriveDestination) -> some View {
        let isSelected = selectedDestination == destination
        return Button {
            SBHaptics.selection()
            selectedDestination = destination
            workspaceStore.currentUploadDestination = destination
            showDestinationChoices = false
        } label: {
            HStack(spacing: SBSpacing.md) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "folder")
                    .sbScaledFont(size: 18, weight: .semibold)
                    .foregroundStyle(isSelected ? SBColors.blue : SBColors.muted)

                VStack(alignment: .leading, spacing: 3) {
                    Text(destination.courseTitle)
                        .font(SBTypography.labelMedium)
                        .foregroundStyle(SBColors.navy)
                        .lineLimit(1)
                    Text(destination.sectionTitle)
                        .font(SBTypography.caption)
                        .foregroundStyle(SBColors.muted)
                        .lineLimit(1)
                }

                Spacer(minLength: 0)
            }
            .padding(SBSpacing.md)
            .frame(maxWidth: .infinity, minHeight: 58, alignment: .leading)
            .background(isSelected ? SBColors.selectedBlue : SBColors.white)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? SBColors.blue.opacity(0.24) : SBColors.softLine, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(destination.courseTitle), \(destination.sectionTitle)")
        .accessibilityValue(isSelected ? "Seçili" : "")
    }

    private var allowedFileTypes: [UTType] {
        DriveUploadService.allowedExtensions.compactMap { UTType(filenameExtension: $0) }
    }

    private func handleFileImport(_ result: Result<[URL], Error>) {
        do {
            guard let destination = selectedDestination else {
                workspaceStore.toast("Yükleme için bir ders ve bölüm seç.")
                return
            }
            guard let url = try result.get().first else {
                workspaceStore.toast("Dosya seçilmedi.")
                return
            }
            let didAccess = url.startAccessingSecurityScopedResource()
            defer {
                if didAccess {
                    url.stopAccessingSecurityScopedResource()
                }
            }
            let values = try url.resourceValues(forKeys: [.fileSizeKey])
            let sizeBytes = values.fileSize ?? 0
            let picked = PickedDriveFile(
                name: url.lastPathComponent,
                contentType: DriveUploadService.contentTypeFor(url.lastPathComponent),
                sizeBytes: sizeBytes,
                fileURL: url
            )
            Task {
                await workspaceStore.uploadPickedFile(picked, destination: destination)
                let uploaded = workspaceStore.file(id: workspaceStore.selectedFileId)
                onUploaded(uploaded)
                dismiss()
            }
        } catch {
            workspaceStore.toast(workspaceStore.friendlyError(error))
        }
    }
}
