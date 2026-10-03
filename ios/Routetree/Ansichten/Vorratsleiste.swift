import SwiftUI

/// Die Leiste über einer Ansicht, die gerade vom Gerät kommt (R14).
///
/// **Warum sie sein MUSS und nicht bloß nett ist.** Eine alte
/// Aufstellung ohne Hinweis ist schlimmer als eine Fehlermeldung: Der
/// Trainer am Spielfeldrand liest sie und hält sie für die von heute.
/// Der Vorrat darf deshalb nur bestehen, solange er sich zu erkennen
/// gibt -- `Vorratsblock.Ausgabe` reicht den Zeitpunkt genau dafür bis
/// hierher durch.
///
/// **Was hier NICHT entschieden wird:** wie alt „alt" ist. Die drei
/// Stufen stehen in `Vorratsblock.naehe` und werden dort gemessen. Hier
/// steht nur der Satz dazu.
struct Vorratsleiste: View {
    let stand: Date
    /// Nur zum Messen: Sonst ließe sich der Satz nur an einem Gerät
    /// ansehen, dessen Uhr gerade richtig steht.
    var jetzt: Date = Date()

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "wifi.slash")
                .font(.footnote)
            Text(satz)
                .font(.footnote)
            Spacer(minLength: 0)
        }
        .foregroundStyle(Farben.inkLeise)
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity)
        .background(Farben.flaechePanel)
        .overlay(alignment: .bottom) {
            Rectangle().fill(Farben.linie).frame(height: 1)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(satz)
    }

    /// „Ohne Netz · Stand von heute, 18:42".
    ///
    /// Die Uhrzeit steht dabei, und zwar auch bei „heute": Wer um 19
    /// Uhr am Platz steht, will wissen, ob die Kopie von 18:40 oder von
    /// heute früh ist.
    private var satz: String {
        let uhr = stand.formatted(date: .omitted, time: .shortened)
        switch Vorratsblock.naehe(stand, jetzt: jetzt) {
        case .heute:
            return String(localized: "Ohne Netz · Stand von heute, \(uhr)")
        case .gestern:
            return String(localized: "Ohne Netz · Stand von gestern, \(uhr)")
        case .aelter:
            let tag = stand.formatted(date: .abbreviated, time: .omitted)
            return String(localized: "Ohne Netz · Stand vom \(tag), \(uhr)")
        }
    }
}
