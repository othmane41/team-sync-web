import Cocoa
import WebKit

// MARK: - Server Manager

class ServerManager {
    private var process: Process?
    private let port: Int

    init(port: Int = 8080) {
        self.port = port
    }

    func start() {
        let bundle = Bundle.main
        guard let serverPath = bundle.path(forResource: "team-sync-web", ofType: nil, inDirectory: nil)
              ?? bundle.path(forAuxiliaryExecutable: "team-sync-web") else {
            // Fallback: look next to the app
            let appDir = bundle.bundlePath
            let parentDir = (appDir as NSString).deletingLastPathComponent
            let fallback = (parentDir as NSString).appendingPathComponent("team-sync-web")
            if FileManager.default.isExecutableFile(atPath: fallback) {
                launchServer(at: fallback)
                return
            }
            print("ERROR: Cannot find team-sync-web binary")
            return
        }
        launchServer(at: serverPath)
    }

    private func launchServer(at path: String) {
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: path)
        proc.environment = ProcessInfo.processInfo.environment
        proc.standardOutput = FileHandle.nullDevice
        proc.standardError = FileHandle.nullDevice

        do {
            try proc.run()
            self.process = proc
            print("Server started (PID \(proc.processIdentifier))")
        } catch {
            print("Failed to start server: \(error)")
        }
    }

    func waitUntilReady(timeout: TimeInterval = 10, completion: @escaping (Bool) -> Void) {
        let start = Date()
        let url = URL(string: "http://127.0.0.1:\(port)/api/machines")!

        func check() {
            let task = URLSession.shared.dataTask(with: url) { _, response, error in
                if let http = response as? HTTPURLResponse, http.statusCode == 200 {
                    DispatchQueue.main.async { completion(true) }
                } else if Date().timeIntervalSince(start) < timeout {
                    DispatchQueue.global().asyncAfter(deadline: .now() + 0.2) { check() }
                } else {
                    DispatchQueue.main.async { completion(false) }
                }
            }
            task.resume()
        }
        check()
    }

    func stop() {
        if let proc = process, proc.isRunning {
            proc.terminate()
            proc.waitUntilExit()
            print("Server stopped")
        }
    }
}

// MARK: - App Delegate

class AppDelegate: NSObject, NSApplicationDelegate, WKNavigationDelegate {
    var window: NSWindow!
    var webView: WKWebView!
    var server: ServerManager!
    var splash: NSTextField!
    let port = 8080

    func applicationDidFinishLaunching(_ notification: Notification) {
        server = ServerManager(port: port)

        // Window
        let screenFrame = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1200, height: 800)
        let width: CGFloat = min(1100, screenFrame.width * 0.8)
        let height: CGFloat = min(750, screenFrame.height * 0.85)
        let x = screenFrame.midX - width / 2
        let y = screenFrame.midY - height / 2

        let frame = NSRect(x: x, y: y, width: width, height: height)
        window = NSWindow(
            contentRect: frame,
            styleMask: [.titled, .closable, .resizable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Dynamic Horizon Sync"
        window.minSize = NSSize(width: 700, height: 500)
        window.isReleasedWhenClosed = false
        window.titlebarAppearsTransparent = true
        window.backgroundColor = NSColor(red: 15/255, green: 17/255, blue: 23/255, alpha: 1)

        // Splash / loading label
        splash = NSTextField(labelWithString: "Starting Dynamic Horizon Sync...")
        splash.font = NSFont.systemFont(ofSize: 16, weight: .medium)
        splash.textColor = NSColor(white: 0.6, alpha: 1)
        splash.alignment = .center
        splash.frame = NSRect(x: 0, y: height/2 - 20, width: width, height: 40)
        splash.autoresizingMask = [.width, .minYMargin, .maxYMargin]

        let container = NSView(frame: NSRect(x: 0, y: 0, width: width, height: height))
        container.wantsLayer = true
        container.layer?.backgroundColor = NSColor(red: 15/255, green: 17/255, blue: 23/255, alpha: 1).cgColor
        container.addSubview(splash)
        window.contentView = container
        window.makeKeyAndOrderFront(nil)

        // Start server, then load WebView
        server.start()
        server.waitUntilReady { [weak self] ok in
            guard let self = self else { return }
            if ok {
                self.loadWebView()
            } else {
                self.splash.stringValue = "Failed to start server.\nCheck that port \(self.port) is free."
                self.splash.textColor = NSColor.systemRed
            }
        }
    }

    func loadWebView() {
        let config = WKWebViewConfiguration()
        config.preferences.setValue(true, forKey: "developerExtrasEnabled")

        webView = WKWebView(frame: window.contentView!.bounds, configuration: config)
        webView.autoresizingMask = [.width, .height]
        webView.navigationDelegate = self
        webView.isHidden = true
        webView.setValue(false, forKey: "drawsBackground") // transparent until loaded

        window.contentView?.addSubview(webView)

        let url = URL(string: "http://127.0.0.1:\(port)/")!
        webView.load(URLRequest(url: url))
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        // Fade in webview, remove splash
        splash.removeFromSuperview()
        webView.isHidden = false
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }

    func applicationWillTerminate(_ notification: Notification) {
        server.stop()
    }
}

// MARK: - Main Menu

func createMainMenu() {
    let mainMenu = NSMenu()

    // App menu
    let appMenuItem = NSMenuItem()
    let appMenu = NSMenu()
    appMenu.addItem(withTitle: "About Dynamic Horizon Sync", action: #selector(NSApplication.orderFrontStandardAboutPanel(_:)), keyEquivalent: "")
    appMenu.addItem(NSMenuItem.separator())
    appMenu.addItem(withTitle: "Quit Dynamic Horizon Sync", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
    appMenuItem.submenu = appMenu
    mainMenu.addItem(appMenuItem)

    // Edit menu (for copy/paste in webview)
    let editMenuItem = NSMenuItem()
    let editMenu = NSMenu(title: "Edit")
    editMenu.addItem(withTitle: "Undo", action: Selector(("undo:")), keyEquivalent: "z")
    editMenu.addItem(withTitle: "Redo", action: Selector(("redo:")), keyEquivalent: "Z")
    editMenu.addItem(NSMenuItem.separator())
    editMenu.addItem(withTitle: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
    editMenu.addItem(withTitle: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
    editMenu.addItem(withTitle: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
    editMenu.addItem(withTitle: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
    editMenuItem.submenu = editMenu
    mainMenu.addItem(editMenuItem)

    // View menu
    let viewMenuItem = NSMenuItem()
    let viewMenu = NSMenu(title: "View")
    viewMenu.addItem(withTitle: "Reload", action: #selector(WKWebView.reload(_:)), keyEquivalent: "r")
    viewMenuItem.submenu = viewMenu
    mainMenu.addItem(viewMenuItem)

    // Window menu
    let windowMenuItem = NSMenuItem()
    let windowMenu = NSMenu(title: "Window")
    windowMenu.addItem(withTitle: "Minimize", action: #selector(NSWindow.performMiniaturize(_:)), keyEquivalent: "m")
    windowMenu.addItem(withTitle: "Close", action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w")
    windowMenuItem.submenu = windowMenu
    mainMenu.addItem(windowMenuItem)

    NSApplication.shared.mainMenu = mainMenu
    NSApplication.shared.windowsMenu = windowMenu
}

// MARK: - Entry point

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
createMainMenu()
app.run()
