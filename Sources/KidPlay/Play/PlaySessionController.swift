import AppKit
import ApplicationServices

enum PlaySessionOutcome {
    case exited
    case failedToStart(String)
}

@MainActor
final class PlaySessionController {
    private let onFinish: (PlaySessionOutcome) -> Void
    private let useColors: Bool

    private let inputGuard = InputGuard()
    private let idleGate = IdleGate()
    private let soundPlayer = SoftSoundPlayer()
    private let touchID = TouchIDAuth()
    private let combo = ComboTracker()
    private var windows: [PlayWindowController] = []
    private var primaryWindow: PlayWindowController?
    private var isExiting = false
    private var lastScreenPoint: CGPoint?
    private var savedPresentationOptions: NSApplication.PresentationOptions = []
    private var localKeyMonitor: Any?
    private var localSystemMonitor: Any?
    private var globalKeyMonitor: Any?
    private var cursorHideTimer: Timer?

    private var pendingPointer: CGPoint?
    private var pointerFlushScheduled = false
    private var lastKeyCode: Int64 = -1
    private var lastKeyAt: CFAbsoluteTime = 0

    /// Bumped every unlock-offer / cleanup so stale Touch ID / hold tasks die.
    private var unlockEpoch: UInt64 = 0
    private var touchIDTask: Task<Void, Never>?

    private var holdStartedAt: CFAbsoluteTime?
    private var holdTimer: Timer?

    init(useColors: Bool, onFinish: @escaping (PlaySessionOutcome) -> Void) {
        self.useColors = useColors
        self.onFinish = onFinish
    }

    func start() {
        hideCursor()
        startCursorHideTimer()
        applyKioskPresentation()
        presentKioskWindows()
        installKeyMonitors()
        wireHoldButtons()

        combo.onChange = { [weak self] keys, path in
            self?.windows.forEach { $0.comboHUD.update(keys: keys, path: path) }
        }

        idleGate.start(
            onArmedChanged: { [weak self] armed in
                self?.handleArmedChanged(armed)
            },
            onProgress: { [weak self] progress in
                guard let self else { return }
                self.windows.forEach {
                    $0.unlockCorner.update(progress: progress, armed: self.idleGate.isArmed)
                }
            }
        )

        inputGuard.onEvent = { [weak self] event in
            guard let self else { return }
            if Thread.isMainThread {
                MainActor.assumeIsolated {
                    self.routeInput(event)
                }
            } else {
                DispatchQueue.main.async {
                    self.routeInput(event)
                }
            }
        }

        do {
            try inputGuard.start()
        } catch {
            tearDown()
            let path = Bundle.main.bundleURL.path
            let detail = (error as? LocalizedError)?.errorDescription ?? InputGuard.permissionSummary()
            onFinish(.failedToStart(
                """
                Не удалось создать CGEventTap.
                \(detail)
                Приложение: \(path)
                """
            ))
        }
    }

    func tearDown() {
        clearUnlockState(restartTap: false)
        if let localKeyMonitor { NSEvent.removeMonitor(localKeyMonitor) }
        if let localSystemMonitor { NSEvent.removeMonitor(localSystemMonitor) }
        if let globalKeyMonitor { NSEvent.removeMonitor(globalKeyMonitor) }
        localKeyMonitor = nil
        localSystemMonitor = nil
        globalKeyMonitor = nil
        cursorHideTimer?.invalidate()
        cursorHideTimer = nil

        idleGate.stop()
        inputGuard.stop()
        restorePresentation()
        windows.forEach {
            $0.unlockCorner.stopBreathing()
            $0.window?.orderOut(nil)
            $0.close()
        }
        windows.removeAll()
        primaryWindow = nil
        NSCursor.unhide()
    }

    private func wireHoldButtons() {
        for window in windows {
            window.unlockCorner.onHoldCompleted = { [weak self] in
                self?.exitSuccessfully()
            }
        }
    }

    private func installKeyMonitors() {
        localKeyMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .keyUp, .flagsChanged]) { [weak self] event in
            if event.type == .keyDown {
                self?.handleKey(keyCode: Int64(event.keyCode), characters: event.charactersIgnoringModifiers)
            }
            return nil
        }

        // Extra local swallow for NX system-defined (volume / brightness) if they reach the app.
        localSystemMonitor = NSEvent.addLocalMonitorForEvents(matching: .systemDefined) { _ in
            nil
        }

        globalKeyMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            DispatchQueue.main.async {
                self?.handleKey(keyCode: Int64(event.keyCode), characters: event.charactersIgnoringModifiers)
            }
        }

        for window in windows {
            window.keySink.onKey = { [weak self] code, chars in
                self?.handleKey(keyCode: Int64(code), characters: chars)
            }
        }
    }

    private func hideCursor() {
        NSCursor.hide()
        NSCursor.setHiddenUntilMouseMoves(false)
    }

    private func startCursorHideTimer() {
        cursorHideTimer?.invalidate()
        let timer = Timer(timeInterval: 0.4, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self, !self.isExiting else { return }
                self.hideCursor()
            }
        }
        cursorHideTimer = timer
        RunLoop.main.add(timer, forMode: .common)
    }

    private func applyKioskPresentation() {
        savedPresentationOptions = NSApp.presentationOptions
        NSApp.presentationOptions = [
            .hideDock,
            .hideMenuBar,
            .disableAppleMenu,
            .disableProcessSwitching,
            .disableHideApplication,
            .disableMenuBarTransparency,
            .disableSessionTermination,
            .disableForceQuit,
        ]
    }

    private func restorePresentation() {
        NSApp.presentationOptions = savedPresentationOptions
    }

    private func presentKioskWindows() {
        for screen in NSScreen.screens {
            let controller = PlayWindowController(screen: screen)
            controller.scene.useColors = useColors
            controller.comboHUD.setUseColors(useColors)
            controller.makeKeyAndOrderFront()
            windows.append(controller)
            if screen == NSScreen.main || primaryWindow == nil {
                primaryWindow = controller
            }
        }
        primaryWindow?.window?.makeKeyAndOrderFront(nil)
        primaryWindow?.window?.makeFirstResponder(primaryWindow?.keySink)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func handleArmedChanged(_ armed: Bool) {
        windows.forEach { $0.unlockCorner.update(progress: idleGate.progress, armed: armed) }
        if armed {
            // Fresh unlock offer: wipe stale Touch ID / hold / epoch so exit can't get stuck.
            beginUnlockOffer()
        } else {
            clearUnlockState(restartTap: false)
        }
    }

    /// Called every time exit is offered — full cleanup + new Touch ID prompt.
    private func beginUnlockOffer() {
        // Invalidate any previous unlock cycle (stuck Touch ID / hold / epoch).
        invalidateUnlockCycle()
        ensureTapRunning()

        unlockEpoch &+= 1
        let epoch = unlockEpoch
        windows.forEach {
            $0.unlockCorner.resetHold()
            $0.unlockCorner.update(progress: 1, armed: true)
        }

        touchIDTask = Task { [weak self] in
            await self?.promptTouchID(epoch: epoch)
        }
    }

    private func clearUnlockState(restartTap: Bool) {
        invalidateUnlockCycle()
        if restartTap {
            ensureTapRunning()
        }
    }

    private func invalidateUnlockCycle() {
        unlockEpoch &+= 1
        touchIDTask?.cancel()
        touchIDTask = nil
        touchID.cancel()
        stopHoldTracking()
        windows.forEach { $0.unlockCorner.resetHold() }
    }

    private func ensureTapRunning() {
        guard !isExiting else { return }
        inputGuard.stop()
        do {
            try inputGuard.start()
        } catch {
            NSLog("KidPlay: tap restart failed during unlock cleanup: \(error)")
        }
    }

    private func routeInput(_ event: PlayInputEvent) {
        guard !isExiting else { return }

        switch event {
        case .keyDown(let keyCode, let characters):
            handleKey(keyCode: keyCode, characters: characters)

        case .labeled(let text):
            notePlayActivity()
            primaryWindow?.scene.spawnLabeled(text)
            combo.noteKey()
            soundPlayer.playKey()

        case .pointerDown(let x, let y):
            handlePointerDown(x: x, y: y)

        case .pointerUp(let x, let y):
            handlePointerUp(x: x, y: y)

        case .pointer(let x, let y, _):
            lastScreenPoint = CGPoint(x: x, y: y)
            // While holding exit, ignore move spam (no ink / no idle reset).
            if holdStartedAt != nil { return }
            pendingPointer = CGPoint(x: x, y: y)
            if !pointerFlushScheduled {
                pointerFlushScheduled = true
                DispatchQueue.main.async { [weak self] in
                    self?.flushPointer()
                }
            }
        }
    }

    private func handlePointerDown(x: Double, y: Double) {
        let point = CGPoint(x: x, y: y)
        if isInsideHoldButton(point) {
            startHoldTracking()
            return
        }
        notePlayActivity()
        lastScreenPoint = point
        pendingPointer = point
        flushPointer()
    }

    private func handlePointerUp(x: Double, y: Double) {
        // Hold cancels only on release — finger jitter must not abort a 10 s press.
        if holdStartedAt != nil {
            stopHoldTracking()
        }
        _ = x
        _ = y
    }

    private func isInsideHoldButton(_ cgEventLocation: CGPoint) -> Bool {
        for window in windows {
            if window.unlockCorner.containsEventLocation(cgEventLocation) {
                return true
            }
        }
        return false
    }

    private func startHoldTracking() {
        stopHoldTracking()
        holdStartedAt = CFAbsoluteTimeGetCurrent()
        // Immediate feedback so the press is obvious.
        windows.forEach { $0.unlockCorner.setHoldProgress(0.02) }
        let timer = Timer(timeInterval: 1.0 / 30.0, repeats: true) { [weak self] _ in
            guard let self else { return }
            MainActor.assumeIsolated {
                self.tickHold()
            }
        }
        holdTimer = timer
        RunLoop.main.add(timer, forMode: .common)
    }

    private func tickHold() {
        guard let started = holdStartedAt else { return }
        let elapsed = CFAbsoluteTimeGetCurrent() - started
        let p = elapsed / UnlockCornerView.holdSeconds
        windows.forEach { $0.unlockCorner.setHoldProgress(p) }
    }

    private func stopHoldTracking() {
        holdStartedAt = nil
        holdTimer?.invalidate()
        holdTimer = nil
        windows.forEach { $0.unlockCorner.resetHold() }
    }

    private func flushPointer() {
        pointerFlushScheduled = false
        guard let point = pendingPointer, !isExiting else { return }
        pendingPointer = nil

        // Don't treat hold-button presses as play activity that resets idle.
        if holdStartedAt != nil { return }

        notePlayActivity()

        guard let primary = primaryWindow else { return }
        let scenePoint = primary.scene.scenePoint(fromScreen: point, in: primary.skView)
        primary.scene.addInk(at: scenePoint)
        combo.notePointer(at: scenePoint)
    }

    private func notePlayActivity() {
        hideCursor()
        idleGate.noteActivity()
        // Activity cancels an in-flight unlock offer cleanly.
        if !idleGate.isArmed {
            clearUnlockState(restartTap: false)
        }
    }

    private func handleKey(keyCode: Int64, characters: String?) {
        guard !isExiting else { return }

        let now = CFAbsoluteTimeGetCurrent()
        if keyCode == lastKeyCode, now - lastKeyAt < 0.03 {
            return
        }
        lastKeyCode = keyCode
        lastKeyAt = now

        spawnKeyVisual(keyCode: keyCode, characters: characters)
        combo.noteKey()
        notePlayActivity()
    }

    private func spawnKeyVisual(keyCode: Int64, characters _: String?) {
        guard let primary = primaryWindow else { return }
        primary.scene.spawnKeyVisual(keyCode: keyCode, characters: nil)
        soundPlayer.playKey()
    }

    private func promptTouchID(epoch: UInt64) async {
        guard !isExiting, unlockEpoch == epoch, idleGate.isArmed else { return }

        // Keep swallowing taps during Touch ID so media/volume keys cannot leak to
        // background apps (Touch ID itself uses the sensor, not keyboard events).
        ensureTapRunning()
        let ok = await touchID.authenticate(reason: "Выйти из KidPlay")
        guard unlockEpoch == epoch, !Task.isCancelled else {
            // Stale cycle — another cleanup already took over.
            return
        }

        if ok {
            exitSuccessfully()
            return
        }

        // Failed / cancelled — wipe unlock state and wait for a fresh 30 s idle.
        idleGate.disarm()
        clearUnlockState(restartTap: true)
        windows.forEach { $0.unlockCorner.update(progress: 0, armed: false) }
    }

    private func exitSuccessfully() {
        guard !isExiting else { return }
        isExiting = true
        clearUnlockState(restartTap: false)
        tearDown()
        onFinish(.exited)
    }
}
