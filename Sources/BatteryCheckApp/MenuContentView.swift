import AppKit
import SwiftUI

struct MenuContentView: View {
    @ObservedObject var model: AppModel

    var body: some View {
        if let lastError = model.lastError, model.devices.isEmpty {
            Text(lastError)
        }

        if model.devices.isEmpty {
            Text("尚無已連線的藍牙鍵盤／滑鼠")
        } else {
            ForEach(model.devices) { device in
                HStack {
                    Text(device.kind.emoji)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(device.name)
                        Text(device.kind.displayNameZH)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 12)
                    Text(device.percentageText)
                        .monospacedDigit()
                        .foregroundStyle(device.percentage == nil ? .secondary : .primary)
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
