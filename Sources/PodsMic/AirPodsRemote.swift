import AVFoundation

/// Recebe o gesto de mudo dos AirPods (apertar a haste com o microfone em uso).
///
/// Com o microfone ativo, os AirPods não mandam play/pause: mandam um comando de mudo que o
/// macOS entrega, via `AVAudioApplication`, a um app que esteja gravando e inscrito no gesto.
/// O Chrome não é inscrito, então este app também captura o microfone (descartando o áudio)
/// e se inscreve: observa `inputMuteStateChangeNotification` e define o handler de mudo.
/// Só fica ativo enquanto há uma reunião aberta.
@MainActor
final class AirPodsRemote {
    /// Chamado com o estado de mudo que o usuário pediu pelos AirPods.
    var onMuteGesture: ((Bool) -> Void)?
    private(set) var isActive = false

    private var engine: AVAudioEngine?
    private var configObserver: NSObjectProtocol?
    private var muteObserver: NSObjectProtocol?

    func activate(muted: Bool) {
        if !isActive {
            isActive = true
            // Observar a notificação com `object: AVAudioApplication.shared` (com `object: nil` não
            // vale) é o que inscreve o app no gesto: o audiomxd passa a vê-lo com
            // PrefersBluetoothAccessoryMuting e entrega o toque da haste ao handler abaixo.
            muteObserver = NotificationCenter.default.addObserver(
                forName: AVAudioApplication.inputMuteStateChangeNotification,
                object: AVAudioApplication.shared, queue: .main
            ) { notification in
                let muted = notification.userInfo?[AVAudioApplication.muteStateKey] as? Bool
                log.notice("mute state notification: \(String(describing: muted), privacy: .public)")
            }
            startCapture()
        }
        // Mantém o estado de mudo do sistema igual ao do Meet, para o próximo gesto pedir o oposto.
        if AVAudioApplication.shared.isInputMuted != muted {
            try? AVAudioApplication.shared.setInputMuted(muted)
        }
    }

    func deactivate() {
        guard isActive else { return }
        isActive = false
        if let muteObserver { NotificationCenter.default.removeObserver(muteObserver) }
        muteObserver = nil
        try? AVAudioApplication.shared.setInputMuteStateChangeHandler(nil)
        stopCapture()
    }

    // Definido depois que a captura começa, enquanto há uma sessão de gravação ativa.
    private func registerMuteHandler() {
        do {
            try AVAudioApplication.shared.setInputMuteStateChangeHandler { [weak self] muted in
                log.notice("airpods mute gesture: muted=\(muted, privacy: .public)")
                DispatchQueue.main.async { self?.onMuteGesture?(muted) }
                return true
            }
            log.notice("mute handler registered")
        } catch {
            log.error("mute handler failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    private func startCapture() {
        let engine = AVAudioEngine()
        let input = engine.inputNode
        input.installTap(onBus: 0, bufferSize: 4096, format: input.outputFormat(forBus: 0)) { _, _ in }
        do {
            try engine.start()
            log.notice("mic capture started")
            registerMuteHandler()
        } catch {
            log.error("mic capture failed: \(error.localizedDescription, privacy: .public)")
        }
        self.engine = engine

        // Troca do dispositivo de entrada (ex.: AirPods conectando) para o engine; reinicia.
        configObserver = NotificationCenter.default.addObserver(
            forName: .AVAudioEngineConfigurationChange, object: engine, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self, self.isActive else { return }
                self.stopCapture()
                self.startCapture()
            }
        }
    }

    private func stopCapture() {
        if let configObserver { NotificationCenter.default.removeObserver(configObserver) }
        configObserver = nil
        engine?.inputNode.removeTap(onBus: 0)
        engine?.stop()
        engine = nil
    }
}
