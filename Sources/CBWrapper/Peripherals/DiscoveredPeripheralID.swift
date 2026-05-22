import Foundation

public struct Peripheral: Identifiable, Hashable, Sendable {
    public let id: UUID
//    public let state: State
}


extension Peripheral {
    public enum State: Sendable, Hashable {
        case discovered(Date)
        case connecting
        case connected(Date)
    }
}
