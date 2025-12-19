import SwiftUI

#if os(iOS)
public struct MarkdownUI: UIViewRepresentable {

  // MARK: Lifecycle

  public init(
    body: String = "",
    css: String? = nil,
    plugins: [String]? = nil,
    stylesheets: [URL]? = nil,
    styled: Bool = true)
  {
    self.body = body
    self.css = css
    self.plugins = plugins
    self.stylesheets = stylesheets
    self.styled = styled
  }

  // MARK: Public

  public let body: String

  public func makeUIView(context _: Context) -> MarkdownView {
    let view = MarkdownView(css: css, plugins: plugins, stylesheets: stylesheets, styled: styled)
    view.isScrollEnabled = false
    view.onTouchLink = onTouchLinkAction
    view.onRendered = onRenderedAction
    return view
  }

  public func updateUIView(_ uiView: MarkdownView, context _: Context) {
    uiView.onTouchLink = onTouchLinkAction
    uiView.onRendered = onRenderedAction
    uiView.show(markdown: body)
  }

  // MARK: Internal

  var onTouchLinkAction: ((URLRequest) -> Bool)?
  var onRenderedAction: ((CGFloat) -> Void)?

  // MARK: Private

  private let css: String?
  private let plugins: [String]?
  private let stylesheets: [URL]?
  private let styled: Bool
}

extension MarkdownUI {
  public func onTouchLink(perform action: @escaping (URLRequest) -> Bool) -> MarkdownUI {
    var copy = self
    copy.onTouchLinkAction = action
    return copy
  }

  public func onRendered(perform action: @escaping (CGFloat) -> Void) -> MarkdownUI {
    var copy = self
    copy.onRenderedAction = action
    return copy
  }
}

#else

public struct MarkdownUI: NSViewRepresentable {

  // MARK: Lifecycle

  public init(
    body: String = "",
    css: String? = nil,
    plugins: [String]? = nil,
    stylesheets: [URL]? = nil,
    styled: Bool = true)
  {
    self.body = body
    self.css = css
    self.plugins = plugins
    self.stylesheets = stylesheets
    self.styled = styled
  }

  // MARK: Public

  public let body: String

  public func makeNSView(context _: Context) -> MarkdownView {
    let view = MarkdownView(css: css, plugins: plugins, stylesheets: stylesheets, styled: styled)
    view.onTouchLink = onTouchLinkAction
    view.onRendered = onRenderedAction
    return view
  }

  public func updateNSView(_ nsView: MarkdownView, context _: Context) {
    nsView.onTouchLink = onTouchLinkAction
    nsView.onRendered = onRenderedAction
    nsView.show(markdown: body)
  }

  // MARK: Internal

  var onTouchLinkAction: ((URLRequest) -> Bool)?
  var onRenderedAction: ((CGFloat) -> Void)?

  // MARK: Private

  private let css: String?
  private let plugins: [String]?
  private let stylesheets: [URL]?
  private let styled: Bool
}

extension MarkdownUI {
  public func onTouchLink(perform action: @escaping (URLRequest) -> Bool) -> MarkdownUI {
    var copy = self
    copy.onTouchLinkAction = action
    return copy
  }

  public func onRendered(perform action: @escaping (CGFloat) -> Void) -> MarkdownUI {
    var copy = self
    copy.onRenderedAction = action
    return copy
  }
}

#endif

#Preview("MarkdownUI") {
  let mockBody = """
    # Hello, World!

    This is a test of the MarkdownView.
    """
  return MarkdownUI(body: mockBody)
}
