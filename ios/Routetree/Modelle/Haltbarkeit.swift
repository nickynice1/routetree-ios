// ERZEUGT VON scripts/teamcode_swift.py. NICHT VON HAND ÄNDERN.
//
// Die Quelle ist backend/designer/teamcode.py -- dieselbe Liste, aus der
// `Teamcode.anlegen` das Ablaufdatum rechnet. Die Werte unten hat der
// SERVER geliefert, nicht ein Mensch abgeschrieben.
//
// Warum das erzeugt wird und nicht getippt: Die Voreinstellung ist
// `24h` und ausdrücklich NICHT „unbegrenzt". Wer die neun
// Spannen von Hand überträgt, hat irgendwann eine Reihenfolge, in der
// „unbegrenzt" oben steht -- und das ist die Wahl, die man trifft, ohne
// hinzusehen.
//
// Neu erzeugen:  ./scripts/teamcode_swift.py
// Geprüft von:   backend/designer/test_teamcode_swift.py

import Foundation

/// Wie lange ein Teamcode gilt. `minuten == nil` heißt unbegrenzt.
struct Haltbarkeit: Identifiable, Hashable {
    let wert: String
    let text: String
    /// `nil` heißt unbegrenzt -- NICHT „null Minuten".
    let minuten: Int?

    var id: String { wert }
    var unbegrenzt: Bool { minuten == nil }
}

enum Haltbarkeiten {

    /// Die neun Spannen aus dem Auftrag (A4), in dieser Reihenfolge.
    static let alle: [Haltbarkeit] = [
        Haltbarkeit(wert: "10min",
                    text: String(localized: "10 Minuten"),
                    minuten: 10),
        Haltbarkeit(wert: "1h",
                    text: String(localized: "1 Stunde"),
                    minuten: 60),
        Haltbarkeit(wert: "12h",
                    text: String(localized: "12 Stunden"),
                    minuten: 720),
        Haltbarkeit(wert: "24h",
                    text: String(localized: "24 Stunden"),
                    minuten: 1440),
        Haltbarkeit(wert: "48h",
                    text: String(localized: "48 Stunden"),
                    minuten: 2880),
        Haltbarkeit(wert: "7t",
                    text: String(localized: "7 Tage"),
                    minuten: 10080),
        Haltbarkeit(wert: "1monat",
                    text: String(localized: "1 Monat"),
                    minuten: 43200),
        Haltbarkeit(wert: "1jahr",
                    text: String(localized: "1 Jahr"),
                    minuten: 525600),
        Haltbarkeit(wert: "unbegrenzt",
                    text: String(localized: "unbegrenzt"),
                    minuten: nil),
    ]

    /// Was vorgewählt ist. Die harmlose Wahl, nicht die bequeme.
    static let vorgabe = "24h"

    /// Die Spanne zu einem Wert, sonst die Vorgabe. Nie `nil`: Ein
    /// Auswahlfeld ohne Auswahl gibt es nicht.
    static func mit(wert: String) -> Haltbarkeit {
        alle.first { $0.wert == wert }
            ?? alle.first { $0.wert == vorgabe }!
    }
}
