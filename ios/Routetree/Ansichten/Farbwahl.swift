import SwiftUI

/// Eine Farbe wählen: Feld, Tupfer, Vorschau.
///
/// **Warum das eine eigene Ansicht ist.** Seit B9 wird an zwei Stellen
/// eine Farbe gewählt: bei einer Kategorie (B7) und bei einer
/// Mannschaft. Zweimal dieselben dreißig Zeilen liefen beim nächsten
/// Vorschlag auseinander, und der Unterschied sähe nicht falsch aus,
/// sondern nach zwei verschiedenen Paletten.
///
/// Die Palette selbst steht in `Farbvorschlaege.swift`, erzeugt aus dem
/// Server (`scripts/farben_swift.py`). Hier wird nichts entschieden,
/// was eine Farbe ist -- das sagt `Farbwert`, und der ist gegen den
/// Server gemessen.
struct Farbwahl: View {
    @Binding var farbe: String

    private var geprueft: Farbwert.Ergebnis { Farbwert.pruefen(farbe) }

    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(Farbvorschlaege.farbe(farbe))
                .frame(width: 26, height: 26)
                .overlay(Circle().stroke(Farben.linie, lineWidth: 1))
                .accessibilityHidden(true)
            TextField("#1A5364", text: $farbe)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
        }
        tupferzeile
    }

    /// Die acht Tupfer aus dem Browser, erzeugt und nicht getippt.
    private var tupferzeile: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(Farbvorschlaege.alle, id: \.self) { wert in
                    // Verglichen wird über `Farbwert.gleich`: Die
                    // Vorschläge stehen groß geschrieben, gespeichert
                    // wird klein. Ein Vergleich Zeichen für Zeichen
                    // zeigte den gewählten Tupfer nach dem Sichern als
                    // nicht gewählt.
                    let gewaehlt = Farbwert.gleich(wert, geprueft.wert)
                    Button {
                        farbe = wert
                    } label: {
                        Circle()
                            .fill(Farbvorschlaege.farbe(wert))
                            .frame(width: 30, height: 30)
                            .overlay(Circle().stroke(
                                gewaehlt ? Farben.ink : Farben.linie,
                                lineWidth: gewaehlt ? 2.5 : 1))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Farbe \(wert) wählen")
                    .accessibilityAddTraits(gewaehlt ? [.isSelected] : [])
                }
            }
            .padding(.vertical, 4)
        }
    }
}
