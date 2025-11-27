//
//  WebBrowserService.swift
//  GaugeWatcher
//
//  Created by Andrew Althage on 11/25/25.
//

import ComposableArchitecture
import SafariServices

// MARK: - WebBrowserService

struct WebBrowserService {
    var open: (URL, WebBrowserOptions?) async throws -> Void
}

// MARK: DependencyKey

extension WebBrowserService: DependencyKey {
    static let liveValue = Self(open: { url, options in
        let browserModule = WebBrowserModule()
        let options = options ?? WebBrowserOptions()
        try await browserModule.openBrowserAsync(url: url, options: options)
    })
}

extension DependencyValues {
    var webBrowserService: WebBrowserService {
        get { self[WebBrowserService.self] }
        set { self[WebBrowserService.self] = newValue }
    }
}

// MARK: - WebBrowserSession

class WebBrowserSession: NSObject, SFSafariViewControllerDelegate, UIAdaptivePresentationControllerDelegate {

    // MARK: Lifecycle

    init(url: URL, options: WebBrowserOptions, onDismiss: @escaping (String) -> Void, didPresent: @escaping () -> Void) {
        self.onDismiss = onDismiss
        self.didPresent = didPresent

        let configuration = SFSafariViewController.Configuration()
        configuration.barCollapsingEnabled = options.enableBarCollapsing
        configuration.entersReaderIfAvailable = options.readerMode

        viewController = SFSafariViewController(url: url, configuration: configuration)
        viewController.modalPresentationStyle = options.presentationStyle.toPresentationStyle()
        viewController.dismissButtonStyle = options.dismissButtonStyle.toSafariDismissButtonStyle()

        super.init()
        viewController.delegate = self
        viewController.presentationController?.delegate = self
    }

    // MARK: Public

    // MARK: - SFSafariViewControllerDelegate

    public func safariViewControllerDidFinish(_: SFSafariViewController) {
        finish(type: "cancel")
    }

    // MARK: - UIAdaptivePresentationControllerDelegate

    public func presentationControllerDidDismiss(_: UIPresentationController) {
        finish(type: "cancel")
    }

    // MARK: Internal

    let viewController: SFSafariViewController
    let onDismiss: (String) -> Void
    let didPresent: () -> Void

    func open() {
        var currentViewController = UIApplication.shared.keyWindow?.rootViewController
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

class WebBrowserModule {

    // MARK: Lifecycle

    init(currentWebBrowserSession: WebBrowserSession? = nil, vcDidPresent: Bool = false) {
        self.currentWebBrowserSession = currentWebBrowserSession
        self.vcDidPresent = vcDidPresent
    }

    // MARK: Internal

    func openBrowserAsync(url: URL, options: WebBrowserOptions = .init()) async throws {
        if vcDidPresent {
            currentWebBrowserSession = nil
            vcDidPresent = false
        }

        guard isValid(url: url) else {
            throw WebBrowserErrors.invalidURL
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

// MARK: - WebBrowserErrors

enum WebBrowserErrors: Error {
    case alreadyOpen, invalidURL
}
