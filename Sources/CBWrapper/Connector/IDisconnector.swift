import Foundation

/// ペリフェラルとの切断プロトコル
@MainActor public protocol IDisconnector: Sendable {
    func disconnect() async throws
}
