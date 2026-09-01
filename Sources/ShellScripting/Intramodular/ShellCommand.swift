//
// Copyright (c) Vatsal Manot
//

/// A command that is evaluated by a shell.
///
/// Conforming values retain their domain semantics until the command is
/// composed or executed. This is particularly important for shell builtins,
/// whose effects must be evaluated by the same shell as the command that
/// follows them.
public protocol ShellCommand: CustomStringConvertible, Sendable {
    var shellCommandString: ShellCommandString { get }
}

extension ShellCommand {
    public var description: String {
        shellCommandString.rawValue
    }

    /// Evaluates `command` after this command in the same shell.
    public func followed<Command: ShellCommand>(
        by command: Command
    ) throws -> ShellCommandString {
        let preceding = shellCommandString
        let following = command.shellCommandString

        guard preceding.dialect == following.dialect else {
            throw ShellCommandString.CompositionError.incompatibleDialects(
                preceding: preceding.dialect,
                following: following.dialect
            )
        }

        return ShellCommandString(
            rawValue: "\(preceding.rawValue); \(following.rawValue)",
            dialect: preceding.dialect
        )
    }

    /// Pipes this command's standard output to `command`'s standard input.
    public func piped<Command: ShellCommand>(
        to command: Command
    ) throws -> ShellCommandString {
        let preceding = shellCommandString
        let following = command.shellCommandString

        guard preceding.dialect == following.dialect else {
            throw ShellCommandString.CompositionError.incompatibleDialects(
                preceding: preceding.dialect,
                following: following.dialect
            )
        }

        return ShellCommandString(
            rawValue: "\(preceding.rawValue) | \(following.rawValue)",
            dialect: preceding.dialect
        )
    }
}

extension ShellCommandString: ShellCommand {
    public var shellCommandString: Self {
        self
    }
}
