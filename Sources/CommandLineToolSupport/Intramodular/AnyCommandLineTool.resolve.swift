//
// Copyright (c) Vatsal Manot
//

import Foundation
import Swallow

@available(macOS 11.0, *)
@available(iOS, unavailable)
@available(macCatalyst, unavailable)
@available(tvOS, unavailable)
@available(watchOS, unavailable)
extension AnyCommandLineTool {
    package func _defaultInvocationComponents(
        context: CommandLineToolInvocationSummary.InvocationSummaryContext,
        positions: Set<_CommandLineToolArgumentPosition.Anchor>
    ) throws -> [CommandLineToolInvocation.Component] {
        try resolve().arguments
            .filter {
                positions.contains($0.defaultPosition.anchor)
            }
            .filter {
                !context.argumentIsHandled(command: self, argumentName: $0.id.rawValue)
            }
            .flatMap { argument -> [CommandLineToolInvocation.Component] in
                let components = argument.publicInvocationComponents
                let shouldRender = try context.registerHandledArgument(
                    command: self,
                    argumentName: argument.id.rawValue,
                    disposition: .defaultRender,
                    defaultPosition: argument.defaultPosition,
                    components: components
                )

                return shouldRender ? components : []
            }
    }

    public func resolve() throws -> _ResolvedCommandLineToolDescription {
        try _CommandLineToolReflectionResolver(tool: self).resolve()
    }
}
