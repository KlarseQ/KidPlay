import AppKit

@MainActor
final class AppCoordinator {
    private var setupController: SetupWindowController?
    private var playController: PlaySessionController?

    func start() {
        showSetup()
    }

    private func showSetup(error: String? = nil) {
        playController?.tearDown()
        playController = nil

        if setupController == nil {
            let setup = SetupWindowController { [weak self] useColors in
                self?.beginPlay(useColors: useColors)
            }
            setupController = setup
        }

        setupController?.showWindow(nil)
        if let error {
            setupController?.showError(error)
        }
        NSApp.activate(ignoringOtherApps: true)
    }

    private func beginPlay(useColors: Bool) {
        setupController?.window?.orderOut(nil)

        let play = PlaySessionController(useColors: useColors) { [weak self] outcome in
            switch outcome {
            case .exited:
                self?.quitApp()
            case .failedToStart(let message):
                self?.playController = nil
                self?.showSetup(error: message)
            }
        }
        playController = play
        play.start()
    }

    private func quitApp() {
        playController?.tearDown()
        playController = nil
        NSApp.terminate(nil)
    }
}
