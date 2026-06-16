import Foundation
import CoreBluetooth

/// センサとの通信に必要な情報群
@MainActor
public final class SessionState: NSObject {
    /// 接続するセンサID
    internal let target: DiscoveredPeripheral
    /// 通信を排他的に行うためのID
    internal let sessionID: UUID

    private let peripheral: CBPeripheral
    private var service: CBService?
    private var characteristic: CBCharacteristic?
    private var serviceContinuation: CheckedContinuation<Void, any Error>?
    private var characteristicContinuation: CheckedContinuation<Void, any Error>?
    private var notifyContinuation: CheckedContinuation<Void, any Error>?
    private var writeContinuation: CheckedContinuation<Void, any Error>?
    private let _valueStream = MultiStream<Data>()

    internal init(_ target: DiscoveredPeripheral, peripheral: CBPeripheral, sessionID: UUID) {
        self.target = target
        self.peripheral = peripheral
        self.sessionID = sessionID
    }
}

extension SessionState: ICommunicator {
    public func discoverService(_ serviceID: CBUUID) async throws {
        if service?.uuid == serviceID {
            return
        }

        if let service = peripheral.services?.first(where: { $0.uuid == serviceID }) {
            self.service = service
            return
        }

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, any Error>) in
            guard peripheral.state == .connected else {
                continuation.resume(throwing: ConnectionError.alreadyDisconnected)
                return
            }

            peripheral.delegate = self
            serviceContinuation = continuation
            peripheral.discoverServices([serviceID])
        }

        guard let service = peripheral.services?.first(where: { $0.uuid == serviceID }) else {
            throw CommunicationError.notFoundService
        }

        self.service = service
        characteristic = nil
    }

    public func discoverCharacteristic(_ characteristicID: CBUUID) async throws {
        guard let service else {
            throw CommunicationError.notFoundService
        }

        if characteristic?.uuid == characteristicID {
            return
        }

        if let characteristic = service.characteristics?.first(where: { $0.uuid == characteristicID }) {
            self.characteristic = characteristic
            try await enableNotify(for: characteristic)
            return
        }

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, any Error>) in
            guard peripheral.state == .connected else {
                continuation.resume(throwing: ConnectionError.alreadyDisconnected)
                return
            }

            peripheral.delegate = self
            characteristicContinuation = continuation
            peripheral.discoverCharacteristics([characteristicID], for: service)
        }

        guard let characteristic = service.characteristics?.first(where: { $0.uuid == characteristicID }) else {
            throw CommunicationError.notFoundCharacteristic
        }

        self.characteristic = characteristic
        try await enableNotify(for: characteristic)
    }

    public func valueStream() async -> AsyncStream<Data> {
        await _valueStream.subscribe()
    }

    public func send(_ value: Data) async throws {
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

extension SessionState: @MainActor CBPeripheralDelegate {
    public func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        if let error {
            serviceContinuation?.resume(throwing: ConnectionError.other(error))
            serviceContinuation = nil
            return
        }

        serviceContinuation?.resume(returning: ())
        serviceContinuation = nil
    }

    public func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        if let error {
            characteristicContinuation?.resume(throwing: ConnectionError.other(error))
            characteristicContinuation = nil
            return
        }

        characteristicContinuation?.resume(returning: ())
        characteristicContinuation = nil
    }

    public func peripheral(_ peripheral: CBPeripheral, didUpdateNotificationStateFor characteristic: CBCharacteristic, error: Error?) {
        if let error {
            notifyContinuation?.resume(throwing: CommunicationError.other(error))
            notifyContinuation = nil
            return
        }

        notifyContinuation?.resume(returning: ())
        notifyContinuation = nil
    }

    public func peripheral(_ peripheral: CBPeripheral, didWriteValueFor characteristic: CBCharacteristic, error: Error?) {
        if let error {
            writeContinuation?.resume(throwing: CommunicationError.other(error))
            writeContinuation = nil
            return
        }

        writeContinuation?.resume(returning: ())
        writeContinuation = nil
    }

    public func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        guard error == nil,
              characteristic.uuid == self.characteristic?.uuid,
              let value = characteristic.value else { return }

        _valueStream.publish(value)
    }
}
