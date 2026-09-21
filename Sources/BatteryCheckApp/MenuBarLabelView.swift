import SwiftUI

struct MenuBarLabelView: View {
    @ObservedObject var model: AppModel

    var body: some View {
        // Emoji + percent is reliable in MenuBarExtra; SF Symbol stacks often collapse to one generic icon.
        Text(model.statusText)
            .font(.system(size: 12, weight: .medium))
            .monospacedDigit()
            .help(
                model.devices.isEmpty
                    ? "尚無已連線的藍牙鍵盤／滑鼠"
                    : model.devices.map { "\($0.kind.displayNameZH)：\($0.name) \($0.percentageText)" }.joined(separator: "\n")
            )
    }
}
