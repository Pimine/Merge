//
// Copyright (c) Vatsal Manot
//

import ShellScripting

/// A command implemented by the current shell rather than an executable.
///
/// A builtin is represented by the same structured invocation model as a
/// command-line tool, but is rendered as a ``ShellCommand`` so it can be
/// composed with the command whose shell state it affects.
@available(macOS 11.0, *)
@available(iOS, unavailable)
@available(macCatalyst, unavailable)
@available(tvOS, unavailable)
@available(watchOS, unavailable)
public protocol ShellBuiltin: ShellCommand {
    var commandInvocation: CommandLineToolInvocation { get }
}

@available(macOS 11.0, *)
@available(iOS, unavailable)
@available(macCatalyst, unavailable)
@available(tvOS, unavailable)
@available(watchOS, unavailable)
extension ShellBuiltin {
    public var shellCommandString: ShellCommandString {
        commandInvocation.renderedShellCommandString(using: .posixShellCommandLine)
    }
}
