import CoreBluetooth
import Foundation

/// Reads standard BLE Battery Service (0x180F / 0x2A19) from system-connected peripherals.
public final class BLEBatteryServiceProvider: NSObject, BLEBatteryServiceProviding, @unchecked Sendable {
    private let timeout: TimeInterval

    public init(timeout: TimeInterval = 6) {
        self.timeout = timeout
    }

    public func fetchBatteryLevels() async throws -> [String: Int] {
        try await BLEBatterySession(timeout: timeout).readLevels()
    }
}

private final class BLEBatterySession: NSObject, CBCentralManagerDelegate, CBPeripheralDelegate {
    private let timeout: TimeInterval
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
            self.central = CBCentralManager(delegate: self, queue: nil, options: [
                CBCentralManagerOptionShowPowerAlertKey: false
            ])
            DispatchQueue.main.asyncAfter(deadline: .now() + timeout) { [weak self] in
                self?.finish()
            }
        }
    }

    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        switch central.state {
        case .poweredOn:
            var connected = central.retrieveConnectedPeripherals(withServices: [
                batteryService, hidService, deviceInfoService
            ])
            // Deduplicate by identifier
            var unique: [UUID: CBPeripheral] = [:]
            for p in connected { unique[p.identifier] = p }
            connected = Array(unique.values)

            if connected.isEmpty {
                finish()
                return
            }

            for peripheral in connected {
                peripherals[peripheral.identifier] = peripheral
                pending.insert(peripheral.identifier)
                peripheral.delegate = self
                if peripheral.services == nil {
                    peripheral.discoverServices([batteryService])
                } else if let services = peripheral.services, services.contains(where: { $0.uuid == batteryService }) {
                    discoverBatteryCharacteristic(on: peripheral)
                } else {
                    peripheral.discoverServices([batteryService])
                }
            }
        case .unauthorized, .poweredOff, .unsupported:
            fail(BLEBatteryError.unavailable(central.state.rawValue))
        case .resetting, .unknown:
            break
        @unknown default:
            break
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        if error != nil {
            completeOne(peripheral.identifier)
            return
        }
        discoverBatteryCharacteristic(on: peripheral)
    }

    private func discoverBatteryCharacteristic(on peripheral: CBPeripheral) {
        guard let service = peripheral.services?.first(where: { $0.uuid == batteryService }) else {
            completeOne(peripheral.identifier)
            return
        }
        peripheral.discoverCharacteristics([batteryLevelChar], for: service)
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        if error != nil {
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

        let name = peripheral.name ?? peripheral.identifier.uuidString
        levels[name] = Int(percent)
        levels[peripheral.identifier.uuidString] = Int(percent)
    }

    private func completeOne(_ id: UUID) {
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
