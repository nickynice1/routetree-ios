// Was im Funkloch auf dem Gerät bleibt (R110.4).
//
// WAS HIER GEMESSEN WIRD, IST ARBEIT. Der Browser hält einen
// ungesicherten Stand seit R4 in `localStorage` und fragt beim nächsten
// Öffnen nach. In der App gab es nur die Fehlermeldung -- App zu heisst
// Arbeit weg, und zwar ausgerechnet dort, wo das Offline-Argument
// dieses Produkts herkommt.

import XCTest
@testable import Routetree

final class EntwurfslagerTests: XCTestCase {

    private let play = 4711

    override func setUp() {
        super.setUp()
        Entwurfslager.vergessen(play: play)
    }

    override func tearDown() {
        Entwurfslager.vergessen(play: play)
        super.tearDown()
    }

    private func zeichnung(x: Double) -> Zeichnung {
        Zeichnung(spieler: [
            Zeichnung.Spieler(id: "o_x", seite: .offense, kuerzel: "X",
                              x: x, y: 5),
        ])
    }

    private func entwurf(version: Int = 3, x: Double = 30,
                         name: String = "Spread Mesh")
        -> Entwurfslager.Entwurf {
        var angaben = Playangabenstand()
        angaben.name = name
        return Entwurfslager.Entwurf(
            play: play, version: version, zeit: Date(),
            zeichnung: zeichnung(x: x), los: 35, richtung: 1,
            angaben: angaben)
    }

    // MARK: - Hinlegen und holen

    func testWasHingelegtWirdKommtZurueck() {
        Entwurfslager.merken(entwurf())
        XCTAssertEqual(Entwurfslager.holen(play: play)?.zeichnung,
                       zeichnung(x: 30))
    }

    func testEsTraegtALLES_undNichtNurDieZeichnung() {
        // Ein Entwurf, der nur die Zeichnung rettet, rettet die Hälfte
        // -- und die andere fehlt danach, ohne dass es jemandem
        // auffällt.
        Entwurfslager.merken(entwurf(x: 12, name: "Trips Right"))
        let zurueck = Entwurfslager.holen(play: play)
        XCTAssertEqual(zurueck?.los, 35)
        XCTAssertEqual(zurueck?.richtung, 1)
        XCTAssertEqual(zurueck?.angaben.name, "Trips Right")
    }

    func testJederPlayHatSeinEigenes() {
        Entwurfslager.merken(entwurf())
        XCTAssertNil(Entwurfslager.holen(play: play + 1))
    }

    func testVergessenVergisst() {
        Entwurfslager.merken(entwurf())
        Entwurfslager.vergessen(play: play)
        XCTAssertNil(Entwurfslager.holen(play: play))
    }

    // MARK: - Was damit zu tun ist

    func testOhneEntwurfGibtEsNichtsZuFragen() {
        XCTAssertEqual(
            Entwurfslager.befund(fuer: play, serverVersion: 3,
                                 serverZeichnung: zeichnung(x: 30)),
            .nichts)
    }

    func testWasOhnehinSchonSoDastehtWirdNichtAngeboten() {
        // Eine Frage, deren beide Antworten dasselbe bewirken, ist eine
        // Frage zu viel.
        Entwurfslager.merken(entwurf(version: 3, x: 30))
        XCTAssertEqual(
            Entwurfslager.befund(fuer: play, serverVersion: 3,
                                 serverZeichnung: zeichnung(x: 30)),
            .nichts)
    }

    func testWasNeuIstWirdAngeboten() {
        Entwurfslager.merken(entwurf(version: 3, x: 12))
        guard case .anbieten(let e) = Entwurfslager.befund(
            fuer: play, serverVersion: 3,
            serverZeichnung: zeichnung(x: 30)) else {
            return XCTFail("nicht angeboten")
        }
        XCTAssertEqual(e.zeichnung, zeichnung(x: 12))
    }

    func testEinFREMDERStandDazwischenIstEinKonflikt() {
        // DER FALL, DEN MAN NICHT STILL ZURUECKSPIELEN DARF. Wer den
        // Entwurf hier ohne Frage einspielte, überschriebe die Arbeit
        // dessen, der inzwischen gespeichert hat -- und der sitzt
        // gerade nicht davor.
        Entwurfslager.merken(entwurf(version: 3, x: 12))
        guard case .veraltet = Entwurfslager.befund(
            fuer: play, serverVersion: 4,
            serverZeichnung: zeichnung(x: 30)) else {
            return XCTFail("nicht als veraltet erkannt")
        }
    }

    // MARK: - Der Block nimmt ihn an

    func testDasUebernehmenIstEinSchrittImVerlauf() {
        // Wer sich vertut und den falschen Stand zurückholt, kommt mit
        // einem Druck wieder heraus. Eine Wiederherstellung, die sich
        // nicht zurücknehmen lässt, ist dieselbe Sackgasse wie ein
        // Löschen ohne Rückfrage.
        var b = Zeichenblock(
            zeichnung: Zeichnung(),
            projektion: Projektion.fuerDieApp(feld: Feld.afvd,
                                              los: Feld.afvd.mitte,
                                              richtung: 1))
        var angaben = Playangabenstand()
        angaben.name = "Zurückgeholt"
        b.entwurfUebernehmen(zeichnung: zeichnung(x: 12), los: 20,
                             richtung: -1, angaben: angaben)
        XCTAssertEqual(b.zeichnung, zeichnung(x: 12))
        XCTAssertEqual(b.projektion.los, 20)
        XCTAssertEqual(b.projektion.richtung, -1)
        XCTAssertEqual(b.angaben.name, "Zurückgeholt")

        XCTAssertTrue(b.kannRueckgaengig)
        b.rueckgaengig()
        XCTAssertEqual(b.zeichnung, Zeichnung())
        XCTAssertEqual(b.projektion.los, Feld.afvd.mitte)
        XCTAssertEqual(b.projektion.richtung, 1)
    }

    func testEsGiltDanachAlsUngesichert() {
        // Sonst läge der zurückgeholte Stand da und ginge nie zum
        // Server -- gerettet und trotzdem verloren.
        var b = Zeichenblock(
            zeichnung: Zeichnung(),
            projektion: Projektion.fuerDieApp(feld: Feld.afvd,
                                              los: Feld.afvd.mitte,
                                              richtung: 1))
        b.gesichert(bis: b.stand)
        XCTAssertFalse(b.geaendert)
        b.entwurfUebernehmen(zeichnung: zeichnung(x: 12), los: 20,
                             richtung: 1, angaben: Playangabenstand())
        XCTAssertTrue(b.geaendert)
    }
}
