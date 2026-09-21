import Foundation

public enum LaunchAtLoginStatus: String, Equatable, Sendable {
    case enabled
    case disabled
    case requiresApproval
    case unavailable
}

public protocol LaunchAtLoginManaging: Sendable {
    func status() -> LaunchAtLoginStatus
    func setEnabled(_ enabled: Bool) throws
}

/// Class wrapper so AppModel can hold a mutable fake without `mutating`.
public final class FakeLaunchAtLoginManager: LaunchAtLoginManaging, @unchecked Sendable {
    public var current: LaunchAtLoginStatus
    public private(set) var setEnabledCalls: [Bool] = []

    public init(current: LaunchAtLoginStatus = .disabled) {
        self.current = current
    }

    public func status() -> LaunchAtLoginStatus { current }

    public func setEnabled(_ enabled: Bool) throws {
        setEnabledCalls.append(enabled)
        current = enabled ? .enabled : .disabled
    }
}
