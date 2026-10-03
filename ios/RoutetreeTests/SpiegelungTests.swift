import CoreGraphics
import XCTest
@testable import Routetree

/// Spiegelt die App wie der Server?
///
/// Die erwarteten Zahlen hat `schema.mirror_play` gerechnet, nicht diese
/// Datei: `scripts/zeichnung_swift.py` schickt die zehn Bibliotheks-Plays
/// durch den Server und legt das Ergebnis als Probe ab.
///
/// **Warum das gemessen wird.** Die Rechnung steht dreimal im Projekt
/// (Python, JavaScript, Swift), weil jede Seite sie sofort und ohne Netz
/// braucht. Drei Fassungen laufen auseinander, und der Unterschied fiele
/// erst auf, wenn derselbe Play aus der App anders im Playbook stünde als
/// aus dem Browser.
final class SpiegelungTests: XCTestCase {

    private let breite = Double(Feld.afvd.breite)

    private func lesen(_ json: String) throws -> Zeichnung {
        try JSONDecoder().decode(Zeichnung.self, from: Data(json.utf8))
    }

    // MARK: - Gegen den Server

    func test_jeder_play_spiegelt_wie_auf_dem_server() throws {
        for probe in ZeichnungProben.spiegelpaare {
            let hier = try lesen(probe.json).gespiegelt(breite: breite)
            let dort = try lesen(probe.gespiegelt)
            XCTAssertEqual(hier, dort,
                           "„\(probe.schluessel)“ spiegelt anders als der "
                           + "Server")
        }
    }

    func test_alle_zehn_paare_sind_dabei() {
        XCTAssertEqual(ZeichnungProben.spiegelpaare.count, 10)
    }

    // MARK: - Die Regeln

    func test_zweimal_gespiegelt_ist_wieder_das_original() throws {
        // Genau das ist bei Flag Football Playmaker X fehlerhaft, und
        // die Rezensionen nennen es. Ein Spiegeln, das man nicht
        // zurücknehmen kann, traut sich niemand zu benutzen.
        for probe in ZeichnungProben.alle {
            let original = try lesen(probe.json)
            let zurueck = original
                .gespiegelt(breite: breite)
                .gespiegelt(breite: breite)
            XCTAssertEqual(zurueck, original, probe.schluessel)
        }
    }

    func test_nur_die_querachse_dreht_sich() throws {
        // Ein Play nach rechts bleibt ein Play nach rechts. Drehte sich
        // auch die Länge, liefe die Offense plötzlich in die eigene
        // Endzone.
        let mesh = try lesen(ZeichnungProben.mesh)
        let gedreht = mesh.gespiegelt(breite: breite)
        for (vorher, nachher) in zip(mesh.spieler, gedreht.spieler) {
            XCTAssertEqual(vorher.x, nachher.x, accuracy: 0.000_1)
            XCTAssertEqual(nachher.y, breite - vorher.y, accuracy: 0.000_1)
        }
    }

    func test_alles_ausser_der_querlage_bleibt_stehen() throws {
        // Der Fehler, den das ausschließt: Wer beim Spiegeln eine neue
        // Linie baut statt die alte zu kopieren, verliert Beschriftung,
        // Verzögerung und Tempo -- und niemand sieht es, weil ein
        // gespiegelter Play ohnehin anders aussieht als vorher.
        let linie = Zeichnung.Linie(
            spieler: "o_x", art: .motion, ende: .tee, gebogen: true,
            beschriftung: "Sweep", verzoegerung: 0.4, tempo: 1.5,
            punkte: [.init(x: 35, y: 5), .init(x: 45, y: 20)])
        let zeichnung = Zeichnung(spieler: [
            Zeichnung.Spieler(id: "o_x", seite: .offense, rolle: "X",
                              kuerzel: "X", farbe: "#1A5364", x: 35, y: 5),
        ], linien: [linie])

        let gedreht = zeichnung.gespiegelt(breite: breite)
        let raus = try XCTUnwrap(gedreht.linien.first)
        XCTAssertEqual(raus.art, .motion)
        XCTAssertEqual(raus.ende, .tee)
        XCTAssertTrue(raus.gebogen)
        XCTAssertEqual(raus.beschriftung, "Sweep")
        XCTAssertEqual(raus.verzoegerung, 0.4)
        XCTAssertEqual(raus.tempo, 1.5)
        XCTAssertEqual(raus.spieler, "o_x")

        let wer = try XCTUnwrap(gedreht.spieler.first)
        XCTAssertEqual(wer.id, "o_x")
        XCTAssertEqual(wer.kuerzel, "X")
        XCTAssertEqual(wer.rolle, "X")
        XCTAssertEqual(wer.farbe, "#1A5364")
    }

    func test_gerundet_wird_auf_zwei_stellen_wie_beim_server() {
        // Bliebe `25 - 7.5` als 17.499999999999996 stehen, stünde nach
        // dem Sichern eine andere Zahl im Play als der Browser
        // geschrieben hätte.
        XCTAssertEqual(Zeichnung.gedreht(7.5, breite: 25), 17.5)
        XCTAssertEqual(Zeichnung.gedreht(0, breite: 25), 25)
        XCTAssertEqual(Zeichnung.gedreht(25, breite: 25), 0)
        XCTAssertEqual(Zeichnung.gedreht(12.34, breite: 25), 12.66)
    }

    func test_die_linie_bleibt_am_spieler_haengen() throws {
        // Der erste Punkt einer Route liegt auf der Figur. Spiegelte man
        // beide verschieden, hinge die Linie hinterher in der Luft.
        for probe in ZeichnungProben.alle {
            let gedreht = try lesen(probe.json).gespiegelt(breite: breite)
            for linie in gedreht.linien {
                guard let kennung = linie.spieler,
                      let wer = gedreht.spieler.first(where: {
                          $0.id == kennung
                      }),
                      let erster = linie.punkte.first else { continue }
                XCTAssertEqual(erster.y, wer.y, accuracy: 0.011,
                               "„\(probe.schluessel)“: \(kennung) hat seinen "
                               + "Weg verloren")
            }
        }
    }

    // MARK: - Im Editor

    private func block() -> Zeichenblock {
        let zeichnung = Zeichnung(spieler: [
            Zeichnung.Spieler(id: "o_x", seite: .offense, kuerzel: "X",
                              x: 35, y: 5),
        ], linien: [
            Zeichnung.Linie(spieler: "o_x", art: .route,
                            punkte: [.init(x: 35, y: 5), .init(x: 45, y: 5)]),
        ])
        return Zeichenblock(
            zeichnung: zeichnung,
            projektion: Projektion(feld: Feld.afvd, los: Feld.afvd.mitte,
                                   richtung: 1))
    }

    func test_der_editor_spiegelt_und_merkt_es_sich() {
        var b = block()
        b.spiegeln()

        XCTAssertEqual(b.zeichnung.spieler[0].y, breite - 5, accuracy: 0.000_1)
        XCTAssertTrue(b.geaendert)
        XCTAssertTrue(b.kannRueckgaengig, "Spiegeln muss zurückzunehmen sein")
        XCTAssertNotNil(b.meldung, "sonst merkt niemand, was passiert ist")

        b.rueckgaengig()
        XCTAssertEqual(b.zeichnung.spieler[0].y, 5, accuracy: 0.000_1)
    }

    func test_ein_leeres_feld_wird_nicht_gespiegelt() {
        var b = Zeichenblock(
            zeichnung: Zeichnung(),
            projektion: Projektion(feld: Feld.afvd, los: Feld.afvd.mitte,
                                   richtung: 1))
        b.spiegeln()
        XCTAssertFalse(b.geaendert)
        XCTAssertFalse(b.kannRueckgaengig,
                       "ein Schritt im Verlauf für nichts wäre ein "
                       + "Rückgängig, das nichts tut")
        XCTAssertNotNil(b.meldung)
    }

    func test_beim_spiegeln_faellt_die_angefangene_linie_weg() {
        // Sie hängt an einem Spieler, der eben noch woanders stand.
        var b = block()
        b.werkzeugSetzen(.linie(.route))
        b.tippen(b.projektion.aufBildschirm(x: 35, y: 5,
                                            groesse: CGSize(width: 370,
                                                            height: 300)),
                 groesse: CGSize(width: 370, height: 300))
        XCTAssertNotNil(b.entwurf)

        b.spiegeln()
        XCTAssertNil(b.entwurf)
        XCTAssertNil(b.auswahl)
    }
}
