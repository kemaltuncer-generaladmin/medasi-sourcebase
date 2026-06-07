import Foundation
import Network
import SourceBaseBackend
import SwiftUI

struct OfflineGenerationRequest: Codable, Identifiable {
    let id: String
    let fileId: String
    let fileTitle: String
    let kind: String
    let options: [String: String]
    let createdAt: Date
    let retryCount: Int
    
    init(fileId: String, fileTitle: String, kind: String, options: [String: String]) {
        self.id = UUID().uuidString
        self.fileId = fileId
        self.fileTitle = fileTitle
        self.kind = kind
        self.options = options
        self.createdAt = Date()
        self.retryCount = 0
    }

    private init(
        id: String,
        fileId: String,
        fileTitle: String,
        kind: String,
        options: [String: String],
        createdAt: Date,
        retryCount: Int
    ) {
        self.id = id
        self.fileId = fileId
        self.fileTitle = fileTitle
        self.kind = kind
        self.options = options
        self.createdAt = createdAt
        self.retryCount = retryCount
    }
    
    func withIncrementedRetry() -> OfflineGenerationRequest {
        OfflineGenerationRequest(
            id: id,
            fileId: fileId,
            fileTitle: fileTitle,
            kind: kind,
            options: options,
            createdAt: createdAt,
            retryCount: retryCount + 1
        )
    }
}

@MainActor
final class SBOfflineQueueService: ObservableObject {
    static let shared = SBOfflineQueueService()
    
    @Published private(set) var isOnline = true
    @Published private(set) var pendingRequests: [OfflineGenerationRequest] = []
    @Published private(set) var isProcessing = false
    
    private let queueKey = "sb_offline_generation_queue"
    private let maxRetries = 3
    private let monitor = NWPathMonitor()
    private let monitorQueue = DispatchQueue(label: "sb.network.monitor")
    
    private init() {
        loadQueue()
        startMonitoring()
    }
    
    // MARK: - Network Monitoring
    
    private func startMonitoring() {
        monitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor in
                let wasOffline = !(self?.isOnline ?? true)
                self?.isOnline = path.status == .satisfied
                
                if wasOffline && path.status == .satisfied {
                    await self?.processQueue()
                }
            }
        }
        monitor.start(queue: monitorQueue)
    }
    
    // MARK: - Queue Management
    
    func enqueue(request: OfflineGenerationRequest) {
        pendingRequests.append(request)
        saveQueue()
        
        if isOnline {
            Task {
                await processQueue()
            }
        }
    }
    
    func processQueue() async {
        guard isOnline, !isProcessing, !pendingRequests.isEmpty else { return }
        
        isProcessing = true
        defer { isProcessing = false }
        
        let requests = pendingRequests
        pendingRequests.removeAll()
        saveQueue()
        
        for request in requests {
            do {
                try await processRequest(request)
            } catch {
                if request.retryCount < maxRetries {
                    pendingRequests.append(request.withIncrementedRetry())
                    saveQueue()
                } else {
                    await notifyFailure(request, error: error)
                }
            }
        }
    }
    
    private func processRequest(_ request: OfflineGenerationRequest) async throws {
        guard isOnline else {
            throw OfflineQueueError.offline
        }

        guard let kind = GeneratedKind(rawValue: request.kind) else {
            throw OfflineQueueError.invalidKind
        }
        
        guard let file = SourceBaseWorkspaceStore.shared.file(id: request.fileId) else {
            throw OfflineQueueError.fileNotFound
        }
        
        let job = await SourceBaseWorkspaceStore.shared.startGeneration(
            file: file,
            kind: kind,
            options: request.options
        )
        
        if job == nil {
            throw OfflineQueueError.generationNotStarted
        }
    }
    
    private func notifyFailure(_ request: OfflineGenerationRequest, error: Error) async {
        await SBNotificationService.shared.notifyJobFailure(
            jobId: request.id,
            jobTitle: request.fileTitle,
            errorMessage: error.localizedDescription
        )
    }
    
    func cancelRequest(_ id: String) {
        pendingRequests.removeAll { $0.id == id }
        saveQueue()
    }
    
    func clearQueue() {
        pendingRequests.removeAll()
        saveQueue()
    }
    
    // MARK: - Persistence
    
    private func loadQueue() {
        if let data = UserDefaults.standard.data(forKey: queueKey),
           let requests = try? JSONDecoder().decode([OfflineGenerationRequest].self, from: data) {
            pendingRequests = requests.filter { request in
                Date().timeIntervalSince(request.createdAt) < 86400 * 7
            }
        }
    }
    
    private func saveQueue() {
        if let data = try? JSONEncoder().encode(pendingRequests) {
            UserDefaults.standard.set(data, forKey: queueKey)
        }
    }
}

enum OfflineQueueError: Error, LocalizedError {
    case offline
    case invalidKind
    case fileNotFound
    case generationNotStarted
    
    var errorDescription: String? {
        switch self {
        case .offline:
            return "İnternet bağlantısı yok"
        case .invalidKind:
            return "Geçersiz üretim türü"
        case .fileNotFound:
            return "Dosya bulunamadı"
        case .generationNotStarted:
            return "Üretim başlatılamadı"
        }
    }
}
