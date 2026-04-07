import Cocoa
import SwiftUI
import IOKit.pwr_mgt

// MARK: - Configuration

struct Config {
    #if DEBUG
    static let workDuration: TimeInterval = 60          // 1 minute for testing
    static let amberWarning: TimeInterval = 55           // amber at 55s
    static let snoozeDuration: TimeInterval = 600        // 10 minutes
    static let gracePeriod: TimeInterval = 120           // 2 minutes
    static let nagAfter: TimeInterval = 300              // 5 minutes
    static let finalExtension: TimeInterval = 300        // 5 more minutes
    #else
    static let workDuration: TimeInterval = 3600         // 60 minutes
    static let amberWarning: TimeInterval = 3300         // 55 minutes
    static let snoozeDuration: TimeInterval = 600        // 10 minutes
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
    static func isMediaActive() -> Bool {
        var assertions: Unmanaged<CFDictionary>?
        let result = IOPMCopyAssertionsByProcess(&assertions)
        guard result == kIOReturnSuccess, let dict = assertions?.takeRetainedValue() as? [String: [[String: Any]]] else {
            return false
        }

        let mediaTypes: Set<String> = [
            "PreventUserIdleDisplaySleep",
            "PreventDisplaySleep",
        ]

        let selfPID = ProcessInfo.processInfo.processIdentifier
        let selfName = ProcessInfo.processInfo.processName

        for (processName, assertionList) in dict {
            if processName == selfName { continue }
            for assertion in assertionList {
                if let type = assertion["AssertionType"] as? String ?? assertion["AssertType"] as? String,
                   mediaTypes.contains(type) {
                    if let pid = assertion["AssertPID"] as? Int32, pid == selfPID { continue }
                    return true
                }
            }
        }
        return false
    }
}

// MARK: - Overlay Window

class OverlayWindowController: NSObject, ObservableObject {
    var window: NSWindow?

    @Published var message: String = ""
    @Published var subtitle: String = ""
    @Published var showSnooze: Bool = true
    @Published var showTakeBreak: Bool = true
    @Published var showLockNow: Bool = false
    @Published var showFiveMore: Bool = false
    @Published var countdownText: String = ""
    @Published var showCountdown: Bool = false
    @Published var dogeImage: NSImage?

    var onSnooze: (() -> Void)?
    var onTakeBreak: (() -> Void)?
    var onLockNow: (() -> Void)?
    var onFiveMore: (() -> Void)?

    func show(playSound: Bool = true) {
        if window == nil {
            createWindow()
        }
        window?.orderFrontRegardless()
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        if playSound {
            NSSound(named: "Purr")?.play()
        }
    }

    func dismiss() {
        window?.orderOut(nil)
    }

    private func createWindow() {
        let contentView = OverlayView(controller: self)
        let hostingView = NSHostingView(rootView: contentView)

        let screenFrame = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 800, height: 600)
        let windowWidth: CGFloat = 420
        let windowHeight: CGFloat = 420
        let windowX = screenFrame.midX - windowWidth / 2
        let windowY = screenFrame.midY - windowHeight / 2 + 80

        let win = NSWindow(
            contentRect: NSRect(x: windowX, y: windowY, width: windowWidth, height: windowHeight),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        win.contentView = hostingView
        win.isReleasedWhenClosed = false
        win.level = .floating
        win.isMovableByWindowBackground = true
        win.backgroundColor = .clear
        win.isOpaque = false
        win.hasShadow = true
        win.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

        self.window = win
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
    @ObservedObject var controller: OverlayWindowController

    var body: some View {
        VStack(spacing: 0) {
            // Rainbow bar at top
            RainbowBar()
                .clipShape(UnevenRoundedRectangle(topLeadingRadius: 16, topTrailingRadius: 16))

            VStack(spacing: 16) {
                Spacer().frame(height: 8)

                // Doge image
                if let img = controller.dogeImage {
                    Image(nsImage: img)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 120, height: 120)
                        .clipShape(Circle())
                        .shadow(color: Palette.suiPink.opacity(0.3), radius: 8, y: 4)
                }

                // Message
                Text(controller.message)
                    .font(.system(size: 17, weight: .semibold, design: .rounded))
                    .foregroundColor(Palette.suiInk)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 28)

                // Subtitle
                if !controller.subtitle.isEmpty {
                    Text(controller.subtitle)
                        .font(.system(size: 13, weight: .regular, design: .rounded))
                        .foregroundColor(Palette.suiGray)
                }

                // Countdown
                if controller.showCountdown {
                    Text(controller.countdownText)
                        .font(.system(size: 40, weight: .light, design: .rounded))
                        .monospacedDigit()
                        .foregroundColor(Palette.suiOrange)
                }

                Spacer().frame(height: 4)

                // Buttons
                HStack(spacing: 14) {
                    if controller.showSnooze {
                        Button(action: { controller.onSnooze?() }) {
                            Text("Snooze 10 min")
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

                Spacer().frame(height: 12)
            }
            .frame(maxWidth: .infinity)
            .background(Palette.suiPaper)
        }
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.black.opacity(0.08), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.15), radius: 20, y: 8)
    }
}

// MARK: - App Controller

class BreakReminderController: NSObject {
    private var statusItem: NSStatusItem!
    private var overlayController = OverlayWindowController()

    private var phase: AppPhase = .idle
    private var workStartTime: Date?
    private var snoozeCount: Int = 0
    private var graceStartTime: Date?

    private var menuBarTimer: Timer?
    private var assertionCheckTimer: Timer?
    private var snoozeTimer: Timer?
    private var graceTimer: Timer?
    private var nagTimer: Timer?

    func start() {
        setupMenuBar()
        setupNotifications()
        setupTimers()
        startWorking()
    }

    // MARK: - Menu Bar

    private func setupMenuBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        updateMenuBarDisplay()

        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Break Reminder", action: nil, keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())

        let statusItem = NSMenuItem(title: "Status: Starting...", action: nil, keyEquivalent: "")
        statusItem.tag = 100
        menu.addItem(statusItem)

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
            let remaining = max(0, Int(Config.workDuration - elapsed))
            let remainingMin = (remaining + 59) / 60

            if elapsed >= Config.workDuration {
                // Overdue - solid red circle
                button.attributedTitle = NSAttributedString(
                    string: "●",
                    attributes: [.foregroundColor: NSColor.systemRed, .font: NSFont.systemFont(ofSize: 14, weight: .bold)]
                )
            } else if elapsed >= Config.amberWarning {
                // Last 5 minutes - countdown in orange
                button.attributedTitle = NSAttributedString(
                    string: "\(remainingMin)m",
                    attributes: [.foregroundColor: NSColor.systemOrange, .font: NSFont.monospacedDigitSystemFont(ofSize: 13, weight: .semibold)]
                )
            } else {
                // Normal - black circle
                button.attributedTitle = NSAttributedString(
                    string: "●",
                    attributes: [.foregroundColor: NSColor.labelColor, .font: NSFont.systemFont(ofSize: 8)]
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
        startWorking()
    }

    @objc private func screenDidLock() {
        cancelAllTimers()
        overlayController.dismiss()
        phase = .idle
        workStartTime = nil
        snoozeCount = 0
        graceStartTime = nil
        updateMenuBarDisplay()
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
        overlayController.dismiss()
        phase = .working
        workStartTime = workStartTime ?? Date()
        snoozeCount = 0
        graceStartTime = nil
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
            let elapsed = Date().timeIntervalSince(start)
            if elapsed >= Config.workDuration {
                if MediaDetector.isMediaActive() {
                    phase = .alertPending
                } else {
                    showBreakAlert()
                }
            }
        }
    }

    private func checkAssertions() {
        if phase == .alertPending && !MediaDetector.isMediaActive() {
            showBreakAlert()
        }
    }

    // MARK: - Break Alert

    private func showBreakAlert() {
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
        overlayController.showSnooze = true
        overlayController.showTakeBreak = true
        overlayController.showLockNow = false
        overlayController.showFiveMore = false
        overlayController.showCountdown = false

        overlayController.onSnooze = { [weak self] in self?.snooze() }
        overlayController.onTakeBreak = { [weak self] in self?.takeBreak() }

        overlayController.show()
        updateMenuBarDisplay()
    }

    // MARK: - Snooze

    private func snooze() {
        snoozeCount += 1
        phase = .working
        overlayController.dismiss()

        snoozeTimer?.invalidate()
        snoozeTimer = Timer.scheduledTimer(withTimeInterval: Config.snoozeDuration, repeats: false) { [weak self] _ in
            guard let self = self, self.phase == .working else { return }
            if MediaDetector.isMediaActive() {
                self.phase = .alertPending
            } else {
                self.showBreakAlert()
            }
        }

        updateMenuBarDisplay()
    }

    // MARK: - Take a Break (Grace Period)

    private func takeBreak() {
        phase = .graceCountdown
        graceStartTime = Date()

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

        updateMenuBarDisplay()
    }

    // MARK: - Nag

    private func showNag() {
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

        overlayController.show()
        updateMenuBarDisplay()
    }

    private func fiveMoreMinutes() {
        phase = .graceCountdown
        graceStartTime = Date()

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

        updateMenuBarDisplay()
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
        let duration = phase == .nagging ? Config.finalExtension : Config.gracePeriod
        return max(0, Int(duration - elapsed))
    }

    private func formatCountdown(_ seconds: Int) -> String {
        let m = seconds / 60
        let s = seconds % 60
        return String(format: "%d:%02d", m, s)
    }

    @objc private func quitApp() {
        NSApplication.shared.terminate(nil)
    }
}

// MARK: - App Delegate

class AppDelegate: NSObject, NSApplicationDelegate {
    let controller = BreakReminderController()

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
