import AppKit

/// Corner unlock UI: clock-style idle timer + hold-to-exit control (10 s).
@MainActor
final class UnlockCornerView: NSView {
    static let holdSeconds: TimeInterval = 10

    private let clockTrackLayer = CAShapeLayer()
    private let clockProgressLayer = CAShapeLayer()
    private let clockHandLayer = CAShapeLayer()
    private let clockHubLayer = CAShapeLayer()

    private let holdTrackLayer = CAShapeLayer()
    private let holdFillLayer = CAShapeLayer()
    private let holdLabel = CATextLayer()

    private var progress: Double = 0
    private var armed = false
    private var breathPhase: CGFloat = 0
    private var holdProgress: Double = 0
    private var holdCompletedSent = false
    private var timer: Timer?

    var onHoldCompleted: (() -> Void)?

    /// Generous local hit zone (bottom-trailing corner).
    var holdHitLocalRect: CGRect {
        let size: CGFloat = 72
        let margin: CGFloat = 8
        return CGRect(
            x: bounds.width - margin - size,
            y: margin,
            width: size,
            height: size
        )
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor

        clockTrackLayer.fillColor = nil
        clockTrackLayer.strokeColor = NSColor.white.withAlphaComponent(0.14).cgColor
        clockTrackLayer.lineWidth = 3
        clockTrackLayer.lineCap = .round
        layer?.addSublayer(clockTrackLayer)

        clockProgressLayer.fillColor = nil
        clockProgressLayer.strokeColor = NSColor.white.withAlphaComponent(0.55).cgColor
        clockProgressLayer.lineWidth = 3
        clockProgressLayer.lineCap = .round
        clockProgressLayer.strokeEnd = 0
        layer?.addSublayer(clockProgressLayer)

        clockHandLayer.fillColor = NSColor.white.withAlphaComponent(0.65).cgColor
        clockHandLayer.strokeColor = nil
        layer?.addSublayer(clockHandLayer)

        clockHubLayer.fillColor = NSColor.white.withAlphaComponent(0.5).cgColor
        layer?.addSublayer(clockHubLayer)

        holdTrackLayer.fillColor = NSColor.white.withAlphaComponent(0.1).cgColor
        holdTrackLayer.strokeColor = NSColor.white.withAlphaComponent(0.35).cgColor
        holdTrackLayer.lineWidth = 1.5
        layer?.addSublayer(holdTrackLayer)

        holdFillLayer.fillColor = NSColor.systemGreen.withAlphaComponent(0.55).cgColor
        layer?.addSublayer(holdFillLayer)

        holdLabel.string = "⏏"
        holdLabel.alignmentMode = .center
        holdLabel.contentsScale = NSScreen.main?.backingScaleFactor ?? 2
        holdLabel.foregroundColor = NSColor.white.withAlphaComponent(0.55).cgColor
        holdLabel.fontSize = 14
        holdLabel.font = NSFont.systemFont(ofSize: 14, weight: .semibold)
        layer?.addSublayer(holdLabel)

        startBreathing()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func update(progress: Double, armed: Bool) {
        self.progress = min(1, max(0, progress))
        self.armed = armed
        applyAppearance()
    }

    func setHoldProgress(_ value: Double) {
        holdProgress = min(1, max(0, value))
        applyAppearance()
        if holdProgress >= 1, !holdCompletedSent {
            holdCompletedSent = true
            onHoldCompleted?()
        }
    }

    func resetHold() {
        holdProgress = 0
        holdCompletedSent = false
        applyAppearance()
    }

    var holdButtonLocalRect: CGRect {
        let size: CGFloat = 36
        let hit = holdHitLocalRect
        return CGRect(
            x: hit.midX - size / 2,
            y: hit.midY - size / 2 + 4,
            width: size,
            height: size
        )
    }

    /// Clock ring sits above the hold button.
    private var clockRect: CGRect {
        let size: CGFloat = 34
        let hold = holdButtonLocalRect
        return CGRect(
            x: hold.midX - size / 2,
            y: hold.maxY + 10,
            width: size,
            height: size
        )
    }

    func stopBreathing() {
        timer?.invalidate()
        timer = nil
    }

    override func layout() {
        super.layout()
        applyAppearance()
    }

    private func startBreathing() {
        timer?.invalidate()
        let timer = Timer(timeInterval: 1.0 / 20.0, repeats: true) { [weak self] _ in
            guard let self else { return }
            MainActor.assumeIsolated {
                self.tickBreath()
            }
        }
        self.timer = timer
        RunLoop.main.add(timer, forMode: .common)
    }

    private func tickBreath() {
        breathPhase += 0.06
        // Only re-draw pulse when armed; progress updates come from IdleGate.
        if armed || holdProgress > 0 {
            applyAppearance()
        }
    }

    private func applyAppearance() {
        let hold = holdButtonLocalRect
        let clock = clockRect
        let center = CGPoint(x: clock.midX, y: clock.midY)
        let radius = clock.width * 0.5 - 2

        // Full circle track (clock face rim).
        let track = CGMutablePath()
        track.addEllipse(in: clock.insetBy(dx: 2, dy: 2))
        clockTrackLayer.path = track

        // Full circle path; strokeEnd 0→1 winds from 12 o'clock clockwise.
        let progressPath = CGMutablePath()
        progressPath.addArc(
            center: center,
            radius: radius,
            startAngle: -.pi / 2,
            endAngle: -.pi / 2 + 2 * .pi,
            clockwise: false
        )
        clockProgressLayer.path = progressPath
        clockProgressLayer.strokeStart = 0

        let displayProgress = armed ? 1.0 : progress
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        clockProgressLayer.strokeEnd = CGFloat(displayProgress)
        CATransaction.commit()

        if armed {
            let pulse = 0.55 + 0.35 * ((sin(breathPhase) + 1) / 2)
            clockProgressLayer.strokeColor = NSColor.systemGreen.withAlphaComponent(pulse).cgColor
            clockTrackLayer.strokeColor = NSColor.systemGreen.withAlphaComponent(0.25).cgColor
            clockHandLayer.opacity = 0
            clockHubLayer.fillColor = NSColor.systemGreen.withAlphaComponent(pulse).cgColor
        } else {
            let alpha = 0.2 + CGFloat(progress) * 0.55
            clockProgressLayer.strokeColor = NSColor.white.withAlphaComponent(alpha).cgColor
            clockTrackLayer.strokeColor = NSColor.white.withAlphaComponent(0.14).cgColor
            clockHandLayer.opacity = progress > 0.01 ? 1 : 0.25
            clockHubLayer.fillColor = NSColor.white.withAlphaComponent(0.45).cgColor
        }

        // Clock hand pointing to current progress (12 o'clock → clockwise).
        let angle = -.pi / 2 + CGFloat(displayProgress) * 2 * .pi
        let handLen = radius * 0.72
        let handEnd = CGPoint(
            x: center.x + cos(angle) * handLen,
            y: center.y + sin(angle) * handLen
        )
        let hand = CGMutablePath()
        hand.move(to: center)
        hand.addLine(to: handEnd)
        // Small triangle tip via thick stroke alternative: thin rect path
        clockHandLayer.path = hand
        clockHandLayer.strokeColor = (armed ? NSColor.systemGreen : NSColor.white)
            .withAlphaComponent(armed ? 0 : 0.7).cgColor
        clockHandLayer.fillColor = nil
        clockHandLayer.lineWidth = 2
        clockHandLayer.lineCap = .round

        let hubSize: CGFloat = 4
        clockHubLayer.path = CGPath(
            ellipseIn: CGRect(x: center.x - hubSize / 2, y: center.y - hubSize / 2, width: hubSize, height: hubSize),
            transform: nil
        )

        // Hold button
        holdTrackLayer.path = CGPath(ellipseIn: hold, transform: nil)
        holdLabel.frame = hold.insetBy(dx: 2, dy: 8)

        if holdProgress > 0.001 {
            let end = CGFloat(holdProgress) * 2 * .pi - .pi / 2
            let hCenter = CGPoint(x: hold.midX, y: hold.midY)
            let hRadius = hold.width * 0.5 - 1
            let path = CGMutablePath()
            path.move(to: hCenter)
            path.addArc(
                center: hCenter,
                radius: hRadius,
                startAngle: -.pi / 2,
                endAngle: end,
                clockwise: false
            )
            path.closeSubpath()
            holdFillLayer.path = path
            holdLabel.foregroundColor = NSColor.white.withAlphaComponent(0.95).cgColor
        } else {
            holdFillLayer.path = nil
            holdLabel.foregroundColor = NSColor.white.withAlphaComponent(armed ? 0.85 : 0.5).cgColor
        }
    }

    func containsEventLocation(_ cgLocation: CGPoint) -> Bool {
        guard let window, bounds.width > 1, bounds.height > 1 else { return false }

        let candidates = Self.appKitCandidates(fromCGEventLocation: cgLocation, for: window)
        for screenPoint in candidates {
            let inWindow = window.convertPoint(fromScreen: screenPoint)
            let inView = convert(inWindow, from: nil)
            if holdHitLocalRect.contains(inView) {
                return true
            }
        }
        return false
    }

    private static func appKitCandidates(fromCGEventLocation loc: CGPoint, for window: NSWindow) -> [CGPoint] {
        var points = [loc]
        let screen = window.screen ?? NSScreen.main
        if let screen {
            let flipped = CGPoint(
                x: loc.x,
                y: screen.frame.maxY - (loc.y - screen.frame.minY)
            )
            if hypot(flipped.x - loc.x, flipped.y - loc.y) > 0.5 {
                points.append(flipped)
            }
        }
        return points
    }
}
