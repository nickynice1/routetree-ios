import XCTest
@testable import Routetree

/// Kennt die App jede Linienart, die es gibt?
///
/// `Linienstil.swift` wird aus `render.py` erzeugt, und dass beide Seiten
/// dieselben Werte HABEN, misst `test_linienstile_swift.py` in Python.
/// Hier geht es um die andere Hälfte: dass die Tabelle zu den Arten
/// passt, die `Zeichnung.Linie.Art` kennt. Fehlt eine, zeichnet die App
/// sie stillschweigend als Route -- und niemand sieht, dass aus einer
/// Motion eine Route geworden ist.
final class LinienstilTests: XCTestCase {

    func test_jede_art_hat_einen_eigenen_stil() {
        for art in Zeichnung.Linie.Art.allCases {
            XCTAssertNotNil(Linienstil.alle[art],
                            "\(art.rawValue) fehlt in Linienstil.alle")
        }
    }

    func test_die_werkzeugleiste_zeigt_jede_art_genau_einmal() {
        let reihe = Zeichnung.Linie.Art.reihenfolge
        XCTAssertEqual(Set(reihe), Set(Zeichnung.Linie.Art.allCases),
                       "In der Werkzeugleiste fehlt eine Art oder steht "
                       + "eine zu viel")
        XCTAssertEqual(reihe.count, Set(reihe).count, "eine Art doppelt")
    }

    func test_die_namen_sind_die_des_servers() {
        // Kurzform für die Leiste, ausgeschrieben für die Legende.
        //
        // „SNAP" seit dem 09.09.2026 (Niklas: „Statt „Abgabe" lieber
        // „snap""). Der lange Name bleibt „Ballabgabe": In der Legende
        // steht, was die Linie IST, in der Leiste, wie man sie ruft.
        XCTAssertEqual(Zeichnung.Linie.Art.handoff.stil.kurz, "Snap")
        XCTAssertEqual(Zeichnung.Linie.Art.handoff.stil.lang, "Ballabgabe")
        XCTAssertEqual(Zeichnung.Linie.Art.motion.stil.lang,
                       "Motion vor dem Snap")
    }

    func test_der_snap_ist_ein_ballweg_die_route_nicht() {
        // R88. Niklas: „Wenn ich einen Spieler eine Abgabe bzw. snap
        // Linie gebe, kann ich ihm keine normale Route mehr geben."
        // Ein Center snappt und läuft danach seine Route -- die Regel
        // „eine Linie je Position" gilt seitdem je SORTE.
        XCTAssertEqual(Zeichnung.Linie.Art.handoff.sorte, .ball)
        XCTAssertEqual(Zeichnung.Linie.Art.pass.sorte, .ball)
        XCTAssertEqual(Zeichnung.Linie.Art.route.sorte, .weg)
        XCTAssertEqual(Zeichnung.Linie.Art.motion.sorte, .weg)
        XCTAssertEqual(Zeichnung.Linie.Art.option.sorte, .option)
    }

    func test_route_und_abschirmen_unterscheiden_sich_im_ende() {
        // Beide durchgezogen, beide in Textfarbe. Fällt das Ende weg,
        // sehen zwei verschiedene Anweisungen gleich aus.
        let route = Zeichnung.Linie.Art.route.stil
        let block = Zeichnung.Linie.Art.block.stil
        XCTAssertEqual(route.farbe, block.farbe)
        XCTAssertNil(route.strich)
        XCTAssertNil(block.strich)
        XCTAssertNotEqual(route.standardEnde, block.standardEnde)
    }

    func test_der_ballweg_ist_nicht_die_farbe_eines_laufwegs() {
        // Abgabe und Pass gehören dem Ball, nicht einem Läufer.
        XCTAssertEqual(Zeichnung.Linie.Art.handoff.stil.farbe, .gold)
        XCTAssertEqual(Zeichnung.Linie.Art.pass.stil.farbe, .gold)
        XCTAssertEqual(Zeichnung.Linie.Art.zone.stil.farbe, .petrol)
        XCTAssertNotEqual(Zeichnung.Linie.Art.route.stil.farbe, .gold)
    }

    func test_gestrichelt_ist_wer_nicht_laeuft() {
        // Motion, Pass und Zone sind gestrichelt, damit der
        // Schwarzweissdruck lesbar bleibt.
        for art in [Zeichnung.Linie.Art.motion, .pass, .zone] {
            XCTAssertNotNil(art.stil.strich, "\(art.rawValue)")
        }
    }
}
