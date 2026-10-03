// Was die App bei der Bibliothek selbst entscheidet (B11).
//
// DIE ENTSCHEIDUNG, AN DER ALLES HÄNGT, ist dieselbe wie seit B4: Was
// der Finger auslöst, steht nicht in der Ansicht. Es gibt keinen Mac,
// und eine Rückmeldung vom Läufer dauert eine halbe Stunde. Eine Regel,
// die in einer SwiftUI-Ansicht steht, lässt sich in dieser Zeit nicht
// messen, sondern nur behaupten.
//
// Hier steht deshalb alles, was falsch sein KANN, und die Ansicht zeigt
// nur noch, was herauskommt:
//
//   * Die Reihenfolge beim Übernehmen. Sie ist die der LISTE und nicht
//     die des Anhakens -- sonst stehen die Plays im Heft danach in der
//     Reihenfolge, in der jemand zufällig getippt hat, und das sieht
//     nicht falsch aus, sondern nur beliebig.
//   * Die Sätze zur Grenze und zum Ergebnis. Ein Teilerfolg, der als
//     Absage gemeldet wird, lässt einen Coach drei fertige Plays
//     übersehen.
//
// Gemessen wird das in RoutetreeTests/BibliothekTests.swift.

import Foundation

enum Bibliotheksblock {

    /// Anhaken und wieder abhaken.
    ///
    /// Als Funktion und nicht als zwei Zeilen in der Ansicht, weil sonst
    /// niemand misst, dass ein zweiter Tipp wirklich zurücknimmt.
    static func umschalten(_ schluessel: String,
                           in gewaehlt: Set<String>) -> Set<String> {
        var neu = gewaehlt
        if neu.contains(schluessel) {
            neu.remove(schluessel)
        } else {
            neu.insert(schluessel)
        }
        return neu
    }

    /// Die gewählten Schlüssel, IN DER REIHENFOLGE DER LISTE.
    ///
    /// `Set` hat keine Reihenfolge. Wer es einfach durchgeht, schickt
    /// die Konzepte in einer Folge, die sich von Lauf zu Lauf ändert --
    /// und der Server vergibt Platz und Nummer genau danach. Im Heft
    /// stünde dann jedes Mal etwas anderes, ohne dass ein einziger
    /// Schritt falsch aussähe.
    ///
    /// Was nicht mehr in der Liste steht, fällt weg: Ein Schlüssel, den
    /// die letzte Antwort nicht mehr kennt, wäre beim Server ein
    /// „Diese Konzepte gibt es nicht".
    static func reihenfolge(gewaehlt: Set<String>,
                            eintraege: [Modell.Bibliothekseintrag])
        -> [String] {
        eintraege.map(\.schluessel).filter { gewaehlt.contains($0) }
    }

    /// Was oben in der Liste über den freien Platz steht.
    ///
    /// `nil` heißt unbegrenzt, und dann steht dort NICHTS. Ein Satz wie
    /// „unbegrenzt frei" wäre eine Zeile, die niemand braucht, an der
    /// auffälligsten Stelle.
    ///
    /// Die Grenze steht da, BEVOR jemand anhakt. Sie erst beim Absenden
    /// zu nennen wäre eine Überraschung, und Überraschungen bei Grenzen
    /// liest man als Fehler der App.
    ///
    /// **Ein Satz je Fall und kein zusammengesetzter (R22).** Vorher
    /// stand hier ein Rumpf mit angehängtem „s"; auf Französisch steht
    /// die Zahl an anderer Stelle und das „s" gehört ans Verb. Wer den
    /// Satz zerlegt, kann ihn in einer Sprache übersetzen und in der
    /// nächsten nicht mehr.
    static func freiText(_ frei: Int?) -> String? {
        guard let frei else { return nil }
        if frei == 0 {
            return String(localized:
                "In dieses Playbook passt nichts mehr hinein.")
        }
        return frei == 1
            ? String(localized: "Noch 1 Play frei in diesem Playbook.")
            : String(localized: "Noch \(frei) Plays frei in diesem Playbook.")
    }

    /// Der Satz nach dem Übernehmen.
    ///
    /// DER TEILERFOLG ZUERST. Wer gerade drei Plays bekommen hat, will
    /// sie sehen und nicht ein Angebot -- steht die Grenze vorn, liest
    /// er die Meldung als Absage und sucht die drei gar nicht erst.
    static func ergebnisText(angelegt: Int, uebergangen: Int) -> String {
        let anfang = angelegt == 1
            ? String(localized: "1 Play übernommen.")
            : String(localized: "\(angelegt) Plays übernommen.")
        guard uebergangen > 0 else { return anfang }
        let rest = uebergangen == 1
            ? String(localized: """
                1 weiterer passt nicht mehr hinein: Die Demo hat eine \
                Obergrenze je Playbook.
                """)
            : String(localized: """
                \(uebergangen) weitere passen nicht mehr hinein: Die Demo \
                hat eine Obergrenze je Playbook.
                """)
        // Zwei ganze Sätze aneinander, nicht zwei Satzhälften: Wo eine
        // Sprache die Reihenfolge dreht, dreht sie sie innerhalb eines
        // Satzes -- über einen Punkt hinweg tut es keine.
        return anfang + " " + rest
    }

    /// Hat es gereicht? Nur dann ist die Meldung eine reine Erfolgsmeldung.
    ///
    /// Getrennt von `ergebnisText`, weil die Ansicht daran entscheidet,
    /// ob sie einen Hinweis stehen lässt oder einen Kasten aufmacht.
    static func vollstaendig(angelegt: Int, uebergangen: Int) -> Bool {
        angelegt > 0 && uebergangen == 0
    }
}
