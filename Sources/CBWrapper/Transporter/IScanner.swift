import CoreBluetooth


protocol IScanner {
    /// スキャナーの現在の状態を返します
    var currentState: CBManagerState { get }
    /// スキャナーの状態変化を通知します
    func stateStream() async -> AsyncStream<CBManagerState>
    /// 受信したペリフェラルを通知します
    func peripheralStream() async -> AsyncStream<DiscoveredPeripheralID>
    
    func startScan(withServices serviceUUIDs: [CBUUID]?, options: [String: Any]?) -> Bool
    func stopScan()
}
