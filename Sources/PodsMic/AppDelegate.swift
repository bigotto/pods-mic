import AppKit
import ServiceManagement

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    private let meet = MeetController()
    private let remote = AirPodsRemote()
    private var status = MeetStatus(mic: .noMeeting)
    private var timer: Timer?

    private let statusMenuItem = NSMenuItem(title: "", action: nil, keyEquivalent: "")
    private let errorMenuItem = NSMenuItem(title: "", action: nil, keyEquivalent: "")
    private let toggleMenuItem = NSMenuItem(title: "Alternar mudo", action: #selector(toggleMuteFromMenu), keyEquivalent: "")
    private let airPodsMenuItem = NSMenuItem(title: "Controlar pelos AirPods", action: #selector(toggleAirPods), keyEquivalent: "")
    private let soundMenuItem = NSMenuItem(title: "Tocar som ao alternar", action: #selector(toggleSound), keyEquivalent: "")
    private let loginMenuItem = NSMenuItem(title: "Abrir ao iniciar sessão", action: #selector(toggleLaunchAtLogin), keyEquivalent: "")

    private var airPodsEnabled: Bool {
        get { UserDefaults.standard.object(forKey: "airPodsEnabled") as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: "airPodsEnabled") }
    }

    // Desligado por padrão: o próprio macOS já toca o som de mudo/desmudo do gesto da haste.
    private var soundEnabled: Bool {
        get { UserDefaults.standard.object(forKey: "soundEnabled") as? Bool ?? false }
        set { UserDefaults.standard.set(newValue, forKey: "soundEnabled") }
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        buildMenu()
        remote.onMuteGesture = { [weak self] wantsMuted in
            guard let self, self.status.mic != .noMeeting else { return }
            // Só alterna se o Meet ainda não estiver no estado pedido (evita alternar em dobro).
            if wantsMuted != (self.status.mic == .muted) {
                self.toggleMute(fromAirPods: true)
            }
        }
        render()

        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.refresh() }
        }
        refresh()
    }

    private func buildMenu() {
        let menu = NSMenu()
        menu.autoenablesItems = false
        statusMenuItem.isEnabled = false
        errorMenuItem.isEnabled = false
        menu.addItem(statusMenuItem)
        menu.addItem(errorMenuItem)
        menu.addItem(.separator())
        for item in [toggleMenuItem, airPodsMenuItem, soundMenuItem, loginMenuItem] {
            item.target = self
            menu.addItem(item)
        }
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Sair", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        statusItem.menu = menu
    }

    private func refresh() {
        meet.poll { [weak self] newStatus in
            self?.apply(newStatus)
        }
    }

    private func apply(_ newStatus: MeetStatus) {
        if newStatus != status {
            log.notice("state: \(String(describing: newStatus.mic), privacy: .public) browser=\(newStatus.browser ?? "-", privacy: .public) error=\(newStatus.error ?? "-", privacy: .public)")
        }
        status = newStatus
        if airPodsEnabled, newStatus.mic != .noMeeting {
            remote.activate(muted: newStatus.mic == .muted)
        } else {
            remote.deactivate()
        }
        render()
    }

    private func render() {
        let symbol: String
        let description: String
        switch status.mic {
        case .unmuted:
            symbol = "mic.fill"
            description = "Microfone ligado"
        case .muted:
            symbol = "mic.slash.fill"
            description = "Microfone desligado"
        case .noMeeting:
            symbol = "mic.slash"
            description = "Nenhuma reunião do Meet aberta"
        }

        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: symbol, accessibilityDescription: description)
            button.image?.isTemplate = true
            button.appearsDisabled = status.mic == .noMeeting
            button.toolTip = "PodsMic — \(description)"
        }

        statusMenuItem.title = status.browser.map { "\(description) (\($0))" } ?? description
        errorMenuItem.title = status.error ?? ""
        errorMenuItem.isHidden = status.error == nil
        toggleMenuItem.isEnabled = status.mic != .noMeeting
        airPodsMenuItem.state = airPodsEnabled ? .on : .off
        soundMenuItem.state = soundEnabled ? .on : .off
        loginMenuItem.state = SMAppService.mainApp.status == .enabled ? .on : .off
    }

    @objc private func toggleMuteFromMenu() {
        toggleMute(fromAirPods: false)
    }

    private func toggleMute(fromAirPods: Bool) {
        meet.toggle { [weak self] newStatus in
            guard let self else { return }
            log.notice("toggle (airpods=\(fromAirPods, privacy: .public)) -> \(String(describing: newStatus.mic), privacy: .public)")
            self.apply(newStatus)
            if fromAirPods, self.soundEnabled, newStatus.mic != .noMeeting {
                NSSound(named: newStatus.mic == .muted ? "Bottle" : "Pop")?.play()
            }
        }
    }

    @objc private func toggleAirPods() {
        airPodsEnabled.toggle()
        apply(status)
    }

    @objc private func toggleSound() {
        soundEnabled.toggle()
        render()
    }

    @objc private func toggleLaunchAtLogin() {
        do {
            if SMAppService.mainApp.status == .enabled {
                try SMAppService.mainApp.unregister()
            } else {
                try SMAppService.mainApp.register()
            }
        } catch {
            let alert = NSAlert(error: error)
            alert.runModal()
        }
        render()
    }
}
