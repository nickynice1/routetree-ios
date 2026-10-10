// ERZEUGT VON scripts/positionsfarben_swift.py. NICHT VON HAND ÄNDERN.
//
// Die Quelle ist backend/designer/schema.py (POSITION_COLORS). Wer hier
// etwas ändert, ändert es nur in der App -- und bietet damit einen Ton
// an, den niemand gegen Bildschirm UND Papier geprüft hat.
//
// Neu erzeugen:  ./scripts/positionsfarben_swift.py
// Geprüft von:   backend/designer/test_positionsfarben_swift.py

import Foundation

/// Eine Farbe, die eine Figur tragen kann.
///
/// Ausgewählt so, dass sie auf dunklem Bildschirm und auf weißem
/// Papier lesbar bleibt: Der Editor ist dunkel, der Ausdruck ist es nie.
///
/// **Hier steht kein `Color`.** Aus dem Hexwert eine Farbe zu machen ist
/// eine Entscheidung, und die fällt an EINER Stelle:
/// `Feldansicht.figurfarbe`. Sie kennt auch den Fall „keine eigene
/// Farbe", der hier gar nicht auftauchen kann.
struct Positionsfarbe: Identifiable, Hashable {

    /// Der gespeicherte Wert. Leer heißt „Standard" -- also die Farbe,
    /// die sich aus der Seite ergibt, und NICHT Grau: Was ohne Farbe
    /// gezeichnet wird, ist nicht farblos, sondern normal.
    let wert: String
    /// Wie sie heißt.
    let name: String

    var id: String { wert }
}

extension Positionsfarbe {

    /// Alle Farben, in der Reihenfolge des Servers.
    static let alle: [Positionsfarbe] = [
        Positionsfarbe(wert: "",
                       name: String(localized: "Standard")),
        Positionsfarbe(wert: "#C24132",
                       name: String(localized: "Ziegel")),
        Positionsfarbe(wert: "#C77B38",
                       name: String(localized: "Kupfer")),
        Positionsfarbe(wert: "#8F7222",
                       name: String(localized: "Gold")),
        Positionsfarbe(wert: "#8D8F56",
                       name: String(localized: "Oliv")),
        Positionsfarbe(wert: "#5D9928",
                       name: String(localized: "Laub")),
        Positionsfarbe(wert: "#239432",
                       name: String(localized: "Grün")),
        Positionsfarbe(wert: "#299E73",
                       name: String(localized: "Smaragd")),
        Positionsfarbe(wert: "#00999E",
                       name: String(localized: "Türkis")),
        Positionsfarbe(wert: "#3095C7",
                       name: String(localized: "Petrol")),
        Positionsfarbe(wert: "#4287FF",
                       name: String(localized: "Stahlblau")),
        Positionsfarbe(wert: "#6B59C2",
                       name: String(localized: "Indigo")),
        Positionsfarbe(wert: "#9E3AE0",
                       name: String(localized: "Violett")),
        Positionsfarbe(wert: "#BD31AF",
                       name: String(localized: "Beere")),
        Positionsfarbe(wert: "#BD3172",
                       name: String(localized: "Himbeere")),
        Positionsfarbe(wert: "#6B7480",
                       name: String(localized: "Grau")),
    ]

    /// Der Name zu einem gespeicherten Wert, sonst der Wert selbst.
    ///
    /// Der Wert selbst und nicht etwa nichts: Ein leeres Feld sähe aus
    /// wie ein Fehler. Steht dort „#123456", weiß wenigstens jemand,
    /// wonach er suchen muss.
    static func name(fuer wert: String?) -> String {
        let gesucht = wert ?? ""
        return alle.first { $0.wert == gesucht }?.name ?? gesucht
    }
}
