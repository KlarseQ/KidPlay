import AppKit

/// Kid-facing combo readout: key streak + trackpad path.
/// Sits below the MacBook notch / camera housing.
@MainActor
final class ComboHUDView: NSView {
    private let keyLabel = NSTextField(labelWithString: "")
    private let pathLabel = NSTextField(labelWithString: "")
    private let stack = NSStackView()
    private var topConstraint: NSLayoutConstraint?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor

        configure(keyLabel, size: 28, weight: .semibold)
        configure(pathLabel, size: 16, weight: .medium)

        stack.setViews([keyLabel, pathLabel], in: .center)
        stack.orientation = .vertical
        stack.alignment = .centerX
        stack.spacing = 2
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

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        refreshTopInset()
    }

    override func layout() {
        super.layout()
        refreshTopInset()
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
        if keys > 0 {
            keyLabel.stringValue = "КОМБО ×\(keys)"
            keyLabel.alphaValue = min(1, 0.35 + CGFloat(keys) * 0.04)
        } else {
            keyLabel.stringValue = ""
            keyLabel.alphaValue = 0
        }

        if path > 0 {
            pathLabel.stringValue = "путь \(path)"
            pathLabel.alphaValue = min(0.85, 0.25 + CGFloat(path) * 0.01)
        } else {
            pathLabel.stringValue = ""
            pathLabel.alphaValue = 0
        }
    }

    private func configure(_ label: NSTextField, size: CGFloat, weight: NSFont.Weight) {
        label.font = .systemFont(ofSize: size, weight: weight)
        label.textColor = NSColor.white.withAlphaComponent(0.7)
        label.alignment = .center
        label.drawsBackground = false
        label.isBezeled = false
        label.isEditable = false
        label.isSelectable = false
    }
}
