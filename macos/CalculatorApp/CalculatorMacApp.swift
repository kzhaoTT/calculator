import AppKit
import CalculatorCore
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    var keyMonitor: Any?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        ResourceProvider.registerCalculatorFont()

        if let icon = Self.renderAppIcon(size: 512) {
            NSApp.applicationIconImage = icon
        }

        NSApp.activate(ignoringOtherApps: true)
    }

    private static func renderAppIcon(size: CGFloat) -> NSImage? {
        let view = WindowsCalculatorAppIcon(size: size * 0.88)
            .frame(width: size, height: size)
        let renderer = ImageRenderer(content: view)
        renderer.scale = 1.0
        return renderer.nsImage
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }
}

private extension Bundle {
    static var calculatorCoreIconURL: URL? {
        // Locate CalculatorAppIcon.png in CalculatorCore's resource bundle
        for bundle in Bundle.allBundles {
            if let url = bundle.url(forResource: "CalculatorAppIcon", withExtension: "png") {
                return url
            }
        }
        return nil
    }
}

@main
struct CalculatorMacApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var appVM = ApplicationViewModel()

    var body: some Scene {
        WindowGroup("Calculator") {
            MainPageView(appVM: appVM)
                .frame(minWidth: 320, minHeight: appVM.isAlwaysOnTop ? 220 : 500)
                .background(WindowConfigurator(appVM: appVM, appDelegate: appDelegate))
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 340, height: 540)
        .commands {
            CommandGroup(replacing: .appSettings) {
                Button("Settings…") {
                    appVM.openSettings()
                }
                .keyboardShortcut(",", modifiers: .command)
            }

            CommandGroup(replacing: .pasteboard) {
                Button("Copy") {
                    appVM.copyCurrentResult()
                }
                .keyboardShortcut("c", modifiers: .command)

                Button("Paste") {
                    appVM.pasteIntoCurrentMode()
                }
                .keyboardShortcut("v", modifiers: .command)
            }

            CommandMenu("Mode") {
                Section("Calculator") {
                    Button("Standard") { appVM.selectMode(.standard) }
                        .keyboardShortcut("1", modifiers: .option)
                    Button("Scientific") { appVM.selectMode(.scientific) }
                        .keyboardShortcut("2", modifiers: .option)
                    Button("Graphing") { appVM.selectMode(.graphing) }
                        .keyboardShortcut("3", modifiers: .option)
                    Button("Programmer") { appVM.selectMode(.programmer) }
                        .keyboardShortcut("4", modifiers: .option)
                    Button("Date calculation") { appVM.selectMode(.date) }
                        .keyboardShortcut("5", modifiers: .option)
                }

                Divider()

                Menu("Converter") {
                    ForEach(ViewMode.converterModes) { mode in
                        Button(mode.displayName) {
                            appVM.selectMode(mode)
                        }
                    }
                }

                Divider()

                Button(appVM.isAlwaysOnTop ? "Back to full view" : "Keep on top") {
                    appVM.toggleAlwaysOnTop()
                }
                .disabled(appVM.mode != .standard && !appVM.isAlwaysOnTop)
            }
        }
    }
}

/// Bridges SwiftUI window to native AppKit `NSWindow` for Fluent titlebar styling, Always-on-Top floating level,
/// compact overlay resizing, and global local keyboard shortcut monitoring.
private struct WindowConfigurator: NSViewRepresentable {
    let appVM: ApplicationViewModel
    let appDelegate: AppDelegate

    func makeCoordinator() -> Coordinator {
        Coordinator(appVM: appVM, appDelegate: appDelegate)
    }

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            if let window = view.window {
                context.coordinator.attach(to: window)
            }
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        if let window = nsView.window {
            context.coordinator.attach(to: window)
        }
    }

    @MainActor
    final class Coordinator {
        private let appVM: ApplicationViewModel
        private let appDelegate: AppDelegate
        private weak var attachedWindow: NSWindow?
        private var savedNormalFrame: NSRect?

        init(appVM: ApplicationViewModel, appDelegate: AppDelegate) {
            self.appVM = appVM
            self.appDelegate = appDelegate
        }

        func attach(to window: NSWindow) {
            guard attachedWindow !== window else { return }
            attachedWindow = window

            window.titlebarAppearsTransparent = true
            window.titleVisibility = .hidden
            window.styleMask.insert(.fullSizeContentView)
            window.isMovableByWindowBackground = true
            window.backgroundColor = .clear
            window.minSize = NSSize(width: 320, height: 500)

            appVM.onAlwaysOnTopChanged = { [weak self, weak window] enabled in
                guard let self, let window else { return }
                if enabled {
                    self.savedNormalFrame = window.frame
                    window.level = .floating
                    window.minSize = NSSize(width: 240, height: 220)
                    let topLeftY = window.frame.maxY
                    let aotFrame = NSRect(x: window.frame.minX, y: topLeftY - 394, width: 320, height: 394)
                    window.setFrame(aotFrame, display: true, animate: true)
                } else {
                    window.level = .normal
                    window.minSize = NSSize(width: 320, height: 500)
                    if let saved = self.savedNormalFrame {
                        window.setFrame(saved, display: true, animate: true)
                    }
                }
            }

            if appDelegate.keyMonitor == nil {
                appDelegate.keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak appVM] event in
                    guard let appVM else { return event }
                    if MainActor.assumeIsolated({ appVM.handleKeyEvent(event) }) {
                        return nil
                    }
                    return event
                }
            }
        }
    }
}
