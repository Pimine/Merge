//
// Copyright (c) Vatsal Manot
//

@testable import Merge

import Combine
import Darwin
import Foundation
import Testing

@Suite(.serialized)
struct _AsyncProcessTests {
    @Test("Captures both standard streams and nonzero termination")
    func capturesStandardStreamsAndTermination() async throws {
        let process = try _AsyncProcess(
            launchPath: "/bin/sh",
            arguments: ["-c", "printf stdout; printf stderr >&2; exit 42"],
            options: []
        )

        do {
            let result = try await process.run()

            #expect(result.stdoutString == "stdout")
            #expect(result.stderrString == "stderr")
            #expect(result.terminationError?.status == 42)
        } catch let error as ProcessTerminationError {
            #expect(error.status == 42)
        }
    }

    @Test("Buffers output larger than a pipe read")
    func buffersLargeOutput() async throws {
        let process = try _AsyncProcess(
            launchPath: "/bin/sh",
            arguments: ["-c", "seq 1 1000"],
            options: []
        )

        let result = try await process.run()

        #expect(result.stdoutString?.hasSuffix("1000") == true)
        #expect((result.stdoutString?.count ?? 0) > 3_000)
    }

    @Test("A completed process returns its recorded result on repeated runs")
    func repeatedRunIsIdempotent() async throws {
        let process = try _AsyncProcess(
            launchPath: "/bin/echo",
            arguments: ["once"],
            options: []
        )

        let first = try await process.run()
        let second = try await process.run()

        #expect(first.stdoutString == "once")
        #expect(second.stdoutString == first.stdoutString)
        #expect(process.state.isTerminated)
        #expect(!process.isRunning)
    }

    @Test("Combined file forwarding preserves captured output")
    func forwardsCombinedOutputToFile() async throws {
        let logFile = temporaryFile(named: "combined.log")
        defer { try? FileManager.default.removeItem(at: logFile.deletingLastPathComponent()) }

        let process = try _AsyncProcess(
            launchPath: "/bin/sh",
            arguments: ["-c", "printf 'stdout-line\\n'; printf 'stderr-line\\n' >&2"],
            options: [._forwardStdoutStderr(to: .file(logFile))]
        )

        let result = try await process.run()
        let forwardedOutput = try String(contentsOf: logFile, encoding: .utf8)

        #expect(result.stdoutString == "stdout-line")
        #expect(result.stderrString == "stderr-line")
        #expect(forwardedOutput.contains("stdout-line"))
        #expect(forwardedOutput.contains("stderr-line"))
    }

    @Test("Split file forwarding does not cross-contaminate streams")
    func forwardsOutputToSeparateFiles() async throws {
        let stdoutFile = temporaryFile(named: "stdout.log")
        let stderrFile = stdoutFile.deletingLastPathComponent().appendingPathComponent("stderr.log")
        defer { try? FileManager.default.removeItem(at: stdoutFile.deletingLastPathComponent()) }

        let process = try _AsyncProcess(
            launchPath: "/bin/sh",
            arguments: ["-c", "printf 'stdout-line\\n'; printf 'stderr-line\\n' >&2"],
            options: [._forwardStdoutStderr(to: .split(stdoutFile.path, err: stderrFile.path))]
        )

        _ = try await process.run()
        let forwardedStdout = try String(contentsOf: stdoutFile, encoding: .utf8)
        let forwardedStderr = try String(contentsOf: stderrFile, encoding: .utf8)

        #expect(forwardedStdout.contains("stdout-line"))
        #expect(!forwardedStdout.contains("stderr-line"))
        #expect(forwardedStderr.contains("stderr-line"))
        #expect(!forwardedStderr.contains("stdout-line"))
    }

    @Test("Concurrent processes keep their standard streams isolated")
    func concurrentProcessesKeepStreamsIsolated() async throws {
        for round in 0..<4 {
            let processes = try (1...32).map { index in
                let identifier = round * 32 + index
                return try _AsyncProcess(
                    launchPath: "/bin/sh",
                    arguments: [
                        "-c",
                        "printf 'stdout-\(identifier)'; printf 'stderr-\(identifier)' >&2",
                    ],
                    options: []
                )
            }

            let results = try await withThrowingTaskGroup(of: _ProcessRunResult.self) { group in
                for process in processes {
                    group.addTask { try await process.run() }
                }
                return try await group.reduce(into: []) { $0.append($1) }
            }

            #expect(results.count == processes.count)
            for result in results {
                let identifier = result.stdoutString?.dropFirst("stdout-".count)
                #expect(identifier != nil)
                #expect(result.stderrString == "stderr-\(identifier ?? "")")
            }
        }
    }

    @Test("Cancelling a run terminates descendants holding output pipes")
    func cancellationTerminatesPipeHoldingDescendant() async throws {
        let pidURL = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("merge-async-process-child-\(UUID().uuidString).pid")
        defer { try? FileManager.default.removeItem(at: pidURL) }

        let process = try _AsyncProcess(
            launchPath: "/bin/sh",
            arguments: [
                "-c",
                "sleep 30 & child=$!; printf '%s' \"$child\" > \"$1\"; wait",
                "sh",
                pidURL.path,
            ],
            options: []
        )
        let runTask = Task { try await process.run() }

        var childPID: pid_t?
        for _ in 0..<100 {
            if let value = try? String(contentsOf: pidURL, encoding: .utf8),
               let parsed = pid_t(value),
               parsed > 1 {
                childPID = parsed
                break
            }
            try await Task.sleep(for: .milliseconds(10))
        }

        let pid = try #require(childPID)
        runTask.cancel()
        _ = try? await runTask.value

        var childExited = false
        for _ in 0..<100 {
            if kill(pid, 0) == -1, errno == ESRCH {
                childExited = true
                break
            }
            try await Task.sleep(for: .milliseconds(10))
        }

        #expect(childExited)
        #expect(!process.isRunning)
    }

    @Test("Configured teardown terminates a running process")
    func configuredTeardownTerminatesRunningProcess() async throws {
        let process = try _AsyncProcess(
            launchPath: "/bin/sh",
            arguments: ["-c", "trap 'echo terminated; exit 0' TERM; while true; do sleep 0.01; done"],
            options: [._teardown([.terminate(allowedDurationToNextStep: .milliseconds(100))])]
        )
        let task = Task { try await process.run() }

        while !process.isRunning {
            try await Task.sleep(.milliseconds(10))
        }
        await process.teardown(using: process.teardownSequence)

        let result = try await task.value
        #expect(result.stdoutString == "terminated")
        #expect(result.terminationStatus.isSuccess)
    }

    @Test("Repeated launch failures do not leak process registrations")
    func launchFailuresDoNotLeakRegistryEntries() async throws {
        let initialCount = _AsyncProcess.$runningProcesses.withCriticalRegion(\.count)

        for _ in 0..<10 {
            let process = try _AsyncProcess(
                executableURL: URL(fileURLWithPath: "/definitely/not/a/real/executable"),
                arguments: [],
                environment: nil,
                currentDirectoryURL: nil,
                options: []
            )

            await #expect(throws: (any Error).self) {
                try await process.run()
            }
            #expect(_AsyncProcess.$runningProcesses.withCriticalRegion(\.count) == initialCount)
        }
    }

    @Test("Repeated successful processes do not leak process registrations")
    func successfulProcessesDoNotLeakRegistryEntries() async throws {
        let initialCount = _AsyncProcess.$runningProcesses.withCriticalRegion(\.count)

        for index in 0..<10 {
            let process = try _AsyncProcess(
                launchPath: "/bin/echo",
                arguments: ["cleanup-\(index)"],
                options: []
            )

            let result = try await process.run()
            #expect(result.stdoutString == "cleanup-\(index)")
            #expect(_AsyncProcess.$runningProcesses.withCriticalRegion(\.count) == initialCount)
        }
    }

    @Test("Termination is harmless outside the running state")
    func terminationIsHarmlessOutsideRunningState() async throws {
        let initialCount = _AsyncProcess.$runningProcesses.withCriticalRegion(\.count)
        let process = try _AsyncProcess(
            launchPath: "/bin/echo",
            arguments: ["termination"],
            options: []
        )

        try await process.terminate()
        #expect(process.state == .notLaunch)

        _ = try await process.run()
        try await process.terminate()
        #expect(process.state.isTerminated)
        #expect(_AsyncProcess.$runningProcesses.withCriticalRegion(\.count) == initialCount)
    }

    @Test("Launch configuration reaches the child process")
    func appliesEnvironmentAndWorkingDirectory() async throws {
        let directoryURL = URL(fileURLWithPath: NSTemporaryDirectory()).standardizedFileURL
        let process = try _AsyncProcess(
            executableURL: URL(fileURLWithPath: "/bin/sh"),
            arguments: ["-c", "printf '%s|%s' \"$TEST_VALUE\" \"$PWD\""],
            environment: ["TEST_VALUE": "configured"],
            currentDirectoryURL: directoryURL,
            options: []
        )

        let result = try await process.run()

        #expect(result.stdoutString?.hasPrefix("configured|") == true)
        #expect(result.stdoutString?.hasSuffix(directoryURL.path) == true)
    }

    @Test("Standard-output publisher observes process output")
    func publishesStandardOutput() async throws {
        let process = try _AsyncProcess(
            launchPath: "/bin/echo",
            arguments: ["publisher test"],
            options: []
        )
        var receivedData: [Data] = []
        let cancellable = process._standardOutputPublisher().sink { receivedData.append($0) }

        _ = try await process.run()
        try await Task.sleep(.milliseconds(100))

        let output = String(data: receivedData.reduce(Data(), +), encoding: .utf8)
        #expect(output?.contains("publisher test") == true)
        cancellable.cancel()
    }

    private func temporaryFile(named name: String) -> URL {
        URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("merge-async-process-tests-\(UUID().uuidString)", isDirectory: true)
            .appendingPathComponent(name)
    }
}
