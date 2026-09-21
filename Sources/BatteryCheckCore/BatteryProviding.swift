import Foundation

public protocol BatteryProviding {
    func fetchDevices() throws -> [BatteryDevice]
}

public struct StaticBatteryProvider: BatteryProviding {
    public var devices: [BatteryDevice]
    public init(devices: [BatteryDevice]) { self.devices = devices }
    public func fetchDevices() throws -> [BatteryDevice] { devices }
}

/// Merges IORegistry battery percentages with connected Bluetooth keyboards/mice from system_profiler.
public struct CompositeBatteryProvider: BatteryProviding {
    private let registry: IORegistryBatteryProvider
    private let bluetooth: BluetoothConnectedDeviceProvider

    public init(
        registry: IORegistryBatteryProvider = IORegistryBatteryProvider(),
        bluetooth: BluetoothConnectedDeviceProvider = BluetoothConnectedDeviceProvider()
    ) {
        self.registry = registry
        self.bluetooth = bluetooth
    }

    public func fetchDevices() throws -> [BatteryDevice] {
        let fromRegistry = (try? registry.fetchDevices()) ?? []
        let fromBluetooth = (try? bluetooth.fetchDevices()) ?? []

        var merged: [String: BatteryDevice] = [:]

        func key(for device: BatteryDevice) -> String {
            let normalized = device.id.lowercased().replacingOccurrences(of: "-", with: ":")
            if normalized.contains(":") { return normalized }
            return device.name.lowercased()
        }

        for device in fromBluetooth {
            merged[key(for: device)] = device
        }
        for device in fromRegistry {
            // Skip built-in Mac keyboard/trackpad — not a Bluetooth peripheral.
            let lower = device.name.lowercased()
            if lower.contains("internal keyboard") || lower.contains("built-in") {
                continue
            }
            let k = key(for: device)
            if var existing = merged[k] {
                existing.percentage = device.percentage ?? existing.percentage
                existing.isConnected = true
                if existing.kind == .other { existing.kind = device.kind }
                merged[k] = existing
            } else {
                merged[k] = device
            }
        }

        return merged.values.sorted { lhs, rhs in
            let order: [DeviceKind: Int] = [.keyboard: 0, .mouse: 1, .trackpad: 2, .other: 3]
            let lo = order[lhs.kind, default: 9]
            let ro = order[rhs.kind, default: 9]
            if lo != ro { return lo < ro }
            return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
        }
    }
}
