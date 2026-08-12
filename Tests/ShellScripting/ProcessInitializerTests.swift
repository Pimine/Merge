//
// Copyright (c) Vatsal Manot
//

@testable import ShellScripting

import Foundation
import Testing

@Suite
struct ShellProcessTests {
    @Test
    func testPreferredUNIXShellName() {
        let bashCommand = "echo 'Hello, World!'"
        let zshCommand = "ls -l"
        let noShellCommand = "/bin/ls"

        let bashProcess = Process(command: bashCommand, shell: .bash)
        let zshProcess = Process(command: zshCommand, shell: .zsh)
        let noShellProcess = Process(command: noShellCommand, shell: .none)

        #expect(bashProcess.executableURL!.path == "/bin/bash")
        #expect(bashProcess.arguments == ["-l", "-c", bashCommand])

        #expect(zshProcess.executableURL!.path == "/bin/zsh")
        #expect(zshProcess.arguments == ["-l", "-c", zshCommand])

        #expect(noShellProcess.executableURL!.path == noShellCommand)
        #expect(noShellProcess.arguments == [])
    }

    @Test
    func testArgumentEscaping() {
        let plainArgument = Process.ArgumentLiteral("Hello")
        let quotedArgument = Process.ArgumentLiteral("Hello, World!", isQuoted: true)
        let nestedQuotesArgument = Process.ArgumentLiteral("echo \"John said, 'Hello'\"", isQuoted: true)

        #expect(plainArgument.rawValue == "Hello")
        #expect(plainArgument.posixShellEscapedValue == "Hello")
        #expect(quotedArgument.posixShellEscapedValue == "\"Hello, World!\"")
        #expect(nestedQuotesArgument.posixShellEscapedValue == "\"echo \\\"John said, 'Hello'\\\"\"")
    }

    @Test
    func testArgumentLiteralRawBytesCanRepresentNonUTF8Values() {
        let argument = Process.ArgumentLiteral(rawBytes: [0xff])

        #expect(argument.stringValue == nil)
        #expect(argument.rawBytes == [0xff])
    }

    @Test
    func testSystemShellRunCommandForwardsInterpreter() async throws {
        let shell = SystemShell()
        let interpreter = SystemShell.Environment(
            launchPath: "/bin/sh",
            deriveArguments: { _ in ["-c", "printf forwarded-interpreter"] }
        )

        let result = try await shell.run(
            command: "printf wrong-interpreter",
            interpreter: interpreter
        )

        #expect(result.stdoutString == "forwarded-interpreter")
    }

    @Test
    func testArgumentLiteralURLRepresentation() {
        let url = URL(fileURLWithPath: "/tmp/Some File")

        #expect(Process.ArgumentLiteral(url).rawValue == "/tmp/Some File")
        #expect(Process.ArgumentLiteral(url, representation: .absoluteString).rawValue == "file:///tmp/Some%20File")
    }

    @Test
    func testSplitArgumentsWithMixedContent() {
        let command = "run --path=\"/Applications/My App.app\" --quiet"
        let result = Process.splitArguments(command)

        #expect(result == ["run", "--path=\"/Applications/My App.app\"", "--quiet"])
    }

}
