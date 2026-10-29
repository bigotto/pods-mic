import AppKit

enum MicState: Equatable {
    case unmuted
    case muted
    case noMeeting
}

struct MeetStatus: Equatable {
    var mic: MicState
    var browser: String?
    var error: String?
}

/// Fala com o Google Meet aberto no navegador via AppleScript, executando JavaScript na aba do Meet.
final class MeetController {
    private enum Kind { case chromium, safari }

    private struct Browser {
        let name: String
        let bundleID: String
        let kind: Kind
    }

    private let browsers = [
        Browser(name: "Google Chrome", bundleID: "com.google.Chrome", kind: .chromium),
        Browser(name: "Safari", bundleID: "com.apple.Safari", kind: .safari),
        Browser(name: "Brave", bundleID: "com.brave.Browser", kind: .chromium),
        Browser(name: "Microsoft Edge", bundleID: "com.microsoft.edgemac", kind: .chromium),
    ]

    private let queue = DispatchQueue(label: "podsmic.applescript")
    private var scripts: [String: NSAppleScript] = [:]
    private var pollInFlight = false

    /// Localiza o botão do microfone do Meet pelo atributo `data-is-muted` e,
    /// se pedido, clica nele. Retorna "muted", "unmuted" ou "none".
    private static func javascript(toggle: Bool) -> String {
        """
        (function(){
          var els = Array.prototype.slice.call(document.querySelectorAll('[data-is-muted]'));
          var mic = null;
          for (var i = 0; i < els.length; i++) {
            var label = (els[i].getAttribute('aria-label') || '').toLowerCase();
            if (label.indexOf('micro') >= 0 || label.indexOf('mikro') >= 0) { mic = els[i]; break; }
          }
          if (!mic && els.length > 0) mic = els[0];
          if (!mic) return 'none';
          var muted = mic.getAttribute('data-is-muted') === 'true';
          if (\(toggle)) {
            var target = mic.tagName === 'BUTTON' ? mic : (mic.querySelector('button') || mic);
            target.click();
            muted = !muted;
          }
          return muted ? 'muted' : 'unmuted';
        })();
        """
    }

    private static func appleScript(for browser: Browser, toggle: Bool) -> String {
        let js = javascript(toggle: toggle)
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
            .replacingOccurrences(of: "\n", with: " ")
        let run: String
        switch browser.kind {
        case .chromium: run = "execute t javascript \"\(js)\""
        case .safari: run = "do JavaScript \"\(js)\" in t"
        }
        return """
        tell application id "\(browser.bundleID)"
          repeat with w in windows
            try
              set ts to tabs of w
            on error
              set ts to {}
            end try
            repeat with t in ts
              if (URL of t as text) starts with "https://meet.google.com/" then
                set r to \(run)
                if r is not missing value and (r as text) is not "none" then return (r as text)
              end if
            end repeat
          end repeat
          return "none"
        end tell
        """
    }

    func poll(completion: @escaping (MeetStatus) -> Void) {
        queue.async {
            if self.pollInFlight { return }
            self.pollInFlight = true
            let status = self.run(toggle: false)
            self.pollInFlight = false
            DispatchQueue.main.async { completion(status) }
        }
    }

    func toggle(completion: @escaping (MeetStatus) -> Void) {
        queue.async {
            let status = self.run(toggle: true)
            DispatchQueue.main.async { completion(status) }
        }
    }

    // Executa na fila serial: o primeiro navegador com uma reunião ativa vence.
    private func run(toggle: Bool) -> MeetStatus {
        let running = Set(NSWorkspace.shared.runningApplications.compactMap(\.bundleIdentifier))
        var firstError: String?

        for browser in browsers where running.contains(browser.bundleID) {
            let key = "\(browser.bundleID)|\(toggle)"
            let script = scripts[key] ?? NSAppleScript(source: Self.appleScript(for: browser, toggle: toggle))!
            scripts[key] = script

            var errorInfo: NSDictionary?
            let result = script.executeAndReturnError(&errorInfo)
            if let errorInfo {
                if firstError == nil { firstError = Self.describe(errorInfo, browser: browser) }
                continue
            }
            switch result.stringValue {
            case "muted": return MeetStatus(mic: .muted, browser: browser.name)
            case "unmuted": return MeetStatus(mic: .unmuted, browser: browser.name)
            default: continue
            }
        }
        return MeetStatus(mic: .noMeeting, error: firstError)
    }

    private static func describe(_ info: NSDictionary, browser: Browser) -> String {
        let number = info[NSAppleScript.errorNumber] as? Int ?? 0
        let message = info[NSAppleScript.errorMessage] as? String ?? "erro desconhecido"
        if number == -1743 {
            return "Sem permissão para controlar o \(browser.name). Libere em Ajustes do Sistema › Privacidade e Segurança › Automação."
        }
        if message.localizedCaseInsensitiveContains("javascript") || message.localizedCaseInsensitiveContains("apple events") {
            switch browser.kind {
            case .chromium:
                return "Ative no \(browser.name): menu Visualizar › Desenvolvedor › Permitir JavaScript de Apple Events."
            case .safari:
                return "Ative no Safari: menu Desenvolvedor › Permitir JavaScript de Apple Events."
            }
        }
        return "\(browser.name): \(message) (\(number))"
    }
}
