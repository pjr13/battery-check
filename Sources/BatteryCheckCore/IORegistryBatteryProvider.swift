import Foundation
import IOKit

public struct IORegistryBatteryProvider: BatteryProviding {
    public init() {}

    public func fetchDevices() async throws -> [BatteryDevice] {
        try Self.readRawDevices().compactMap { raw -> BatteryDevice? in
            let lower = raw.name.lowercased()
            if lower.contains("internal keyboard") || lower.contains("built-in") {
                return nil
            }
            return BatteryDevice(
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

    struct RawDevice {
        var name: String
        var address: String
        var percentage: Int
    }

    static func readRawDevices() throws -> [RawDevice] {
        var result: [RawDevice] = []
        // Apple first-party and some Logitech devices
        let classNames = [
            "AppleDeviceManagementHIDEventService",
            "AppleBluetoothHIDKeyboard",
            "BNBTrackpadDevice",
            "BNBMouseDevice",
            "AppleBluetoothHIDMouseDevice"
        ]
        for className in classNames {
            result.append(contentsOf: readDevices(matchingClass: className))
        }

        // Deduplicate
        var seen = Set<String>()
        return result.filter { device in
            let key = device.address.isEmpty ? device.name : device.address.lowercased()
            if seen.contains(key) { return false }
            seen.insert(key)
            return true
        }
    }

    private static func readDevices(matchingClass className: String) -> [RawDevice] {
        var result: [RawDevice] = []
        var iterator: io_iterator_t = 0
        guard let matching = IOServiceMatching(className) else { return [] }
        let kr = IOServiceGetMatchingServices(kIOMainPortDefault, matching, &iterator)
        guard kr == KERN_SUCCESS else { return [] }
        defer { IOObjectRelease(iterator) }

        var service = IOIteratorNext(iterator)
        while service != 0 {
            defer {
                IOObjectRelease(service)
                service = IOIteratorNext(iterator)
            }
            guard let percentage = intProperty("BatteryPercent", service: service)
                    ?? intProperty("BatteryPercentRaw", service: service) else { continue }
            let name = stringProperty("Product", service: service)
                ?? stringProperty("DeviceName", service: service)
                ?? className
            let address = stringProperty("DeviceAddress", service: service)
                ?? stringProperty("BluetoothDeviceAddress", service: service)
                ?? ""
            result.append(RawDevice(name: name, address: address, percentage: percentage))
        }
        return result
    }

    static func intProperty(_ key: String, service: io_registry_entry_t) -> Int? {
        guard let num = IORegistryEntryCreateCFProperty(service, key as CFString, kCFAllocatorDefault, 0)?
            .takeRetainedValue() as? NSNumber else { return nil }
        return num.intValue
    }

    static func stringProperty(_ key: String, service: io_registry_entry_t) -> String? {
        IORegistryEntryCreateCFProperty(service, key as CFString, kCFAllocatorDefault, 0)?
            .takeRetainedValue() as? String
    }
}

public enum BatteryProviderError: Error, Equatable {
    case ioRegistry(kern_return_t)
}
