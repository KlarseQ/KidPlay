import CoreGraphics
import Foundation

struct KeyVisual: Sendable {
    enum Kind: Sendable {
        /// Letter key: only this key's latin/cyrillic pair, random case.
        case letter(latin: Character, cyrillic: Character)
        /// Digit key: show the digit (and optional shifted symbol rarely).
        case digit(Character, shifted: Character?)
        /// Named special key — always show its label.
        case named(String)
    }

    let kind: Kind
    /// Normalized keyboard position (0...1), lower area of screen.
    let nx: CGFloat
    let ny: CGFloat
}

enum KeyLayout {
    /// Physical Mac ANSI key → visual + on-screen keyboard slot.
    private static let table: [Int64: KeyVisual] = {
        func L(_ lat: Character, _ cyr: Character, _ x: CGFloat, _ y: CGFloat) -> KeyVisual {
            KeyVisual(kind: .letter(latin: lat, cyrillic: cyr), nx: x, ny: y)
        }
        func D(_ d: Character, _ shift: Character?, _ x: CGFloat, _ y: CGFloat) -> KeyVisual {
            KeyVisual(kind: .digit(d, shifted: shift), nx: x, ny: y)
        }
        func N(_ name: String, _ x: CGFloat, _ y: CGFloat) -> KeyVisual {
            KeyVisual(kind: .named(name), nx: x, ny: y)
        }

        // Rows roughly match a MacBook keyboard projected to the lower half of the display.
        let r0: CGFloat = 0.44 // numbers
        let r1: CGFloat = 0.36 // qwerty
        let r2: CGFloat = 0.28 // asdf
        let r3: CGFloat = 0.20 // zxcv
        let r4: CGFloat = 0.12 // space row

        return [
            // digits
            18: D("1", "!", 0.14, r0), 19: D("2", "@", 0.21, r0), 20: D("3", "#", 0.28, r0),
            21: D("4", "$", 0.35, r0), 23: D("5", "%", 0.42, r0), 22: D("6", "^", 0.49, r0),
            26: D("7", "&", 0.56, r0), 28: D("8", "*", 0.63, r0), 25: D("9", "(", 0.70, r0),
            29: D("0", ")", 0.77, r0),

            // qwerty / йцукен
            12: L("q", "й", 0.16, r1), 13: L("w", "ц", 0.23, r1), 14: L("e", "у", 0.30, r1),
            15: L("r", "к", 0.37, r1), 17: L("t", "е", 0.44, r1), 16: L("y", "н", 0.51, r1),
            32: L("u", "г", 0.58, r1), 34: L("i", "ш", 0.65, r1), 31: L("o", "щ", 0.72, r1),
            35: L("p", "з", 0.79, r1),
            33: N("[", 0.86, r1), 30: N("]", 0.90, r1),

            // asdf
            0: L("a", "ф", 0.19, r2), 1: L("s", "ы", 0.26, r2), 2: L("d", "в", 0.33, r2),
            3: L("f", "а", 0.40, r2), 5: L("g", "п", 0.47, r2), 4: L("h", "р", 0.54, r2),
            38: L("j", "о", 0.61, r2), 40: L("k", "л", 0.68, r2), 37: L("l", "д", 0.75, r2),
            41: N(";", 0.82, r2), 39: N("'", 0.87, r2),

            // zxcv
            6: L("z", "я", 0.24, r3), 7: L("x", "ч", 0.31, r3), 8: L("c", "с", 0.38, r3),
            9: L("v", "м", 0.45, r3), 11: L("b", "и", 0.52, r3), 45: L("n", "т", 0.59, r3),
            46: L("m", "ь", 0.66, r3),
            43: N(",", 0.73, r3), 47: N(".", 0.78, r3), 44: N("/", 0.83, r3),

            // specials
            49: N("пробел", 0.50, r4),
            48: N("tab", 0.10, r1),
            36: N("return", 0.90, r2),
            51: N("delete", 0.88, r0),
            53: N("esc", 0.06, r0),
            57: N("caps", 0.10, r2),
            56: N("shift", 0.10, r3), // left shift
            60: N("shift", 0.90, r3), // right shift
            59: N("control", 0.12, r4),
            58: N("option", 0.20, r4),
            55: N("command", 0.30, r4),
            54: N("command", 0.70, r4), // right cmd
            61: N("option", 0.78, r4), // right opt
            62: N("control", 0.86, r4),
            63: N("fn", 0.06, r4),
            50: N("`", 0.08, r0),
            27: N("-", 0.84, r0),
            24: N("=", 0.90, r0),
        ]
    }()

    static func visual(forKeyCode keyCode: Int64) -> KeyVisual? {
        table[keyCode]
    }

    /// Text to show for this key press.
    static func displayText(forKeyCode keyCode: Int64) -> String {
        guard let visual = table[keyCode] else {
            return "•"
        }
        switch visual.kind {
        case .named(let name):
            return name
        case .digit(let d, let shifted):
            if let shifted, Bool.random(), Double.random(in: 0...1) < 0.25 {
                return String(shifted)
            }
            return String(d)
        case .letter(let latin, let cyrillic):
            // Only this key's pair: z/Z/я/Я — never unrelated letters.
            let options: [String] = [
                String(latin),
                String(latin).uppercased(),
                String(cyrillic),
                String(cyrillic).uppercased(),
            ]
            return options.randomElement() ?? String(latin)
        }
    }

    /// Scene point for this key, with random radius jitter.
    static func spawnPoint(forKeyCode keyCode: Int64, sceneSize: CGSize, radius: CGFloat = 56) -> CGPoint {
        let visual = table[keyCode]
        let nx = visual?.nx ?? CGFloat.random(in: 0.2...0.8)
        let ny = visual?.ny ?? CGFloat.random(in: 0.15...0.4)
        let base = CGPoint(x: sceneSize.width * nx, y: sceneSize.height * ny)
        let angle = CGFloat.random(in: 0...(2 * .pi))
        let dist = CGFloat.random(in: 0...radius)
        return CGPoint(x: base.x + cos(angle) * dist, y: base.y + sin(angle) * dist)
    }
}
