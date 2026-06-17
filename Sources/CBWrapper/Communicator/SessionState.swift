import Foundation
import CoreBluetooth

/// センサとの通信に必要な情報群
@MainActor
public final class SessionState {
    /// 接続するセンサID
    internal let target: DiscoveredPeripheral
    /// 通信を排他的に行うためのID
    internal let sessionID: UUID

    private let peripheral: CBPeripheral
    private let characteristicTransceiver: CharacteristicTransceiver

    private var service: CBService?
    private var characteristic: CBCharacteristic?

    internal init(_ target: DiscoveredPeripheral, peripheral: CBPeripheral, sessionID: UUID) {
        self.target = target
        self.peripheral = peripheral
        self.sessionID = sessionID
        self.characteristicTransceiver = CharacteristicTransceiver(target, peripheral)
    }
}

extension SessionState: ICommunicator {
    public func discoverService(_ targetID: CBUUID) async throws {
        if service?.uuid == targetID { return }

        let discovered = try await ServiceDiscoverer(target, peripheral).discover(targetID)
        self.service = discovered
        self.characteristic = nil
    }

    public func discoverCharacteristic(_ targetID: CBUUID) async throws {
        guard let service else { throw CommunicationError.notFoundService }

        if characteristic?.uuid == targetID { return }

        let discovered = try await CharacteristicDiscoverer(target, peripheral)
            .discover(targetID, in: service)
        self.characteristic = discovered
        try await characteristicTransceiver.prepareCommunication(with: discovered)
    }

    public func valueStream() async -> AsyncStream<Data> {
        await characteristicTransceiver.stream()
    }

    public func send(_ value: Data) async throws {
        try await characteristicTransceiver.send(value)
    }
}
