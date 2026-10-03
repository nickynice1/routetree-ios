// Zoom und Ausschnitt in der App (R110.6).
//
// Am Platz steht der Trainer mit dem Telefon in der Sonne und will eine
// Ecke des Feldes gross sehen. Der Browser kann das seit Langem, die
// App nicht -- und Playmaker-X-Nutzer vermissen beides.
//
// WAS HIER GEMESSEN WIRD, IST DIE RECHNUNG. Sie sitzt in `aufFlaeche`,
// also an der EINEN Stelle, an der die Projektion den Bildschirm
// trifft: Zeichnen und Finger gehen beide dort durch. Liefe eins davon
// an ihr vorbei, zeichnete man neben den Finger.

import XCTest
@testable import Routetree

final class AusschnittTests: XCTestCase {

    private let groesse = CGSize(width: 390, height: 700)

    private func block() -> Zeichenblock {
        Zeichenblock(zeichnung: Zeichnung(),
                     projektion: Projektion.fuerDieApp(
                        feld: Feld.afvd, los: Feld.afvd.mitte, richtung: 1))
    }

    // MARK: - Der Zoom

    func testOhneZoomIstAllesWieVorher() {
        let b = block()
        XCTAssertEqual(b.projektion.zoom, 1)
        XCTAssertFalse(b.ausschnittVerstellt)
    }

    func testNaeherHeranMachtDieFigurenGroesser() {
        var b = block()
        let vorher = b.projektion.aufFlaeche(groesse).faktor
        b.zoomSetzen(2, groesse: groesse)
        XCTAssertEqual(b.projektion.aufFlaeche(groesse).faktor, vorher * 2,
                       accuracy: 0.001)
    }

    func testWeiterAlsErlaubtGehtNicht() {
        // Ein Regler, der am Ende hängt, ist verständlicher als einer,
        // der zurückspringt.
        var b = block()
        b.zoomSetzen(99, groesse: groesse)
        XCTAssertEqual(b.projektion.zoom, Projektion.zoomMax)
        b.zoomSetzen(0.01, groesse: groesse)
        XCTAssertEqual(b.projektion.zoom, Projektion.zoomMin)
    }

    func testDerPunktUNTERDEMFINGERBleibtWoErIst() {
        // DER KERN. Wer auf eine Stelle zoomt, meint diese Stelle; ein
        // Zoom auf die Bildmitte schiebt sie aus dem Bild, und man
        // sucht sie danach wieder.
        //
        // GEMESSEN, WO ES FELD ZU VERSCHIEBEN GIBT: seitlich weit
        // aussen, senkrecht in der Mitte. Am oberen Rand liegt das Feld
        // schon ganz im Bild, dort gewinnt die Grenze -- und das ist
        // Absicht, siehe unten.
        var b = block()
        let finger = CGPoint(x: groesse.width * 0.8, y: groesse.height / 2)
        let vorher = b.projektion.vomBildschirm(finger, groesse: groesse)
        b.zoomSetzen(2.5, um: finger, groesse: groesse)
        let nachher = b.projektion.vomBildschirm(finger, groesse: groesse)
        XCTAssertEqual(nachher.x, vorher.x, accuracy: 0.35)
        XCTAssertEqual(nachher.y, vorher.y, accuracy: 0.35)
    }

    func testAberDerRandGewinntGegenDenFinger() {
        // Wer am Rand kneift, will nicht als Ergebnis eine leere Fläche
        // neben dem Feld. Die Grenze sticht deshalb den Finger -- der
        // Punkt darunter wandert dabei ein Stück, und das ist der
        // bessere der beiden Fehler.
        var b = block()
        b.zoomSetzen(2.5, um: CGPoint(x: 80, y: 140), groesse: groesse)
        let faktor = b.projektion.aufFlaeche(groesse).faktor
        let grenze = b.projektion.versatzgrenze(faktor: faktor,
                                                groesse: groesse)
        XCTAssertLessThanOrEqual(abs(Double(b.projektion.versatz.x)),
                                 Double(grenze.x) + 0.001)
        XCTAssertLessThanOrEqual(abs(Double(b.projektion.versatz.y)),
                                 Double(grenze.y) + 0.001)
        XCTAssertTrue(b.ausschnittVerstellt)
    }

    // MARK: - Zeichnen und Finger bleiben zusammen

    func testWasGEZEICHNETWirdUndWasDerFingerTRIFFT_istDasselbe() {
        // Ginge eins von beiden an `aufFlaeche` vorbei, zeichnete man
        // neben den Finger -- und zwar nur im gezoomten Zustand, also
        // genau dort, wo es keiner ausprobiert.
        var b = block()
        b.zoomSetzen(3, um: CGPoint(x: 120, y: 300), groesse: groesse)
        for (x, y) in [(35.0, 12.5), (30.0, 4.0), (44.0, 20.0)] {
            let schirm = b.projektion.aufBildschirm(x: x, y: y,
                                                    groesse: groesse)
            let zurueck = b.projektion.vomBildschirm(schirm, groesse: groesse)
            XCTAssertEqual(zurueck.x, x, accuracy: 0.01)
            XCTAssertEqual(zurueck.y, y, accuracy: 0.01)
        }
    }

    // MARK: - Das Verschieben

    func testOhneZoomLaesstSichNichtsSchieben() {
        // Da passt ohnehin alles ins Bild. Wer trotzdem schieben darf,
        // hat gleich eine schwarze Fläche vor sich.
        var b = block()
        b.verschieben(um: CGSize(width: 200, height: 200), groesse: groesse)
        XCTAssertEqual(Double(b.projektion.versatz.x), 0, accuracy: 0.001)
        XCTAssertEqual(Double(b.projektion.versatz.y), 0, accuracy: 0.001)
    }

    func testMitZoomSchonUndNurSoWeitWieFeldDaIst() {
        var b = block()
        b.zoomSetzen(3, groesse: groesse)
        b.verschieben(um: CGSize(width: 40, height: 0), groesse: groesse)
        XCTAssertEqual(Double(b.projektion.versatz.x), 40, accuracy: 0.001)

        // Und weiter als erlaubt geht es nicht.
        b.verschieben(um: CGSize(width: 99_999, height: 0), groesse: groesse)
        let (faktor, _) = b.projektion.aufFlaeche(groesse)
        let grenze = b.projektion.versatzgrenze(faktor: faktor,
                                                groesse: groesse)
        XCTAssertEqual(Double(b.projektion.versatz.x), Double(grenze.x),
                       accuracy: 0.001)
    }

    // MARK: - Zurück

    func testEsGibtEinenWegZurueck() {
        var b = block()
        b.zoomSetzen(3, um: CGPoint(x: 100, y: 200), groesse: groesse)
        XCTAssertTrue(b.ausschnittVerstellt)
        b.ausschnittZuruecksetzen()
        XCTAssertFalse(b.ausschnittVerstellt)
        XCTAssertEqual(b.projektion.zoom, 1)
    }

    // MARK: - Es ist keine Änderung am Play

    func testDerZoomStehtInKeinemVerlaufUndInKeinerDatei() {
        // Zoom und Verschiebung sind keine Änderung am Play -- sie
        // stehen in keinem Ausdruck. Ein „Rückgängig", das erst den
        // Ausschnitt zurückdreht, wäre ein Knopf, den man dreimal
        // drücken muss, um einmal etwas zu erreichen.
        var b = block()
        b.gesichert(bis: b.stand)
        b.zoomSetzen(3, groesse: groesse)
        b.verschieben(um: CGSize(width: 20, height: 20), groesse: groesse)
        XCTAssertFalse(b.kannRueckgaengig)
        XCTAssertFalse(b.geaendert, "der Autosave darf davon nichts merken")
    }

    // MARK: - Der Ausschnitt überlebt das Zeichnen

    func testEineLangeRouteWirftDenAusschnittNichtWeg() {
        // Sonst springt das Bild auf Anfang, sobald jemand eine lange
        // Route zieht -- also genau dann, wenn er hineingezoomt hat, um
        // sie zu zeichnen.
        var b = block()
        b.zoomSetzen(2.5, groesse: groesse)
        let weit = Zeichnung(spieler: [
            Zeichnung.Spieler(id: "o_x", seite: .offense, kuerzel: "X",
                              x: 35, y: 12.5),
        ], linien: [
            Zeichnung.Linie(spieler: "o_x", art: .route, punkte: [
                Zeichnung.Punkt(x: 35, y: 12.5),
                Zeichnung.Punkt(x: 58, y: 12.5),
            ]),
        ])
        let gedehnt = b.projektion.passendFuer(weit)
        XCTAssertEqual(gedehnt.zoom, 2.5)
    }
}
