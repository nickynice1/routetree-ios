// Wo der Ball liegt und wohin angegriffen wird (R110.3).
//
// WAS HIER GEMESSEN WIRD. Die App konnte die Lage des Balls bis zum
// 10.09.2026 gar nicht setzen -- ein Play, der nicht an der
// Mittellinie beginnt, liess sich am Telefon nicht anlegen. Der
// Browser hat den Regler seit dem ersten Tag, und die Sätze darunter
// sind dieselben; zwei Fassungen wären zwei Auskünfte über dieselbe
// Lage.

import XCTest
@testable import Routetree

final class SpiellageblockTests: XCTestCase {

    private let feld = Feld.afvd

    private func lage(_ los: Double, richtung: Int = 1)
        -> Spiellageblock.Lage {
        Spiellageblock.lage(los: los, richtung: richtung, feld: feld)
    }

    // MARK: - Wo der Ball liegt

    func testAufDerMitteHeisstEsMittellinie() {
        XCTAssertEqual(lage(feld.mitte).ort, "Mittellinie")
    }

    func testSonstDieYardZahlDerNAECHSTENTorlinie() {
        // Auf einem Footballfeld zählt man von der nächsten Torlinie:
        // Die 20-Yard-Linie gibt es zweimal.
        let links = lage(feld.torlinieLinks + 20)
        let rechts = lage(feld.torlinieRechts - 20)
        XCTAssertEqual(links.ort, rechts.ort)
        XCTAssertTrue(links.ort.contains("20"), links.ort)
    }

    // MARK: - Was der Satz sagt

    func testErNenntDieAngegriffeneEndzone() {
        XCTAssertTrue(lage(feld.mitte, richtung: 1).satz
                        .contains("rechte Endzone"))
        XCTAssertTrue(lage(feld.mitte, richtung: -1).satz
                        .contains("linke Endzone"))
    }

    func testAufDerMitteLiegtDerBallAufDerLineToGain() {
        XCTAssertTrue(lage(feld.mitte).satz.contains("Line to Gain"))
    }

    func testHinterDerMitteZaehltNurNochDieEndzone() {
        // Richtung rechts, Ball schon rechts der Mitte.
        let s = lage(feld.mitte + 8, richtung: 1).satz
        XCTAssertTrue(s.contains("überquert"), s)
    }

    func testDavorStehtDieEntfernung() {
        let s = lage(feld.mitte - 8, richtung: 1).satz
        XCTAssertTrue(s.contains("8"), s)
    }

    // MARK: - Die No-Run-Zone

    func testInDerZoneStehtDieWarnung() {
        let s = lage(feld.torlinieLinks + 1)
        XCTAssertTrue(s.inKeinLaufZone)
        XCTAssertTrue(s.satz.contains("No-Run-Zone"), s.satz)
    }

    func testAusserhalbNicht() {
        XCTAssertFalse(lage(feld.mitte).inKeinLaufZone)
    }

    func testWoEsKEINEZoneGIBT_stehtAuchKeineWarnung() {
        // DER FALL, DEN EINE NAIVE RECHNUNG FALSCH MACHT. Ist
        // `keinLauf` null, liegt jeder Ball rechnerisch „in" der Zone --
        // und die App warnte im Elfer-Tackle vor einer Regel, die es
        // dort nicht gibt. Dieselbe Falle wie bei den Situationen
        // (R110.8).
        var ohne = feld
        ohne.keinLauf = 0
        let s = Spiellageblock.lage(los: ohne.torlinieLinks + 1,
                                    richtung: 1, feld: ohne)
        XCTAssertFalse(s.inKeinLaufZone)
        XCTAssertFalse(s.satz.contains("No-Run-Zone"), s.satz)
    }

    // MARK: - Der Block setzt sie

    private func block() -> Zeichenblock {
        Zeichenblock(zeichnung: Zeichnung(),
                     projektion: Projektion.fuerDieApp(
                        feld: feld, los: feld.mitte, richtung: 1))
    }

    func testDieLosLaesstSichSetzen() {
        var b = block()
        b.losSetzen(feld.mitte - 10)
        XCTAssertEqual(b.projektion.los, feld.mitte - 10, accuracy: 0.001)
    }

    func testSieWirdGEKLEMMTUndNichtAbgelehnt() {
        // Ein Regler, der am Ende hängt, ist verständlicher als einer,
        // der zurückspringt.
        var b = block()
        b.losSetzen(-999)
        XCTAssertEqual(b.projektion.los, feld.torlinieLinks, accuracy: 0.001)
        b.losSetzen(9999)
        XCTAssertEqual(b.projektion.los, feld.torlinieRechts, accuracy: 0.001)
    }

    func testHinterDerTorlinieGibtEsKeinenSnap() {
        let b = block()
        XCTAssertEqual(b.losBereich.lowerBound, feld.torlinieLinks,
                       accuracy: 0.001)
        XCTAssertEqual(b.losBereich.upperBound, feld.torlinieRechts,
                       accuracy: 0.001)
    }

    func testDasVerschiebenGehtInDenVerlauf() {
        // Sonst liesse sich eine Lage nicht zurücknehmen -- und der
        // Regler ist das Bedienelement, an dem man sich am leichtesten
        // vertut.
        var b = block()
        b.losSetzen(feld.mitte - 12)
        XCTAssertTrue(b.kannRueckgaengig)
        b.rueckgaengig()
        XCTAssertEqual(b.projektion.los, feld.mitte, accuracy: 0.001)
    }

    func testDieselbeLageNochEinmalIstKeinSchritt() {
        // Ein Verlauf, der jeden Reglerzucker aufnimmt, ist beim
        // Zurückgehen nutzlos.
        var b = block()
        b.losSetzen(feld.mitte)
        XCTAssertFalse(b.kannRueckgaengig)
    }

    func testDieRichtungLaesstSichWechseln() {
        var b = block()
        b.richtungWechseln()
        XCTAssertEqual(b.projektion.richtung, -1)
        b.richtungWechseln()
        XCTAssertEqual(b.projektion.richtung, 1)
    }

    func testDerWechselIstNICHTDasSpiegeln() {
        // Wer beides verwechselt, bekommt eine Formation, die falsch
        // herum steht. Spiegeln tauscht links und rechts und lässt die
        // Richtung stehen.
        var b = block()
        b.spiegeln()
        XCTAssertEqual(b.projektion.richtung, 1,
                       "Spiegeln hat die Angriffsrichtung gedreht")
    }
}

/// Die Playangaben im Verlauf (R110.7).
///
/// **Ein Schritt je Bearbeitung und nicht je Tastendruck.** Das Blatt
/// schreibt laufend in `block.angaben`; ein Verlauf, der jeden
/// Buchstaben aufnimmt, ist beim Zurückgehen nutzlos -- man drückt
/// zwanzigmal und ist beim ersten Buchstaben des Namens.
final class PlayangabenImVerlaufTests: XCTestCase {

    private func block() -> Zeichenblock {
        Zeichenblock(zeichnung: Zeichnung(),
                     projektion: Projektion.fuerDieApp(
                        feld: Feld.afvd, los: Feld.afvd.mitte, richtung: 1))
    }

    func testEineBearbeitungIstEinSchritt() {
        var b = block()
        let vorher = b.angaben
        b.angaben.name = "Spread Mesh"
        b.angaben.name = "Spread Mesh Right"
        b.angaben.hinweise = "Gegen Cover 2"
        b.angabenGemerkt(vorher: vorher)
        XCTAssertTrue(b.kannRueckgaengig)
        b.rueckgaengig()
        XCTAssertEqual(b.angaben, vorher)
    }

    func testOhneAenderungGibtEsKeinenSchritt() {
        // Ein Schritt, der nichts zurückzunehmen hat, ist einer, den
        // man umsonst drückt. „Abbrechen" auf dem Blatt setzt den Stand
        // selbst zurück -- dann sind beide gleich.
        var b = block()
        b.angabenGemerkt(vorher: b.angaben)
        XCTAssertFalse(b.kannRueckgaengig)
    }

    func testDerSchrittNimmtDieZeichnungNICHTMit() {
        // Sonst nähme ein „Rückgängig" auf eine Umbenennung auch die
        // Linie zurück, die danach gezogen wurde.
        var b = block()
        let vorher = b.angaben
        b.angaben.name = "Trips Right"
        b.angabenGemerkt(vorher: vorher)
        let gezeichnet = b.zeichnung
        b.rueckgaengig()
        XCTAssertEqual(b.zeichnung, gezeichnet)
    }
}
