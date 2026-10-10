import Foundation
import Observation
import XCTest
@testable import CupertinoSchemaContracts

@Observable
private final class AvailabilityState {
    var value = "assetsUnavailable"
}

final class AvailabilityMonitorTests: XCTestCase {
    @MainActor
    func testObservationEmitsInitialChangesAndDeduplicatesEquivalentSnapshots() async throws {
        let state = AvailabilityState()
        var snapshots: [[String: Any]] = []
        var reads = 0
        let monitor = AvailabilityMonitor(read: {
            reads += 1
            let value = state.value
            return ["status": value, "details": ["readiness": value == "available"]]
        }, emit: { snapshots.append($0) })
        monitor.start()
        monitor.start()
        XCTAssertEqual(snapshots.count, 1)
        state.value = "assetsUnavailable"
        try await Task.sleep(nanoseconds: 20_000_000)
        XCTAssertEqual(snapshots.count, 1)
        state.value = "available"
        try await Task.sleep(nanoseconds: 20_000_000)
        XCTAssertEqual(snapshots.map { $0["status"] as! String }, ["assetsUnavailable", "available"])
        XCTAssertGreaterThan(reads, 1)
        monitor.stop()
    }

    @MainActor
    func testStoppingAndRestartingDiscardsQueuedObservationInvalidations() async throws {
        let state = AvailabilityState()
        var values: [String] = []
        let monitor = AvailabilityMonitor(read: { ["status": state.value] }, emit: { values.append($0["status"] as! String) })
        monitor.start()
        state.value = "available"
        monitor.stop()
        monitor.start()
        try await Task.sleep(nanoseconds: 20_000_000)
        XCTAssertEqual(values, ["assetsUnavailable", "available"])
        monitor.stop()
        state.value = "disabled"
        try await Task.sleep(nanoseconds: 20_000_000)
        XCTAssertEqual(values.count, 2)
        monitor.stop()
    }

    @MainActor
    func testReleasedObservationOwnerIsNotRetainedByInvalidationCallbacks() async throws {
        let state = AvailabilityState()
        var calls = 0
        var monitor: AvailabilityMonitor? = AvailabilityMonitor(read: { ["status": state.value] }, emit: { _ in calls += 1 })
        weak var released = monitor
        monitor!.start()
        monitor = nil
        XCTAssertNil(released)
        state.value = "available"
        try await Task.sleep(nanoseconds: 20_000_000)
        XCTAssertEqual(calls, 1)
    }

    @MainActor
    func testExplicitPollingReadsChangesWithoutDuplicateEventsAndStopsImmediately() async throws {
        let firstPoll = expectation(description: "Polling reads the initial state")
        let available = expectation(description: "Polling emits the changed state")
        var state = "assetsUnavailable"
        var reads = 0
        var values: [String] = []
        let monitor = AvailabilityMonitor(read: {
            reads += 1
            if reads == 2 { firstPoll.fulfill() }
            return ["status": state]
        }, emit: {
            let status = $0["status"] as! String
            values.append(status)
            if status == "available" { available.fulfill() }
        }, pollingInterval: 0.005)
        monitor.start()
        await fulfillment(of: [firstPoll], timeout: 2)
        XCTAssertGreaterThan(reads, 1)
        XCTAssertEqual(values.count, 1)
        state = "available"
        await fulfillment(of: [available], timeout: 2)
        XCTAssertEqual(values, ["assetsUnavailable", "available"])
        monitor.stop()
        let count = reads
        try await Task.sleep(nanoseconds: 20_000_000)
        XCTAssertEqual(reads, count)
        monitor.start()
        monitor.stop()
        try await Task.sleep(nanoseconds: 20_000_000)
        XCTAssertEqual(reads, count + 1)
    }

    @MainActor
    func testStopCancelsAnActiveSleepingPollWithoutFurtherReads() async throws {
        let firstPoll = expectation(description: "The polling task has read availability")
        var reads = 0
        let monitor = AvailabilityMonitor(read: {
            reads += 1
            if reads == 2 { firstPoll.fulfill() }
            return ["status": "available"]
        }, emit: { _ in }, pollingInterval: 0.05)
        monitor.start()
        await fulfillment(of: [firstPoll], timeout: 1)
        monitor.stop()
        let stoppedReads = reads
        try await Task.sleep(nanoseconds: 100_000_000)
        XCTAssertEqual(reads, stoppedReads)
    }

    @MainActor
    func testPollingDoesNotRetainAnAbandonedOwner() async throws {
        var monitor: AvailabilityMonitor? = AvailabilityMonitor(read: { ["status": "available"] }, emit: { _ in }, pollingInterval: 0.005)
        weak var released = monitor
        monitor!.start()
        await Task.yield()
        monitor = nil
        XCTAssertNil(released)
        try await Task.sleep(nanoseconds: 20_000_000)
    }
}
