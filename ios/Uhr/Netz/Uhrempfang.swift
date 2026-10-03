// Die Uhr hört zu (R140).
//
// Gegenstück zu `Uhrbruecke` auf dem Telefon. Beide Seiten sprechen
// WatchConnectivity; welche Wege es gibt und warum wir sie so nutzen,
// steht drüben -- hier steht nur, was die Uhr damit macht.
//
// DREI WEGE KOMMEN AN, UND SIE SIND NICHT GLEICHWERTIG:
//
// * `didReceive file`     -- das vollständige Paket. Der Normalfall.
// * `didReceiveUserInfo`  -- ein kleines Paket, das in die Warteschlange
//                            passt. Gleichwertig zum File, nur kürzer.
// * `didReceiveApplicationContext` -- nur der STAND, nicht der Inhalt.
//                            Damit weiß die Uhr, dass sie alt ist, ohne
//                            dass jemand Daten schickt.
//
// Der dritte ist der, der dieses Ding brauchbar macht: Ein Trainer, der
// morgens ein Play ändert, sieht am Handgelenk „veraltet" und tippt auf
// „Neu holen" -- statt sich zu wundern, warum die Uhr etwas anderes
// zeigt als das Telefon.

import Foundation
import WatchConnectivity

/// Nimmt Pakete vom Telefon an und hält den Bestand.
///
/// `@MainActor`, weil die Oberfläche direkt daran hängt: Was hier
/// gesetzt wird, zeichnet SwiftUI sofort neu.
@MainActor
final class Uhrempfang: NSObject, ObservableObject {

    /// Was auf der Uhr liegt. Beim Start aus dem Lager.
    @Published private(set) var paket: Uhrpaket

    /// Der Stand, den das Telefon zuletzt gemeldet hat.
    ///
    /// Er kommt über den Anwendungszusammenhang und ist deshalb auch
    /// dann da, wenn noch kein Inhalt übertragen wurde.
    @Published private(set) var standAufDemTelefon: Date?

    /// Läuft gerade ein Abgleich?
    @Published private(set) var holtGerade = false

    /// Die letzte Meldung, die einem Menschen etwas sagt. `nil` heißt:
    /// alles in Ordnung.
    @Published private(set) var hinweis: String?

    private let sitzung: WCSession?

    override init() {
        paket = Uhrlager.holen() ?? .leer()
        sitzung = WCSession.isSupported() ? .default : nil
        super.init()
        sitzung?.delegate = self
        sitzung?.activate()
    }

    /// Ist der Bestand älter als das, was das Telefon hat?
    ///
    /// **Kein Vergleich auf Gleichheit.** Uhr und Telefon haben zwei
    /// Uhren, die um Sekunden auseinanderliegen; „ungleich" hieße dann
    /// dauernd „veraltet". Gefragt wird, ob das Telefon MERKLICH weiter
    /// ist.
    var istVeraltet: Bool {
        guard let standAufDemTelefon else { return false }
        return standAufDemTelefon.timeIntervalSince(paket.stand) > 5
    }

    var istLeer: Bool { paket.hefte.isEmpty }

    /// Bittet das Telefon um einen frischen Stand.
    ///
    /// **Das Telefon muss dafür erreichbar sein.** Ist es das nicht,
    /// sagen wir das -- und zwar als Satz, nicht als drehendes Rad, das
    /// nie aufhört.
    func neuHolen() {
        guard let sitzung, sitzung.activationState == .activated else {
            hinweis = String(localized: #"Die Uhr ist noch nicht verbunden."#)
            return
        }
        guard sitzung.isReachable else {
            hinweis = String(localized: #"Das Telefon ist gerade nicht erreichbar. Öffne Routetree auf dem iPhone."#)
            return
        }
        holtGerade = true
        hinweis = nil
        sitzung.sendMessage(
            [Uhrfunk.bitteSchicken: true],
            replyHandler: { [weak self] _ in
                Task { @MainActor in self?.holtGerade = false }
            },
            errorHandler: { [weak self] fehler in
                Task { @MainActor in
                    self?.holtGerade = false
                    self?.hinweis = fehler.localizedDescription
                }
            })
    }

    // MARK: - Was ankommt

    fileprivate func uebernehmen(_ daten: Data) {
        guard let neu = Uhrpaket.lesen(daten) else {
            // EIN UNLESBARES PAKET AENDERT NICHTS. Der alte Stand ist
            // besser als kein Stand -- und die Fassung im Paket sagt,
            // warum es nicht passt (siehe `Uhrpaket.fassung`).
            hinweis = String(localized: #"Das iPhone hat einen Stand geschickt, den diese Uhr-App nicht lesen kann. Aktualisiere beide Apps."#)
            return
        }
        paket = neu
        standAufDemTelefon = neu.stand
        holtGerade = false
        hinweis = nil
        Uhrlager.ablegen(neu)
    }
}

// MARK: - WCSessionDelegate

extension Uhrempfang: WCSessionDelegate {

    nonisolated func session(_ session: WCSession,
                             activationDidCompleteWith state: WCSessionActivationState,
                             error: Error?) {}

    nonisolated func session(_ session: WCSession,
                             didReceiveApplicationContext context: [String: Any]) {
        guard let stand = context[Uhrfunk.stand] as? Double else { return }
        Task { @MainActor in
            self.standAufDemTelefon = Date(timeIntervalSince1970: stand)
        }
    }

    nonisolated func session(_ session: WCSession,
                             didReceiveUserInfo userInfo: [String: Any]) {
        guard let daten = userInfo[Uhrfunk.paket] as? Data else { return }
        Task { @MainActor in self.uebernehmen(daten) }
    }

    nonisolated func session(_ session: WCSession, didReceive file: WCSessionFile) {
        // DIE DATEI MUSS SOFORT GELESEN WERDEN. Das System löscht sie,
        // sobald diese Methode zurückkehrt -- ein `Task`, der sie später
        // aufmacht, findet nichts mehr.
        guard let daten = try? Data(contentsOf: file.fileURL) else { return }
        Task { @MainActor in self.uebernehmen(daten) }
    }
}
