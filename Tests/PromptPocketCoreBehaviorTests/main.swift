import Foundation
import PromptPocketCore

func expect(_ condition: @autoclosure () -> Bool, _ message: String) {
    if !condition() {
        FileHandle.standardError.write("FAIL: \(message)\n".data(using: .utf8)!)
        exit(1)
    }
}

func testAppendingFirstCaptureStoresTextExactly() {
    var buffer = NoteBuffer()
    let appended = buffer.appendCapture("hello prompt")
    expect(appended == true, "first capture should append")
    expect(buffer.text == "hello prompt", "first capture should preserve text exactly")
}

func testAppendingMultipleCapturesSeparatesThemWithBlankLine() {
    var buffer = NoteBuffer()
    expect(buffer.appendCapture("first") == true, "first capture should append")
    expect(buffer.appendCapture("second") == true, "second capture should append")
    expect(buffer.text == "first\n\nsecond", "captures should be separated by a blank line")
}

func testWhitespaceOnlyCaptureIsIgnored() {
    var buffer = NoteBuffer(text: "existing")
    let appended = buffer.appendCapture("  \n\t  ")
    expect(appended == false, "whitespace-only capture should be ignored")
    expect(buffer.text == "existing", "whitespace-only capture should not change text")
}

func testClearRemovesAllText() {
    var buffer = NoteBuffer(text: "saved prompt")
    buffer.clear()
    expect(buffer.text == "", "clear should remove all text")
}

func testCloseButtonHidesPanelWithoutTerminatingBackgroundApp() {
    expect(PromptPocketLifecyclePolicy.bundleIdentifier == "com.hwangseonghyeon.promptpocket", "bundle identifier should stay stable for macOS permissions")
    expect(PromptPocketLifecyclePolicy.showExistingInstanceNotification == "com.hwangseonghyeon.promptpocket.show", "show notification should stay stable for duplicate launches")
    expect(PromptPocketLifecyclePolicy.shouldClosePanelOnCloseRequest == false, "close button should hide the panel instead of closing it")
    expect(PromptPocketLifecyclePolicy.shouldTerminateAfterLastWindowClosed == false, "app should keep running after the panel is hidden")
}

func testCapturedTextBecomesFinalClipboardText() {
    expect(CaptureClipboardPolicy.finalClipboardString(afterCapturing: "codex prompt", previousClipboardString: "old") == "codex prompt", "captured text should replace the previous clipboard text")
    expect(CaptureClipboardPolicy.finalClipboardString(afterCapturing: "  \n\t  ", previousClipboardString: "old") == "old", "blank captures should not erase the previous clipboard text")
}

func testKeyboardFallbackCutsBeforeCopyDeleteFallback() {
    let attempts = KeyboardCaptureFallbackPlan.attempts
    expect(attempts.count == 2, "keyboard fallback should have a preferred attempt and a compatibility fallback")
    expect(attempts[0] == [.selectAll, .cutToClipboard], "Codex/Electron-like inputs should first use Cmd+A then Cmd+X so copy and clear happen atomically")
    expect(attempts[1] == [.selectAll, .copyToClipboard, .deleteSelection], "older compatible fallback should remain for apps where Cut is unavailable")
}

testAppendingFirstCaptureStoresTextExactly()
testAppendingMultipleCapturesSeparatesThemWithBlankLine()
testWhitespaceOnlyCaptureIsIgnored()
testClearRemovesAllText()
testCloseButtonHidesPanelWithoutTerminatingBackgroundApp()
testCapturedTextBecomesFinalClipboardText()
testKeyboardFallbackCutsBeforeCopyDeleteFallback()
print("PromptPocketCoreBehaviorTests: 7 passed")
