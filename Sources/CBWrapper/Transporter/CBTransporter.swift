import Foundation
import CoreBluetooth
import Observation

@MainActor
@Observable
public final class CBTransporter: NSObject {
    internal var centralManager: CBCentralManager!
    private var discoveredPeripherals: [UUID: CBPeripheral] = [:]
    private let _peripheralStream = MultiStream<Peripheral>(bufferingPolicy: .bufferingNewest(1))
    private let _stateStream = MultiStream<CBManagerState>(bufferingPolicy: .bufferingNewest(1))

    public private(set) var currentState: CBManagerState = .unknown
    public private(set) var isScanning = false
    
    internal var connectContinuation: [UUID: CheckedContinuation<Void, any Error>] = [:]
    internal var serviceContinuation: [UUID: CheckedContinuation<Void, any Error>] = [:]
    internal var characteristicContinuation: [UUID: CheckedContinuation<Void, any Error>] = [:]
    internal var characteristics: [UUID: CBCharacteristic] = [:]

    override init() {
        super.init()
        self.centralManager = CBCentralManager(delegate: self, queue: .main)
    }
    
}

extension CBTransporter {
    internal func getPeripheral(_ target: Peripheral) -> CBPeripheral? {
        discoveredPeripherals[target.id]
    }
}

extension CBTransporter: @MainActor CBCentralManagerDelegate {
    public func centralManagerDidUpdateState(_ central: CBCentralManager) {
        self.currentState = central.state
        if central.state != .poweredOn {
            isScanning = false
        }
    }
    
    // ペリフェラル検出
    public func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        discoveredPeripherals[peripheral.identifier] = peripheral
        _peripheralStream.publish(Peripheral(id: peripheral.identifier))
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

extension CBTransporter: @MainActor IPeripheralScanner {
    /// スキャナーの状態変化を通知します
    func stateStream() async -> AsyncStream<CBManagerState> {
        await _stateStream.subscribe()
    }

    public func peripheralStream() async -> AsyncStream<Peripheral> {
        await _peripheralStream.subscribe()
    }

    public func startScan(withServices serviceUUIDs: [CBUUID]?, options: [String: Any]?) -> Bool {
        guard currentState == .poweredOn else {
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

extension CBTransporter: IConnector {
    public var isMaxConnection: Bool { false }

    public func connect(_ target: Peripheral, _ criteria: ConnectionCriteria, communicate: @Sendable @escaping (ICommunicator) async throws -> Void) async throws {
        let communicator = try await self.connect(target, criteria)
        
        do {
            try await communicate(communicator)
            try await self.disconnect(target)
            
        } catch {
            try await self.disconnect(target)
            
        }
    }

    public func connect(_ target: Peripheral, _ criteria: ConnectionCriteria) async throws -> ICommunicator {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, any Error>) in
            guard self.centralManager.state == .poweredOn else {
                continuation.resume(throwing: ConnectionError.powerOff)
                return
            }
            
            guard let peripheral = self.getPeripheral(target) else {
                continuation.resume(throwing: ConnectionError.notFound)
                return
            }
            
            switch peripheral.state {
            case .connecting:
                continuation.resume(throwing: ConnectionError.connecting)
                
            case .disconnecting:
                continuation.resume(throwing: ConnectionError.disconnecting)
                
            case .connected:
                continuation.resume(throwing: ConnectionError.connectedOtherTask)
                
            case .disconnected:
                self.connectContinuation[target.id] = continuation
                self.centralManager.connect(peripheral, options: nil)
                
            @unknown default:
                continuation.resume(throwing: ConnectionError.unknown)
            }
        }
        
        guard let peripheral = self.getPeripheral(target) else {
            throw ConnectionError.notFound
        }

        let service = try await getService(peripheral, serviceID: criteria.serviceID)
        let characteristic = try await getCharacteristic(service, characteristicID: criteria.characteristicID)
        
        return SessionState(target, sessionID: UUID())
    }

    public func disconnect(_ target: Peripheral) async throws {
        guard let peripheral = self.getPeripheral(target) else {
            throw ConnectionError.notFound
        }
        
        try self.disconnect(peripheral)
    }
}

extension CBTransporter {
    private func disconnect(_ peripheral: CBPeripheral) throws(ConnectionError) {
        switch peripheral.state {
        case .connecting:
            self.centralManager.cancelPeripheralConnection(peripheral)

        case .disconnecting:
            throw .disconnecting

        case .connected:
            self.centralManager.cancelPeripheralConnection(peripheral)

        case .disconnected:
            throw .alreadyDisconnected

        @unknown default:
            throw .unknown
        }
    }
    
    private func getService(_ target: CBPeripheral, serviceID: CBUUID) async throws -> CBService {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, any Error>) in
            guard target.state == .connected else {
                continuation.resume(throwing: ConnectionError.alreadyDisconnected)
                return
            }
            
            target.delegate = self
            target.discoverServices([serviceID])
            
            self.serviceContinuation[target.identifier] = continuation
        }
        
        guard let service = target.services?.first(where: { $0.uuid == serviceID}) else {
            throw CommunicationError.notFoundService
        }
            
        return service
    }
    
    private func getCharacteristic(_ target: CBService, characteristicID: CBUUID) async throws -> CBCharacteristic {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, any Error>) in
            guard let peripheral = target.peripheral,
                  peripheral.state == .connected else {
                continuation.resume(throwing: ConnectionError.alreadyDisconnected)
                return
            }
            
            peripheral.discoverCharacteristics([characteristicID], for: target)
            self.characteristicContinuation[peripheral.identifier] = continuation
        }
        
        guard let characteristic = target.characteristics?.first(where: { $0.uuid == characteristicID }) else {
            throw CommunicationError.notFoundCharacteristic
        }
        
        return characteristic
    }
}
