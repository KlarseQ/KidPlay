import AppKit
import SpriteKit

@MainActor
final class InkFlowScene: SKScene {
    private var lastInkPoint: CGPoint?
    private let residueNode = SKNode()
    private let liveNode = SKNode()
    private var residueCount = 0
    private let maxResidue = 2500
    /// Permanent stain opacity — faint but visible; stacks as you draw.
    private let residueAlpha: CGFloat = 0.09

    override func didMove(to view: SKView) {
        backgroundColor = SKColor(calibratedWhite: 0.03, alpha: 1)
        scaleMode = .resizeFill
        isPaused = false
        residueNode.zPosition = 1
        liveNode.zPosition = 50
        addChild(residueNode)
        addChild(liveNode)
    }

    func addInk(at point: CGPoint) {
        if let last = lastInkPoint, hypot(point.x - last.x, point.y - last.y) < 2.5 {
            return
        }
        lastInkPoint = point

        let blot = makeInkStain(
            at: point,
            baseRadius: CGFloat.random(in: 10...28),
            alpha: CGFloat.random(in: 0.45...0.8)
        )
        liveNode.addChild(blot)
        stampPermanentResidue(like: blot)
        animateEphemeral(blot, duration: CGFloat.random(in: 0.9...1.5))
    }

    func spawnKeyVisual(keyCode: Int64, characters _: String?) {
        let text = KeyLayout.displayText(forKeyCode: keyCode)
        let point = KeyLayout.spawnPoint(forKeyCode: keyCode, sceneSize: size, radius: 64)

        let isNamed = KeyLayout.visual(forKeyCode: keyCode).map { visual -> Bool in
            if case .named = visual.kind { return true }
            return false
        } ?? false

        let fontSize: CGFloat = isNamed
            ? CGFloat.random(in: 28...48)
            : (Bool.random() ? CGFloat.random(in: 44...70) : CGFloat.random(in: 90...150))

        let under = makeInkStain(
            at: point,
            baseRadius: fontSize * (isNamed ? 0.55 : CGFloat.random(in: 0.35...0.55)),
            alpha: CGFloat.random(in: 0.4...0.75)
        )
        liveNode.addChild(under)
        stampPermanentResidue(like: under)
        animateEphemeral(under, duration: 1.3)

        let label = SKLabelNode(text: text)
        label.fontName = Self.randomFontName()
        label.fontSize = fontSize
        label.fontColor = SKColor(calibratedWhite: CGFloat.random(in: 0.88...1.0), alpha: 0.95)
        label.verticalAlignmentMode = .center
        label.horizontalAlignmentMode = .center
        label.zPosition = 5
        label.position = point
        label.setScale(0.25)
        label.zRotation = isNamed ? CGFloat.random(in: -0.12...0.12) : CGFloat.random(in: -0.35...0.35)
        liveNode.addChild(label)

        // Permanent faint letter/name stain.
        if let stain = label.copy() as? SKLabelNode {
            stain.removeAllActions()
            stain.setScale(1)
            stain.alpha = residueAlpha
            stain.zRotation = label.zRotation
            addResidue(stain)
        }

        let drip = makeInkStain(
            at: CGPoint(x: point.x + CGFloat.random(in: -10...10), y: point.y - fontSize * 0.35),
            baseRadius: max(6, fontSize * 0.1),
            alpha: 0.5
        )
        liveNode.addChild(drip)
        stampPermanentResidue(like: drip)
        animateEphemeral(drip, duration: 1.4)

        let drift = CGVector(
            dx: CGFloat.random(in: -40...40),
            dy: CGFloat.random(in: 20...90)
        )
        label.run(.sequence([
            .group([
                .scale(to: 1.0, duration: 0.2),
                .move(by: drift, duration: CGFloat.random(in: 1.2...1.9)),
                .sequence([
                    .wait(forDuration: 0.35),
                    .fadeOut(withDuration: 1.0),
                ]),
            ]),
            .removeFromParent(),
        ]))
    }

    func spawnLabeled(_ text: String) {
        // Media / brightness / etc. — named label at a random keyboard-ish slot.
        let point = CGPoint(
            x: size.width * CGFloat.random(in: 0.15...0.85),
            y: size.height * CGFloat.random(in: 0.12...0.45)
        )
        let fontSize = CGFloat.random(in: 32...56)

        let under = makeInkStain(at: point, baseRadius: fontSize * 0.6, alpha: 0.55)
        liveNode.addChild(under)
        stampPermanentResidue(like: under)
        animateEphemeral(under, duration: 1.2)

        let label = SKLabelNode(text: text)
        label.fontName = Self.randomFontName()
        label.fontSize = fontSize
        label.fontColor = SKColor(calibratedWhite: 0.95, alpha: 0.95)
        label.verticalAlignmentMode = .center
        label.horizontalAlignmentMode = .center
        label.position = point
        label.setScale(0.3)
        liveNode.addChild(label)

        if let stain = label.copy() as? SKLabelNode {
            stain.removeAllActions()
            stain.setScale(1)
            stain.alpha = residueAlpha
            addResidue(stain)
        }

        label.run(.sequence([
            .group([
                .scale(to: 1.0, duration: 0.18),
                .fadeOut(withDuration: 1.2),
            ]),
            .removeFromParent(),
        ]))
    }

    private static func randomFontName() -> String {
        let thin = [
            "HelveticaNeue-UltraLight",
            "HelveticaNeue-Thin",
            "AvenirNext-UltraLight",
            "AvenirNext-Thin",
            "Avenir-Light",
        ]
        let bold = [
            "HelveticaNeue-Bold",
            "HelveticaNeue-Medium",
            "HelveticaNeue-CondensedBold",
            "AvenirNext-Bold",
            "AvenirNext-DemiBold",
            "Avenir-Black",
        ]
        return Bool.random()
            ? (bold.randomElement() ?? "HelveticaNeue-Bold")
            : (thin.randomElement() ?? "HelveticaNeue-Thin")
    }

    func scenePoint(fromScreen screenPoint: CGPoint, in view: SKView) -> CGPoint {
        guard let window = view.window else {
            return CGPoint(x: size.width / 2, y: size.height / 2)
        }
        let windowPoint = window.convertPoint(fromScreen: NSPoint(x: screenPoint.x, y: screenPoint.y))
        let viewPoint = view.convert(windowPoint, from: nil)
        var p = convertPoint(fromView: viewPoint)
        p.y = size.height - p.y
        return p
    }

    // MARK: - Wet ink stains

    private func makeInkStain(at point: CGPoint, baseRadius: CGFloat, alpha: CGFloat) -> SKNode {
        let container = SKNode()
        container.position = point
        container.zRotation = CGFloat.random(in: 0...(2 * .pi))

        // Dark wet core — irregular blot.
        let core = SKShapeNode(path: blotPath(radius: baseRadius, jagged: 0.55))
        core.fillColor = inkColor(alpha: alpha)
        core.strokeColor = .clear
        core.glowWidth = 0
        core.lineWidth = 0
        container.addChild(core)

        // Soft soak around the core (larger, lighter).
        let soak = SKShapeNode(path: blotPath(radius: baseRadius * 1.55, jagged: 0.4))
        soak.fillColor = inkColor(alpha: alpha * 0.28)
        soak.strokeColor = .clear
        soak.glowWidth = 0
        soak.zPosition = -1
        container.addChild(soak)

        // Feather fringe.
        let fringe = SKShapeNode(path: blotPath(radius: baseRadius * 2.1, jagged: 0.7))
        fringe.fillColor = inkColor(alpha: alpha * 0.1)
        fringe.strokeColor = .clear
        fringe.glowWidth = 0
        fringe.zPosition = -2
        container.addChild(fringe)

        // Drip / run-down for wet feel.
        if Bool.random() {
            let dripH = baseRadius * CGFloat.random(in: 0.6...1.8)
            let drip = SKShapeNode(path: dripPath(width: baseRadius * 0.18, height: dripH))
            drip.position = CGPoint(x: CGFloat.random(in: -baseRadius * 0.2...baseRadius * 0.2), y: -baseRadius * 0.3)
            drip.fillColor = inkColor(alpha: alpha * 0.7)
            drip.strokeColor = .clear
            drip.glowWidth = 0
            container.addChild(drip)
        }

        // Satellite spatters.
        for _ in 0..<Int.random(in: 2...6) {
            let a = CGFloat.random(in: 0...(2 * .pi))
            let d = baseRadius * CGFloat.random(in: 0.85...2.0)
            let sr = baseRadius * CGFloat.random(in: 0.06...0.2)
            let speck = SKShapeNode(path: blotPath(radius: sr, jagged: 0.8))
            speck.position = CGPoint(x: cos(a) * d, y: sin(a) * d)
            speck.fillColor = inkColor(alpha: alpha * CGFloat.random(in: 0.4...0.8))
            speck.strokeColor = .clear
            speck.glowWidth = 0
            container.addChild(speck)
        }

        return container
    }

    private func blotPath(radius: CGFloat, jagged: CGFloat) -> CGPath {
        let path = CGMutablePath()
        let lobes = Int.random(in: 7...11)
        var pts: [CGPoint] = []
        for i in 0..<lobes {
            let t = CGFloat(i) / CGFloat(lobes) * 2 * .pi
            let r = radius * CGFloat.random(in: (1 - jagged * 0.5)...(1 + jagged * 0.5))
            pts.append(CGPoint(x: cos(t) * r, y: sin(t) * r * CGFloat.random(in: 0.75...1.15)))
        }
        path.move(to: pts[0])
        for i in 0..<lobes {
            let p0 = pts[i]
            let p1 = pts[(i + 1) % lobes]
            let ctrl = CGPoint(
                x: (p0.x + p1.x) * 0.5 + CGFloat.random(in: -radius * 0.2...radius * 0.2) * jagged,
                y: (p0.y + p1.y) * 0.5 + CGFloat.random(in: -radius * 0.2...radius * 0.2) * jagged
            )
            path.addQuadCurve(to: p1, control: ctrl)
        }
        path.closeSubpath()
        return path
    }

    private func dripPath(width: CGFloat, height: CGFloat) -> CGPath {
        let path = CGMutablePath()
        path.move(to: CGPoint(x: -width, y: 0))
        path.addQuadCurve(to: CGPoint(x: 0, y: -height), control: CGPoint(x: -width * 0.2, y: -height * 0.4))
        path.addQuadCurve(to: CGPoint(x: width, y: 0), control: CGPoint(x: width * 0.2, y: -height * 0.4))
        path.closeSubpath()
        return path
    }

    private func inkColor(alpha: CGFloat) -> SKColor {
        // Carbon ink: almost black with a hint of indigo.
        SKColor(
            calibratedRed: CGFloat.random(in: 0.01...0.07),
            green: CGFloat.random(in: 0.02...0.08),
            blue: CGFloat.random(in: 0.06...0.16),
            alpha: alpha
        )
    }

    private func animateEphemeral(_ node: SKNode, duration: CGFloat) {
        node.run(.sequence([
            .group([
                .fadeOut(withDuration: duration),
                .scale(to: CGFloat.random(in: 1.02...1.15), duration: duration),
            ]),
            .removeFromParent(),
        ]))
    }

    private func stampPermanentResidue(like node: SKNode) {
        guard let stain = node.copy() as? SKNode else { return }
        stain.removeAllActions()
        stain.setScale(1)
        // Flatten to residue brightness: visible permanent ink film.
        stain.alpha = residueAlpha
        addResidue(stain)
    }

    private func addResidue(_ node: SKNode) {
        while residueCount >= maxResidue, let oldest = residueNode.children.first {
            oldest.removeFromParent()
            residueCount -= 1
        }
        node.zPosition = CGFloat(residueCount)
        residueNode.addChild(node)
        residueCount += 1
    }
}
