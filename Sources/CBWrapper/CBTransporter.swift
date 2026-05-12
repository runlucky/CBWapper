import Foundation
import CoreBluetooth
import Observation

@MainActor
@Observable
public final class CBTransporter: NSObject {
    private var centralManager: CBCentralManager!
    private var discoveredPeripherals: [UUID: CBPeripheral] = [:]
    private let _peripheralStream = MultiStream<DiscoveredPeripheral>(bufferingPolicy: .bufferingNewest(1))
    public func peripheralStream() async -> AsyncStream<DiscoveredPeripheral> {
        await _peripheralStream.subscribe()
    }
        
    public private(set) var state: CBManagerState = .unknown
    public private(set) var isScanning = false

    override init() {
        super.init()
        self.centralManager = CBCentralManager(delegate: self, queue: .main)
    }

    @discardableResult public func startScan(withServices serviceUUIDs: [CBUUID]? = nil, options: [String: Any]? = nil) -> Bool {
        guard state == .poweredOn else {
            return false
        }

        centralManager.scanForPeripherals(withServices: serviceUUIDs, options: options)
        isScanning = true
        return true
    }

    public func stopScan() {
        centralManager.stopScan()
        isScanning = false
    }
}

extension CBTransporter: @MainActor CBCentralManagerDelegate {
    public func centralManagerDidUpdateState(_ central: CBCentralManager) {
        self.state = central.state
        if central.state != .poweredOn {
            isScanning = false
        }
    }

    // 以下、必要に応じて実装を追加してください。
    // 例: ペリフェラル検出
    public func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        discoveredPeripherals[peripheral.identifier] = peripheral
        _peripheralStream.publish(DiscoveredPeripheral(id: peripheral.identifier))
    }

    // 例: 接続成功
    // func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
    //     // 接続後の処理
    // }

    // 例: 接続失敗
    // func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
    //     // エラーハンドリング
    // }

    // 例: 切断
    // func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
    //     // 再接続や状態更新
    // }
}

