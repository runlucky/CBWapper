import CoreBluetooth

@MainActor
internal final class ServiceDiscoverer: NSObject {
    private let target: DiscoveredPeripheral
    private let peripheral: CBPeripheral

    private var continuation: CheckedContinuation<Void, any Error>?

    internal init(_ target: DiscoveredPeripheral, _ peripheral: CBPeripheral) {
        self.target = target
        self.peripheral = peripheral
        super.init()
    }

    internal func discover(_ targetID: CBUUID) async throws -> CBService {
        if let service = peripheral.getService(targetID) {
            return service
        }

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, any Error>) in
            guard peripheral.state == .connected else {
                continuation.resume(throwing: ConnectionError.alreadyDisconnected)
                return
            }

            peripheral.delegate = self
            self.continuation = continuation
            peripheral.discoverServices([targetID])
            logging(.info, "\(target.name) Service検出開始")
        }

        guard let service = peripheral.getService(targetID) else {
            throw CommunicationError.notFoundService
        }

        return service
    }
}

extension ServiceDiscoverer: @MainActor CBPeripheralDelegate {
    internal func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        if let error {
            continuation?.resume(throwing: ConnectionError.other(error))
            continuation = nil
            logging(.info, "\(target.name) Service検出失敗: \(error.localizedDescription)")
            return
        }

        continuation?.resume(returning: ())
        continuation = nil
        logging(.info, "\(target.name) Service検出成功")
    }
}
