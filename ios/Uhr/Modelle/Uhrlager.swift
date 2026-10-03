// Wo das Paket auf der Uhr liegt (R140).
//
// **Die Uhr muss ohne Telefon auskommen.** Das ist der ganze Zweck: Am
// Spielfeldrand steckt das Telefon in der Tasche des Trainers, im Bus
// oder gar nicht dort. Ein Wristcoach, der erst nachfragen muss, ist
// kein Wristcoach.
//
// Deshalb wird jedes Paket sofort auf die Platte geschrieben und beim
// Start von dort gelesen. Was ankommt, ersetzt den ganzen Stand -- siehe
// `Uhrpaket`.
//
// WARUM NICHT `UserDefaults`. Dort liegen Einstellungen, keine
// Datenmengen; Apple sagt dazu deutlich, dass sie klein bleiben sollen.
// Ein Heft mit fünfzig Plays sind einige hundert Kilobyte.

import Foundation

/// Die Platte der Uhr. Nichts hiervon wirft.
///
/// Ein Lager, das beim Schreiben einen Fehler auslöst, machte aus einem
/// fehlgeschlagenen Abgleich einen Absturz -- dieselbe Überlegung wie in
/// `Vorrat` auf dem Telefon. Was nicht abgelegt werden kann, ist nicht
/// abgelegt; die Uhr zeigt dann den alten Stand und holt beim nächsten
/// Abgleich neu.
enum Uhrlager {

    static let dateiname = "uhrpaket.json"

    private static var ordner: URL? {
        try? FileManager.default.url(for: .applicationSupportDirectory,
                                     in: .userDomainMask,
                                     appropriateFor: nil, create: true)
    }

    static var datei: URL? { ordner?.appendingPathComponent(dateiname) }

    /// Legt ein Paket ab. `false` heißt: Es ist nicht abgelegt.
    @discardableResult
    static func ablegen(_ paket: Uhrpaket) -> Bool {
        guard let datei, let daten = try? paket.schreiben() else { return false }
        do {
            try daten.write(to: datei, options: .atomic)
            return true
        } catch {
            return false
        }
    }

    /// Holt das abgelegte Paket. `nil` heißt: Es gibt keins, oder es ist
    /// unlesbar -- für die Uhr dasselbe.
    static func holen() -> Uhrpaket? {
        guard let datei, let daten = try? Data(contentsOf: datei) else {
            return nil
        }
        return Uhrpaket.lesen(daten)
    }

    /// Räumt ab. Nach einer Abmeldung auf dem Telefon gehören fremde
    /// Plays nicht mehr auf dieses Handgelenk.
    static func leeren() {
        guard let datei else { return }
        try? FileManager.default.removeItem(at: datei)
    }
}
