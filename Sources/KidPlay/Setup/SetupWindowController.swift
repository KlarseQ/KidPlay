import AppKit
import ApplicationServices
import CoreGraphics

@MainActor
final class SetupWindowController: NSWindowController {
    private let onStart: (_ useColors: Bool) -> Void

    private let statusLabel = NSTextField(labelWithString: "")
    private let pathLabel = NSTextField(wrappingLabelWithString: "")
    private let colorsCheckbox = NSButton(checkboxWithTitle: "Использовать цвета", target: nil, action: nil)
    private let startButton = NSButton(title: "Старт", target: nil, action: nil)
    private let accessibilityButton = NSButton(title: "Универсальный доступ…", target: nil, action: nil)
    private let inputMonitoringButton = NSButton(title: "Мониторинг ввода…", target: nil, action: nil)
    private let donateButton = NSButton(title: "Поддержать @klarseq", target: nil, action: nil)

    var useColors: Bool { colorsCheckbox.state == .on }

    init(onStart: @escaping (_ useColors: Bool) -> Void) {
        self.onStart = onStart

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 460, height: 400),
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
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appDidBecomeActive),
            name: NSApplication.didBecomeActiveNotification,
            object: nil
        )
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
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
        statusLabel.maximumNumberOfLines = 5

        pathLabel.font = .systemFont(ofSize: 10)
        pathLabel.textColor = .tertiaryLabelColor
        pathLabel.alignment = .center
        pathLabel.stringValue = "Приложение: \(Self.executablePath)"

        colorsCheckbox.state = .on
        colorsCheckbox.font = .systemFont(ofSize: 13)
        colorsCheckbox.setButtonType(.switch)

        startButton.bezelStyle = .rounded
        startButton.setButtonType(.momentaryPushIn)
        startButton.isEnabled = true
        startButton.keyEquivalent = "\r"
        startButton.target = self
        startButton.action = #selector(startTapped)

        accessibilityButton.bezelStyle = .rounded
        accessibilityButton.target = self
        accessibilityButton.action = #selector(openAccessibilityTapped)

        inputMonitoringButton.bezelStyle = .rounded
        inputMonitoringButton.target = self
        inputMonitoringButton.action = #selector(openInputMonitoringTapped)

        let permissionsRow = NSStackView(views: [accessibilityButton, inputMonitoringButton])
        permissionsRow.orientation = .horizontal
        permissionsRow.alignment = .centerY
        permissionsRow.distribution = .fillEqually
        permissionsRow.spacing = 8

        donateButton.bezelStyle = .inline
        donateButton.isBordered = false
        donateButton.contentTintColor = .linkColor
        donateButton.font = .systemFont(ofSize: 12)
        donateButton.target = self
        donateButton.action = #selector(openDonate)

        let stack = NSStackView(views: [
            title,
            subtitle,
            statusLabel,
            pathLabel,
            colorsCheckbox,
            startButton,
            permissionsRow,
            donateButton,
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
            accessibilityButton.heightAnchor.constraint(equalToConstant: 28),
            inputMonitoringButton.heightAnchor.constraint(equalToConstant: 28),
        ])
    }

    private func refreshAccessibilityStatus() {
        let summary = InputGuard.permissionSummary()
        let trusted = AXIsProcessTrusted()
        let listen = CGPreflightListenEventAccess()
        pathLabel.stringValue = "Приложение: \(Self.executablePath)"

        if trusted || listen {
            statusLabel.stringValue = "Статус: \(summary). Можно жать Старт."
            statusLabel.textColor = .secondaryLabelColor
        } else {
            statusLabel.stringValue = """
            Статус: \(summary).
            Нажми кнопки ниже → добавь KidPlay через ＋ → включи тумблер.
            Затем Cmd+Q и открой снова.
            """
            statusLabel.textColor = .systemOrange
        }
    }

    private static var executablePath: String {
        Bundle.main.executableURL?.path
            ?? CommandLine.arguments.first
            ?? "(unknown)"
    }

    @objc private func appDidBecomeActive() {
        // After returning from System Settings, re-read TCC without prompting.
        refreshAccessibilityStatus()
    }

    @objc private func openAccessibilityTapped() {
        InputGuard.promptAccessibility()
        InputGuard.openSettings(for: .accessibility)
        scheduleStatusRefresh()
    }

    @objc private func openInputMonitoringTapped() {
        InputGuard.promptInputMonitoring()
        InputGuard.openSettings(for: .inputMonitoring)
        scheduleStatusRefresh()
    }

    private func scheduleStatusRefresh() {
        for delay in [0.5, 1.5, 3.0] {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
                self?.refreshAccessibilityStatus()
            }
        }
    }

    @objc private func openDonate() {
        if let url = URL(string: "https://t.me/klarseq") {
            NSWorkspace.shared.open(url)
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
        onStart(useColors)
    }
}
