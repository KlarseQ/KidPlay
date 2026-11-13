import AppKit
import ApplicationServices
import CoreGraphics
import Foundation

enum PlayInputEvent: Sendable {
    case keyDown(keyCode: Int64, characters: String?)
    case pointer(x: Double, y: Double, isDrag: Bool)
    case pointerDown(x: Double, y: Double)
    case pointerUp(x: Double, y: Double)
    case labeled(String)
}

/// System-wide CGEventTap(s) that swallow input — including media/brightness keys.
final class InputGuard: @unchecked Sendable {
    private var taps: [CFMachPort] = []
    private var runLoopSources: [CFRunLoopSource] = []
    private(set) var isSwallowing = false

    var onEvent: (@Sendable (PlayInputEvent) -> Void)?

    private var lastEmittedPointer = CGPoint(x: -10_000, y: -10_000)
    private var lastPointerEmitAt: CFAbsoluteTime = 0
    private let pointerMinDistance: CGFloat = 6
    private let pointerMinInterval: CFAbsoluteTime = 1.0 / 45.0

    /// Silent status only — never triggers system permission sheets.
    static func permissionSummary() -> String {
        let ax = AXIsProcessTrusted()
        let listen = CGPreflightListenEventAccess()
        let post = CGPreflightPostEventAccess()
        return "Accessibility: \(ax ? "OK" : "нет") · Input Monitoring: \(listen ? "OK" : "нет") · Post Events: \(post ? "OK" : "нет")"
    }

    /// Call ONLY from the explicit «Разрешения…» button — shows system prompts.
    static func promptForPermissions() {
        let axOptions = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(axOptions)
        _ = CGRequestListenEventAccess()
        _ = CGRequestPostEventAccess()
    }

    static func canCreateTap() -> Bool {
        // Soft hint for UI only. Actual ability is determined by tapCreate.
        AXIsProcessTrusted() || CGPreflightListenEventAccess() || CGPreflightPostEventAccess()
    }

    func start() throws {
        stop()
        // Do NOT prompt here. User already granted rights once; re-requesting every launch
        // spam-prompts and can confuse TCC.

        let mask = Self.eventMask
        let userInfo = Unmanaged.passUnretained(self).toOpaque()
        let callback: CGEventTapCallBack = { _, type, event, refcon -> Unmanaged<CGEvent>? in
            guard let refcon else { return Unmanaged.passUnretained(event) }
            let guardRef = Unmanaged<InputGuard>.fromOpaque(refcon).takeUnretainedValue()
            return guardRef.handle(type: type, event: event)
        }

        // Prefer swallowing taps. Do not gate on Preflight* — they often lie until after a
        // successful tap / process restart, and Request* would pop dialogs again.
        let locations: [CGEventTapLocation] = [.cghidEventTap, .cgSessionEventTap]
        for location in locations {
            if let tap = CGEvent.tapCreate(
                tap: location,
                place: .headInsertEventTap,
                options: .defaultTap,
                eventsOfInterest: mask,
                callback: callback,
                userInfo: userInfo
            ) {
                taps.append(tap)
                if let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0) {
                    runLoopSources.append(source)
                    CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
                }
                CGEvent.tapEnable(tap: tap, enable: true)
            }
        }

        if taps.isEmpty {
            // Last resort: observe-only so Play still works; media keys may leak.
            for location in locations {
                if let tap = CGEvent.tapCreate(
                    tap: location,
                    place: .headInsertEventTap,
                    options: .listenOnly,
                    eventsOfInterest: mask,
                    callback: callback,
                    userInfo: userInfo
                ) {
                    taps.append(tap)
                    if let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0) {
                        runLoopSources.append(source)
                        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
                    }
                    CGEvent.tapEnable(tap: tap, enable: true)
                }
            }
            if !taps.isEmpty {
                isSwallowing = false
                NSLog("KidPlay: listenOnly tap(s) only. \(Self.permissionSummary())")
                return
            }

            throw InputGuardError.tapCreateFailed(
                """
                Не удалось создать CGEventTap.
                \(Self.permissionSummary())
                Если галочки уже стоят: сними и поставь снова для KidPlay в
                Универсальный доступ и Мониторинг ввода, полностью закрой приложение и запусти через ./scripts/run-app.sh.
                Не нажимай «Разрешения…» каждый раз — только если галочек ещё нет.
                """
            )
        }

        isSwallowing = true
        NSLog("KidPlay: installed \(taps.count) swallowing tap(s). \(Self.permissionSummary())")
    }

    func stop() {
        for tap in taps {
            CGEvent.tapEnable(tap: tap, enable: false)
        }
        for source in runLoopSources {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
        }
        taps.removeAll()
        runLoopSources.removeAll()
        isSwallowing = false
    }

    private static var eventMask: CGEventMask {
        let bits: [UInt64] = [
            UInt64(CGEventType.keyDown.rawValue),
            UInt64(CGEventType.keyUp.rawValue),
            UInt64(CGEventType.flagsChanged.rawValue),
            UInt64(CGEventType.leftMouseDown.rawValue),
            UInt64(CGEventType.leftMouseUp.rawValue),
            UInt64(CGEventType.rightMouseDown.rawValue),
            UInt64(CGEventType.rightMouseUp.rawValue),
            UInt64(CGEventType.otherMouseDown.rawValue),
            UInt64(CGEventType.otherMouseUp.rawValue),
            UInt64(CGEventType.mouseMoved.rawValue),
            UInt64(CGEventType.leftMouseDragged.rawValue),
            UInt64(CGEventType.rightMouseDragged.rawValue),
            UInt64(CGEventType.otherMouseDragged.rawValue),
            UInt64(CGEventType.scrollWheel.rawValue),
            14,
            29,
        ]
        return bits.reduce(CGEventMask(0)) { $0 | (1 << $1) }
    }

    private func handle(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            for tap in taps {
                CGEvent.tapEnable(tap: tap, enable: true)
            }
            return Unmanaged.passUnretained(event)
        }

        let emit = onEvent
        let raw = Int(type.rawValue)

        if raw == 14 {
            if let label = Self.mediaLabel(from: event) {
                emit?(.labeled(label))
            }
            return isSwallowing ? nil : Unmanaged.passUnretained(event)
        }

        switch type {
        case .keyDown:
            let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
            if let fLabel = Self.functionKeyLabel(keyCode) {
                emit?(.labeled(fLabel))
            } else {
                emit?(.keyDown(keyCode: keyCode, characters: event.keyboardCharacters()))
            }

        case .keyUp, .flagsChanged:
            break

        case .mouseMoved, .leftMouseDragged, .rightMouseDragged, .otherMouseDragged:
            emitPointerIfNeeded(event.location, isDrag: type != .mouseMoved)

        case .leftMouseDown, .rightMouseDown, .otherMouseDown:
            let loc = event.location
            lastEmittedPointer = CGPoint(x: loc.x, y: loc.y)
            lastPointerEmitAt = CFAbsoluteTimeGetCurrent()
            emit?(.pointerDown(x: loc.x, y: loc.y))
            emit?(.pointer(x: loc.x, y: loc.y, isDrag: false))

        case .leftMouseUp, .rightMouseUp, .otherMouseUp:
            let loc = event.location
            emit?(.pointerUp(x: loc.x, y: loc.y))

        case .scrollWheel:
            let loc = event.location
            lastEmittedPointer = CGPoint(x: loc.x, y: loc.y)
            lastPointerEmitAt = CFAbsoluteTimeGetCurrent()
            emit?(.pointer(x: loc.x, y: loc.y, isDrag: false))

        default:
            break
        }

        return isSwallowing ? nil : Unmanaged.passUnretained(event)
    }

    private func emitPointerIfNeeded(_ loc: CGPoint, isDrag: Bool) {
        let now = CFAbsoluteTimeGetCurrent()
        let dx = loc.x - lastEmittedPointer.x
        let dy = loc.y - lastEmittedPointer.y
        let dist = (dx * dx + dy * dy).squareRoot()
        guard dist >= pointerMinDistance || now - lastPointerEmitAt >= pointerMinInterval else {
            return
        }
        lastEmittedPointer = loc
        lastPointerEmitAt = now
        onEvent?(.pointer(x: loc.x, y: loc.y, isDrag: isDrag))
    }

    private static func mediaLabel(from event: CGEvent) -> String? {
        guard let ns = NSEvent(cgEvent: event) else { return "media" }
        let data1 = ns.data1
        let keyType = (data1 & 0xFFFF_0000) >> 16
        let keyState = data1 & 0x0000_00FF
        if keyState == 0x0B { return nil }

        switch keyType {
        case 0: return "звук +"
        case 1: return "звук −"
        case 2: return "яркость +"
        case 3: return "яркость −"
        case 7: return "mute"
        case 8: return "contrast +"
        case 9: return "contrast −"
        case 16: return "play"
        case 17: return "next"
        case 18: return "prev"
        case 21: return "подсветка +"
        case 22: return "подсветка −"
        case 23: return "подсветка"
        case 6: return "power"
        default: return "media \(keyType)"
        }
    }

    private static func functionKeyLabel(_ keyCode: Int64) -> String? {
        switch keyCode {
        case 122: return "F1"
        case 120: return "F2"
        case 99: return "F3"
        case 118: return "F4"
        case 96: return "F5"
        case 97: return "F6"
        case 98: return "F7"
        case 100: return "F8"
        case 101: return "F9"
        case 109: return "F10"
        case 103: return "F11"
        case 111: return "F12"
        default: return nil
        }
    }
}

enum InputGuardError: Error, LocalizedError {
    case tapCreateFailed(String)

    var errorDescription: String? {
        switch self {
        case .tapCreateFailed(let summary):
            return summary
        }
    }
}

private extension CGEvent {
    func keyboardCharacters() -> String? {
        var length = 0
        var chars = [UniChar](repeating: 0, count: 4)
        keyboardGetUnicodeString(maxStringLength: 4, actualStringLength: &length, unicodeString: &chars)
        guard length > 0 else { return nil }
        return String(utf16CodeUnits: chars, count: Int(length))
    }
}
