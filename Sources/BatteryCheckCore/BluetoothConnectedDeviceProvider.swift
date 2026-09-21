import Foundation

/// Discovers connected Bluetooth keyboards/mice via `system_profiler` (no percentage by itself).
public struct BluetoothConnectedDeviceProvider: BatteryProviding {
    public init() {}

    public func fetchDevices() async throws -> [BatteryDevice] {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/sbin/system_profiler")
        process.arguments = ["SPBluetoothDataType", "-json"]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()
        try process.run()
        process.waitUntilExit()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        guard !data.isEmpty else { return [] }

        guard
            let root = try JSONSerialization.jsonObject(with: data) as? [String: Any],
            let list = root["SPBluetoothDataType"] as? [[String: Any]]
        else { return [] }

        var devices: [BatteryDevice] = []
        for controller in list {
            // macOS uses device_connected as array of single-key dictionaries
            let connected = controller["device_connected"] as? [[String: Any]] ?? []
            for item in connected {
                for (name, rawProps) in item {
                    guard let props = rawProps as? [String: Any] else { continue }
                    let minor = (props["device_minorType"] as? String) ?? ""
                    let kind = DeviceKind.infer(fromName: name, minorType: minor)
                    guard kind == .keyboard || kind == .mouse || kind == .trackpad else { continue }
                    let address = (props["device_address"] as? String) ?? name
                    // system_profiler rarely includes battery; leave nil unless present
                    let percentage = parsePercentage(props)
                    devices.append(
                        BatteryDevice(
                            id: address,
                            name: name,
                            kind: kind,
                            percentage: percentage,
                            isConnected: true
                        )
                    )
                }
            }
        }
        return devices
    }

    private func parsePercentage(_ props: [String: Any]) -> Int? {
        let keys = ["device_batteryLevel", "battery_percent", "device_batteryPercent", "battery"]
        for key in keys {
            if let n = props[key] as? Int { return n }
            if let s = props[key] as? String {
                let digits = s.filter(\.isNumber)
                if let v = Int(digits), !digits.isEmpty { return v }
            }
        }
        return nil
    }
}
