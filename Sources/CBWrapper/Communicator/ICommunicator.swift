import Foundation
import CoreBluetooth

/// センサとの通信プロトコル
@MainActor public protocol ICommunicator: Sendable {
    /// Serviceを検出し、内部に保持します。
    func discoverService(_ serviceID: CBUUID) async throws
    /// 保持済みのServiceに含まれるCharacteristicを検出し、内部に保持します。
    func discoverCharacteristic(_ characteristicID: CBUUID) async throws
    /// ペリフェラルから通知された値を受け取ります。
    func valueStream() async -> AsyncStream<Data>
    /// ペリフェラルにwriteでデータを送り、writeの成功を待ちます。
    func send(_ value: Data) async throws
}
