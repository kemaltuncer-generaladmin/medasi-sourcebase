import Foundation
import SourceBaseBackend

@MainActor
final class SBJobCancellationService: ObservableObject {
    static let shared = SBJobCancellationService()
    
    @Published private(set) var cancellingJobIds = Set<String>()
    @Published private(set) var verificationStatus: [String: CancellationStatus] = [:]
    
    enum CancellationStatus: Equatable {
        case pending
        case verifying
        case confirmed
        case failed(String)
    }
    
    private init() {}
    
    func cancelJob(_ job: SBGenerationJob) async {
        guard !cancellingJobIds.contains(job.id) else { return }
        
        cancellingJobIds.insert(job.id)
        verificationStatus[job.id] = .pending
        
        do {
            let repo = try await repository()
            try await repo.cancelJob(job.id)
            
            verificationStatus[job.id] = .verifying
            
            let verified = await verifyCancellation(jobId: job.id, repo: repo)
            
            if verified {
                verificationStatus[job.id] = .confirmed
                await updateJobStatus(job.id, status: .failed("İptal edildi."))
            } else {
                verificationStatus[job.id] = .failed("İptal doğrulanamadı")
            }
        } catch {
            verificationStatus[job.id] = .failed(error.localizedDescription)
        }
        
        cancellingJobIds.remove(job.id)
        
        Task {
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            await MainActor.run {
                _ = self.verificationStatus.removeValue(forKey: job.id)
            }
        }
    }
    
    private func verifyCancellation(jobId: String, repo: DriveRepository) async -> Bool {
        for attempt in 0..<5 {
            do {
                let jobs = try await repo.listUserJobs(limit: 50)
                
                if let job = jobs.first(where: { $0.id == jobId || $0.jobId == jobId }) {
                    let phase = GenerationJobPhase(rawStatus: job.status)
                    
                    switch phase {
                    case .failed, .completed:
                        return true
                    case .queued, .running:
                        if attempt < 4 {
                            try? await Task.sleep(nanoseconds: 1_000_000_000)
                            continue
                        }
                    }
                } else {
                    return true
                }
            } catch {
                if attempt < 4 {
                    try? await Task.sleep(nanoseconds: 1_000_000_000)
                    continue
                }
            }
        }
        
        return false
    }
    
    private func updateJobStatus(_ jobId: String, status: SBGenerationStatus) async {
        let store = SourceBaseWorkspaceStore.shared
        
        if let index = store.generationJobs.firstIndex(where: { $0.id == jobId }) {
            store.generationJobs[index].status = status
            store.generationJobs[index].progress = 1.0
        }
    }
    
    private func repository() async throws -> DriveRepository {
        guard let client = await AuthBackend.shared.getClient() else {
            throw CancellationError.sessionExpired
        }
        return DriveRepository(api: DriveAPI(client: client))
    }
}

enum CancellationError: Error, LocalizedError {
    case sessionExpired
    case jobNotFound
    case alreadyCompleted
    
    var errorDescription: String? {
        switch self {
        case .sessionExpired:
            return "Oturum süresi doldu"
        case .jobNotFound:
            return "Üretim bulunamadı"
        case .alreadyCompleted:
            return "Üretim zaten tamamlandı"
        }
    }
}
