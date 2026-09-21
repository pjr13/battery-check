import CoreBluetooth
import Foundation

/// Reads standard BLE Battery Service (0x180F / 0x2A19) from peripherals.
public final class BLEBatteryServiceProvider: NSObject, BLEBatteryServiceProviding, @unchecked Sendable {
    private let timeout: TimeInterval

    public init(timeout: TimeInterval = 8) {
        self.timeout = timeout
    }

    public func fetchBatteryLevels() async throws -> [String: Int] {
        try await BLEBatterySession(timeout: timeout).readLevels()
    }
}

/// Pure helper so connection decisions can be unit-tested without CoreBluetooth.
public enum BLEPeripheralAction: Equatable {
    case connect
    case discoverServices
    case skip
}

public enum BLEPeripheralGate {
    public static func nextAction(state: CBPeripheralState) -> BLEPeripheralAction {
        switch state {
        case .connected:
            return .discoverServices
        case .disconnected, .disconnecting:
            return .connect
        case .connecting:
            return .skip
        @unknown default:
            return .skip
        }
    }
}

private final class BLEBatterySession: NSObject, CBCentralManagerDelegate, CBPeripheralDelegate {
    private let timeout: TimeInterval
    private let queue = DispatchQueue(label: "com.pjr13.battery-check.ble")
    private var central: CBCentralManager?
    private var continuation: CheckedContinuation<[String: Int], Error>?
    private var levels: [String: Int] = [:]
    private var pending = Set<UUID>()
    private var peripherals: [UUID: CBPeripheral] = [:]
    private var finished = false
    private let batteryService = CBUUID(string: "180F")
    private let batteryLevelChar = CBUUID(string: "2A19")
    private let hidService = CBUUID(string: "1812")
    private let deviceInfoService = CBUUID(string: "180A")

    init(timeout: TimeInterval) {
        self.timeout = timeout
    }

    func readLevels() async throws -> [String: Int] {
        try await withCheckedThrowingContinuation { cont in
            self.continuation = cont
            self.central = CBCentralManager(
                delegate: self,
                queue: queue,
                options: [CBCentralManagerOptionShowPowerAlertKey: false]
            )
            queue.asyncAfter(deadline: .now() + timeout) { [weak self] in
                self?.finish()
            }
        }
    }

    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        switch central.state {
        case .poweredOn:
            start(with: central)
        case .unauthorized, .poweredOff, .unsupported:
            fail(BLEBatteryError.unavailable(central.state.rawValue))
        case .resetting, .unknown:
            break
        @unknown default:
            break
        }
    }

    private func start(with central: CBCentralManager) {
        var unique: [UUID: CBPeripheral] = [:]
        for peripheral in central.retrieveConnectedPeripherals(withServices: [
            batteryService, hidService, deviceInfoService
        ]) {
            unique[peripheral.identifier] = peripheral
        }

        let targets = Array(unique.values)
        if targets.isEmpty {
            finish()
            return
        }

        for peripheral in targets {
            peripherals[peripheral.identifier] = peripheral
            pending.insert(peripheral.identifier)
            peripheral.delegate = self
            engage(peripheral)
        }
    }

    private func engage(_ peripheral: CBPeripheral) {
        guard let central else {
            completeOne(peripheral.identifier)
            return
        }

        switch BLEPeripheralGate.nextAction(state: peripheral.state) {
        case .discoverServices:
            discoverBatteryService(on: peripheral)
        case .connect:
            // System-paired HID devices often appear disconnected to our central.
            // Connect first; only discover after didConnect.
            central.connect(peripheral, options: nil)
        case .skip:
            // Still connecting — wait for delegate callback or timeout.
            break
        }
    }

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        peripheral.delegate = self
        discoverBatteryService(on: peripheral)
    }

    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        completeOne(peripheral.identifier)
    }

    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        // If we disconnect mid-read, stop waiting on this peripheral.
        completeOne(peripheral.identifier)
    }

    private func discoverBatteryService(on peripheral: CBPeripheral) {
        guard peripheral.state == .connected else {
            // Never send GATT commands while disconnected (API MISUSE).
            if let central {
                central.connect(peripheral, options: nil)
            } else {
                completeOne(peripheral.identifier)
            }
            return
        }
        peripheral.discoverServices([batteryService])
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        if error != nil || peripheral.state != .connected {
            completeOne(peripheral.identifier)
            return
        }
        guard let service = peripheral.services?.first(where: { $0.uuid == batteryService }) else {
            completeOne(peripheral.identifier)
            return
        }
        peripheral.discoverCharacteristics([batteryLevelChar], for: service)
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        if error != nil || peripheral.state != .connected {
            completeOne(peripheral.identifier)
            return
        }
        guard let char = service.characteristics?.first(where: { $0.uuid == batteryLevelChar }) else {
            completeOne(peripheral.identifier)
            return
        }
        peripheral.readValue(for: char)
    }

    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        defer { completeOne(peripheral.identifier) }
        guard error == nil,
              characteristic.uuid == batteryLevelChar,
              let data = characteristic.value,
              let percent = data.first else { return }

        let value = Int(percent)
        if let name = peripheral.name, !name.isEmpty {
            levels[name] = value
        }
        levels[peripheral.identifier.uuidString] = value
    }

    private func completeOne(_ id: UUID) {
        guard pending.contains(id) else { return }
        pending.remove(id)
        if pending.isEmpty {
            finish()
        }
    }

    private func finish() {
        guard !finished else { return }
        finished = true
        let cont = continuation
        continuation = nil
        // Cancel outstanding connects to avoid lingering API activity.
        if let central {
            for peripheral in peripherals.values where peripheral.state == .connecting {
                central.cancelPeripheralConnection(peripheral)
            }
        }
        cont?.resume(returning: levels)
    }

    private func fail(_ error: Error) {
        guard !finished else { return }
        finished = true
        let cont = continuation
        continuation = nil
        cont?.resume(throwing: error)
    }
}

public enum BLEBatteryError: Error, Equatable {
    case unavailable(Int)
    case timeout
}
