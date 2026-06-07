import Foundation
import SourceBaseBackend
import Supabase

private struct WorkspaceStoreError: Error {
    let message: String
}

public enum SBUploadPhase: String, Sendable {
    case idle
    case selecting
    case extracting
    case uploading
    case completing
    case success
    case error

    var message: String {
        switch self {
        case .idle: return "Yükleme beklemede."
        case .selecting: return "Dosya seçiliyor..."
        case .extracting: return "Metin çıkarılıyor..."
        case .uploading: return "Dosya güvenli şekilde yükleniyor."
        case .completing: return "Kaynak Drive alanına ekleniyor."
        case .success: return "Dosya Drive alanına eklendi."
        case .error: return "Yükleme tamamlanamadı. Tekrar deneyebilirsin."
        }
    }
}

public enum SBGenerationStatus: Sendable, Equatable {
    case queued
    case running
    case completed
    case failed(String)
}

public struct SBGenerationJob: Identifiable, Sendable {
    public let id: String
    public let sourceFileId: String
    public let sourceTitle: String
    public let kind: GeneratedKind
    public var status: SBGenerationStatus
    public var progress: Double
    public var output: GeneratedOutput?
    public var outputId: String?

    public init(
        id: String,
        sourceFileId: String,
        sourceTitle: String,
        kind: GeneratedKind,
        status: SBGenerationStatus,
        progress: Double,
        output: GeneratedOutput? = nil,
        outputId: String? = nil
    ) {
        self.id = id
        self.sourceFileId = sourceFileId
        self.sourceTitle = sourceTitle
        self.kind = kind
        self.status = status
        self.progress = progress
        self.output = output
        self.outputId = outputId
    }
}

@Observable
@MainActor
public final class SourceBaseWorkspaceStore {
    public static let shared = SourceBaseWorkspaceStore()

    public var workspace: DriveWorkspaceData = .empty
    public var isLoading = false
    /// True once the workspace has been fetched at least once. Lets secondary
    /// screens (factories, SourceLab tools) skip the full-screen loading veil
    /// when data is already in memory, so reopening a tool feels instant.
    public private(set) var hasLoadedWorkspace = false
    public var isBusy = false
    public var errorMessage: String?
    public var toastMessage: String?
    public var uploadPhase: SBUploadPhase = .idle
    public var selectedCourseId: String?
    public var selectedSectionId: String?
    public var selectedFileId: String?
    public var selectedSourceIds: Set<String> = []
    public var generationJobs: [SBGenerationJob] = []
    public var currentUploadDestination: DriveDestination?

    private let uploadService = DriveUploadService()

    private init() {}

    public var allFiles: [DriveFile] {
        var seen = Set<String>()
        var files: [DriveFile] = []
        for file in workspace.recentFiles + workspace.courses.flatMap({ $0.sections.flatMap(\.files) }) {
            guard !file.id.isEmpty, seen.insert(file.id).inserted else { continue }
            files.append(file)
        }
        return files
    }

    public var readyFiles: [DriveFile] {
        allFiles.filter { isReadyForGeneration($0) }
    }

    public var selectedReadyFiles: [DriveFile] {
        readyFiles.filter { selectedSourceIds.contains($0.id) }
    }

    public var totalGeneratedOutputCount: Int {
        allFiles.reduce(into: 0) { result, file in
            result += file.generated.count
        }
    }

    public var latestGeneratedPairs: [(file: DriveFile, output: GeneratedOutput)] {
        allFiles.compactMap { file in
            file.generated.first.map { output in
                (file: file, output: output)
            }
        }
    }

    public var quickContinueOutput: (file: DriveFile, output: GeneratedOutput)? {
        latestGeneratedPairs.first
    }

    public var quickContinueReadyFile: DriveFile? {
        if let selectedSource = readyFiles.first(where: { selectedSourceIds.contains($0.id) }) {
            return selectedSource
        }
        if let selectedFile = file(id: selectedFileId), isReadyForGeneration(selectedFile) {
            return selectedFile
        }
        return readyFiles.first
    }

    public var momentumFocusTitle: String {
        quickContinueOutput?.file.courseTitle
            ?? quickContinueReadyFile?.courseTitle
            ?? workspace.primaryCourse?.title
            ?? "Hazır kaynak bekleniyor"
    }

    public func loadWorkspace(force: Bool = false) async {
        if isLoading && !force { return }

        isLoading = true
        errorMessage = nil
        do {
            let repo = try await repository()
            workspace = try await repo.loadWorkspace()
            hasLoadedWorkspace = true
            syncSelection()
            try? await refreshGenerationJobs(using: repo)
        } catch {
            errorMessage = friendlyError(error)
            workspace = .empty
        }
        isLoading = false
    }

    public func refresh() async {
        await loadWorkspace(force: true)
    }

    public func refreshGenerationQueue() async {
        do {
            let repo = try await repository()
            try await refreshGenerationJobs(using: repo)
        } catch {
            toast(friendlyError(error))
        }
    }

    public func file(id: String?) -> DriveFile? {
        guard let id else { return nil }
        return allFiles.first { $0.id == id }
    }

    public func generatedOutput(id: String?) -> GeneratedOutput? {
        guard let id else { return nil }
        return allFiles
            .flatMap(\.generated)
            .first { $0.id == id || $0.jobId == id }
    }

    public func course(id: String?) -> DriveCourse? {
        guard let id else { return nil }
        return workspace.courses.first { $0.id == id }
    }

    public func section(id: String?) -> DriveSection? {
        guard let id else { return nil }
        return workspace.courses.flatMap(\.sections).first { $0.id == id }
    }

    public func selectFile(_ file: DriveFile) {
        selectedFileId = file.id
        for course in workspace.courses {
            for section in course.sections where section.files.contains(where: { $0.id == file.id }) {
                selectedCourseId = course.id
                selectedSectionId = section.id
                return
            }
        }
    }

    public func setSelectedSources(_ ids: Set<String>) {
        selectedSourceIds = Set(ids.filter { id in
            guard let file = file(id: id) else { return false }
            return isReadyForGeneration(file)
        })
        let orderedSelection = readyFiles.filter { selectedSourceIds.contains($0.id) }
        if let first = orderedSelection.first,
           selectedFileId == nil || !selectedSourceIds.contains(selectedFileId ?? "") {
            selectFile(first)
        }
    }

    public func toggleSource(_ file: DriveFile) {
        guard isReadyForGeneration(file) else {
            toast("Bu kaynak hazır olmadan üretime alınamaz.")
            return
        }
        if selectedSourceIds.contains(file.id) {
            selectedSourceIds.remove(file.id)
        } else {
            selectedSourceIds.insert(file.id)
        }
    }

    public func isReadyForGeneration(_ file: DriveFile) -> Bool {
        file.isReadyForGeneration && !file.id.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    public func createCourse(
        title: String = "Yeni Ders",
        iconName: String? = nil,
        colorHex: String? = nil
    ) async {
        await runBusy("Ders oluşturuluyor...") {
            _ = try await repository().createCourse(title, iconName: iconName, colorHex: colorHex)
            await refresh()
        }
    }

    public func createSection(
        courseId: String? = nil,
        title: String = "Genel",
        iconName: String? = nil,
        colorHex: String? = nil
    ) async {
        await runBusy("Bölüm ekleniyor...") {
            let targetCourse = course(id: courseId) ?? workspace.primaryCourse
            guard let targetCourse else {
                _ = try await repository().createCourse("Yeni Ders")
                await refresh()
                return
            }
            _ = try await repository().createSection(
                courseId: targetCourse.id,
                title: title,
                iconName: iconName,
                colorHex: colorHex
            )
            await refresh()
        }
    }

    public func renameCourse(_ courseId: String, title: String) async {
        let cleanTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanTitle.isEmpty else {
            toast("Ders adı boş olamaz.")
            return
        }

        await runBusy("Ders yeniden adlandırılıyor...") {
            _ = try await repository().renameCourse(courseId: courseId, title: cleanTitle)
            await refresh()
        }
    }

    public func renameSection(_ sectionId: String, title: String) async {
        let cleanTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanTitle.isEmpty else {
            toast("Bölüm adı boş olamaz.")
            return
        }

        await runBusy("Bölüm yeniden adlandırılıyor...") {
            _ = try await repository().renameSection(sectionId: sectionId, title: cleanTitle)
            await refresh()
        }
    }

    public func deleteCourse(_ courseId: String) async {
        await runBusy("Ders siliniyor...") {
            try await repository().deleteCourse(courseId)
            await refresh()
        }
    }

    public func deleteSection(_ sectionId: String) async {
        await runBusy("Bölüm siliniyor...") {
            try await repository().deleteSection(sectionId)
            await refresh()
        }
    }

    public func renameFile(_ fileId: String, title: String) async {
        let cleanTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanTitle.isEmpty else {
            toast("Dosya adı boş olamaz.")
            return
        }

        await runBusy("Dosya yeniden adlandırılıyor...") {
            let current = file(id: fileId)
            _ = try await repository().renameFile(
                fileId: fileId,
                title: cleanTitle,
                courseTitle: current?.courseTitle ?? "",
                sectionTitle: current?.sectionTitle ?? ""
            )
            await refresh()
        }
    }

    public func moveFiles(_ fileIds: [String], courseId: String? = nil, sectionId: String? = nil) async {
        let ids = Array(Set(fileIds.filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }))
        guard !ids.isEmpty else { return }

        let targetCourseId = courseId ?? selectedCourseId ?? workspace.primaryCourse?.id
        let targetSectionId = sectionId ?? selectedSectionId ?? course(id: targetCourseId)?.sections.first?.id
        guard let targetCourseId, let targetSectionId else {
            toast("Dosyaları taşıyacak bir ders ve bölüm seç.")
            return
        }

        await runBusy("Dosyalar taşınıyor...") {
            try await repository().moveFiles(fileIds: ids, courseId: targetCourseId, sectionId: targetSectionId)
            await refresh()
        }
    }

    /// Save a generated output into a course section (first-class item).
    public func saveOutput(_ outputId: String, courseId: String, sectionId: String) async {
        let id = outputId.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !id.isEmpty else { return }
        await runBusy("Çıktı kaydediliyor...") {
            try await repository().moveGeneratedOutput(outputId: id, courseId: courseId, sectionId: sectionId)
            await refresh()
        }
    }

    public func deleteFiles(_ fileIds: [String]) async {
        let ids = Set(fileIds.filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty })
        guard !ids.isEmpty else { return }

        await runBusy("Dosyalar siliniyor...") {
            try await repository().deleteFiles(Array(ids))
            await refresh()
        }
    }

    public func retryFileProcessing(_ fileId: String) async {
        await runBusy("Dosya yeniden işleme alınıyor...") {
            try await repository().retryFileProcessing(fileId)
            await refresh()
        }
    }

    public func addToCollection(fileId: String, outputId: String? = nil, collection: String? = nil) async {
        await runBusy("Koleksiyona ekleniyor...") {
            try await repository().addToCollection(fileId: fileId, outputId: outputId, collection: collection)
            await refresh()
        }
    }

    public var availableDestinations: [DriveDestination] {
        workspace.courses.flatMap { course in
            course.sections.map { section in
                DriveDestination(
                    courseId: course.id,
                    sectionId: section.id,
                    courseTitle: course.title,
                    sectionTitle: section.title
                )
            }
        }
    }

    public var preferredUploadDestination: DriveDestination? {
        if let currentUploadDestination,
           availableDestinations.contains(currentUploadDestination) {
            return currentUploadDestination
        }
        guard let course = course(id: selectedCourseId) ?? workspace.primaryCourse,
              let section = section(id: selectedSectionId) ?? course.sections.first else {
            return nil
        }
        return DriveDestination(
            courseId: course.id,
            sectionId: section.id,
            courseTitle: course.title,
            sectionTitle: section.title
        )
    }

    public func uploadPickedFile(_ file: PickedDriveFile, destination: DriveDestination) async {
        guard !isBusy else { return }
        guard destination.isUsable else {
            uploadPhase = .error
            toast("Yükleme için ders ve bölüm seç.")
            return
        }
        guard file.hasSupportedExtension else {
            uploadPhase = .error
            toast("Bu dosya türü desteklenmiyor. \(DriveUploadService.supportedExtensionsDisplay) yükleyebilirsin.")
            return
        }
        guard file.hasReadableContent else {
            uploadPhase = .error
            toast("Dosya okunamadı veya boş görünüyor.")
            return
        }
        guard file.sizeBytes <= DriveUploadService.maxSizeBytes else {
            uploadPhase = .error
            toast("Dosya boyutu 100 MB sınırını aşıyor.")
            return
        }

        isBusy = true
        uploadPhase = .selecting
        do {
            uploadPhase = .extracting
            toast(uploadPhase.message)

            var extractedText: String? = nil
            var pageCount: Int? = nil
            var extractionMetadata: ExtractionMetadata? = nil

            if let fileURL = file.fileURL {
                let extractor = DocumentExtractor.shared
                let result = try await extractor.extract(from: fileURL, fileType: file.contentType)
                extractedText = result.text
                pageCount = result.pageCount
                extractionMetadata = result.metadata
            }

            uploadPhase = .uploading
            toast(uploadPhase.message)
            let draft = DriveUploadDraft(
                fileName: file.name,
                contentType: file.contentType,
                sizeBytes: file.sizeBytes,
                courseId: destination.courseId,
                sectionId: destination.sectionId
            )
            let session = try await repository().createUploadSession(draft)
            try await uploadService.uploadBytes(uploadURL: session.uploadURL, headers: session.headers, file: file)
            uploadPhase = .completing
            toast(uploadPhase.message)
            let uploaded = try await repository().completeUpload(
                file: file,
                objectName: session.objectName,
                courseId: destination.courseId,
                sectionId: destination.sectionId,
                courseTitle: destination.courseTitle,
                sectionTitle: destination.sectionTitle,
                extractedText: extractedText,
                pageCount: pageCount,
                extractionMetadata: extractionMetadata
            )
            selectedCourseId = destination.courseId
            selectedSectionId = destination.sectionId
            selectedFileId = uploaded.id
            currentUploadDestination = destination
            uploadPhase = .success
            toast("\(file.name) Drive alanına eklendi.")
            await refresh()
        } catch {
            uploadPhase = .error
            toast(friendlyError(error))
        }
        isBusy = false
    }

    public func uploadPickedFile(_ file: PickedDriveFile) async {
        guard let destination = preferredUploadDestination else {
            uploadPhase = .error
            toast("Yükleme için önce bir ders ve bölüm oluştur.")
            return
        }
        await uploadPickedFile(file, destination: destination)
    }

    public func generate(file: DriveFile? = nil, kind: GeneratedKind, options: [String: String]? = nil) async -> GeneratedOutput? {
        let source = file ?? selectedReadyFiles.first ?? readyFiles.first
        guard let source else {
            toast("Üretim için önce hazır bir Drive kaynağı seç.")
            return nil
        }
        guard isReadyForGeneration(source) else {
            toast("Üretim için dosyanın yüklenip işlenmesi tamamlanmalı.")
            return nil
        }

        guard kind.jobType != nil else {
            toast("\(kind.titleLabel) üretimi bu sürümde henüz açılmadı.")
            return nil
        }

        do {
            let sourceIds = Array((selectedSourceIds.union([source.id])).filter { !$0.isEmpty })
            let enrichedOptions = generationOptions(
                base: options,
                source: source,
                kind: kind,
                sourceIds: sourceIds
            )
            let output = try await repository().createGeneratedOutput(
                file: source,
                kind: kind,
                options: enrichedOptions,
                sourceIds: sourceIds
            )
            toast("\(output.title) oluşturuldu.")
            await refresh()
            return output
        } catch {
            toast(friendlyError(error))
            if let repo = try? await repository() {
                try? await refreshGenerationJobs(using: repo)
            }
            return nil
        }
    }

    public func startGeneration(file: DriveFile? = nil, kind: GeneratedKind, options: [String: String]? = nil) async -> SBGenerationJob? {
        let source = file ?? selectedReadyFiles.first ?? readyFiles.first
        guard let source else {
            toast("Üretim için önce hazır bir Drive kaynağı seç.")
            return nil
        }
        guard isReadyForGeneration(source) else {
            toast("Üretim için dosyanın yüklenip işlenmesi tamamlanmalı.")
            return nil
        }

        guard kind.jobType != nil else {
            toast("\(kind.titleLabel) üretimi bu sürümde henüz açılmadı.")
            return nil
        }

        do {
            let sourceIds = Array((selectedSourceIds.union([source.id])).filter { !$0.isEmpty })
            let enrichedOptions = generationOptions(
                base: options,
                source: source,
                kind: kind,
                sourceIds: sourceIds
            )
            let snapshot = try await repository().startGenerationJob(
                file: source,
                kind: kind,
                options: enrichedOptions,
                sourceIds: sourceIds
            )
            let job = SBGenerationJob(
                id: snapshot.jobId ?? snapshot.id,
                sourceFileId: snapshot.sourceFileId,
                sourceTitle: snapshot.sourceTitle,
                kind: snapshot.kind,
                status: generationStatus(from: snapshot.status, errorMessage: snapshot.errorMessage),
                progress: snapshot.progress,
                output: generatedOutput(id: snapshot.outputId),
                outputId: snapshot.outputId
            )
            upsertGenerationJob(job)
            toast("\(kind.titleLabel) üretimi kuyruğa alındı.")
            await refreshGenerationQueue()
            return generationJobs.first { $0.id == job.id } ?? job
        } catch {
            toast(friendlyError(error))
            if let repo = try? await repository() {
                try? await refreshGenerationJobs(using: repo)
            }
            return nil
        }
    }

    public func finalizeGenerationJob(_ job: SBGenerationJob) async -> GeneratedOutput? {
        guard let source = file(id: job.sourceFileId) else {
            toast("Bu üretimi tamamlamak için kaynak bulunamadı.")
            return nil
        }

        do {
            let output = try await repository().finalizeGenerationJob(
                file: source,
                kind: job.kind,
                jobId: job.id
            )
            if let output {
                toast("\(output.title) hazır.")
                await refresh()
            } else {
                await refreshGenerationQueue()
            }
            return output
        } catch {
            toast(friendlyError(error))
            if let index = generationJobs.firstIndex(where: { $0.id == job.id }) {
                generationJobs[index].status = .failed(friendlyError(error))
                generationJobs[index].progress = 1
            }
            return nil
        }
    }

    public func cancelJob(_ job: SBGenerationJob) async {
        do {
            let repo = try await repository()
            try await repo.cancelJob(job.id)
            if let index = generationJobs.firstIndex(where: { $0.id == job.id }) {
                generationJobs[index].status = .failed("Üretim durduruldu.")
                generationJobs[index].progress = 1
            }
            toast("Üretim durduruldu.")
            try? await refreshGenerationJobs(using: repo)
        } catch {
            toast(friendlyError(error))
        }
    }

    public func retryJob(_ job: SBGenerationJob) async {
        do {
            let repo = try await repository()
            try await repo.retryJob(job.id)
            if let index = generationJobs.firstIndex(where: { $0.id == job.id }) {
                generationJobs[index].status = .running
                generationJobs[index].progress = 0.25
            }
            toast("Üretim yeniden kuyruğa alındı.")
            try? await refreshGenerationJobs(using: repo)
            await refresh()
        } catch {
            toast(friendlyError(error))
        }
    }

    public func sendCentralAIMessage(_ message: String, fileIds: [String] = []) async throws -> String {
        let context = centralAIContext(for: fileIds)
        let driveAPI = try await api()
        let response = try await driveAPI.centralAiChat(message, context: context, fileIds: fileIds)
        return responseText(from: response)
    }

    public func loadQuestionSession(outputId: String) async throws -> [SBQuestionPrompt] {
        let driveAPI = try await api()
        let response = try await driveAPI.sourcebaseQuestionSession(outputId: outputId)
        return GeneratedContentParser.questionPrompts(from: response)
    }

    public func submitQuestionAnswer(
        outputId: String,
        questionId: String,
        selectedIndex: Int,
        elapsedSeconds: Int? = nil
    ) async throws -> SBQuestionAnswerFeedback {
        let driveAPI = try await api()
        let response = try await driveAPI.submitSourcebaseQuestionAnswer(
            outputId: outputId,
            questionId: questionId,
            selectedIndex: selectedIndex,
            elapsedSeconds: elapsedSeconds
        )
        return GeneratedContentParser.questionAnswerFeedback(
            from: response,
            fallbackQuestionId: questionId,
            selectedIndex: selectedIndex
        )
    }

    public func requestAccountDeletion() async -> Bool {
        do {
            let driveRepository = try await repository()
            try await driveRepository.requestAccountDeletion()
            toast("Hesap silme talebin alındı.")
            return true
        } catch {
            toast(friendlyError(error))
            return false
        }
    }

    public func submitSupportForm(topic: String, email: String, message: String) async -> Bool {
        let cleanTopic = topic.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanMessage = message.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanTopic.isEmpty, !cleanEmail.isEmpty, cleanMessage.count >= 10 else {
            toast("Destek formu için konu, e-posta ve en az 10 karakterlik mesaj gerekli.")
            return false
        }

        do {
            let driveAPI = try await api()
            _ = try await driveAPI.submitSupportForm(
                topic: cleanTopic,
                email: cleanEmail,
                message: cleanMessage
            )
            toast("Destek talebin alındı.")
            return true
        } catch {
            toast(friendlyError(error))
            return false
        }
    }

    public func friendlyError(_ error: Error) -> String {
        if let apiError = error as? DriveAPIError {
            return userFacingServerMessage(apiError.message, code: apiError.code, status: apiError.status)
        }
        if let repoError = error as? RepositoryError {
            return userFacingServerMessage(repoError.message, code: nil, status: nil)
        }
        if let storeError = error as? WorkspaceStoreError {
            return storeError.message
        }
        let text = String(describing: error)
            .replacingOccurrences(of: "Error Domain=NSCocoaErrorDomain Code=257", with: "")
            .replacingOccurrences(of: "Exception: ", with: "")
            .replacingOccurrences(of: "StateError: ", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if text.contains("401") || text.contains("UNAUTHORIZED") {
            return "Oturum süren doldu. Lütfen tekrar giriş yap."
        }
        return userFacingServerMessage(text, code: nil, status: nil)
    }

    private func userFacingServerMessage(_ message: String, code: String?, status: Int?) -> String {
        let trimmed = message.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalized = "\(trimmed) \(code ?? "")".lowercased()
        if trimmed.isEmpty {
            return "İşlem tamamlanamadı. Tekrar deneyebilirsin."
        }
        if status == 401 || normalized.contains("unauthorized") || normalized.contains("auth") {
            return "Oturum süren doldu. Lütfen tekrar giriş yap."
        }
        if normalized.contains("ocr") || normalized.contains("scanned") || normalized.contains("no text") || normalized.contains("metin bulunamad") {
            return "Bu PDF görüntü tabanlı görünüyor. OCR/metin çıkarımı sonuç vermedi; daha net tarama veya metin içeren PDF deneyebilirsin."
        }
        if normalized.contains("encrypt") || normalized.contains("password") || normalized.contains("protected")
            || normalized.contains("şifre") || normalized.contains("sifre") || normalized.contains("parola") {
            return "Bu PDF şifreli görünüyor. Şifre korumasını kaldırıp tekrar yükleyebilirsin."
        }
        if normalized.contains("corrupt") || normalized.contains("damaged") || normalized.contains("malformed")
            || normalized.contains("bozuk") || normalized.contains("okunamıyor") || normalized.contains("unreadable") {
            return "Dosya bozuk ya da okunamıyor. Dosyayı yeniden kaydedip tekrar yükleyebilirsin."
        }
        if normalized.contains("old doc") || normalized.contains("eski doc") {
            return "Eski DOC dosyaları sınırlı desteklenir. Dosyayı DOCX olarak kaydedip tekrar yükleyebilirsin."
        }
        if normalized.contains("old ppt") || normalized.contains("eski ppt") {
            return "Eski PPT dosyaları sınırlı desteklenir. Dosyayı PPTX olarak kaydedip tekrar yükleyebilirsin."
        }
        if normalized.contains("limited_support") || normalized.contains("legacy") {
            return "Eski PPT/DOC dosyaları sınırlı desteklenir. Mümkünse PPTX veya DOCX olarak kaydedip tekrar yükleyebilirsin."
        }
        if normalized.contains("unsupported") || normalized.contains("file type") {
            return "Bu dosya biçimi şu anda desteklenmiyor. \(DriveUploadService.supportedExtensionsDisplay) formatlarından birini deneyebilirsin."
        }
        if normalized.contains("backend") || normalized.contains("edge function") || normalized.contains("job type") || normalized.contains("server") {
            return "İşlem şu anda hazırlanamadı. Biraz sonra tekrar deneyebilirsin."
        }
        if normalized.contains("network") || normalized.contains("timed out") || normalized.contains("timeout") {
            return "Bağlantı kesildi. İnternetini kontrol edip tekrar deneyebilirsin."
        }
        return trimmed
    }

    public func toast(_ message: String) {
        toastMessage = message
    }

    private func syncSelection() {
        selectedCourseId = course(id: selectedCourseId)?.id ?? workspace.primaryCourse?.id
        selectedSectionId = section(id: selectedSectionId)?.id ?? course(id: selectedCourseId)?.sections.first?.id
        selectedFileId = file(id: selectedFileId)?.id ?? section(id: selectedSectionId)?.files.first?.id ?? readyFiles.first?.id
        selectedSourceIds = Set(selectedSourceIds.filter { id in
            guard let file = file(id: id) else { return false }
            return isReadyForGeneration(file)
        })
        currentUploadDestination = preferredUploadDestination
    }

    private func refreshGenerationJobs(using repository: DriveRepository) async throws {
        let snapshots = try await repository.listUserJobs(limit: 50)
        generationJobs = snapshots.map { snapshot in
            let output = generatedOutput(id: snapshot.outputId)
            return SBGenerationJob(
                id: snapshot.jobId ?? snapshot.id,
                sourceFileId: snapshot.sourceFileId,
                sourceTitle: snapshot.sourceTitle,
                kind: snapshot.kind,
                status: generationStatus(from: snapshot.status, errorMessage: snapshot.errorMessage),
                progress: snapshot.progress,
                output: output,
                outputId: snapshot.outputId
            )
        }
    }

    private func generationStatus(from raw: String, errorMessage: String?) -> SBGenerationStatus {
        switch GenerationJobPhase(rawStatus: raw) {
        case .completed:
            return .completed
        case .failed:
            return .failed(errorMessage ?? "Üretim tamamlanamadı.")
        case .queued:
            return .queued
        case .running:
            return .running
        }
    }

    private func upsertGenerationJob(_ job: SBGenerationJob) {
        if let index = generationJobs.firstIndex(where: { $0.id == job.id }) {
            generationJobs[index] = job
        } else {
            generationJobs.insert(job, at: 0)
        }
    }

    private func runBusy(_ label: String, action: () async throws -> Void) async {
        guard !isBusy else { return }
        isBusy = true
        toast(label)
        do {
            try await action()
        } catch {
            toast(friendlyError(error))
        }
        isBusy = false
    }

    private func repository() async throws -> DriveRepository {
        guard let client = await AuthBackend.shared.getClient() else {
            throw WorkspaceStoreError(message: "Oturum doğrulanamadı. Lütfen tekrar giriş yap.")
        }
        return DriveRepository(api: DriveAPI(client: client))
    }

    private func api() async throws -> DriveAPI {
        guard let client = await AuthBackend.shared.getClient() else {
            throw WorkspaceStoreError(message: "Oturum doğrulanamadı. Lütfen tekrar giriş yap.")
        }
        return DriveAPI(client: client)
    }

    private func centralAIContext(for fileIds: [String]) -> String? {
        let selected = fileIds.isEmpty ? selectedReadyFiles : fileIds.compactMap { file(id: $0) }
        guard !selected.isEmpty else { return nil }
        return selected.map { file in
            "- \(file.title) / \(file.courseTitle) / \(file.sectionTitle) / \(file.pageLabel)"
        }.joined(separator: "\n")
    }

    private func generationOptions(
        base options: [String: String]?,
        source: DriveFile,
        kind: GeneratedKind,
        sourceIds: [String]
    ) -> [String: String] {
        var enriched = options ?? [:]
        enriched["ecosystemAuditRequired"] = "true"
        enriched["preflightPolicy"] = "evaluate_user_ecosystem_mistakes_before_generation"
        enriched["gapAnalysisRequired"] = "true"
        enriched["sourceGroundingPolicy"] = "strict_source_grounded_no_fabrication"
        enriched["sourceReadPolicy"] = enriched["sourceReadPolicy"] ?? defaultSourceReadPolicy(for: kind)
        enriched["source_read_policy"] = enriched["source_read_policy"] ?? defaultSourceReadPolicy(for: kind)
        enriched["sourceCoveragePolicy"] = enriched["sourceCoveragePolicy"] ?? defaultSourceCoveragePolicy(for: kind)
        enriched["source_coverage_policy"] = enriched["source_coverage_policy"] ?? defaultSourceCoveragePolicy(for: kind)
        enriched["sourceChunkPolicy"] = enriched["sourceChunkPolicy"] ?? defaultSourceChunkPolicy(for: kind)
        enriched["source_chunk_policy"] = enriched["source_chunk_policy"] ?? defaultSourceChunkPolicy(for: kind)
        enriched["largeSourcePolicy"] = enriched["largeSourcePolicy"] ?? defaultLargeSourcePolicy(for: kind)
        enriched["large_source_policy"] = enriched["large_source_policy"] ?? defaultLargeSourcePolicy(for: kind)
        enriched["ocrPolicy"] = enriched["ocrPolicy"] ?? defaultOCRPolicy(for: kind)
        enriched["ocr_policy"] = enriched["ocr_policy"] ?? defaultOCRPolicy(for: kind)
        enriched["modelRouterPolicy"] = enriched["modelRouterPolicy"] ?? defaultModelRouterPolicy(for: kind)
        enriched["model_router_policy"] = enriched["model_router_policy"] ?? defaultModelRouterPolicy(for: kind)
        enriched["preferredModelTier"] = enriched["preferredModelTier"] ?? defaultPreferredModelTier(for: kind)
        enriched["preferred_model_tier"] = enriched["preferred_model_tier"] ?? defaultPreferredModelTier(for: kind)
        enriched["modelUpgradeAllowed"] = "true"
        enriched["model_upgrade_allowed"] = "true"
        enriched["learningSciencePolicy"] = enriched["learningSciencePolicy"] ?? defaultLearningSciencePolicy(for: kind)
        enriched["learning_science_policy"] = enriched["learning_science_policy"] ?? defaultLearningSciencePolicy(for: kind)
        enriched["retrievalPracticePolicy"] = enriched["retrievalPracticePolicy"] ?? "force_commit_before_answer_with_self_check_or_questions"
        enriched["retrieval_practice_policy"] = enriched["retrieval_practice_policy"] ?? "force_commit_before_answer_with_self_check_or_questions"
        enriched["spacedReviewPolicy"] = enriched["spacedReviewPolicy"] ?? "include_today_24h_72h_7d_review_prompts_when_applicable"
        enriched["spaced_review_policy"] = enriched["spaced_review_policy"] ?? "include_today_24h_72h_7d_review_prompts_when_applicable"
        enriched["clinicalReasoningPolicy"] = enriched["clinicalReasoningPolicy"] ?? "problem_representation_differential_justification_red_flags_and_management_frame"
        enriched["clinical_reasoning_policy"] = enriched["clinical_reasoning_policy"] ?? "problem_representation_differential_justification_red_flags_and_management_frame"
        enriched["studentOutcomeContract"] = enriched["studentOutcomeContract"] ?? defaultStudentOutcomeContract(for: kind)
        enriched["student_outcome_contract"] = enriched["student_outcome_contract"] ?? defaultStudentOutcomeContract(for: kind)
        enriched["antiCrutchPolicy"] = enriched["antiCrutchPolicy"] ?? "do_not_skip_reasoning_do_not_spoonfeed_final_answer_without_check_step"
        enriched["anti_crutch_policy"] = enriched["anti_crutch_policy"] ?? "do_not_skip_reasoning_do_not_spoonfeed_final_answer_without_check_step"
        enriched["qualityGate"] = enriched["qualityGate"] ?? defaultQualityGate(for: kind)
        enriched["quality_gate"] = enriched["quality_gate"] ?? defaultQualityGate(for: kind)
        enriched["driveSelectionPolicy"] = "honor_selected_course_section_and_pdf_sources"
        enriched["drive_selection_policy"] = "honor_selected_course_section_and_pdf_sources"
        enriched["primarySourceTitle"] = source.title
        enriched["primary_source_title"] = source.title
        enriched["primarySourceCourse"] = source.courseTitle
        enriched["primary_source_course"] = source.courseTitle
        enriched["primarySourceSection"] = source.sectionTitle
        enriched["primary_source_section"] = source.sectionTitle
        enriched["primarySourceKind"] = source.kind.rawValue
        enriched["primary_source_kind"] = source.kind.rawValue
        enriched["selectedSourceManifest"] = selectedSourceManifest(sourceIds: sourceIds)
        enriched["selected_source_manifest"] = selectedSourceManifest(sourceIds: sourceIds)
        enriched["ecosystemContext"] = ecosystemGenerationContext(source: source, kind: kind, sourceIds: sourceIds)
        enriched["mistakeDetectionFocus"] = [
            "eksik_kapsam",
            "yanlis_kavram_eslestirme",
            "celiskili_baslik",
            "sik_karistirilan_tani_bulgu_tedavi",
            "sinav_ve_klinik_riskli_bosluk"
        ].joined(separator: ",")
        if enriched["qualityTier"] == nil {
            enriched["qualityTier"] = defaultQualityTier(for: kind)
        }
        if enriched["modelPolicy"] == nil {
            enriched["modelPolicy"] = defaultModelPolicy(for: kind)
        }
        if enriched["minimumDepth"] == nil {
            enriched["minimumDepth"] = defaultMinimumDepth(for: kind)
        }
        if enriched["outputLengthPolicy"] == nil {
            enriched["outputLengthPolicy"] = defaultOutputLengthPolicy(for: kind)
        }
        if kind == .infographic, enriched["assetFallbackPolicy"] == nil {
            enriched["assetFallbackPolicy"] = "structured_text_blocks_when_image_unavailable"
        }
        if kind == .infographic {
            let imageModel = enriched["imageModelPolicy"]
                ?? enriched["image_model_policy"]
                ?? enriched["gptImageModel"]
                ?? enriched["gpt_image_model"]
                ?? defaultInfographicImageModel(for: enriched["qualityTier"] ?? enriched["quality_tier"])
            enriched["imageModelPolicy"] = enriched["imageModelPolicy"] ?? imageModel
            enriched["image_model_policy"] = enriched["image_model_policy"] ?? imageModel
            enriched["gptImageModel"] = enriched["gptImageModel"] ?? imageModel
            enriched["gpt_image_model"] = enriched["gpt_image_model"] ?? imageModel
            enriched["openaiImageModel"] = enriched["openaiImageModel"] ?? imageModel
            enriched["openai_image_model"] = enriched["openai_image_model"] ?? imageModel
            enriched["visualAssetRequired"] = enriched["visualAssetRequired"] ?? "true"
            enriched["visual_asset_required"] = enriched["visual_asset_required"] ?? "true"
            enriched["visualOutputContract"] = enriched["visualOutputContract"] ?? "return_image_url_or_renderable_sections_with_source_note"
            enriched["visual_output_contract"] = enriched["visual_output_contract"] ?? "return_image_url_or_renderable_sections_with_source_note"
        }
        if kind == .podcast {
            enriched["audioAssetRequired"] = enriched["audioAssetRequired"] ?? "true"
            enriched["audio_asset_required"] = enriched["audio_asset_required"] ?? "true"
            enriched["audioFormat"] = enriched["audioFormat"] ?? "m4a_or_mp3_exportable"
            enriched["audio_format"] = enriched["audio_format"] ?? "m4a_or_mp3_exportable"
            enriched["podcastOutputContract"] = enriched["podcastOutputContract"] ?? "return_audio_url_when_available_plus_full_segment_transcript"
            enriched["podcast_output_contract"] = enriched["podcast_output_contract"] ?? "return_audio_url_when_available_plus_full_segment_transcript"
        }
        return enriched
    }

    private func defaultQualityTier(for kind: GeneratedKind) -> String {
        "premium"
    }

    private func defaultInfographicImageModel(for quality: String?) -> String {
        let normalized = (quality ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        if normalized.contains("economy") || normalized.contains("ekonomik") {
            return "gpt-image-1-mini"
        }
        if normalized.contains("standard") || normalized.contains("standart") {
            return "gpt-image-1.5"
        }
        return "gpt-image-2"
    }

    private func defaultModelPolicy(for kind: GeneratedKind) -> String {
        switch kind {
        case .infographic:
            return "premium_latest_long_context_visual_quality_first"
        case .clinicalScenario:
            return "premium_latest_long_context_clinical_reasoning_first"
        case .question:
            return "premium_latest_long_context_assessment_quality_first"
        case .examMorningSummary, .algorithm, .comparison, .table, .mindMap:
            return "premium_latest_long_context_structured_reasoning_first"
        case .podcast:
            return "premium_latest_long_context_longform_learning_quality"
        case .flashcard:
            return "premium_latest_long_context_active_recall_quality_first"
        case .summary:
            return "premium_latest_long_context_summary_synthesis_first"
        case .learningPlan:
            return "premium_latest_long_context_adaptive_study_planning"
        }
    }

    private func defaultSourceReadPolicy(for kind: GeneratedKind) -> String {
        "read_full_extracted_document_not_first_excerpt"
    }

    private func defaultSourceCoveragePolicy(for kind: GeneratedKind) -> String {
        switch kind {
        case .comparison, .table:
            return "all_selected_sources_all_sections_tables_middle_end_and_conclusions"
        case .question:
            return "all_testable_objectives_tables_figures_common_misconceptions_and_edge_cases"
        case .flashcard:
            return "all_core_concepts_definitions_mechanisms_tables_figures_and_common_mistakes"
        case .algorithm:
            return "all_decision_points_thresholds_exceptions_red_flags_and_actions"
        case .clinicalScenario:
            return "full_case_relevant_source_findings_labs_decisions_differential_and_safety_limits"
        case .podcast:
            return "full_source_episode_arc_beginning_middle_end_tables_and_recap"
        case .infographic:
            return "full_source_visual_hierarchy_warnings_main_message_and_text_fallback"
        case .learningPlan:
            return "full_source_objectives_weak_points_sessions_reviews_and_gap_closure"
        case .mindMap:
            return "full_source_branches_cross_links_confusions_and_clinical_ties"
        case .summary, .examMorningSummary:
            return "full_source_beginning_middle_end_headings_tables_conclusions_red_flags_and_self_check"
        }
    }

    private func defaultSourceChunkPolicy(for kind: GeneratedKind) -> String {
        "adaptive_full_document_chunk_map_reduce_for_long_sources"
    }

    private func defaultLargeSourcePolicy(for kind: GeneratedKind) -> String {
        "10_pages_read_all_200_pages_chunk_index_all_sections_then_synthesize"
    }

    private func defaultOCRPolicy(for kind: GeneratedKind) -> String {
        "use_ocr_text_for_scanned_pdf_or_low_text_density_slide_pages_before_generation"
    }

    private func defaultModelRouterPolicy(for kind: GeneratedKind) -> String {
        switch kind {
        case .comparison, .table, .clinicalScenario, .podcast, .infographic:
            return "route_large_or_sparse_sources_to_long_context_high_reasoning_model"
        default:
            return "route_to_long_context_reasoning_when_source_or_quality_requires_it"
        }
    }

    private func defaultPreferredModelTier(for kind: GeneratedKind) -> String {
        switch kind {
        case .comparison, .table, .clinicalScenario, .podcast, .infographic:
            return "latest_premium_high_reasoning_long_context"
        default:
            return "latest_premium_reasoning_long_context"
        }
    }

    private func defaultQualityGate(for kind: GeneratedKind) -> String {
        switch kind {
        case .comparison, .table:
            return "reject_first_excerpt_surface_table_or_under_8_criteria_without_source_gap"
        case .flashcard:
            return "reject_too_few_atomic_cards_or_generic_front_back_pairs"
        case .question:
            return "reject_shallow_questions_missing_rationales_source_coverage_or_real_distractors"
        default:
            return "reject_surface_level_first_excerpt_single_paragraph_or_underfilled_structured_output"
        }
    }

    private func defaultMinimumDepth(for kind: GeneratedKind) -> String {
        switch kind {
        case .clinicalScenario:
            return "clinical_deep_with_differential"
        case .infographic:
            return "visual_detailed_with_text_fallback"
        case .question:
            return "assessment_deep_with_distractor_rationales"
        case .podcast:
            return "longform_deep_segmented"
        case .flashcard, .summary, .examMorningSummary, .algorithm, .comparison, .table, .learningPlan, .mindMap:
            return "premium_deep"
        }
    }

    private func defaultOutputLengthPolicy(for kind: GeneratedKind) -> String {
        switch kind {
        case .clinicalScenario, .summary, .examMorningSummary, .algorithm, .comparison, .table, .learningPlan, .mindMap:
            return "comprehensive_structured_not_short"
        case .infographic:
            return "comprehensive_visual_structured"
        case .podcast:
            return "longform_comprehensive_not_padded"
        case .flashcard, .question:
            return "complete_set_not_short"
        }
    }

    private func defaultLearningSciencePolicy(for kind: GeneratedKind) -> String {
        switch kind {
        case .flashcard:
            return "retrieval_practice_atomic_cards_spaced_review_common_mistake_feedback"
        case .question:
            return "test_enhanced_learning_five_choice_commitment_rationales_error_correction"
        case .clinicalScenario:
            return "case_based_clinical_reasoning_problem_representation_differential_justification_feedback"
        case .learningPlan:
            return "spaced_practice_interleaving_retrieval_checkpoints_gap_closure"
        case .podcast:
            return "dual_coding_audio_recap_retrieval_pauses_and_later_review_prompts"
        case .infographic, .mindMap:
            return "dual_coding_visual_hierarchy_active_recall_and_common_confusion_links"
        case .summary, .examMorningSummary, .algorithm, .comparison, .table:
            return "spaced_practice_retrieval_practice_interleaving_elaboration_dual_coding_concrete_examples"
        }
    }

    private func defaultStudentOutcomeContract(for kind: GeneratedKind) -> String {
        switch kind {
        case .flashcard:
            return "student_can_cover_answer_recall_explain_common_mistake_and_schedule_next_review"
        case .question:
            return "student_commits_to_answer_receives_rationale_reviews_wrong_options_and_knows_weak_topic"
        case .clinicalScenario:
            return "student_forms_problem_representation_lists_differential_justifies_top_diagnosis_and_names_red_flags"
        case .learningPlan:
            return "student_knows_what_to_do_today_next_24h_72h_7d_and_how_to_measure_progress"
        case .comparison, .table:
            return "student_can_distinguish_entities_by_same_criteria_exam_traps_source_refs_and_red_flags"
        case .algorithm:
            return "student_can_enter_from_symptom_or_finding_follow_decisions_and_stop_at_red_flags"
        case .podcast:
            return "student_can_list_key_points_after_listening_answer_recall_prompts_and_export_audio"
        case .infographic:
            return "student_can_scan_main_message_warnings_blocks_and_quick_check_without_plain_text_dump"
        case .mindMap:
            return "student_can_explain_central_concept_branches_cross_links_and_common_confusions"
        case .summary, .examMorningSummary:
            return "student_can_study_actively_review_later_identify_gaps_and_verify_source_grounding"
        }
    }

    private func ecosystemGenerationContext(source: DriveFile, kind: GeneratedKind, sourceIds: [String]) -> String {
        let selectedFiles = sourceIds.compactMap { file(id: $0) }
        let allGenerated = allFiles.flatMap(\.generated)
        let readyCount = readyFiles.count
        let blockedCount = allFiles.count - readyCount
        let selectedLines = selectedFiles.prefix(6).map { file in
            "- \(file.title) | \(file.courseTitle) / \(file.sectionTitle) | \(file.kind.rawValue.uppercased()) | \(file.pageLabel) | \(file.sizeLabel)"
        }.joined(separator: "\n")
        let recentOutputLines = allGenerated.prefix(6).map { output in
            "- \(output.title) | \(output.kind.titleLabel) | \(output.updatedLabel)"
        }.joined(separator: "\n")
        let courseLines = workspace.courses.prefix(6).map { course in
            "- \(course.title): \(course.sections.count) bölüm, \(course.fileCount) dosya"
        }.joined(separator: "\n")

        return """
        Kullanıcı ekosistem özeti:
        Aktif kaynak: \(source.title) | \(source.courseTitle) / \(source.sectionTitle) | \(source.kind.rawValue.uppercased()) | \(source.pageLabel) | \(source.sizeLabel)
        Üretim modu: \(kind.titleLabel)
        Hazır kaynak sayısı: \(readyCount)
        Hazır olmayan veya eksik kaynak sayısı: \(max(blockedCount, 0))

        Seçili kaynaklar:
        \(selectedLines.isEmpty ? "- Seçili ek kaynak yok." : selectedLines)

        Ders/bölüm yapısı:
        \(courseLines.isEmpty ? "- Ders yapısı bulunamadı." : courseLines)

        Önceki üretimler:
        \(recentOutputLines.isEmpty ? "- Önceki üretim bulunamadı." : recentOutputLines)

        Çalışma yönergesi:
        Başlamadan önce bu çalışma alanında kullanıcının muhtemel yanlışlarını, eksik kaynak kapsamını, karıştırdığı veya karıştırma riski taşıyan başlıkları ve seçili kaynağın üretim moduna uygunluk boşluklarını değerlendir. Sonuçta gerekiyorsa "eksik/kaynakta açık değil" uyarılarını içeriğe kat. Her çıktı tıp öğrencisinin aktif hatırlama yapmasına, sonraki tekrar zamanını bilmesine, vaka/ayırıcı tanı aklı kurmasına ve kaynak dışı iddiayı fark etmesine yardım etmeli.
        """
    }

    private func selectedSourceManifest(sourceIds: [String]) -> String {
        sourceIds
            .compactMap { file(id: $0) }
            .map { file in
                "\(file.id)|\(file.title)|\(file.courseTitle)|\(file.sectionTitle)|\(file.kind.rawValue)|\(file.pageLabel)"
            }
            .joined(separator: "\n")
    }

    private func responseText(from response: [String: AnyJSON]) -> String {
        let data: [String: AnyJSON]?
        if let raw = response["data"], case .object(let dict) = raw {
            data = dict
        } else {
            data = nil
        }
        let candidates = [
            data?["message"]?.stringValue,
            data?["answer"]?.stringValue,
            data?["content"]?.stringValue,
            data?["text"]?.stringValue,
            response["message"]?.stringValue
        ]
        return candidates.compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }.first { !$0.isEmpty }
            ?? "Yanıt alındı ancak metin alanı boş döndü."
    }
}
