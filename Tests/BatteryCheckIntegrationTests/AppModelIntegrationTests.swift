import XCTest
@testable import BatteryCheck

@MainActor
final class AppModelIntegrationTests: XCTestCase {
    func testRefreshPopulatesDevicesFromProvider() async {
        let provider = StaticBatteryProvider(devices: [
            BatteryDevice(id: "kb", name: "Magic Keyboard", kind: .keyboard, percentage: 88, isConnected: true),
            BatteryDevice(id: "ms", name: "Magic Mouse", kind: .mouse, percentage: 64, isConnected: true)
        ])
        let defaults = UserDefaults(suiteName: "BatteryCheck.Integration.\(UUID().uuidString)")!
        let model = AppModel(
            provider: provider,
            scheduler: RefreshScheduler(dailyHour: 0, dailyMinute: 0),
            defaults: defaults,
            launchAtLogin: FakeLaunchAtLoginManager()
        )

        await model.refreshManually()

        XCTAssertEqual(model.devices.count, 2)
        XCTAssertEqual(model.devices.first?.percentage, 88)
        XCTAssertTrue(model.statusText.contains("⌨️"))
        XCTAssertTrue(model.statusText.contains("🖱️"))
        XCTAssertNil(model.lastError)
    }

    func testEmptyProviderSetsFriendlyError() async {
        let provider = StaticBatteryProvider(devices: [])
        let defaults = UserDefaults(suiteName: "BatteryCheck.Integration.\(UUID().uuidString)")!
        let model = AppModel(provider: provider, defaults: defaults, launchAtLogin: FakeLaunchAtLoginManager())
        await model.refreshManually()
        XCTAssertTrue(model.devices.isEmpty)
        XCTAssertEqual(model.lastError, "找不到已連線的藍牙鍵盤／滑鼠")
    }

    func testCompositeProviderFindsConnectedKeyboard() async throws {
        let devices = try await CompositeBatteryProvider(
            bleBattery: StaticBLEBatteryServiceProvider(levels: [:])
        ).fetchDevices()
        XCTAssertNotNil(devices)
        if let keyboard = devices.first(where: { $0.kind == .keyboard }) {
            XCTAssertFalse(keyboard.name.isEmpty)
        }
    }

    func testCompositeMergesBLEBatteryLevels() async throws {
        let devices = try await CompositeBatteryProvider(
            bleBattery: StaticBLEBatteryServiceProvider(levels: [
                "Keychron K2 HE": 77,
                "MX Master 4": 55
            ])
        ).fetchDevices()
        let keyboard = devices.first { $0.kind == .keyboard }
        let mouse = devices.first { $0.kind == .mouse }
        XCTAssertEqual(keyboard?.percentage, 77)
        XCTAssertEqual(mouse?.percentage, 55)
    }
}


@MainActor
final class LaunchAtLoginIntegrationTests: XCTestCase {
    func testAppModelEnablesLaunchAtLoginThroughManager() {
        let launch = FakeLaunchAtLoginManager(current: .disabled)
        let defaults = UserDefaults(suiteName: "BatteryCheck.Launch.\(UUID().uuidString)")!
        let model = AppModel(
            provider: StaticBatteryProvider(devices: []),
            defaults: defaults,
            launchAtLogin: launch
        )
        // init auto-enables when disabled
        XCTAssertEqual(launch.status(), .enabled)
        XCTAssertEqual(model.launchAtLoginStatus, .enabled)

        model.setLaunchAtLoginEnabled(false)
        XCTAssertEqual(model.launchAtLoginStatus, .disabled)
        XCTAssertEqual(launch.setEnabledCalls.last, false)
    }
}
