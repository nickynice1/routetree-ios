// Die Auflage auf dem Sucher (R142).
//
// **Niklas, 25.09.2026:** „die idee ist das wir beim kamera scan gleich
// los und 5y 10y linie auf seinem bildschirm einzeichnen. so können wir
// 1. gewährleisten das es kein schrägformat ist und 2. sehen wir gleich
// wie lang die routen sein sollen."
//
// Das ist mehr als eine Hilfslinie. Der Tiefenmaßstab -- wie viele Yard
// eine gezeichnete Strecke bedeutet -- lässt sich aus einem Blatt ohne
// Raster NICHT herleiten. Es ist keine schwierige Messung, es ist gar
// keine: Wer vier Routen auf einen Zettel kritzelt, hat die Auskunft
// nie hingeschrieben.
//
// Hier schreibt er sie hin, ohne es zu merken -- indem er sein Blatt an
// diese Linien legt.
//
// Gemessen am 25.09.2026 an einem gebauten Blatt mit vier Routen von
// 10, 15, 20 und 25 Yard, ohne LOS und ohne Raster:
//
//     geraten      13,3 / 20,2 / 27,2 / 34,1 yd   -> 36 Prozent daneben
//     mit Rahmen    9,6 / 14,6 / 19,6 / 24,6 yd   ->  4 Prozent

import SwiftUI

/// Wo die Linien liegen -- in Anteilen der Sucherhöhe und -breite.
///
/// **Anteile und keine Punkte.** Der Sucher ist auf einem SE anders
/// groß als auf einem Max, und das Bild, das am Ende hochgeht, hat
/// wieder eine dritte Größe. Ein Anteil überlebt jede Umrechnung;
/// ein Punktwert überlebt keine.
struct Rahmenlage: Equatable {

    /// Die Line of Scrimmage, von oben gezählt.
    var los: CGFloat = 0.62

    /// Der Abstand von der LOS zur Fünf-Yard-Linie.
    var fuenfYard: CGFloat = 0.11

    /// Wie breit das Feld ist, als Anteil der Sucherbreite.
    var breite: CGFloat = 0.86

    /// Die Vorgabe ist bewusst großzügig: Die meisten zeichnen ein
    /// Blatt quer voll und die Routen etwa halb so hoch wie breit.
    static let vorgabe = Rahmenlage()

    /// Was der Server davon braucht, in Bildpunkten des Fotos.
    ///
    /// **Der Sucher zeigt das Bild BESCHNITTEN, und das ist der
    /// schwierige Teil.** Die Vorschau läuft mit `resizeAspectFill`:
    /// Ein Foto im Format 3:4 wird in einen Sucher von etwa 9:19,5
    /// gelegt, an der Höhe ausgerichtet -- und links und rechts fällt
    /// etwas weg. Ein Anteil der SUCHERbreite ist deshalb nicht
    /// derselbe Anteil der BILDbreite.
    ///
    /// Genau daran hinge sonst der Quermaßstab: Die Länge der Line of
    /// Scrimmage sagt dem Leser, wie viele Yard die Feldbreite hat.
    /// Wer hier den Beschnitt vergisst, bekommt auf einem heutigen
    /// iPhone eine um rund ein Drittel zu breite Aufstellung -- und
    /// sie sähe völlig plausibel aus.
    ///
    /// Senkrecht stimmt es in diesem Fall zufällig, weil an der Höhe
    /// ausgerichtet wird. Gerechnet wird trotzdem für beide Achsen:
    /// Bei einem iPad ist es andersherum.
    ///
    /// **Die Umrechnung passiert hier und nicht auf dem Server.** Nur
    /// hier ist bekannt, wie der Sucher auf das Bild abgebildet wurde.
    func fuerServer(bildgroesse bild: CGSize,
                    sucher: CGSize) -> [String: String] {
        guard bild.width > 0, bild.height > 0,
              sucher.width > 0, sucher.height > 0 else {
            return [:]
        }
        // `aspectFill`: das Bild wird so vergrössert, dass es den
        // Sucher FÜLLT -- also nach der grösseren der beiden
        // Streckungen.
        let streckung = max(sucher.width / bild.width,
                            sucher.height / bild.height)
        // Wie viele Bildpunkte des Fotos im Sucher zu sehen sind.
        let sichtbar = CGSize(width: sucher.width / streckung,
                              height: sucher.height / streckung)
        // Der obere linke sichtbare Punkt im Bild.
        let obenLinks = CGPoint(x: (bild.width - sichtbar.width) / 2,
                                y: (bild.height - sichtbar.height) / 2)

        return [
            "los": String(format: "%.2f",
                          obenLinks.y + los * sichtbar.height),
            "yardabstand": String(format: "%.2f",
                                  fuenfYard * sichtbar.height),
            "losbreite": String(format: "%.2f", breite * sichtbar.width),
        ]
    }
}

/// Die Linien über dem Kamerabild.
struct Scanrahmen: View {

    let lage: Rahmenlage

    /// Wie weit der Scanner ist -- 0 bis 1. Während er läuft, tritt
    /// der Rahmen zurück: Dann geht es nicht mehr ums Ausrichten.
    var fortschritt: Double = 0

    var body: some View {
        GeometryReader { raum in
            let hoehe = raum.size.height
            let breite = raum.size.width
            let links = (breite - breite * lage.breite) / 2
            let rechts = breite - links
            let los = hoehe * lage.los
            let fuenf = hoehe * lage.fuenfYard

            ZStack {
                // Die Yard-Linien, von der LOS nach oben. Nur fünf und
                // zehn sind beschriftet -- mehr Text im Sucher liest
                // ohnehin niemand, während er ein Blatt gerade hält.
                ForEach(1..<5) { schritt in
                    let y = los - fuenf * CGFloat(schritt)
                    if y > 8 {
                        Yardlinie(y: y, von: links, bis: rechts,
                                  stark: schritt % 2 == 0,
                                  beschriftung: schritt <= 2
                                      ? "\(schritt * 5)" : nil)
                    }
                }
                // Und eine nach hinten, fürs Backfield.
                if los + fuenf < hoehe - 8 {
                    Yardlinie(y: los + fuenf, von: links, bis: rechts,
                              stark: false, beschriftung: nil)
                }

                // Die Line of Scrimmage -- die einzige durchgezogene.
                Path { stift in
                    stift.move(to: CGPoint(x: links, y: los))
                    stift.addLine(to: CGPoint(x: rechts, y: los))
                }
                .stroke(Color.white, lineWidth: 2.5)
                .shadow(color: .black.opacity(0.6), radius: 3)

                // Die Seitenlinien. Sie sagen, was „Feldbreite" heißt
                // -- ohne sie wäre die LOS nur ein Strich irgendwo.
                ForEach([links, rechts], id: \.self) { x in
                    Path { stift in
                        stift.move(to: CGPoint(x: x, y: 10))
                        stift.addLine(to: CGPoint(x: x, y: hoehe - 10))
                    }
                    .stroke(Color.white.opacity(0.75),
                            style: StrokeStyle(lineWidth: 1.5,
                                               dash: [6, 7]))
                }

                Text("LOS")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 1)
                    .background(Color.black.opacity(0.45),
                                in: Capsule())
                    .position(x: links + 22, y: los - 11)
            }
            .opacity(fortschritt > 0 ? 0.25 : 1)
            .animation(.easeInOut(duration: 0.4), value: fortschritt > 0)
        }
        .allowsHitTesting(false)
    }
}

private struct Yardlinie: View {

    let y: CGFloat
    let von: CGFloat
    let bis: CGFloat
    let stark: Bool
    let beschriftung: String?

    var body: some View {
        ZStack {
            Path { stift in
                stift.move(to: CGPoint(x: von, y: y))
                stift.addLine(to: CGPoint(x: bis, y: y))
            }
            .stroke(Color.white.opacity(stark ? 0.7 : 0.4),
                    style: StrokeStyle(lineWidth: stark ? 1.4 : 1,
                                       dash: [9, 8]))
            if let beschriftung {
                Text(beschriftung)
                    .font(.system(size: 10, weight: .medium,
                                  design: .rounded))
                    .foregroundStyle(.white.opacity(0.85))
                    .position(x: von + 13, y: y - 8)
            }
        }
    }
}
