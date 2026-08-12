//
// Copyright (c) Vatsal Manot
//

import Combine
import Foundation
import Swallow

@available(macOS 11.0, *)
@available(iOS, unavailable)
@available(macCatalyst, unavailable)
@available(tvOS, unavailable)
@available(watchOS, unavailable)
extension SystemShell {
    package var runningProcesses: [_AsyncProcess] {
        get async {
            await _internalState.runningProcesses
        }
    }

    @available(iOS 16.0, macOS 13.0, tvOS 16.0, watchOS 9.0, *)
    package func teardownRunningProcesses() async throws {
        _ = try await teardownRunningProcessesReporting()
    }

    package func _run(
        _ process: _AsyncProcess
    ) async throws -> _ProcessRunResult {
        await _internalState.insertRunningProcess(process)

        do {
            let result = try await process.run()

            await _internalState.removeRunningProcess(process)

            return result
        } catch {
            await _internalState.removeRunningProcess(process)

            throw error
        }
    }
}

@available(macOS 11.0, *)
@available(iOS, unavailable)
@available(macCatalyst, unavailable)
@available(tvOS, unavailable)
@available(watchOS, unavailable)
extension SystemShell {
    package actor _InternalState: ObjectDidChangeObservableObject {
        nonisolated package let objectWillChange = ObservableObjectPublisher()
        nonisolated package let objectDidChange = _ObjectDidChangePublisher()

        package private(set) var runningProcesses: [_AsyncProcess] = []

        package init() {

        }

        package func insertRunningProcess(
            _ process: _AsyncProcess
        ) {
            guard !runningProcesses.contains(where: { $0 === process }) else {
                return
            }

            objectWillChange.send()
            runningProcesses.append(process)
            objectDidChange.send()
        }

        package func removeRunningProcess(
            _ process: _AsyncProcess
        ) {
            guard runningProcesses.contains(where: { $0 === process }) else {
                return
            }

            objectWillChange.send()
            runningProcesses.removeAll(where: { $0 === process })
            objectDidChange.send()
        }
    }

    package struct OwnershipError: Swift.Error, Hashable, CustomStringConvertible {
        package let reason: String

        package var description: String {
            reason
        }
    }
}
