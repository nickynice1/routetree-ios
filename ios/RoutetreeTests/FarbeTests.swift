// Prüft die App dieselbe Farbe wie der Server? (B7)
//
// `FarbProben` trägt die Antworten des SERVERS, erzeugt von
// `scripts/farben_swift.py` aus `backend/designer/farben.py`. Hier wird
// `Farbwert` dagegen gemessen -- Fall für Fall, Satz für Satz.
//
// Warum das mehr ist als Formalismus: Läuft die Regel auseinander,
// sperrt die App einen Wert, den der Browser nebenan nimmt, oder sie
// schickt einen los und bekommt 400, nachdem der Coach ihn dreimal
// getippt hat. Beides sieht aus, als sei die App kaputt.

import XCTest
@testable import Routetree

final class FarbeTests: XCTestCase {

    func testEsGibtUeberhauptProben() {
        // Eine Schleife über null Fälle ist grün. Dieselbe Lehre wie aus
        // `AppTexteTest` in B5: Eine Prüfung, die nichts findet, hört
        // still auf zu messen.
        XCTAssertGreaterThanOrEqual(FarbProben.faelle.count, 12)
    }

    func testJederFallTrifftDieAntwortDesServers() {
        for fall in FarbProben.faelle {
            let ergebnis = Farbwert.pruefen(fall.eingabe)
            XCTAssertEqual(ergebnis.wert, fall.wert,
                           "\(fall.name): \(fall.hinweis)")
            XCTAssertEqual(ergebnis.fehler, fall.fehler,
                           "\(fall.name): \(fall.hinweis)")
            // Genau eins von beiden. Ein Ergebnis mit Wert UND Fehler
            // wäre für den Aufrufer nicht entscheidbar.
            XCTAssertEqual(ergebnis.wert == nil, ergebnis.fehler != nil,
                           fall.name)
            XCTAssertEqual(ergebnis.taugt, fall.wert != nil, fall.name)
        }
    }

    func testGeprueftesKommtKleinZurueck() {
        // Der Fall, an dem eine nachgebaute Prüfung als Erstes
        // vorbeigeht: Sie prüft richtig und gibt die Eingabe zurück.
        XCTAssertEqual(Farbwert.pruefen("#1A5364").wert, "#1a5364")
    }

    func testDieKurzformIstKeineFarbe() {
        // Im CSS gültig, hier nicht.
        XCTAssertFalse(Farbwert.pruefen("#abc").taugt)
    }

    func testWasEinBrowserNichtZeichnetGehtNichtDurch() {
        // Die vier Fälle, die der Server bis B7 durchgelassen hat, weil
        // er den Rest als Zahl las. Sie sahen aus wie eine Farbe und
        // färbten nichts.
        for wert in ["# 12345", "#1_2345", "#+12345", "#１２３４５６"] {
            XCTAssertFalse(Farbwert.pruefen(wert).taugt, wert)
        }
    }

    func testLeerIstKeinFehler() {
        let ergebnis = Farbwert.pruefen("   ")
        XCTAssertEqual(ergebnis.wert, Farbwert.standard)
        XCTAssertNil(ergebnis.fehler)
    }

    // MARK: - Die Palette

    func testDieVorschlaegeSindAcht() {
        XCTAssertEqual(Farbvorschlaege.alle.count, 8)
    }

    func testJederVorschlagIstEineFarbe() {
        // Ein Tupfer, den die eigene Prüfung ablehnt, wäre ein Knopf,
        // der beim Drücken den Sichern-Knopf ausgraut.
        for wert in Farbvorschlaege.alle {
            XCTAssertTrue(Farbwert.pruefen(wert).taugt, wert)
        }
        XCTAssertTrue(Farbwert.pruefen(Farbvorschlaege.standard).taugt)
    }

    func testDerVergleichNimmtDieSchreibweiseNichtKrumm() {
        XCTAssertTrue(Farbwert.gleich("#1A5364", "#1a5364"))
        XCTAssertFalse(Farbwert.gleich("#1A5364", "#2e7d96"))
        XCTAssertFalse(Farbwert.gleich("#1A5364", nil))
        XCTAssertTrue(Farbwert.gleich(nil, nil))
    }
}
