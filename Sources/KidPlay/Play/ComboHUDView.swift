import AppKit
import QuartzCore

/// Kid-facing combo readout: key streak + trackpad path.
/// Sits below the MacBook notch / camera housing.
@MainActor
final class ComboHUDView: NSView {
    private let keyLabel = NSTextField(labelWithString: "")
    private let pathLabel = NSTextField(labelWithString: "")
    private let stack = NSStackView()
    private var topConstraint: NSLayoutConstraint?
    private var useColors = false
    private var lastKeys = 0
    private var lastPath = 0

    /// Soft radial bloom behind the labels (not a hard band/stripe).
    private var bloomLayer: CAGradientLayer?
    private var bloomHost: CALayer?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor

        configure(keyLabel, size: 30, weight: .heavy)
        configure(pathLabel, size: 17, weight: .semibold)

        stack.setViews([keyLabel, pathLabel], in: .center)
        stack.orientation = .vertical
        stack.alignment = .centerX
        stack.spacing = 4
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)

        let top = stack.topAnchor.constraint(equalTo: topAnchor, constant: Self.defaultTopInset)
        topConstraint = top
        NSLayoutConstraint.activate([
            stack.centerXAnchor.constraint(equalTo: centerXAnchor),
            top,
        ])

        update(keys: 0, path: 0)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    /// Notch / camera housing clearance (fullscreen borderless ignores menu bar safe area alone).
    private static let defaultTopInset: CGFloat = 56
    private static let minTopInset: CGFloat = 48

    func setUseColors(_ enabled: Bool) {
        useColors = enabled
        update(keys: lastKeys, path: lastPath)
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        refreshTopInset()
    }

    override func layout() {
        super.layout()
        refreshTopInset()
        layoutBloom()
    }

    private func refreshTopInset() {
        let safeTop = window?.screen?.safeAreaInsets.top ?? 0
        // Below notch: safe area + padding, floored so non-notch Macs still look balanced.
        let inset = max(Self.minTopInset, safeTop + 20)
        if topConstraint?.constant != inset {
            topConstraint?.constant = inset
        }
    }

    func update(keys: Int, path: Int) {
        lastKeys = keys
        lastPath = path
        if keys > 0 {
            keyLabel.stringValue = "КОМБО ×\(keys)"
            keyLabel.alphaValue = 1
            if useColors {
                let color = PlayPalette.streakNSColor(level: keys)
                keyLabel.textColor = color
                keyLabel.font = .systemFont(ofSize: min(42, 28 + CGFloat(keys)), weight: .heavy)
                applySoftGlow(color: color, intensity: min(1, 0.3 + CGFloat(keys) * 0.045))
            } else {
                keyLabel.textColor = NSColor.white.withAlphaComponent(min(1, 0.45 + CGFloat(keys) * 0.05))
                keyLabel.font = .systemFont(ofSize: 30, weight: .heavy)
                clearGlow()
            }
        } else {
            keyLabel.stringValue = ""
            keyLabel.alphaValue = 0
            clearGlow()
        }

        if path > 0 {
            pathLabel.stringValue = "путь \(path)"
            pathLabel.alphaValue = 1
            if useColors {
                let color = PlayPalette.streakNSColor(level: max(1, path / 8 + 1))
                pathLabel.textColor = color.withAlphaComponent(0.95)
            } else {
                pathLabel.textColor = NSColor.white.withAlphaComponent(min(0.85, 0.3 + CGFloat(path) * 0.01))
            }
        } else {
            pathLabel.stringValue = ""
            pathLabel.alphaValue = 0
        }
    }

    private func applySoftGlow(color: NSColor, intensity: CGFloat) {
        wantsLayer = true

        if bloomHost == nil {
            let host = CALayer()
            host.masksToBounds = false
            layer?.insertSublayer(host, at: 0)
            bloomHost = host
        }

        if bloomLayer == nil {
            let g = CAGradientLayer()
            g.type = .radial
            // Soft falloff: bright core → mid haze → fully clear (no hard stripe edge).
            g.startPoint = CGPoint(x: 0.5, y: 0.5)
            g.endPoint = CGPoint(x: 1.0, y: 1.0)
            bloomHost?.addSublayer(g)
            bloomLayer = g
        }

        let core = color.withAlphaComponent(intensity * 0.55).cgColor
        let mid = color.withAlphaComponent(intensity * 0.22).cgColor
        let edge = color.withAlphaComponent(intensity * 0.06).cgColor
        let clear = NSColor.clear.cgColor
        bloomLayer?.colors = [core, mid, edge, clear]
        bloomLayer?.locations = [0.0, 0.35, 0.65, 1.0] as [NSNumber]

        // Text bloom via shadow — feathered, not a band.
        keyLabel.shadow = softTextShadow(color: color, intensity: intensity)
        pathLabel.shadow = softTextShadow(color: color, intensity: intensity * 0.7)

        layoutBloom()
    }

    private func softTextShadow(color: NSColor, intensity: CGFloat) -> NSShadow {
        let shadow = NSShadow()
        shadow.shadowColor = color.withAlphaComponent(min(0.9, intensity * 0.85))
        shadow.shadowBlurRadius = 18 + intensity * 14
        shadow.shadowOffset = .zero
        return shadow
    }

    private func layoutBloom() {
        guard let bloomLayer, let bloomHost else { return }
        let labelFrame = stack.frame
        guard labelFrame.width > 1, labelFrame.height > 1 else { return }

        // Elliptical soft pool around the combo text — oversized so the rim dissolves.
        let padX = max(120, labelFrame.width * 1.6)
        let padY = max(72, labelFrame.height * 2.2)
        let bloomRect = labelFrame.insetBy(dx: -padX / 2, dy: -padY / 2)

        bloomHost.frame = bounds
        bloomLayer.frame = bloomRect
        bloomLayer.cornerRadius = min(bloomRect.width, bloomRect.height) * 0.5
        bloomLayer.masksToBounds = false
    }

    private func clearGlow() {
        bloomLayer?.removeFromSuperlayer()
        bloomLayer = nil
        bloomHost?.removeFromSuperlayer()
        bloomHost = nil
        keyLabel.shadow = nil
        pathLabel.shadow = nil
    }

    private func configure(_ label: NSTextField, size: CGFloat, weight: NSFont.Weight) {
        label.font = .systemFont(ofSize: size, weight: weight)
        label.textColor = NSColor.white.withAlphaComponent(0.7)
        label.alignment = .center
        label.drawsBackground = false
        label.isBezeled = false
        label.isEditable = false
        label.isSelectable = false
        label.wantsLayer = true
    }
}
