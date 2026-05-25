
public enum ConnectionError: Error {
    case powerOff
    case connecting
    case connectedOtherTask
    case connectedOtherApp
    case disconnecting
    case timeout
    case other(Error?)
    case canceledFromPeripheral
    case canceledFromCentral
    case sessionClosed
    case disconnected
    case locked
    case notFound
    case alreadyConnecting
    case alreadyDisconnected
    case maxLack(Int)
    case maxConnection
    case noUpdate
    case unknown
}
