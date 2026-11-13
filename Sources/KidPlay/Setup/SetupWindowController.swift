import AppKit
import ApplicationServices

@MainActor
final class SetupWindowController: NSWindowController {
    private let onStart: () -> Void

    private let statusLabel = NSTextField(labelWithString: "")
    private let pathLabel = NSTextField(wrappingLabelWithString: "")
    private let startButton = NSButton(title: "Старт", target: nil, action: nil)
    private let accessibilityButton = NSButton(title: "Разрешения…", target: nil, action: nil)

    init(onStart: @escaping () -> Void) {
        self.onStart = onStart

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 440, height: 280),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = "KidPlay"
        window.center()
        window.isReleasedWhenClosed = false

        super.init(window: window)
        buildUI()
        refreshAccessibilityStatus()
        scheduleUpdateCheck()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func showError(_ message: String) {
        statusLabel.stringValue = message
        statusLabel.textColor = .systemRed
        showWindow(nil)
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        startButton.isEnabled = true
    }

    func setStatus(_ message: String, emphasis: Bool = false) {
        statusLabel.stringValue = message
        statusLabel.textColor = emphasis ? .secondaryLabelColor : .secondaryLabelColor
    }

    private func scheduleUpdateCheck() {
        Task { @MainActor [weak self] in
            guard let self else { return }
            let outcome = await AppUpdater.checkAndInstallIfNeeded { [weak self] text in
                self?.setStatus(text, emphasis: true)
            }
            switch outcome {
            case .upToDate, .skipped:
                self.refreshAccessibilityStatus()
            case .updated(let version):
                self.setStatus("Обновлено до \(version). Перезапуск…", emphasis: true)
            case .failed(let message):
                // Don't block Start — just show the note.
                self.statusLabel.stringValue = message
                self.statusLabel.textColor = .systemOrange
            }
        }
    }

    private func buildUI() {
        guard let content = window?.contentView else { return }

        let title = NSTextField(labelWithString: "KidPlay")
        title.font = .systemFont(ofSize: 28, weight: .semibold)
        title.alignment = .center

        let subtitle = NSTextField(wrappingLabelWithString: "После 30 с тишины — выход по Touch ID. Либо зажми кнопку ⏏ у индикатора на 10 с.")
        subtitle.font = .systemFont(ofSize: 13)
        subtitle.textColor = .secondaryLabelColor
        subtitle.alignment = .center

        statusLabel.font = .systemFont(ofSize: 12)
        statusLabel.textColor = .secondaryLabelColor
        statusLabel.alignment = .center
        statusLabel.maximumNumberOfLines = 4

        pathLabel.font = .systemFont(ofSize: 10)
        pathLabel.textColor = .tertiaryLabelColor
        pathLabel.alignment = .center
        pathLabel.stringValue = "Приложение: \(Self.executablePath)"

        startButton.bezelStyle = .rounded
        startButton.setButtonType(.momentaryPushIn)
        startButton.isEnabled = true
        startButton.keyEquivalent = "\r"
        startButton.target = self
        startButton.action = #selector(startTapped)

        accessibilityButton.bezelStyle = .rounded
        accessibilityButton.target = self
        accessibilityButton.action = #selector(openAccessibilitySettings)

        let stack = NSStackView(views: [
            title,
            subtitle,
            statusLabel,
            pathLabel,
            startButton,
            accessibilityButton,
        ])
        stack.orientation = .vertical
        stack.alignment = .width
        stack.spacing = 12
        stack.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 28),
            stack.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -28),
            stack.topAnchor.constraint(equalTo: content.topAnchor, constant: 24),
            startButton.heightAnchor.constraint(equalToConstant: 28),
        ])
    }

    private func refreshAccessibilityStatus() {
        let summary = InputGuard.permissionSummary()
        statusLabel.stringValue = "Статус: \(summary). Запрос прав — только «Разрешения…»."
        statusLabel.textColor = .secondaryLabelColor
        pathLabel.stringValue = "Приложение: \(Self.executablePath)"
    }

    private static var executablePath: String {
        Bundle.main.executableURL?.path
            ?? CommandLine.arguments.first
            ?? "(unknown)"
    }

    @objc private func openAccessibilitySettings() {
        InputGuard.promptForPermissions()
        if let url = URL(string: "x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        } else if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.refreshAccessibilityStatus()
        }
    }

    @objc private func startTapped() {
        startButton.isEnabled = false
        defer {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { [weak self] in
                self?.startButton.isEnabled = true
            }
        }
        refreshAccessibilityStatus()
        statusLabel.stringValue = "Запуск…"
        statusLabel.textColor = .secondaryLabelColor
        onStart()
    }
}
