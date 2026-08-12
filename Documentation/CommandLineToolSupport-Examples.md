# CommandLineToolSupport Examples

The examples in `Examples/CommandLineToolSupport` demonstrate how to model existing command-line tools in Swift. They live in the dedicated `CommandLineToolSupportExamples` target and are dependencies of the command-line support test target. Consequently, every `swift test` compile-checks them without pretending that declarations alone are behavioral tests.

## Examples

- `ExampleUsage.swift` contains compile-checked call sites that configure, compose, select, and resolve representative tools.
- `ExampleSwiftTool.swift` is the broad baseline: parent-local options, subcommands, inverted and counted flags, option separators, repeated single-value options, typed values, and positional operands.
- `ExampleGitTool.swift` demonstrates parent and final-command placement, optional inversion, nested subcommands, URL values, and typed option values.
- `ExampleGitHubReleaseTool.swift` demonstrates deeply nested subcommands and conditional argument selection for release notes.
- `ExampleXcrunTool.swift` demonstrates selected-tool hosting, including a selected tool with its own subcommands.
- `ExampleXcodebuildInvocationSummaryTool.swift` demonstrates advanced invocation summaries, inherited parent arguments, conditional applicability, and post-resolution rewrite rules.
- `ExampleDocumentationCompilerTool.swift` demonstrates operation-dependent argument ordering with `Switch`, `Case`, `DefaultCase`, and `When`.
- `ExampleInvocationSummaryApplicabilityContrastTool.swift` contrasts explicit summary nodes with modifier-based omission and unavailability.
- `ExampleStatefulCommandTools.swift` models tools whose arguments form mutually exclusive operational modes.
- `ExamplePlainSubcommandTool.swift` demonstrates subcommand declarations whose nested tools rely on synthesized conformance.
- `ExampleSandboxExecTool.swift` demonstrates a trailing arbitrary argument vector and composing one modeled tool inside another.
- `ExampleXcbeautifyTool.swift` demonstrates the output-formatter tool protocol.

These are illustrative declarations rather than fake tests. Behavioral coverage belongs in `Tests/CommandLineSupport`; example coverage belongs here.
