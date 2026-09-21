import Foundation

public protocol BatteryProviding: Sendable {
    func fetchDevices() throws -> [BatteryDevice]
}

public struct StaticBatteryProvider: BatteryProviding {
    public var devices: [BatteryDevice]

    public init(devices: [BatteryDevice]) {
        self.devices = devices
    }

    public func fetchDevices() throws -> [BatteryDevice] {
        devices
    }
}
