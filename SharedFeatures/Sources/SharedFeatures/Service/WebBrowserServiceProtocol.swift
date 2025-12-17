//
//  WebBrowserServiceProtocol.swift
//  SharedFeatures
//
//  Platform-agnostic web browser service protocol.
//  Implementations are provided by each app target.
//

import ComposableArchitecture
import Foundation

// MARK: - WebBrowserOptions

/// Options for configuring the web browser presentation
public struct WebBrowserOptions: Sendable {
    public var readerMode: Bool
    public var enableBarCollapsing: Bool
    public var dismissButtonStyle: DismissButtonStyle
    public var presentationStyle: PresentationStyle

    public init(
        readerMode: Bool = false,
        enableBarCollapsing: Bool = false,
        dismissButtonStyle: DismissButtonStyle = .done,
        presentationStyle: PresentationStyle = .overFullScreen
    ) {
        self.readerMode = readerMode
        self.enableBarCollapsing = enableBarCollapsing
        self.dismissButtonStyle = dismissButtonStyle
        self.presentationStyle = presentationStyle
    }
}

// MARK: - DismissButtonStyle

public enum DismissButtonStyle: String, Sendable {
    case done
    case close
    case cancel
}

// MARK: - PresentationStyle

public enum PresentationStyle: String, Sendable {
    case fullScreen
    case pageSheet
    case formSheet
    case currentContext
    case overFullScreen
    case overCurrentContext
    case popover
    case none
    case automatic
}

// MARK: - WebBrowserErrors

public enum WebBrowserErrors: Error {
    case alreadyOpen
    case invalidURL
    case notSupported
}

// MARK: - WebBrowserService

/// Platform-agnostic web browser service.
/// Uses a struct with closures for easy dependency injection.
public struct WebBrowserService: Sendable {
    public var open: @Sendable (URL, WebBrowserOptions?) async throws -> Void

    public init(open: @escaping @Sendable (URL, WebBrowserOptions?) async throws -> Void) {
        self.open = open
    }
}

// MARK: - TestDependencyKey

extension WebBrowserService: TestDependencyKey {
    public static var testValue: WebBrowserService {
        WebBrowserService { _, _ in
            // No-op for tests
        }
    }
}

public extension DependencyValues {
    var webBrowserService: WebBrowserService {
        get { self[WebBrowserService.self] }
        set { self[WebBrowserService.self] = newValue }
    }
}

