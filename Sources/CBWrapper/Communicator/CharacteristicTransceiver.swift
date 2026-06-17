import Foundation
import CoreBluetooth

@MainActor
internal final class CharacteristicTransceiver: NSObject {
    private let target: DiscoveredPeripheral
    private let peripheral: CBPeripheral
    private let valueStream = MultiStream<Data>()

    private var characteristic: CBCharacteristic?
    private var notifyContinuation: CheckedContinuation<Void, any Error>?
    private var writeContinuation: CheckedContinuation<Void, any Error>?

    internal init(_ target: DiscoveredPeripheral, _ peripheral: CBPeripheral) {
        self.target = target
        self.peripheral = peripheral
        super.init()
    }

    internal func prepareCommunication(with characteristic: CBCharacteristic) async throws {
        self.characteristic = characteristic
        try await enableNotify(for: characteristic)
    }

    internal func stream() async -> AsyncStream<Data> {
        await valueStream.subscribe()
    }

    internal func send(_ value: Data) async throws {
        guard let characteristic else {
            throw CommunicationError.notFoundCharacteristic
        }

        guard writeContinuation == nil else {
            throw CommunicationError.alreadySending
        }

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, any Error>) in
            guard peripheral.state == .connected else {
                continuation.resume(throwing: ConnectionError.alreadyDisconnected)
                return
            }

            peripheral.delegate = self
            writeContinuation = continuation
            peripheral.writeValue(value, for: characteristic, type: .withResponse)
            logging(.info, "\(target.name) データ送信開始: \(value as NSData)")
        }
    }

    private func enableNotify(for characteristic: CBCharacteristic) async throws {
        guard characteristic.properties.contains(.notify) || characteristic.properties.contains(.indicate) else {
            throw CommunicationError.notSupportedNotify
        }

        guard !characteristic.isNotifying else {
            return
        }

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, any Error>) in
            guard peripheral.state == .connected else {
                continuation.resume(throwing: ConnectionError.alreadyDisconnected)
                return
            }

            peripheral.delegate = self
            notifyContinuation = continuation
            peripheral.setNotifyValue(true, for: characteristic)
        }
    }
}

extension CharacteristicTransceiver: @MainActor CBPeripheralDelegate {
    internal func peripheral(_ peripheral: CBPeripheral, didUpdateNotificationStateFor characteristic: CBCharacteristic, error: Error?) {
        if let error {
            notifyContinuation?.resume(throwing: CommunicationError.other(error))
            notifyContinuation = nil
            return
        }

        notifyContinuation?.resume(returning: ())
        notifyContinuation = nil
    }

    internal func peripheral(_ peripheral: CBPeripheral, didWriteValueFor characteristic: CBCharacteristic, error: Error?) {
        if let error {
            writeContinuation?.resume(throwing: CommunicationError.other(error))
            writeContinuation = nil
            return
        }

        writeContinuation?.resume(returning: ())
        writeContinuation = nil
    }

    internal func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        guard error == nil,
              characteristic.uuid == self.characteristic?.uuid,
              let value = characteristic.value else { return }

        valueStream.publish(value)
    }
}
