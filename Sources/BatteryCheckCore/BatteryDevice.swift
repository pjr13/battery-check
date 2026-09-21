import Foundation

public enum DeviceKind: String, Equatable, Sendable {
    case keyboard
    case mouse
    case trackpad
    case other

    public var symbolName: String {
        switch self {
        case .keyboard: return "keyboard"
        case .mouse: return "computermouse"
        case .trackpad: return "trackpad"
        case .other: return "battery.100.bolt"
        }
    }

    public var chineseLabel: String {
        switch self {
        case .keyboard: return "鍵盤"
        case .mouse: return "滑鼠"
        case .trackpad: return "觸控板"
        case .other: return "裝置"
        }
    }

    public static func infer(fromName name: String) -> DeviceKind {
        let lower = name.lowercased()
        if lower.contains("keyboard") || lower.contains("鍵盤") { return .keyboard }
        if lower.contains("mouse") || lower.contains("滑鼠") { return .mouse }
        if lower.contains("trackpad") || lower.contains("觸控板") { return .trackpad }
        return .other
    }
}

public struct BatteryDevice: Equatable, Identifiable, Sendable {
    public var id: String
    public var name: String
    public var kind: DeviceKind
    public var percentage: Int
    public var isConnected: Bool

    public init(id: String, name: String, kind: DeviceKind, percentage: Int, isConnected: Bool = true) {
        self.id = id
        self.name = name
        self.kind = kind
        self.percentage = max(0, min(100, percentage))
        self.isConnected = isConnected
    }
}

public enum MenuBarFormatter {
    /// Compact menu-bar text: "⌨️ 85%  🖱️ 72%" style using SF Symbol names for UI layer.
    public static func statusText(for devices: [BatteryDevice]) -> String {
        let preferred = devices.filter { $0.kind == .keyboard || $0.kind == .mouse || $0.kind == .trackpad }
        let list = preferred.isEmpty ? devices : preferred
        guard !list.isEmpty else { return "電量 —" }

        return list.map { device in
            "\(glyph(for: device.kind)) \(device.percentage)%"
        }.joined(separator: "  ")
    }

    public static func glyph(for kind: DeviceKind) -> String {
        switch kind {
        case .keyboard: return "⌘K"
        case .mouse: return "⌘M"
        case .trackpad: return "⌘T"
        case .other: return "⌘B"
        }
    }
}
