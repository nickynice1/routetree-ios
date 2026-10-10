import SwiftUI

#if canImport(UIKit)
import UIKit
#endif

/// Eine echte kleine Zeichnung der Linienart -- als Bild, nicht als Wort.
///
/// **Woher der Punkt kommt (R90).** Niklas am 09.09.2026, mit einem Bild
/// des offenen Menüs: „Das gefällt mir nicht so ganz 1. sieht man nicht
/// wie die Routen dann aussehen also so Vorschau mäßig. Zweitens ist das
/// Menü jetzt nicht wirklich erkennbar hast da noch andere Ideen".
///
/// Er hat recht: „Abschirmen" und „Passweg" sind Wörter. Wer den Editor
/// zum ersten Mal aufmacht, weiß nicht, dass das eine mit einem
/// Querstrich endet und das andere gepunktet ist. Im Ausdruck steht der
/// Unterschied, in der Auswahl stand er nicht.
///
/// **Warum ein `UIImage` und kein SwiftUI-Canvas.** Ein Menü in iOS ist
/// am Ende ein `UIMenu`, und ein Eintrag darin trägt genau zweierlei:
/// einen Titel und ein BILD. Eine gezeichnete Ansicht als Beschriftung
/// wird dabei plattgemacht -- übrig bliebe der Text. Ein gerendertes
/// Bild kommt durch.
///
/// **Eine Zeichenroutine für beide Stellen.** Der zugeklappte Knopf zeigt
/// dasselbe Bild wie der Eintrag im Menü. Zwei Zeichnungen desselben
/// Strichs wären zwei Gelegenheiten, ihn verschieden zu zeichnen.
enum Linienbild {

    /// Wie gross die Probe wird. Breit genug für zwei Striche eines
    /// gestrichelten Musters -- bei zwanzig Punkten sähe „Motion" aus
    /// wie „Route".
    static let breite: CGFloat = 34
    static let hoehe: CGFloat = 12

    #if canImport(UIKit)
    /// Gerenderte Bilder liegen bereit, statt bei jedem Aufbau der
    /// Ansicht neu zu entstehen. Es sind sieben Stück von 34 mal 12
    /// Punkten; sie einmal zu zeichnen kostet weniger als sie
    /// wegzuwerfen.
    private static var vorrat: [Zeichnung.Linie.Art: UIImage] = [:]

    static func bild(fuer art: Zeichnung.Linie.Art) -> UIImage {
        if let fertig = vorrat[art] { return fertig }
        let stil = art.stil
        let farbe = UIColor(Feldansicht.farbe(fuer: stil.farbe))
        let zeichner = UIGraphicsImageRenderer(
            size: CGSize(width: breite, height: hoehe))
        let bild = zeichner.image { lage in
            let c = lage.cgContext
            let mitte = hoehe / 2
            // Platz für die Spitze am Ende, wie in der Feldansicht.
            let ende = breite - (stil.standardEnde == .none ? 0 : 6)
            c.setStrokeColor(farbe.cgColor)
            c.setLineWidth(2)
            c.setLineCap(.round)
            if let strich = stil.strich, !strich.isEmpty {
                // Dieselben Zahlen wie im SVG des Servers, halbiert:
                // Die Probe ist ein Drittel so lang wie ein Laufweg auf
                // dem Feld, und ein unverkleinertes Muster ergäbe darin
                // einen einzigen Strich.
                c.setLineDash(phase: 0, lengths: strich.map { $0 * 0.5 })
            }
            c.move(to: CGPoint(x: 1, y: mitte))
            c.addLine(to: CGPoint(x: ende, y: mitte))
            c.strokePath()

            c.setLineDash(phase: 0, lengths: [])
            switch stil.standardEnde {
            case .arrow:
                c.setFillColor(farbe.cgColor)
                c.move(to: CGPoint(x: breite - 1, y: mitte))
                c.addLine(to: CGPoint(x: ende - 1, y: mitte - 3.5))
                c.addLine(to: CGPoint(x: ende - 1, y: mitte + 3.5))
                c.closePath()
                c.fillPath()
            case .tee:
                c.move(to: CGPoint(x: ende, y: mitte - 4.5))
                c.addLine(to: CGPoint(x: ende, y: mitte + 4.5))
                c.strokePath()
            case .none:
                break
            }
        }
        // ALS ORIGINAL UND NICHT ALS SCHABLONE. Ein Menü färbt seine
        // Zeichen sonst alle in der Akzentfarbe ein -- und damit wäre
        // der Passweg nicht mehr golden, sondern sähe aus wie eine
        // Route. Genau der Unterschied, um den es hier geht.
        let fertig = bild.withRenderingMode(.alwaysOriginal)
        vorrat[art] = fertig
        return fertig
    }
    #endif
}

/// Eine kleine Probe der Linienart als Ansicht: Strich, Muster, Ende.
///
/// Dieselbe Aufgabe wie `linienProbe` im Browser. Ohne sie stünden in der
/// Leiste sechs Wörter, und welche Linie dabei herauskommt, wüsste man
/// erst nach dem Zeichnen.
struct Linienprobe: View {
    let art: Zeichnung.Linie.Art

    var body: some View {
        #if canImport(UIKit)
        Image(uiImage: Linienbild.bild(fuer: art))
            .accessibilityHidden(true)
        #else
        Rectangle()
            .frame(width: Linienbild.breite, height: 2)
            .accessibilityHidden(true)
        #endif
    }
}

/// Eine kleine Probe einer Spielerfigur: Kreis oder Viereck.
///
/// **Wofür.** Die Hilfe zeigt die Grundnotation als Legende (09.09.2026)
/// -- und zwar gezeichnet, nicht beschrieben: „rund gegen eckig" ist ein
/// Satz über zwei Formen, und wer zum ersten Mal ein Play liest, sucht
/// die Form im Diagramm.
///
/// **Aus derselben Quelle wie das Feld.** `Feldansicht.figurform`
/// zeichnet auch die echten Figuren. Eine zweite Zeichnung hier wäre
/// eine zweite Notation: Ändert sich die echte noch einmal -- und sie
/// hat sich am 09.09.2026 geändert, vom Kreuz zum Viereck --, erklärt
/// die Legende danach die alte.
///
/// Ohne Kürzel: In sechzehn Punkten ist ein Buchstabe ein Fleck, und um
/// die FORM geht es hier.
struct Spielerprobe: View {
    /// „off" oder „def", wie der Server sie schickt. Ein unbekannter
    /// Wert gilt als Defense -- das ist die Seite, die den Sonderfall
    /// hat, und ein Kreis für etwas Unbekanntes wäre die stillere
    /// Lüge.
    let seite: String

    private static let groesse: CGFloat = 22

    var body: some View {
        let radius = Double(Self.groesse) / 2
        let mitte = CGPoint(x: radius, y: radius)
        let welche: Zeichnung.Spieler.Seite = seite == "off" ? .offense
                                                             : .defense
        Canvas { grund, _ in
            let form = Feldansicht.figurform(seite: welche, mitte: mitte,
                                             radius: radius)
            grund.fill(form, with: .color(Farben.akzent))
            grund.stroke(form, with: .color(Farben.flaeche), lineWidth: 1.4)
        }
        .frame(width: Self.groesse, height: Self.groesse)
        .accessibilityHidden(true)
    }
}
