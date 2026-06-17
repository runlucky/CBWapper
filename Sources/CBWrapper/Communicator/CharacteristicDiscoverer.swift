import CoreBluetooth

@MainActor
internal final class CharacteristicDiscoverer: NSObject {
    private let target: DiscoveredPeripheral
    private let peripheral: CBPeripheral

    private var continuation: CheckedContinuation<Void, any Error>?

    internal init(_ target: DiscoveredPeripheral, _ peripheral: CBPeripheral) {
        self.target = target
        self.peripheral = peripheral
        super.init()
    }

    internal func discover(_ targetID: CBUUID, in service: CBService) async throws -> CBCharacteristic {
        if let characteristic = service.getCharacteristic(targetID) {
            return characteristic
        }

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, any Error>) in
            guard peripheral.state == .connected else {
                continuation.resume(throwing: ConnectionError.alreadyDisconnected)
                return
            }

            peripheral.delegate = self
            self.continuation = continuation
            peripheral.discoverCharacteristics([targetID], for: service)
            logging(.info, "\(target.name) Characteristic検出開始")
        }

        guard let characteristic = service.getCharacteristic(targetID) else {
            throw CommunicationError.notFoundCharacteristic
        }

        return characteristic
    }
}

extension CharacteristicDiscoverer: @MainActor CBPeripheralDelegate {
    internal func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        if let error {
            continuation?.resume(throwing: ConnectionError.other(error))
            continuation = nil
            logging(.info, "\(target.name) Characteristic検出失敗: \(error.localizedDescription)")
            return
        }

        continuation?.resume(returning: ())
        continuation = nil
        logging(.info, "\(target.name) Characteristic検出成功")
    }
}
