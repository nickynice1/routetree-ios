// Anmelden mit Google und Apple, in der App (R19).
//
// DER WEG, UND WARUM ER SO LÄUFT. Die App öffnet ein
// `ASWebAuthenticationSession` auf `…/konto/<anbieter>/app/`. Darin
// erledigt der SERVER den ganzen OAuth-Ablauf -- derselbe Code, der ihn
// auch im Browser erledigt. Am Ende schickt er den Browser auf
// `routetree://anmeldung?code=…`, das Fenster schließt sich von selbst,
// und die App tauscht den Code gegen ihr Tokenpaar.
//
// **DIE APP FASST NIE EIN ID-TOKEN AN**, und das ist der Kern.
// Apples `ASAuthorizationController` würde ihr eines in die Hand
// drücken -- bequem, und genau der Fall, den `fremdanmeldung.py`
// ausschließt: ein Token aus fremder Hand, dessen Signatur der Server
// dann doch prüfen müsste, mit JWKS-Abruf und Schlüsselrotation. So
// kommt jedes Token aus der TLS-Verbindung des Servers zum Anbieter,
// und die Prüfung entfällt (OpenID Connect Core 3.1.3.7).
//
// **UND DIE TOKEN STEHEN NICHT IN DER RÜCKRUFADRESSE.** Eine Adresse
// landet in Protokollen, im Verlauf und in jedem Absturzbericht
// dazwischen. Der Code dort ist eine Fahrkarte: zwei Minuten gültig,
// einmal einlösbar, in der Datenbank nur als Hash.
//
// WARUM KEIN EIGENES FENSTER MIT `WKWebView`. Ein `WKWebView` teilt
// keine Anmeldung mit Safari, zeigt keine Adresszeile und ist für den
// Benutzer nicht von einer nachgebauten Anmeldemaske zu unterscheiden.
// Google lehnt ihn für OAuth ausdrücklich ab. `ASWebAuthenticationSession`
// ist der vorgesehene Weg: Systemfenster, echte Adresszeile, eigener
// Speicher.

import AuthenticationServices
import Foundation

/// Führt die Anmeldung bei einem Anbieter durch und liefert den Code.
@MainActor
final class Fremdanmeldung: NSObject, ObservableObject {

    enum Anbieter: String, CaseIterable {
        case google
        case apple

        /// Was auf dem Knopf steht. Nicht übersetzt geraten: Beide
        /// Anbieter schreiben ihre Namen vor, und „Mit Apple anmelden"
        /// ist Apples eigener Wortlaut.
        var knopf: String {
            switch self {
            case .google: return String(localized: "Mit Google anmelden")
            case .apple: return String(localized: "Mit Apple anmelden")
            }
        }
    }

    /// Das Schema, an dem das Fenster erkennt, dass es fertig ist.
    /// Es steht auch in `project.yml` (CFBundleURLSchemes) und in
    /// `views.APP_RUECKRUF` -- wer eines ändert, muss die anderen
    /// mitändern, sonst bleibt das Fenster offen und niemand sieht,
    /// warum.
    static let schema = "routetree"

    @Published private(set) var laeuft = false
    @Published var fehler: String?

    private var sitzung: ASWebAuthenticationSession?

    /// Öffnet das Fenster und gibt den Einmalcode zurück.
    ///
    /// `nil` heißt „abgebrochen" -- und das ist KEIN Fehler, sondern
    /// eine Entscheidung. Wer das Fenster zumacht, will keine
    /// Fehlermeldung sehen.
    func anmelden(bei anbieter: Anbieter) async -> String? {
        fehler = nil
        guard let start = URL(string: "konto/\(anbieter.rawValue)/app/",
                              relativeTo: Server.basis)?.absoluteURL else {
            fehler = String(localized: "Die Adresse des Anmeldedienstes stimmt nicht.")
            return nil
        }

        laeuft = true
        defer { laeuft = false }

        return await withCheckedContinuation { fortsetzen in
            let sitzung = ASWebAuthenticationSession(
                url: start, callbackURLScheme: Self.schema
            ) { [weak self] adresse, fehlerchen in
                guard let self else {
                    fortsetzen.resume(returning: nil)
                    return
                }
                if let fehlerchen = fehlerchen as? ASWebAuthenticationSessionError,
                   fehlerchen.code == .canceledLogin {
                    // Abbrechen ist eine Entscheidung, kein Fehler.
                    fortsetzen.resume(returning: nil)
                    return
                }
                if fehlerchen != nil {
                    self.fehler = String(localized:
                        "Die Anmeldung ließ sich nicht öffnen.")
                    fortsetzen.resume(returning: nil)
                    return
                }
                guard let code = Self.code(aus: adresse) else {
                    self.fehler = String(localized:
                        "Die Anmeldung kam ohne Kennung zurück.")
                    fortsetzen.resume(returning: nil)
                    return
                }
                fortsetzen.resume(returning: code)
            }
            // OHNE eigenen, leeren Speicher: Wer sein Google-Konto im
            // Safari schon offen hat, soll nicht noch einmal tippen --
            // das ist der halbe Gewinn dieses Weges.
            sitzung.prefersEphemeralWebBrowserSession = false
            sitzung.presentationContextProvider = self
            self.sitzung = sitzung
            if !sitzung.start() {
                self.fehler = String(localized:
                    "Die Anmeldung ließ sich nicht öffnen.")
                fortsetzen.resume(returning: nil)
            }
        }
    }

    /// Der Code aus `routetree://anmeldung?code=…`.
    ///
    /// Statisch und ohne Zustand, damit ein Test ihn messen kann, ohne
    /// ein Fenster zu öffnen.
    static func code(aus adresse: URL?) -> String? {
        guard let adresse,
              let teile = URLComponents(url: adresse,
                                        resolvingAgainstBaseURL: false),
              let wert = teile.queryItems?.first(where: { $0.name == "code" })?
                  .value,
              !wert.isEmpty
        else { return nil }
        return wert
    }
}

extension Fremdanmeldung: ASWebAuthenticationPresentationContextProviding {
    func presentationAnchor(for session: ASWebAuthenticationSession)
        -> ASPresentationAnchor {
        // Das vorderste Fenster der App. Ohne eines gibt es nichts, an
        // dem das Systemfenster hängen könnte -- dann lieber ein leeres
        // als ein Absturz.
        let szene = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first { $0.activationState == .foregroundActive }
        return szene?.keyWindow ?? ASPresentationAnchor()
    }
}
