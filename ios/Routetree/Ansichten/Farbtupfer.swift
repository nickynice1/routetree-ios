// Ein farbiger Punkt als Bild -- für ein Menü, das ihn sonst grau malte.
//
// WARUM EIN BILD UND KEIN `Circle()`. In einem SwiftUI-`Menu` zeichnet
// das System die Zeilen selbst und nimmt vom Inhalt nur Text und Symbol
// an; eine eigene Form daneben wird stillschweigend weggelassen. Und
// selbst ein `Image` färbt das Menü in seiner Akzentfarbe ein, solange
// es nicht ausdrücklich `.alwaysOriginal` heißt -- dann sähen alle
// sechzehn Punkte gleich aus, und der Punkt wäre keiner.
//
// Niklas am 02.09.2026 zum Farbmenü: „Hier gleich die Farbe mit
// anzeigen." Bis dahin trug nur der geschlossene Knopf einen Tupfer;
// wer das Menü öffnete, las fünfzehn Wörter und musste raten, welches
// Grün „Laub" ist und welches „Smaragd".

import SwiftUI
import UIKit

/// Malt den Punkt, der im Farbmenü neben dem Namen steht.
enum Farbtupfer {

    /// Kantenlänge in Punkten. Eine Menüzeile zeigt ihr Symbol in etwa
    /// dieser Größe; ein größeres Bild wird beschnitten, ein kleineres
    /// sitzt neben dem Text wie ein Staubkorn.
    static let mass: CGFloat = 16

    /// Der Punkt zu einer Farbe.
    ///
    /// Der Rand gehört dazu und ist keine Zierde: „Standard" auf der
    /// Defense ist ein sehr stilles Grau, und ohne Rand wäre auf einem
    /// hellen Menügrund nicht zu sehen, dass dort überhaupt etwas ist.
    static func bild(_ farbe: Color) -> UIImage {
        let kasten = CGSize(width: mass, height: mass)
        let maler = UIGraphicsImageRenderer(size: kasten)
        let bild = maler.image { zug in
            let rund = CGRect(origin: .zero, size: kasten)
                .insetBy(dx: 1, dy: 1)
            zug.cgContext.setFillColor(UIColor(farbe).cgColor)
            zug.cgContext.fillEllipse(in: rund)
            zug.cgContext.setStrokeColor(
                UIColor(Farben.linie).cgColor)
            zug.cgContext.setLineWidth(1)
            zug.cgContext.strokeEllipse(in: rund)
        }
        return bild.withRenderingMode(.alwaysOriginal)
    }
}
