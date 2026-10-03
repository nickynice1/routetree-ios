// Die Farben der Uhr (R140).
//
// **ABGELEITET, NICHT NEU ERFUNDEN.** Jede Farbe hier kommt aus
// `Farben` -- und die wird aus `backend/static/designer/app.css`
// erzeugt. Eine eigene Palette für die Uhr wäre eine vierte Wahrheit
// neben Web, Telefon und Ausdruck, und sie liefe beim nächsten
// Farbwechsel auseinander, ohne dass es jemandem auffiele.
//
// Was die Uhr eigenes hat, sind nicht andere Farben, sondern andere
// KONTRASTE: Der Bildschirm ist klein, oft im Sonnenlicht, und er wird
// im Vorbeigehen gelesen. Deshalb sitzen hier ein paar bewusste
// Abweichungen -- jede einzeln begründet.

import SwiftUI

enum Uhrfarben {

    /// Der Hintergrund des Feldes.
    ///
    /// Auf dem Telefon liegt der Play auf `flaeche`. Auf der Uhr ist
    /// das schwarze OLED-Schwarz daneben besser: Es kostet keinen Strom
    /// und hebt die Routen stärker ab. `flaecheTief` ist die dunkelste
    /// Stufe der Palette -- also die Antwort aus der eigenen Quelle
    /// statt eines getippten `.black`.
    static let rasen = Farben.flaecheTief

    /// Die Line of Scrimmage.
    static let grundlinie = Farben.inkStill

    /// Rand um eine Figur, damit zwei nebeneinander nicht
    /// ineinanderlaufen.
    static let rand = Farben.flaecheTief

    /// Was in der Figur steht.
    static let aufFigur = Farben.aufPetrol

    /// Beschriftung an einer Route.
    static let schrift = Farben.ink

    /// Die Farbe einer Linienart.
    ///
    /// `Linienstil` nennt eine ROLLE (`text`, `still`, `gold`,
    /// `petrol`); welcher Wert dahintersteht, entscheidet die Palette.
    /// Genau diese Trennung erlaubt es der Uhr, dieselbe Rolle etwas
    /// heller zu zeigen, ohne die Bedeutung zu verschieben.
    static func fuer(_ rolle: Linienstil.Rolle) -> Color {
        switch rolle {
        case .text: return Farben.ink
        case .still: return Farben.inkLeise
        case .gold: return Farben.gold
        case .petrol: return Farben.petrolTief
        }
    }

    /// Die Farbe einer Figur.
    ///
    /// Eigene Farbe schlägt Seite. Wer einem Spieler im Editor eine
    /// Farbe gegeben hat, hat das getan, damit man ihn wiedererkennt;
    /// am Handgelenk gilt das genauso.
    ///
    /// **Keine Farbe aus der Position.** `Positionsfarbe` ist eine
    /// Liste von Farben zum AUSWÄHLEN, kein Nachschlagewerk von
    /// Position zu Farbe -- nachgesehen, nicht angenommen. Wer daraus
    /// eine Zuordnung bastelte, erfände eine Regel, die es weder im
    /// Browser noch auf dem Telefon gibt.
    static func fuerSpieler(_ spieler: Zeichnung.Spieler) -> Color {
        if let hex = spieler.farbe, let eigen = Color(hexwert: hex) {
            return eigen
        }
        return spieler.seite == .defense ? Farben.ziegel : Farben.petrol
    }
}

extension Color {

    /// Liest `#rrggbb` und `rrggbb`. `nil` bei allem anderen.
    ///
    /// **Steht hier und nicht in `Gestaltung`**, weil die Uhr die
    /// einzige Stelle ist, die sie so braucht: Auf dem Telefon geht der
    /// Weg über `Farbwert`, und der zieht die halbe App hinter sich
    /// her (`Farbvorschlaege`). Für sechs Hexziffern ist das zu viel.
    init?(hexwert: String) {
        var text = hexwert.trimmingCharacters(in: .whitespaces)
        if text.hasPrefix("#") { text.removeFirst() }
        guard text.count == 6, let zahl = UInt32(text, radix: 16) else {
            return nil
        }
        self.init(.sRGB,
                  red: Double((zahl >> 16) & 0xFF) / 255,
                  green: Double((zahl >> 8) & 0xFF) / 255,
                  blue: Double(zahl & 0xFF) / 255,
                  opacity: 1)
    }
}
