import SwiftUI

/// Der Passwort-Stärkebalken (R110.10).
///
/// **Vier Striche und kein durchlaufender Balken.** Ein Balken, der von
/// rot nach grün läuft, ist für eine Rot-Grün-Schwäche keine Auskunft.
/// Vier gefüllte Striche zählt man auch ohne Farbe -- dieselbe
/// Überlegung wie im ganzen Haus: Farbe ist nie die einzige
/// Information. Der Browser macht es seit R108 genauso.
///
/// **Über einem leeren Feld steht nichts.** Ein Balken, bevor jemand
/// angefangen hat, sieht aus wie ein Vorwurf.
///
/// **Gerechnet wird in `Passwortstaerke`** und nicht hier. Es gibt
/// keinen Mac; eine Regel in einer SwiftUI-Ansicht lässt sich nicht
/// ausprobieren, sondern nur behaupten.
struct Staerkebalken: View {

    let passwort: String
    /// Vom Server, nicht getippt: Eine Acht in Swift sagt „mindestens 8
    /// Zeichen", während der Server zwölf verlangt.
    let mindestlaenge: Int
    /// Benutzername, Namen, Mailadresse aus DEMSELBEN Formular. Leer,
    /// wo es sie nicht gibt (Passwort ändern).
    var umfeld: [String] = []

    private var stand: Passwortstaerke.Stand? {
        Passwortstaerke.bewerten(passwort, mindestens: mindestlaenge,
                                 umfeld: umfeld)
    }

    var body: some View {
        if let stand {
            HStack(spacing: 8) {
                HStack(spacing: 3) {
                    ForEach(0..<4, id: \.self) { i in
                        Capsule()
                            .fill(i < stand.stufe.striche
                                  ? farbe(stand.stufe) : Farben.linie)
                            .frame(height: 4)
                    }
                }
                .frame(maxWidth: 120)
                Text(stand.wort)
                    .font(.caption)
                    .foregroundStyle(stand.stufe.reicht
                                     ? Farben.inkStill : Farben.fehler)
                Spacer(minLength: 0)
            }
            .padding(.top, 2)
            // EINE ANSAGE UND NICHT VIER. Ohne das liest VoiceOver vier
            // namenlose Formen vor und danach ein Wort; mit `.combine`
            // wäre der Balken selbst der Inhalt. Was zählt, ist der
            // Stand, und der steht im Wort.
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text(String(localized: "Passwortstärke")))
            .accessibilityValue(Text(stand.wort))
        }
    }

    private func farbe(_ stufe: Passwortstaerke.Stufe) -> Color {
        switch stufe {
        case .zuKurz, .schwach: return Farben.fehler
        case .gehtSo: return Farben.gold
        case .gut, .stark: return Farben.akzent
        }
    }
}
