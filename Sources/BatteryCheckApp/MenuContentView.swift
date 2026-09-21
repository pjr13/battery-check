import SwiftUI

struct MenuContentView: View {
    @ObservedObject var model: AppModel

    var body: some View {
        if let lastError = model.lastError, model.devices.isEmpty {
            Text(lastError)
        }

        if model.devices.isEmpty {
            Text("尚無裝置電量資料")
        } else {
            ForEach(model.devices) { device in
                HStack {
                    Image(systemName: device.kind.symbolName)
                    Text(device.name)
                    Spacer()
                    Text("\(device.percentage)%")
                        .monospacedDigit()
                }
            }
        }

        Divider()

        Button(model.isRefreshing ? "更新中…" : "立即更新電量") {
            Task { await model.refreshManually() }
        }
        .disabled(model.isRefreshing)

        if let last = model.lastSuccess {
            Text("上次更新：\(last.formatted(date: .abbreviated, time: .shortened))")
        }
        if let next = model.nextRefresh {
            Text("下次檢查：\(next.formatted(date: .abbreviated, time: .shortened))")
        }

        Divider()

        SettingsLink {
            Text("設定…")
        }

        Button("結束 BatteryCheck") {
            NSApplication.shared.terminate(nil)
        }
    }
}
