import AppKit
import Foundation

/// Soft key click via NSSound (not AudioServices — those sounded like the blocked-key funk).
@MainActor
final class SoftSoundPlayer {
    private var lastKeySound = Date.distantPast
    private let keyMinInterval: TimeInterval = 0.06
    private let sound: NSSound?

    init() {
        // Built-in macOS sounds; quiet volume.
        let candidates = ["Tink", "Pop", "Purr", "Bottle"]
        var loaded: NSSound?
        for name in candidates {
            if let s = NSSound(named: NSSound.Name(name)) {
                s.volume = 0.22
                loaded = s
                break
            }
        }
        sound = loaded
    }

    func playKey() {
        let now = Date()
        guard now.timeIntervalSince(lastKeySound) >= keyMinInterval else { return }
        lastKeySound = now
        guard let sound else { return }
        // Clone so overlapping presses don't cut each other harshly.
        if let clone = sound.copy() as? NSSound {
            clone.volume = 0.18 + Float.random(in: 0...0.1)
            clone.play()
        } else {
            sound.play()
        }
    }
}
