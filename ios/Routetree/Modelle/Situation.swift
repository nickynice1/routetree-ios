// ERZEUGT VON scripts/situationen_swift.py. NICHT VON HAND ÄNDERN.
//
// Die Quelle ist backend/designer/schema.py (SITUATIONEN). Wer hier etwas
// ändert, ändert es nur in der App -- und `pruefe_situationen` auf dem
// Server wirft Unbekanntes STILL heraus. Ein Tippfehler gäbe dann keinen
// Fehler, sondern eine Auswahl, die beim Speichern verschwindet.
//
// Neu erzeugen:  ./scripts/situationen_swift.py
// Geprüft von:   backend/designer/test_situationen_swift.py

import Foundation

/// Eine Spielsituation, nach der das Call Sheet gegliedert ist.
///
/// Ein Play steht in JEDEM Block, zu dem er passt -- die Auswahl ist
/// keine Einordnung in ein Fach, sondern eine Liste von Lagen, in denen
/// der Play gerufen wird.
struct Situation: Identifiable, Hashable {

    /// Der gespeicherte Wert. Genau diese Zeichenkette nimmt der Server
    /// entgegen; alles andere fällt beim Speichern still weg.
    let wert: String
    /// Wie sie heißt.
    let name: String
    /// Ein Satz dazu, für die Zeile darunter.
    let hinweis: String
    /// Gibt es diese Lage nur da, wo vor der Endzone gepasst werden
    /// muss? (R110.8)
    ///
    /// **Nicht getippt, sondern gemessen.** Der Erzeuger fragt
    /// `schema.situationen_fuer` einmal für eine Form MIT und einmal
    /// für eine ohne No-Run-Zone und markiert, was nur in der ersten
    /// vorkommt. Ändert der Server seine Regel, ändert sich diese
    /// Kennzeichnung mit -- eine Liste von Sonderfällen in Swift wäre
    /// die zweite Regel und beim nächsten Mal die falsche.
    let nurMitKeinLaufZone: Bool

    var id: String { wert }
}

extension Situation {

    /// Alle Situationen, in der Reihenfolge des Call Sheets.
    ///
    /// Die Reihenfolge ist Teil der Sache: Sie ist die Gliederung des
    /// Bogens, den der Trainer in der Hand hält. Alphabetisch sortiert
    /// stünde „Red Zone" zwischen „Opener" und „Zwei-Minuten".
    static let alle: [Situation] = [
        Situation(wert: "opener",
                  name: String(localized: "Opener"),
                  hinweis: String(localized: "Die ersten Spielzüge, vorher festgelegt"),
                  nurMitKeinLaufZone: false),
        Situation(wert: "first",
                  name: String(localized: "1st Down"),
                  hinweis: String(localized: "Erster Versuch, alle Möglichkeiten offen"),
                  nurMitKeinLaufZone: false),
        Situation(wert: "second_kurz",
                  name: String(localized: "2nd & kurz"),
                  hinweis: String(localized: "Zweiter Versuch, wenig zu gehen"),
                  nurMitKeinLaufZone: false),
        Situation(wert: "second_lang",
                  name: String(localized: "2nd & lang"),
                  hinweis: String(localized: "Zweiter Versuch, viel zu gehen"),
                  nurMitKeinLaufZone: false),
        Situation(wert: "third_kurz",
                  name: String(localized: "3rd & kurz"),
                  hinweis: String(localized: "Letzter Versuch, wenig zu gehen"),
                  nurMitKeinLaufZone: false),
        Situation(wert: "third_mittel",
                  name: String(localized: "3rd & mittel"),
                  hinweis: String(localized: "Letzter Versuch, mittlere Distanz"),
                  nurMitKeinLaufZone: false),
        Situation(wert: "third_lang",
                  name: String(localized: "3rd & lang"),
                  hinweis: String(localized: "Letzter Versuch, viel zu gehen"),
                  nurMitKeinLaufZone: false),
        Situation(wert: "redzone",
                  name: String(localized: "Red Zone"),
                  hinweis: String(localized: "Nah an der Endzone"),
                  nurMitKeinLaufZone: false),
        Situation(wert: "norun",
                  name: String(localized: "No-Run-Zone"),
                  hinweis: String(localized: "Muss gepasst werden"),
                  nurMitKeinLaufZone: true),
        Situation(wert: "zweiminuten",
                  name: String(localized: "Zwei-Minuten"),
                  hinweis: String(localized: "Uhr läuft, Seitenlinie und Timeouts zählen"),
                  nurMitKeinLaufZone: false),
    ]

    /// Bringt eine gespeicherte Auswahl in die Reihenfolge des Bogens
    /// und wirft Unbekanntes heraus -- wie `pruefe_situationen` auf dem
    /// Server.
    ///
    /// **Dieselbe Rechnung an zwei Stellen, und das mit Absicht.** Der
    /// Server ist die Wahrheit und prüft ohnehin; die App tut es
    /// trotzdem, damit die Auswahl auf dem Bildschirm schon so aussieht,
    /// wie sie gespeichert wird. Sonst springt sie nach dem Sichern um.
    static func geordnet(_ werte: [String]) -> [String] {
        // Ueber `alle` gelaufen und nicht ueber `werte`: Damit ist die
        // Reihenfolge die des Bogens, Unbekanntes faellt heraus und
        // Doppeltes kann gar nicht erst entstehen -- alle drei Zusagen
        // von `pruefe_situationen` in einer Zeile.
        let gewaehlt = Set(werte)
        return alle.map(\.wert).filter(gewaehlt.contains)
    }

    /// Der Name zu einem gespeicherten Wert, sonst der Wert selbst.
    ///
    /// Der Wert selbst und nicht etwa nichts: Ein leeres Feld sähe aus
    /// wie ein Fehler der Liste. Steht dort „redzone" statt „Red Zone",
    /// weiß wenigstens jemand, wonach er suchen muss.
    static func name(fuer wert: String) -> String {
        alle.first { $0.wert == wert }?.name ?? wert
    }

    /// Die Situationen, die es in DIESER Spielform gibt (R110.8).
    ///
    /// **Warum die App das überhaupt unterscheiden muss.** „No-Run-Zone"
    /// gibt es nur da, wo vor der Endzone gepasst werden muss: im Flag
    /// und im 5er-Tackle. In jeder anderen Tackle-Form ist ein Kästchen
    /// mit dieser Aufschrift kein Angebot, sondern eine falsche Auskunft
    /// über die Regeln. Wer es anhakt, sortiert seinen Play im Call
    /// Sheet unter eine Lage, die es im Spiel nicht gibt.
    ///
    /// Der Browser fragt seit dem 07.09.2026 `schema.situationen_fuer`.
    /// Die App zeigte weiter alle zehn.
    ///
    /// Gefragt wird die Tiefe der Zone und nicht der Name der Form: Wer
    /// eine Form hinzufügt, bekommt die richtige Liste, ohne sie hier
    /// einzutragen.
    static func fuer(_ form: Spielform) -> [Situation] {
        let mitZone = form.feld.keinLauf > 0
        return alle.filter { mitZone || !$0.nurMitKeinLaufZone }
    }

    /// Dasselbe über den Schlüssel der Form.
    ///
    /// Ein unbekannter Schlüssel bekommt die Voreinstellung -- also
    /// eine Liste und nicht eine leere. Ein Bildschirm ohne jede
    /// Situation sähe aus wie ein Fehler.
    static func fuer(schluessel: String?) -> [Situation] {
        fuer(Spielform.zu(schluessel))
    }
}
