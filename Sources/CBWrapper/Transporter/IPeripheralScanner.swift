import CoreBluetooth

/// ペリフェラルのスキャンを行うためのプロトコル
protocol IPeripheralScanner {
    /// スキャン中かどうかを返します
    var isScanning: Bool { get }
    /// スキャナーの現在の状態を返します
    var currentState: TransporterState { get }
    /// スキャナーの状態変化を通知します
    func stateStream() async -> AsyncStream<TransporterState>
    /// 受信したペリフェラルを通知します
    func peripheralStream() async -> AsyncStream<DiscoveredPeripheral>
    /// スキャンを開始します
    /// - serviceUUIDs スキャン対象のサービスUUID。nilの場合は全てのペリフェラルをスキャンします
    /// - options スキャンオプション
    /// - 戻り値 スキャンの開始に成功したかどうかを返します
    func startScan(withServices serviceUUIDs: [CBUUID]?, options: [String: Any]?) -> Bool
    /// スキャンを停止します
    func stopScan()
}
