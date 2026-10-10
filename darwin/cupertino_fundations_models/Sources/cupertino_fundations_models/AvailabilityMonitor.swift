import Foundation
#if canImport(Observation)
import Observation
#endif

@available(iOS 26.0, macOS 26.0, *)
@MainActor
final class AvailabilityMonitor {
    private let read: () -> [String: Any]
    private let emit: ([String: Any]) -> Void
    private let pollingInterval: TimeInterval?
    private var pollingTask: Task<Void, Never>?
    private var generation = 0
    private var running = false
    private var previous: [String: Any]?

    init(read: @escaping () -> [String: Any], emit: @escaping ([String: Any]) -> Void,
         pollingInterval: TimeInterval? = nil) {
        self.read = read
        self.emit = emit
        self.pollingInterval = pollingInterval
    }

    func start() {
        guard !running else { return }
        running = true
        generation += 1
        refresh(generation: generation)
        if let pollingInterval {
            let expected = generation
            pollingTask = Task { @MainActor [weak self] in
                while !Task.isCancelled {
                    do { try await Task.sleep(nanoseconds: UInt64(pollingInterval * 1_000_000_000)) }
                    catch { return }
                    guard let self else { return }
                    self.refresh(generation: expected)
                }
            }
        }
    }

    func stop() {
        running = false
        generation += 1
        pollingTask?.cancel()
        pollingTask = nil
    }

    private func refresh(generation expected: Int) {
        guard running, generation == expected else { return }
        let snapshot: [String: Any]
        if pollingInterval != nil {
            snapshot = read()
        } else {
            #if canImport(Observation)
            snapshot = withObservationTracking { read() } onChange: { [weak self] in
                Task { @MainActor [weak self] in self?.refresh(generation: expected) }
            }
            #else
            snapshot = read()
            #endif
        }
        if let previous, NSDictionary(dictionary: previous).isEqual(to: snapshot) { return }
        previous = snapshot
        emit(snapshot)
    }
}
