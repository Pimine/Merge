//
// Copyright (c) Vatsal Manot
//

/// A command string together with the shell grammar used to interpret it.
public struct ShellCommandString: CustomStringConvertible, CustomDebugStringConvertible, Hashable, Sendable, ExpressibleByStringLiteral {
    public enum CompositionError: Swift.Error, Hashable, Sendable {
        case incompatibleDialects(
            preceding: ShellDialect,
            following: ShellDialect
        )
    }

    public var rawValue: String
    public var dialect: ShellDialect

    public init(
        rawValue: String,
        dialect: ShellDialect = .posix
    ) {
        self.rawValue = rawValue
        self.dialect = dialect
    }

    public init(
        stringLiteral value: String
    ) {
        self.init(rawValue: value)
    }

    public var description: String {
        rawValue
    }

    public var debugDescription: String {
        "ShellCommandString(rawValue: \(String(reflecting: rawValue)), dialect: \(dialect))"
    }
}
