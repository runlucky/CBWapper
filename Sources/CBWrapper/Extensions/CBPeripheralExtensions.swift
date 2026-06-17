import CoreBluetooth

extension CBPeripheral {
    internal func getService(_ uuid: CBUUID) -> CBService? {
        self.services?.first { $0.uuid == uuid }
    }
}
