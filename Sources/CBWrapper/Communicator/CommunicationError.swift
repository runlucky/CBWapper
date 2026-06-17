public enum CommunicationError: Error {
    case notFoundService
    case notFoundCharacteristic
    case notSupportedNotify
    case alreadySending
    case notResponse
    case other(Error?)
}
