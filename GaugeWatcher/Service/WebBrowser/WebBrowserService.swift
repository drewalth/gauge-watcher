//
//  WebBrowserService.swift
//  GaugeWatcher
//
//  Created by Andrew Althage on 11/25/25.
//

import ComposableArchitecture
import SafariServices
import SharedFeatures
import UIKit

// MARK: - SharedFeatures.WebBrowserService + DependencyKey

extension SharedFeatures.WebBrowserService: DependencyKey {
    public static let liveValue = SharedFeatures.WebBrowserService { url, options in
        await MainActor.run {
            let browserModule = WebBrowserModule()
            let opts = options ?? SharedFeatures.WebBrowserOptions()
            Task {
                try await browserModule.openBrowserAsync(url: url, options: opts)
            }
        }
    }
}

// MARK: - WebBrowserSession

@MainActor
class WebBrowserSession: NSObject, SFSafariViewControllerDelegate, UIAdaptivePresentationControllerDelegate {

    // MARK: Lifecycle

    init(
        url: URL,
        options: SharedFeatures.WebBrowserOptions,
        onDismiss: @escaping (String) -> Void,
        didPresent: @escaping () -> Void) {
        self.onDismiss = onDismiss
        self.didPresent = didPresent

        let configuration = SFSafariViewController.Configuration()
        configuration.barCollapsingEnabled = options.enableBarCollapsing
        configuration.entersReaderIfAvailable = options.readerMode

        viewController = SFSafariViewController(url: url, configuration: configuration)
        viewController.modalPresentationStyle = options.presentationStyle.toUIKit()
        viewController.dismissButtonStyle = options.dismissButtonStyle.toSafari()

        super.init()
        viewController.delegate = self
        viewController.presentationController?.delegate = self
    }

    // MARK: Public

    // MARK: - SFSafariViewControllerDelegate

    nonisolated public func safariViewControllerDidFinish(_: SFSafariViewController) {
        Task { @MainActor in
            self.finish(type: "cancel")
        }
    }

    // MARK: - UIAdaptivePresentationControllerDelegate

    nonisolated public func presentationControllerDidDismiss(_: UIPresentationController) {
        Task { @MainActor in
            self.finish(type: "cancel")
        }
    }

    // MARK: Internal

    let viewController: SFSafariViewController
    let onDismiss: (String) -> Void
    let didPresent: () -> Void

    func open() {
        guard
            let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
            let window = windowScene.windows.first
        else { return }

        var currentViewController = window.rootViewController
        while currentViewController?.presentedViewController != nil {
            currentViewController = currentViewController?.presentedViewController
        }
        if UIDevice.current.userInterfaceIdiom == .pad {
            let viewFrame = currentViewController?.view.frame
            viewController.popoverPresentationController?.sourceRect = CGRect(
                x: viewFrame?.midX ?? 0,
                y: viewFrame?.maxY ?? 0,
                width: 0,
                height: 0)
            viewController.popoverPresentationController?.sourceView = currentViewController?.view
        }

        currentViewController?.present(viewController, animated: true) {
            self.didPresent()
        }
    }

    func dismiss(completion: ((String) -> Void)? = nil) {
        viewController.dismiss(animated: true) {
            let type = "dismiss"
            self.finish(type: type)
            completion?(type)
        }
    }

    // MARK: Private

    private func finish(type: String) {
        onDismiss(type)
    }
}

// MARK: - WebBrowserModule

@MainActor
class WebBrowserModule {

    // MARK: Lifecycle

    init(currentWebBrowserSession: WebBrowserSession? = nil, vcDidPresent: Bool = false) {
        self.currentWebBrowserSession = currentWebBrowserSession
        self.vcDidPresent = vcDidPresent
    }

    // MARK: Internal

    func openBrowserAsync(url: URL, options: SharedFeatures.WebBrowserOptions = .init()) async throws {
        if vcDidPresent {
            currentWebBrowserSession = nil
            vcDidPresent = false
        }

        guard isValid(url: url) else {
            throw SharedFeatures.WebBrowserErrors.invalidURL
        }

        currentWebBrowserSession = WebBrowserSession(url: url, options: options) { _ in
            self.currentWebBrowserSession = nil
        } didPresent: {
            self.vcDidPresent = true
        }

        currentWebBrowserSession?.open()
    }

    // MARK: Private

    private var currentWebBrowserSession: WebBrowserSession?
    private var vcDidPresent = false

    private func isValid(url: URL) -> Bool {
        url.scheme == "http" || url.scheme == "https"
    }
}

// MARK: - Style Conversions

extension SharedFeatures.DismissButtonStyle {
    func toSafari() -> SFSafariViewController.DismissButtonStyle {
        switch self {
        case .done: .done
        case .close: .close
        case .cancel: .cancel
        }
    }
}

extension SharedFeatures.PresentationStyle {
    func toUIKit() -> UIModalPresentationStyle {
        switch self {
        case .fullScreen: .fullScreen
        case .pageSheet: .pageSheet
        case .formSheet: .formSheet
        case .currentContext: .currentContext
        case .overFullScreen: .overFullScreen
        case .overCurrentContext: .overCurrentContext
        case .popover: .popover
        case .none: .none
        case .automatic: .automatic
        }
    }
}
