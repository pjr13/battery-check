import Foundation
import IOKit

/// Reads Bluetooth HID peripheral battery percentages from IORegistry.
public struct IORegistryBatteryProvider: BatteryProviding {
    public init() {}

    public func fetchDevices() throws -> [BatteryDevice] {
        let snapshot = try Self.readRawDevices()
        return snapshot
            .map { raw in
                BatteryDevice(
                    id: raw.address.isEmpty ? raw.name : raw.address,
                    name: raw.name,
                    kind: DeviceKind.infer(fromName: raw.name),
                    percentage: raw.percentage,
                    isConnected: true
                )
            }
            .sorted { lhs, rhs in
                rank(lhs.kind) < rank(rhs.kind)
            }
    }

    private func rank(_ kind: DeviceKind) -> Int {
        switch kind {
        case .keyboard: return 0
        case .mouse: return 1
        case .trackpad: return 2
        case .other: return 3
        }
    }

    struct RawDevice: Equatable {
        var name: String
        var address: String
        var percentage: Int
    }

    static func readRawDevices() throws -> [RawDevice] {
        var result: [RawDevice] = []
        var iterator: io_iterator_t = 0
        let matching = IOServiceMatching("AppleDeviceManagementHIDEventService")
        let kr = IOServiceGetMatchingServices(kIOMainPortDefault, matching, &iterator)
        guard kr == KERN_SUCCESS else {
            throw BatteryProviderError.ioRegistry(kr)
        }
        defer { IOObjectRelease(iterator) }

        var service = IOIteratorNext(iterator)
        while service != 0 {
            defer {
                IOObjectRelease(service)
                service = IOIteratorNext(iterator)
            }

            guard let percentage = intProperty("BatteryPercent", service: service) else { continue }
            let name = stringProperty("Product", service: service)
                ?? stringProperty("DeviceName", service: service)
                ?? "Bluetooth Device"
            let address = stringProperty("DeviceAddress", service: service) ?? ""
            result.append(RawDevice(name: name, address: address, percentage: percentage))
        }

        // Deduplicate by address/name keeping first.
        var seen = Set<String>()
        return result.filter { device in
            let key = device.address.isEmpty ? device.name : device.address
            if seen.contains(key) { return false }
            seen.insert(key)
            return true
        }
    }

    static func intProperty(_ key: String, service: io_registry_entry_t) -> Int? {
        guard let num = IORegistryEntryCreateCFProperty(
            service,
            key as CFString,
            kCFAllocatorDefault,
            0
        )?.takeRetainedValue() as? NSNumber else {
            return nil
        }
        return num.intValue
    }

    static func stringProperty(_ key: String, service: io_registry_entry_t) -> String? {
        IORegistryEntryCreateCFProperty(
            service,
            key as CFString,
            kCFAllocatorDefault,
            0
        )?.takeRetainedValue() as? String
    }
}

public enum BatteryProviderError: Error, Equatable {
    case ioRegistry(kern_return_t)
}
