import CoreBluetooth

public struct ConnectionCriteria {
    public var service: CBUUID
    public var characteristics: [CBUUID]
    
    public init(service: CBUUID, characteristics: [CBUUID]) {
        self.service = service
        self.characteristics = characteristics
    }
}
