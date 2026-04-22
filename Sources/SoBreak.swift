import Cocoa
import SwiftUI
import IOKit.pwr_mgt
import Carbon.HIToolbox

// MARK: - Configuration

struct Config {
    #if DEBUG
    static let workDuration: TimeInterval = 5           // 5 seconds for testing
    static let amberWarning: TimeInterval = 3            // amber at 3s
    static let snoozeDuration: TimeInterval = 600        // 10 minutes (first snooze)
    static let shortSnoozeDuration: TimeInterval = 300   // 5 minutes (second snooze)
    static let persistentSnoozeDuration: TimeInterval = 120  // 2 minutes (third+ snooze)
    static let gracePeriod: TimeInterval = 120           // 2 minutes
    static let nagAfter: TimeInterval = 300              // 5 minutes
    static let finalExtension: TimeInterval = 60         // 1 more minute
    #else
    static let workDuration: TimeInterval = 3600         // 60 minutes
    static let amberWarning: TimeInterval = 3300         // 55 minutes
    static let snoozeDuration: TimeInterval = 600        // 10 minutes (first snooze)
    static let shortSnoozeDuration: TimeInterval = 300   // 5 minutes (second snooze)
    static let persistentSnoozeDuration: TimeInterval = 120  // 2 minutes (third+ snooze)
    static let gracePeriod: TimeInterval = 120           // 2 minutes
    static let nagAfter: TimeInterval = 300              // 5 minutes
    static let finalExtension: TimeInterval = 60         // 1 more minute
    #endif

    static let assertionCheckInterval: TimeInterval = 10
    static let menuBarUpdateInterval: TimeInterval = 1
    static let firstSnoozeConfirmationDelay: TimeInterval = 5
    static let repeatedSnoozeConfirmationDelay: TimeInterval = 10
    static let lockResetThreshold: TimeInterval = 300    // reset break counter only if locked ≥ 5 min
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
        "much focus! you've been at it for an hour. break time?",
        "wow, an hour already! your eyes and brain would love a break.",
        "one hour of solid work. very impressive. time to step away?",
        "such dedication! sixty minutes of focus. how about a break?",
        "you've been going strong for an hour. much work. break time?",
    ]

    static let snoozeEscalation = [
        "still going? very determined. break whenever you're ready, fren.",
        "such snooze. your future self would appreciate a stretch.",
        "quite the streak! but seriously, a short break works wonders.",
        "many snooze. such stubborn. your chair is starting to worry.",
        "very committed. wow. five minutes won't undo that.",
    ]

    static func snoozeEscalationFallback(snoozeCount: Int) -> String {
        "doge has asked nicely \(snoozeCount) times now. please take break."
    }

    static let graceCountdown = "wrapping up..."
    static let nagMessage = [
        "still here? you said you'd take a break. such betrayal.",
        "wow. much disappoint. doge has been very patient.",
    ]
    static let nagSubtle = "your break is waiting for you."

    static let fiveMoreMinutesMessage = "one more minute..."
    static let fiveMoreMinutesSubtitle = "then it's really break time, fren"

    static let pomodoroStarted = [
        "such focus. very productive. wow.",
        "much ambition. let's go.",
        "focus mode: activated. wow.",
        "deep work time. very serious.",
        "locked in. such determination.",
        "go time. much energy.",
    ]
}

// MARK: - Doge Images

enum DogeImage: String, CaseIterable {
    // Happy (snoozeCount=0)
    case happy1Tea = "doge-happy-1-tea"
    case happy2Wave = "doge-happy-2-wave"
    case happy3Peek = "doge-happy-3-peek"
    // Nudge (snoozeCount 1-2)
    case nudge1Watch = "doge-nudge-1-watch"
    case nudge2Sign = "doge-nudge-2-sign"
    case nudge3Poke = "doge-nudge-3-poke"
    // Sassy (snoozeCount 3+)
    case sassy1Crossed = "doge-sassy-1-crossed"
    case sassy2Facepalm = "doge-sassy-2-facepalm"
    case sassy3Flopped = "doge-sassy-3-flopped"
    // Stretch (grace countdown)
    case stretch1Bow = "doge-stretch-1-bow"
    // Focused (pomodoro toast)
    case focused1Headband = "doge-focused-1-headband"
    case focused2Flex = "doge-focused-2-flex"

    /// Load the small (256px) transparent version for UI display.
    /// Fallback chain: small → transparent → original.
    var nsImage: NSImage? {
        let candidates = [rawValue + "-small", rawValue + "-transparent", rawValue]
        let bundle = Bundle.main
        for name in candidates {
            if let url = bundle.url(forResource: name, withExtension: "png", subdirectory: "images") {
                return NSImage(contentsOf: url)
            }
        }
        // Fallback: check relative to executable
        let execURL = URL(fileURLWithPath: CommandLine.arguments[0])
        for name in candidates {
            let url = execURL.deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent("Resources/images/\(name).png")
            if let img = NSImage(contentsOf: url) { return img }
        }
        return nil
    }

    /// The entrance animation style for this doge image
    enum EntranceAnimation {
        case bounce    // happy
        case slide     // nudge
        case dramatic  // sassy/nag
        case wiggle    // stretch
    }

    var entranceAnimation: EntranceAnimation {
        switch self {
        case .happy1Tea, .happy2Wave, .happy3Peek, .focused1Headband, .focused2Flex:
            return .bounce
        case .nudge1Watch, .nudge2Sign, .nudge3Poke:
            return .slide
        case .sassy1Crossed, .sassy2Facepalm, .sassy3Flopped:
            return .dramatic
        case .stretch1Bow:
            return .wiggle
        }
    }

    static let happyImages: [DogeImage] = [.happy1Tea, .happy2Wave, .happy3Peek]
    static let nudgeImages: [DogeImage] = [.nudge1Watch, .nudge2Sign, .nudge3Poke]
    static let sassyImages: [DogeImage] = [.sassy1Crossed, .sassy2Facepalm, .sassy3Flopped]
    static let focusedImages: [DogeImage] = [.focused1Headband, .focused2Flex]
    static let nagImages: [DogeImage] = [.sassy3Flopped, .sassy1Crossed]

    /// Pick the right doge for the current situation
    static func forAlert(snoozeCount: Int) -> DogeImage {
        if snoozeCount == 0 { return happyImages.randomElement()! }
        if snoozeCount <= 2 { return nudgeImages.randomElement()! }
        return sassyImages.randomElement()!
    }

    static var forGrace: DogeImage { .stretch1Bow }
    static var forNag: DogeImage { nagImages.randomElement()! }
    static var forFocused: DogeImage { focusedImages.randomElement()! }
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
        NSLog("[SoBreak] Media check: active=\(active)\(details.isEmpty ? "" : " — \(details)")")
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

class KeyableWindow: NSWindow {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

class OverlayWindowController: NSObject, ObservableObject {
    private enum Metrics {
        static let centerSize = NSSize(width: 400, height: 450)
        static let topSize = NSSize(width: 340, height: 110)
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
    @Published var dogeImageEnum: DogeImage = .happy1Tea
    @Published var borderColor: Color = Palette.suiYellow
    @Published var backgroundTint: Color = Palette.suiPaper
    @Published var isCompact: Bool = false
    @Published var snoozeLabel: String = "Snooze 10 min"
    @Published var isSnoozeEnabled: Bool = true
    @Published var fiveMoreLabel: String = "1 more minute"
    @Published var isFiveMoreEnabled: Bool = true

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

        let win = KeyableWindow(
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

// MARK: - Doge Entrance Animation View

struct DogeEntranceView: View {
    let image: NSImage
    let animation: DogeImage.EntranceAnimation
    let size: CGFloat

    @State private var entered = false
    @State private var floatOffset: CGFloat = 0

    var body: some View {
        // Outer wrapper: idle float
        ZStack {
            Image(nsImage: image)
                .resizable()
                .interpolation(.high)
                .aspectRatio(contentMode: .fit)
                .frame(width: size)
                .modifier(EntranceModifier(animation: animation, entered: entered))
        }
        .offset(y: floatOffset)
        .onAppear {
            // Trigger entrance
            withAnimation(entranceSpring) {
                entered = true
            }
            // Start idle float after entrance completes
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                withAnimation(.easeInOut(duration: 3.0).repeatForever(autoreverses: true)) {
                    floatOffset = -4
                }
            }
        }
        .onDisappear {
            entered = false
            floatOffset = 0
        }
    }

    private var entranceSpring: Animation {
        switch animation {
        case .bounce:
            return .spring(response: 0.5, dampingFraction: 0.6)
        case .slide:
            return .spring(response: 0.5, dampingFraction: 0.7)
        case .dramatic:
            return .spring(response: 0.7, dampingFraction: 0.65)
        case .wiggle:
            return .spring(response: 0.5, dampingFraction: 0.6)
        }
    }
}

struct EntranceModifier: ViewModifier {
    let animation: DogeImage.EntranceAnimation
    let entered: Bool

    func body(content: Content) -> some View {
        switch animation {
        case .bounce:
            content
                .offset(y: entered ? 0 : -30)
                .scaleEffect(entered ? 1.0 : 0.8)
                .opacity(entered ? 1 : 0)
        case .slide:
            content
                .offset(x: entered ? 0 : 40)
                .rotationEffect(.degrees(entered ? 0 : 8))
                .opacity(entered ? 1 : 0)
        case .dramatic:
            content
                .scaleEffect(entered ? 1.0 : 0.6)
                .opacity(entered ? 1 : 0)
        case .wiggle:
            content
                .offset(x: entered ? 0 : -20)
                .rotationEffect(.degrees(entered ? 0 : -10))
                .opacity(entered ? 1 : 0)
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
    @State private var appeared = false

    var body: some View {
        VStack(spacing: 0) {
            content
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: layout == .top ? .top : .center)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(controller.borderColor, lineWidth: 2)
        )
        .shadow(color: Palette.suiInk.opacity(0.08), radius: 30, y: 12)
        .scaleEffect(appeared ? 1.0 : 0.92)
        .opacity(appeared ? 1.0 : 0)
        .onAppear {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                appeared = true
            }
        }
        .onDisappear {
            appeared = false
        }
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
        HStack(spacing: 14) {
            if let img = controller.dogeImage {
                DogeEntranceView(
                    image: img,
                    animation: controller.dogeImageEnum.entranceAnimation,
                    size: 72
                )
                .shadow(color: Palette.suiInk.opacity(0.08), radius: 4, y: 2)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(controller.message)
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundColor(Palette.suiInk)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)

                if !controller.subtitle.isEmpty {
                    Text(controller.subtitle)
                        .font(.system(size: 11, weight: .regular, design: .rounded))
                        .foregroundColor(Palette.suiGray)
                }

                HStack(spacing: 10) {
                    if controller.showCountdown {
                        Text(controller.countdownText)
                            .font(.system(size: 24, weight: .light, design: .rounded))
                            .monospacedDigit()
                            .foregroundColor(Palette.suiOrange)
                    }

                    compactActionButtons
                }
            }
        }
        .padding(.leading, 16)
        .padding(.trailing, 14)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Palette.suiPaper)
    }

    // Full centered layout for break alerts and nag
    private var fullContent: some View {
        VStack(spacing: 0) {
            Spacer().frame(height: 24)

            if let img = controller.dogeImage {
                DogeEntranceView(
                    image: img,
                    animation: controller.dogeImageEnum.entranceAnimation,
                    size: 180
                )
            }

            Spacer().frame(height: 14)

            Text(controller.message)
                .font(.system(size: 21, weight: .semibold, design: .rounded))
                .foregroundColor(Palette.suiInk)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 28)

            Spacer().frame(height: 5)

            if !controller.subtitle.isEmpty {
                Text(controller.subtitle)
                    .font(.system(size: 13, weight: .regular, design: .rounded))
                    .foregroundColor(Palette.suiGray)
            }

            if controller.showCountdown {
                Spacer().frame(height: 12)
                Text(controller.countdownText)
                    .font(.system(size: 36, weight: .light, design: .rounded))
                    .monospacedDigit()
                    .foregroundColor(Palette.suiOrange)
            }

            Spacer()

            actionButtons

            Spacer().frame(height: 22)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        .background(
            RadialGradient(
                colors: [controller.backgroundTint, Palette.suiPaperDark],
                center: .center,
                startRadius: 20,
                endRadius: 300
            )
        )
    }

    // Full-size buttons for center layout
    private var actionButtons: some View {
        VStack(spacing: 8) {
            HStack(spacing: 12) {
                if controller.showTakeBreak {
                    PillButton(
                        title: "Take a break",
                        color: Palette.suiPink,
                        action: { controller.onTakeBreak?() }
                    )
                }

                if controller.showLockNow {
                    PillButton(
                        title: "Lock now",
                        color: Palette.suiCyan,
                        action: { controller.onLockNow?() }
                    )
                }
            }

            if controller.showSnooze {
                Button(action: { controller.onSnooze?() }) {
                    Text(controller.snoozeLabel)
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundColor(Palette.suiGray)
                }
                .buttonStyle(.plain)
                .disabled(!controller.isSnoozeEnabled)
                .opacity(controller.isSnoozeEnabled ? 1 : 0.4)
            }

            if controller.showFiveMore {
                Button(action: { controller.onFiveMore?() }) {
                    Text(controller.fiveMoreLabel)
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundColor(Palette.suiGray)
                }
                .buttonStyle(.plain)
                .disabled(!controller.isFiveMoreEnabled)
                .opacity(controller.isFiveMoreEnabled ? 1 : 0.4)
            }
        }
    }

    // Compact buttons for top layout
    private var compactActionButtons: some View {
        HStack(spacing: 8) {
            if controller.showLockNow {
                PillButton(
                    title: "Lock now",
                    color: Palette.suiCyan,
                    size: .compact,
                    action: { controller.onLockNow?() }
                )
            }

            if controller.showFiveMore {
                Button(action: { controller.onFiveMore?() }) {
                    Text(controller.fiveMoreLabel)
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundColor(Palette.suiGray)
                }
                .buttonStyle(.plain)
                .disabled(!controller.isFiveMoreEnabled)
                .opacity(controller.isFiveMoreEnabled ? 1 : 0.4)
            }
        }
    }
}

// MARK: - Pill Button

struct PillButton: View {
    enum Size {
        case regular
        case compact
    }

    let title: String
    let color: Color
    var size: Size = .regular
    let action: () -> Void

    @State private var isHovered = false
    @State private var glowPulse = false

    private var fontSize: CGFloat { size == .compact ? 12 : 14 }
    private var hPad: CGFloat { size == .compact ? 16 : 24 }
    private var vPad: CGFloat { size == .compact ? 7 : 10 }

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: fontSize, weight: .semibold, design: .rounded))
                .padding(.horizontal, hPad)
                .padding(.vertical, vPad)
                .background(
                    Capsule().fill(color)
                )
                .foregroundColor(.white)
                .shadow(color: color.opacity(glowPulse ? 0.50 : 0.25), radius: glowPulse ? 16 : 8, y: 2)
        }
        .buttonStyle(.plain)
        .scaleEffect(isHovered ? 1.04 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isHovered)
        .onHover { hovering in
            isHovered = hovering
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 2.5).repeatForever(autoreverses: true)) {
                glowPulse = true
            }
        }
    }
}

// MARK: - App Controller

class SoBreakController: NSObject {
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
    private var snoozeUnlockAt: Date?
    private var snoozeReadyLabel: String = "Snooze 10 min"
    private var fiveMoreUnlockAt: Date?
    private var fiveMoreClickCount: Int = 0
    private static let fiveMoreReadyLabel = "1 more minute"
    private static let firstFiveMoreDelay: TimeInterval = 5
    private static let repeatedFiveMoreDelay: TimeInterval = 10
    private var lockedAt: Date?

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
        menu.addItem(NSMenuItem(title: "So Break", action: nil, keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())

        let statusItem = NSMenuItem(title: "Status: Starting...", action: nil, keyEquivalent: "")
        statusItem.tag = 100
        menu.addItem(statusItem)

        menu.addItem(NSMenuItem.separator())

        let pomo25 = NSMenuItem(title: "Start 25 min timer", action: #selector(startPomodoro25), keyEquivalent: "t")
        pomo25.keyEquivalentModifierMask = [.command, .option]
        pomo25.target = self
        pomo25.tag = 200
        menu.addItem(pomo25)

        let pomo45 = NSMenuItem(title: "Start 45 min timer", action: #selector(startPomodoro45), keyEquivalent: "")
        pomo45.target = self
        pomo45.tag = 201
        menu.addItem(pomo45)

        let cancelPomo = NSMenuItem(title: "Cancel timer", action: #selector(cancelPomodoro), keyEquivalent: "")
        cancelPomo.target = self
        cancelPomo.tag = 202
        cancelPomo.isHidden = true
        menu.addItem(cancelPomo)

        menu.addItem(NSMenuItem.separator())
        let quitItem = NSMenuItem(title: "Quit", action: #selector(quitApp), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

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
        NSLog("[SoBreak] Screen unlocked")
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            let lockDuration = self.lockedAt.map { Date().timeIntervalSince($0) } ?? .infinity
            self.lockedAt = nil

            if lockDuration >= Config.lockResetThreshold {
                NSLog("[SoBreak] Locked for \(Int(lockDuration))s — resetting break counter")
                self.workStartTime = nil
            } else if let start = self.workStartTime {
                NSLog("[SoBreak] Locked for \(Int(lockDuration))s — preserving break counter")
                self.workStartTime = start.addingTimeInterval(lockDuration)
            }
            self.startWorking()
        }
    }

    @objc private func screenDidLock() {
        NSLog("[SoBreak] Screen locked — pausing timers")
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.lockedAt = Date()
            self.cancelAllTimers()
            self.overlayController.dismiss()
            self.hideDim()
            self.phase = .idle
            // Preserve workStartTime so a quick unlock (< lockResetThreshold) resumes the counter.
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

    private func snoozeConfirmationDelay() -> TimeInterval {
        snoozeCount == 0 ? Config.firstSnoozeConfirmationDelay : Config.repeatedSnoozeConfirmationDelay
    }

    private func updateSnoozeButtonState(now: Date = Date()) {
        guard phase == .alertShown, overlayController.showSnooze else {
            overlayController.isSnoozeEnabled = true
            overlayController.snoozeLabel = snoozeReadyLabel
            return
        }

        guard let snoozeUnlockAt else {
            overlayController.isSnoozeEnabled = true
            overlayController.snoozeLabel = snoozeReadyLabel
            return
        }

        let remaining = max(0, Int(ceil(snoozeUnlockAt.timeIntervalSince(now))))
        let isReady = remaining == 0
        overlayController.isSnoozeEnabled = isReady
        overlayController.snoozeLabel = isReady ? snoozeReadyLabel : "\(snoozeReadyLabel) (\(remaining)s)"
    }

    private func updateFiveMoreButtonState(now: Date = Date()) {
        guard phase == .nagging, overlayController.showFiveMore else {
            overlayController.isFiveMoreEnabled = true
            overlayController.fiveMoreLabel = Self.fiveMoreReadyLabel
            return
        }

        guard let fiveMoreUnlockAt else {
            overlayController.isFiveMoreEnabled = true
            overlayController.fiveMoreLabel = Self.fiveMoreReadyLabel
            return
        }

        let remaining = max(0, Int(ceil(fiveMoreUnlockAt.timeIntervalSince(now))))
        let isReady = remaining == 0
        overlayController.isFiveMoreEnabled = isReady
        overlayController.fiveMoreLabel = isReady ? Self.fiveMoreReadyLabel : "\(Self.fiveMoreReadyLabel) (\(remaining)s)"
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
        snoozeUnlockAt = nil
        fiveMoreUnlockAt = nil
        fiveMoreClickCount = 0
        overlayController.isSnoozeEnabled = true
        overlayController.isFiveMoreEnabled = true
        overlayController.fiveMoreLabel = Self.fiveMoreReadyLabel
        overlayController.showSnooze = true
        overlayController.snoozeLabel = snoozeReadyLabel
        NSLog("[SoBreak] Started working, timer from \(workStartTime!)")
        updateMenuBarDisplay()
    }

    private func tick() {
        updateMenuBarDisplay()

        if phase == .alertShown {
            updateSnoozeButtonState()
        }

        if phase == .nagging {
            updateFiveMoreButtonState()
        }

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
                        NSLog("[SoBreak] Alert deferred — media/call active")
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
            NSLog("[SoBreak] Media no longer active — showing deferred alert")
            showBreakAlert()
        }
    }

    // MARK: - Break Alert

    private func showBreakAlert() {
        NSLog("[SoBreak] Showing break alert (snoozeCount: \(snoozeCount))")
        phase = .alertShown

        let message: String
        if snoozeCount == 0 {
            message = Messages.firstAlert.randomElement()!
        } else if snoozeCount <= Messages.snoozeEscalation.count {
            message = Messages.snoozeEscalation[snoozeCount - 1]
        } else {
            message = Messages.snoozeEscalationFallback(snoozeCount: snoozeCount)
        }

        let elapsed = workStartTime.map { Int(Date().timeIntervalSince($0)) / 60 } ?? 0

        let dogeEnum = DogeImage.forAlert(snoozeCount: snoozeCount)
        overlayController.dogeImageEnum = dogeEnum
        overlayController.dogeImage = dogeEnum.nsImage

        // Mood-coloured border and background tint
        if snoozeCount == 0 {
            overlayController.borderColor = Palette.suiYellow
            overlayController.backgroundTint = Color(red: 1.0, green: 0.976, blue: 0.890) // #FFF9E3
        } else if snoozeCount <= 2 {
            overlayController.borderColor = Palette.suiOrange
            overlayController.backgroundTint = Color(red: 1.0, green: 0.965, blue: 0.863) // warmer
        } else {
            overlayController.borderColor = Palette.suiPink
            overlayController.backgroundTint = Color(red: 1.0, green: 0.950, blue: 0.878) // warmest
        }

        overlayController.message = message
        overlayController.subtitle = snoozeCount > 0 ? "Snoozed \(snoozeCount) time\(snoozeCount == 1 ? "" : "s") · \(elapsed) min active" : "\(elapsed) min of continuous work"
        let nextSnoozeSeconds: TimeInterval
        switch snoozeCount {
        case 0: nextSnoozeSeconds = Config.snoozeDuration
        case 1: nextSnoozeSeconds = Config.shortSnoozeDuration
        default: nextSnoozeSeconds = Config.persistentSnoozeDuration
        }
        snoozeReadyLabel = "Snooze \(Int(nextSnoozeSeconds / 60)) min"
        snoozeUnlockAt = Date().addingTimeInterval(snoozeConfirmationDelay())
        overlayController.snoozeLabel = snoozeReadyLabel
        overlayController.showSnooze = true
        overlayController.showTakeBreak = true
        overlayController.showLockNow = false
        overlayController.showFiveMore = false
        overlayController.showCountdown = false

        updateSnoozeButtonState()

        overlayController.onSnooze = { [weak self] in self?.snooze() }
        overlayController.onTakeBreak = { [weak self] in self?.takeBreak() }

        overlayController.isCompact = false
        showDim(opacity: 0.4, blocking: true)
        overlayController.show(position: .center)
        updateMenuBarDisplay()
    }

    // MARK: - Snooze

    private func snooze() {
        updateSnoozeButtonState()
        guard overlayController.isSnoozeEnabled else {
            NSLog("[SoBreak] Snooze click ignored — confirmation countdown still active")
            return
        }

        snoozeUnlockAt = nil
        snoozeCount += 1
        let duration: TimeInterval
        switch snoozeCount {
        case 1: duration = Config.snoozeDuration
        case 2: duration = Config.shortSnoozeDuration
        default: duration = Config.persistentSnoozeDuration
        }
        phase = .working
        snoozeUntil = Date().addingTimeInterval(duration)
        hideDim()
        overlayController.dismiss()
        NSLog("[SoBreak] Snoozed (count: \(snoozeCount), duration: \(Int(duration/60)) min), next alert after \(snoozeUntil!)")

        snoozeTimer?.invalidate()
        snoozeTimer = Timer.scheduledTimer(withTimeInterval: duration, repeats: false) { [weak self] _ in
            guard let self = self, self.phase == .working else { return }
            self.snoozeUntil = nil
            NSLog("[SoBreak] Snooze timer fired, checking media...")
            if MediaDetector.isMediaActive() {
                NSLog("[SoBreak] Media active after snooze — deferring alert")
                self.phase = .alertPending
            } else {
                NSLog("[SoBreak] No media active — showing break alert")
                self.showBreakAlert()
            }
        }

        updateMenuBarDisplay()
    }

    // MARK: - Take a Break (Grace Period)

    private func takeBreak() {
        NSLog("[SoBreak] User chose 'Take a break' — starting grace countdown")
        phase = .graceCountdown
        graceStartTime = Date()
        graceDuration = Config.gracePeriod
        snoozeUnlockAt = nil

        let dogeEnum = DogeImage.forGrace
        overlayController.dogeImageEnum = dogeEnum
        overlayController.dogeImage = dogeEnum.nsImage
        overlayController.borderColor = Palette.suiCyan
        overlayController.backgroundTint = Palette.suiPaper
        overlayController.message = Messages.graceCountdown
        overlayController.subtitle = "lock your screen when you're ready"
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
        NSLog("[SoBreak] Grace period expired — showing nag")
        phase = .nagging

        let dogeEnum = DogeImage.forNag
        overlayController.dogeImageEnum = dogeEnum
        overlayController.dogeImage = dogeEnum.nsImage
        overlayController.borderColor = Palette.suiPink
        overlayController.backgroundTint = Color(red: 1.0, green: 0.941, blue: 0.902) // warmest for nag
        overlayController.message = Messages.nagMessage.randomElement()!
        overlayController.subtitle = Messages.nagSubtle
        overlayController.showSnooze = false
        overlayController.showTakeBreak = false
        overlayController.showLockNow = true
        overlayController.showFiveMore = true
        overlayController.showCountdown = false

        let fiveMoreDelay = fiveMoreClickCount == 0 ? Self.firstFiveMoreDelay : Self.repeatedFiveMoreDelay
        fiveMoreUnlockAt = Date().addingTimeInterval(fiveMoreDelay)
        overlayController.fiveMoreLabel = Self.fiveMoreReadyLabel
        updateFiveMoreButtonState()

        overlayController.onLockNow = { [weak self] in self?.lockScreen() }
        overlayController.onFiveMore = { [weak self] in self?.fiveMoreMinutes() }

        overlayController.isCompact = false
        showDim(opacity: 0.4, blocking: true)
        overlayController.show(position: .center)
        updateMenuBarDisplay()
    }

    private func fiveMoreMinutes() {
        updateFiveMoreButtonState()
        guard overlayController.isFiveMoreEnabled else {
            NSLog("[SoBreak] '1 more minute' click ignored — cooldown still active")
            return
        }

        fiveMoreUnlockAt = nil
        fiveMoreClickCount += 1
        phase = .graceCountdown
        graceStartTime = Date()
        graceDuration = Config.finalExtension

        let dogeEnum = DogeImage.forGrace
        overlayController.dogeImageEnum = dogeEnum
        overlayController.dogeImage = dogeEnum.nsImage
        overlayController.borderColor = Palette.suiCyan
        overlayController.backgroundTint = Palette.suiPaper
        overlayController.message = Messages.fiveMoreMinutesMessage
        overlayController.subtitle = Messages.fiveMoreMinutesSubtitle
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

    private func showDim(opacity: CGFloat = 0.4, blocking: Bool = false) {
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
            win.ignoresMouseEvents = !blocking
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

    // MARK: - Global Hotkeys

    private var hotkeyRefs: [EventHotKeyRef?] = []
    private var debugPreviewStep: Int = -1

    private func setupGlobalHotkey() {
        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        let controller = Unmanaged.passUnretained(self).toOpaque()

        InstallEventHandler(GetApplicationEventTarget(), { (_, event, userData) -> OSStatus in
            guard let userData = userData,
                  let event = event else { return OSStatus(eventNotHandledErr) }

            var hotkeyID = EventHotKeyID()
            GetEventParameter(event, EventParamName(kEventParamDirectObject),
                              EventParamType(typeEventHotKeyID), nil,
                              MemoryLayout<EventHotKeyID>.size, nil, &hotkeyID)

            let controller = Unmanaged<SoBreakController>.fromOpaque(userData).takeUnretainedValue()
            DispatchQueue.main.async {
                switch hotkeyID.id {
                case 1: // Cmd+Option+T — start 25 min pomodoro
                    controller.startPomodoro(minutes: 25)
                    controller.showConfirmationToast("25 min timer started")
                case 2: // Cmd+Option+D — cycle debug preview
                    controller.cycleDebugPreview()
                default:
                    break
                }
            }
            return noErr
        }, 1, &eventType, controller, nil)

        let modifiers: UInt32 = UInt32(cmdKey | optionKey)

        // Hotkey 1: Cmd+Option+T — pomodoro
        var ref1: EventHotKeyRef?
        let id1 = EventHotKeyID(signature: OSType(0x5442524B), id: 1)
        RegisterEventHotKey(UInt32(kVK_ANSI_T), modifiers, id1, GetApplicationEventTarget(), 0, &ref1)
        hotkeyRefs.append(ref1)

        // Hotkey 2: Cmd+Option+D — debug preview
        var ref2: EventHotKeyRef?
        let id2 = EventHotKeyID(signature: OSType(0x5442524B), id: 2)
        RegisterEventHotKey(UInt32(kVK_ANSI_D), modifiers, id2, GetApplicationEventTarget(), 0, &ref2)
        hotkeyRefs.append(ref2)

        NSLog("[SoBreak] Registered global hotkeys: Cmd+Option+T (pomodoro), Cmd+Option+D (debug preview)")
    }

    // MARK: - Debug Preview (Cmd+Option+D)

    func cycleDebugPreview() {
        debugPreviewStep += 1
        if debugPreviewStep > 5 { debugPreviewStep = 0 }

        // Clean up before showing next state
        overlayController.dismiss()
        hideDim()
        confirmationWindow?.orderOut(nil)

        let stepName: String
        switch debugPreviewStep {
        case 0:
            stepName = "Break alert (first time)"
            snoozeCount = 0
            showBreakAlert()
        case 1:
            stepName = "Break alert (snoozed 2x)"
            snoozeCount = 2
            showBreakAlert()
        case 2:
            stepName = "Grace countdown"
            takeBreak()
        case 3:
            stepName = "Nag"
            showNag()
        case 4:
            stepName = "Pomodoro toast"
            overlayController.dismiss()
            hideDim()
            showConfirmationToast("25 min timer started")
        case 5:
            stepName = "Dismissed"
            overlayController.dismiss()
            hideDim()
            // Restore normal working state
            phase = .working
            workStartTime = Date()
            snoozeCount = 0
            snoozeUntil = nil
            graceStartTime = nil
            updateMenuBarDisplay()
        default:
            stepName = "Unknown"
        }

        NSLog("[SoBreak] Debug preview step \(debugPreviewStep): \(stepName)")
    }

    func showConfirmationToast(_ text: String) {
        confirmationWindow?.orderOut(nil)

        let motivation = Messages.pomodoroStarted.randomElement()!
        let dogeEnum = DogeImage.forFocused
        let dogeImg = dogeEnum.nsImage

        let toastView = HStack(spacing: 14) {
            if let img = dogeImg {
                DogeEntranceView(
                    image: img,
                    animation: dogeEnum.entranceAnimation,
                    size: 48
                )
                .shadow(color: Palette.suiInk.opacity(0.08), radius: 4, y: 2)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(text)
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundColor(Palette.suiInk)
                Text(motivation)
                    .font(.system(size: 12, weight: .regular, design: .rounded))
                    .foregroundColor(Palette.suiGray)
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
        .background(Palette.suiPaper)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Palette.suiCyan, lineWidth: 2)
        )

        let size = NSSize(width: 300, height: 88)
        let hostingView = NSHostingView(rootView: toastView.frame(width: size.width, height: size.height))
        hostingView.frame = NSRect(origin: .zero, size: size)

        let screen = NSScreen.screens.first(where: { $0.frame.contains(NSEvent.mouseLocation) })
            ?? NSScreen.main ?? NSScreen.screens.first!
        let origin = NSPoint(
            x: screen.frame.midX - size.width / 2,
            y: screen.visibleFrame.maxY - size.height - 8
        )

        let win = NSWindow(contentRect: NSRect(origin: origin, size: size),
                           styleMask: [.borderless], backing: .buffered, defer: false)
        win.contentView = hostingView
        win.isOpaque = false
        win.backgroundColor = .clear
        win.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.floatingWindow)))
        win.hasShadow = true
        win.isReleasedWhenClosed = false
        win.orderFrontRegardless()
        confirmationWindow = win

        NSSound(named: "Blow")?.play()

        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
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

    func startPomodoro(minutes: Int) {
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
        snoozeUnlockAt = nil
        fiveMoreUnlockAt = nil
        fiveMoreClickCount = 0
        NSLog("[SoBreak] Started \(minutes) min pomodoro timer")
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
        snoozeUnlockAt = nil
        fiveMoreUnlockAt = nil
        fiveMoreClickCount = 0
        NSLog("[SoBreak] Cancelled pomodoro, back to default 60 min timer")
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
    let controller = SoBreakController()

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
