// Der Übungsmodus: was ein Fingertipp auf einen Antwortknopf auslöst.
//
// WARUM DAS NICHT IN DER ANSICHT STEHT. Derselbe Grund wie beim
// `Zeichenblock`: Es gibt keinen Mac, und eine Rückmeldung vom Läufer
// dauert eine halbe Stunde. Eine Regel, die in einer SwiftUI-Ansicht
// steht, lässt sich in dieser Zeit nicht messen, sondern nur behaupten.
//
// WAS HIER NICHT PASSIERT: Es wird nicht entschieden, welcher Play
// gefragt wird, welche Namen danebenstehen oder ob eine Antwort richtig
// war. Das alles sagt der SERVER (`api_v1_uebung`). Nachgebaut wäre es
// die Lösung im Speicher der App -- und der Übungsmodus prüfte danach
// nur noch, wer hineinsehen kann.
//
// Übrig bleiben genau die drei Dinge, die eine App falsch machen kann:
// dass ein doppelter Fingertipp zweimal zählt, dass eine Meldung zur
// falschen Frage steht, und dass ein fehlgeschlagenes Absenden das Bild
// vom Schirm nimmt.

import Foundation

/// Der Stand des Übungsmodus -- ein Wert, kein Objekt.
struct Uebungsblock: Equatable {

    /// Was gerade auf dem Schirm steht.
    enum Zustand: Equatable {
        /// Noch keine Frage da. Der Anfang, und sonst nie wieder: Nach
        /// einer Antwort kommt die nächste Frage in derselben Antwort
        /// des Servers mit.
        case laedt
        case frage(Modell.Uebungsstand.Runde)
        /// Zum Üben fehlen Plays. `noetig` und `hat` kommen vom Server.
        case zuWenige(noetig: Int, hat: Int)
        /// Es gibt nichts zu zeigen, und der Grund steht dabei. Nur
        /// wenn noch NIE eine Frage dastand -- sonst bleibt die Frage
        /// stehen und der Fehler wird zur Meldung.
        case fehler(String)
    }

    /// Der Satz nach einer Antwort. Er gehört zur VORIGEN Frage und
    /// steht über der neuen -- genau wie im Browser, wo die Meldung
    /// nach der Umleitung über dem nächsten Diagramm erscheint.
    struct Meldung: Equatable {
        let text: String
        /// Nur für die Farbe. Ob eine Antwort richtig war, sagt der
        /// Server; die App leitet es nicht aus dem Text ab.
        let richtig: Bool
    }

    private(set) var zustand: Zustand = .laedt
    /// Die Kennung der Antwort, die gerade unterwegs ist. `nil` heißt:
    /// Es wartet nichts.
    private(set) var unterwegs: Int?
    private(set) var meldung: Meldung?

    /// Ob ein Antwortknopf jetzt etwas auslösen darf.
    var darfAntworten: Bool {
        guard case .frage = zustand else { return false }
        return unterwegs == nil
    }

    /// Ob überhaupt schon einmal eine Frage dastand.
    private var hatFrage: Bool {
        if case .frage = zustand { return true }
        return false
    }

    /// Nimmt einen Fingertipp entgegen.
    ///
    /// Gibt zurück, ob die Antwort losgeschickt werden soll.
    ///
    /// **Der zweite Tipp zählt nicht.** Ein Kind, das auf einem
    /// langsamen Netz zweimal tippt, schickte sonst zwei Antworten: Die
    /// erste wird gewertet, die zweite trifft auf eine Frage, die es
    /// nicht mehr gibt. Auf dem Schirm stünde dann eine Meldung zu einer
    /// Frage, die gar nicht mehr gestellt war.
    mutating func antworten(_ id: Int) -> Bool {
        guard darfAntworten else { return false }
        unterwegs = id
        // Die alte Meldung geht weg, sobald geantwortet ist. Sonst
        // stünde der Satz zur vorletzten Frage noch da, während die
        // letzte schon unterwegs ist.
        meldung = nil
        return true
    }

    /// Die erste Frage (oder eine nach dem Nochmal-Versuchen).
    mutating func uebernimm(_ stand: Modell.Uebungsstand) {
        unterwegs = nil
        switch stand {
        case .frage(let runde):
            zustand = .frage(runde)
        case .zuWenige(let noetig, let hat):
            zustand = .zuWenige(noetig: noetig, hat: hat)
            meldung = nil
        }
    }

    /// Das Ergebnis einer Antwort samt der nächsten Frage.
    ///
    /// **Ohne Wertung keine Meldung.** `gewertet: false` heißt, dass
    /// keine Frage offen stand -- nach einem Neustart, einem zweiten
    /// Gerät, einem doppelten Tipp. Ein Satz dazu würde etwas
    /// behaupten, das nicht passiert ist; gefragt wird einfach neu.
    mutating func uebernimm(_ runde: Modell.Antwortrunde) {
        uebernimm(runde.naechste)
        guard let ergebnis = runde.ergebnis else { return }
        meldung = Meldung(text: ergebnis.meldung, richtig: ergebnis.richtig)
    }

    // MARK: - Ohne Empfang (R14)

    /// Eine Frage aus dem vorausberechneten Paket zeigen.
    ///
    /// **Sie sieht auf dem Schirm aus wie jede andere**, und das ist
    /// Absicht: Am Platz soll niemand einen zweiten Übungsmodus lernen
    /// müssen. Der Unterschied steht nur in der Leiste darüber, die
    /// sagt, dass die Antworten auf Netz warten.
    ///
    /// Der `fortschritt` kommt aus dem Paket und ist damit der vom
    /// Zeitpunkt des Holens. Er bewegt sich ohne Netz nicht -- deshalb
    /// zeigt die Ansicht daneben den Paketstand, der sich bewegt.
    mutating func uebernimm(_ frage: Modell.Paketfrage,
                            fortschritt: Modell.Fortschritt) {
        unterwegs = nil
        zustand = .frage(Modell.Uebungsstand.Runde(
            frage: frage.frage, auswahl: frage.auswahl,
            fortschritt: fortschritt,
            serieFuerSitzt: frage.serieFuerSitzt))
    }

    /// Der Satz zu einer am Platz gegebenen Antwort.
    ///
    /// **Er kommt aus dem Paket, nicht aus Swift.** Denselben Satz
    /// liest der Browser; in Swift nachgebaut wäre er beim nächsten
    /// Wort ein anderer, und `test_ton.py` käme an ihn nicht heran.
    /// Deshalb schickt der Server ihn im Paket mit -- einen je
    /// möglicher Antwort.
    mutating func meldeAusPaket(_ frage: Modell.Paketfrage,
                                gewaehlt: Int) {
        let text = frage.satz(fuer: gewaehlt)
        guard !text.isEmpty else { return }
        meldung = Meldung(text: text,
                          richtig: Paketblock.warRichtig(frage,
                                                         gewaehlt: gewaehlt))
    }

    /// Eine Meldung setzen, die eine neue Frage überleben soll.
    ///
    /// **Warum das nötig ist.** Am Netz kommt Ergebnis und nächste
    /// Frage in EINER Antwort, und `uebernimm(_ runde:)` setzt beides
    /// in der richtigen Reihenfolge. Am Platz sind es zwei Schritte --
    /// bewerten, dann die nächste Frage aus dem Paket --, und die
    /// zweite löschte den Satz zur ersten wieder weg. Der Satz gehört
    /// aber zur VORIGEN Frage und steht über der neuen, genau wie im
    /// Browser.
    mutating func meldungSetzen(_ was: Meldung) {
        meldung = was
    }

    /// Das Paket ist durchgearbeitet und es gibt kein Netz für Nachschub.
    mutating func paketLeer(_ text: String) {
        unterwegs = nil
        zustand = .fehler(text)
    }

    /// Etwas ist schiefgegangen.
    ///
    /// **Die Frage bleibt stehen, wenn es eine gibt.** Ein Netzfehler
    /// beim Absenden nähme sonst das Diagramm vom Schirm, und der
    /// nächste Fingertipp träfe eine leere Seite. Steht dagegen noch
    /// gar nichts da, ist der Fehler das Einzige, was es zu zeigen
    /// gibt.
    mutating func fehlgeschlagen(_ text: String) {
        unterwegs = nil
        if hatFrage {
            meldung = Meldung(text: text, richtig: false)
        } else {
            zustand = .fehler(text)
            meldung = nil
        }
    }
}
