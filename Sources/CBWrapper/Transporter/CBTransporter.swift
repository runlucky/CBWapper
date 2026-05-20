import Foundation
import CoreBluetooth
import Observation

@MainActor
@Observable
public final class CBTransporter: NSObject {
    internal var centralManager: CBCentralManager!
    private var discoveredPeripherals: [UUID: CBPeripheral] = [:]
    private let _peripheralStream = MultiStream<DiscoveredPeripheralID>(bufferingPolicy: .bufferingNewest(1))
    public func peripheralStream() async -> AsyncStream<DiscoveredPeripheralID> {
        await _peripheralStream.subscribe()
    }
    
    public private(set) var state: CBManagerState = .unknown
    public private(set) var isScanning = false
    
    internal var connectContinuation: [UUID: CheckedContinuation<Void, any Error>] = [:]
    internal var serviceContinuation: [UUID: CheckedContinuation<Void, any Error>] = [:]
    internal var characteristicContinuation: [UUID: CheckedContinuation<Void, any Error>] = [:]
    internal var characteristics: [UUID: CBCharacteristic] = [:]

    override init() {
        super.init()
        self.centralManager = CBCentralManager(delegate: self, queue: .main)
    }
    
    @discardableResult public func startScan(withServices serviceUUIDs: [CBUUID]? = nil, options: [String: Any]? = nil) -> Bool {
        guard state == .poweredOn else {
            return false
        }
        
        centralManager.scanForPeripherals(withServices: serviceUUIDs, options: options)
        isScanning = true
        return true
    }
    
    public func stopScan() {
        centralManager.stopScan()
        isScanning = false
    }
}

extension CBTransporter: @MainActor CBCentralManagerDelegate {
    public func centralManagerDidUpdateState(_ central: CBCentralManager) {
        self.state = central.state
        if central.state != .poweredOn {
            isScanning = false
        }
    }
    
    // ペリフェラル検出
    public func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        discoveredPeripherals[peripheral.identifier] = peripheral
        _peripheralStream.publish(DiscoveredPeripheralID(id: peripheral.identifier))
    }
    
    // 接続成功
    public func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        self.connectContinuation[peripheral.identifier]?.resume(returning: ())
        self.connectContinuation.removeValue(forKey: peripheral.identifier)
    }
    
    // 接続失敗
    public func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        self.connectContinuation[peripheral.identifier]?.resume(throwing: ConnectionError.other(error))
        self.connectContinuation.removeValue(forKey: peripheral.identifier)
    }
}


extension CBTransporter {
    internal func getPeripheral(_ discoveredPeripheral: DiscoveredPeripheralID) -> CBPeripheral? {
        discoveredPeripherals[discoveredPeripheral.id]
    }
}

extension CBTransporter: @MainActor CBPeripheralDelegate {
    /// Serviceを発見すると呼ばれます
    public func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        if let error {
            self.serviceContinuation[peripheral.identifier]?.resume(throwing: ConnectionError.other(error))
            self.serviceContinuation.removeValue(forKey: peripheral.identifier)
            return
        }

        self.serviceContinuation[peripheral.identifier]?.resume(returning: ())
        self.serviceContinuation.removeValue(forKey: peripheral.identifier)
    }

    /// Characteristicを発見すると呼ばれます
    public func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        if let error {
            self.characteristicContinuation[peripheral.identifier]?.resume(throwing: ConnectionError.other(error))
            self.characteristicContinuation.removeValue(forKey: peripheral.identifier)
            return
        }
        
        self.characteristicContinuation[peripheral.identifier]?.resume(returning: ())
        self.characteristicContinuation.removeValue(forKey: peripheral.identifier)
    }
}

