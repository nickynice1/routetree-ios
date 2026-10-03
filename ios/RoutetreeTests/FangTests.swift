import XCTest
@testable import Routetree

/// Rechnet die App den Zeichenfang wie der Browser?
///
/// **Der Fang ist seit dem 27.08.2026 magnetisch.** Niklas: „Punkte
/// werden gesetzt, wo getippt wird, nicht im Raster." Vorher landete
/// jeder Punkt auf dem halben Yard; wer 3,2 wollte, bekam 3,0.
///
/// Der alte Grund bleibt wahr, deshalb ist der Fang nicht ersatzlos weg:
/// Ohne ihn fängt man Zittern ein, und im Ausdruck sieht man das. Knapp
/// an einer Marke rastet es, weiter weg bleibt der Punkt liegen.
///
/// **Warum das gemessen werden muss.** Ein Punkt, der einen Zehntel Yard
/// danebenliegt, sieht nicht falsch aus. Man bemerkt ihn erst, wenn
/// derselbe Play im Browser und in der App nebeneinander liegt -- oder
/// gar nicht, weil er im Ausdruck nur „etwas krumm" wirkt.
///
/// Deshalb steht hier kein selbst ausgedachtes Ergebnis. Die Zahlen in
/// `FangProben` hat der SERVER gerechnet (`backend/designer/fang.py`,
/// dieselbe Regel, die `editor.js` im Browser anwendet).
final class FangTests: XCTestCase {

    /// EIN LAUF ÜBER NULL FÄLLE IST DIE STILLSTE ART, WIE EINE PRÜFUNG
    /// AUFHÖRT ZU MESSEN. Dieselbe Lehre wie in `OrdnenTests`.
    func testEsGibtUeberhauptProben() {
        XCTAssertGreaterThanOrEqual(
            FangProben.faelle.count, 8,
            "Die Probendatei ist leer oder geschrumpft. "
            + "Neu erzeugen: ./scripts/fang_swift.py")
        XCTAssertGreaterThanOrEqual(FangProben.winkelfaelle.count, 4)
    }

    /// DIE PRÜFUNG: jeder Fall des Servers, durch die App gerechnet.
    func testJederFallKommtGleichHeraus() {
        for fall in FangProben.faelle {
            XCTAssertEqual(
                Projektion.fangen(fall.wert), fall.erwartet, accuracy: 1e-6,
                "\(fall.hinweis) (Wert \(fall.wert))")
        }
    }

    /// Der Fall aus dem Auftrag noch einmal einzeln. Wer den Magneten
    /// wieder aufweitet, soll DIESEN Test rot sehen und nicht einen von
    /// zwölf.
    func testDerFallAusDemAuftrag() {
        XCTAssertEqual(Projektion.fangen(3.2), 3.2, accuracy: 1e-6,
                       "3,2 Yards müssen 3,2 bleiben")
    }

    /// Die andere Hälfte. Ein Fang, der nie fängt, ist kein Fang -- und
    /// das Zittern, gegen das er gebaut wurde, ist wieder da.
    func testUndDassEsUeberhauptNochFaengt() {
        XCTAssertEqual(Projektion.fangen(3.02), 3.0, accuracy: 1e-6)
    }

    /// Die Winkel, ebenfalls gegen die Zahlen des Servers.
    ///
    /// Gerechnet wird von (0, 0) aus, auf einem Feld, das groß genug
    /// ist, dass `begrenzen` nicht dazwischenfunkt -- sonst misst der
    /// Test die Feldkante statt den Fang.
    func testDieWinkelAuch() {
        let projektion = Projektion(feld: Feld.afvd, los: 0, richtung: 1)
        for fall in FangProben.winkelfaelle {
            let ende = projektion.fangenAufWinkel(
                von: (x: 0, y: 0), nach: (x: fall.nachX, y: fall.nachY))
            XCTAssertEqual(ende.x, fall.erwartetX, accuracy: 1e-6,
                           "\(fall.hinweis) (x)")
            XCTAssertEqual(ende.y, fall.erwartetY, accuracy: 1e-6,
                           "\(fall.hinweis) (y)")
        }
    }

    /// Die Magnetweite muss kleiner sein als der halbe Rasterschritt.
    /// Wäre sie größer oder gleich, zöge JEDER Punkt auf eine Marke --
    /// das alte Verhalten unter neuem Namen.
    func testDerMagnetIstEngerAlsDerHalbeSchritt() {
        XCTAssertLessThan(Feld.fangMagnetYards, Feld.fangYards / 2)
        XCTAssertGreaterThan(Feld.fangMagnetYards, 0)
    }
}
