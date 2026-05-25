import Foundation
import CoreBluetooth

public struct DiscoveredPeripheral: Identifiable, Hashable, Sendable {
    public let id: UUID
    public let name: String
    public let timestamp: Date
    public let rssi: Int
    
    internal init?(_ peripheral: CBPeripheral, _ advertisementData: [String : Any], _ rssi: NSNumber) {
        guard let name = advertisementData.localNameKey else { return nil }

        self.id = peripheral.identifier
        self.name = name
        self.timestamp = advertisementData.advDataTimestamp ?? Date()
        self.rssi = rssi.intValue
    }
}

extension Dictionary where Key == String, Value == Any {
    fileprivate var advDataTimestamp: Date? {
        guard let unixtime = self["kCBAdvDataTimestamp"] as? TimeInterval else { return nil }
        return Date(timeIntervalSinceReferenceDate: unixtime)
    }
    
    fileprivate var localNameKey: String? {
        self[CBAdvertisementDataLocalNameKey] as? String
    }
}

/// stateは刻一刻と変化する、つまりSendableにできない
/// ここではないところで別途保持すべき
extension DiscoveredPeripheral {
    public enum State: Sendable, Hashable {
        case discovered(Date)
        case connecting
        case connected(Date)
    }
}
