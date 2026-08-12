//
// Copyright (c) Vatsal Manot
//


import Foundation
import Merge
import ShellScripting

@available(macOS 11.0, *)
@available(iOS, unavailable)
@available(macCatalyst, unavailable)
@available(tvOS, unavailable)
@available(watchOS, unavailable)
extension CommandLineTool {
    @discardableResult
    public func _run(
        invocation: CommandLineToolInvocation,
        applying differences: [SystemShell.Configuration.Difference] = []
    ) async throws -> _CommandLineToolExecutionRecord<Self> {
        try await _executionPlan(
            invocation: invocation,
            applying: differences
        )
        ._run()
    }
    
    @available(iOS 16.0, macOS 13.0, tvOS 16.0, watchOS 9.0, *)
    @discardableResult
    public func _run(
        applying differences: [SystemShell.Configuration.Difference] = []
    ) async throws -> _CommandLineToolExecutionRecord<Self> {
        try await _run(
            invocation: try commandInvocation,
            applying: differences
        )
    }
    
    /// Returns this tool's modeled invocation with the supplied arguments added
    /// after its declared arguments.
    @available(iOS 16.0, macOS 13.0, tvOS 16.0, watchOS 9.0, *)
    public func _invocation(
        additionalArguments: CommandLineToolInvocation.Arguments
    ) throws -> CommandLineToolInvocation {
        try commandInvocation.appending(arguments: additionalArguments)
    }
    
    /// Runs this tool with arguments added after its declared arguments.
    @available(iOS 16.0, macOS 13.0, tvOS 16.0, watchOS 9.0, *)
    @discardableResult
    public func _run(
        additionalArguments: CommandLineToolInvocation.Arguments,
        applying differences: [SystemShell.Configuration.Difference] = []
    ) async throws -> _CommandLineToolExecutionRecord<Self> {
        try await _run(
            invocation: try _invocation(additionalArguments: additionalArguments),
            applying: differences
        )
    }

    @available(iOS 16.0, macOS 13.0, tvOS 16.0, watchOS 9.0, *)
    @_disfavoredOverload
    @discardableResult
    public func _run(
        additionalArguments: [String],
        applying differences: [SystemShell.Configuration.Difference] = []
    ) async throws -> _CommandLineToolExecutionRecord<Self> {
        try await _run(
            additionalArguments: CommandLineToolInvocation.Arguments(additionalArguments),
            applying: differences
        )
    }
    
    /// Runs this tool with additional arguments while capturing its standard
    /// output and standard error.
    @available(iOS 16.0, macOS 13.0, tvOS 16.0, watchOS 9.0, *)
    @discardableResult
    public func _runCollectingOutput(
        additionalArguments: CommandLineToolInvocation.Arguments = [],
        applying differences: [SystemShell.Configuration.Difference] = []
    ) async throws -> _CommandLineToolExecutionRecord<Self> {
        try await _run(
            additionalArguments: additionalArguments,
            applying: differences + [._collectingOutput]
        )
    }

    @available(iOS 16.0, macOS 13.0, tvOS 16.0, watchOS 9.0, *)
    @_disfavoredOverload
    @discardableResult
    public func _runCollectingOutput(
        additionalArguments: [String],
        applying differences: [SystemShell.Configuration.Difference] = []
    ) async throws -> _CommandLineToolExecutionRecord<Self> {
        try await _runCollectingOutput(
            additionalArguments: CommandLineToolInvocation.Arguments(additionalArguments),
            applying: differences
        )
    }
    
    @discardableResult
    public func _run(
        command commandString: _ShellCommandString,
        input: String? = nil,
        applying differences: [SystemShell.Configuration.Difference] = []
    ) async throws -> _CommandLineToolExecutionRecord<Self> {
        let record: _CommandLineToolExecutionRecord<AnyCommandLineTool> = try await (self as AnyCommandLineTool)._run(
            command: commandString,
            input: input,
            applying: differences
        )
        
        return _CommandLineToolExecutionRecord(
            tool: self,
            source: record.source,
            processResult: record.processResult,
            selectedToolInvocation: record.selectedToolInvocation
        )
    }
    
    @discardableResult
    public func _run(
        command commandLine: String,
        input: String? = nil,
        applying differences: [SystemShell.Configuration.Difference] = []
    ) async throws -> _CommandLineToolExecutionRecord<Self> {
        try await _run(
            command: _ShellCommandString(rawValue: commandLine),
            input: input,
            applying: differences
        )
    }
    
}
