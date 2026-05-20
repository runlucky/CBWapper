import Foundation
import CoreBluetooth

/// センサとの通信に必要な情報群
public struct SessionState {
    /// 接続するセンサID
    internal let targetID: DiscoveredPeripheralID
    /// 通信を排他的に行うためのID
    internal let sessionID: UUID
    
    internal init(targetID: DiscoveredPeripheralID, sessionID: UUID) {
        self.targetID = targetID
        self.sessionID = sessionID
    }
}

extension SessionState: ICommunicator {
    public func send(_ value: Data) async throws -> Data {
        Data()
    }
}


extension SessionState: IDisconnector {
    public func disconnect() async throws {
        
    }
    
}
