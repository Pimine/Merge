//
// Copyright (c) Vatsal Manot
//

// MARK: - Deprecated

#if os(macOS)

@available(macOS 11.0, *)
@available(iOS, unavailable)
@available(macCatalyst, unavailable)
@available(tvOS, unavailable)
@available(watchOS, unavailable)
@available(*, deprecated, renamed: "SystemShell")
public typealias Shell = SystemShell

#endif
