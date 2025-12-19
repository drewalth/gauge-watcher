#if os(iOS)
import UIKit
import WebKit

/// Markdown View for iOS.
///
/// - Note: [How to get height of entire document with javascript](https://stackoverflow.com/questions/1145850/how-to-get-height-of-entire-document-with-javascript)
open class MarkdownView: UIView {

  // MARK: Lifecycle

  public convenience init() {
    self.init(frame: .zero)
  }

  /// Reserve a web view before displaying markdown.
  /// You can use this for performance optimization.
  ///
  /// - Note: `webView` needs complete loading before invoking `show` method.
  public convenience init(css: String?, plugins: [String]?, stylesheets: [URL]? = nil, styled: Bool = true) {
    self.init(frame: .zero)

    let configuration = WKWebViewConfiguration()
    configuration.userContentController = makeContentController(
      css: css,
      plugins: plugins,
      stylesheets: stylesheets,
      markdown: nil,
      enableImage: nil)
    if let handler = updateHeightHandler {
      configuration.userContentController.add(handler, name: "updateHeight")
    }
    webView = makeWebView(with: configuration)
    webView?.load(URLRequest(url: styled ? Self.styledHtmlUrl : Self.nonStyledHtmlUrl))
  }

  override init(frame: CGRect) {
    super.init(frame: frame)

    let updateHeightHandler = UpdateHeightHandler { [weak self] height in
      guard height > self?.intrinsicContentHeight ?? 0 else { return }
      self?.onRendered?(height)
      self?.intrinsicContentHeight = height
    }
    self.updateHeightHandler = updateHeightHandler
  }

  public required init?(coder aDecoder: NSCoder) {
    super.init(coder: aDecoder)
  }

  // MARK: Public

  @objc public var onTouchLink: ((URLRequest) -> Bool)?

  @objc public var onRendered: ((CGFloat) -> Void)?

  @objc public var isScrollEnabled = true {
    didSet {
      webView?.scrollView.isScrollEnabled = isScrollEnabled
    }
  }

  // MARK: Private

  private var webView: WKWebView?
  private var updateHeightHandler: UpdateHeightHandler?
  private var isReady = false
  private var pendingMarkdown: String?

  private var intrinsicContentHeight: CGFloat? {
    didSet {
      invalidateIntrinsicContentSize()
    }
  }

}

extension MarkdownView {

  // MARK: Open

  open override var intrinsicContentSize: CGSize {
    if let height = intrinsicContentHeight {
      return CGSize(width: UIView.noIntrinsicMetric, height: height)
    } else {
      return CGSize.zero
    }
  }

  // MARK: Public

  /// Load markdown with a newly configured webView.
  ///
  /// If you want to preserve already applied css or plugins, use `show` instead.
  @objc
  public func load(
    markdown: String?,
    enableImage: Bool = true,
    css: String? = nil,
    plugins: [String]? = nil,
    stylesheets: [URL]? = nil,
    styled: Bool = true)
  {
    guard let markdown else { return }

    isReady = false
    webView?.removeFromSuperview()

    let configuration = WKWebViewConfiguration()
    configuration.userContentController = makeContentController(
      css: css,
      plugins: plugins,
      stylesheets: stylesheets,
      markdown: markdown,
      enableImage: enableImage)
    if let handler = updateHeightHandler {
      configuration.userContentController.add(handler, name: "updateHeight")
    }
    webView = makeWebView(with: configuration)
    webView?.load(URLRequest(url: styled ? Self.styledHtmlUrl : Self.nonStyledHtmlUrl))
  }

  public func show(markdown: String) {
    guard !markdown.isEmpty else { return }

    if isReady, let webView {
      executeShowMarkdown(markdown, in: webView)
    } else {
      pendingMarkdown = markdown
    }
  }

  // MARK: Private

  private func executeShowMarkdown(_ markdown: String, in webView: WKWebView) {
    let escapedMarkdown = escape(markdown: markdown) ?? ""
    let script = "window.showMarkdown('\(escapedMarkdown)', true);"
    webView.evaluateJavaScript(script) { _, error in
      if let error {
        print("[MarkdownView][Error] \(error)")
      }
    }
  }
}

// MARK: - WKNavigationDelegate

extension MarkdownView: WKNavigationDelegate {

  public func webView(_ webView: WKWebView, didFinish _: WKNavigation!) {
    isReady = true
    if let pending = pendingMarkdown {
      pendingMarkdown = nil
      executeShowMarkdown(pending, in: webView)
    }
  }

  public func webView(
    _: WKWebView,
    decidePolicyFor navigationAction: WKNavigationAction,
    decisionHandler: @escaping (WKNavigationActionPolicy) -> Void)
  {
    switch navigationAction.navigationType {
    case .linkActivated:
      if let onTouchLink, onTouchLink(navigationAction.request) {
        decisionHandler(.allow)
      } else {
        decisionHandler(.cancel)
      }
    default:
      decisionHandler(.allow)
    }
  }
}

// MARK: - UpdateHeightHandler

private final class UpdateHeightHandler: NSObject, WKScriptMessageHandler {

  // MARK: Lifecycle

  init(onUpdate: @escaping (CGFloat) -> Void) {
    self.onUpdate = onUpdate
  }

  // MARK: Internal

  func userContentController(_: WKUserContentController, didReceive message: WKScriptMessage) {
    if let height = message.body as? CGFloat {
      onUpdate(height)
    }
  }

  // MARK: Private

  private let onUpdate: (CGFloat) -> Void

}

// MARK: - Scripts

extension MarkdownView {

  fileprivate func styleScript(_ css: String) -> String {
    [
      "var s = document.createElement('style');",
      "s.innerHTML = `\(css)`;",
      "document.head.appendChild(s);",
    ].joined()
  }

  fileprivate func linkScript(_ url: URL) -> String {
    [
      "var link = document.createElement('link');",
      "link.href = '\(url.absoluteURL)';",
      "link.rel = 'stylesheet';",
      "document.head.appendChild(link);",
    ].joined()
  }

  fileprivate func usePluginScript(_ pluginBody: String) -> String {
    """
      var _module = {};
      var _exports = {};
      (function(module, exports) {
        \(pluginBody)
      })(_module, _exports);
      window.usePlugin(_module.exports || _exports);
    """
  }
}

// MARK: - Misc

extension MarkdownView {
  fileprivate static var styledHtmlUrl: URL = {
    #if SWIFT_PACKAGE
    let bundle = Bundle.module
    #else
    let bundle = Bundle(for: MarkdownView.self)
    #endif
    return bundle.url(
      forResource: "styled",
      withExtension: "html") ??
      bundle.url(
        forResource: "styled",
        withExtension: "html",
        subdirectory: "MarkdownView.bundle")!
  }()

  fileprivate static var nonStyledHtmlUrl: URL = {
    #if SWIFT_PACKAGE
    let bundle = Bundle.module
    #else
    let bundle = Bundle(for: MarkdownView.self)
    #endif
    return bundle.url(
      forResource: "non_styled",
      withExtension: "html") ??
      bundle.url(
        forResource: "non_styled",
        withExtension: "html",
        subdirectory: "MarkdownView.bundle")!
  }()

  fileprivate func escape(markdown: String) -> String? {
    markdown.addingPercentEncoding(withAllowedCharacters: CharacterSet.alphanumerics)
  }

  fileprivate func makeWebView(with configuration: WKWebViewConfiguration) -> WKWebView {
    let wv = WKWebView(frame: bounds, configuration: configuration)
    wv.scrollView.isScrollEnabled = isScrollEnabled
    wv.translatesAutoresizingMaskIntoConstraints = false
    wv.navigationDelegate = self
    addSubview(wv)
    wv.topAnchor.constraint(equalTo: topAnchor).isActive = true
    wv.bottomAnchor.constraint(equalTo: bottomAnchor).isActive = true
    wv.leadingAnchor.constraint(equalTo: leadingAnchor).isActive = true
    wv.trailingAnchor.constraint(equalTo: trailingAnchor).isActive = true
    wv.isOpaque = false
    wv.backgroundColor = .clear
    wv.scrollView.backgroundColor = .clear
    return wv
  }

  fileprivate func makeContentController(
    css: String?,
    plugins: [String]?,
    stylesheets: [URL]?,
    markdown: String?,
    enableImage: Bool?)
    -> WKUserContentController
  {
    let controller = WKUserContentController()

    if let css {
      let styleInjection = WKUserScript(source: styleScript(css), injectionTime: .atDocumentEnd, forMainFrameOnly: true)
      controller.addUserScript(styleInjection)
    }

    plugins?.forEach { plugin in
      let scriptInjection = WKUserScript(source: usePluginScript(plugin), injectionTime: .atDocumentEnd, forMainFrameOnly: true)
      controller.addUserScript(scriptInjection)
    }

    stylesheets?.forEach { url in
      let linkInjection = WKUserScript(source: linkScript(url), injectionTime: .atDocumentEnd, forMainFrameOnly: true)
      controller.addUserScript(linkInjection)
    }

    if let markdown {
      let escapedMarkdown = escape(markdown: markdown) ?? ""
      let imageOption = (enableImage ?? true) ? "true" : "false"
      let script = "window.showMarkdown('\(escapedMarkdown)', \(imageOption));"
      let userScript = WKUserScript(source: script, injectionTime: .atDocumentEnd, forMainFrameOnly: true)
      controller.addUserScript(userScript)
    }

    return controller
  }
}
#else
import AppKit
import WebKit

/// Markdown View for macOS.
///
/// - Note: [How to get height of entire document with javascript](https://stackoverflow.com/questions/1145850/how-to-get-height-of-entire-document-with-javascript)
open class MarkdownView: NSView {

  // MARK: Lifecycle

  public convenience init() {
    self.init(frame: .zero)
  }

  /// Reserve a web view before displaying markdown.
  /// You can use this for performance optimization.
  ///
  /// - Note: `webView` needs complete loading before invoking `show` method.
  public convenience init(css: String?, plugins: [String]?, stylesheets: [URL]? = nil, styled: Bool = true) {
    self.init(frame: .zero)

    let configuration = WKWebViewConfiguration()
    configuration.userContentController = makeContentController(
      css: css,
      plugins: plugins,
      stylesheets: stylesheets,
      markdown: nil,
      enableImage: nil)
    if let handler = updateHeightHandler {
      configuration.userContentController.add(handler, name: "updateHeight")
    }
    webView = makeWebView(with: configuration)
    webView?.load(URLRequest(url: styled ? Self.styledHtmlUrl : Self.nonStyledHtmlUrl))
  }

  override init(frame: CGRect) {
    super.init(frame: frame)

    let updateHeightHandler = UpdateHeightHandler { [weak self] height in
      guard height > self?.intrinsicContentHeight ?? 0 else { return }
      self?.onRendered?(height)
      self?.intrinsicContentHeight = height
    }
    self.updateHeightHandler = updateHeightHandler
  }

  public required init?(coder aDecoder: NSCoder) {
    super.init(coder: aDecoder)
  }

  // MARK: Public

  public var onTouchLink: ((URLRequest) -> Bool)?

  public var onRendered: ((CGFloat) -> Void)?

  // MARK: Private

  private var webView: WKWebView?
  private var updateHeightHandler: UpdateHeightHandler?
  private var isReady = false
  private var pendingMarkdown: String?

  private var intrinsicContentHeight: CGFloat? {
    didSet {
      invalidateIntrinsicContentSize()
    }
  }

}

extension MarkdownView {

  // MARK: Open

  open override var intrinsicContentSize: NSSize {
    if let height = intrinsicContentHeight {
      return NSSize(width: NSView.noIntrinsicMetric, height: height)
    } else {
      return NSSize.zero
    }
  }

  // MARK: Public

  /// Load markdown with a newly configured webView.
  ///
  /// If you want to preserve already applied css or plugins, use `show` instead.
  public func load(
    markdown: String?,
    enableImage: Bool = true,
    css: String? = nil,
    plugins: [String]? = nil,
    stylesheets: [URL]? = nil,
    styled: Bool = true)
  {
    guard let markdown else { return }

    isReady = false
    webView?.removeFromSuperview()

    let configuration = WKWebViewConfiguration()
    configuration.userContentController = makeContentController(
      css: css,
      plugins: plugins,
      stylesheets: stylesheets,
      markdown: markdown,
      enableImage: enableImage)
    if let handler = updateHeightHandler {
      configuration.userContentController.add(handler, name: "updateHeight")
    }
    webView = makeWebView(with: configuration)
    webView?.load(URLRequest(url: styled ? Self.styledHtmlUrl : Self.nonStyledHtmlUrl))
  }

  public func show(markdown: String) {
    guard !markdown.isEmpty else { return }

    if isReady, let webView {
      executeShowMarkdown(markdown, in: webView)
    } else {
      pendingMarkdown = markdown
    }
  }

  // MARK: Private

  private func executeShowMarkdown(_ markdown: String, in webView: WKWebView) {
    let escapedMarkdown = escape(markdown: markdown) ?? ""
    let script = "window.showMarkdown('\(escapedMarkdown)', true);"
    webView.evaluateJavaScript(script) { _, error in
      if let error {
        print("[MarkdownView][Error] \(error)")
      }
    }
  }
}

// MARK: - WKNavigationDelegate

extension MarkdownView: WKNavigationDelegate {

  public func webView(_ webView: WKWebView, didFinish _: WKNavigation!) {
    isReady = true
    if let pending = pendingMarkdown {
      pendingMarkdown = nil
      executeShowMarkdown(pending, in: webView)
    }
  }

  public func webView(
    _: WKWebView,
    decidePolicyFor navigationAction: WKNavigationAction,
    decisionHandler: @escaping (WKNavigationActionPolicy) -> Void)
  {
    switch navigationAction.navigationType {
    case .linkActivated:
      if let onTouchLink, onTouchLink(navigationAction.request) {
        decisionHandler(.allow)
      } else {
        decisionHandler(.cancel)
      }
    default:
      decisionHandler(.allow)
    }
  }
}

// MARK: - UpdateHeightHandler

private final class UpdateHeightHandler: NSObject, WKScriptMessageHandler {

  // MARK: Lifecycle

  init(onUpdate: @escaping (CGFloat) -> Void) {
    self.onUpdate = onUpdate
  }

  // MARK: Internal

  func userContentController(_: WKUserContentController, didReceive message: WKScriptMessage) {
    if let height = message.body as? CGFloat {
      onUpdate(height)
    }
  }

  // MARK: Private

  private let onUpdate: (CGFloat) -> Void

}

// MARK: - Scripts

extension MarkdownView {

  fileprivate func styleScript(_ css: String) -> String {
    [
      "var s = document.createElement('style');",
      "s.innerHTML = `\(css)`;",
      "document.head.appendChild(s);",
    ].joined()
  }

  fileprivate func linkScript(_ url: URL) -> String {
    [
      "var link = document.createElement('link');",
      "link.href = '\(url.absoluteURL)';",
      "link.rel = 'stylesheet';",
      "document.head.appendChild(link);",
    ].joined()
  }

  fileprivate func usePluginScript(_ pluginBody: String) -> String {
    """
      var _module = {};
      var _exports = {};
      (function(module, exports) {
        \(pluginBody)
      })(_module, _exports);
      window.usePlugin(_module.exports || _exports);
    """
  }
}

// MARK: - Misc

extension MarkdownView {
  fileprivate static var styledHtmlUrl: URL = {
    #if SWIFT_PACKAGE
    let bundle = Bundle.module
    #else
    let bundle = Bundle(for: MarkdownView.self)
    #endif
    return bundle.url(
      forResource: "styled",
      withExtension: "html") ??
      bundle.url(
        forResource: "styled",
        withExtension: "html",
        subdirectory: "MarkdownView.bundle")!
  }()

  fileprivate static var nonStyledHtmlUrl: URL = {
    #if SWIFT_PACKAGE
    let bundle = Bundle.module
    #else
    let bundle = Bundle(for: MarkdownView.self)
    #endif
    return bundle.url(
      forResource: "non_styled",
      withExtension: "html") ??
      bundle.url(
        forResource: "non_styled",
        withExtension: "html",
        subdirectory: "MarkdownView.bundle")!
  }()

  fileprivate func escape(markdown: String) -> String? {
    markdown.addingPercentEncoding(withAllowedCharacters: CharacterSet.alphanumerics)
  }

  fileprivate func makeWebView(with configuration: WKWebViewConfiguration) -> WKWebView {
    let wv = WKWebView(frame: bounds, configuration: configuration)
    wv.translatesAutoresizingMaskIntoConstraints = false
    wv.navigationDelegate = self
    addSubview(wv)
    wv.topAnchor.constraint(equalTo: topAnchor).isActive = true
    wv.bottomAnchor.constraint(equalTo: bottomAnchor).isActive = true
    wv.leadingAnchor.constraint(equalTo: leadingAnchor).isActive = true
    wv.trailingAnchor.constraint(equalTo: trailingAnchor).isActive = true

    // macOS WKWebView configuration for transparency
    wv.setValue(false, forKey: "drawsBackground")

    return wv
  }

  fileprivate func makeContentController(
    css: String?,
    plugins: [String]?,
    stylesheets: [URL]?,
    markdown: String?,
    enableImage: Bool?)
    -> WKUserContentController
  {
    let controller = WKUserContentController()

    if let css {
      let styleInjection = WKUserScript(source: styleScript(css), injectionTime: .atDocumentEnd, forMainFrameOnly: true)
      controller.addUserScript(styleInjection)
    }

    plugins?.forEach { plugin in
      let scriptInjection = WKUserScript(source: usePluginScript(plugin), injectionTime: .atDocumentEnd, forMainFrameOnly: true)
      controller.addUserScript(scriptInjection)
    }

    stylesheets?.forEach { url in
      let linkInjection = WKUserScript(source: linkScript(url), injectionTime: .atDocumentEnd, forMainFrameOnly: true)
      controller.addUserScript(linkInjection)
    }

    if let markdown {
      let escapedMarkdown = escape(markdown: markdown) ?? ""
      let imageOption = (enableImage ?? true) ? "true" : "false"
      let script = "window.showMarkdown('\(escapedMarkdown)', \(imageOption));"
      let userScript = WKUserScript(source: script, injectionTime: .atDocumentEnd, forMainFrameOnly: true)
      controller.addUserScript(userScript)
    }

    return controller
  }
}
#endif
