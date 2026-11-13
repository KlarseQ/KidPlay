import Foundation

@MainActor
final class ComboTracker {
    private(set) var keyCombo = 0
    private(set) var pathComboMeters: Double = 0

    private var lastKeyAt = Date.distantPast
    private var lastPointerAt = Date.distantPast
    private var lastPointerPoint: CGPoint?
    private let keyGap: TimeInterval = 1.2
    private let pathGap: TimeInterval = 0.8

    /// Points → "path combo" units (scaled screen pixels).
    private let pathScale: Double = 0.02

    var onChange: ((Int, Int) -> Void)?

    func noteKey() {
        let now = Date()
        if now.timeIntervalSince(lastKeyAt) > keyGap {
            keyCombo = 0
        }
        keyCombo += 1
        lastKeyAt = now
        emit()
    }

    func notePointer(at point: CGPoint) {
        let now = Date()
        if now.timeIntervalSince(lastPointerAt) > pathGap {
            pathComboMeters = 0
            lastPointerPoint = point
        } else if let last = lastPointerPoint {
            let dx = Double(point.x - last.x)
            let dy = Double(point.y - last.y)
            pathComboMeters += (dx * dx + dy * dy).squareRoot() * pathScale
            lastPointerPoint = point
        } else {
            lastPointerPoint = point
        }
        lastPointerAt = now
        emit()
    }

    func reset() {
        keyCombo = 0
        pathComboMeters = 0
        lastPointerPoint = nil
        emit()
    }

    private func emit() {
        onChange?(keyCombo, Int(pathComboMeters.rounded()))
    }
}
