import Foundation

/// Die Regel für das Üben ohne Empfang (R14).
///
/// **Warum das eine eigene Datei ist**, aus demselben Grund wie
/// `Vorratsblock` (R14), `Kachelblock` (R13) und `Kurve` (R7): Zwischen
/// Dateizugriffen und einer Ansicht ließe es sich ohne Mac nicht messen,
/// sondern nur behaupten. Hier steht nur Rechnung, kein Zustand.
///
/// **Was hier NICHT passiert: gewichten.** Welcher Play drankommt, hat
/// der Server entschieden, als er das Paket rechnete. Diese Datei sagt
/// nur, welche Frage aus der fertigen Reihe noch offen ist -- der
/// Reihe nach. Eine zweite Gewichtung in Swift sähe nie falsch aus,
/// sondern nur nach Zufall.
enum Paketblock {

    /// Welche Fragen aus dem Paket noch niemand beantwortet hat.
    ///
    /// **In der Reihenfolge des Pakets.** Sie ist die des Servers, und
    /// sie umzusortieren hieße, seine Gewichtung zu übergehen.
    static func offen(_ paket: Modell.Uebungspaket,
                      beantwortet: [Modell.OffeneAntwort])
        -> [Modell.Paketfrage] {
        let erledigt = Set(beantwortet.map(\.marke))
        return paket.fragen.filter { !erledigt.contains($0.marke) }
    }

    /// Die nächste Frage, oder `nil`, wenn das Paket durch ist.
    static func naechste(_ paket: Modell.Uebungspaket,
                         beantwortet: [Modell.OffeneAntwort])
        -> Modell.Paketfrage? {
        offen(paket, beantwortet: beantwortet).first
    }

    /// Wie viele von wie vielen -- für die Anzeige am Platz.
    ///
    /// **Nicht `Fortschritt` aus der Antwort des Servers.** Der zählt
    /// den LERNSTAND (wie viele Plays sitzen) und ändert sich ohne Netz
    /// nicht. Hier geht es um etwas anderes: wie weit man in diesem
    /// Paket ist. Beides zu vermischen hieße, am Platz eine Zahl zu
    /// zeigen, die sich nie bewegt.
    static func stand(_ paket: Modell.Uebungspaket,
                      beantwortet: [Modell.OffeneAntwort])
        -> (fertig: Int, gesamt: Int) {
        let gesamt = paket.fragen.count
        let fertig = gesamt - offen(paket, beantwortet: beantwortet).count
        return (fertig, gesamt)
    }

    /// Lohnt es, ein neues Paket zu holen?
    ///
    /// **Bei der Hälfte und nicht erst, wenn es leer ist.** Wer die
    /// letzte Frage beantwortet und dann kein Netz hat, steht vor einem
    /// leeren Übungsmodus -- genau in dem Moment, für den das Ganze
    /// gebaut ist. Nachgeholt wird deshalb, solange noch Netz da ist.
    static func brauchtNachschub(_ paket: Modell.Uebungspaket?,
                                 beantwortet: [Modell.OffeneAntwort]) -> Bool {
        guard let paket, !paket.fragen.isEmpty else { return true }
        let (fertig, gesamt) = stand(paket, beantwortet: beantwortet)
        return fertig * 2 >= gesamt
    }

    /// War die Antwort richtig?
    ///
    /// **Nur für den Moment am Platz.** Was im Lernstand landet,
    /// entscheidet der Server beim Nachtragen aus seiner eigenen Zeile.
    /// Diese Rechnung hier steht nie in einer Anfrage.
    static func warRichtig(_ frage: Modell.Paketfrage, gewaehlt: Int) -> Bool {
        gewaehlt == frage.loesung
    }

    /// Wie viele Antworten warten darauf, nachgetragen zu werden.
    ///
    /// Die Zahl steht am Bildschirm: „4 Antworten warten auf Netz."
    /// Ohne sie sähe es aus, als wäre das Üben am Platz folgenlos
    /// gewesen -- und niemand übt gern ins Leere.
    static func wartend(_ beantwortet: [Modell.OffeneAntwort]) -> Int {
        beantwortet.count
    }

    /// Wie viele Antworten höchstens in EINE Anfrage gehen.
    ///
    /// Der Server weist mehr ab (`nachtragen/`, 200). Die Zahl steht
    /// hier, damit die App gar nicht erst zu viele schickt -- und zwar
    /// mit Abstand: Wer genau an die Grenze geht, bekommt beim
    /// nächsten Feld darüber eine Absage, die niemand erwartet hat.
    static let hoechstensJeAnfrage = 100

    /// Die nächste Fuhre für das Nachtragen -- die ÄLTESTEN zuerst.
    ///
    /// Die Reihenfolge ist die zeitliche, und `Lernstand.serie` hängt
    /// daran. Wer die neuesten zuerst schickte, drehte am Platz die
    /// Geschichte um.
    static func naechsteFuhre(_ beantwortet: [Modell.OffeneAntwort])
        -> [Modell.OffeneAntwort] {
        Array(beantwortet.sorted { $0.wann < $1.wann }
            .prefix(hoechstensJeAnfrage))
    }
}
