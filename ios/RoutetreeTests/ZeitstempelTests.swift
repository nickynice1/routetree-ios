// Liest die App die Zeitangaben des Servers? (B9)
//
// Django schreibt Mikrosekunden, sobald welche da sind, und bei
// `auto_now` sind immer welche da:
// `2026-08-25T05:58:53.123456+00:00`. Foundations `.iso8601` liest genau
// das NICHT -- es kennt nur ganze Sekunden und wirft.
//
// DAS IST KEIN KLEINER FEHLER. Eine Antwort wird auf einmal
// entschlüsselt: Fällt ein Datum aus, fällt die ganze Liste aus. Die App
// zeigt „Die Antwort des Servers war nicht lesbar" -- und zwar erst auf
// dem Gerät, denn hier läuft kein Server, der Mikrosekunden schickt.
//
// Gefunden beim Kader, wo „dabei seit" das erste Datum ist, das jemand
// liest. Die Playbook-Liste trägt seit B2 dasselbe Feld.

import XCTest
@testable import Routetree

final class ZeitstempelTests: XCTestCase {

    func testMitMikrosekundenWieDjangoSieSchreibt() {
        XCTAssertNotNil(Zeitstempel.lesen("2026-08-25T05:58:53.123456+00:00"))
        XCTAssertNotNil(Zeitstempel.lesen("2026-08-25T05:58:53.123456Z"))
        XCTAssertNotNil(Zeitstempel.lesen("2026-08-25T07:58:53.9+02:00"))
    }

    func testOhneBruchteileGehtWeiterhin() {
        XCTAssertNotNil(Zeitstempel.lesen("2026-08-25T05:58:53+00:00"))
        XCTAssertNotNil(Zeitstempel.lesen("2026-08-25T05:58:53Z"))
    }

    func testDieBruchteileVerschiebenDieZeitNicht() {
        // Abgeschnitten und nicht gerundet: Angezeigt wird ohnehin ein
        // Tag. Aber wenn aus 53,9 Sekunden 54 würden, stünde an einem
        // Beitritt um 23:59:59,9 der falsche Tag.
        let ohne = Zeitstempel.lesen("2026-08-25T05:58:53Z")
        let mit = Zeitstempel.lesen("2026-08-25T05:58:53.987654Z")
        XCTAssertEqual(ohne, mit)
    }

    func testAusKaputtemWirdNichtDurchKuerzenGueltiges() {
        // Ein Punkt ohne Ziffern dahinter bleibt stehen. Sonst machte
        // das Wegkürzen aus einem unlesbaren Text einen lesbaren, und
        // die App zeigte ein Datum, das nie geschickt wurde.
        XCTAssertEqual(Zeitstempel.ohneBruchteile("2026-08-25T05:58:53.Z"),
                       "2026-08-25T05:58:53.Z")
        XCTAssertNil(Zeitstempel.lesen("2026-08-25T05:58:53.Z"))
        XCTAssertNil(Zeitstempel.lesen("gestern"))
        XCTAssertNil(Zeitstempel.lesen(""))
    }

    func testNurDieBruchteileVerschwindenUndNichtDieZeitzone() {
        XCTAssertEqual(
            Zeitstempel.ohneBruchteile("2026-08-25T05:58:53.123456+02:00"),
            "2026-08-25T05:58:53+02:00")
    }

    func testDerEntschluesslerDesServersNimmtBeides() {
        // Die eigentliche Stelle: Nicht `Zeitstempel` wird benutzt,
        // sondern `Server.entschluessler`. Eine Prüfung, die nur die
        // Hilfsfunktion misst, wäre grün, während die App weiter
        // `.iso8601` benutzt.
        struct Probe: Decodable { let seit: Date? }
        for text in ["2026-08-25T05:58:53.123456+00:00",
                     "2026-08-25T05:58:53+00:00"] {
            let json = "{\"seit\": \"\(text)\"}"
            let probe = try? Server.entschluessler.decode(
                Probe.self, from: Data(json.utf8))
            XCTAssertNotNil(probe?.seit, text)
        }
    }

    func testEinKaderMitMikrosekundenLaesstSichLesen() {
        // Der Fall, der die ganze Liste mitgerissen hätte.
        let json = """
        {"id": 3, "name": "Robin Bergman", "rolle": "viewer",
         "rolle_text": "Nur Ansicht",
         "seit": "2026-08-25T05:58:53.123456+00:00",
         "ich": false, "letzter_head": false, "darf_name": true}
        """
        let zeile = try? Server.entschluessler.decode(
            Modell.Kadermitglied.self, from: Data(json.utf8))
        XCTAssertNotNil(zeile?.seit)
        XCTAssertEqual(zeile?.name, "Robin Bergman")
    }
}
