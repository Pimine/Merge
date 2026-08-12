#if os(macOS)

import CommandLineToolSupport
import Foundation

enum CommandLineToolSupportExampleUsage {
    static func swiftBuild() throws -> CommandLineToolInvocation {
        try ExampleSwiftTool()
            .with(\.verbose, true)
            .with(
                \.sdk,
                "/Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX.sdk"
            )
            .build()
            .with(\.configuration, .release)
            .with(\.verbosity, 2)
            .with(\.sandbox, false)
            .with(\.packagePath, "Fixtures/Example Package")
            .with(\.triple, "arm64-apple-macosx15.0")
            .with(\.swiftcOptions, [
                .define("TRACE_IMPORTS"),
                .unsafeFlag("-emit-loaded-module-trace"),
            ])
            .with(\.explicitProducts, ["ExampleCLI", "ExampleSupport"])
            .commandInvocation
    }

    static func gitPush() throws -> CommandLineToolInvocation {
        try ExampleGitTool()
            .with(\.localRepositoryURL, URL(fileURLWithPath: "/tmp/repo"))
            .with(\.tags, true)
            .with(\.force, true)
            .push()
            .commandInvocation
    }

    static func gitRemoteUpdate() throws -> CommandLineToolInvocation {
        try ExampleGitTool()
            .with(\.verbose, true)
            .with(\.prune, true)
            .remote()
            .update()
            .commandInvocation
    }

    static func selectedSwiftCompiler() throws -> CommandLineToolInvocation {
        try ExampleXcrunTool()
            .with(\.sdk, "macosx")
            .swiftc()
            .with(\.typecheck, true)
            .with(\.inputFiles, ["Sources/Example.swift"])
            .commandInvocation
    }

    static func sandboxedSwiftBuild() throws -> CommandLineToolInvocation {
        let swiftBuild = ExampleSwiftTool()
            .build()
            .with(\.configuration, .release)
            .with(\.packagePath, "Fixtures/Example Package")
            .with(\.explicitProducts, ["ExampleCLI"])

        return try ExampleSandboxExecTool()
            .with(\.profileFilePath, "Profiles/no-network.sb")
            .executing(swiftBuild)
            .commandInvocation
    }

    static func documentationForStaticHosting() throws -> CommandLineToolInvocation {
        try ExampleDocumentationCompilerTool()
            .with(\.catalogPath, "Documentation.docc")
            .with(\.outputPath, ".build/site")
            .with(\.transformForStaticHosting, true)
            .with(\.hostingBasePath, "/project")
            .with(\.emitDigest, true)
            .commandInvocation
    }

    static func xcodeTest() throws -> CommandLineToolInvocation {
        try ExampleXcodebuildLikeTool()
            .with(\.scheme, "ExampleApp")
            .with(\.destination, "platform=iOS Simulator,name=iPhone 15")
            .with(\.enableCodeCoverage, .enabled)
            .test()
            .with(\.testPlan, "Smoke")
            .with(\.onlyTesting, ["ExampleAppTests/LoginTests"])
            .with(\.skipTesting, ["ExampleAppTests/SlowTests"])
            .commandInvocation
    }

    static func xcodeArchive() throws -> CommandLineToolInvocation {
        try ExampleXcodebuildLikeTool()
            .with(\.workspace, "ExampleApp.xcworkspace")
            .with(\.scheme, "ExampleApp")
            .with(\.destination, "generic/platform=iOS")
            .with(\.derivedDataPath, ".build/DerivedData")
            .archive()
            .with(\.archivePath, ".build/ExampleApp.xcarchive")
            .with(\.allowProvisioningUpdates, true)
            .commandInvocation
    }

    static func githubRelease() throws -> CommandLineToolInvocation {
        try ExampleGitHubTool()
            .with(\.repository, "PreternaturalAI/ExampleApp")
            .release()
            .create()
            .with(\.tagName, "1.2.0")
            .with(\.title, "ExampleApp 1.2.0")
            .with(\.notesFile, "CHANGELOG.md")
            .with(\.draft, true)
            .with(\.assets, [
                ".build/ExampleApp.zip",
                ".build/ExampleApp.dSYM.zip",
            ])
            .commandInvocation
    }

    static func kubectlUseContext() throws -> CommandLineToolInvocation {
        try ExampleKubectlTool()
            .with(\.kubeconfig, ".kube/config")
            .config()
            .useContext()
            .with(\.contextName, "staging")
            .commandInvocation
    }
}

#endif
