import Foundation

@MainActor
final class IdleGate {
    static let idleSeconds: TimeInterval = 30

    private(set) var isArmed = false
    private var lastActivity = Date()
    private var timer: Timer?
    private var onArmedChanged: ((Bool) -> Void)?
    private var onProgress: ((Double) -> Void)?

    /// Progress 0...1 toward arm; 1 means armed.
    var progress: Double {
        if isArmed { return 1 }
        let elapsed = Date().timeIntervalSince(lastActivity)
        return min(1, max(0, elapsed / Self.idleSeconds))
    }

    func start(onArmedChanged: @escaping (Bool) -> Void, onProgress: @escaping (Double) -> Void) {
        self.onArmedChanged = onArmedChanged
        self.onProgress = onProgress
        noteActivity()
        timer?.invalidate()
        let timer = Timer(timeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self else { return }
            MainActor.assumeIsolated {
                self.tick()
            }
        }
        self.timer = timer
        RunLoop.main.add(timer, forMode: .common)
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        setArmed(false)
    }

    func noteActivity() {
        lastActivity = Date()
        if isArmed {
            setArmed(false)
        }
        onProgress?(0)
    }

    func disarm() {
        lastActivity = Date()
        setArmed(false)
        onProgress?(0)
    }

    /// Full clean slate for a new unlock-offer cycle.
    func resetForNewOffer() {
        lastActivity = Date()
        // Keep armed if caller is about to re-arm; only clear activity clock when disarmed.
        if !isArmed {
            onProgress?(0)
        }
    }

    private func tick() {
        let p = progress
        onProgress?(p)
        if !isArmed, p >= 1 {
            setArmed(true)
        }
    }

    private func setArmed(_ value: Bool) {
        guard isArmed != value else { return }
        isArmed = value
        onArmedChanged?(value)
    }
}
