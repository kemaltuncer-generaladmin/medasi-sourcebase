import Foundation
import UserNotifications
import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

@MainActor
final class SBNotificationService: ObservableObject {
    static let shared = SBNotificationService()
    
    @Published private(set) var isAuthorized = false
    @Published private(set) var pendingPermission = false
    
    private var notifiedJobIds = Set<String>()
    private let notifiedJobsKey = "sb_notified_jobs"
    private var generationNotificationsEnabled: Bool {
        if UserDefaults.standard.object(forKey: SBProfilePreferenceKey.generationNotifications) == nil {
            return true
        }
        return UserDefaults.standard.bool(forKey: SBProfilePreferenceKey.generationNotifications)
    }
    
    private init() {
        loadNotifiedJobs()
        checkAuthorizationStatus()
    }
    
    // MARK: - Authorization
    
    func requestAuthorization() async {
        guard !isAuthorized, !pendingPermission else { return }
        
        pendingPermission = true
        defer { pendingPermission = false }
        
        do {
            let granted = try await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .sound, .badge])
            
            isAuthorized = granted
            
            if granted {
                await registerForRemoteNotifications()
            }
        } catch {
            isAuthorized = false
        }
    }
    
    func checkAuthorizationStatus() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            let isAuthorized = settings.authorizationStatus == .authorized
            Task { @MainActor in
                self.isAuthorized = isAuthorized
            }
        }
    }

    func prepareGenerationNotificationsIfNeeded() async {
        guard generationNotificationsEnabled else { return }

        let status = await authorizationStatus()
        isAuthorized = status == .authorized

        if status == .notDetermined {
            await requestAuthorization()
        }
    }

    private func authorizationStatus() async -> UNAuthorizationStatus {
        await withCheckedContinuation { continuation in
            UNUserNotificationCenter.current().getNotificationSettings { settings in
                continuation.resume(returning: settings.authorizationStatus)
            }
        }
    }
    
    private func registerForRemoteNotifications() async {
        #if canImport(UIKit) && os(iOS) && !targetEnvironment(simulator)
        await MainActor.run {
            UIApplication.shared.registerForRemoteNotifications()
        }
        #endif
    }
    
    // MARK: - Job Completion Notifications
    
    func notifyJobCompletion(
        jobId: String,
        jobTitle: String,
        jobKind: String,
        sourceTitle: String
    ) async {
        guard generationNotificationsEnabled else { return }
        guard isAuthorized else { return }
        guard !notifiedJobIds.contains(jobId) else { return }
        
        notifiedJobIds.insert(jobId)
        saveNotifiedJobs()
        
        let content = UNMutableNotificationContent()
        content.title = "Üretim hazır"
        content.body = "\(jobTitle) hazır. \(sourceTitle) kaynağından üretildi."
        content.sound = .default
        content.userInfo = [
            "jobId": jobId,
            "jobKind": jobKind,
            "sourceTitle": sourceTitle
        ]
        content.categoryIdentifier = "JOB_COMPLETION"
        
        let request = UNNotificationRequest(
            identifier: "job-\(jobId)",
            content: content,
            trigger: nil
        )
        
        do {
            try await UNUserNotificationCenter.current().add(request)
        } catch {
            notifiedJobIds.remove(jobId)
            saveNotifiedJobs()
        }
    }
    
    func notifyJobFailure(
        jobId: String,
        jobTitle: String,
        errorMessage: String
    ) async {
        guard generationNotificationsEnabled else { return }
        guard isAuthorized else { return }
        guard !notifiedJobIds.contains("fail-\(jobId)") else { return }
        
        notifiedJobIds.insert("fail-\(jobId)")
        saveNotifiedJobs()
        
        let content = UNMutableNotificationContent()
        content.title = "Üretim tamamlanamadı"
        content.body = "\(jobTitle) üretilemedi. \(errorMessage)"
        content.sound = .default
        content.userInfo = [
            "jobId": jobId,
            "error": errorMessage
        ]
        content.categoryIdentifier = "JOB_FAILURE"
        
        let request = UNNotificationRequest(
            identifier: "job-fail-\(jobId)",
            content: content,
            trigger: nil
        )
        
        do {
            try await UNUserNotificationCenter.current().add(request)
        } catch {
            notifiedJobIds.remove("fail-\(jobId)")
            saveNotifiedJobs()
        }
    }
    
    // MARK: - Persistence
    
    private func loadNotifiedJobs() {
        if let data = UserDefaults.standard.data(forKey: notifiedJobsKey),
           let jobs = try? JSONDecoder().decode(Set<String>.self, from: data) {
            notifiedJobIds = jobs
            
            let dayAgo = Date().addingTimeInterval(-86400)
            notifiedJobIds = notifiedJobIds.filter { jobId in
                if let timestamp = Double(jobId.split(separator: "-").last ?? "") {
                    return Date(timeIntervalSince1970: timestamp) > dayAgo
                }
                return true
            }
        }
    }
    
    private func saveNotifiedJobs() {
        if let data = try? JSONEncoder().encode(notifiedJobIds) {
            UserDefaults.standard.set(data, forKey: notifiedJobsKey)
        }
    }
    
    func clearNotifiedJobs() {
        notifiedJobIds.removeAll()
        saveNotifiedJobs()
    }
}
