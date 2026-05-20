import Foundation

/// センサとの通信プロトコル
@MainActor public protocol ICommunicator: Sendable {
    /// ペリフェラルにwriteでデータを送り、notifyで応答を受け取ります。
    func send(_ value: Data) async throws -> Data
}
