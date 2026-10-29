import AppKit
import PreviewPPKit
import UniformTypeIdentifiers
import WebKit

/// A plugin written in HTML/JS, running in WebKit's separate content process.
///
/// The page sees one origin and nothing else (enforced by CSP): `ppp-plugin://plugin/<path>` serves the
/// plugin folder, and the reserved path `/__ppp__/file` serves the opened file.
/// It talks back with `webkit.messageHandlers.ppp.postMessage({type: "ready"})`; the host
/// invokes commands with `window.ppp.command(id)`.
struct WebPluginAdapter: ExternalPlugin {
    let folder: URL
    let manifest: ExternalManifest
    var runtime: Runtime { .web }

    func open(_ url: URL, host: any PluginHost) throws -> Viewer {
        let entry = try manifest.entryURL(in: folder)
        let controller = WebViewerController(folder: folder, entry: entry, file: url, host: host)
        return Viewer(
            content: controller,
            commands: manifest.commands { controller.invoke($0) },
            readiness: .reportedByPlugin,
            onClose: { controller.close() }
        )
    }
}

final class WebViewerController: NSViewController, WKNavigationDelegate {
    private let folder: URL
    private let entry: URL
    private let file: URL
    private weak var host: (any PluginHost)?
    private var webView: WKWebView!
    private let bridge = Bridge()

    init(folder: URL, entry: URL, file: URL, host: any PluginHost) {
        self.folder = folder
        self.entry = entry
        self.file = file
        self.host = host
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError("not used") }

    override func loadView() {
        let configuration = WKWebViewConfiguration()
        let schemes = SchemeHandler(folder: folder, file: file)
        configuration.setURLSchemeHandler(schemes, forURLScheme: "ppp-plugin")
        configuration.websiteDataStore = .nonPersistent()
        bridge.controller = self
        configuration.userContentController.add(bridge, name: "ppp")
        configuration.userContentController.addUserScript(WKUserScript(source: Self.errorForwarder, injectionTime: .atDocumentStart, forMainFrameOnly: true))
        webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = self
        webView.underPageBackgroundColor = .textBackgroundColor
        let relative = String(entry.path.dropFirst(folder.standardizedFileURL.resolvingSymlinksInPath().path.count))
        webView.load(URLRequest(url: URL(string: "ppp-plugin://plugin\(relative)")!))
        view = webView
    }

    func invoke(_ commandID: String) {
        guard let data = try? JSONEncoder().encode(commandID), let literal = String(data: data, encoding: .utf8) else { return }
        webView.evaluateJavaScript("window.ppp?.command(\(literal))")
    }

    func close() {
        webView?.configuration.userContentController.removeScriptMessageHandler(forName: "ppp")
    }

    fileprivate func received(_ body: Any) {
        guard let message = body as? [String: Any], let type = message["type"] as? String else { return }
        switch type {
        case "ready": host?.contentDidBecomeReady()
        case "error": host?.viewerDidFail(message["message"] as? String ?? "Plugin error")
        case "log": FileHandle.standardError.write(Data("web plugin: \(message["message"] ?? "")\n".utf8))
        default: break
        }
    }

    /// Uncaught page errors otherwise vanish inside WebKit's process; surface them on the host's stderr.
    private static let errorForwarder = """
        addEventListener("error", e => webkit.messageHandlers.ppp.postMessage({type: "log", message: `${e.message} (${e.filename}:${e.lineno})`}));
        addEventListener("unhandledrejection", e => webkit.messageHandlers.ppp.postMessage({type: "log", message: String(e.reason)}));
        addEventListener("securitypolicyviolation", e => webkit.messageHandlers.ppp.postMessage({type: "log", message: `CSP blocked ${e.blockedURI}`}));
        """

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: any Error) {
        host?.viewerDidFail(error.localizedDescription)
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: any Error) {
        host?.viewerDidFail(error.localizedDescription)
    }

    func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
        host?.viewerDidFail("The plugin's web process stopped. The rest of the app is unaffected.")
    }

    /// Breaks the WKUserContentController -> handler retain cycle.
    private final class Bridge: NSObject, WKScriptMessageHandler {
        weak var controller: WebViewerController?
        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            controller?.received(message.body)
        }
    }
}

private final class SchemeHandler: NSObject, WKURLSchemeHandler {
    private static let csp = "default-src 'self'; style-src 'self' 'unsafe-inline'; img-src 'self' data:"
    private let folder: URL
    private let file: URL

    init(folder: URL, file: URL) {
        self.folder = folder.standardizedFileURL.resolvingSymlinksInPath()
        self.file = file
    }

    func webView(_ webView: WKWebView, start task: any WKURLSchemeTask) {
        guard let url = task.request.url, let target = resolve(url), let data = try? Data(contentsOf: target) else {
            task.didFailWithError(URLError(.fileDoesNotExist))
            return
        }
        let mime = UTType(filenameExtension: target.pathExtension)?.preferredMIMEType ?? "application/octet-stream"
        let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: "HTTP/1.1", headerFields: [
            "Content-Type": mime,
            "Content-Security-Policy": Self.csp,
        ])!
        task.didReceive(response)
        task.didReceive(data)
        task.didFinish()
    }

    func webView(_ webView: WKWebView, stop task: any WKURLSchemeTask) {}

    private func resolve(_ url: URL) -> URL? {
        guard url.scheme == "ppp-plugin", url.host() == "plugin" else { return nil }
        if url.path() == "/__ppp__/file" { return file }
        let target = folder.appending(path: url.path()).standardizedFileURL.resolvingSymlinksInPath()
        return target.path.hasPrefix(folder.path + "/") ? target : nil
    }
}
