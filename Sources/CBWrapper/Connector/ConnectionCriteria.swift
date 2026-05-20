import CoreBluetooth

public struct ConnectionCriteria {
    public var target: DiscoveredPeripheralID
    public var serviceID: CBUUID
    public var characteristicID: CBUUID
}
