import XCTest
@testable import BatteryCheck

final class RefreshSchedulerTests: XCTestCase {
    private var calendar: Calendar!
    private var scheduler: RefreshScheduler!

    override func setUp() {
        super.setUp()
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "Asia/Taipei")!
        calendar = cal
        scheduler = RefreshScheduler(
            dailyHour: 9,
            dailyMinute: 30,
            catchUpInterval: 30 * 60,
            calendar: cal
        )
    }

    private func date(_ y: Int, _ m: Int, _ d: Int, _ h: Int, _ min: Int) -> Date {
        calendar.date(from: DateComponents(year: y, month: m, day: d, hour: h, minute: min))!
    }

    func testBeforeWindowWaitsUntilNineThirty() {
        let now = date(2026, 9, 21, 8, 0)
        XCTAssertEqual(scheduler.nextRefreshDate(lastSuccess: nil, now: now), date(2026, 9, 21, 9, 30))
        XCTAssertFalse(scheduler.shouldRefreshNow(lastSuccess: nil, now: now))
    }

    func testAtWindowWithoutSuccessIsDue() {
        let now = date(2026, 9, 21, 9, 30)
        XCTAssertTrue(scheduler.shouldRefreshNow(lastSuccess: nil, now: now))
    }

    func testMissedWindowUsesCatchUpUntilSuccess() {
        let now = date(2026, 9, 21, 11, 0)
        let lastNight = date(2026, 9, 20, 9, 30)
        XCTAssertTrue(scheduler.shouldRefreshNow(lastSuccess: lastNight, now: now))
    }

    func testAfterSuccessSchedulesTomorrow() {
        let success = date(2026, 9, 21, 9, 31)
        let now = date(2026, 9, 21, 10, 0)
        XCTAssertTrue(scheduler.hasCompletedToday(lastSuccess: success, now: now))
        XCTAssertEqual(scheduler.nextRefreshDate(lastSuccess: success, now: now), date(2026, 9, 22, 9, 30))
    }

    func testCatchUpDoesNotMarkCompleteWithoutSuccess() {
        let now = date(2026, 9, 21, 12, 0)
        XCTAssertFalse(scheduler.hasCompletedToday(lastSuccess: nil, now: now))
    }
}

final class MenuBarFormatterTests: XCTestCase {
    func testStatusTextUsesKeyboardAndMouseEmoji() {
        let devices = [
            BatteryDevice(id: "k", name: "Keyboard", kind: .keyboard, percentage: 85, isConnected: true),
            BatteryDevice(id: "m", name: "Mouse", kind: .mouse, percentage: 72, isConnected: true)
        ]
        let text = MenuBarFormatter.statusText(for: devices)
        XCTAssertTrue(text.contains("⌨️"))
        XCTAssertTrue(text.contains("🖱️"))
        XCTAssertTrue(text.contains("85%"))
        XCTAssertTrue(text.contains("72%"))
    }

    func testUnknownPercentageShowsDash() {
        let devices = [
            BatteryDevice(id: "k", name: "Keychron", kind: .keyboard, percentage: nil, isConnected: true)
        ]
        XCTAssertEqual(MenuBarFormatter.statusText(for: devices), "⌨️—")
    }

    func testEmptyShowsPlaceholders() {
        XCTAssertEqual(MenuBarFormatter.statusText(for: []), "⌨️—  🖱️—")
    }

    func testKindInferenceIncludesKeychron() {
        XCTAssertEqual(DeviceKind.infer(fromName: "Keychron K2 HE"), .keyboard)
        XCTAssertEqual(DeviceKind.infer(fromName: "MX Master 4", minorType: "Mouse"), .mouse)
    }
}
