import AppKit
import WebKit

/// Bundled, offline productivity workspace. No remote page receives native privileges.
final class WorkspaceViewController: NSViewController, WKNavigationDelegate, WKUIDelegate, WKScriptMessageHandler {
    private var webView: WKWebView!
    private var workspaceURL: URL?

    override func loadView() {
        let controller = WKUserContentController()
        controller.add(WorkspaceMessageProxy(self), name: "glassDeckExport")
        controller.addUserScript(WKUserScript(source: "window.glassDeckNative = true;", injectionTime: .atDocumentStart, forMainFrameOnly: true))
        let configuration = WKWebViewConfiguration()
        configuration.userContentController = controller
        configuration.websiteDataStore = .default()
        webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = self
        webView.uiDelegate = self
        view = webView
        guard let resource = Bundle.main.resourceURL?.appendingPathComponent("Workspace", isDirectory: true),
              FileManager.default.fileExists(atPath: resource.appendingPathComponent("index.html").path) else {
            webView.loadHTMLString("<h1>Glass Deck</h1><p>Workspace resources are missing. Please reinstall the complete app bundle.</p>", baseURL: nil)
            return
        }
        workspaceURL = resource.standardizedFileURL
        webView.loadFileURL(resource.appendingPathComponent("index.html"), allowingReadAccessTo: resource)
    }

    private func isWorkspace(_ url: URL?) -> Bool {
        guard let url = url, url.isFileURL, let root = workspaceURL else { return false }
        return url.standardizedFileURL.path.hasPrefix(root.path + "/")
    }

    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction,
                 decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        guard let url = navigationAction.request.url else { decisionHandler(.cancel); return }
        if isWorkspace(url) { decisionHandler(.allow); return }
        // Web links leave the embedded workspace. Other file URLs and schemes never open.
        if url.scheme == "https", navigationAction.navigationType == .linkActivated {
            NSWorkspace.shared.open(url)
        } else if url.isFileURL, navigationAction.navigationType == .linkActivated {
            NSWorkspace.shared.open(URL(string: "https://aarongame.com/")!)
        }
        decisionHandler(.cancel)
    }

    func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration,
                 for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
        if let url = navigationAction.request.url, url.scheme == "https" { NSWorkspace.shared.open(url) }
        return nil
    }

    func webView(_ webView: WKWebView, runJavaScriptConfirmPanelWithMessage message: String,
                 initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping (Bool) -> Void) {
        let alert = NSAlert()
        alert.messageText = WorkspaceLabels.workspace
        alert.informativeText = message
        alert.addButton(withTitle: WorkspaceLabels.continueTitle)
        alert.addButton(withTitle: WorkspaceLabels.cancel)
        if let window = view.window {
            alert.beginSheetModal(for: window) { completionHandler($0 == .alertFirstButtonReturn) }
        } else { completionHandler(false) }
    }

    func webView(_ webView: WKWebView, runOpenPanelWith parameters: WKOpenPanelParameters,
                 initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping ([URL]?) -> Void) {
        guard frame.isMainFrame, isWorkspace(frame.request.url), let window = view.window else { completionHandler(nil); return }
        let panel = NSOpenPanel()
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowsMultipleSelection = false
        panel.beginSheetModal(for: window) { response in completionHandler(response == .OK ? panel.urls : nil) }
    }

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard message.frameInfo.isMainFrame, isWorkspace(message.frameInfo.request.url),
              let body = message.body as? [String: Any], let text = body["text"] as? String,
              text.utf8.count <= 2 * 1024 * 1024,
              let action = body["action"] as? String else { return }
        if action == "copy" {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(text, forType: .string)
            return
        }
        guard action == "save", let name = body["name"] as? String,
              name == (name as NSString).lastPathComponent,
              ["json", "txt"].contains((name as NSString).pathExtension), let window = view.window else { return }
        let panel = NSSavePanel()
        panel.nameFieldStringValue = name
        panel.canCreateDirectories = true
        panel.beginSheetModal(for: window) { [weak self] response in
            guard response == .OK, let url = panel.url else { return }
            do {
                try text.write(to: url, atomically: true, encoding: .utf8)
            } catch {
                let alert = NSAlert(error: error)
                if let window = self?.view.window { alert.beginSheetModal(for: window) }
            }
        }
    }
}

enum WorkspaceLabels {
    static var workspace: String {
        switch L.current { case .zhHans: return "工作台"; case .zhHant: return "工作台"; case .ja: return "ワークスペース"; case .ko: return "작업 공간"; case .en: return "Workspace" }
    }
    static var controls: String {
        switch L.current { case .zhHans: return "系统控制"; case .zhHant: return "系統控制"; case .ja: return "システム"; case .ko: return "시스템 제어"; case .en: return "System controls" }
    }
    static var cancel: String { L.current == .zhHans || L.current == .zhHant ? "取消" : "Cancel" }
    static var continueTitle: String { L.current == .zhHans || L.current == .zhHant ? "继续" : "Continue" }
}

/// Hosts the original control deck and the workspace in the same app window.
final class MainDeckViewController: NSViewController {
    private let controls = DeckViewController()
    private let workspace = WorkspaceViewController()
    private var container: NSView!
    private var picker: NSSegmentedControl!
    private var selectedController: NSViewController?

    override func loadView() {
        view = NSView(frame: NSRect(x: 0, y: 0, width: 380, height: 780))
        picker = NSSegmentedControl(labels: [WorkspaceLabels.controls, WorkspaceLabels.workspace], trackingMode: .selectOne,
                                    target: self, action: #selector(selectionChanged))
        picker.selectedSegment = 0
        picker.translatesAutoresizingMaskIntoConstraints = false
        picker.setAccessibilityLabel("Glass Deck mode")
        container = NSView()
        container.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(picker)
        view.addSubview(container)
        NSLayoutConstraint.activate([
            picker.topAnchor.constraint(equalTo: view.topAnchor, constant: 10),
            picker.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            container.topAnchor.constraint(equalTo: picker.bottomAnchor, constant: 10),
            container.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            container.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            container.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
        show(controls)
    }

    func openWorkspace() { _ = view; picker.selectedSegment = 1; selectionChanged() }

    @objc private func selectionChanged() {
        let isWorkspace = picker.selectedSegment == 1
        let window = view.window
        preferredContentSize = isWorkspace ? NSSize(width: 1100, height: 800) : NSSize(width: 380, height: 780)
        show(isWorkspace ? workspace : controls)
        guard let window = window else { return }
        let top = window.frame.maxY
        window.contentMinSize = isWorkspace ? NSSize(width: 760, height: 620) : NSSize(width: 380, height: 760)
        window.setContentSize(isWorkspace ? NSSize(width: 1100, height: 800) : NSSize(width: 380, height: 780))
        var frame = window.frame
        frame.origin.y = top - frame.height
        if let visible = window.screen?.visibleFrame {
            frame.size.width = min(frame.width, visible.width)
            frame.size.height = min(frame.height, visible.height)
            frame.origin.x = max(visible.minX, min(frame.origin.x, visible.maxX - frame.width))
            frame.origin.y = max(visible.minY, min(frame.origin.y, visible.maxY - frame.height))
        }
        window.setFrame(frame, display: true)
    }

    private func show(_ controller: NSViewController) {
        guard selectedController !== controller else { return }
        selectedController?.view.removeFromSuperview()
        selectedController?.removeFromParent()
        addChild(controller)
        let child = controller.view
        child.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(child)
        NSLayoutConstraint.activate([
            child.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            child.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            child.topAnchor.constraint(equalTo: container.topAnchor),
            child.bottomAnchor.constraint(equalTo: container.bottomAnchor),
        ])
        selectedController = controller
    }
}

/// WebKit retains its message handler; a weak proxy lets closed windows deallocate.
private final class WorkspaceMessageProxy: NSObject, WKScriptMessageHandler {
    weak var receiver: WorkspaceViewController?
    init(_ receiver: WorkspaceViewController) { self.receiver = receiver }
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        receiver?.userContentController(userContentController, didReceive: message)
    }
}
