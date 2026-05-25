import Foundation
import CoreBluetooth

/// センサとの通信に必要な情報群
public struct SessionState {
    /// 接続するセンサID
    internal let target: DiscoveredPeripheral
    /// 通信を排他的に行うためのID
    internal let sessionID: UUID
    
    internal init(_ target: DiscoveredPeripheral, sessionID: UUID) {
        self.target = target
        self.sessionID = sessionID
    }
}

extension SessionState: ICommunicator {
    public func send(_ value: Data) async throws -> Data {
        Data()
    }
}

