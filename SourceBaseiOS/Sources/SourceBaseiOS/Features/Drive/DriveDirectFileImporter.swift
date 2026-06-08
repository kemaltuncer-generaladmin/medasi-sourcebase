import SwiftUI
import SourceBaseBackend
import UniformTypeIdentifiers

struct DriveDirectFileImporter: ViewModifier {
    @Environment(SourceBaseWorkspaceStore.self) private var workspaceStore

    @Binding var isPresented: Bool
    let initialDestination: DriveDestination?
    let onUploaded: (DriveFile?) -> Void

    @State private var showFileImporter = false
    @State private var selectedDestination: DriveDestination?

    func body(content: Content) -> some View {
        content
            .onChange(of: isPresented) { _, requested in
                guard requested else { return }
                Task { await openFileImporter() }
            }
            .fileImporter(
                isPresented: $showFileImporter,
                allowedContentTypes: allowedFileTypes,
                allowsMultipleSelection: false
            ) { result in
                handleFileImport(result)
            }
    }

    private var allowedFileTypes: [UTType] {
        DriveUploadService.allowedExtensions.compactMap { UTType(filenameExtension: $0) }
    }

    @MainActor
    private func openFileImporter() async {
        defer { isPresented = false }
        if !workspaceStore.hasLoadedWorkspace {
            await workspaceStore.loadWorkspace()
        }

        guard let destination = await resolveDestination() else {
            workspaceStore.toast("Yükleme için ders ve bölüm oluşturulamadı.")
            return
        }
        selectedDestination = destination
        showFileImporter = true
    }

    @MainActor
    private func resolveDestination() async -> DriveDestination? {
        if let initialDestination, initialDestination.isUsable {
            return initialDestination
        }
        if let preferred = workspaceStore.preferredUploadDestination {
            return preferred
        }

        let course: DriveCourse?
        if let primaryCourse = workspaceStore.workspace.primaryCourse {
            course = primaryCourse
        } else {
            course = await workspaceStore.createCourse(
                title: "Yeni Ders",
                iconName: "book.closed",
                colorHex: "#0A5BFF"
            )
        }
        guard let course else { return workspaceStore.preferredUploadDestination }

        if let section = course.sections.first {
            return DriveDestination(
                courseId: course.id,
                sectionId: section.id,
                courseTitle: course.title,
                sectionTitle: section.title
            )
        }

        let section = await workspaceStore.createSection(
            courseId: course.id,
            title: "Genel",
            iconName: "folder",
            colorHex: "#0A5BFF"
        )
        guard let section else { return workspaceStore.preferredUploadDestination }
        let resolvedCourse = workspaceStore.course(id: course.id) ?? course
        return DriveDestination(
            courseId: resolvedCourse.id,
            sectionId: section.id,
            courseTitle: resolvedCourse.title,
            sectionTitle: section.title
        )
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
            let picked = try pickedFile(from: url)
            Task {
                await workspaceStore.uploadPickedFile(picked, destination: destination)
                let uploaded = workspaceStore.file(id: workspaceStore.selectedFileId)
                onUploaded(uploaded)
            }
        } catch {
            workspaceStore.toast(workspaceStore.friendlyError(error))
        }
    }

    private func pickedFile(from url: URL) throws -> PickedDriveFile {
        let didAccess = url.startAccessingSecurityScopedResource()
        defer {
            if didAccess {
                url.stopAccessingSecurityScopedResource()
            }
        }
        let values = try url.resourceValues(forKeys: [.fileSizeKey, .localizedNameKey, .contentTypeKey])
        let fileName = values.localizedName?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
            ? values.localizedName!
            : url.lastPathComponent
        return PickedDriveFile(
            name: fileName,
            contentType: values.contentType?.preferredMIMEType ?? DriveUploadService.contentTypeFor(fileName),
            sizeBytes: values.fileSize ?? 0,
            fileURL: url
        )
    }
}

extension View {
    func driveDirectFileImporter(
        isPresented: Binding<Bool>,
        initialDestination: DriveDestination?,
        onUploaded: @escaping (DriveFile?) -> Void
    ) -> some View {
        modifier(
            DriveDirectFileImporter(
                isPresented: isPresented,
                initialDestination: initialDestination,
                onUploaded: onUploaded
            )
        )
    }
}
