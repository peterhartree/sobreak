import Cocoa
import SwiftUI
import IOKit.pwr_mgt

// MARK: - Configuration

struct Config {
    #if DEBUG
    static let workDuration: TimeInterval = 5           // 5 seconds for testing
    static let amberWarning: TimeInterval = 3            // amber at 3s
    static let snoozeDuration: TimeInterval = 600        // 10 minutes (first snooze)
    static let shortSnoozeDuration: TimeInterval = 300   // 5 minutes (subsequent snoozes)
    static let gracePeriod: TimeInterval = 120           // 2 minutes
    static let nagAfter: TimeInterval = 300              // 5 minutes
    static let finalExtension: TimeInterval = 300        // 5 more minutes
    #else
    static let workDuration: TimeInterval = 3600         // 60 minutes
    static let amberWarning: TimeInterval = 3300         // 55 minutes
    static let snoozeDuration: TimeInterval = 600        // 10 minutes (first snooze)
    static let shortSnoozeDuration: TimeInterval = 300   // 5 minutes (subsequent snoozes)
    static let gracePeriod: TimeInterval = 120           // 2 minutes
    static let nagAfter: TimeInterval = 300              // 5 minutes
    static let finalExtension: TimeInterval = 300        // 5 more minutes
    #endif

    static let assertionCheckInterval: TimeInterval = 10
    static let menuBarUpdateInterval: TimeInterval = 1
}

// MARK: - AI Wow Colour Palette

struct Palette {
    static let paper = NSColor(red: 1.0, green: 0.976, blue: 0.890, alpha: 1.0)        // #FFF9E3
    static let paperDark = NSColor(red: 0.949, green: 0.941, blue: 0.898, alpha: 1.0)   // #F2F0E5
    static let ink = NSColor(red: 0.063, green: 0.059, blue: 0.059, alpha: 1.0)          // #100F0F
    static let gray = NSColor(red: 0.529, green: 0.522, blue: 0.502, alpha: 1.0)         // #878580

    static let vividPink = NSColor(red: 0.910, green: 0.212, blue: 0.561, alpha: 1.0)    // #E8368F
    static let vividOrange = NSColor(red: 0.910, green: 0.459, blue: 0.039, alpha: 1.0)  // #E8750A
    static let vividYellow = NSColor(red: 0.941, green: 0.769, blue: 0.188, alpha: 1.0)  // #F0C430
    static let vividCyan = NSColor(red: 0.078, green: 0.722, blue: 0.651, alpha: 1.0)    // #14B8A6
    static let vividPurple = NSColor(red: 0.608, green: 0.427, blue: 0.843, alpha: 1.0)  // #9B6DD7

    // SwiftUI versions
    static let suiPaper = Color(red: 1.0, green: 0.976, blue: 0.890)
    static let suiPaperDark = Color(red: 0.949, green: 0.941, blue: 0.898)
    static let suiInk = Color(red: 0.063, green: 0.059, blue: 0.059)
    static let suiGray = Color(red: 0.529, green: 0.522, blue: 0.502)
    static let suiPink = Color(red: 0.910, green: 0.212, blue: 0.561)
    static let suiOrange = Color(red: 0.910, green: 0.459, blue: 0.039)
    static let suiYellow = Color(red: 0.941, green: 0.769, blue: 0.188)
    static let suiCyan = Color(red: 0.078, green: 0.722, blue: 0.651)
    static let suiPurple = Color(red: 0.608, green: 0.427, blue: 0.843)
}

// MARK: - Messages

struct Messages {
    static let firstAlert = [
        "You've been at it for an hour. Nice focus! Ready for a break?",
        "One hour of solid work—time to step away for a bit?",
        "An hour already! Your eyes and brain would love a break.",
        "You've been going strong for an hour. Break time?",
        "Sixty minutes of focus. How about a change of scenery?",
    ]

    static let snoozeEscalation = [
        "Still going? Just checking in—break whenever you're ready.",
        "That's another snooze. Your future self would appreciate a stretch.",
        "Quite the streak! But seriously, a short break works wonders.",
        "Three snoozes deep. Your chair is starting to worry about you.",
        "You're very committed. A five-minute break won't undo that.",
        "At this point, taking a break would be the rebellious thing to do.",
    ]

    static let graceCountdown = "Wrapping up..."
    static let nagMessage = "Still here? You said you'd take a break."
    static let nagSubtle = "Your break is waiting for you."
}

// MARK: - Doge Images

enum DogeImage: String, CaseIterable {
    case happy = "doge-happy"
    case nudge = "doge-nudge"
    case sassy = "doge-sassy"
    case stretch = "doge-stretch"

    var nsImage: NSImage? {
        let bundle = Bundle.main
        if let url = bundle.url(forResource: rawValue, withExtension: "png", subdirectory: "images") {
            return NSImage(contentsOf: url)
        }
        // Fallback: check relative to executable
        let execURL = URL(fileURLWithPath: CommandLine.arguments[0])
        let resourcesURL = execURL.deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent("Resources/images/\(rawValue).png")
        return NSImage(contentsOf: resourcesURL)
    }

    /// Pick the right doge for the current situation
    static func forAlert(snoozeCount: Int) -> DogeImage {
        if snoozeCount == 0 { return .happy }
        if snoozeCount <= 2 { return .nudge }
        return .sassy
    }

    static var forGrace: DogeImage { .stretch }
    static var forNag: DogeImage { .sassy }
}

// MARK: - App State

enum AppPhase {
    case idle
    case working
    case alertPending
    case alertShown
    case graceCountdown
    case nagging
}

// MARK: - Power Assertion Checker

class MediaDetector {
    /// Returns true if any process (other than ourselves) holds a display-sleep power assertion,
    /// which typically indicates video playback or a video call is active.
    static func isMediaActive() -> Bool {
        let (active, details) = checkAssertions()
        NSLog("[TakeBreak] Media check: active=\(active)\(details.isEmpty ? "" : " — \(details)")")
        return active
    }

    /// Check assertions and return (isActive, description of what was found)
    static func checkAssertions() -> (Bool, String) {
        var assertions: Unmanaged<CFDictionary>?
        let result = IOPMCopyAssertionsByProcess(&assertions)
        guard result == kIOReturnSuccess,
              let cfDict = assertions?.takeRetainedValue() else {
            return (false, "IOPMCopyAssertionsByProcess failed")
        }

        let mediaTypes: Set<String> = [
            "PreventUserIdleDisplaySleep",
            "NoDisplaySleepAssertion",
        ]

        let selfPID = Int(ProcessInfo.processInfo.processIdentifier)
        var found: [(pid: Int, type: String, name: String)] = []

        // IOPMCopyAssertionsByProcess returns {pid_number: [assertion_dict]}
        let dict = cfDict as NSDictionary
        for (pidKey, value) in dict {
            guard let pid = (pidKey as? NSNumber)?.intValue,
                  pid != selfPID,
                  let assertionList = value as? [[String: Any]] else { continue }

            for assertion in assertionList {
                if let type = assertion["AssertionType"] as? String ?? assertion["AssertType"] as? String,
                   mediaTypes.contains(type) {
                    let name = assertion["Process Name"] as? String ?? "pid:\(pid)"
                    found.append((pid: pid, type: type, name: name))
                }
            }
        }

        if found.isEmpty {
            return (false, "no display-sleep assertions held")
        }

        let details = found.map { "\($0.name)(\($0.pid)):\($0.type)" }.joined(separator: ", ")
        return (true, details)
    }
}

// MARK: - Overlay Window

class OverlayWindowController: NSObject, ObservableObject {
    private enum Metrics {
        static let centerSize = NSSize(width: 420, height: 420)
        static let topSize = NSSize(width: 340, height: 130)
        static let topShadowCompensation: CGFloat = 0
    }

    private var centerWindow: NSWindow?
    private var topWindow: NSWindow?

    @Published var message: String = ""
    @Published var subtitle: String = ""
    @Published var showSnooze: Bool = true
    @Published var showTakeBreak: Bool = true
    @Published var showLockNow: Bool = false
    @Published var showFiveMore: Bool = false
    @Published var countdownText: String = ""
    @Published var showCountdown: Bool = false
    @Published var dogeImage: NSImage?
    @Published var isCompact: Bool = false
    @Published var snoozeLabel: String = "Snooze 10 min"

    var onSnooze: (() -> Void)?
    var onTakeBreak: (() -> Void)?
    var onLockNow: (() -> Void)?
    var onFiveMore: (() -> Void)?

    enum Position { case center, top }

    func show(playSound: Bool = true, position: Position = .center) {
        createWindowsIfNeeded()

        let activeScreen = activeScreenForMouse()
        let window = window(for: position)

        positionWindow(window, on: activeScreen, position: position)
        inactiveWindow(for: position)?.orderOut(nil)

        window?.orderFrontRegardless()
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        #if DEBUG
        let pos = position
        NSLog("=== Window positioning (immediate) ===")
        NSLog("Position: \(pos == .center ? "center" : "top")")
        NSLog("Screen '\(activeScreen.localizedName)': frame=\(activeScreen.frame)")
        NSLog("Window frame: \(window?.frame ?? .zero)")
        NSLog("ContentView frame: \(window?.contentView?.frame ?? .zero)")
        if let hv = window?.contentView {
            NSLog("ContentView fittingSize: \(hv.fittingSize)")
        }
        // Check again after SwiftUI layout
        let windowRef = window
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            guard let win = windowRef else { return }
            NSLog("=== Window positioning (after 0.5s) ===")
            NSLog("Window frame: \(win.frame)")
            NSLog("ContentView frame: \(win.contentView?.frame ?? .zero)")
            if let hv = win.contentView {
                NSLog("ContentView fittingSize: \(hv.fittingSize)")
            }
        }
        #endif

        if playSound {
            NSSound(named: "Purr")?.play()
        }
    }

    func dismiss() {
        centerWindow?.orderOut(nil)
        topWindow?.orderOut(nil)
    }

    private func createWindowsIfNeeded() {
        if centerWindow == nil {
            centerWindow = makeWindow(
                size: Metrics.centerSize,
                rootView: OverlayView(controller: self, layout: .center)
                    .frame(width: Metrics.centerSize.width, height: Metrics.centerSize.height)
            )
        }

        if topWindow == nil {
            topWindow = makeWindow(
                size: Metrics.topSize,
                rootView: OverlayView(controller: self, layout: .top)
                    .frame(width: Metrics.topSize.width, height: Metrics.topSize.height, alignment: .top)
            )
        }
    }

    private func makeWindow<Content: View>(size: NSSize, rootView: Content) -> NSWindow {
        let hostingView = NSHostingView(
            rootView: rootView
        )
        hostingView.frame = NSRect(origin: .zero, size: size)

        let win = NSWindow(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        win.contentView = hostingView
        win.isReleasedWhenClosed = false
        win.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.screenSaverWindow)))
        win.isMovableByWindowBackground = true
        win.backgroundColor = .clear
        win.isOpaque = false
        win.hasShadow = true
        win.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        win.contentMinSize = size
        win.contentMaxSize = size
        win.setContentSize(size)
        return win
    }

    private func activeScreenForMouse() -> NSScreen {
        let mouseLocation = NSEvent.mouseLocation
        return NSScreen.screens.first(where: { $0.frame.contains(mouseLocation) })
            ?? NSScreen.main
            ?? NSScreen.screens.first!
    }

    private func window(for position: Position) -> NSWindow? {
        switch position {
        case .center:
            return centerWindow
        case .top:
            return topWindow
        }
    }

    private func inactiveWindow(for position: Position) -> NSWindow? {
        switch position {
        case .center:
            return topWindow
        case .top:
            return centerWindow
        }
    }

    private func positionWindow(_ window: NSWindow?, on screen: NSScreen, position: Position) {
        guard let window else { return }

        let size = window.frame.size
        let screenFrame = screen.frame
        let origin: NSPoint

        switch position {
        case .center:
            origin = NSPoint(
                x: screenFrame.midX - size.width / 2,
                y: screenFrame.midY - size.height / 2
            )
        case .top:
            // Use visibleFrame so the dialog sits below the menu bar / notch
            let visibleFrame = screen.visibleFrame
            origin = NSPoint(
                x: screenFrame.midX - size.width / 2,
                y: visibleFrame.maxY - size.height + Metrics.topShadowCompensation
            )
        }

        window.setFrameOrigin(origin)
    }
}

// MARK: - Rainbow Bar

struct RainbowBar: View {
    @State private var offset: CGFloat = 0

    let colors: [Color] = [
        Color(red: 0.910, green: 0.271, blue: 0.235),  // red
        Color(red: 0.910, green: 0.459, blue: 0.039),  // orange
        Color(red: 0.941, green: 0.769, blue: 0.188),  // yellow
        Color(red: 0.216, green: 0.780, blue: 0.349),  // green
        Color(red: 0.078, green: 0.722, blue: 0.651),  // cyan
        Color(red: 0.322, green: 0.506, blue: 0.863),  // blue
        Color(red: 0.608, green: 0.427, blue: 0.843),  // purple
        Color(red: 0.910, green: 0.212, blue: 0.561),  // pink
        Color(red: 0.910, green: 0.271, blue: 0.235),  // red (loop)
    ]

    var body: some View {
        GeometryReader { geo in
            LinearGradient(
                colors: colors,
                startPoint: UnitPoint(x: offset, y: 0.5),
                endPoint: UnitPoint(x: offset + 1, y: 0.5)
            )
            .frame(height: 5)
        }
        .frame(height: 5)
        .onAppear {
            withAnimation(.linear(duration: 4).repeatForever(autoreverses: false)) {
                offset = -1
            }
        }
    }
}

// MARK: - Overlay View (AI Wow styled)

struct OverlayView: View {
    enum Layout {
        case center
        case top
    }

    @ObservedObject var controller: OverlayWindowController
    let layout: Layout

    var body: some View {
        VStack(spacing: 0) {
            RainbowBar()
                .clipShape(UnevenRoundedRectangle(topLeadingRadius: 16, topTrailingRadius: 16))

            content
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: layout == .top ? .top : .center)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.black.opacity(0.08), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.15), radius: 20, y: 8)
    }

    @ViewBuilder
    private var content: some View {
        if layout == .top {
            compactContent
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        } else {
            fullContent
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        }
    }

    // Two-column compact layout: doge on left, text+buttons on right
    private var compactContent: some View {
        HStack(spacing: 16) {
            if let img = controller.dogeImage {
                Image(nsImage: img)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 80, height: 80)
                    .clipShape(Circle())
                    .shadow(color: Palette.suiPink.opacity(0.3), radius: 6, y: 3)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text(controller.message)
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundColor(Palette.suiInk)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)

                if !controller.subtitle.isEmpty {
                    Text(controller.subtitle)
                        .font(.system(size: 12, weight: .regular, design: .rounded))
                        .foregroundColor(Palette.suiGray)
                }

                HStack(spacing: 10) {
                    if controller.showCountdown {
                        Text(controller.countdownText)
                            .font(.system(size: 28, weight: .light, design: .rounded))
                            .monospacedDigit()
                            .foregroundColor(Palette.suiOrange)
                    }

                    actionButtons
                }
            }
        }
        .padding(.leading, 20)
        .padding(.trailing, 16)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Palette.suiPaper)
    }

    // Full centered layout for break alerts and nag
    private var fullContent: some View {
        VStack(spacing: 16) {
            Spacer().frame(height: 8)

            if let img = controller.dogeImage {
                Image(nsImage: img)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 120, height: 120)
                    .clipShape(Circle())
                    .shadow(color: Palette.suiPink.opacity(0.3), radius: 8, y: 4)
            }

            Text(controller.message)
                .font(.system(size: 17, weight: .semibold, design: .rounded))
                .foregroundColor(Palette.suiInk)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 28)

            if !controller.subtitle.isEmpty {
                Text(controller.subtitle)
                    .font(.system(size: 13, weight: .regular, design: .rounded))
                    .foregroundColor(Palette.suiGray)
            }

            if controller.showCountdown {
                Text(controller.countdownText)
                    .font(.system(size: 40, weight: .light, design: .rounded))
                    .monospacedDigit()
                    .foregroundColor(Palette.suiOrange)
            }

            Spacer().frame(height: 4)

            actionButtons

            Spacer().frame(height: 12)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        .background(Palette.suiPaper)
    }

    // Shared buttons
    private var actionButtons: some View {
        HStack(spacing: 14) {
            if controller.showSnooze {
                Button(action: { controller.onSnooze?() }) {
                    Text(controller.snoozeLabel)
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(Palette.suiGray.opacity(0.3), lineWidth: 1.5)
                                .background(RoundedRectangle(cornerRadius: 10).fill(Palette.suiPaperDark))
                        )
                        .foregroundColor(Palette.suiInk)
                }
                .buttonStyle(.plain)
            }

            if controller.showTakeBreak {
                Button(action: { controller.onTakeBreak?() }) {
                    Text("Take a break")
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .padding(.horizontal, 24)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Palette.suiPink)
                        )
                        .foregroundColor(.white)
                }
                .buttonStyle(.plain)
            }

            if controller.showLockNow {
                Button(action: { controller.onLockNow?() }) {
                    Text("Lock now")
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .padding(.horizontal, 24)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Palette.suiCyan)
                        )
                        .foregroundColor(.white)
                }
                .buttonStyle(.plain)
            }

            if controller.showFiveMore {
                Button(action: { controller.onFiveMore?() }) {
                    Text("5 more minutes")
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(Palette.suiGray.opacity(0.3), lineWidth: 1.5)
                                .background(RoundedRectangle(cornerRadius: 10).fill(Palette.suiPaperDark))
                        )
                        .foregroundColor(Palette.suiInk)
                }
                .buttonStyle(.plain)
            }
        }
    }
}

// MARK: - App Controller

class TakeBreakController: NSObject {
    private var statusItem: NSStatusItem!
    private var overlayController = OverlayWindowController()
    private var dimWindows: [NSWindow] = []

    private var phase: AppPhase = .idle
    private var workStartTime: Date?
    private var snoozeCount: Int = 0
    private var snoozeUntil: Date?
    private var graceStartTime: Date?
    private var graceDuration: TimeInterval = Config.gracePeriod
    private var customWorkDuration: TimeInterval?

    /// The active work duration — custom pomodoro or default 60 min.
    private var effectiveWorkDuration: TimeInterval {
        customWorkDuration ?? Config.workDuration
    }

    /// Amber warning starts 5 minutes before the effective deadline.
    private var effectiveAmberWarning: TimeInterval {
        max(0, effectiveWorkDuration - (Config.workDuration - Config.amberWarning))
    }

    private var menuBarTimer: Timer?
    private var assertionCheckTimer: Timer?
    private var snoozeTimer: Timer?
    private var graceTimer: Timer?
    private var nagTimer: Timer?

    private var confirmationWindow: NSWindow?

    func start() {
        setupMenuBar()
        setupNotifications()
        setupTimers()
        setupGlobalHotkey()
        startWorking()
    }

    // MARK: - Menu Bar

    private func setupMenuBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        updateMenuBarDisplay()

        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Take Break", action: nil, keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())

        let statusItem = NSMenuItem(title: "Status: Starting...", action: nil, keyEquivalent: "")
        statusItem.tag = 100
        menu.addItem(statusItem)

        menu.addItem(NSMenuItem.separator())

        let pomo25 = NSMenuItem(title: "Start 25 min timer", action: #selector(startPomodoro25), keyEquivalent: "")
        pomo25.tag = 200
        menu.addItem(pomo25)

        let pomo45 = NSMenuItem(title: "Start 45 min timer", action: #selector(startPomodoro45), keyEquivalent: "")
        pomo45.tag = 201
        menu.addItem(pomo45)

        let cancelPomo = NSMenuItem(title: "Cancel timer", action: #selector(cancelPomodoro), keyEquivalent: "")
        cancelPomo.tag = 202
        cancelPomo.isHidden = true
        menu.addItem(cancelPomo)

        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(quitApp), keyEquivalent: "q"))

        self.statusItem.menu = menu
    }

    private func updateMenuBarDisplay() {
        guard let button = statusItem.button else { return }

        switch phase {
        case .idle:
            button.title = "☀️"
            updateStatusMenuItem("Screen locked—timer paused")

        case .working, .alertPending:
            let elapsed = workStartTime.map { Date().timeIntervalSince($0) } ?? 0
            let minutes = Int(elapsed) / 60
            let remaining = max(0, Int(effectiveWorkDuration - elapsed))
            let remainingMin = (remaining + 59) / 60

            if elapsed >= effectiveWorkDuration {
                // Overdue - solid red circle
                button.attributedTitle = NSAttributedString(
                    string: "●",
                    attributes: [.foregroundColor: NSColor.systemRed, .font: NSFont.systemFont(ofSize: 16, weight: .bold), .baselineOffset: -2.0]
                )
            } else if elapsed >= effectiveAmberWarning {
                // Last 5 minutes - countdown in orange
                button.attributedTitle = NSAttributedString(
                    string: "\(remainingMin)m",
                    attributes: [.foregroundColor: NSColor.systemOrange, .font: NSFont.monospacedDigitSystemFont(ofSize: 13, weight: .semibold)]
                )
            } else {
                // Normal - black circle
                button.attributedTitle = NSAttributedString(
                    string: "●",
                    attributes: [.foregroundColor: NSColor.labelColor, .font: NSFont.systemFont(ofSize: 16), .baselineOffset: -2.0]
                )
            }

            let status = phase == .alertPending ? "Break due (video/call active)" : "Working"
            updateStatusMenuItem("\(status) — \(minutes) min")

        case .alertShown:
            button.attributedTitle = NSAttributedString(
                string: "●",
                attributes: [.foregroundColor: NSColor.systemRed, .font: NSFont.systemFont(ofSize: 14, weight: .bold)]
            )
            updateStatusMenuItem("Break reminder showing")

        case .graceCountdown:
            let remaining = graceRemainingSeconds()
            let m = remaining / 60
            let s = remaining % 60
            button.attributedTitle = NSAttributedString(
                string: String(format: "%d:%02d", m, s),
                attributes: [.foregroundColor: Palette.vividCyan, .font: NSFont.monospacedDigitSystemFont(ofSize: 13, weight: .semibold)]
            )
            updateStatusMenuItem("Wrapping up — \(remaining)s")

        case .nagging:
            button.attributedTitle = NSAttributedString(
                string: "●",
                attributes: [.foregroundColor: NSColor.systemRed, .font: NSFont.systemFont(ofSize: 14, weight: .bold)]
            )
            updateStatusMenuItem("Break overdue!")
        }
    }

    private func updateStatusMenuItem(_ text: String) {
        if let menu = statusItem.menu, let item = menu.item(withTag: 100) {
            item.title = text
        }
    }

    // MARK: - Notifications (Screen Lock/Unlock)

    private func setupNotifications() {
        let dnc = DistributedNotificationCenter.default()

        dnc.addObserver(
            self,
            selector: #selector(screenDidUnlock),
            name: NSNotification.Name("com.apple.screenIsUnlocked"),
            object: nil
        )

        dnc.addObserver(
            self,
            selector: #selector(screenDidLock),
            name: NSNotification.Name("com.apple.screenIsLocked"),
            object: nil
        )
    }

    @objc private func screenDidUnlock() {
        NSLog("[TakeBreak] Screen unlocked")
        DispatchQueue.main.async { [weak self] in
            self?.startWorking()
        }
    }

    @objc private func screenDidLock() {
        NSLog("[TakeBreak] Screen locked — resetting all state")
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.cancelAllTimers()
            self.overlayController.dismiss()
            self.hideDim()
            self.phase = .idle
            self.workStartTime = nil
            self.snoozeCount = 0
            self.snoozeUntil = nil
            self.graceStartTime = nil
            self.customWorkDuration = nil
            self.updatePomodoroMenuItems()
            self.updateMenuBarDisplay()
        }
    }

    // MARK: - Timer Setup

    private func setupTimers() {
        menuBarTimer = Timer.scheduledTimer(withTimeInterval: Config.menuBarUpdateInterval, repeats: true) { [weak self] _ in
            self?.tick()
        }

        assertionCheckTimer = Timer.scheduledTimer(withTimeInterval: Config.assertionCheckInterval, repeats: true) { [weak self] _ in
            self?.checkAssertions()
        }
    }

    private func cancelAllTimers() {
        snoozeTimer?.invalidate()
        snoozeTimer = nil
        graceTimer?.invalidate()
        graceTimer = nil
        nagTimer?.invalidate()
        nagTimer = nil
    }

    // MARK: - Core Logic

    private func startWorking() {
        cancelAllTimers()
        hideDim()
        overlayController.dismiss()
        phase = .working
        workStartTime = workStartTime ?? Date()
        snoozeCount = 0
        snoozeUntil = nil
        graceStartTime = nil
        NSLog("[TakeBreak] Started working, timer from \(workStartTime!)")
        updateMenuBarDisplay()
    }

    private func tick() {
        updateMenuBarDisplay()

        if phase == .graceCountdown {
            let remaining = graceRemainingSeconds()
            overlayController.countdownText = formatCountdown(remaining)
            if remaining <= 0 {
                showNag()
            }
        }

        if phase == .working, let start = workStartTime {
            // Don't trigger during snooze period
            if let snoozeDeadline = snoozeUntil, Date() < snoozeDeadline {
                return
            }

            let elapsed = Date().timeIntervalSince(start)
            if elapsed >= effectiveWorkDuration {
                if MediaDetector.isMediaActive() {
                    if phase != .alertPending {
                        NSLog("[TakeBreak] Alert deferred — media/call active")
                    }
                    phase = .alertPending
                } else {
                    showBreakAlert()
                }
            }
        }
    }

    private func checkAssertions() {
        if phase == .alertPending && !MediaDetector.isMediaActive() {
            NSLog("[TakeBreak] Media no longer active — showing deferred alert")
            showBreakAlert()
        }
    }

    // MARK: - Break Alert

    private func showBreakAlert() {
        NSLog("[TakeBreak] Showing break alert (snoozeCount: \(snoozeCount))")
        phase = .alertShown

        let message: String
        if snoozeCount == 0 {
            message = Messages.firstAlert.randomElement()!
        } else {
            let index = min(snoozeCount - 1, Messages.snoozeEscalation.count - 1)
            message = Messages.snoozeEscalation[index]
        }

        let elapsed = workStartTime.map { Int(Date().timeIntervalSince($0)) / 60 } ?? 0

        overlayController.dogeImage = DogeImage.forAlert(snoozeCount: snoozeCount).nsImage
        overlayController.message = message
        overlayController.subtitle = snoozeCount > 0 ? "Snoozed \(snoozeCount) time\(snoozeCount == 1 ? "" : "s") · \(elapsed) min active" : "\(elapsed) min of continuous work"
        let nextSnoozeMins = snoozeCount == 0 ? Int(Config.snoozeDuration / 60) : Int(Config.shortSnoozeDuration / 60)
        overlayController.snoozeLabel = "Snooze \(nextSnoozeMins) min"
        overlayController.showSnooze = true
        overlayController.showTakeBreak = true
        overlayController.showLockNow = false
        overlayController.showFiveMore = false
        overlayController.showCountdown = false

        overlayController.onSnooze = { [weak self] in self?.snooze() }
        overlayController.onTakeBreak = { [weak self] in self?.takeBreak() }

        overlayController.isCompact = false
        showDim(opacity: 0.4)
        overlayController.show(position: .center)
        updateMenuBarDisplay()
    }

    // MARK: - Snooze

    private func snooze() {
        snoozeCount += 1
        let duration = snoozeCount <= 1 ? Config.snoozeDuration : Config.shortSnoozeDuration
        phase = .working
        snoozeUntil = Date().addingTimeInterval(duration)
        hideDim()
        overlayController.dismiss()
        NSLog("[TakeBreak] Snoozed (count: \(snoozeCount), duration: \(Int(duration/60)) min), next alert after \(snoozeUntil!)")

        snoozeTimer?.invalidate()
        snoozeTimer = Timer.scheduledTimer(withTimeInterval: duration, repeats: false) { [weak self] _ in
            guard let self = self, self.phase == .working else { return }
            self.snoozeUntil = nil
            NSLog("[TakeBreak] Snooze timer fired, checking media...")
            if MediaDetector.isMediaActive() {
                NSLog("[TakeBreak] Media active after snooze — deferring alert")
                self.phase = .alertPending
            } else {
                NSLog("[TakeBreak] No media active — showing break alert")
                self.showBreakAlert()
            }
        }

        updateMenuBarDisplay()
    }

    // MARK: - Take a Break (Grace Period)

    private func takeBreak() {
        NSLog("[TakeBreak] User chose 'Take a break' — starting grace countdown")
        phase = .graceCountdown
        graceStartTime = Date()
        graceDuration = Config.gracePeriod

        overlayController.dogeImage = DogeImage.forGrace.nsImage
        overlayController.message = Messages.graceCountdown
        overlayController.subtitle = "Lock your screen when you're ready"
        overlayController.showSnooze = false
        overlayController.showTakeBreak = false
        overlayController.showLockNow = true
        overlayController.showFiveMore = false
        overlayController.showCountdown = true
        overlayController.countdownText = formatCountdown(Int(Config.gracePeriod))

        overlayController.onLockNow = { [weak self] in self?.lockScreen() }

        overlayController.isCompact = true
        showDim(opacity: 0.1)
        overlayController.show(playSound: false, position: .top)
        updateMenuBarDisplay()
    }

    // MARK: - Nag

    private func showNag() {
        NSLog("[TakeBreak] Grace period expired — showing nag")
        phase = .nagging

        overlayController.dogeImage = DogeImage.forNag.nsImage
        overlayController.message = Messages.nagMessage
        overlayController.subtitle = Messages.nagSubtle
        overlayController.showSnooze = false
        overlayController.showTakeBreak = false
        overlayController.showLockNow = true
        overlayController.showFiveMore = true
        overlayController.showCountdown = false

        overlayController.onLockNow = { [weak self] in self?.lockScreen() }
        overlayController.onFiveMore = { [weak self] in self?.fiveMoreMinutes() }

        overlayController.isCompact = false
        showDim(opacity: 0.4)
        overlayController.show(position: .center)
        updateMenuBarDisplay()
    }

    private func fiveMoreMinutes() {
        phase = .graceCountdown
        graceStartTime = Date()
        graceDuration = Config.finalExtension

        overlayController.dogeImage = DogeImage.forGrace.nsImage
        overlayController.message = "Five more minutes..."
        overlayController.subtitle = "Then it's really break time"
        overlayController.showSnooze = false
        overlayController.showTakeBreak = false
        overlayController.showLockNow = true
        overlayController.showFiveMore = false
        overlayController.showCountdown = true
        overlayController.countdownText = formatCountdown(Int(Config.finalExtension))

        overlayController.onLockNow = { [weak self] in self?.lockScreen() }

        overlayController.isCompact = true
        showDim(opacity: 0.1)
        overlayController.show(playSound: false, position: .top)
        updateMenuBarDisplay()
    }

    // MARK: - Screen Dim

    private func showDim(opacity: CGFloat = 0.4) {
        hideDim()
        for screen in NSScreen.screens {
            let win = NSWindow(
                contentRect: screen.frame,
                styleMask: [.borderless],
                backing: .buffered,
                defer: false
            )
            win.backgroundColor = NSColor.black.withAlphaComponent(opacity)
            win.isOpaque = false
            win.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.screenSaverWindow)) - 1)
            win.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
            win.ignoresMouseEvents = true
            win.isReleasedWhenClosed = false
            win.orderFrontRegardless()
            dimWindows.append(win)
        }
    }

    private func hideDim() {
        for win in dimWindows {
            win.orderOut(nil)
        }
        dimWindows.removeAll()
    }

    // MARK: - Lock Screen

    private func lockScreen() {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/pmset")
        task.arguments = ["displaysleepnow"]
        try? task.run()
    }

    // MARK: - Helpers

    private func graceRemainingSeconds() -> Int {
        guard let start = graceStartTime else { return 0 }
        let elapsed = Date().timeIntervalSince(start)
        return max(0, Int(graceDuration - elapsed))
    }

    private func formatCountdown(_ seconds: Int) -> String {
        let m = seconds / 60
        let s = seconds % 60
        return String(format: "%d:%02d", m, s)
    }

    // MARK: - Global Hotkey (Cmd+Option+T)

    private func setupGlobalHotkey() {
        NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            // Cmd+Option+T
            if event.modifierFlags.contains([.command, .option]),
               event.charactersIgnoringModifiers == "t" {
                DispatchQueue.main.async {
                    self?.startPomodoro(minutes: 25)
                    self?.showConfirmationToast("25 min timer started")
                }
            }
        }
        // Also monitor when app is focused
        NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if event.modifierFlags.contains([.command, .option]),
               event.charactersIgnoringModifiers == "t" {
                DispatchQueue.main.async {
                    self?.startPomodoro(minutes: 25)
                    self?.showConfirmationToast("25 min timer started")
                }
                return nil
            }
            return event
        }
    }

    private func showConfirmationToast(_ text: String) {
        confirmationWindow?.orderOut(nil)

        let label = NSTextField(labelWithString: text)
        label.font = NSFont.systemFont(ofSize: 14, weight: .medium)
        label.textColor = Palette.ink
        label.alignment = .center
        label.sizeToFit()

        let padding: CGFloat = 24
        let size = NSSize(width: label.frame.width + padding * 2, height: 40)
        label.frame = NSRect(x: padding, y: 8, width: label.frame.width, height: label.frame.height)

        let container = NSView(frame: NSRect(origin: .zero, size: size))
        container.wantsLayer = true
        container.layer?.backgroundColor = Palette.paper.cgColor
        container.layer?.cornerRadius = 10
        container.layer?.borderWidth = 1
        container.layer?.borderColor = NSColor.black.withAlphaComponent(0.08).cgColor
        container.addSubview(label)

        let screen = NSScreen.screens.first(where: { $0.frame.contains(NSEvent.mouseLocation) })
            ?? NSScreen.main ?? NSScreen.screens.first!
        let origin = NSPoint(
            x: screen.frame.midX - size.width / 2,
            y: screen.visibleFrame.maxY - size.height - 8
        )

        let win = NSWindow(contentRect: NSRect(origin: origin, size: size),
                           styleMask: [.borderless], backing: .buffered, defer: false)
        win.contentView = container
        win.isOpaque = false
        win.backgroundColor = .clear
        win.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.floatingWindow)))
        win.hasShadow = true
        win.isReleasedWhenClosed = false
        win.orderFrontRegardless()
        confirmationWindow = win

        NSSound(named: "Tink")?.play()

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
            self?.confirmationWindow?.orderOut(nil)
            self?.confirmationWindow = nil
        }
    }

    // MARK: - Pomodoro Timers

    @objc private func startPomodoro25() {
        startPomodoro(minutes: 25)
    }

    @objc private func startPomodoro45() {
        startPomodoro(minutes: 45)
    }

    private func startPomodoro(minutes: Int) {
        let duration = TimeInterval(minutes * 60)
        customWorkDuration = duration
        cancelAllTimers()
        hideDim()
        overlayController.dismiss()
        phase = .working
        workStartTime = Date()
        snoozeCount = 0
        snoozeUntil = nil
        graceStartTime = nil
        NSLog("[TakeBreak] Started \(minutes) min pomodoro timer")
        updatePomodoroMenuItems()
        updateMenuBarDisplay()
    }

    @objc private func cancelPomodoro() {
        customWorkDuration = nil
        cancelAllTimers()
        hideDim()
        overlayController.dismiss()
        phase = .working
        workStartTime = Date()
        snoozeCount = 0
        snoozeUntil = nil
        graceStartTime = nil
        NSLog("[TakeBreak] Cancelled pomodoro, back to default 60 min timer")
        updatePomodoroMenuItems()
        updateMenuBarDisplay()
    }

    private func updatePomodoroMenuItems() {
        guard let menu = statusItem.menu else { return }
        let hasCustom = customWorkDuration != nil
        menu.item(withTag: 200)?.isHidden = hasCustom  // "Start 25 min"
        menu.item(withTag: 201)?.isHidden = hasCustom  // "Start 45 min"
        menu.item(withTag: 202)?.isHidden = !hasCustom // "Cancel timer"
        if hasCustom {
            let mins = Int(customWorkDuration! / 60)
            menu.item(withTag: 202)?.title = "Cancel \(mins) min timer"
        }
    }

    @objc private func quitApp() {
        NSApplication.shared.terminate(nil)
    }
}

// MARK: - App Delegate

class AppDelegate: NSObject, NSApplicationDelegate {
    let controller = TakeBreakController()

    func applicationDidFinishLaunching(_ notification: Notification) {
        controller.start()
    }
}

// MARK: - Main

let app = NSApplication.shared
app.setActivationPolicy(.accessory)
let delegate = AppDelegate()
app.delegate = delegate
app.run()
