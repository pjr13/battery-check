import XCTest
@testable import BatteryCheck

@MainActor
final class AppModelIntegrationTests: XCTestCase {
    func testRefreshPopulatesDevicesFromProvider() async {
        let provider = StaticBatteryProvider(devices: [
            BatteryDevice(id: "kb", name: "Magic Keyboard", kind: .keyboard, percentage: 88),
            BatteryDevice(id: "ms", name: "Magic Mouse", kind: .mouse, percentage: 64)
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
        XCTAssertNotNil(model.lastSuccess)
        XCTAssertNil(model.lastError)
        XCTAssertTrue(model.statusText.contains("88%"))
        XCTAssertTrue(model.statusText.contains("64%"))
    }

    func testEmptyProviderSetsFriendlyError() async {
        let provider = StaticBatteryProvider(devices: [])
        let defaults = UserDefaults(suiteName: "BatteryCheck.Integration.\(UUID().uuidString)")!
        let model = AppModel(provider: provider, defaults: defaults)

        await model.refreshManually()

        XCTAssertTrue(model.devices.isEmpty)
        XCTAssertEqual(model.lastError, "找不到可讀取電量的藍牙鍵盤／滑鼠")
    }

    func testIORegistryProviderDoesNotThrow() throws {
        let provider = IORegistryBatteryProvider()
        XCTAssertNoThrow(try provider.fetchDevices())
    }
}
