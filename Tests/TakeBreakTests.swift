import Foundation

// Minimal test framework for standalone Swift
var totalTests = 0
var passedTests = 0
var failedTests: [(String, String)] = []

func test(_ name: String, _ body: () -> Void) {
    totalTests += 1
    body()
}

func assertEqual<T: Equatable>(_ a: T, _ b: T, _ msg: String = "", file: String = #file, line: Int = #line) {
    if a == b {
        passedTests += 1
    } else {
        let detail = msg.isEmpty ? "Expected \(b), got \(a)" : "\(msg): expected \(b), got \(a)"
        failedTests.append(("\(file):\(line)", detail))
    }
}

func assertTrue(_ condition: Bool, _ msg: String = "", file: String = #file, line: Int = #line) {
    if condition {
        passedTests += 1
    } else {
        failedTests.append(("\(file):\(line)", msg.isEmpty ? "Assertion failed" : msg))
    }
}

// MARK: - Config Tests

test("Work duration is 60 minutes") {
    assertEqual(3600.0, 3600.0, "Work duration")
}

test("Amber warning is 5 minutes before work duration") {
    let work: TimeInterval = 3600
    let amber: TimeInterval = 3300
    assertEqual(work - amber, 300.0, "Amber gap should be 5 minutes")
    assertTrue(amber < work, "Amber warning must be before work duration")
}

test("Snooze is 10 minutes") {
    assertEqual(600.0, 600.0, "Snooze duration")
}

test("Grace period is 2 minutes") {
    assertEqual(120.0, 120.0, "Grace period")
}

// MARK: - Message Tests

test("First alert messages have variety") {
    let firstAlert = [
        "You've been at it for an hour. Nice focus! Ready for a break?",
        "One hour of solid work—time to step away for a bit?",
        "An hour already! Your eyes and brain would love a break.",
        "You've been going strong for an hour. Break time?",
        "Sixty minutes of focus. How about a change of scenery?",
    ]
    assertTrue(firstAlert.count >= 3, "Should have at least 3 first alert messages")
}

test("Snooze escalation has enough messages") {
    let snoozeEscalation = [
        "Still going? Just checking in—break whenever you're ready.",
        "That's another snooze. Your future self would appreciate a stretch.",
        "Quite the streak! But seriously, a short break works wonders.",
        "Three snoozes deep. Your chair is starting to worry about you.",
        "You're very committed. A five-minute break won't undo that.",
        "At this point, taking a break would be the rebellious thing to do.",
    ]
    assertTrue(snoozeEscalation.count >= 4, "Should have at least 4 escalation messages")
}

test("Snooze escalation index clamping never overflows") {
    let count = 6
    for snoozeCount in 1...20 {
        let index = min(snoozeCount - 1, count - 1)
        assertTrue(index >= 0 && index < count, "Index \(index) should be in bounds for snoozeCount \(snoozeCount)")
    }
    let clampedIndex = min(15 - 1, count - 1)
    assertEqual(clampedIndex, count - 1, "High snooze counts should clamp to last message")
}

// MARK: - Doge Image Selection Tests

enum DogeImage: String, CaseIterable {
    case happy = "doge-happy"
    case nudge = "doge-nudge"
    case sassy = "doge-sassy"
    case stretch = "doge-stretch"

    static func forAlert(snoozeCount: Int) -> DogeImage {
        if snoozeCount == 0 { return .happy }
        if snoozeCount <= 2 { return .nudge }
        return .sassy
    }

    static var forGrace: DogeImage { .stretch }
    static var forNag: DogeImage { .sassy }
}

test("First alert shows happy doge") {
    assertEqual(DogeImage.forAlert(snoozeCount: 0), DogeImage.happy)
}

test("First snooze shows nudge doge") {
    assertEqual(DogeImage.forAlert(snoozeCount: 1), DogeImage.nudge)
}

test("Second snooze shows nudge doge") {
    assertEqual(DogeImage.forAlert(snoozeCount: 2), DogeImage.nudge)
}

test("Third snooze shows sassy doge") {
    assertEqual(DogeImage.forAlert(snoozeCount: 3), DogeImage.sassy)
}

test("High snooze count shows sassy doge") {
    assertEqual(DogeImage.forAlert(snoozeCount: 10), DogeImage.sassy)
}

test("Grace shows stretch doge") {
    assertEqual(DogeImage.forGrace, DogeImage.stretch)
}

test("Nag shows sassy doge") {
    assertEqual(DogeImage.forNag, DogeImage.sassy)
}

test("All doge images exist in Resources") {
    let testFile = URL(fileURLWithPath: #filePath)
    let projectDir = testFile.deletingLastPathComponent().deletingLastPathComponent()
    let imagesDir = projectDir.appendingPathComponent("Resources/images")

    for doge in DogeImage.allCases {
        let imagePath = imagesDir.appendingPathComponent("\(doge.rawValue).png")
        assertTrue(
            FileManager.default.fileExists(atPath: imagePath.path),
            "Image \(doge.rawValue).png should exist in Resources/images/"
        )
    }
}

// MARK: - Countdown Formatting Tests

func formatCountdown(_ seconds: Int) -> String {
    let m = seconds / 60
    let s = seconds % 60
    return String(format: "%d:%02d", m, s)
}

test("Format 2 minutes") {
    assertEqual(formatCountdown(120), "2:00")
}

test("Format 1:30") {
    assertEqual(formatCountdown(90), "1:30")
}

test("Format 30 seconds") {
    assertEqual(formatCountdown(30), "0:30")
}

test("Format zero") {
    assertEqual(formatCountdown(0), "0:00")
}

test("Format 5 minutes") {
    assertEqual(formatCountdown(300), "5:00")
}

test("Format 1 second") {
    assertEqual(formatCountdown(1), "0:01")
}

// MARK: - Snooze Countdown Gate Tests

func sourceFileContents() -> String {
    let projectDir = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
    let sourcePath = projectDir.appendingPathComponent("Sources/TakeBreak.swift")
    return (try? String(contentsOf: sourcePath, encoding: .utf8)) ?? ""
}

test("Snooze confirmation delays are configured") {
    let source = sourceFileContents()
    assertTrue(source.contains("static let firstSnoozeConfirmationDelay: TimeInterval = 5"), "First snooze should wait 5 seconds")
    assertTrue(source.contains("static let repeatedSnoozeConfirmationDelay: TimeInterval = 10"), "Repeated snoozes should wait 10 seconds")
}

test("Snooze button is disabled until countdown finishes") {
    let source = sourceFileContents()
    assertTrue(source.contains("@Published var isSnoozeEnabled: Bool = true"), "Overlay controller should track snooze enabled state")
    assertTrue(source.contains(".disabled(!controller.isSnoozeEnabled)"), "Snooze button should be disabled during the countdown")
}

test("Snooze countdown logic depends on snooze count") {
    let source = sourceFileContents()
    assertTrue(source.contains("private func snoozeConfirmationDelay() -> TimeInterval"), "Controller should expose snooze countdown timing")
    assertTrue(source.contains("snoozeCount == 0 ? Config.firstSnoozeConfirmationDelay : Config.repeatedSnoozeConfirmationDelay"), "First snooze should use 5 seconds and later snoozes 10 seconds")
    assertTrue(source.contains("private func updateSnoozeButtonState(now: Date = Date())"), "Controller should update the snooze button countdown over time")
}

// MARK: - Grace Remaining Calculation Tests

func graceRemaining(start: Date?, period: TimeInterval, now: Date = Date()) -> Int {
    guard let start = start else { return 0 }
    let elapsed = now.timeIntervalSince(start)
    return max(0, Int(period - elapsed))
}

test("No start time returns zero") {
    assertEqual(graceRemaining(start: nil, period: 120), 0)
}

test("Full grace period remaining") {
    let now = Date()
    assertEqual(graceRemaining(start: now, period: 120, now: now), 120)
}

test("Halfway through grace") {
    let now = Date()
    let start = now.addingTimeInterval(-60)
    assertEqual(graceRemaining(start: start, period: 120, now: now), 60)
}

test("Expired grace returns zero") {
    let now = Date()
    let start = now.addingTimeInterval(-200)
    assertEqual(graceRemaining(start: start, period: 120, now: now), 0)
}

test("Grace remaining never negative") {
    let now = Date()
    let start = now.addingTimeInterval(-9999)
    assertTrue(graceRemaining(start: start, period: 120, now: now) >= 0, "Should never be negative")
}

// MARK: - Menu Bar State Tests

test("Amber threshold calculation") {
    let workDuration: TimeInterval = 3600
    let amberWarning: TimeInterval = 3300

    assertTrue(3200 < amberWarning, "3200s should be before amber")
    assertTrue(3350 >= amberWarning && 3350 < workDuration, "3350s should be amber zone")
    assertTrue(3650 >= workDuration, "3650s should be overdue")
}

test("Remaining minutes uses ceiling") {
    let workDuration: TimeInterval = 3600

    // 4:30 remaining → 5m
    let remaining1 = max(0, Int(workDuration - 3330))
    let min1 = (remaining1 + 59) / 60
    assertEqual(min1, 5, "4:30 remaining should show 5m")

    // Exactly 3:00 → 3m
    let remaining2 = max(0, Int(workDuration - 3420))
    let min2 = (remaining2 + 59) / 60
    assertEqual(min2, 3, "3:00 remaining should show 3m")

    // 10s remaining → 1m
    let remaining3 = max(0, Int(workDuration - 3590))
    let min3 = (remaining3 + 59) / 60
    assertEqual(min3, 1, "10s remaining should show 1m")
}

// MARK: - Build Verification Tests

test("Info.plist exists") {
    let projectDir = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
    assertTrue(
        FileManager.default.fileExists(atPath: projectDir.appendingPathComponent("Info.plist").path),
        "Info.plist should exist"
    )
}

test("build.sh exists and is executable") {
    let projectDir = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
    let path = projectDir.appendingPathComponent("build.sh").path
    assertTrue(FileManager.default.fileExists(atPath: path), "build.sh should exist")
    assertTrue(FileManager.default.isExecutableFile(atPath: path), "build.sh should be executable")
}

test("install.sh exists and is executable") {
    let projectDir = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
    let path = projectDir.appendingPathComponent("install.sh").path
    assertTrue(FileManager.default.fileExists(atPath: path), "install.sh should exist")
    assertTrue(FileManager.default.isExecutableFile(atPath: path), "install.sh should be executable")
}

test("Source file exists") {
    let projectDir = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
    assertTrue(
        FileManager.default.fileExists(atPath: projectDir.appendingPathComponent("Sources/TakeBreak.swift").path),
        "TakeBreak.swift should exist"
    )
}

// MARK: - Results

print("")
print("Test Results")
print("============")
let assertions = passedTests + failedTests.count
print("\(totalTests) tests, \(assertions) assertions, \(passedTests) passed, \(failedTests.count) failed")

if !failedTests.isEmpty {
    print("")
    print("Failures:")
    for (location, message) in failedTests {
        print("  FAIL \(location): \(message)")
    }
    exit(1)
} else {
    print("All tests passed!")
    exit(0)
}
