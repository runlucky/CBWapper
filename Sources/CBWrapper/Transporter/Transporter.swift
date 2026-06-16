import Foundation
import CoreBluetooth
import Observation

@MainActor
public final class Transporter: NSObject {
    private var centralManager: CBCentralManager!

    private var discoveredPeripherals: [UUID: (timestamp: Date, peripheral: CBPeripheral)] = [:]
    private var connectContinuation: [UUID: CheckedContinuation<Void, any Error>] = [:]

    private let _peripheralStream = MultiStream<DiscoveredPeripheral>(bufferingPolicy: .bufferingNewest(1))
    private let _stateStream = MultiStream<TransporterState>(bufferingPolicy: .bufferingNewest(1))

    override public init() {
        super.init()
        self.centralManager = CBCentralManager(delegate: self, queue: .main)
    }
}

extension Transporter {
    internal func getPeripheral(_ target: DiscoveredPeripheral) -> CBPeripheral? {
        discoveredPeripherals[target.id]?.peripheral
    }
}

extension Transporter: @MainActor CBCentralManagerDelegate {
    public func centralManagerDidUpdateState(_ central: CBCentralManager) {
        let state = TransporterState(central.state)
        _stateStream.publish(state)
    }
    
    // ペリフェラル検出
    public func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        guard let discovered = DiscoveredPeripheral(peripheral, advertisementData, RSSI) else { return }
        if isDuplicate(peripheral.identifier, discovered.timestamp) { return }
        
        discoveredPeripherals[peripheral.identifier] = (discovered.timestamp, peripheral)
        _peripheralStream.publish(discovered)
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
    
    private func isDuplicate(_ id: UUID, _ timestamp: Date) -> Bool {
        if let previous = discoveredPeripherals[id]?.timestamp {
            let delta = timestamp.timeIntervalSince(previous)
            return (0 <= delta && delta <= 0.1)
        }
        return false
    }
}

extension Transporter: @MainActor IPeripheralScanner {
    public var isScanning: Bool {
        centralManager.isScanning
    }
    
    public var currentState: TransporterState {
        TransporterState(centralManager.state)
    }

    public func stateStream() async -> AsyncStream<TransporterState> {
        await _stateStream.subscribe()
    }

    public func peripheralStream() async -> AsyncStream<DiscoveredPeripheral> {
        await _peripheralStream.subscribe()
    }

    public func startScan(withServices serviceUUIDs: [CBUUID]?, options: [String: Any]?) -> Bool {
        guard currentState == .poweredOn else {
            return false
        }
        
        centralManager.scanForPeripherals(withServices: serviceUUIDs, options: options)
        return true
    }
    
    public func stopScan() {
        centralManager.stopScan()
    }

}

extension Transporter: IConnector {
    public var isMaxConnection: Bool { false }

    public func connect(_ target: DiscoveredPeripheral, _: ConnectionCriteria, communicate: @Sendable @escaping (ICommunicator) async throws -> Void) async throws {
        let communicator = try await self.connect(target, ConnectionCriteria())
        
        do {
            try await communicate(communicator)
            try await self.disconnect(target)
            
        } catch {
            try await self.disconnect(target)
            
        }
    }

    public func connect(_ target: DiscoveredPeripheral, _: ConnectionCriteria) async throws -> ICommunicator {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, any Error>) in
            guard self.centralManager.state == .poweredOn else {
                continuation.resume(throwing: ConnectionError.powerOff)
                return
            }
            
            guard let peripheral = self.getPeripheral(target) else {
                continuation.resume(throwing: ConnectionError.notFound)
                return
            }
            
            if self.connectContinuation[target.id] != nil {
                continuation.resume(throwing: ConnectionError.alreadyConnecting)
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
                logging(.info, "\(target.name) 接続開始")
                self.connectContinuation[target.id] = continuation
                self.centralManager.connect(peripheral, options: nil)
                
            @unknown default:
                continuation.resume(throwing: ConnectionError.unknown)
            }
        }
        logging(.info, "\(target.name) 接続成功")

        guard let peripheral = self.getPeripheral(target) else {
            throw ConnectionError.notFound
        }

        return SessionState(target, peripheral: peripheral, sessionID: UUID())
    }

    public func disconnect(_ target: DiscoveredPeripheral) async throws {
        guard let peripheral = self.getPeripheral(target) else {
            throw ConnectionError.notFound
        }
        
        try self.disconnect(peripheral)
        logging(.info, "\(target.name) 切断")
    }

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
}
