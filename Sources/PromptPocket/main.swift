import AppKit
import ApplicationServices
import PromptPocketCore

private let keyCodeA: CGKeyCode = 0
private let keyCodeC: CGKeyCode = 8
private let keyCodeL: CGKeyCode = 37
private let keyCodeX: CGKeyCode = 7
private let keyCodeDelete: CGKeyCode = 51
private let rightCommandDeviceMask: UInt64 = 0x00000010

private enum CaptureMethod: String {
    case accessibility = "Accessibility"
    case keyboardCutFallback = "Keyboard fallback: Cmd+A → Cmd+X"
    case keyboardCopyDeleteFallback = "Keyboard fallback: Cmd+A → Cmd+C → Delete"
}

private enum CaptureOutcome {
    case captured(text: String, method: CaptureMethod)
    case empty
    case permissionMissing
    case failed(String)
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var panelController: PromptPocketPanelController!
    private var hotKeyMonitor: HotKeyMonitor?
    private let captureService = FocusedTextCaptureService()

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        DistributedNotificationCenter.default().addObserver(
            self,
            selector: #selector(showFromDuplicateLaunchRequest),
            name: .promptPocketShowRequested,
            object: nil
        )

        panelController = PromptPocketPanelController()
        panelController.show()
        requestAccessibilityPermissionIfNeeded()

        let monitor = HotKeyMonitor { [weak self] in
            self?.moveFocusedTextIntoPocket()
        }
        hotKeyMonitor = monitor

        if monitor.start() {
            panelController.showStatus("오른쪽 ⌘ + L 로 입력 중인 텍스트를 옮겨둘 수 있어요.")
        } else {
            panelController.showStatus("키 감지 실패: Accessibility/Input Monitoring 권한을 확인해줘요.")
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        PromptPocketLifecyclePolicy.shouldTerminateAfterLastWindowClosed
    }

    @objc private func showFromDuplicateLaunchRequest() {
        panelController?.show()
    }

    private func requestAccessibilityPermissionIfNeeded() {
        let promptKey = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        let options = [promptKey: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
    }

    private func moveFocusedTextIntoPocket() {
        let outcome = captureService.captureAndClearFocusedText()

        switch outcome {
        case .captured(let text, let method):
            publishCapturedTextToClipboard(text)
            panelController.appendCapturedText(text, method: method.rawValue)
        case .empty:
            panelController.showStatus("옮길 텍스트가 없어요.")
            panelController.show()
        case .permissionMissing:
            panelController.showStatus("Accessibility 권한이 필요해요. 시스템 설정에서 PromptPocket을 허용해줘요.")
            panelController.show()
        case .failed(let message):
            panelController.showStatus(message)
            panelController.show()
        }
    }

    private func publishCapturedTextToClipboard(_ text: String) {
        let pasteboard = NSPasteboard.general
        let previousClipboardString = pasteboard.string(forType: .string)
        guard let finalClipboardString = CaptureClipboardPolicy.finalClipboardString(
            afterCapturing: text,
            previousClipboardString: previousClipboardString
        ) else {
            return
        }

        pasteboard.clearContents()
        pasteboard.setString(finalClipboardString, forType: .string)
    }
}

final class PromptPocketPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

final class PromptPocketPanelController: NSObject, NSTextViewDelegate, NSWindowDelegate {
    private let panel: PromptPocketPanel
    private let textView = NSTextView()
    private let statusLabel = NSTextField(labelWithString: "")
    private var buffer = NoteBuffer()

    override init() {
        let initialSize = NSSize(width: 516, height: 360) // 4.3:3 ratio
        let visibleFrame = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
        let origin = NSPoint(
            x: visibleFrame.maxX - initialSize.width - 24,
            y: visibleFrame.maxY - initialSize.height - 44
        )

        panel = PromptPocketPanel(
            contentRect: NSRect(origin: origin, size: initialSize),
            styleMask: [.titled, .closable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )

        super.init()
        configurePanel()
        configureContentView()
    }

    func show() {
        panel.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.screenSaverWindow)))
        panel.orderFrontRegardless()
    }

    func appendCapturedText(_ text: String, method: String) {
        guard buffer.appendCapture(text) else {
            showStatus("옮길 텍스트가 없어요.")
            show()
            return
        }

        textView.string = buffer.text
        textView.textStorage?.setAttributedString(NSAttributedString(string: buffer.text, attributes: textAttributes()))
        textView.layoutManager?.ensureLayout(for: textView.textContainer!)
        textView.needsDisplay = true
        textView.scrollToEndOfDocument(nil)
        showStatus("\(text.count)자 옮김 · \(preview(text)) · \(method)")
        show()
    }

    func showStatus(_ message: String) {
        statusLabel.stringValue = message
    }

    private func textAttributes() -> [NSAttributedString.Key: Any] {
        [
            .font: NSFont.monospacedSystemFont(ofSize: 14, weight: .regular),
            .foregroundColor: NSColor.labelColor
        ]
    }

    private func preview(_ text: String) -> String {
        let collapsed = text
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let maxLength = 36
        if collapsed.count <= maxLength {
            return "“\(collapsed)”"
        }
        return "“\(String(collapsed.prefix(maxLength)))…”"
    }

    func textDidChange(_ notification: Notification) {
        buffer = NoteBuffer(text: textView.string)
    }

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        showStatus("백그라운드 대기 중 · 오른쪽 ⌘ + L로 다시 띄워요.")
        sender.orderOut(nil)
        return PromptPocketLifecyclePolicy.shouldClosePanelOnCloseRequest
    }

    @objc private func clearNote() {
        buffer.clear()
        textView.string = ""
        showStatus("메모를 비웠어요.")
    }

    @objc private func quitApp() {
        NSApp.terminate(nil)
    }

    private func configurePanel() {
        panel.title = "PromptPocket"
        panel.delegate = self
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        panel.isReleasedWhenClosed = false
        panel.hidesOnDeactivate = false
        panel.isMovableByWindowBackground = true
        panel.minSize = NSSize(width: 344, height: 240)
        panel.collectionBehavior = [
            .canJoinAllSpaces,
            .fullScreenAuxiliary,
            .stationary,
            .ignoresCycle
        ]
        panel.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.screenSaverWindow)))
        panel.backgroundColor = .clear
        panel.isOpaque = false
    }

    private func configureContentView() {
        let root = NSVisualEffectView()
        root.translatesAutoresizingMaskIntoConstraints = false
        root.material = .hudWindow
        root.blendingMode = .behindWindow
        root.state = .active
        root.wantsLayer = true
        root.layer?.cornerRadius = 16
        root.layer?.masksToBounds = true

        let titleLabel = NSTextField(labelWithString: "PromptPocket")
        titleLabel.font = .systemFont(ofSize: 15, weight: .semibold)
        titleLabel.textColor = .labelColor
        titleLabel.translatesAutoresizingMaskIntoConstraints = false

        statusLabel.font = .systemFont(ofSize: 11, weight: .regular)
        statusLabel.textColor = .secondaryLabelColor
        statusLabel.lineBreakMode = .byTruncatingTail
        statusLabel.translatesAutoresizingMaskIntoConstraints = false

        let clearButton = NSButton(title: "비우기", target: self, action: #selector(clearNote))
        clearButton.bezelStyle = .rounded
        clearButton.controlSize = .small
        clearButton.translatesAutoresizingMaskIntoConstraints = false

        let quitButton = NSButton(title: "종료", target: self, action: #selector(quitApp))
        quitButton.bezelStyle = .rounded
        quitButton.controlSize = .small
        quitButton.translatesAutoresizingMaskIntoConstraints = false

        textView.delegate = self
        textView.isRichText = false
        textView.importsGraphics = false
        textView.allowsUndo = true
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.font = .monospacedSystemFont(ofSize: 14, weight: .regular)
        textView.textColor = .labelColor
        textView.typingAttributes = textAttributes()
        textView.drawsBackground = false
        textView.backgroundColor = .clear
        textView.textContainerInset = NSSize(width: 14, height: 14)
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]
        textView.minSize = NSSize(width: 0, height: 0)
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.textContainer?.widthTracksTextView = true
        textView.textContainer?.containerSize = NSSize(width: 0, height: CGFloat.greatestFiniteMagnitude)
        textView.string = ""

        let scrollView = NSScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.borderType = .noBorder
        scrollView.drawsBackground = false
        scrollView.contentView.drawsBackground = false
        scrollView.documentView = textView
        textView.frame = scrollView.contentView.bounds
        textView.textContainer?.containerSize = NSSize(width: scrollView.contentSize.width, height: CGFloat.greatestFiniteMagnitude)

        let notePaperView = NotePaperView()
        notePaperView.translatesAutoresizingMaskIntoConstraints = false
        notePaperView.addSubview(scrollView)

        root.addSubview(titleLabel)
        root.addSubview(statusLabel)
        root.addSubview(clearButton)
        root.addSubview(quitButton)
        root.addSubview(notePaperView)
        panel.contentView = root

        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: root.topAnchor, constant: 14),
            titleLabel.leadingAnchor.constraint(equalTo: root.leadingAnchor, constant: 16),

            quitButton.centerYAnchor.constraint(equalTo: titleLabel.centerYAnchor),
            quitButton.trailingAnchor.constraint(equalTo: root.trailingAnchor, constant: -14),

            clearButton.centerYAnchor.constraint(equalTo: titleLabel.centerYAnchor),
            clearButton.trailingAnchor.constraint(equalTo: quitButton.leadingAnchor, constant: -8),

            statusLabel.leadingAnchor.constraint(equalTo: titleLabel.trailingAnchor, constant: 12),
            statusLabel.trailingAnchor.constraint(lessThanOrEqualTo: clearButton.leadingAnchor, constant: -12),
            statusLabel.centerYAnchor.constraint(equalTo: titleLabel.centerYAnchor),

            notePaperView.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 12),
            notePaperView.leadingAnchor.constraint(equalTo: root.leadingAnchor, constant: 14),
            notePaperView.trailingAnchor.constraint(equalTo: root.trailingAnchor, constant: -14),
            notePaperView.bottomAnchor.constraint(equalTo: root.bottomAnchor, constant: -14),

            scrollView.topAnchor.constraint(equalTo: notePaperView.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: notePaperView.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: notePaperView.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: notePaperView.bottomAnchor)
        ])
    }
}

private final class NotePaperView: NSView {
    private static let cornerRadius: CGFloat = 14
    private static var textureCache: [NotePaperAppearance: NSImage] = [:]

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        configureLayer()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        configureLayer()
    }

    override func draw(_ dirtyRect: NSRect) {
        let palette = NotePaperPalette(appearance: notePaperAppearance)
        layer?.borderColor = palette.border.cgColor

        NSGraphicsContext.saveGraphicsState()
        NSColor(patternImage: Self.texture(for: notePaperAppearance, palette: palette)).setFill()
        bounds.fill()
        palette.surfaceWash.setFill()
        bounds.fill(using: .sourceAtop)
        NSGraphicsContext.restoreGraphicsState()
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        needsDisplay = true
    }

    private var notePaperAppearance: NotePaperAppearance {
        effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? .dark : .light
    }

    private func configureLayer() {
        wantsLayer = true
        layer?.cornerRadius = Self.cornerRadius
        layer?.masksToBounds = true
        layer?.borderWidth = 1
        layer?.contentsScale = NSScreen.main?.backingScaleFactor ?? 2
        if #available(macOS 10.15, *) {
            layer?.cornerCurve = .continuous
        }
    }

    private static func texture(for appearance: NotePaperAppearance, palette: NotePaperPalette) -> NSImage {
        if let cached = textureCache[appearance] {
            return cached
        }

        let size = 96
        let image = NSImage(size: NSSize(width: size, height: size))
        image.lockFocus()

        guard let context = NSGraphicsContext.current?.cgContext else {
            image.unlockFocus()
            return image
        }

        for y in 0..<size {
            for x in 0..<size {
                let grain = deterministicNoise(x: x, y: y, seed: 31) - 0.5
                let fiber = deterministicNoise(x: x / 3, y: y, seed: 83) - 0.5
                let crossFiber = deterministicNoise(x: x, y: y / 7, seed: 151) - 0.5
                let variation = grain * palette.grainStrength
                    + fiber * palette.fiberStrength
                    + crossFiber * palette.crossFiberStrength

                var color = palette.base.adjusted(by: variation)
                if y % 18 == 0 || y % 18 == 1 {
                    color = color.blended(with: palette.ruleLine, amount: palette.ruleLineAmount)
                }
                if deterministicNoise(x: x, y: y, seed: 229) > 0.985 {
                    color = color.blended(with: palette.speck, amount: palette.speckAmount)
                }

                context.setFillColor(color.cgColor)
                context.fill(CGRect(x: x, y: y, width: 1, height: 1))
            }
        }

        image.unlockFocus()
        image.isTemplate = false
        textureCache[appearance] = image
        return image
    }

    private static func deterministicNoise(x: Int, y: Int, seed: UInt32) -> CGFloat {
        var value = UInt32(x) &* 374_761_393
        value = value &+ UInt32(y) &* 668_265_263
        value = value &+ seed &* 2_246_822_519
        value = (value ^ (value >> 13)) &* 1_274_126_177
        value = value ^ (value >> 16)
        return CGFloat(value & 0xffff) / CGFloat(UInt16.max)
    }
}

private enum NotePaperAppearance: Hashable {
    case light
    case dark
}

private struct NotePaperPalette {
    let base: NSColor
    let surfaceWash: NSColor
    let border: NSColor
    let ruleLine: NSColor
    let speck: NSColor
    let grainStrength: CGFloat
    let fiberStrength: CGFloat
    let crossFiberStrength: CGFloat
    let ruleLineAmount: CGFloat
    let speckAmount: CGFloat

    init(appearance: NotePaperAppearance) {
        switch appearance {
        case .light:
            base = NSColor(deviceRed: 0.965, green: 0.936, blue: 0.824, alpha: 1)
            surfaceWash = NSColor(deviceRed: 1.0, green: 0.965, blue: 0.83, alpha: 0.16)
            border = NSColor(deviceRed: 0.52, green: 0.42, blue: 0.24, alpha: 0.28)
            ruleLine = NSColor(deviceRed: 0.72, green: 0.52, blue: 0.28, alpha: 1)
            speck = NSColor(deviceRed: 0.48, green: 0.35, blue: 0.18, alpha: 1)
            grainStrength = 0.026
            fiberStrength = 0.020
            crossFiberStrength = 0.010
            ruleLineAmount = 0.035
            speckAmount = 0.11
        case .dark:
            base = NSColor(deviceRed: 0.145, green: 0.129, blue: 0.095, alpha: 1)
            surfaceWash = NSColor(deviceRed: 0.22, green: 0.18, blue: 0.12, alpha: 0.20)
            border = NSColor(deviceRed: 0.72, green: 0.58, blue: 0.36, alpha: 0.20)
            ruleLine = NSColor(deviceRed: 0.46, green: 0.35, blue: 0.20, alpha: 1)
            speck = NSColor(deviceRed: 0.72, green: 0.58, blue: 0.34, alpha: 1)
            grainStrength = 0.018
            fiberStrength = 0.016
            crossFiberStrength = 0.008
            ruleLineAmount = 0.045
            speckAmount = 0.09
        }
    }
}

private extension NSColor {
    func adjusted(by delta: CGFloat) -> NSColor {
        let color = usingColorSpace(.deviceRGB) ?? self
        return NSColor(
            deviceRed: clamp(color.redComponent + delta),
            green: clamp(color.greenComponent + delta * 0.92),
            blue: clamp(color.blueComponent + delta * 0.72),
            alpha: color.alphaComponent
        )
    }

    func blended(with overlay: NSColor, amount: CGFloat) -> NSColor {
        let base = usingColorSpace(.deviceRGB) ?? self
        let top = overlay.usingColorSpace(.deviceRGB) ?? overlay
        return NSColor(
            deviceRed: base.redComponent * (1 - amount) + top.redComponent * amount,
            green: base.greenComponent * (1 - amount) + top.greenComponent * amount,
            blue: base.blueComponent * (1 - amount) + top.blueComponent * amount,
            alpha: base.alphaComponent
        )
    }

    private func clamp(_ value: CGFloat) -> CGFloat {
        min(max(value, 0), 1)
    }
}

final class HotKeyMonitor {
    private let handler: () -> Void
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?

    init(handler: @escaping () -> Void) {
        self.handler = handler
    }

    func start() -> Bool {
        let eventMask = CGEventMask(1 << CGEventType.keyDown.rawValue)
        let refcon = UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: eventMask,
            callback: HotKeyMonitor.eventCallback,
            userInfo: refcon
        ) else {
            return false
        }

        eventTap = tap
        runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        if let runLoopSource {
            CFRunLoopAddSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        }
        CGEvent.tapEnable(tap: tap, enable: true)
        return true
    }

    deinit {
        if let eventTap {
            CGEvent.tapEnable(tap: eventTap, enable: false)
        }
        if let runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        }
    }

    private static let eventCallback: CGEventTapCallBack = { _, type, event, refcon in
        guard let refcon else {
            return Unmanaged.passUnretained(event)
        }

        let monitor = Unmanaged<HotKeyMonitor>.fromOpaque(refcon).takeUnretainedValue()

        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let eventTap = monitor.eventTap {
                CGEvent.tapEnable(tap: eventTap, enable: true)
            }
            return Unmanaged.passUnretained(event)
        }

        guard type == .keyDown else {
            return Unmanaged.passUnretained(event)
        }

        if monitor.isRightCommandL(event) {
            DispatchQueue.main.async {
                monitor.handler()
            }
            return nil
        }

        return Unmanaged.passUnretained(event)
    }

    private func isRightCommandL(_ event: CGEvent) -> Bool {
        let keyCode = CGKeyCode(event.getIntegerValueField(.keyboardEventKeycode))
        guard keyCode == keyCodeL else { return false }

        let rawFlags = event.flags.rawValue
        let commandDown = event.flags.contains(.maskCommand)
        let rightCommandDown = (rawFlags & rightCommandDeviceMask) != 0
        let disallowedModifiers = CGEventFlags.maskAlternate.rawValue
            | CGEventFlags.maskControl.rawValue
            | CGEventFlags.maskShift.rawValue

        return commandDown && rightCommandDown && (rawFlags & disallowedModifiers) == 0
    }
}

private final class FocusedTextCaptureService {
    func captureAndClearFocusedText() -> CaptureOutcome {
        guard AXIsProcessTrusted() else {
            return .permissionMissing
        }

        if let axText = captureUsingAccessibility() {
            if axText.containsNonWhitespace {
                return .captured(text: axText, method: .accessibility)
            }
            return .empty
        }

        if let fallback = captureUsingKeyboardFallback() {
            if fallback.text.containsNonWhitespace {
                return .captured(text: fallback.text, method: fallback.method)
            }
            return .empty
        }

        return .failed("텍스트를 읽지 못했어요. 포커스가 입력창에 있는지 확인해줘요.")
    }

    private func captureUsingAccessibility() -> String? {
        let systemWideElement = AXUIElementCreateSystemWide()
        var focusedReference: CFTypeRef?
        let focusedError = AXUIElementCopyAttributeValue(
            systemWideElement,
            kAXFocusedUIElementAttribute as CFString,
            &focusedReference
        )

        guard focusedError == .success, let focusedReference else {
            return nil
        }

        let focusedElement = focusedReference as! AXUIElement
        var valueReference: CFTypeRef?
        let valueError = AXUIElementCopyAttributeValue(
            focusedElement,
            kAXValueAttribute as CFString,
            &valueReference
        )

        guard valueError == .success, let text = valueReference as? String else {
            return nil
        }

        guard text.containsNonWhitespace else {
            return ""
        }

        let clearError = AXUIElementSetAttributeValue(
            focusedElement,
            kAXValueAttribute as CFString,
            "" as CFString
        )

        guard clearError == .success else {
            return nil
        }

        return text
    }

    private func captureUsingKeyboardFallback() -> (text: String, method: CaptureMethod)? {
        let pasteboard = NSPasteboard.general

        for attempt in KeyboardCaptureFallbackPlan.attempts {
            if let capturedText = performKeyboardCaptureAttempt(attempt, on: pasteboard) {
                let method: CaptureMethod = attempt.contains(.cutToClipboard)
                    ? .keyboardCutFallback
                    : .keyboardCopyDeleteFallback
                return (capturedText, method)
            }
        }

        return nil
    }

    private func performKeyboardCaptureAttempt(_ attempt: [KeyboardCaptureOperation], on pasteboard: NSPasteboard) -> String? {
        let oldChangeCount = pasteboard.changeCount
        var capturedText: String?

        for operation in attempt {
            switch operation {
            case .selectAll:
                postShortcut(keyCodeA, flags: .maskCommand)
                Thread.sleep(forTimeInterval: 0.12)
            case .cutToClipboard:
                postShortcut(keyCodeX, flags: .maskCommand)
                capturedText = waitForCopiedString(on: pasteboard, oldChangeCount: oldChangeCount, timeout: 1.5)
                guard capturedText?.containsNonWhitespace == true else { return nil }
            case .copyToClipboard:
                postShortcut(keyCodeC, flags: .maskCommand)
                capturedText = waitForCopiedString(on: pasteboard, oldChangeCount: oldChangeCount, timeout: 1.5)
                guard capturedText?.containsNonWhitespace == true else { return nil }
            case .deleteSelection:
                postKey(keyCodeDelete)
                Thread.sleep(forTimeInterval: 0.08)
            }
        }

        guard let capturedText, capturedText.containsNonWhitespace else {
            return nil
        }
        return capturedText
    }

    private func waitForCopiedString(on pasteboard: NSPasteboard, oldChangeCount: Int, timeout: TimeInterval) -> String? {
        let deadline = Date().addingTimeInterval(timeout)

        while Date() < deadline {
            if pasteboard.changeCount != oldChangeCount,
               let copiedString = pasteboard.string(forType: .string),
               copiedString.containsNonWhitespace {
                return copiedString
            }
            Thread.sleep(forTimeInterval: 0.03)
        }

        return nil
    }

    private func postShortcut(_ keyCode: CGKeyCode, flags: CGEventFlags) {
        postKey(keyCode, flags: flags)
    }

    private func postKey(_ keyCode: CGKeyCode, flags: CGEventFlags = []) {
        let source = CGEventSource(stateID: .hidSystemState)
        source?.localEventsSuppressionInterval = 0

        let keyDown = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: true)
        keyDown?.flags = flags
        keyDown?.post(tap: .cghidEventTap)

        let keyUp = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: false)
        keyUp?.flags = flags
        keyUp?.post(tap: .cghidEventTap)
    }
}

private extension String {
    var containsNonWhitespace: Bool {
        rangeOfCharacter(from: CharacterSet.whitespacesAndNewlines.inverted) != nil
    }
}

private extension Notification.Name {
    static let promptPocketShowRequested = Notification.Name(PromptPocketLifecyclePolicy.showExistingInstanceNotification)
}

private func handOffToExistingInstanceIfNeeded() {
    let currentPID = ProcessInfo.processInfo.processIdentifier
    let existingInstances = NSRunningApplication
        .runningApplications(withBundleIdentifier: PromptPocketLifecyclePolicy.bundleIdentifier)
        .filter { $0.processIdentifier != currentPID && !$0.isTerminated }

    guard !existingInstances.isEmpty else { return }

    DistributedNotificationCenter.default().postNotificationName(
        .promptPocketShowRequested,
        object: nil,
        userInfo: nil,
        deliverImmediately: true
    )
    existingInstances.first?.activate(options: [.activateIgnoringOtherApps])
    exit(0)
}

handOffToExistingInstanceIfNeeded()
let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()
