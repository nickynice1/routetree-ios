// ERZEUGT VON scripts/farben_swift.py. NICHT VON HAND ÄNDERN.
//
// Die Quelle ist backend/designer/farben.py -- dieselben acht Tupfer,
// die auch die Kategorieseite im Browser anbietet, und derselbe
// Standard.
//
// Neu erzeugen:  ./scripts/farben_swift.py
// Geprüft von:   backend/designer/test_farben_swift.py (Gleichstand)

import SwiftUI

/// Die Farben, die beim Anlegen einer Kategorie zur Wahl stehen.
///
/// Ein Angebot, keine Auswahlliste: Wer eine Vereinsfarbe hat, tippt sie
/// als Hexwert ein. Die Tupfer sind für alle anderen da.
enum Farbvorschlaege {

    /// Womit eine Kategorie anfängt, wenn niemand etwas sagt.
    static let standard = "#1A5364"

    /// Die acht Vorschläge, in der Reihenfolge des Browsers.
    static let alle: [String] = [
        "#1A5364",
        "#2E7D96",
        "#9C6310",
        "#C8871F",
        "#8E3320",
        "#B4472F",
        "#3F8F5C",
        "#7D5BA6",
    ]

    /// Ein Hexwert als `Color`, zum Zeichnen des Punktes.
    ///
    /// Ungültiges ergibt Grau und nicht etwa gar nichts: Ein Punkt, der
    /// verschwindet, sieht aus wie ein Fehler der Liste. Was gültig ist,
    /// entscheidet `Farbwert` -- hier wird nur noch gezeichnet.
    static func farbe(_ hex: String) -> Color {
        guard let wert = Farbwert.pruefen(hex).wert,
              let zahl = Int(wert.dropFirst(), radix: 16) else {
            return Color(white: 0.45)
        }
        return Color(red: Double((zahl >> 16) & 0xFF) / 255,
                     green: Double((zahl >> 8) & 0xFF) / 255,
                     blue: Double(zahl & 0xFF) / 255)
    }
}
