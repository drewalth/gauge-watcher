//
//  WebBrowserOptions.swift
//  GaugeWatcher
//
//  Created by Andrew Althage on 11/25/25.
//

//
//  WebBrowserOptions.swift
//  GaugeWatcher
//
//  Created by Andrew Althage on 8/19/25.
//
import Foundation
import SafariServices

// MARK: - WebBrowserOptions

nonisolated struct WebBrowserOptions {

    init(
        readerMode: Bool = false,
        enableBarCollapsing: Bool = false,
        dismissButtonStyle: DismissButtonStyle = .done,
        presentationStyle: PresentationStyle = .overFullScreen) {
        self.readerMode = readerMode
        self.enableBarCollapsing = enableBarCollapsing
        self.dismissButtonStyle = dismissButtonStyle
        self.presentationStyle = presentationStyle
    }

    var readerMode = false
    var enableBarCollapsing = false
    var dismissButtonStyle: DismissButtonStyle = .done
    var toolbarColor: UIColor?
    var controlsColor: UIColor?
    var presentationStyle: PresentationStyle = .overFullScreen
}

// MARK: - DismissButtonStyle

enum DismissButtonStyle: String {
    case done
    case close
    case cancel

    func toSafariDismissButtonStyle() -> SFSafariViewController.DismissButtonStyle {
        switch self {
        case .done:
            return .done
        case .close:
            return .close
        case .cancel:
            return .cancel
        }
    }
}

// MARK: - PresentationStyle

enum PresentationStyle: String {
    case fullScreen
    case pageSheet
    case formSheet
    case currentContext
    case overFullScreen
    case overCurrentContext
    case popover
    case none
    case automatic

    // MARK: Internal

    func toPresentationStyle() -> UIModalPresentationStyle {
        switch self {
        case .fullScreen:
            return .fullScreen
        case .pageSheet:
            return .pageSheet
        case .formSheet:
            return .formSheet
        case .currentContext:
            return .currentContext
        case .overFullScreen:
            return .overFullScreen
        case .overCurrentContext:
            return .overCurrentContext
        case .popover:
            return .popover
        case .none:
            return .none
        case .automatic:
            return .automatic
        }
    }
}
