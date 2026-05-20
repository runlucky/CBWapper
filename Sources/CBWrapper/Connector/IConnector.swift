import Foundation

/// ペリフェラルとの接続プロトコル
@MainActor public protocol IConnector: Sendable {
    /// 接続〜通信〜切断までを行います。disconnectを呼ぶ必要はありません。
    func connect(_ criteria: ConnectionCriteria, communicate: @Sendable @escaping (ICommunicator) async throws -> Void) async throws
    /// 接続のみを行います。このメソッドを呼んだ場合、使用後にdisconnectを呼んでください。
    func connect(_ criteria: ConnectionCriteria) async throws -> ICommunicator & IDisconnector
    /// 同時接続上限に達しているかどうかを返します
    var isMaxConnection: Bool { get }
}
