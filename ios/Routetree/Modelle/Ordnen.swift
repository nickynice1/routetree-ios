// Anlegen und Ordnen: die Regeln, die eine Liste umsortieren (B6).
//
// WARUM DAS EINE EIGENE DATEI IST -- und zwar aus demselben Grund wie
// `Zeichenblock` in B4: Es gibt keinen Mac, und eine Rückmeldung vom
// Läufer dauert eine halbe Stunde. Was in einer SwiftUI-Ansicht steht,
// lässt sich in dieser Zeit nicht messen, sondern nur behaupten.
//
// DIE ENTSCHEIDUNG, AN DER ALLES HÄNGT: DIE NUMMERN RECHNET DIESE
// DATEI, UND DIE ZAHLEN KOMMEN VOM SERVER.
//
// Beim Umsortieren fragt die App, ob die Nummern mitwandern sollen --
// dieselbe Frage wie im Browser. Damit sie beantwortbar ist, muss
// vorher dastehen, WAS dann passiert: welcher Play die 3 bekommt und
// welcher die 7. Die Nummer ist das, was auf dem Armband steht.
//
// Diese Vorschau ist eine Rechnung, und sie steht damit zweimal im
// Projekt: hier und in `designer/ordnen.py`. Zwei Fassungen laufen
// auseinander, und dieser Unterschied sieht nicht falsch aus -- eine
// Vorschau, die um eins danebenliegt, ist eine Zahl wie jede andere.
// Wer sie sieht, glaubt sie und druckt danach.
//
// Deshalb rechnet der SERVER die Fälle, `scripts/ordnen_swift.py` legt
// sie als `OrdnenProben.swift` ab, und `OrdnenTests` vergleicht Zahl
// für Zahl. Dasselbe Muster wie bei den Feldmaßen (B1), der Spiegelung
// und dem Laufplan (B5).

import Foundation

/// Die Umordnung einer Playliste -- ohne Ansicht, ohne Netz.
enum Ordnen {

    /// Was ein Play für die Umordnung mitbringt.
    ///
    /// Nicht `Modell.PlayKurz` selbst: Die Rechnung braucht drei Zahlen
    /// und keinen Namen, keine Kategorie und keine Situationen. Ein
    /// Test, der ein vollständiges Servermodell aufbauen muss, um eine
    /// Vertauschung zu prüfen, wird nicht geschrieben.
    struct Platz: Equatable {
        let id: Int
        /// Der Platz, den dieser Play HEUTE einnimmt (`position`).
        let platz: Int
        /// Die Nummer, die er heute hat. `nil` heißt „hat keine" --
        /// ausdrücklich nicht „Nummer 0".
        let nummer: Int?

        init(id: Int, platz: Int, nummer: Int?) {
            self.id = id
            self.platz = platz
            self.nummer = nummer
        }
    }

    /// Wer bekommt welchen Platz und welche Nummer?
    ///
    /// - Parameter reihenfolge: die Plays in der NEUEN Reihenfolge, mit
    ///   ihren alten Werten.
    /// - Parameter nummernMitziehen: ob die Nummern der neuen
    ///   Reihenfolge folgen sollen.
    /// - Returns: dieselben Plays, in derselben Reihenfolge, mit den
    ///   Werten von nachher.
    ///
    /// **Getauscht werden die Plätze, die genau diese Plays schon
    /// einnehmen** -- nicht 1 bis n. Die Liste lässt sich filtern, und
    /// wer im Filter „nur Offense" umsortiert, will die Defense nicht
    /// mit verschieben. Deren Plätze kommen hier gar nicht vor.
    ///
    /// **Der Satz der vergebenen Nummern bleibt derselbe.** Sie wechseln
    /// nur den Besitzer. Wer keine hatte, bekommt auch keine -- sonst
    /// entstünde beim Umsortieren aus einem Play ohne Nummer einer mit,
    /// und im Armband stünde eine Zeile, die niemand angelegt hat.
    static func neuePlaetze(_ reihenfolge: [Platz],
                            nummernMitziehen: Bool) -> [Platz] {
        let frei = reihenfolge.map(\.platz).sorted()
        guard nummernMitziehen else {
            return reihenfolge.enumerated().map { stelle, alt in
                Platz(id: alt.id, platz: frei[stelle], nummer: alt.nummer)
            }
        }

        var vergeben = reihenfolge.compactMap(\.nummer).sorted().makeIterator()
        return reihenfolge.enumerated().map { stelle, alt in
            // `alt.nummer != nil` entscheidet, NICHT die Stelle in der
            // Liste: Wer vorher keine Nummer hatte, überspringt den
            // Zähler, und die nächste Nummer geht an den nächsten, der
            // eine hatte.
            let neu = alt.nummer == nil ? nil : vergeben.next()
            return Platz(id: alt.id, platz: frei[stelle], nummer: neu)
        }
    }

    /// Eine Liste umordnen, wie SwiftUIs `.onMove` sie meldet.
    ///
    /// **Warum das hier steht und nicht in der Ansicht.** `toOffset` ist
    /// die Stelle VOR dem Entfernen -- wer ein Element von 0 nach 2
    /// zieht, meint damit Platz 1, nicht Platz 2. Diese Verschiebung um
    /// eins ist der klassische Fehler an dieser Stelle, sie tritt nur
    /// beim Ziehen nach unten auf, und sie sieht wie ein Wackler der
    /// Geste aus statt wie ein Rechenfehler.
    ///
    /// Swifts `move(fromOffsets:toOffset:)` macht es richtig. Diese
    /// Hülle gibt es, damit `OrdnenTests` es festhält: Wer sie einmal
    /// durch eigene Indexrechnerei ersetzt, fällt auf.
    static func verschieben<T>(_ liste: [T], von: IndexSet,
                               nach: Int) -> [T] {
        var kopie = liste
        kopie.move(fromOffsets: von, toOffset: nach)
        return kopie
    }

    /// Bringt eine Liste in die Reihenfolge der genannten Kennungen.
    ///
    /// Gebraucht, weil der Ordnen-Modus mit `Platz`-Werten arbeitet
    /// (drei Zahlen), die Liste aber Namen anzeigt.
    ///
    /// **Was fehlt, fällt weg -- ausdrücklich und nicht am Ende
    /// angehängt.** Eine Kennung ohne Play ist ein Zeichen dafür, dass
    /// sich die Liste unter der Hand geändert hat. Sie stillschweigend
    /// anzuhängen ergäbe eine Ansicht, die vollständig aussieht und in
    /// der falschen Ordnung steht.
    static func sortieren<T>(_ alle: [T], nach kennungen: [Int],
                             id: (T) -> Int) -> [T] {
        let karte = Dictionary(alle.map { (id($0), $0) },
                               uniquingKeysWith: { erster, _ in erster })
        return kennungen.compactMap { karte[$0] }
    }
}

/// Der Ordnen-Modus einer Playliste.
///
/// Er hält drei Dinge auseinander, die die Ansicht sonst vermischen
/// würde: die Reihenfolge beim Betreten (zum Zurücknehmen), die
/// Reihenfolge jetzt, und die Frage, ob überhaupt etwas anders ist.
///
/// **„Etwas anders" wird gemessen und nicht angenommen.** Wer eine
/// Kachel anfasst und wieder loslässt, hat nichts geändert -- und dann
/// darf die Leiste mit „Nummern mitziehen?" nicht erscheinen. Eine
/// Frage, die man beantworten muss, obwohl nichts passiert ist, ist die
/// zuverlässigste Art, Leute zum Wegklicken zu erziehen.
struct Ordnungsstand: Equatable {

    /// Die Reihenfolge beim Betreten des Modus.
    let anfang: [Ordnen.Platz]
    /// Die Reihenfolge jetzt.
    private(set) var jetzt: [Ordnen.Platz]

    init(_ plaetze: [Ordnen.Platz]) {
        self.anfang = plaetze
        self.jetzt = plaetze
    }

    /// Hat sich die Reihenfolge geändert?
    ///
    /// Verglichen werden die Kennungen und nicht die ganzen Werte: Eine
    /// Liste, die nach dem Sichern neue Plätze trägt, aber in derselben
    /// Ordnung steht, ist nicht geändert.
    var geaendert: Bool {
        anfang.map(\.id) != jetzt.map(\.id)
    }

    mutating func verschieben(von: IndexSet, nach: Int) {
        jetzt = Ordnen.verschieben(jetzt, von: von, nach: nach)
    }

    /// Zurück auf den Stand beim Betreten.
    mutating func zuruecknehmen() {
        jetzt = anfang
    }

    /// Was der Server bekommt: die Kennungen in der neuen Reihenfolge.
    var kennungen: [Int] { jetzt.map(\.id) }

    /// Die Vorschau: wie die Liste nach dem Sichern aussieht.
    ///
    /// Sie wird für BEIDE Antworten gerechnet und nicht erst, wenn
    /// jemand „Nummern mitziehen" drückt. Genau darum geht es: Die Frage
    /// ist nur zu beantworten, wenn beide Fassungen nebeneinander
    /// stehen.
    func vorschau(nummernMitziehen: Bool) -> [Ordnen.Platz] {
        Ordnen.neuePlaetze(jetzt, nummernMitziehen: nummernMitziehen)
    }

    /// Die Nummern der Vorschau, nach Kennung nachschlagbar.
    ///
    /// **Nach Kennung und nicht nach Stelle in der Liste.** Die Ansicht
    /// zeichnet ihre Zeilen aus einer zweiten Liste (den Plays mit
    /// ihren Namen); wenn dort je ein Eintrag fehlte, verschöben sich
    /// die Stellen um eins, und jede Zeile zeigte die Nummer ihres
    /// Nachbarn. Das sähe wie eine plausible Vorschau aus.
    func vorschauNummern(nummernMitziehen: Bool) -> [Int: Int?] {
        var karte: [Int: Int?] = [:]
        for platz in vorschau(nummernMitziehen: nummernMitziehen) {
            karte[platz.id] = platz.nummer
        }
        return karte
    }

    /// Die Plays in der Reihenfolge, die gerade auf dem Schirm steht.
    func inReihenfolge(_ alle: [Modell.PlayKurz]) -> [Modell.PlayKurz] {
        Ordnen.sortieren(alle, nach: kennungen, id: \.id)
    }
}
