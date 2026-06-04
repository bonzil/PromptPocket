import Foundation

public struct PromptPocketLifecyclePolicy: Equatable {
    public static let bundleIdentifier = "com.hwangseonghyeon.promptpocket"
    public static let showExistingInstanceNotification = "com.hwangseonghyeon.promptpocket.show"
    public static let shouldClosePanelOnCloseRequest = false
    public static let shouldTerminateAfterLastWindowClosed = false
}

public struct NoteBuffer: Equatable {
    public private(set) var text: String

    public init(text: String = "") {
        self.text = text
    }

    @discardableResult
    public mutating func appendCapture(_ capturedText: String) -> Bool {
        guard capturedText.containsNonWhitespace else {
            return false
        }

        if text.isEmpty {
            text = capturedText
        } else {
            text += "\n\n" + capturedText
        }

        return true
    }

    public mutating func clear() {
        text = ""
    }
}

public struct CaptureClipboardPolicy: Equatable {
    public static func finalClipboardString(afterCapturing capturedText: String, previousClipboardString: String?) -> String? {
        capturedText.containsNonWhitespace ? capturedText : previousClipboardString
    }
}

public enum KeyboardCaptureOperation: Equatable {
    case selectAll
    case cutToClipboard
    case copyToClipboard
    case deleteSelection
}

public struct KeyboardCaptureFallbackPlan: Equatable {
    public static let attempts: [[KeyboardCaptureOperation]] = [
        [.selectAll, .cutToClipboard],
        [.selectAll, .copyToClipboard, .deleteSelection]
    ]
}

private extension String {
    var containsNonWhitespace: Bool {
        rangeOfCharacter(from: CharacterSet.whitespacesAndNewlines.inverted) != nil
    }
}
