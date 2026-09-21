import Foundation

public enum DeviceKind: String, Codable, CaseIterable, Sendable {
    case keyboard
    case mouse
    case trackpad
    case other

    public var symbolName: String {
        switch self {
        case .keyboard: return "keyboard"
        case .mouse: return "computermouse"
        case .trackpad: return "trackpad"
        case .other: return "battery.100"
        }
    }

    public var emoji: String {
        switch self {
        case .keyboard: return "⌨️"
        case .mouse: return "🖱️"
        case .trackpad: return "🖲️"
        case .other: return "🔋"
        }
    }

    public var displayNameZH: String {
        switch self {
        case .keyboard: return "鍵盤"
        case .mouse: return "滑鼠"
        case .trackpad: return "觸控板"
        case .other: return "裝置"
        }
    }

    public static func infer(fromName name: String, minorType: String? = nil) -> DeviceKind {
        let blob = ((minorType ?? "") + " " + name).lowercased()
        if blob.contains("keyboard") || blob.contains("鍵盤") || blob.contains("keychron") {
            return .keyboard
        }
        if blob.contains("mouse") || blob.contains("滑鼠") {
            return .mouse
        }
        if blob.contains("trackpad") || blob.contains("觸控板") {
            return .trackpad
        }
        return .other
    }
}

public struct BatteryDevice: Identifiable, Equatable, Sendable {
    public var id: String
    public var name: String
    public var kind: DeviceKind
    /// nil means connected (or known) but percentage unavailable
    public var percentage: Int?
    public var isConnected: Bool

    public init(id: String, name: String, kind: DeviceKind, percentage: Int?, isConnected: Bool) {
        self.id = id
        self.name = name
        self.kind = kind
        if let percentage {
            self.percentage = min(100, max(0, percentage))
        } else {
            self.percentage = nil
        }
        self.isConnected = isConnected
    }

    public var percentageText: String {
        if let percentage { return "\(percentage)%" }
        return "—"
    }
}

public enum MenuBarFormatter {
    /// Menu bar friendly text using emoji (SF Symbols are unreliable in MenuBarExtra labels).
    public static func statusText(for devices: [BatteryDevice]) -> String {
        let focus = devices.filter { $0.isConnected && ($0.kind == .keyboard || $0.kind == .mouse || $0.kind == .trackpad) }
        let list = focus.isEmpty ? devices.filter(\.isConnected) : focus
        guard !list.isEmpty else { return "⌨️—  🖱️—" }
        return list.map { "\($0.kind.emoji)\($0.percentageText)" }.joined(separator: "  ")
    }
}
