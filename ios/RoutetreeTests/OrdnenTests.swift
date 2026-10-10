import XCTest
@testable import Routetree

/// Rechnet die App die Umordnung wie der Server?
///
/// **Warum das die eigentliche Frage ist.** Beim Umsortieren fragt die
/// App, ob die Nummern mitwandern sollen -- dieselbe Frage wie im
/// Browser. Damit sie beantwortbar ist, muss vorher dastehen, WAS dann
/// passiert: welcher Play die 3 bekommt und welcher die 7.
///
/// Die Nummer ist das, was auf dem Armband steht. Eine Vorschau, die um
/// eins danebenliegt, ist schlimmer als gar keine: Sie sieht nicht falsch
/// aus, sondern nur wie eine Zahl. Wer sie sieht, glaubt sie und druckt
/// danach -- und merkt es am Spieltag, wenn der Coach eine Nummer ruft
/// und drei Spieler etwas anderes laufen.
///
/// Deshalb steht hier kein selbst ausgedachtes Ergebnis. Die Zahlen in
/// `OrdnenProben` hat der SERVER gerechnet
/// (`backend/designer/ordnen.py`, dieselbe Funktion, die
/// `Playbook.reihenfolge_setzen` beim Sichern wirklich ausführt).
final class OrdnenTests: XCTestCase {

    // --- Die Proben vom Server -------------------------------------------

    /// EIN RGLOB INS LEERE IST DIE STILLSTE ART, WIE EINE PRÜFUNG
    /// AUFHÖRT ZU MESSEN. Dieselbe Lehre wie aus `AppTexteTest` in B5:
    /// Eine Schleife über null Fälle ist grün.
    func testEsGibtUeberhauptProben() {
        XCTAssertGreaterThanOrEqual(
            OrdnenProben.faelle.count, 10,
            "Die Probendatei ist leer oder geschrumpft. "
            + "Neu erzeugen: ./scripts/ordnen_swift.py")
    }

    func testOhneMitziehenRechnetDieAppWieDerServer() {
        for fall in OrdnenProben.faelle {
            let ergebnis = Ordnen.neuePlaetze(plaetze(fall),
                                              nummernMitziehen: false)
            vergleichen(ergebnis, fall.ohneMitziehen,
                        fall: fall, was: "ohne Mitziehen")
        }
    }

    func testMitMitziehenRechnetDieAppWieDerServer() {
        for fall in OrdnenProben.faelle {
            let ergebnis = Ordnen.neuePlaetze(plaetze(fall),
                                              nummernMitziehen: true)
            vergleichen(ergebnis, fall.mitMitziehen,
                        fall: fall, was: "mit Mitziehen")
        }
    }

    /// Die Reihenfolge der Plays selbst bleibt unangetastet.
    ///
    /// Gemessen, weil es der leiseste Fehler wäre: Wer beim Sortieren der
    /// freien Plätze versehentlich die Liste mitsortiert, bekommt lauter
    /// plausible Zahlen -- und die Plays stehen in der falschen Ordnung.
    func testDieKennungenBehaltenIhreReihenfolge() {
        for fall in OrdnenProben.faelle {
            let ein = plaetze(fall)
            for mitziehen in [false, true] {
                let aus = Ordnen.neuePlaetze(ein, nummernMitziehen: mitziehen)
                XCTAssertEqual(aus.map(\.id), ein.map(\.id),
                               "\(fall.name), mitziehen=\(mitziehen)")
            }
        }
    }

    /// Der Satz der vergebenen Nummern bleibt derselbe -- sie wechseln
    /// nur den Besitzer. Sonst entstünden Lücken im Armband.
    func testKeineNummerVerschwindetUndKeineKommtDazu() {
        for fall in OrdnenProben.faelle {
            let ein = plaetze(fall)
            let aus = Ordnen.neuePlaetze(ein, nummernMitziehen: true)
            XCTAssertEqual(ein.compactMap(\.nummer).sorted(),
                           aus.compactMap(\.nummer).sorted(), fall.name)
        }
    }

    /// Wer keine Nummer hatte, bekommt auch keine.
    func testOhneNummerBleibtOhneNummer() {
        for fall in OrdnenProben.faelle {
            let ein = plaetze(fall)
            let aus = Ordnen.neuePlaetze(ein, nummernMitziehen: true)
            for (alt, neu) in zip(ein, aus) {
                XCTAssertEqual(alt.nummer == nil, neu.nummer == nil,
                               "\(fall.name), Play \(alt.id)")
            }
        }
    }

    /// Die Plätze sind genau die, die vorher belegt waren -- nicht 1..n.
    ///
    /// Das ist der Fall `luecken_in_den_plaetzen`: Nach einem gefilterten
    /// Umsortieren sind die Plätze etwa 2, 5 und 9. Wer hier 1, 2, 3
    /// vergibt, schiebt die Plays vor die ungefilterten.
    func testDiePlaetzeSindDieAltenPlaetze() {
        for fall in OrdnenProben.faelle {
            let ein = plaetze(fall)
            let aus = Ordnen.neuePlaetze(ein, nummernMitziehen: false)
            XCTAssertEqual(aus.map(\.platz).sorted(),
                           ein.map(\.platz).sorted(), fall.name)
        }
    }

    // --- Die Liste verschieben -------------------------------------------

    private let drei = [
        Ordnen.Platz(id: 1, platz: 1, nummer: 1),
        Ordnen.Platz(id: 2, platz: 2, nummer: 2),
        Ordnen.Platz(id: 3, platz: 3, nummer: 3),
    ]

    /// **Der klassische Fehler an dieser Stelle.** `toOffset` ist die
    /// Stelle VOR dem Entfernen. Wer von 0 nach 2 zieht, meint Platz 1.
    /// Die Verschiebung um eins tritt nur beim Ziehen nach unten auf und
    /// sieht wie ein Wackler der Geste aus statt wie ein Rechenfehler.
    func testNachUntenZiehen() {
        let neu = Ordnen.verschieben(drei, von: IndexSet(integer: 0), nach: 2)
        XCTAssertEqual(neu.map(\.id), [2, 1, 3])
    }

    func testNachObenZiehen() {
        let neu = Ordnen.verschieben(drei, von: IndexSet(integer: 2), nach: 0)
        XCTAssertEqual(neu.map(\.id), [3, 1, 2])
    }

    func testGanzNachUntenZiehen() {
        let neu = Ordnen.verschieben(drei, von: IndexSet(integer: 0), nach: 3)
        XCTAssertEqual(neu.map(\.id), [2, 3, 1])
    }

    func testAufDenEigenenPlatzZiehenAendertNichts() {
        let neu = Ordnen.verschieben(drei, von: IndexSet(integer: 1), nach: 1)
        XCTAssertEqual(neu.map(\.id), [1, 2, 3])
    }

    // --- Der Ordnen-Modus -------------------------------------------------

    /// **Eine Frage, die man beantworten muss, obwohl nichts passiert
    /// ist, erzieht Leute zum Wegklicken.** Wer eine Kachel anfasst und
    /// wieder loslässt, hat nichts geändert -- dann darf die Leiste mit
    /// „Nummern mitziehen?" nicht erscheinen.
    func testOhneBewegungIstNichtsGeaendert() {
        var stand = Ordnungsstand(drei)
        XCTAssertFalse(stand.geaendert)
        stand.verschieben(von: IndexSet(integer: 1), nach: 1)
        XCTAssertFalse(stand.geaendert)
    }

    func testNachEinerBewegungIstEtwasGeaendert() {
        var stand = Ordnungsstand(drei)
        stand.verschieben(von: IndexSet(integer: 0), nach: 2)
        XCTAssertTrue(stand.geaendert)
        XCTAssertEqual(stand.kennungen, [2, 1, 3])
    }

    /// Zurücknehmen bringt den Stand beim Betreten zurück -- nicht den
    /// vorletzten. Wer sich verzogen hat, will die Liste zurück, wie sie
    /// war, und nicht einen Schritt davon.
    func testZuruecknehmenGehtBisZumAnfang() {
        var stand = Ordnungsstand(drei)
        stand.verschieben(von: IndexSet(integer: 0), nach: 2)
        stand.verschieben(von: IndexSet(integer: 2), nach: 0)
        stand.zuruecknehmen()
        XCTAssertEqual(stand.kennungen, [1, 2, 3])
        XCTAssertFalse(stand.geaendert)
    }

    /// Hin und zurück ist keine Änderung, auch wenn zweimal gezogen wurde.
    func testHinUndZurueckIstKeineAenderung() {
        var stand = Ordnungsstand(drei)
        stand.verschieben(von: IndexSet(integer: 0), nach: 3)
        stand.verschieben(von: IndexSet(integer: 2), nach: 0)
        XCTAssertFalse(stand.geaendert)
    }

    /// Die Vorschau ist für BEIDE Antworten da, nicht erst nach dem
    /// Drücken. Die Frage ist nur zu beantworten, wenn beide Fassungen
    /// nebeneinanderstehen.
    func testDieVorschauZeigtBeideFassungen() {
        var stand = Ordnungsstand(drei)
        stand.verschieben(von: IndexSet(integer: 2), nach: 0)
        XCTAssertEqual(stand.vorschau(nummernMitziehen: false).map(\.nummer),
                       [3, 1, 2])
        XCTAssertEqual(stand.vorschau(nummernMitziehen: true).map(\.nummer),
                       [1, 2, 3])
    }

    // --- Die Liste in die neue Reihenfolge bringen ------------------------

    private var dreiPlays: [Modell.PlayKurz] {
        [Modell.PlayKurz(id: 1, name: "Slant", nummer: 1, position: 1),
         Modell.PlayKurz(id: 2, name: "Mesh", nummer: 2, position: 2),
         Modell.PlayKurz(id: 3, name: "Go", nummer: 3, position: 3)]
    }

    func testSortierenFolgtDenKennungen() {
        let neu = Ordnen.sortieren(dreiPlays, nach: [3, 1, 2], id: \.id)
        XCTAssertEqual(neu.map(\.name), ["Go", "Slant", "Mesh"])
    }

    /// **Was fehlt, fällt weg -- ausdrücklich und nicht am Ende
    /// angehängt.** Eine Kennung ohne Play heißt, dass sich die Liste
    /// unter der Hand geändert hat. Stillschweigend anzuhängen ergäbe
    /// eine Ansicht, die vollständig aussieht und falsch geordnet ist.
    func testEineUnbekannteKennungFaelltWeg() {
        let neu = Ordnen.sortieren(dreiPlays, nach: [3, 99, 1], id: \.id)
        XCTAssertEqual(neu.map(\.id), [3, 1])
    }

    func testEinPlayOhneKennungInDerListeFaelltWeg() {
        let neu = Ordnen.sortieren(dreiPlays, nach: [2], id: \.id)
        XCTAssertEqual(neu.map(\.id), [2])
    }

    /// Die Vorschau wird nach KENNUNG nachgeschlagen. Nach Stelle wäre
    /// sie um eins verschoben, sobald die beiden Listen sich um einen
    /// Eintrag unterscheiden -- und sähe trotzdem plausibel aus.
    func testDieVorschauLaesstSichNachKennungNachschlagen() {
        var stand = Ordnungsstand(dreiPlays.map(\.alsPlatz))
        stand.verschieben(von: IndexSet(integer: 2), nach: 0)
        let karte = stand.vorschauNummern(nummernMitziehen: true)
        // Go stand auf 3 und steht jetzt vorn, bekommt also die 1.
        XCTAssertEqual(karte[3], .some(.some(1)))
        XCTAssertEqual(karte[1], .some(.some(2)))
        XCTAssertEqual(karte[2], .some(.some(3)))
    }

    func testOhneMitziehenBleibenDieNummernInDerKarte() {
        var stand = Ordnungsstand(dreiPlays.map(\.alsPlatz))
        stand.verschieben(von: IndexSet(integer: 2), nach: 0)
        let karte = stand.vorschauNummern(nummernMitziehen: false)
        XCTAssertEqual(karte[3], .some(.some(3)))
        XCTAssertEqual(karte[1], .some(.some(1)))
    }

    func testDerStandBringtDiePlaysInSeineReihenfolge() {
        var stand = Ordnungsstand(dreiPlays.map(\.alsPlatz))
        stand.verschieben(von: IndexSet(integer: 2), nach: 0)
        XCTAssertEqual(stand.inReihenfolge(dreiPlays).map(\.name),
                       ["Go", "Slant", "Mesh"])
    }

    // --- Ein Play liefert seine drei Zahlen selbst ------------------------

    func testEinPlayWirdZumPlatz() {
        let play = Modell.PlayKurz(id: 7, name: "Slant", nummer: 4,
                                   position: 9)
        XCTAssertEqual(play.alsPlatz,
                       Ordnen.Platz(id: 7, platz: 9, nummer: 4))
    }

    // --- Helfer -----------------------------------------------------------

    private func plaetze(_ fall: OrdnenProben.Fall) -> [Ordnen.Platz] {
        fall.plaetze.indices.map { i in
            Ordnen.Platz(id: i + 1, platz: fall.plaetze[i],
                         nummer: fall.nummern[i])
        }
    }

    private func vergleichen(_ ergebnis: [Ordnen.Platz],
                             _ erwartet: [(platz: Int, nummer: Int?)],
                             fall: OrdnenProben.Fall, was: String) {
        XCTAssertEqual(ergebnis.count, erwartet.count,
                       "\(fall.name) (\(was)): Länge")
        for (i, (ist, soll)) in zip(ergebnis, erwartet).enumerated() {
            XCTAssertEqual(ist.platz, soll.platz,
                           "\(fall.name) (\(was)), Stelle \(i): Platz. "
                           + fall.hinweis)
            XCTAssertEqual(ist.nummer, soll.nummer,
                           "\(fall.name) (\(was)), Stelle \(i): Nummer. "
                           + fall.hinweis)
        }
    }
}
