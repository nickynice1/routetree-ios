// ERZEUGT VON scripts/playfelder_swift.py. NICHT VON HAND ÄNDERN.
//
// Die Quelle ist backend/designer/models.py (Play.Seite, NUMMER_MAX).
// Wer hier etwas ändert, ändert es nur in der App -- und `_play_felder`
// auf dem Server lehnt eine unbekannte Seite mit „Diese Seite gibt es
// nicht." ab. Der Trainer sähe eine Fehlermeldung, die zu nichts passt,
// was auf seinem Bildschirm steht.
//
// Neu erzeugen:  ./scripts/playfelder_swift.py
// Geprüft von:   backend/designer/test_playfelder_swift.py

import Foundation

/// Die Seite, auf der ein Play steht.
///
/// Angriff, Verteidigung, Special Teams -- dieselbe Einteilung, nach der
/// die Playliste filtert und der Druckbogen gegliedert wird.
struct Seite: Identifiable, Hashable {

    /// Der gespeicherte Wert. Genau diese Zeichenkette nimmt der Server
    /// entgegen, und nur diese drei.
    let wert: String
    /// Wie sie heißt.
    let name: String

    var id: String { wert }
}

extension Seite {

    /// Alle Seiten, in der Reihenfolge des Servers.
    static let alle: [Seite] = [
        Seite(wert: "off",
              name: String(localized: "Offense")),
        Seite(wert: "def",
              name: String(localized: "Defense")),
        Seite(wert: "st",
              name: String(localized: "Special")),
    ]

    /// Der Name zu einem gespeicherten Wert, sonst der Wert selbst.
    ///
    /// Der Wert selbst und nicht etwa nichts: Ein leeres Feld sähe aus
    /// wie ein Fehler der Liste. Steht dort „st" statt „Special", weiß
    /// wenigstens jemand, wonach er suchen muss.
    static func name(fuer wert: String) -> String {
        alle.first { $0.wert == wert }?.name ?? wert
    }

    /// Die Vorgabe für einen Play ohne Angabe.
    ///
    /// Die erste der Liste und keine eingetippte Zeichenkette: Sonst
    /// stünde hier ein vierter Wert, sobald jemand die Reihenfolge auf
    /// dem Server ändert.
    static var vorgabe: String { alle.first?.wert ?? "" }
}

/// Was der Server an einem Play noch begrenzt.
enum Playgrenzen {
    /// Die größte Playnummer. Der Server prüft `1 <= n <= nummerMax`.
    static let nummerMax = 99
    /// So lang darf ein Playname sein (`max_length` am Feld).
    static let nameLaenge = 80
    /// So lang dürfen die Hinweise sein. Der Server schneidet ab.
    static let hinweiseLaenge = 2000
}
