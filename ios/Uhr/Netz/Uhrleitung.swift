// Welchen Weg die Uhr zum Server hat -- und was der Träger wissen muss.
//
// **Niklas am 01.10.2026:** „die uhr muss entscheiden welche verbindung
// stärker ist ob bluetooth oder mobilfunk. wenns keine mobilfunk uhr ist
// das geht nur bluetooth und da soll stehen das das handy beim
// uhrenträger bleiben muss, wenns mobilfunk ist sollte dementsprechend
// auch ein hinweis stehen."
//
// ## Warum das überhaupt eine Frage ist
//
// Der Coaching-Modus läuft über den SERVER: Der Coach ruft einen Play
// auf seinem Telefon, die Uhr des Spielers fragt den Server, was gerade
// gilt. Die beiden Geräte stehen hundert Meter auseinander und gehören
// verschiedenen Menschen -- über Bluetooth reden sie nie miteinander.
//
// Die Uhr kommt auf zwei Wegen ins Netz:
//
//   * **Eigenes Netz.** Eine Uhr mit Mobilfunk oder in einem bekannten
//     WLAN geht direkt. Das Telefon des Trägers darf in der Tasche
//     bleiben, im Spind liegen oder ausgeschaltet sein.
//
//   * **Über das gekoppelte iPhone.** Ohne eigenes Netz reicht watchOS
//     die Anfrage an das Telefon des TRÄGERS weiter. Dann muss dieses
//     Telefon in Reichweite sein -- und genau das weiss niemand von
//     selbst. Ein Spieler, der sein Telefon beim Coach an der Bank
//     lässt, steht auf dem Feld mit einer Uhr, die nichts mehr bekommt,
//     und hält sie für kaputt.
//
// Deshalb steht hier nicht nur, OB es geht, sondern WAS der Träger tun
// muss, damit es weiter geht.
//
// ## Was hier NICHT gemessen wird
//
// Eine Signalstärke in Balken. `NWPathMonitor` sagt, über welche Art
// von Schnittstelle der Weg läuft und ob er teuer ist -- nicht, wie
// gut er ist. Wer daraus Balken malte, malte eine Schätzung.
//
// Die Frage „welche Verbindung ist stärker" beantwortet das Gerät
// ohnehin selbst: watchOS nimmt den eigenen Weg, wenn es einen hat,
// und reicht sonst an das Telefon weiter. Was die App beitragen kann,
// ist zu SAGEN, welcher Fall gerade vorliegt.

import Foundation
import Network
#if canImport(WatchConnectivity)
import WatchConnectivity
#endif

/// Auf welchem Weg die Uhr gerade an den Server kommt.
enum Uhrweg: String, Equatable {

    /// Eigenes Netz -- Mobilfunk oder WLAN. Das Telefon wird nicht
    /// gebraucht.
    case eigenes

    /// Nur über das gekoppelte iPhone. Es muss beim Träger bleiben.
    case ueberDasTelefon

    /// Gar kein Weg. Weder eigenes Netz noch ein erreichbares Telefon.
    case keiner
}

/// Beobachtet den Weg der Uhr ins Netz und sagt, was der Träger wissen
/// muss.
///
/// **Ein eigener Beobachter und nicht `Uhrempfang`.** Der nimmt Pakete
/// vom Telefon an (Bluetooth, R140) und hat mit dem Server nichts zu
/// tun. Zwei Dinge in einer Klasse hiessen, dass ein Wristcoach ohne
/// Netz kaputt aussähe.
@MainActor
final class Uhrleitung: ObservableObject {

    @Published private(set) var weg: Uhrweg = .keiner

    /// Ob der Weg Geld kostet. Mobilfunk auf der Uhr ist oft ein
    /// eigener Vertrag, und ein Spieltag mit Dauerabfrage ist etwas
    /// anderes als eine Nachricht.
    @Published private(set) var teuer = false

    private let waechter = NWPathMonitor()
    private let schlange = DispatchQueue(label: "de.routetree.uhrleitung")

    init() {
        waechter.pathUpdateHandler = { [weak self] pfad in
            Task { @MainActor in self?.uebernehmen(pfad) }
        }
        waechter.start(queue: schlange)
    }

    deinit { waechter.cancel() }

    /// Was auf dem Bildschirm steht, als ganzer Satz.
    ///
    /// **Ein Satz und keine zwei Wörter.** „Bluetooth" sagt einem
    /// Spieler nicht, dass sein Telefon mit aufs Feld muss. Genau das
    /// ist aber die ganze Auskunft, auf die es ankommt.
    var hinweis: String {
        switch weg {
        case .eigenes:
            return teuer
                ? String(localized: "Über Mobilfunk. Das Telefon kann bleiben, wo es ist.")
                : String(localized: "Über WLAN. Das Telefon kann bleiben, wo es ist.")
        case .ueberDasTelefon:
            return String(localized:
                "Über dein iPhone. Es muss bei dir bleiben, nicht an der Bank.")
        case .keiner:
            return String(localized:
                "Kein Netz. Die Uhr bekommt gerade keine Plays.")
        }
    }

    /// Kurzform für die Zeile über dem Play, wo kein Platz für einen
    /// Satz ist.
    var kurz: String {
        switch weg {
        case .eigenes: return teuer
            ? String(localized: "Mobilfunk") : String(localized: "WLAN")
        case .ueberDasTelefon: return String(localized: "über iPhone")
        case .keiner: return String(localized: "kein Netz")
        }
    }

    /// Ob überhaupt etwas ankommen kann.
    var erreichbar: Bool { weg != .keiner }

    // MARK: - Innen

    private func uebernehmen(_ pfad: NWPath) {
        teuer = pfad.isExpensive
        guard pfad.status == .satisfied else {
            // KEIN WEG HEISST NICHT ZWINGEND KEIN NETZ.
            //
            // `NWPathMonitor` sieht auf der Uhr die Weiterleitung über
            // das Telefon nicht immer als eigenen Pfad. Ist das Telefon
            // erreichbar, geht es trotzdem -- watchOS reicht die
            // Anfrage durch, ohne dass die App davon erfährt.
            weg = telefonErreichbar ? .ueberDasTelefon : .keiner
            return
        }
        // EINE EIGENE SCHNITTSTELLE SCHLAEGT DIE WEITERLEITUNG. Hat die
        // Uhr Mobilfunk oder WLAN, nimmt watchOS diesen Weg -- das
        // Telefon wird dann nicht gebraucht, auch wenn es daliegt.
        if pfad.usesInterfaceType(.cellular) || pfad.usesInterfaceType(.wifi) {
            weg = .eigenes
        } else {
            weg = telefonErreichbar ? .ueberDasTelefon : .keiner
        }
    }

    private var telefonErreichbar: Bool {
        #if canImport(WatchConnectivity)
        guard WCSession.isSupported() else { return false }
        return WCSession.default.isReachable
        #else
        return false
        #endif
    }
}
