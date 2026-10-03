import Foundation

/// Aus einer Aufstellungs-Vorlage werden Figuren auf dem Feld (R110.5).
///
/// **Was gefehlt hat.** Der Browser bietet seit jeher sieben
/// Offense-Aufstellungen und vier Deckungen an; die App kannte nur die
/// GESPEICHERTEN. Wer dort ein Playbook neu anlegte, hatte also gar
/// keine Vorlage und musste fünf Figuren von Hand setzen, bevor er die
/// erste Route zeichnen konnte.
///
/// **Warum das hier steht und nicht in der Ansicht.** Es gibt keinen
/// Mac. Eine Regel in einer SwiftUI-Ansicht lässt sich nicht
/// ausprobieren, sondern nur behaupten. Dieselbe Entscheidung wie bei
/// `Zeichenblock` (B4), `Kaderblock` (B9) und `Spiellageblock`
/// (R110.3).
///
/// **Die einzige Rechnung, die hier passiert**, ist die Längslage: Sie
/// hängt an der Line of Scrimmage und der Angriffsrichtung. Die
/// Querlage kommt fertig vom Server -- und zwar für Richtung +1;
/// greift die Mannschaft anders herum an, wird sie gespiegelt. Sonst
/// stünde „Trips rechts" im Diagramm links, und genau das zeigt der
/// Trainer der Mannschaft.
enum Vorlagenblock {

    /// Die Figuren einer OFFENSE-Vorlage.
    ///
    /// **`zurueck` geht beim Angriff nach HINTEN**, also gegen die
    /// Angriffsrichtung -- bei der Verteidigung nach vorn. Ein
    /// Vorzeichen, und es entscheidet, ob der Quarterback hinter dem
    /// Center steht oder in der Verteidigung.
    static func offense(_ vorlage: Modell.Vorlage, los: Double,
                        richtung: Int, feld: Feld,
                        farbenVon vorher: [Zeichnung.Spieler] = [])
        -> [Zeichnung.Spieler] {
        // DIE FARBEN BLEIBEN. Wer seinem X eine Farbe gegeben hat, hat
        // das für den Spieler getan und nicht für die Aufstellung --
        // ein Wechsel der Formation ist kein Grund, sie wegzuwerfen.
        var farben: [String: String] = [:]
        for s in vorher where s.seite == .offense {
            if let f = s.farbe, !f.isEmpty { farben[s.id] = f }
        }
        return vorlage.leute.map { platz in
            let x = los - platz.zurueck * Double(richtung)
            let y = richtung >= 0 ? platz.y : (feld.breite - platz.y)
            return Zeichnung.Spieler(
                id: platz.id, seite: .offense, rolle: platz.role,
                kuerzel: platz.label, farbe: farben[platz.id],
                x: min(max(x, 0), feld.gesamtLaenge),
                y: min(max(y, 0), feld.breite))
        }
    }

    /// Die Figuren einer DECKUNG.
    static func defense(_ vorlage: Modell.Vorlage, los: Double,
                        richtung: Int, feld: Feld) -> [Zeichnung.Spieler] {
        vorlage.leute.map { platz in
            let x = los + platz.zurueck * Double(richtung)
            let y = richtung >= 0 ? platz.y : (feld.breite - platz.y)
            return Zeichnung.Spieler(
                id: platz.id, seite: .defense, rolle: platz.role,
                kuerzel: platz.label, farbe: nil,
                x: min(max(x, 0), feld.gesamtLaenge),
                y: min(max(y, 0), feld.breite))
        }
    }

    /// Die neue Aufstellung, wenn eine OFFENSE-Vorlage angewendet wird.
    ///
    /// **Die Defense bleibt stehen.** Wer die Angriffsformation
    /// wechselt, wechselt nicht die Deckung, gegen die er sie zeichnet
    /// -- und die wieder aufzubauen wäre die Arbeit, die man gerade
    /// gespart hat.
    static func mitOffense(_ vorlage: Modell.Vorlage,
                           in zeichnung: Zeichnung, los: Double,
                           richtung: Int, feld: Feld) -> [Zeichnung.Spieler] {
        let deckung = zeichnung.spieler.filter { $0.seite == .defense }
        return offense(vorlage, los: los, richtung: richtung, feld: feld,
                       farbenVon: zeichnung.spieler) + deckung
    }

    /// Dasselbe für eine Deckung: Die Offense bleibt stehen.
    static func mitDefense(_ vorlage: Modell.Vorlage,
                           in zeichnung: Zeichnung, los: Double,
                           richtung: Int, feld: Feld) -> [Zeichnung.Spieler] {
        let angriff = zeichnung.spieler.filter { $0.seite != .defense }
        return angriff + defense(vorlage, los: los, richtung: richtung,
                                 feld: feld)
    }

    /// Die Aufstellung ohne die Verteidigung.
    ///
    /// **Leere Liste heisst hier: Es stand keine da.** Der Aufrufer
    /// unterscheidet das -- „Es steht keine Defense auf dem Feld" ist
    /// eine Auskunft, ein lautloses Nichts wäre keine.
    static func ohneDefense(_ zeichnung: Zeichnung) -> [Zeichnung.Spieler] {
        zeichnung.spieler.filter { $0.seite != .defense }
    }

    static func hatDefense(_ zeichnung: Zeichnung) -> Bool {
        zeichnung.spieler.contains { $0.seite == .defense }
    }
}
