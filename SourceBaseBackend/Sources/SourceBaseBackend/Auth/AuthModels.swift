import Foundation

public enum AuthResult: Sendable {
    case success(String)
    case failure(String)

    public var ok: Bool {
        if case .success = self { return true }
        return false
    }

    public var message: String? {
        if case .success(let msg) = self { return msg }
        return nil
    }

    public var error: String? {
        if case .failure(let err) = self { return err }
        return nil
    }
}

public struct AuthCallbackResult: Sendable {
    public let redirectType: String?

    public var isPasswordRecovery: Bool {
        redirectType == "recovery" || redirectType == "passwordRecovery"
    }
}

public struct SourceBaseProfile: Sendable {
    public let faculty: String
    public let department: String

    public init(faculty: String, department: String) {
        self.faculty = faculty.trimmingCharacters(in: .whitespaces)
        self.department = department.trimmingCharacters(in: .whitespaces)
    }

    public func metadata() -> [String: Any] {
        [
            "sourcebase_faculty": faculty,
            "sourcebase_department": department,
            "sourcebase_profile_completed": true,
            "sourcebase_profile_completed_at": ISO8601DateFormatter().string(from: Date())
        ]
    }
}
