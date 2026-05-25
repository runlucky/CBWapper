import CoreBluetooth

/// Transporterの状態。CBManagerStateのラッパー
public enum TransporterState : Sendable {
    /// 不明な状態
    case unknown
    /// Bluetoothシステムサービスとの接続が一時的に失われ、再接続を試みている
    case resetting
    /// 実行デバイスがBluetoothをサポートしていない
    case unsupported
    /// アプリがBluetoothの使用権限を持っていない
    case unauthorized
    /// BluetoothがOFFになっている
    case poweredOff
    /// BluetoothがONになっており、使用可能な状態
    case poweredOn
    
    internal init(_ state: CBManagerState) {
        switch state {
        case .unknown     : self = .unknown
        case .resetting   : self = .resetting
        case .unsupported : self = .unsupported
        case .unauthorized: self = .unauthorized
        case .poweredOff  : self = .poweredOff
        case .poweredOn   : self = .poweredOn
        @unknown default  : self = .unknown
        }
    }
    
    public var description: String {
        switch self {
        case .unknown     : "unknown"
        case .resetting   : "resetting"
        case .unsupported : "unsupported"
        case .unauthorized: "unauthorized"
        case .poweredOff  : "poweredOff"
        case .poweredOn   : "poweredOn"
        }
    }
}
