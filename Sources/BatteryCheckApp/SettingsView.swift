import SwiftUI

struct SettingsView: View {
    @ObservedObject var model: AppModel

    var body: some View {
        Form {
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
        .frame(width: 420, height: 240)
        .padding()
    }
}
