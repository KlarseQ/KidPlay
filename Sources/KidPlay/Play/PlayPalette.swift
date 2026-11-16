import AppKit
import SpriteKit

/// Bright kid-facing colors for streaks / symbols when «использовать цвета» is on.
enum PlayPalette {
    /// Hue steps that stay vivid on a near-black field.
    private static let hues: [CGFloat] = [
        0.00, 0.08, 0.14, 0.22, 0.33, 0.45, 0.55, 0.63, 0.72, 0.83, 0.92,
    ]

    static func streakNSColor(level: Int) -> NSColor {
        let idx = max(0, level - 1) % hues.count
        let hue = hues[idx]
        // Escalate saturation / brightness a bit as the streak climbs.
        let sat = min(1.0, 0.75 + Double(min(level, 20)) * 0.01)
        let bri = min(1.0, 0.85 + Double(min(level, 15)) * 0.008)
        return NSColor(calibratedHue: hue, saturation: sat, brightness: bri, alpha: 1)
    }

    static func randomSymbolSKColor() -> SKColor {
        let hue = hues.randomElement() ?? CGFloat.random(in: 0...1)
        return SKColor(
            calibratedHue: hue,
            saturation: CGFloat.random(in: 0.72...1.0),
            brightness: CGFloat.random(in: 0.88...1.0),
            alpha: 0.98
        )
    }

    static func randomInkSKColor(alpha: CGFloat) -> SKColor {
        let hue = hues.randomElement() ?? CGFloat.random(in: 0...1)
        return SKColor(
            calibratedHue: hue,
            saturation: CGFloat.random(in: 0.55...0.95),
            brightness: CGFloat.random(in: 0.45...0.85),
            alpha: alpha
        )
    }
}
