import AppKit
import SwiftUI

struct SettingsView: View {
    @ObservedObject var model: AppModel

    var body: some View {
        Form {
            Section("一般") {
                Toggle("開機自動啟動", isOn: launchAtLoginBinding)
                Text(launchAtLoginHelp)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if model.launchAtLoginStatus == .requiresApproval {
                    Button("打開登入項目設定") {
                        openLoginItemsSettings()
                    }
                }
                if let error = model.launchAtLoginError {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }

            Section("更新排程") {
                Text("每天約 09:30 檢查一次。若當時未開機，喚醒後每 30 分鐘補查，成功後恢復每日排程。")
                    .foregroundStyle(.secondary)
                if let next = model.nextRefresh {
                    LabeledContent("下次檢查") {
                        Text(next.formatted(date: .abbreviated, time: .shortened))
                    }
                }
                if let last = model.lastSuccess {
                    LabeledContent("上次成功") {
                        Text(last.formatted(date: .abbreviated, time: .shortened))
                    }
                }
            }

            Section("關於") {
                Text("BatteryCheck 會讀取已配對藍牙鍵盤／滑鼠的電量，並顯示在選單列。")
            }
        }
        .formStyle(.grouped)
        .frame(width: 440, height: 320)
        .padding()
        .onAppear {
            model.refreshLaunchAtLoginStatus()
        }
    }

    private var launchAtLoginBinding: Binding<Bool> {
        Binding(
            get: { model.launchAtLoginStatus == .enabled || model.launchAtLoginStatus == .requiresApproval },
            set: { model.setLaunchAtLoginEnabled($0) }
        )
    }

    private var launchAtLoginHelp: String {
        switch model.launchAtLoginStatus {
        case .enabled:
            return "已啟用：登入 macOS 後會自動開啟 BatteryCheck。"
        case .requiresApproval:
            return "已送出登錄，但系統還需要你在「登入項目」中允許 BatteryCheck。"
        case .disabled:
            return "關閉時，開機後不會自動啟動。"
        case .unavailable:
            return "目前無法管理自動啟動（可能不是從正式 App bundle 執行）。"
        }
    }

    private func openLoginItemsSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.LoginItems-Settings.extension") {
            NSWorkspace.shared.open(url)
        }
    }
}
