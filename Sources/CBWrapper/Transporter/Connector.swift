import CoreBluetooth


extension CBTransporter: IConnector {
    public func connect(_ criteria: ConnectionCriteria, communicate: @escaping (ICommunicator) async throws -> Void) async throws {
        try await self.connect(criteria)
        
        do {
            
            try await communicate(ConnectedPeripheralID(id: criteria.target.id))
            try await self.disconnect(criteria.target)
            
        } catch {
            try await self.disconnect(criteria.target)
            
        }
    }
    
    
    public func connect(_ criteria: ConnectionCriteria) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, any Error>) in
            guard self.centralManager.state == .poweredOn else {
                continuation.resume(throwing: ConnectionError.powerOff)
                return
            }
            
            guard let peripheral = self.getPeripheral(criteria.target) else {
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
                self.connectContinuation[criteria.target.id] = continuation
                self.centralManager.connect(peripheral, options: nil)
                
            @unknown default:
                continuation.resume(throwing: ConnectionError.unknown)
            }
        }
        
        guard let peripheral = self.getPeripheral(criteria.target) else {
            throw ConnectionError.notFound
        }

        let service = try await getService(peripheral, serviceID: criteria.serviceID)
        let characteristic = try await getCharacteristic(service, characteristicID: criteria.characteristicID)
        
    }
    
    public func disconnect(_ target: DiscoveredPeripheralID) async throws {
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
