import Foundation

/// AsyncStreamを複数購読できるようにするactor
public actor MultiStream<T: Sendable> {
    private var continuations: [UUID: AsyncStream<T>.Continuation] = [:]
    private let bufferingPolicy: AsyncStream<T>.Continuation.BufferingPolicy

    public init(bufferingPolicy: AsyncStream<T>.Continuation.BufferingPolicy = .unbounded) {
        self.bufferingPolicy = bufferingPolicy
    }

    public func subscribe() -> AsyncStream<T> {
        let id = UUID()
        let (stream, continuation) = AsyncStream<T>.makeStream(bufferingPolicy: bufferingPolicy)
        continuations[id] = continuation

        continuation.onTermination = { [weak self] _ in
            guard let self else { return }
            Task { await self.removeContinuation(id) }
        }

        return stream
    }

    private func removeContinuation(_ id: UUID) {
        continuations.removeValue(forKey: id)
    }

    /// すべての購読者に対して値を配信します
    public nonisolated func publish(_ value: T) {
        Task {
            await continuations.values.forEach {
                $0.yield(value)
            }
        }
    }

    public func finish() {
        continuations.values.forEach { $0.finish() }
        continuations.removeAll()
    }
}
