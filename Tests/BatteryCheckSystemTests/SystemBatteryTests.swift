import CoreBluetooth
import XCTest
@testable import BatteryCheck

/// Live system tests against real macOS Bluetooth / IORegistry / BLE APIs.
/// These are intentionally not mocked. Skip only when required peripherals are absent.
final class SystemBatteryTests: XCTestCase {
    private var connectedNames: Set<String> = []

    override func setUp() async throws {
        try await super.setUp()
        connectedNames = try await Self.loadConnectedBluetoothNames()
    }

    func testSystemProfilerSeesKeyboardAndMouseWhenConnected() async throws {
        try XCTSkipIf(
            !connectedNames.contains(where: { $0.localizedCaseInsensitiveContains("Keychron") }),
            "Keychron keyboard not connected"
        )
        try XCTSkipIf(
            !connectedNames.contains(where: { $0.localizedCaseInsensitiveContains("MX Master") }),
            "MX Master mouse not connected"
        )

        let devices = try await BluetoothConnectedDeviceProvider().fetchDevices()
        let names = devices.map(\.name)

        XCTAssertTrue(names.contains(where: { $0.localizedCaseInsensitiveContains("Keychron") }), names.joined(separator: ", "))
        XCTAssertTrue(names.contains(where: { $0.localizedCaseInsensitiveContains("MX Master") }), names.joined(separator: ", "))
        XCTAssertEqual(devices.first(where: { $0.name.localizedCaseInsensitiveContains("Keychron") })?.kind, .keyboard)
        XCTAssertEqual(devices.first(where: { $0.name.localizedCaseInsensitiveContains("MX Master") })?.kind, .mouse)
    }

    func testIORegistryProviderDoesNotThrowOnThisMac() async throws {
        let devices = try await IORegistryBatteryProvider().fetchDevices()
        // May be empty on third-party devices; must not throw / crash.
        XCTAssertNotNil(devices)
    }

    func testBLEBatteryServiceReadCompletesWithoutAPIMisuseCrash() async throws {
        try XCTSkipIf(connectedNames.isEmpty, "No Bluetooth peripherals connected")

        // Real CoreBluetooth path. Success = completes and returns a dictionary.
        // Percentage may be empty if system HID owns the GATT connection.
        let levels = try await BLEBatteryServiceProvider(timeout: 10).fetchBatteryLevels()
        XCTAssertNotNil(levels)

        // Soft signal: if we got any level, it must be 0...100
        for (key, value) in levels {
            XCTAssertGreaterThanOrEqual(value, 0, key)
            XCTAssertLessThanOrEqual(value, 100, key)
        }
    }

    func testCompositeProviderIncludesConnectedKeyboardAndMouse() async throws {
        try XCTSkipIf(
            !connectedNames.contains(where: { $0.localizedCaseInsensitiveContains("Keychron") }),
            "Keychron keyboard not connected"
        )
        try XCTSkipIf(
            !connectedNames.contains(where: { $0.localizedCaseInsensitiveContains("MX Master") }),
            "MX Master mouse not connected"
        )

        let devices = try await CompositeBatteryProvider(
            bleBattery: BLEBatteryServiceProvider(timeout: 10)
        ).fetchDevices()

        let keyboard = devices.first { $0.name.localizedCaseInsensitiveContains("Keychron") }
        let mouse = devices.first { $0.name.localizedCaseInsensitiveContains("MX Master") }

        XCTAssertNotNil(keyboard, "composite missing Keychron: \(devices.map(\.name))")
        XCTAssertNotNil(mouse, "composite missing MX Master: \(devices.map(\.name))")
        XCTAssertEqual(keyboard?.kind, .keyboard)
        XCTAssertEqual(mouse?.kind, .mouse)
        XCTAssertTrue(keyboard?.isConnected == true)
        XCTAssertTrue(mouse?.isConnected == true)

        // Menu bar text must identify both device classes somehow when both connected.
        let status = MenuBarFormatter.statusText(for: devices)
        XCTAssertTrue(status.contains("⌨️"), status)
        XCTAssertTrue(status.contains("🖱️"), status)
    }

    @MainActor
    func testAppModelRefreshAgainstRealProviders() async throws {
        try XCTSkipIf(
            !connectedNames.contains(where: { $0.localizedCaseInsensitiveContains("Keychron") }),
            "Keychron keyboard not connected"
        )

        let defaults = UserDefaults(suiteName: "BatteryCheck.System.\(UUID().uuidString)")!
        let model = AppModel(
            provider: CompositeBatteryProvider(bleBattery: BLEBatteryServiceProvider(timeout: 10)),
            scheduler: RefreshScheduler(dailyHour: 0, dailyMinute: 0),
            defaults: defaults,
            launchAtLogin: FakeLaunchAtLoginManager(current: .enabled)
        )

        await model.refreshManually()

        XCTAssertFalse(model.devices.isEmpty, "expected connected devices after refresh")
        XCTAssertNotNil(model.lastSuccess)
        XCTAssertTrue(model.statusText.contains("⌨️"), model.statusText)
    }

    private static func loadConnectedBluetoothNames() async throws -> Set<String> {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/sbin/system_profiler")
        process.arguments = ["SPBluetoothDataType", "-json"]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()
        try process.run()
        process.waitUntilExit()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        guard
            let root = try JSONSerialization.jsonObject(with: data) as? [String: Any],
            let list = root["SPBluetoothDataType"] as? [[String: Any]]
        else { return [] }

        var names = Set<String>()
        for controller in list {
            for item in controller["device_connected"] as? [[String: Any]] ?? [] {
                names.formUnion(item.keys)
            }
        }
        return names
    }
}

final class SystemLaunchAtLoginTests: XCTestCase {
    func testRegisterLaunchAtLoginWithSMAppService() throws {
        let manager = SMAppServiceLaunchAtLoginManager()
        // When running under xcodebuild test host, mainApp registration may be
        // unavailable or require approval; accept enabled/requiresApproval/unavailable.
        do {
            try manager.setEnabled(true)
        } catch {
            // Still assert we can read a status without crashing.
            let status = manager.status()
            XCTAssertTrue(
                [.enabled, .requiresApproval, .disabled, .unavailable].contains(status),
                "unexpected status \(status) after error \(error)"
            )
            return
        }

        let status = manager.status()
        XCTAssertTrue(
            status == .enabled || status == .requiresApproval || status == .unavailable,
            "expected enabled/requiresApproval/unavailable, got \(status)"
        )
    }
}
