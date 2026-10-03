// Wie die Playliste in Abschnitte zerfällt (B7).
//
// WARUM DAS HIER STEHT UND NICHT IN `PlayListe`. Es gibt keinen Mac, und
// eine Rückmeldung vom Läufer dauert eine halbe Stunde. Eine Regel, die
// in einer SwiftUI-Ansicht steht, lässt sich in dieser Zeit nicht
// messen, sondern nur behaupten -- dieselbe Begründung wie bei
// `Zeichenblock` (B4) und `Ordnen` (B6).
//
// UND ES IST EINE REGEL, KEINE DARSTELLUNG. Bis B7 standen die
// Abschnitte alphabetisch. Die Kategorien haben aber eine Reihenfolge,
// und es ist dieselbe, in der die Wristcoach-Einlage druckt: Ein Coach,
// der „Red Zone" nach oben gezogen hat, fand sie in der App zwischen
// „Pass" und „Trick" wieder. Die Liste in der Hand sah anders aus als
// die auf dem Bildschirm, und das fällt erst am Spieltag auf.

import Foundation

/// Die Abschnitte der Playliste, in der Reihenfolge der Kategorien.
enum Abschnitte {

    /// Plays ohne Kategorie landen nicht unter „“, sondern hier drunter.
    /// Eine leere Überschrift sieht aus wie ein Fehler.
    ///
    /// Der Text ist zugleich der Schlüssel der Restgruppe: Zwei
    /// Schreibweisen davon ergäben zwei Abschnitte.
    static let ohneKategorie = String(localized: "Ohne Kategorie")

    /// Die Überschrift über den aufgegebenen Plays (A7, B8).
    static let aufgabe = String(localized: "Deine Aufgabe")

    /// Ein Abschnitt: die Überschrift und was darunter steht.
    struct Abschnitt: Identifiable, Equatable {
        let name: String
        let plays: [Modell.PlayKurz]
        /// **Nicht der Name.** Eine Kategorie darf „Deine Aufgabe"
        /// heißen, und dann gäbe es zwei Abschnitte mit derselben
        /// Kennung -- SwiftUI zeigt in dem Fall einen davon gar nicht
        /// an, ohne dass irgendwo ein Fehler steht.
        let id: String
    }

    /// Gruppiert die Plays nach Kategorie und sortiert die Abschnitte.
    ///
    /// Die Reihenfolge, von oben nach unten:
    ///
    /// 1. die bekannten Kategorien nach ihrem `position`,
    /// 2. Kategorien, die die App nicht kennt -- eine ältere
    ///    Serverfassung, oder sie ist gerade gelöscht worden --,
    ///    untereinander alphabetisch,
    /// 3. „Ohne Kategorie" ganz zuletzt.
    ///
    /// Punkt 2 ist keine Spitzfindigkeit: Ohne ihn hinge die Stelle
    /// eines unbekannten Namens davon ab, in welcher Reihenfolge die
    /// Wörterbuchschlüssel gerade herauskommen -- und die steht in Swift
    /// nicht fest. Dieselbe Liste sähe bei jedem Öffnen anders aus.
    ///
    /// Punkt 3 gilt auch dann, wenn die Kategorien gar nicht geladen
    /// werden konnten. Eine Restgruppe gehört nach unten, und mehr
    /// verspricht die Playliste in dem Fall auch nicht.
    ///
    /// **`aufgabeZuerst` hebt die aufgegebenen Plays heraus (A7, B8)** --
    /// in einen eigenen Abschnitt ganz oben, und aus ihren Kategorien
    /// heraus. Zweimal derselbe Play in einer Liste wäre zweimal
    /// dieselbe Kachel, und wer die zweite antippt, glaubt, es sei eine
    /// andere.
    ///
    /// Die Fahne gehört dem Aufrufer, weil im Browser dieselbe
    /// Entscheidung an derselben Frage hängt: Für einen Coach IST diese
    /// Liste die Reihenfolge -- er zieht die Kacheln darin --, und eine
    /// Ansicht, die sie stillschweigend anders legt, macht aus dem
    /// Ziehen eine Behauptung. Ein Spieler kann hier nichts verschieben,
    /// und für ihn ist „meine Aufgabe zuerst" die nützliche Ordnung.
    static func gruppieren(_ plays: [Modell.PlayKurz],
                           kategorien: [Modell.Kategorie],
                           aufgabeZuerst: Bool = false) -> [Abschnitt] {
        let aufgegeben = aufgabeZuerst ? plays.filter(\.aufgabe) : []
        let uebrige = aufgegeben.isEmpty ? plays : plays.filter { !$0.aufgabe }
        let nachName = Dictionary(grouping: uebrige) {
            $0.kategorie ?? ohneKategorie
        }
        // Nachgeschlagen wird nach NAMEN, denn danach gruppiert der
        // Server die Plays (`kategorie` ist ein Name). Zwei Kategorien
        // mit demselben Namen kann es je Playbook nicht geben; käme es
        // trotzdem so weit, gilt die erste und nicht die zufällig
        // letzte.
        let plaetze = Dictionary(kategorien.map { ($0.name, $0.position) },
                                 uniquingKeysWith: { erste, _ in erste })
        let kategorieteil = nachName.keys
            .sorted { eine, andere in
                let a = rang(eine, plaetze), b = rang(andere, plaetze)
                return a == b
                    ? eine.localizedCompare(andere) == .orderedAscending
                    : a < b
            }
            .map { Abschnitt(name: $0, plays: nachName[$0] ?? [],
                             id: "kategorie:\($0)") }
        guard !aufgegeben.isEmpty else { return kategorieteil }
        return [Abschnitt(name: aufgabe, plays: aufgegeben, id: "aufgabe")]
            + kategorieteil
    }

    /// Der Platz eines Abschnitts. Je kleiner, desto weiter oben.
    private static func rang(_ name: String, _ plaetze: [String: Int]) -> Int {
        if name == ohneKategorie { return Int.max }
        return plaetze[name] ?? (Int.max - 1)
    }
}
