import XCTest
@testable import Routetree

/// Meinen App und Server dieselbe Zeichnung?
///
/// `Zeichnung.swift` behauptet, das Format aus
/// `backend/designer/schema.py` zu lesen. Behaupten kann das jede Datei.
/// Hier laufen echte Server-Plays durch das Swift-Modell und wieder
/// hinaus, und das Ergebnis muss zeichengleich sein.
///
/// **Der Fehler, für den dieser Test gebaut ist.** Kennt Swift ein Feld
/// nicht, fällt es beim Speichern still weg. Wer in der App einen
/// Spieler verschiebt, löscht dann die Verzögerung einer Route, die
/// jemand im Browser gesetzt hat. Es gibt keine Fehlermeldung, keinen
/// roten Bau -- der Play sieht nur beim Abspielen anders aus, Wochen
/// später.
final class ZeichnungTests: XCTestCase {

    private func lesen(_ json: String) throws -> Zeichnung {
        try JSONDecoder().decode(Zeichnung.self,
                                 from: Data(json.utf8))
    }

    /// Als Wörterbuch, nicht als Zeichenkette: Die Reihenfolge der
    /// Schlüssel in einer JSON-Ausgabe ist beliebig, der Inhalt nicht.
    private func alsObjekt(_ daten: Data) throws -> NSDictionary {
        try XCTUnwrap(JSONSerialization.jsonObject(with: daten)
                        as? NSDictionary)
    }

    // MARK: - Hin und zurück

    func test_jeder_bibliotheks_play_kommt_gleich_wieder_heraus() throws {
        for probe in ZeichnungProben.alle {
            let zeichnung = try lesen(probe.json)
            let hinaus = try JSONEncoder().encode(zeichnung)

            let vorher = try alsObjekt(Data(probe.json.utf8))
            let nachher = try alsObjekt(hinaus)
            XCTAssertEqual(vorher, nachher,
                           "„\(probe.schluessel)“ verliert oder ändert etwas")
        }
    }

    func test_zweimal_durch_aendert_nichts_mehr() throws {
        // Ein Formatwechsel, der beim ersten Durchlauf noch aufgeht und
        // beim zweiten kippt, wäre der unangenehmste Fall: Er fällt
        // nicht beim Speichern auf, sondern beim wiederholten Speichern.
        for probe in ZeichnungProben.alle {
            let einmal = try JSONEncoder().encode(try lesen(probe.json))
            let zweimal = try JSONEncoder().encode(
                try JSONDecoder().decode(Zeichnung.self, from: einmal))
            XCTAssertEqual(try alsObjekt(einmal), try alsObjekt(zweimal),
                           "„\(probe.schluessel)“ ist nicht stabil")
        }
    }

    // MARK: - Was gelesen wird, ist auch da

    func test_die_spieler_stehen_mit_kuerzel_und_seite_da() throws {
        let mesh = try lesen(ZeichnungProben.mesh)
        XCTAssertEqual(mesh.anzahl(.offense), 5, "5 gegen 5")
        XCTAssertTrue(mesh.spieler.contains { $0.id == "o_qb" })
        let qb = try XCTUnwrap(mesh.spieler.first { $0.id == "o_qb" })
        XCTAssertEqual(qb.kuerzel, "Q")
        XCTAssertEqual(qb.seite, .offense)
    }

    func test_die_linien_haengen_an_ihren_spielern() throws {
        let mesh = try lesen(ZeichnungProben.mesh)
        let linie = try XCTUnwrap(mesh.linie(von: "o_x"))
        XCTAssertEqual(linie.art, .route)
        XCTAssertGreaterThanOrEqual(linie.punkte.count, 2)
        // Eine Route beginnt dort, wo der Spieler steht. Wäre das nicht
        // so, hinge die Linie in der Luft.
        let x = try XCTUnwrap(mesh.spieler.first { $0.id == "o_x" })
        XCTAssertEqual(linie.punkte[0].x, x.x, accuracy: 0.001)
        XCTAssertEqual(linie.punkte[0].y, x.y, accuracy: 0.001)
    }

    func test_ein_block_ist_kein_pass() throws {
        // Die Arten stehen als Zeichenketten im JSON. Ein Tippfehler in
        // einem `rawValue` fällt sonst erst auf, wenn ein Ausdruck einen
        // Pfeil statt eines Querbalkens zeigt.
        let flood = try lesen(ZeichnungProben.flood)
        let block = try XCTUnwrap(flood.linien.first { $0.art == .block })
        XCTAssertEqual(block.spieler, "o_c")
    }

    // MARK: - Die Ränder

    func test_ein_leerer_play_ist_kein_fehler() throws {
        // Ein neu angelegter Play hat `data = {}`. Ohne diesen Fall
        // zeigte die App eine Fehlermeldung statt eines leeren Feldes --
        // und zwar genau beim ersten Play, den jemand anlegt.
        let leer = try lesen("{}")
        XCTAssertTrue(leer.spieler.isEmpty)
        XCTAssertTrue(leer.linien.isEmpty)
    }

    func test_eine_linie_ohne_spieler_geht() throws {
        let json = #"""
        {"players": [],
         "routes": [{"player": null, "kind": "zone", "end": "none",
                     "points": [{"x": 30, "y": 5}, {"x": 40, "y": 5},
                                {"x": 40, "y": 15}]}]}
        """#
        let zeichnung = try lesen(json)
        let zone = try XCTUnwrap(zeichnung.linien.first)
        XCTAssertNil(zone.spieler)
        XCTAssertEqual(zone.art, .zone)
        XCTAssertTrue(zone.istVollstaendig, "drei Punkte genügen der Zone")
    }

    func test_eine_zone_mit_zwei_punkten_ist_unvollstaendig() throws {
        // Dieselbe Regel wie in schema.validate_play_data. Der Editor
        // soll sie kennen, bevor der Server sie durchsetzt: Eine
        // Fehlermeldung nach dem Speichern ist die schlechteste Stelle,
        // um von einer Regel zu erfahren.
        let zone = Zeichnung.Linie(
            spieler: nil, art: .zone,
            punkte: [.init(x: 30, y: 5), .init(x: 40, y: 5)])
        XCTAssertFalse(zone.istVollstaendig)
        XCTAssertEqual(zone.mindestensPunkte, 3)

        let route = Zeichnung.Linie(
            spieler: "o_x", art: .route,
            punkte: [.init(x: 30, y: 5), .init(x: 40, y: 5)])
        XCTAssertTrue(route.istVollstaendig)
    }

    func test_fehlende_angaben_bekommen_die_vorgaben_des_servers() throws {
        // Der Server füllt `kind`, `end`, `curve`, `delay` und `speed`
        // auf, wenn sie fehlen. Die App muss dieselben Vorgaben nehmen,
        // sonst zeichnet sie ein aus dem Browser gespeichertes Play
        // anders als der Browser.
        let json = #"""
        {"players": [{"id": "o_x", "x": 35, "y": 2.5}],
         "routes": [{"player": "o_x",
                     "points": [{"x": 35, "y": 2.5}, {"x": 45, "y": 2.5}]}]}
        """#
        let zeichnung = try lesen(json)
        let spieler = try XCTUnwrap(zeichnung.spieler.first)
        XCTAssertEqual(spieler.seite, .offense, "Vorgabe ist die Offense")
        XCTAssertEqual(spieler.kuerzel, "?")

        let linie = try XCTUnwrap(zeichnung.linien.first)
        XCTAssertEqual(linie.art, .route)
        XCTAssertEqual(linie.ende, .arrow)
        XCTAssertFalse(linie.gebogen)
        XCTAssertEqual(linie.verzoegerung, 0)
        XCTAssertEqual(linie.tempo, 1)
    }

    func test_halbe_yards_ueberleben_den_weg() throws {
        // Auf halben Yards liegen die Aufstellungen, die ein Trainer
        // wirklich zeichnet -- der Fang rastet darauf. Ginge hier
        // Genauigkeit verloren, stünde die Offense in der App einen
        // halben Yard neben dem Ausdruck.
        let zeichnung = try lesen(ZeichnungProben.mesh)
        let y = try XCTUnwrap(zeichnung.spieler.first { $0.id == "o_y" })
        XCTAssertEqual(y.y, 7.5, accuracy: 0.0001)

        let zurueck = try JSONDecoder().decode(
            Zeichnung.self, from: try JSONEncoder().encode(zeichnung))
        let danach = try XCTUnwrap(zurueck.spieler.first { $0.id == "o_y" })
        XCTAssertEqual(danach.y, 7.5, accuracy: 0.0001)
    }

    // MARK: - Die Stücke einer Linie (R45)

    func test_eine_gerade_route_hat_genau_ein_stueck() throws {
        // DER ABSTURZ VOM 08.09.2026. `abschnitte` rechnete den Bereich
        // `1...(punkte.count - 2)`; bei zwei Punkten ist das `1...0`,
        // und ein Bereich, dessen Ende vor seinem Anfang liegt, bricht
        // in Swift das Programm ab. Getroffen hat es den häufigsten Fall
        // überhaupt: die gerade Route.
        //
        // Gemerkt hat es niemand, weil `abschnitte` in keinem Test
        // vorkam -- die Linien wurden angelegt und auf `istVollstaendig`
        // geprüft, nie gezeichnet.
        let gerade = Zeichnung.Linie(
            spieler: "o_x", art: .route,
            punkte: [.init(x: 30, y: 5), .init(x: 30, y: 15)])
        let stuecke = gerade.abschnitte
        XCTAssertEqual(stuecke.count, 1)
        XCTAssertEqual(stuecke.first?.art, .route)
        XCTAssertEqual(stuecke.first?.punkte.count, 2)
    }

    func test_eine_option_mit_zwei_punkten_stuerzt_nicht_ab() throws {
        // Derselbe Fall, so wie Niklas ihn getroffen hat: Eine
        // Option-Route setzt an einem Punkt an und hat nach dem ersten
        // Tipp genau zwei Punkte.
        let option = Zeichnung.Linie(
            spieler: "o_x", art: .option,
            punkte: [.init(x: 30, y: 15), .init(x: 24, y: 21)])
        XCTAssertEqual(option.abschnitte.count, 1)
        XCTAssertEqual(option.teilstellen, 0)
    }

    func test_ein_motion_vorlauf_teilt_die_linie() throws {
        var linie = Zeichnung.Linie(
            spieler: "o_z", art: .route,
            punkte: [.init(x: 40, y: 2), .init(x: 30, y: 2),
                     .init(x: 30, y: 12)])
        linie.motionBis = 1
        let stuecke = linie.abschnitte
        XCTAssertEqual(stuecke.count, 2)
        XCTAssertEqual(stuecke.first?.art, .motion)
        XCTAssertEqual(stuecke.last?.art, .route)
        // Der Knick gehört BEIDEN Stücken, sonst klafft dort eine Lücke.
        XCTAssertEqual(stuecke.first?.punkte.count, 2)
        XCTAssertEqual(stuecke.last?.punkte.count, 2)
    }

    func test_ein_unsinniger_vorlauf_wird_ignoriert_und_bricht_nicht_ab() throws {
        // Ein `motionBis`, das über die Linie hinausgeht, kann aus einer
        // älteren Zeichnung kommen, deren Punkte jemand gelöscht hat.
        // Es darf ein Stück ergeben und keinen Abbruch.
        var linie = Zeichnung.Linie(
            spieler: "o_z", art: .route,
            punkte: [.init(x: 40, y: 2), .init(x: 30, y: 2)])
        linie.motionBis = 5
        XCTAssertEqual(linie.abschnitte.count, 1)
        linie.motionBis = -3
        XCTAssertEqual(linie.abschnitte.count, 1)
    }

    func test_eine_zone_wird_nie_geteilt() throws {
        var zone = Zeichnung.Linie(
            spieler: nil, art: .zone,
            punkte: [.init(x: 20, y: 5), .init(x: 30, y: 5),
                     .init(x: 30, y: 15)])
        zone.motionBis = 1
        XCTAssertEqual(zone.abschnitte.count, 1,
                       "eine Fläche hat keinen Vorlauf")
    }

    func test_alle_bibliotheks_plays_sind_dabei() {
        // Sonst prüfte der Hin-und-Rück-Test irgendwann eine Auswahl,
        // und niemand merkte, dass die Hälfte fehlt.
        XCTAssertEqual(ZeichnungProben.alle.count, 10,
                       "die zehn Konzepte aus bibliothek.py")
    }
}
