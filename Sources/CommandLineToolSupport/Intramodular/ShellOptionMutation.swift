//
// Copyright (c) Vatsal Manot
//

import ShellScripting

/// A mutation of the current Bourne-style shell's named options.
///
/// Shell options belong to the shell process evaluating a command. Compose a
/// mutation with the command it should affect using ``ShellCommand/followed(by:)``.
@available(macOS 11.0, *)
@available(iOS, unavailable)
@available(macCatalyst, unavailable)
@available(tvOS, unavailable)
@available(watchOS, unavailable)
public struct ShellOptionMutation: ShellBuiltin, Hashable, Sendable {
    /// A named option understood by a Bourne-style shell.
    public struct Option: RawRepresentable, Hashable, Sendable, ExpressibleByStringLiteral {
        public let rawValue: String

        public init(rawValue: String) {
            self.rawValue = rawValue
        }

        public init(stringLiteral value: String) {
            self.init(rawValue: value)
        }

        public static let errexit: Self = "errexit"
        public static let nounset: Self = "nounset"
        public static let pipefail: Self = "pipefail"
        public static let xtrace: Self = "xtrace"
    }

    public enum Operation: Hashable, Sendable {
        case enable
        case disable

        fileprivate var argument: CommandLineToolInvocation.Argument {
            switch self {
                case .enable:
                    "-o"
                case .disable:
                    "+o"
            }
        }
    }

    public let operation: Operation
    public let options: [Option]

    public init(
        enabling option: Option,
        _ additionalOptions: Option...
    ) {
        self.init(operation: .enable, options: [option] + additionalOptions)
    }

    public init(
        disabling option: Option,
        _ additionalOptions: Option...
    ) {
        self.init(operation: .disable, options: [option] + additionalOptions)
    }

    private init(
        operation: Operation,
        options: [Option]
    ) {
        self.operation = operation
        self.options = options.reduce(into: []) { result, option in
            if !result.contains(option) {
                result.append(option)
            }
        }
    }

    public var commandInvocation: CommandLineToolInvocation {
        CommandLineToolInvocation(
            argumentValues: [CommandLineToolInvocation.Argument("set")] + options.flatMap { option in
                [operation.argument, .string(option)]
            }
        )
    }
}

@available(macOS 11.0, *)
@available(iOS, unavailable)
@available(macCatalyst, unavailable)
@available(tvOS, unavailable)
@available(watchOS, unavailable)
extension CLT {
    /// The command-line-tool spelling for a shell option mutation.
    public typealias set = ShellOptionMutation
}
