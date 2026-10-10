// Die Griffe an einer fertigen Linie: welcher Stützpunkt liegt unter dem
// Finger, und welcher darf überhaupt angefasst werden?
//
// EIGENE DATEI AUS DEMSELBEN GRUND WIE `Kurve.swift`: Damit sich diese
// Entscheidung messen lässt. Es gibt keinen Mac; jede Swift-Zeile geht auf
// einen Läufer und kommt eine halbe Stunde später zurück. Eine Regel, die
// in einer SwiftUI-Geste steckt, lässt sich in dieser Zeit nicht messen,
// sondern nur behaupten.
//
// DIE QUELLE IST `backend/static/designer/griffe.js`. Zwei Fassungen
// derselben Regel laufen auseinander, und zwar dort, wo es weh tut: Auf
// dem Handy erwischt der Finger einen anderen Punkt als die Maus im
// Browser, und niemand kann sagen, warum. `scripts/griffe_swift.py` legt
// Proben ab, `GriffeTests.swift` rechnet sie nach, und `test_griffe.py`
// fährt dieselben Fälle unter Node durch das JavaScript.
//
// DER ANLASS: R11 (Niklas) und R5 (Cyell), 25.08.2026. Gemessen mit
// `scripts/_probe_griff.py`, bevor hier etwas entstand.

import CoreGraphics
import Foundation

/// Welcher Stützpunkt liegt unter dem Finger?
enum Griffe {

    /// Griffweite um einen Stützpunkt, in Bildschirmpunkten.
    ///
    /// Größer als im Browser (dort 12): Ein Finger ist kein Mauszeiger.
    /// Kleiner als `Zeichenblock.griff` (26) für eine Figur, denn ein
    /// Stützpunkt sitzt oft dicht neben der Figur, an der seine Linie
    /// hängt -- wäre er gleich groß, verdeckte einer den anderen.
    static let weite: Double = 22

    /// Der Stützpunkt unter dem Finger, als Stelle in `punkte`.
    ///
    /// `punkte`, `ziel` und `weite` müssen im GLEICHEN Maßraum liegen.
    /// `nil` heißt: keiner liegt nah genug.
    ///
    /// **Der nächste, nicht der erste.** Bei einer engen Ecke liegen zwei
    /// Stützpunkte übereinander; wer den ersten aus der Liste nimmt,
    /// lässt die Reihenfolge im Datensatz entscheiden, welchen Punkt der
    /// Finger erwischt -- und die sieht niemand.
    ///
    /// **`verankert`** heißt: Die Linie gehört einer Position, Punkt 0
    /// liegt auf der Figur und ist kein Griff. Zöge man ihn weg, begänne
    /// die Route in der Luft.
    static func naechster(_ punkte: [CGPoint], zu ziel: CGPoint,
                          weite: Double, verankert: Bool) -> Int? {
        var beste: Int?
        var kleinster = Double.infinity
        for (stelle, punkt) in punkte.enumerated() {
            if verankert && stelle == 0 { continue }
            let dx = Double(punkt.x - ziel.x)
            let dy = Double(punkt.y - ziel.y)
            let abstand = (dx * dx + dy * dy).squareRoot()
            guard abstand <= weite else { continue }
            // Streng kleiner: Bei genau gleichem Abstand bleibt der
            // früher gefundene stehen, wie im Browser.
            if abstand < kleinster {
                kleinster = abstand
                beste = stelle
            }
        }
        return beste
    }

    /// Darf dieser Punkt angefasst werden?
    static func istGriff(_ stelle: Int, von anzahl: Int,
                         verankert: Bool) -> Bool {
        guard stelle >= 0, stelle < anzahl else { return false }
        return !(verankert && stelle == 0)
    }
}
