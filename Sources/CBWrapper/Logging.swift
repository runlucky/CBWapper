import Foundation

public let formatter = {
    let formatter = DateFormatter()
    formatter.dateFormat = "HH:mm:ss.SSS"
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.timeZone = .current
    
    return formatter
}()

public func logging(_ level: Log.Level, file: String = #fileID, function: String = #function, line: Int = #line, _ message: String, allowDuplicate: Bool = true) {
    print(formatter.string(from: Date()), file, line, function, message)
}

public struct Log: Sendable {
    public enum Level: String, Sendable {
        /// デバッグ時に使用。サーバへの送信は行わない
        case debug   = "D"
        /// ユーザ操作や重要な処理開始・終了など、特筆すべきこと
        case info    = "I"
        /// 例外発生や想定外の挙動など異常系のログ
        case warning = "W"
        /// アプリがこれ以上実行できなくなる致命的なエラー
        case error   = "E"
    }
}
