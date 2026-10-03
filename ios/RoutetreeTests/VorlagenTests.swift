// Aufstellungs-Vorlagen in der App (R110.5).
//
// WAS GEFEHLT HAT. Der Browser bietet seit jeher sieben
// Offense-Aufstellungen und vier Deckungen an; die App kannte nur die
// GESPEICHERTEN. Wer dort ein Playbook neu anlegte, hatte gar keine
// Vorlage und musste fünf Figuren von Hand setzen, bevor er die erste
// Route zeichnen konnte.
//
// GEMESSEN WIRD DIE RECHNUNG. Die Querlage kommt fertig vom Server, die
// Längslage entsteht hier -- und ein Vorzeichen entscheidet, ob der
// Quarterback hinter dem Center steht oder in der Verteidigung.

import XCTest
@testable import Routetree

final class VorlagenblockTests: XCTestCase {

    private let feld = Feld.afvd

    private func vorlage(_ schluessel: String = "spread",
                         leute: [Modell.Vorlagenplatz]) -> Modell.Vorlage {
        // Über den Entschlüssler und nicht über einen Init: So wird
        // nebenbei gemessen, dass die Feldnamen des Servers ankommen.
        let json = """
        {"schluessel": "\(schluessel)", "name": "Spread",
         "hinweis": "Drei Empfänger verteilt",
         "leute": [\(leute.map { platz in
            """
            {"id": "\(platz.id)", "role": "\(platz.role)",
             "label": "\(platz.label)", "zurueck": \(platz.zurueck),
             "y": \(platz.y)}
            """
         }.joined(separator: ","))]}
        """
        return try! JSONDecoder().decode(Modell.Vorlage.self,
                                         from: Data(json.utf8))
    }

    private func platz(_ id: String, zurueck: Double, y: Double)
        -> Modell.Vorlagenplatz {
        Modell.Vorlagenplatz(id: id, role: "QB", label: "Q",
                             zurueck: zurueck, y: y)
    }

    // MARK: - Die Längslage

    func testBeimAngriffGehtZurueckNACHHINTEN() {
        // Der Quarterback steht HINTER dem Center -- also gegen die
        // Angriffsrichtung. Ein Vorzeichen, und er stünde in der
        // Verteidigung.
        let leute = Vorlagenblock.offense(
            vorlage(leute: [platz("o_qb", zurueck: 5, y: 12.5)]),
            los: 35, richtung: 1, feld: feld)
        XCTAssertEqual(leute.first?.x ?? .nan, 30, accuracy: 0.001)
    }

    func testBeiDerVerteidigungNACHVORN() {
        let leute = Vorlagenblock.defense(
            vorlage(leute: [platz("d_r", zurueck: 7, y: 12.5)]),
            los: 35, richtung: 1, feld: feld)
        XCTAssertEqual(leute.first?.x ?? .nan, 42, accuracy: 0.001)
    }

    func testUndAndersHerumAndersHerum() {
        let leute = Vorlagenblock.offense(
            vorlage(leute: [platz("o_qb", zurueck: 5, y: 12.5)]),
            los: 35, richtung: -1, feld: feld)
        XCTAssertEqual(leute.first?.x ?? .nan, 40, accuracy: 0.001)
    }

    // MARK: - Die Querlage

    func testSieGiltFuerRichtungPlusEinsUndWirdSonstGespiegelt() {
        // Sonst stünde „Trips rechts" im Diagramm links -- und genau
        // das zeigt der Trainer der Mannschaft.
        let rechts = Vorlagenblock.offense(
            vorlage(leute: [platz("o_x", zurueck: 0, y: 2.5)]),
            los: 35, richtung: 1, feld: feld)
        let links = Vorlagenblock.offense(
            vorlage(leute: [platz("o_x", zurueck: 0, y: 2.5)]),
            los: 35, richtung: -1, feld: feld)
        XCTAssertEqual(rechts.first?.y ?? .nan, 2.5, accuracy: 0.001)
        XCTAssertEqual(links.first?.y ?? .nan, feld.breite - 2.5,
                       accuracy: 0.001)
    }

    func testNiemandLandetAusserhalbDesFeldes() {
        let leute = Vorlagenblock.offense(
            vorlage(leute: [platz("o_x", zurueck: 999, y: -50)]),
            los: 35, richtung: 1, feld: feld)
        XCTAssertGreaterThanOrEqual(leute.first?.x ?? -1, 0)
        XCTAssertGreaterThanOrEqual(leute.first?.y ?? -1, 0)
    }

    // MARK: - Was stehen bleibt

    func testDieVerteidigungBleibtBeimAngriffswechsel() {
        // Wer die Angriffsformation wechselt, wechselt nicht die
        // Deckung, gegen die er sie zeichnet.
        let zeichnung = Zeichnung(spieler: [
            Zeichnung.Spieler(id: "d_r", seite: .defense, kuerzel: "R",
                              x: 42, y: 12.5),
        ])
        let neu = Vorlagenblock.mitOffense(
            vorlage(leute: [platz("o_qb", zurueck: 5, y: 12.5)]),
            in: zeichnung, los: 35, richtung: 1, feld: feld)
        XCTAssertTrue(neu.contains { $0.id == "d_r" })
        XCTAssertTrue(neu.contains { $0.id == "o_qb" })
    }

    func testUndUmgekehrtDerAngriff() {
        let zeichnung = Zeichnung(spieler: [
            Zeichnung.Spieler(id: "o_qb", seite: .offense, kuerzel: "Q",
                              x: 30, y: 12.5),
        ])
        let neu = Vorlagenblock.mitDefense(
            vorlage(leute: [platz("d_r", zurueck: 7, y: 12.5)]),
            in: zeichnung, los: 35, richtung: 1, feld: feld)
        XCTAssertTrue(neu.contains { $0.id == "o_qb" })
        XCTAssertTrue(neu.contains { $0.id == "d_r" })
    }

    func testDieFarbenDerSpielerBleiben() {
        // Wer seinem X eine Farbe gegeben hat, hat das für den Spieler
        // getan und nicht für die Aufstellung.
        let zeichnung = Zeichnung(spieler: [
            Zeichnung.Spieler(id: "o_qb", seite: .offense, kuerzel: "Q",
                              farbe: "#C24132", x: 30, y: 12.5),
        ])
        let neu = Vorlagenblock.mitOffense(
            vorlage(leute: [platz("o_qb", zurueck: 5, y: 12.5)]),
            in: zeichnung, los: 35, richtung: 1, feld: feld)
        XCTAssertEqual(neu.first { $0.id == "o_qb" }?.farbe, "#C24132")
    }

    // MARK: - Defense entfernen

    func testSieGehtWeg() {
        let zeichnung = Zeichnung(spieler: [
            Zeichnung.Spieler(id: "o_qb", seite: .offense, kuerzel: "Q",
                              x: 30, y: 12.5),
            Zeichnung.Spieler(id: "d_r", seite: .defense, kuerzel: "R",
                              x: 42, y: 12.5),
        ])
        let uebrig = Vorlagenblock.ohneDefense(zeichnung)
        XCTAssertEqual(uebrig.map(\.id), ["o_qb"])
    }

    func testOhneDefenseSagtDerBlockDasAuchSo() {
        // Ein lautloses Nichts wäre keine Auskunft.
        var b = Zeichenblock(
            zeichnung: Zeichnung(spieler: [
                Zeichnung.Spieler(id: "o_qb", seite: .offense, kuerzel: "Q",
                                  x: 30, y: 12.5),
            ]),
            projektion: Projektion.fuerDieApp(feld: feld, los: 35,
                                              richtung: 1))
        XCTAssertFalse(b.defenseEntfernen())
        XCTAssertNotNil(b.meldung)
    }

    func testUndSonstIstEsEinSchrittImVerlauf() {
        var b = Zeichenblock(
            zeichnung: Zeichnung(spieler: [
                Zeichnung.Spieler(id: "o_qb", seite: .offense, kuerzel: "Q",
                                  x: 30, y: 12.5),
                Zeichnung.Spieler(id: "d_r", seite: .defense, kuerzel: "R",
                                  x: 42, y: 12.5),
            ]),
            projektion: Projektion.fuerDieApp(feld: feld, los: 35,
                                              richtung: 1))
        XCTAssertTrue(b.defenseEntfernen())
        XCTAssertEqual(b.zeichnung.spieler.count, 1)
        b.rueckgaengig()
        XCTAssertEqual(b.zeichnung.spieler.count, 2)
    }
}
