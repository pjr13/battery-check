import SwiftUI

struct MenuBarLabelView: View {
    @ObservedObject var model: AppModel

    var body: some View {
        HStack(spacing: 6) {
            if model.devices.isEmpty {
                Image(systemName: "battery.100.bolt")
                Text("電量")
            } else {
                ForEach(displayDevices) { device in
                    HStack(spacing: 2) {
                        Image(systemName: device.kind.symbolName)
                        Text("\(device.percentage)%")
                    }
                }
            }
        }
        .font(.system(size: 12, weight: .medium))
    }

    private var displayDevices: [BatteryDevice] {
        let preferred = model.devices.filter {
            $0.kind == .keyboard || $0.kind == .mouse || $0.kind == .trackpad
        }
        return preferred.isEmpty ? Array(model.devices.prefix(3)) : preferred
    }
}
