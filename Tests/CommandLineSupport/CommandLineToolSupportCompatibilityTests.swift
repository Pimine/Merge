#if os(macOS)

import CommandLineToolSupport
import Foundation
import Merge
import ShellScripting
import Testing

final class LegacyAnyCommandLineToolCompatibilityTool: AnyCommandLineTool {
    override var commandName: CommandLineTool.Name? {
        "legacy-any-command-line-tool"
    }
}

final class EnvironmentOverrideCompatibilityTool: AnyCommandLineTool, CommandLineTool {
    override var commandName: CommandLineTool.Name? {
        "env"
    }

    @CLT.EnvironmentVariable(name: "MERGE_COMMAND_LINE_TOOL_TEST_VALUE")
    var modeledValue = "modeled"
}

@Suite
struct CommandLineToolSupportCompatibilityTests {
    @Test("Explicit environment configuration overrides modeled values")
    func explicitEnvironmentConfigurationOverridesModeledValues() async throws {
        let tool = EnvironmentOverrideCompatibilityTool()
        tool.environmentVariables["MERGE_COMMAND_LINE_TOOL_TEST_VALUE"] = "configured"

        let record = try await tool._runCollectingOutput()

        #expect(try record.lines.contains("MERGE_COMMAND_LINE_TOOL_TEST_VALUE=configured"))
    }

    @Test("AnyCommandLineTool _run(command:) records shell command lines")
    func anyCommandLineToolRunCommandRecordsShellCommandLine() async throws {
        let tool = LegacyAnyCommandLineToolCompatibilityTool()
        let record = try await tool._run(
            command: "printf raw-shell",
            applying: .standardStreamMirroring(.disabled)
        )

        guard case .shellCommandString(let commandString) = record.source else {
            Issue.record("Expected AnyCommandLineTool._run(command:) to record a shell command string.")
            return
        }

        #expect(commandString.rawValue == "printf raw-shell")
        #expect(commandString.dialect == .posix)
        #expect(record.tool === tool)
        #expect(record.invocation == nil)
        #expect(record.shellCommandString == commandString)
        #expect(record.commandLine == commandString.rawValue)
        #expect(record.stdoutString == "raw-shell")
    }

    @Test("AnyCommandLineTool _run(command:) applies scoped SystemShell configuration")
    func anyCommandLineToolRunCommandAppliesScopedSystemShellConfiguration() async throws {
        let directoryURL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
            .appendingPathComponent(".build", isDirectory: true)
            .appendingPathComponent(
                "merge-command-line-tool-run-\(UUID().uuidString)",
                isDirectory: true
            )

        try FileManager.default.createDirectory(
            at: directoryURL,
            withIntermediateDirectories: true
        )
        defer {
            try? FileManager.default.removeItem(at: directoryURL)
        }

        let record = try await LegacyAnyCommandLineToolCompatibilityTool()._run(
            command: "pwd",
            applying: .currentDirectoryURL(directoryURL),
            .standardStreamMirroring(.disabled)
        )

        #expect(record.commandLine == "pwd")
        #expect(record.stdoutString == directoryURL.path)
    }

    @Test("Borrowed SystemShell rejects owned process teardown")
    func borrowedSystemShellRejectsOwnedProcessTeardown() async throws {
        do {
            try await LegacyAnyCommandLineToolCompatibilityTool().withSystemShell { shell in
                try await shell.teardownRunningProcesses()
            }

            Issue.record("Expected borrowed SystemShell teardown to fail.")
        } catch SystemShell._DeveloperError.borrowedShellOwnedOperation(let operation) {
            #expect(operation == .teardownRunningProcesses)
        } catch {
            Issue.record("Expected borrowedShellOwnedOperation, got \(error).")
            #expect(
                String(describing: error).contains("withSystemShell"),
                "The teardown failure should call out the borrowed-shell API boundary."
            )
        }
    }

    @Test("Borrowed SystemShell kill is an owned operation")
    func borrowedSystemShellKillIsAnOwnedOperation() async throws {
        do {
            try await LegacyAnyCommandLineToolCompatibilityTool().withSystemShell { shell in
                try shell._validateCanAttemptOwnedShellOperation(.kill)
            }

            Issue.record("Expected borrowed SystemShell kill ownership check to fail.")
        } catch SystemShell._DeveloperError.borrowedShellOwnedOperation(let operation) {
            #expect(operation == .kill)
        } catch {
            Issue.record("Expected borrowedShellOwnedOperation, got \(error).")
            #expect(
                String(describing: error).contains("withSystemShell"),
                "The kill ownership failure should call out the borrowed-shell API boundary."
            )
        }
    }

    @Test("Borrowed SystemShell rejects use after withSystemShell returns")
    func borrowedSystemShellRejectsUseAfterClosureReturns() async throws {
        var escapedShell: SystemShell?

        try await LegacyAnyCommandLineToolCompatibilityTool().withSystemShell { shell in
            escapedShell = shell
        }

        do {
            _ = try await escapedShell?.run(command: "echo leaked")

            Issue.record("Expected escaped borrowed SystemShell use to fail.")
        } catch SystemShell._DeveloperError.invalidBorrowedShellLease {
        } catch {
            Issue.record("Expected invalidBorrowedShellLease, got \(error).")
        }
    }

    @Test("Sink wrapper uses scoped SystemShell configuration")
    func sinkWrapperUsesScopedConfiguration() async throws {
        let result = try await LegacyAnyCommandLineToolCompatibilityTool().withSystemShell(sink: .null) { shell in
            try await shell.run(command: "echo captured")
        }

        #expect(
            result.stdoutString == "captured",
            "The legacy .null sink should disable mirroring while preserving captured stdout."
        )
    }

    @Test("Killing an AnyCommandLineTool with no active shells makes the instance unusable")
    func killingAnyCommandLineToolWithNoActiveShellsMakesInstanceUnusable() async throws {
        let tool = LegacyAnyCommandLineToolCompatibilityTool()

        try await tool.kill()

        #expect(await tool._internalState._lifecycleStatus == .killed)

        do {
            try await tool.withSystemShell { _ in

            }

            Issue.record("Expected killed AnyCommandLineTool instance usage to fail.")
        } catch AnyCommandLineTool._DeveloperError.killedInstanceUsage {
        } catch {
            Issue.record("Expected killedInstanceUsage, got \(error).")
        }
    }

    @Test("Killing an AnyCommandLineTool tears down active borrowed shell sessions")
    func killingAnyCommandLineToolTearsDownActiveBorrowedShellSessions() async throws {
        let tool = LegacyAnyCommandLineToolCompatibilityTool()
        var shellState: SystemShell._InternalState?

        let task = Task {
            try await tool.withSystemShell { shell in
                shellState = shell._internalState

                _ = try await shell.run(command: "trap 'exit 0' TERM; while true; do sleep 1; done")
            }
        }

        while shellState == nil {
            try await Task.sleep(.milliseconds(10))
        }

        while await shellState?.runningProcesses.isEmpty != false {
            try await Task.sleep(.milliseconds(10))
        }

        try await tool.kill()

        _ = try await task.value

        #expect(await tool._internalState._lifecycleStatus == .killed)
        #expect(await shellState?.runningProcesses.isEmpty == true)
    }
}

#endif
