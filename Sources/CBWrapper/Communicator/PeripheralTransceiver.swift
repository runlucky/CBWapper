import Foundation
import CoreBluetooth

/// ペリフェラルと値の送受信を行います
@MainActor
internal final class PeripheralTransceiver: NSObject {
    private let peripheral: CBPeripheral
    private var characteristic: CBCharacteristic

    private let _receiveStream = MultiStream<Data>()

    private var notifyContinuation: CheckedContinuation<Void, any Error>?
    private var writeContinuation: CheckedContinuation<Void, any Error>?

    internal init(_ peripheral: CBPeripheral, _ characteristic: CBCharacteristic) async throws {
        self.peripheral = peripheral
        self.characteristic = characteristic
        super.init()
        try await enableNotify(for: characteristic)
    }

    internal func receiveStream() async -> AsyncStream<Data> {
        await _receiveStream.subscribe()
    }

    internal func submit(_ value: Data) async throws {
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
            logging(.info, "\(peripheral.name ?? "nil") データ送信: \(value as NSData)")
        }
    }

    private func enableNotify(for characteristic: CBCharacteristic) async throws {
        guard characteristic.properties.contains(.notify) || characteristic.properties.contains(.indicate) else {
            throw CommunicationError.notSupportedNotify
        }

        if characteristic.isNotifying { return }

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, any Error>) in
            guard peripheral.state == .connected else {
                continuation.resume(throwing: ConnectionError.alreadyDisconnected)
                return
            }

            peripheral.delegate = self
            notifyContinuation = continuation
            peripheral.setNotifyValue(true, for: characteristic)
            logging(.info, "\(peripheral.name ?? "nil") Notify開始")
        }
    }
}

extension PeripheralTransceiver: @MainActor CBPeripheralDelegate {
    internal func peripheral(_ peripheral: CBPeripheral, didUpdateNotificationStateFor characteristic: CBCharacteristic, error: Error?) {
        if let error {
            notifyContinuation?.resume(throwing: CommunicationError.other(error))
            notifyContinuation = nil
            return
        }

        logging(.info, "\(peripheral.name ?? "nil") Notify状態更新: \(characteristic.isNotifying ? "ON" : "OFF")")
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
              characteristic.uuid == self.characteristic.uuid,
              let value = characteristic.value else { return }

        logging(.info, "\(peripheral.name ?? "nil") データ受信: \(value as NSData)")
        _receiveStream.publish(value)
    }
}
