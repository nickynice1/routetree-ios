import XCTest
@testable import RoutetreeUhr

/// Kommt auf der Uhr an, was das Telefon geschickt hat? (R140)
///
/// **Die Stelle, an der es lautlos schiefgeht.** Zwischen Telefon und
/// Uhr liegt eine Funkstrecke und ein JSON. Fällt dabei ein Feld weg,
/// gibt es keine Fehlermeldung und keinen roten Bau -- der Play sieht
/// am Handgelenk nur anders aus als auf dem Telefon, und das merkt
/// jemand am Spielfeldrand.
///
/// Deshalb läuft hier ein vollständiges Paket hinaus und wieder
/// herein, und das Ergebnis muss gleich sein.
final class UhrpaketTests: XCTestCase {

    private func beispiel() -> Uhrpaket {
        var zeichnung = Zeichnung()
        zeichnung.spieler = [
            Zeichnung.Spieler(id: "o_qb", seite: .offense, rolle: "QB",
                              kuerzel: "QB", farbe: nil, notiz: "",
                              x: 20, y: 12.5),
            Zeichnung.Spieler(id: "o_x", seite: .offense, rolle: "X",
                              kuerzel: "X", farbe: "#ffcc00",
                              notiz: "gegen Zone kurz sitzen",
                              x: 22, y: 4),
            Zeichnung.Spieler(id: "d_c1", seite: .defense, rolle: "C1",
                              kuerzel: "C1", farbe: nil, notiz: "",
                              x: 27, y: 4),
        ]
        zeichnung.linien = [
            Zeichnung.Linie(
                spieler: "o_x", art: .route, ende: .arrow,
                beschriftung: "Go",
                punkte: [.init(x: 22, y: 4), .init(x: 34, y: 4)]),
        ]

        let play = Uhrpaket.Play(id: "17", name: "Trips Rechts Go",
                                 los: 22, richtung: 1,
                                 zeichnung: zeichnung)
        let kategorie = Uhrpaket.Kategorie(id: "3", name: "3rd & long",
                                           farbe: "#1A5364",
                                           plays: [play])
        let heft = Uhrpaket.Heft(id: "9", name: "Saison 2026",
                                 spielform: "flag5", feld: Feld.afvd,
                                 kategorien: [kategorie])
        return Uhrpaket(stand: Date(timeIntervalSince1970: 1_790_000_000),
                        hefte: [heft])
    }

    func test_hin_und_zurueck_ist_gleich() throws {
        let vorher = beispiel()
        let daten = try vorher.schreiben()
        let nachher = try XCTUnwrap(Uhrpaket.lesen(daten))
        XCTAssertEqual(vorher, nachher)
    }

    func test_die_zeichnung_ueberlebt_vollstaendig() throws {
        let daten = try beispiel().schreiben()
        let nachher = try XCTUnwrap(Uhrpaket.lesen(daten))
        let play = try XCTUnwrap(nachher.hefte.first?.kategorien.first?
            .plays.first)

        XCTAssertEqual(play.zeichnung.spieler.count, 3)
        XCTAssertEqual(play.zeichnung.linien.count, 1)
        // DIE NOTIZ IST DER EMPFINDLICHE TEIL. Sie ist als einziges
        // Feld mit einem Rückfall auf leer versehen; ein Tippfehler im
        // Schlüssel fiele deshalb nirgends auf.
        XCTAssertEqual(play.zeichnung.spieler[1].notiz,
                       "gegen Zone kurz sitzen")
        XCTAssertEqual(play.zeichnung.spieler[1].farbe, "#ffcc00")
        XCTAssertEqual(play.zeichnung.linien[0].beschriftung, "Go")
        XCTAssertEqual(play.zeichnung.linien[0].ende, .arrow)
    }

    func test_die_feldmasse_reisen_mit() throws {
        // Ein Heft auf kleinem Feld. Ginge das Maß verloren, zeichnete
        // die Uhr die Normmaße -- und die Aufstellung stünde fünf Yards
        // neben der Seitenlinie.
        var paket = beispiel()
        let klein = Feld(spielLaenge: 40, endzone: 8, breite: 20,
                         keinLauf: 5, rush: 7, hashAbstand: nil)
        paket.hefte[0] = Uhrpaket.Heft(id: paket.hefte[0].id,
                                       name: paket.hefte[0].name,
                                       spielform: paket.hefte[0].spielform,
                                       feld: klein,
                                       kategorien: paket.hefte[0].kategorien)
        let nachher = try XCTUnwrap(Uhrpaket.lesen(paket.schreiben()))
        XCTAssertEqual(nachher.hefte[0].feld, klein)
    }

    /// Ein halb gelesenes Playbook ist schlimmer als ein altes.
    func test_eine_fremde_fassung_wird_verworfen() throws {
        var paket = beispiel()
        paket.fassung = Uhrpaket.aktuelleFassung + 1
        XCTAssertNil(Uhrpaket.lesen(try paket.schreiben()))
    }

    func test_unsinn_stuerzt_nicht_ab() {
        XCTAssertNil(Uhrpaket.lesen(Data("keine Ahnung".utf8)))
        XCTAssertNil(Uhrpaket.lesen(Data()))
    }

    func test_das_leere_paket_ist_leer() {
        let leer = Uhrpaket.leer()
        XCTAssertTrue(leer.hefte.isEmpty)
        XCTAssertEqual(leer.anzahlPlays, 0)
    }

    func test_die_plays_eines_hefts_stehen_quer_ueber_die_kategorien() {
        let paket = beispiel()
        XCTAssertEqual(paket.anzahlPlays, 1)
        XCTAssertEqual(paket.hefte[0].plays.count, 1)
    }
}
