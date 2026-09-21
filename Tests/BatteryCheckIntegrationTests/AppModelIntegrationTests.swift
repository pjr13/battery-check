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
            defaults: defaults
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
        let model = AppModel(provider: provider, defaults: defaults)
        await model.refreshManually()
        XCTAssertTrue(model.devices.isEmpty)
        XCTAssertEqual(model.lastError, "找不到已連線的藍牙鍵盤／滑鼠")
    }

    func testCompositeProviderFindsConnectedKeyboard() throws {
        let devices = try CompositeBatteryProvider().fetchDevices()
        // On this machine a Keychron keyboard is typically connected; at minimum call should not throw.
        XCTAssertNotNil(devices)
        if let keyboard = devices.first(where: { $0.kind == .keyboard }) {
            XCTAssertFalse(keyboard.name.isEmpty)
        }
    }
}
