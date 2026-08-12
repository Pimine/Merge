//
// Copyright (c) Vatsal Manot
//

import Combine
import Diagnostics
import Foundation
import Merge

@available(macOS 11.0, *)
@available(iOS, unavailable)
@available(macCatalyst, unavailable)
@available(tvOS, unavailable)
@available(watchOS, unavailable)
extension AnyCommandLineTool {
    public enum _DeveloperError: Swift.Error, Hashable, CustomStringConvertible {
        case killedInstanceUsage
        case failedToKillShellSessions(failedSessionCount: Int, totalSessionCount: Int)
        case outputFormatterToolAlreadyAttached
        case hostToolAlreadyAttached
        case missingRequiredCommandName(toolType: String)

        public var description: String {
            switch self {
                case .killedInstanceUsage:
                    return "Cannot use an AnyCommandLineTool instance after kill() has been called on it."
                case .failedToKillShellSessions(let failedSessionCount, let totalSessionCount):
                    return "Failed to kill running command-line tool work: \(failedSessionCount) of \(totalSessionCount) tracked shell session(s) remained incomplete after teardown."
                case .outputFormatterToolAlreadyAttached:
                    return "Cannot attach more than one output formatter tool to the same command-line tool serializer state."
                case .hostToolAlreadyAttached:
                    return "Cannot attach more than one host tool to the same command-line tool serializer state."
                case .missingRequiredCommandName(let toolType):
                    return "Cannot render or resolve \(toolType) as a named command-line tool because commandName is nil."
            }
        }
    }

    package enum _LifecycleStatus: Hashable, Sendable {
        case active
        case killed
    }

    package struct _ShellSession: Identifiable, Sendable {
        package typealias ID = UUID

        package let id: ID
        package let shellState: SystemShell._InternalState

        package init(
            id: ID = ID(),
            shellState: SystemShell._InternalState
        ) {
            self.id = id
            self.shellState = shellState
        }
    }

    package actor _InternalState: ObjectDidChangeObservableObject {
        nonisolated package let objectWillChange = ObservableObjectPublisher()
        nonisolated package let objectDidChange = _ObjectDidChangePublisher()

        package private(set) var _lifecycleStatus: _LifecycleStatus = .active
        package private(set) var _shellSessions: IdentifierIndexingArrayOf<_ShellSession> = []

        package init() {

        }

        package func _insertShellSession(
            _ session: AnyCommandLineTool._ShellSession
        ) {
            objectWillChange.send()
            _shellSessions.updateOrAppend(session)
            objectDidChange.send()
        }

        package func _insertShellSessionAfterValidatingUse(
            _ session: AnyCommandLineTool._ShellSession
        ) throws {
            try _validateCanUse()
            _insertShellSession(session)
        }

        package func _completeShellSession(
            id: AnyCommandLineTool._ShellSession.ID
        ) {
            guard _shellSessions[id: id] != nil else {
                return
            }

            objectWillChange.send()
            _shellSessions[id: id] = nil
            objectDidChange.send()
        }

        package func _beginKill() -> [AnyCommandLineTool._ShellSession] {
            let activeShellSessions = Array(_shellSessions)

            if _lifecycleStatus != .killed {
                objectWillChange.send()
                _lifecycleStatus = .killed
                objectDidChange.send()
            }

            return activeShellSessions
        }

        package func _validateCanUse() throws {
            guard _lifecycleStatus != .killed else {
                let error = _DeveloperError.killedInstanceUsage

                runtimeIssue(error)
                throw error
            }
        }
    }

    @available(iOS 16.0, macOS 13.0, tvOS 16.0, watchOS 9.0, *)
    public func kill() async throws {
        let sessions = await _internalState._beginKill()

        var failedSessionCount = 0

        for session in sessions {
            let report = await session.shellState._teardownRunningProcessesReportingForOwningCommandLineTool()

            if !report.fullySucceeded {
                failedSessionCount += 1
            }

            await _internalState._completeShellSession(id: session.id)
        }

        guard failedSessionCount == 0 else {
            throw _DeveloperError.failedToKillShellSessions(
                failedSessionCount: failedSessionCount,
                totalSessionCount: sessions.count
            )
        }
    }
}
