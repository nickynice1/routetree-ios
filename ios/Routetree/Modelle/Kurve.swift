// Die weiche Verbindung von Stützpunkten -- dieselbe Rechnung wie im
// Ausdruck und im Browser.
//
// **Warum diese Datei entstanden ist** (R7/R12, 25.08.2026). Die App
// konnte gebogene Linien anzeigen, aber mit einer EIGENEN, einfacheren
// Rechnung: eine Kette quadratischer Bögen durch die Mittelpunkte. Der
// Server zeichnet zentripetales Catmull-Rom. Beide gehen durch dieselben
// Stützpunkte, aber dazwischen laufen sie auseinander -- und genau
// dazwischen liegt bei einer Wheel Route die Route.
//
// Eine Wheel läuft flach nach außen und dann in einem Bogen nach oben.
// Der Bogen IST die Information. Sieht er auf dem Handy anders aus als
// auf dem Ausdruck, dann läuft der Spieler etwas anderes als der
// Trainer gezeichnet hat, und keiner von beiden merkt es.
//
// Die dritte Fassung steht in `backend/static/designer/editor.js`
// (`bezierStuetzen`), die erste in `backend/designer/render.py`
// (`_catmull_rom_to_bezier`). Das ist die Quelle.
//
// Geprüft von:  ios/RoutetreeTests/KurveTests.swift gegen
//               ios/RoutetreeTests/KurveProben.swift (aus Python erzeugt)
//               und backend/designer/test_kurve_swift.py

import Foundation
import SwiftUI

enum Kurve {

    /// Zentripetale Parametrisierung.
    ///
    /// Der Wert steht dreimal: hier, als `CATMULL_ROM_ALPHA` in
    /// `render.py` und als `ALPHA` in `editor.js`. `test_kurve_swift.py`
    /// misst alle drei gegeneinander -- läuft einer weg, biegt eine
    /// Fassung anders als die andere.
    ///
    /// Mit 0.5 laufen Routen bei scharfen Richtungswechseln nicht in
    /// Schlaufen aus. Bei der gleichförmigen Variante (0.0) tun sie das,
    /// was bei einer Comeback-Route sofort sichtbar wird.
    static let alpha = 0.5

    /// Die beiden Bezier-Stützpunkte für das Segment `p1`–`p2`.
    ///
    /// `p0` und `p3` sind die Nachbarn davor und dahinter; an den Enden
    /// wird der Randpunkt auf sich selbst gespiegelt, damit Anfang und
    /// Ende nicht ausreißen. Wortgleich zu `_catmull_rom_to_bezier`.
    static func stuetzen(_ p0: CGPoint, _ p1: CGPoint,
                         _ p2: CGPoint, _ p3: CGPoint) -> (CGPoint, CGPoint) {
        func abstand(_ a: CGPoint, _ b: CGPoint) -> Double {
            Double(hypot(b.x - a.x, b.y - a.y))
        }

        let d1 = pow(abstand(p0, p1), alpha)
        let d2 = pow(abstand(p1, p2), alpha)
        let d3 = pow(abstand(p2, p3), alpha)

        // Fallen Punkte zusammen, wäre die Division nicht definiert. Dann
        // ist die gerade Verbindung die richtige Antwort.
        var b1 = p1
        if d1 >= 1e-9 && d2 >= 1e-9 {
            let d1_2 = d1 * d1, d2_2 = d2 * d2
            let nenner = 3.0 * d1 * (d1 + d2)
            b1 = CGPoint(
                x: (d1_2 * Double(p2.x) - d2_2 * Double(p0.x)
                    + (2 * d1_2 + 3 * d1 * d2 + d2_2) * Double(p1.x)) / nenner,
                y: (d1_2 * Double(p2.y) - d2_2 * Double(p0.y)
                    + (2 * d1_2 + 3 * d1 * d2 + d2_2) * Double(p1.y)) / nenner)
        }

        var b2 = p2
        if d3 >= 1e-9 && d2 >= 1e-9 {
            let d3_2 = d3 * d3, d2_2 = d2 * d2
            let nenner = 3.0 * d3 * (d3 + d2)
            b2 = CGPoint(
                x: (d3_2 * Double(p1.x) - d2_2 * Double(p3.x)
                    + (2 * d3_2 + 3 * d3 * d2 + d2_2) * Double(p2.x)) / nenner,
                y: (d3_2 * Double(p1.y) - d2_2 * Double(p3.y)
                    + (2 * d3_2 + 3 * d3 * d2 + d2_2) * Double(p2.y)) / nenner)
        }

        return (b1, b2)
    }

    /// Der ganze Weg durch die Punkte, weich oder eckig.
    ///
    /// Bei weniger als drei Punkten gibt es nichts zu runden: Durch zwei
    /// Punkte geht genau eine Gerade. `render.py` und `editor.js`
    /// entscheiden an derselben Stelle genauso.
    ///
    /// **`geschlossen` ist eine Zone, und dort gibt es keine Ränder**
    /// (R8, 26.08.2026). Der Weg läuft rundum, also sind die Nachbarn
    /// RINGSUM zu nehmen: vor dem ersten Punkt liegt der letzte, hinter
    /// dem letzten der erste. Bis dahin stand hier dieselbe Spiegelung
    /// wie bei einer Route -- damit blieben die erste und die letzte
    /// Ecke ein Knick, während die dazwischen rund waren, und die
    /// Schlusskante war eine Gerade. Das sieht nicht nach einer runden
    /// Zone aus, sondern nach einem Fehler.
    static func pfad(_ punkte: [CGPoint], weich: Bool,
                     geschlossen: Bool = false) -> Path {
        var pfad = Path()
        guard let erster = punkte.first else { return pfad }
        // Ein Ring braucht drei Ecken. Mit zweien wäre er eine Strecke
        // hin und zurück, und `render.py` gibt dafür gar nichts aus.
        if geschlossen && punkte.count < 3 { return pfad }
        pfad.move(to: erster)

        let n = punkte.count
        if !weich || n == 2 {
            for punkt in punkte.dropFirst() { pfad.addLine(to: punkt) }
        } else {
            let segmente = geschlossen ? n : n - 1
            for i in 0..<segmente {
                let p1: CGPoint, p2: CGPoint, p0: CGPoint, p3: CGPoint
                if geschlossen {
                    p0 = punkte[(i - 1 + n) % n]
                    p1 = punkte[i]
                    p2 = punkte[(i + 1) % n]
                    p3 = punkte[(i + 2) % n]
                } else {
                    p1 = punkte[i]
                    p2 = punkte[i + 1]
                    p0 = i - 1 >= 0 ? punkte[i - 1] : p1
                    p3 = i + 2 < n ? punkte[i + 2] : p2
                }
                let (b1, b2) = stuetzen(p0, p1, p2, p3)
                pfad.addCurve(to: p2, control1: b1, control2: b2)
            }
        }

        if geschlossen { pfad.closeSubpath() }
        return pfad
    }
}

/// Wo die Beschriftung einer Linie steht (R25).
///
/// **Dieselbe Rechnung wie `_label_stelle` in `render.py`**, und das ist
/// keine Bequemlichkeit: Wer im Editor „Go" eintippt, sieht es auf dem
/// Gerät und auf dem Ausdruck. Stünde es an zwei verschiedenen Stellen,
/// wäre die Frage, welche stimmt -- und am Spielfeldrand liegt beides
/// nebeneinander.
///
/// Die Beschriftung sitzt HINTER der Spitze, nicht darauf: Die letzte
/// Teilstrecke wird um `abstand` verlängert. Auf der Spitze läge sie
/// über dem Pfeil.
///
/// **Beide Rechnungen geben die MITTE des Textes zurück, nicht seine
/// Grundlinie.** Das ist der Unterschied zwischen SVG und `GraphicsContext`
/// und keine Kleinigkeit: Ein `<text y="…">` hängt an seiner Grundlinie,
/// `grund.draw(…, anchor: .center)` an seiner Mitte. `render.py` schiebt
/// den Zonennamen deshalb um `LABEL_MITTE` nach unten -- wer dieselbe
/// Zeichnung ohne diese Umrechnung zeichnet, setzt die Beschriftung einer
/// Route eine halbe Zeilenhöhe zu tief.
enum Beschriftungsstelle {

    /// Wie weit hinter der Spitze, in BILDEINHEITEN.
    ///
    /// **Die Zahl steht in `render.py` als `LABEL_OFFSET`**, und
    /// `test_beschriftung_swift.py` vergleicht beide. Weicht eine ab,
    /// wird die Prüfung rot -- eine zweite Zahl über denselben Abstand
    /// fällt sonst erst auf, wenn jemand Papier und Gerät nebeneinander
    /// legt.
    static let abstand: Double = 9.0

    /// Halbe Versalhöhe der Beschriftung, in Bildeinheiten. Steht in
    /// `render.py` als `LABEL_MITTE`.
    static let grundlinie: Double = 2.5

    /// Wo die Mitte der Beschriftung einer Linie liegt.
    ///
    /// **`faktor` ist Pflicht und hat keinen Vorgabewert**, und das ist
    /// die Lehre aus dem Fehler, mit dem diese Datei angefangen hat: Die
    /// Punkte, die hier hereinkommen, sind BILDSCHIRMPUNKTE -- schon mit
    /// dem Faktor gestreckt (`Feldansicht` rechnet sie über `auf(_:_:)`
    /// aus). `abstand` steht dagegen in Bildeinheiten, wie jede andere
    /// Zahl aus `render.py`. Wer ihn ungestreckt draufrechnet, bekommt
    /// auf dem iPhone knapp daneben und auf dem iPad die Beschriftung
    /// mitten in der Pfeilspitze -- und zwar ohne dass irgendeine
    /// Prüfung anschlägt, die nur die ZAHL vergleicht.
    ///
    /// Bei einer Linie ohne Länge fällt sie auf den Punkt selbst
    /// zurück -- wie im Browser.
    static func fuer(_ punkte: [CGPoint], faktor: Double) -> CGPoint? {
        guard let ende = punkte.last else { return nil }
        guard punkte.count >= 2 else { return hoch(ende, faktor: faktor) }
        let dx = ende.x - punkte[punkte.count - 2].x
        let dy = ende.y - punkte[punkte.count - 2].y
        let laenge = (dx * dx + dy * dy).squareRoot()
        guard laenge >= 0.001 else { return hoch(ende, faktor: faktor) }
        return hoch(CGPoint(x: ende.x + dx / laenge * abstand * faktor,
                            y: ende.y + dy / laenge * abstand * faktor),
                    faktor: faktor)
    }

    /// Bei einer Zone: die Mitte der Fläche.
    ///
    /// `render.py` nimmt dort den Schwerpunkt der Stützpunkte, nicht
    /// die Mitte des umschließenden Rechtecks -- bei einem Ring liegt
    /// beides auseinander.
    ///
    /// **Ohne `faktor`, und das ist Absicht:** Ein Schwerpunkt ist
    /// maßstabsfrei, hier gibt es nichts umzurechnen. Der Unterschied zur
    /// Signatur von `fuer` ist die kürzeste Fassung der Begründung oben.
    static func mitte(_ punkte: [CGPoint]) -> CGPoint? {
        guard !punkte.isEmpty else { return nil }
        let x = punkte.reduce(0.0) { $0 + $1.x } / Double(punkte.count)
        let y = punkte.reduce(0.0) { $0 + $1.y } / Double(punkte.count)
        return CGPoint(x: x, y: y)
    }

    /// Von der Grundlinie auf die Mitte. Im Bild wächst y nach unten,
    /// also liegt die Mitte ÜBER der Grundlinie.
    private static func hoch(_ punkt: CGPoint, faktor: Double) -> CGPoint {
        CGPoint(x: punkt.x, y: punkt.y - grundlinie * faktor)
    }
}
