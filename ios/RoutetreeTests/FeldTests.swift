import XCTest
@testable import Routetree

/// Rechnet die App dasselbe wie der Server?
///
/// `Feld.swift` wird aus `backend/designer/geometry.py` erzeugt, also
/// haben beide Seiten dieselben ZAHLEN. Das genügt nicht: Sie müssen
/// damit auch dasselbe RECHNEN.
///
/// Die erwarteten Werte in `FeldProben` hat Python ausgerechnet. Hier
/// werden dieselben Fälle in Swift nachgerechnet. Weicht eine Sprache
/// ab, wird dieser Test rot, und zwar bevor jemand ein Handy neben einen
/// Ausdruck legt.
///
/// **Der Fall, für den es gebaut wurde.** Python rundet mit `round()`
/// kaufmännisch zur geraden Zahl: 4,5 wird 4. Swifts `.rounded()` rundet
/// von der Null weg und macht daraus 5. Der Zeichenfang rastet auf halbe
/// Yards, also liegt genau dort der Normalfall und nicht der Sonderfall.
final class FeldTests: XCTestCase {

    func test_die_masse_sind_die_der_norm() {
        let f = Feld.afvd
        XCTAssertEqual(f.spielLaenge, 50, "50 yd zwischen den Endzonen")
        XCTAssertEqual(f.endzone, 10)
        XCTAssertEqual(f.breite, 25)
        XCTAssertEqual(f.gesamtLaenge, 70, "50 plus zwei Endzonen")
        XCTAssertEqual(f.mitte, 35)
        XCTAssertEqual(Feld.fangYards, 0.5)
        XCTAssertEqual(Feld.fangGrad, 45)
    }

    func test_yard_linie_rechnet_wie_python() {
        let f = Feld.afvd
        for (x, erwartet) in FeldProben.yardLinie {
            XCTAssertEqual(f.yardLinie(x), erwartet,
                           "yardLinie(\(x)) weicht von Python ab")
        }
    }

    func test_no_run_zone_wie_python() {
        let f = Feld.afvd
        for (x, erwartet) in FeldProben.keinLaufZone {
            XCTAssertEqual(f.inKeinLaufZone(x), erwartet,
                           "inKeinLaufZone(\(x)) weicht von Python ab")
        }
    }

    func test_rushlinie_wie_python() {
        let f = Feld.afvd
        for (los, richtung, erwartet) in FeldProben.rushLinie {
            XCTAssertEqual(f.rushLinie(los: los, richtung: richtung), erwartet,
                           accuracy: 0.0001,
                           "rushLinie(\(los), \(richtung)) weicht ab")
        }
    }

    func test_begrenzen_wie_python() {
        let f = Feld.afvd
        for (x, y, ex, ey) in FeldProben.begrenzen {
            let (gx, gy) = f.begrenzen(x: x, y: y)
            XCTAssertEqual(gx, ex, accuracy: 0.0001, "x bei (\(x), \(y))")
            XCTAssertEqual(gy, ey, accuracy: 0.0001, "y bei (\(x), \(y))")
        }
    }

    func test_die_voreinstellungen_sind_vollstaendig() {
        // Wer im Editor ein Feldformat wählt, muss es in der App
        // wiederfinden. Sonst zeichnet die App auf einem anderen Feld.
        XCTAssertNotNil(Feld.voreinstellungen["afvd"])
        XCTAssertNotNil(Feld.voreinstellungen["afvd_klein"])
        XCTAssertNotNil(Feld.voreinstellungen["afvd_gross"])
        XCTAssertEqual(Feld.voreinstellungen["afvd"], Feld.afvd)
    }

    func test_das_regelmass_wird_geprueft() {
        XCTAssertTrue(Feld.afvd.istGueltig)
        XCTAssertFalse(Feld(spielLaenge: 30, breite: 25).istGueltig,
                       "30 yd liegt unter dem Regelminimum")
        XCTAssertFalse(Feld(spielLaenge: 50, breite: 35).istGueltig,
                       "35 yd liegt über dem Regelmaximum")
    }
}
