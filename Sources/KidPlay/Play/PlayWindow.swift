import AppKit

/// Key-capable borderless window so swallowed keys don't trigger the system "funk" beep as often.
final class PlayWindow: NSWindow {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

/// First-responder sink for any key events that still reach the app.
final class KeySinkView: NSView {
    var onKey: ((UInt16, String?) -> Void)?

    override var acceptsFirstResponder: Bool { true }

    override func keyDown(with event: NSEvent) {
        onKey?(event.keyCode, event.charactersIgnoringModifiers)
        // Do not call super — avoids NSBeep for unhandled keys.
    }

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        onKey?(event.keyCode, event.charactersIgnoringModifiers)
        return true
    }
}
