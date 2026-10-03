// Play spiegeln: links wird rechts.
//
// Die Quelle sind `schema.mirror_play` (Python) und
// `static/designer/spiegeln.js` (Browser). Das ist die dritte Fassung
// derselben Rechnung, und drei Fassungen laufen auseinander -- deshalb
// hängt an dieser hier eine Prüfung, die nicht behauptet, sondern misst:
// `scripts/zeichnung_swift.py` lässt den SERVER die zehn Bibliotheks-
// Plays spiegeln und schreibt das Ergebnis nach `ZeichnungProben`.
// `SpiegelungTests` spiegelt dieselben Plays in Swift und vergleicht Zahl
// für Zahl.
//
// GEDREHT WIRD NUR DIE QUERACHSE. Die Angriffsrichtung bleibt: Ein Play
// nach rechts bleibt ein Play nach rechts, er läuft nur zur anderen
// Seitenlinie. Für die Richtung gibt es einen eigenen Knopf -- im Web,
// und in der App, sobald B6 die Play-Eigenschaften nachzieht.
//
// ZWEIMAL GESPIEGELT MUSS WIEDER DAS ORIGINAL ERGEBEN. Das ist keine
// Nebensache, sondern der Prüfstein: Bei Flag Football Playmaker X ist
// genau das fehlerhaft, und die Rezensionen nennen es.

import Foundation

extension Zeichnung {

    /// Die Zeichnung an der Längsachse gespiegelt.
    ///
    /// `breite` ist die Feldbreite in Yards. Alles andere bleibt, wie es
    /// ist: Kennungen, Kürzel, Farben, Arten, Enden, Beschriftungen,
    /// Verzögerung und Tempo. Wer hier ein Feld vergisst, verliert es
    /// beim Spiegeln -- und niemand sieht es, weil ein gespiegelter Play
    /// ohnehin anders aussieht als vorher.
    func gespiegelt(breite: Double) -> Zeichnung {
        Zeichnung(
            spieler: spieler.map { einer in
                var kopie = einer
                kopie.y = Zeichnung.gedreht(einer.y, breite: breite)
                return kopie
            },
            linien: linien.map { linie in
                var kopie = linie
                kopie.punkte = linie.punkte.map {
                    Punkt(x: $0.x, y: Zeichnung.gedreht($0.y, breite: breite))
                }
                return kopie
            })
    }

    /// Ein Querwert, gedreht und auf zwei Stellen gerundet.
    ///
    /// **Warum überhaupt gerundet.** Der Server rundet mit
    /// `round(breite - y, 2)`, und was er speichert, ist die Wahrheit.
    /// Bliebe hier `25 - 7.5` als `17.499999999999996` stehen, stünde
    /// nach dem Sichern eine andere Zahl im Play als der Browser
    /// geschrieben hätte -- und der Vergleich zweier Fassungen zeigte
    /// einen Unterschied, den niemand gemacht hat.
    ///
    /// Auf- oder abrunden bei genau einem halben Hundertstel ist hier
    /// gleichgültig: Ein Querwert hat höchstens zwei Nachkommastellen
    /// (der Server rundet ihn beim Prüfen), also entsteht die dritte
    /// Stelle gar nicht erst.
    static func gedreht(_ y: Double, breite: Double) -> Double {
        ((breite - y) * 100).rounded() / 100
    }
}
