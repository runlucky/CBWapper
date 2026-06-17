import Foundation
import CoreBluetooth

/// センサとの通信プロトコル
@MainActor public protocol ICommunicator: Sendable {
    /// Serviceを検出し、内部に保持します
    func discoverService(_ serviceID: CBUUID) async throws
    /// 保持したServiceに含まれるCharacteristicを検出し、内部に保持します
    func discoverCharacteristic(_ characteristicID: CBUUID) async throws
    /// ペリフェラルから通知された値を受け取ります
    func receiveStream() async throws -> AsyncStream<Data>
    /// ペリフェラルにデータを送ります
    func submit(_ value: Data) async throws
}

extension ICommunicator {
    /// ペリフェラルにデータを送り、受信した値を返します。
    public func exchange(_ value: Data) async throws -> Data {
        let stream = try await receiveStream()

        try await submit(value)

        for await receivedValue in stream {
            return receivedValue
        }

        throw CommunicationError.notResponse
    }
}

