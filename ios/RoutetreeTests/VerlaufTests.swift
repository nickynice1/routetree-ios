import CoreGraphics
import XCTest
@testable import Routetree

/// Nimmt Rückgängig genau das zurück, was gerade passiert ist?
///
/// **Warum das die eigentliche Frage ist.** Ein Rückgängig, das nur die
/// Hälfte zurücknimmt, ist schlimmer als keins: Wer einmal erlebt hat,
/// dass ein Schritt zurück etwas anderes wiederherstellt als das, was er
/// gerade geändert hat, drückt den Knopf nie wieder und arbeitet ab dann
/// vorsichtig statt schnell.
///
/// Gemessen wird deshalb nicht „es gibt einen Stapel", sondern die drei
/// Stellen, an denen so ein Knopf schiefgeht: ein Zug mit dem Finger, der
/// dreißig Schritte hinterlässt statt einem; eine Änderung, die gar nicht
/// stattgefunden hat und trotzdem einen Schritt kostet; und ein
/// Wiederholen, das nach neuer Arbeit einen alten Ast zurückholt.
final class VerlaufTests: XCTestCase {

    private let groesse = CGSize(width: 370, height: 300)
    private let feld = Feld.afvd

    private var projektion: Projektion {
        Projektion(feld: feld, los: feld.mitte, richtung: 1)
    }

    private func schirm(_ x: Double, _ y: Double) -> CGPoint {
        projektion.aufBildschirm(x: x, y: y, groesse: groesse)
    }

    private func block(_ werkzeug: Zeichenblock.Werkzeug = .auswahl)
        -> Zeichenblock {
        let zeichnung = Zeichnung(spieler: [
            Zeichnung.Spieler(id: "o_qb", seite: .offense, rolle: "QB",
                              kuerzel: "Q", x: 35, y: 12.5),
            Zeichnung.Spieler(id: "o_x", seite: .offense, rolle: "X",
                              kuerzel: "X", x: 35, y: 20),
        ])
        var b = Zeichenblock(zeichnung: zeichnung, projektion: projektion)
        b.werkzeugSetzen(werkzeug)
        return b
    }

    // MARK: - Die beiden Stapel für sich

    /// Ein Arbeitsstand, so knapp wie moeglich.
    ///
    /// SEIT R110.3 traegt ein Schritt nicht mehr nur die Zeichnung,
    /// sondern auch die Lage des Balls. Ein Rueckgaengig, das nur die
    /// Zeichnung zuruecknahm, haette danach die Haelfte zurueckgenommen:
    /// Die Figuren stuenden wieder, wo sie waren, der Ball laege weiter
    /// woanders.
    private func stand(_ zeichnung: Zeichnung = Zeichnung(),
                       los: Double = 30, richtung: Int = 1,
                       angaben: Playangabenstand = Playangabenstand())
        -> Verlauf.Stand {
        Verlauf.Stand(zeichnung: zeichnung, los: los, richtung: richtung,
                      angaben: angaben)
    }

    func test_ein_frischer_verlauf_kann_nichts() {
        var v = Verlauf()
        XCTAssertFalse(v.kannZurueck)
        XCTAssertFalse(v.kannVorwaerts)
        XCTAssertNil(v.zurueckgehen(von: stand()))
        XCTAssertNil(v.vorgehen(von: stand()))
    }

    func test_ein_schritt_traegt_auch_die_playangaben() {
        // R110.7. Wer einen Play umbenennt, eine Kategorie setzt oder
        // eine Situation anhakt, hat etwas geändert -- und drückte er
        // danach „Rückgängig", nahm es die letzte LINIE zurück und
        // liess die Umbenennung stehen.
        var v = Verlauf()
        var alt = Playangabenstand()
        alt.name = "Spread Mesh"
        var neu = Playangabenstand()
        neu.name = "Trips Right"
        v.merken(stand(angaben: alt))
        XCTAssertEqual(v.zurueckgehen(von: stand(angaben: neu))?.angaben.name,
                       "Spread Mesh")
    }

    func test_ein_schritt_traegt_auch_die_lage_des_balls() {
        // R110.3. Ohne diese Zeile waere der Verlauf genau der, den der
        // Kopf von `Verlauf.swift` als den schlimmsten Fall beschreibt.
        var v = Verlauf()
        v.merken(stand(los: 30, richtung: 1))
        let zurueck = v.zurueckgehen(von: stand(los: 12, richtung: -1))
        XCTAssertEqual(zurueck?.los, 30)
        XCTAssertEqual(zurueck?.richtung, 1)
        // Und der Weg nach vorn hat die neue Lage.
        XCTAssertEqual(v.vorgehen(von: stand(los: 30))?.los, 12)
    }

    func test_der_stapel_hoert_bei_sechzig_auf() {
        // Jeder Schritt ist eine ganze Zeichnung. Unbegrenzt hieße: ein
        // Editor, der eine Stunde offen liegt, füllt den Speicher eines
        // Telefons mit Zwischenständen.
        var v = Verlauf()
        for i in 0..<80 {
            v.merken(stand(Zeichnung(spieler: [
                Zeichnung.Spieler(id: "o_x", seite: .offense, kuerzel: "X",
                                  x: Double(i), y: 5),
            ])))
        }
        XCTAssertEqual(v.zurueck.count, Verlauf.grenze)
        // Was bleibt, sind die JÜNGSTEN. Fiele oben etwas heraus statt
        // unten, ginge die letzte Änderung verloren und die erste bliebe.
        XCTAssertEqual(v.zurueck.last?.zeichnung.spieler.first?.x, 79)
        XCTAssertEqual(v.zurueck.first?.zeichnung.spieler.first?.x, 20)
    }

    func test_eine_neue_aenderung_loescht_den_weg_nach_vorn() {
        var v = Verlauf()
        v.merken(stand())
        _ = v.zurueckgehen(von: stand())
        XCTAssertTrue(v.kannVorwaerts)

        v.merken(stand())
        XCTAssertFalse(v.kannVorwaerts,
                       "sonst überschriebe ein Wiederholen frische Arbeit")
    }

    // MARK: - Im Editor

    func test_eine_fertige_linie_ist_ein_schritt_zurueck() {
        var b = block(.linie(.route))
        b.tippen(schirm(35, 12.5), groesse: groesse)
        b.tippen(schirm(45, 12.5), groesse: groesse)
        b.abschliessen()
        XCTAssertEqual(b.zeichnung.linien.count, 1)
        XCTAssertTrue(b.kannRueckgaengig)

        b.rueckgaengig()
        XCTAssertTrue(b.zeichnung.linien.isEmpty)
        XCTAssertTrue(b.kannWiederherstellen)

        b.wiederherstellen()
        XCTAssertEqual(b.zeichnung.linien.count, 1)
    }

    func test_eine_ersetzte_linie_ist_EIN_schritt_und_nicht_zwei() {
        // Der Fall, der auffällt: Eine neue Linie ersetzt die alte an
        // derselben Position. Wären das zwei Schritte, stünde nach dem
        // ersten Rückgängig gar keine Linie mehr da -- und der Trainer
        // hätte den Weg verloren, den er behalten wollte.
        var b = block(.linie(.route))
        b.tippen(schirm(35, 12.5), groesse: groesse)
        b.tippen(schirm(45, 12.5), groesse: groesse)
        b.abschliessen()

        b.werkzeugSetzen(.linie(.motion))
        b.tippen(schirm(35, 12.5), groesse: groesse)
        b.tippen(schirm(40, 17.5), groesse: groesse)
        b.abschliessen()
        XCTAssertEqual(b.zeichnung.linien.count, 1)
        XCTAssertEqual(b.zeichnung.linien[0].art, .motion)

        b.rueckgaengig()
        XCTAssertEqual(b.zeichnung.linien.count, 1,
                       "die ersetzte Linie muss in einem Schritt zurück sein")
        XCTAssertEqual(b.zeichnung.linien[0].art, .route)
    }

    func test_ein_zug_mit_dem_finger_ist_EIN_schritt() {
        // Ein Finger, der eine Figur über das Feld schiebt, löst
        // dutzendweise `verschiebe` aus. Wären das dutzendweise
        // Schritte, käme die Figur beim Rückgängig einen halben Yard
        // zurück statt an ihren Platz.
        var b = block()
        b.anfassen("o_x")
        for y in stride(from: 19.5, through: 15.0, by: -0.5) {
            b.verschiebe("o_x", x: 35, y: y)
        }
        b.loslassen()

        XCTAssertEqual(b.zeichnung.spieler[1].y, 15, accuracy: 0.000_1)
        b.rueckgaengig()
        XCTAssertEqual(b.zeichnung.spieler[1].y, 20, accuracy: 0.000_1,
                       "zurück an den Platz vor dem Anfassen")
        XCTAssertFalse(b.kannRueckgaengig, "und zwar in einem einzigen Schritt")
    }

    func test_zwei_zuege_sind_zwei_schritte() {
        var b = block()
        b.anfassen("o_x")
        b.verschiebe("o_x", x: 35, y: 18)
        b.loslassen()
        b.anfassen("o_x")
        b.verschiebe("o_x", x: 35, y: 16)
        b.loslassen()

        b.rueckgaengig()
        XCTAssertEqual(b.zeichnung.spieler[1].y, 18, accuracy: 0.000_1)
        b.rueckgaengig()
        XCTAssertEqual(b.zeichnung.spieler[1].y, 20, accuracy: 0.000_1)
    }

    func test_antippen_ohne_ziehen_kostet_keinen_schritt() {
        // Sonst hinterließe jede Auswahl einen leeren Schritt, und
        // Rückgängig täte beim ersten Drücken nichts.
        var b = block()
        b.anfassen("o_x")
        b.loslassen()
        XCTAssertFalse(b.kannRueckgaengig)
    }

    func test_ein_spieler_auf_seinem_eigenen_platz_kostet_keinen_schritt() {
        var b = block()
        b.anfassen("o_x")
        b.verschiebe("o_x", x: 35, y: 20)
        b.loslassen()
        XCTAssertFalse(b.kannRueckgaengig)
        XCTAssertFalse(b.geaendert)
    }

    func test_ein_ende_das_schon_steht_kostet_keinen_schritt() {
        var b = block(.linie(.route))
        b.tippen(schirm(35, 12.5), groesse: groesse)
        b.tippen(schirm(45, 12.5), groesse: groesse)
        b.abschliessen()
        let vorher = b.verlauf.zurueck.count

        b.endeSetzen(b.ausgewaehlteLinie?.ende ?? .arrow)
        XCTAssertEqual(b.verlauf.zurueck.count, vorher)

        b.endeSetzen(.tee)
        XCTAssertEqual(b.verlauf.zurueck.count, vorher + 1)
        b.rueckgaengig()
        XCTAssertEqual(b.zeichnung.linien.first?.ende, .arrow)
    }

    func test_eine_geloeschte_linie_kommt_zurueck() {
        var b = block(.linie(.route))
        b.tippen(schirm(35, 12.5), groesse: groesse)
        b.tippen(schirm(45, 12.5), groesse: groesse)
        b.abschliessen()
        b.ausgewaehlteLinieLoeschen()
        XCTAssertTrue(b.zeichnung.linien.isEmpty)

        b.rueckgaengig()
        XCTAssertEqual(b.zeichnung.linien.count, 1)
        XCTAssertEqual(b.zeichnung.linien.first?.spieler, "o_qb")
    }

    func test_die_verschobene_linie_geht_mit_zurueck() {
        // Wer eine Figur verschiebt, verschiebt ihren Weg mit. Nähme das
        // Rückgängig nur die Figur zurück, hinge die Linie hinterher
        // neben ihr.
        var b = block(.linie(.route))
        b.tippen(schirm(35, 20), groesse: groesse)
        b.tippen(schirm(45, 20), groesse: groesse)
        b.abschliessen()

        b.werkzeugSetzen(.auswahl)
        b.anfassen("o_x")
        b.verschiebe("o_x", x: 35, y: 15)
        b.loslassen()
        b.rueckgaengig()

        XCTAssertEqual(b.zeichnung.spieler[1].y, 20, accuracy: 0.000_1)
        XCTAssertEqual(b.zeichnung.linien.first?.punkte.first?.y ?? 0, 20,
                       accuracy: 0.000_1)
    }

    // MARK: - Was ein Sprung aufräumt

    func test_nach_einem_sprung_zeigt_die_auswahl_ins_leere() {
        // Die Auswahl ist eine STELLE in der Linienliste, und die Liste
        // ist gerade eine andere geworden. Bliebe sie stehen, löschte
        // der nächste Griff zum Papierkorb eine Linie, die niemand
        // angetippt hat.
        var b = block(.linie(.route))
        b.tippen(schirm(35, 12.5), groesse: groesse)
        b.tippen(schirm(45, 12.5), groesse: groesse)
        b.abschliessen()
        XCTAssertNotNil(b.auswahl)

        b.rueckgaengig()
        XCTAssertNil(b.auswahl)
        XCTAssertNil(b.ausgewaehlteLinie)
    }

    func test_nach_einem_sprung_ist_die_angefangene_linie_weg() {
        var b = block(.linie(.route))
        b.tippen(schirm(35, 12.5), groesse: groesse)
        b.tippen(schirm(45, 12.5), groesse: groesse)
        b.abschliessen()

        b.tippen(schirm(35, 20), groesse: groesse)
        XCTAssertNotNil(b.entwurf)
        b.rueckgaengig()
        XCTAssertNil(b.entwurf, "sie hinge an einem Stand, den es nicht "
                     + "mehr gibt")
    }

    func test_ein_sprung_zaehlt_als_ungesichert() {
        var b = block(.linie(.route))
        b.tippen(schirm(35, 12.5), groesse: groesse)
        b.tippen(schirm(45, 12.5), groesse: groesse)
        b.abschliessen()
        b.gesichert(bis: b.stand)
        XCTAssertFalse(b.geaendert)

        b.rueckgaengig()
        XCTAssertTrue(b.geaendert,
                      "lieber einmal zu viel sichern als einmal zu wenig")
    }

    func test_neue_arbeit_nach_einem_rueckgaengig_loescht_das_wiederholen() {
        var b = block(.linie(.route))
        b.tippen(schirm(35, 12.5), groesse: groesse)
        b.tippen(schirm(45, 12.5), groesse: groesse)
        b.abschliessen()
        b.rueckgaengig()
        XCTAssertTrue(b.kannWiederherstellen)

        b.werkzeugSetzen(.auswahl)
        b.anfassen("o_x")
        b.verschiebe("o_x", x: 35, y: 18)
        b.loslassen()
        XCTAssertFalse(b.kannWiederherstellen)
    }

    func test_ohne_verlauf_tut_der_knopf_nichts() {
        var b = block()
        let vorher = b.zeichnung
        b.rueckgaengig()
        b.wiederherstellen()
        XCTAssertEqual(b.zeichnung, vorher)
        XCTAssertFalse(b.geaendert, "ein Knopf ins Leere ändert nichts")
    }
}
