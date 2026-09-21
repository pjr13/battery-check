import AppKit
import Combine
import Foundation

@MainActor
final class AppModel: ObservableObject {
    @Published private(set) var devices: [BatteryDevice] = []
    @Published private(set) var lastSuccess: Date?
    @Published private(set) var lastError: String?
    @Published private(set) var nextRefresh: Date?
    @Published var isRefreshing = false

    private let provider: BatteryProviding
    private let scheduler: RefreshScheduler
    private let defaults: UserDefaults
    private let lastSuccessKey = "lastSuccessfulRefresh"
    private var timer: Timer?
    private var wakeObserver: NSObjectProtocol?

    init(
        provider: BatteryProviding = CompositeBatteryProvider(),
        scheduler: RefreshScheduler = RefreshScheduler(),
        defaults: UserDefaults = .standard
    ) {
        self.provider = provider
        self.scheduler = scheduler
        self.defaults = defaults
        self.lastSuccess = defaults.object(forKey: lastSuccessKey) as? Date
        scheduleNext()
        observeWake()
        Task { await refreshIfDue(force: false) }
    }

    deinit {
        timer?.invalidate()
        if let wakeObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(wakeObserver)
        }
    }

    var statusText: String {
        MenuBarFormatter.statusText(for: devices)
    }

    func refreshManually() async {
        await refreshIfDue(force: true)
    }

    func refreshIfDue(force: Bool) async {
        let now = Date()
        if !force && !scheduler.shouldRefreshNow(lastSuccess: lastSuccess, now: now) {
            scheduleNext()
            return
        }
        await performRefresh()
    }

    private func performRefresh() async {
        isRefreshing = true
        defer { isRefreshing = false }
        do {
            let fetched = try await provider.fetchDevices()
            devices = fetched
            lastSuccess = Date()
            defaults.set(lastSuccess, forKey: lastSuccessKey)
            lastError = fetched.isEmpty ? "找不到已連線的藍牙鍵盤／滑鼠" : nil
        } catch {
            lastError = error.localizedDescription
        }
        scheduleNext()
    }

    private func scheduleNext() {
        timer?.invalidate()
        let now = Date()
        var next = scheduler.nextRefreshDate(lastSuccess: lastSuccess, now: now)
        // If still in catch-up (due now) after an attempt, wait the catch-up interval instead of looping every second.
        if next <= now && !scheduler.hasCompletedToday(lastSuccess: lastSuccess, now: now) {
            next = now.addingTimeInterval(scheduler.catchUpInterval)
        }
        nextRefresh = next
        let interval = max(1, next.timeIntervalSince(now))
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: false) { [weak self] _ in
            Task { @MainActor in
                await self?.refreshIfDue(force: false)
            }
        }
        if let timer {
            RunLoop.main.add(timer, forMode: .common)
        }
    }

    private func observeWake() {
        wakeObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                await self?.refreshIfDue(force: false)
            }
        }
    }
}
