import Foundation

public protocol BatteryProviding: Sendable {
    func fetchDevices() async throws -> [BatteryDevice]
}

public struct StaticBatteryProvider: BatteryProviding {
    public var devices: [BatteryDevice]
    public init(devices: [BatteryDevice]) { self.devices = devices }
    public func fetchDevices() async throws -> [BatteryDevice] { devices }
}

public struct CompositeBatteryProvider: BatteryProviding {
    private let registry: IORegistryBatteryProvider
    private let bluetooth: BluetoothConnectedDeviceProvider
    private let bleBattery: BLEBatteryServiceProviding

    public init(
        registry: IORegistryBatteryProvider = IORegistryBatteryProvider(),
        bluetooth: BluetoothConnectedDeviceProvider = BluetoothConnectedDeviceProvider(),
        bleBattery: BLEBatteryServiceProviding = BLEBatteryServiceProvider()
    ) {
        self.registry = registry
        self.bluetooth = bluetooth
        self.bleBattery = bleBattery
    }

    public func fetchDevices() async throws -> [BatteryDevice] {
        async let fromRegistry = registry.fetchDevices()
        async let fromBluetooth = bluetooth.fetchDevices()
        async let fromBLE = bleBattery.fetchBatteryLevels()

        let registryDevices = (try? await fromRegistry) ?? []
        let bluetoothDevices = (try? await fromBluetooth) ?? []
        let bleLevels = (try? await fromBLE) ?? [:]

        var merged: [String: BatteryDevice] = [:]

        func key(for device: BatteryDevice) -> String {
            let normalized = device.id.lowercased()
                .replacingOccurrences(of: "-", with: ":")
            if normalized.contains(":") { return normalized }
            return device.name.lowercased()
        }

        for device in bluetoothDevices {
            merged[key(for: device)] = device
        }

        for device in registryDevices {
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

        // Apply BLE Battery Service percentages by address / name.
        for (token, percent) in bleLevels {
            let normalized = token.lowercased().replacingOccurrences(of: "-", with: ":")
            if var match = merged.first(where: {
                key(for: $0.value) == normalized || $0.value.name.lowercased() == normalized
            })?.value {
                match.percentage = percent
                merged[key(for: match)] = match
            } else if normalized.contains(":") {
                // Unknown connected peripheral with battery — keep as other if we at least have a token.
                continue
            }
        }

        // Second pass: if BLE returned name-keyed levels
        for (token, percent) in bleLevels {
            let needle = token.lowercased()
            for (k, var device) in merged {
                if device.percentage == nil,
                   device.name.lowercased().contains(needle) || needle.contains(device.name.lowercased()) {
                    device.percentage = percent
                    merged[k] = device
                }
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

public protocol BLEBatteryServiceProviding: Sendable {
    /// Returns map of peripheral address/name -> battery percent.
    func fetchBatteryLevels() async throws -> [String: Int]
}

public struct StaticBLEBatteryServiceProvider: BLEBatteryServiceProviding {
    public var levels: [String: Int]
    public init(levels: [String: Int] = [:]) { self.levels = levels }
    public func fetchBatteryLevels() async throws -> [String: Int] { levels }
}
