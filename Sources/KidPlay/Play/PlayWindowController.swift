import AppKit
import SpriteKit

@MainActor
final class PlayWindowController: NSWindowController {
    let skView = SKView(frame: .zero)
    let scene = InkFlowScene(size: CGSize(width: 800, height: 600))
    let unlockCorner = UnlockCornerView(frame: .zero)
    let comboHUD = ComboHUDView(frame: .zero)
    let keySink = KeySinkView(frame: .zero)

    init(screen: NSScreen) {
        let frame = screen.frame
        let window = PlayWindow(
            contentRect: frame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false,
            screen: screen
        )
        window.setFrame(frame, display: true)
        window.isOpaque = true
        window.backgroundColor = .black
        window.level = .screenSaver
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        window.sharingType = .none
        window.ignoresMouseEvents = false
        window.acceptsMouseMovedEvents = true
        window.isReleasedWhenClosed = false
        window.hasShadow = false

        super.init(window: window)

        skView.translatesAutoresizingMaskIntoConstraints = false
        skView.allowsTransparency = false
        skView.ignoresSiblingOrder = true
        skView.isPaused = false

        unlockCorner.translatesAutoresizingMaskIntoConstraints = false
        comboHUD.translatesAutoresizingMaskIntoConstraints = false
        keySink.translatesAutoresizingMaskIntoConstraints = false

        guard let content = window.contentView else { return }
        content.addSubview(skView)
        content.addSubview(keySink)
        content.addSubview(unlockCorner)
        content.addSubview(comboHUD)

        NSLayoutConstraint.activate([
            skView.leadingAnchor.constraint(equalTo: content.leadingAnchor),
            skView.trailingAnchor.constraint(equalTo: content.trailingAnchor),
            skView.topAnchor.constraint(equalTo: content.topAnchor),
            skView.bottomAnchor.constraint(equalTo: content.bottomAnchor),
            keySink.leadingAnchor.constraint(equalTo: content.leadingAnchor),
            keySink.trailingAnchor.constraint(equalTo: content.trailingAnchor),
            keySink.topAnchor.constraint(equalTo: content.topAnchor),
            keySink.bottomAnchor.constraint(equalTo: content.bottomAnchor),
            unlockCorner.leadingAnchor.constraint(equalTo: content.leadingAnchor),
            unlockCorner.trailingAnchor.constraint(equalTo: content.trailingAnchor),
            unlockCorner.topAnchor.constraint(equalTo: content.topAnchor),
            unlockCorner.bottomAnchor.constraint(equalTo: content.bottomAnchor),
            comboHUD.leadingAnchor.constraint(equalTo: content.leadingAnchor),
            comboHUD.trailingAnchor.constraint(equalTo: content.trailingAnchor),
            comboHUD.topAnchor.constraint(equalTo: content.topAnchor),
            comboHUD.heightAnchor.constraint(equalToConstant: 96),
        ])

        scene.size = frame.size
        skView.presentScene(scene)
        window.makeFirstResponder(keySink)
        window.initialFirstResponder = keySink
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func makeKeyAndOrderFront() {
        window?.makeKeyAndOrderFront(nil)
        window?.orderFrontRegardless()
        window?.makeFirstResponder(keySink)
    }
}
