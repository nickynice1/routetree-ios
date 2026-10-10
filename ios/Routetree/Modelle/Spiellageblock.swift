import Foundation

/// Was die Lage des Balls bedeutet (R110.3).
///
/// **Warum das hier steht und nicht in der Ansicht.** Es gibt keinen
/// Mac. Eine Regel in einer SwiftUI-Ansicht lässt sich nicht
/// ausprobieren, sondern nur behaupten, und die Rückmeldung vom Läufer
/// dauert eine halbe Stunde. Dieselbe Entscheidung wie bei
/// `Zeichenblock` (B4), `Kaderblock` (B9) und `Stufenblock` (R117).
///
/// **Die Sätze sind dieselben wie im Browser** (`situationAktualisieren`
/// in `editor.js`). Zwei Fassungen wären zwei Auskünfte über dieselbe
/// Lage -- und ein Trainer, der am Rechner plant und am Telefon
/// korrigiert, läse zweimal etwas anderes.
enum Spiellageblock {

    /// Was über eine Lage zu sagen ist.
    struct Lage: Equatable {
        /// „Mittellinie" oder „32-Yard-Linie".
        let ort: String
        /// Der ganze Satz darunter: welche Endzone, wie weit bis zur
        /// Line to Gain, und ob hier gepasst werden muss.
        let satz: String
        /// „Ziel: rechts" oder „Ziel: links".
        let richtungstext: String
        /// Liegt der Ball in einer No-Run-Zone?
        let inKeinLaufZone: Bool
    }

    static func lage(los: Double, richtung: Int, feld: Feld) -> Lage {
        // DIE YARD-ZAHL IST DIE KLEINERE VON BEIDEN SEITEN. Auf einem
        // Footballfeld zählt man von der nächsten Torlinie: Die
        // 32-Yard-Linie gibt es zweimal, und welche gemeint ist, sagt
        // die Richtung.
        // GERUNDET IN EINE EIGENE VARIABLE. Nicht aus Umständlichkeit:
        // `appsprache.py` liest die Interpolationen aus dem Quelltext
        // und schlägt jeden Ausdruck in einer Liste nach -- geraten
        // wird dort nichts, weil ein falscher Platzhalter sich
        // nirgends zeigt ausser auf einem fremdsprachigen Telefon. Ein
        // `\(Int(yard.rounded()))` mitten im Satz ist kein Name,
        // sondern eine Rechnung; `yardzahl` ist einer.
        let yardzahl = Int(min(los - feld.torlinieLinks,
                               feld.torlinieRechts - los).rounded())
        let aufDerMitte = abs(los - feld.mitte) < 0.01
        let ort = aufDerMitte
            ? String(localized: "Mittellinie")
            : String(localized: "\(yardzahl)-Yard-Linie")

        let zielLinks = richtung < 0
        var satz = zielLinks
            ? String(localized: "Ihr greift die linke Endzone an. ")
            : String(localized: "Ihr greift die rechte Endzone an. ")

        let bisMitte = abs(feld.mitte - los)
        let ueberMitte = zielLinks ? los < feld.mitte : los > feld.mitte
        if bisMitte < 0.01 {
            satz += String(localized:
                "Der Ball liegt genau auf der Line to Gain.")
        } else if ueberMitte {
            satz += String(localized: """
                Die Mittellinie ist schon überquert, von hier zählt nur \
                noch die Endzone.
                """)
        } else {
            let yardsBisMitte = Int(bisMitte.rounded())
            satz += String(localized:
                "Bis zur Line to Gain sind es \(yardsBisMitte) Yards.")
        }

        // NUR WO ES DIE ZONE GIBT. Im Elfer-Tackle ist `keinLauf` null,
        // und dann liegt jeder Ball rechnerisch „in" ihr -- ein Satz
        // über eine Regel, die es dort nicht gibt, ist schlimmer als
        // keiner (dieselbe Überlegung wie bei den Situationen, R110.8).
        let inZone = feld.keinLauf > 0
            && (los < feld.keinLaufLinks || los > feld.keinLaufRechts)
        if inZone {
            satz += String(localized:
                " Achtung: No-Run-Zone, hier muss gepasst werden.")
        }

        return Lage(ort: ort, satz: satz,
                    richtungstext: richtung > 0
                        ? String(localized: "Ziel: rechts")
                        : String(localized: "Ziel: links"),
                    inKeinLaufZone: inZone)
    }
}
