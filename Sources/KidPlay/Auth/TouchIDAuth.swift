import Foundation
import LocalAuthentication

@MainActor
final class TouchIDAuth {
    private var inFlight = false
    private var activeContext: LAContext?

    func cancel() {
        activeContext?.invalidate()
        activeContext = nil
        inFlight = false
    }

    func authenticate(reason: String) async -> Bool {
        cancel()
        inFlight = true
        defer {
            inFlight = false
            activeContext = nil
        }

        let context = LAContext()
        context.localizedCancelTitle = "Отмена"
        activeContext = context

        var error: NSError?
        let policy: LAPolicy
        if context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) {
            policy = .deviceOwnerAuthenticationWithBiometrics
        } else if context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) {
            policy = .deviceOwnerAuthentication
        } else {
            return false
        }

        return await evaluate(context, policy: policy, reason: reason)
    }

    private func evaluate(_ context: LAContext, policy: LAPolicy, reason: String) async -> Bool {
        await withCheckedContinuation { continuation in
            context.evaluatePolicy(policy, localizedReason: reason) { success, _ in
                continuation.resume(returning: success)
            }
        }
    }
}
