import CoreGraphics
import XCTest
@testable import Routetree

/// Greift der Finger denselben Stützpunkt wie die Maus im Browser?
///
/// `Griffe.naechster` ist die zweite Fassung der Regel aus
/// `backend/static/designer/griffe.js`. Die erwarteten Werte in
/// `GriffeProben` hat `scripts/griffe_swift.py` ausgerechnet; dieselben
/// Fälle laufen unter Node durch das JavaScript
/// (`backend/designer/test_griffe.py`).
///
/// **Wofür es gebaut wurde** (R11 und R5, 25.08.2026). Gemessen mit
/// `scripts/_probe_griff.py` im echten Editor: Die Stützpunkte einer
/// ausgewählten Route waren gezeichnet und ließen sich nicht bewegen,
/// bei einer Zone wurden sie nicht einmal gezeichnet, und die App hatte
/// beides nicht.
final class GriffeTests: XCTestCase {

    func test_naechster_griff_wie_python() {
        for probe in GriffeProben.faelle {
            let ergebnis = Griffe.naechster(probe.punkte, zu: probe.ziel,
                                            weite: probe.weite,
                                            verankert: probe.verankert)
            XCTAssertEqual(ergebnis ?? -1, probe.erwartet,
                           "Ein anderer Stützpunkt als im Browser")
        }
    }

    /// Ohne diese Probe wäre der Test oben zufrieden, wenn `GriffeProben`
    /// leer wäre -- eine Schleife über nichts läuft grün durch.
    func test_es_gibt_ueberhaupt_proben() {
        XCTAssertGreaterThanOrEqual(GriffeProben.faelle.count, 8,
                                    "Die Proben sind weg oder wurden nicht "
                                    + "erzeugt")
    }

    func test_der_naechste_gewinnt_und_nicht_der_erste() {
        // Zwei Punkte in Reichweite, der zweite näher. Wer die Schleife
        // beim ersten Treffer verlässt, bekommt hier 0 statt 1.
        let punkte = [CGPoint(x: 0, y: 0), CGPoint(x: 6, y: 0)]
        XCTAssertEqual(Griffe.naechster(punkte, zu: CGPoint(x: 5, y: 0),
                                        weite: 12, verankert: false), 1)
    }

    func test_der_anfang_einer_positionslinie_ist_kein_griff() {
        let punkte = [CGPoint(x: 0, y: 0), CGPoint(x: 40, y: 0)]
        XCTAssertNil(Griffe.naechster(punkte, zu: CGPoint(x: 0, y: 0),
                                      weite: 12, verankert: true),
                     "Der Anfang gehört der Figur und darf nicht einzeln "
                     + "wegzuziehen sein")
        XCTAssertEqual(Griffe.naechster(punkte, zu: CGPoint(x: 0, y: 0),
                                        weite: 12, verankert: false), 0,
                       "An einer Zone ist auch die erste Ecke ein Griff")
    }

    func test_ausserhalb_der_weite_faellt_weg() {
        let punkte = [CGPoint(x: 0, y: 0)]
        XCTAssertNil(Griffe.naechster(punkte, zu: CGPoint(x: 13, y: 0),
                                      weite: 12, verankert: false))
        XCTAssertEqual(Griffe.naechster(punkte, zu: CGPoint(x: 12, y: 0),
                                        weite: 12, verankert: false), 0,
                       "Genau auf der Weite zählt noch als Treffer")
    }

    func test_die_weite_ist_groesser_als_im_browser() {
        // Ein Finger ist kein Mauszeiger. Kleiner als der Griff für eine
        // Figur muss sie trotzdem bleiben, sonst verdeckt ein Stützpunkt
        // die Figur, an der seine Linie hängt.
        XCTAssertGreaterThan(Griffe.weite, 12)
        XCTAssertLessThan(Griffe.weite, Zeichenblock.griff)
    }
}

// MARK: - Der Block

/// Was der Zeichenblock daraus macht: anfassen, ziehen, zurücknehmen.
final class GriffeImBlockTests: XCTestCase {

    private func block(mitLinie linie: Zeichnung.Linie) -> Zeichenblock {
        var zeichnung = Zeichnung()
        zeichnung.spieler = [
            Zeichnung.Spieler(id: "o_x", seite: .offense, rolle: "X",
                              kuerzel: "X", farbe: nil,
                              x: 35, y: 22.5),
        ]
        zeichnung.linien = [linie]
        return Zeichenblock(
            zeichnung: zeichnung,
            projektion: Projektion(feld: Feld.afvd, los: 35, richtung: 1))
    }

    private var route: Zeichnung.Linie {
        Zeichnung.Linie(spieler: "o_x", art: .route, ende: .arrow,
                        gebogen: false,
                        punkte: [Zeichnung.Punkt(x: 35, y: 22.5),
                                 Zeichnung.Punkt(x: 40, y: 22.5),
                                 Zeichnung.Punkt(x: 45, y: 17.5)])
    }

    private var zone: Zeichnung.Linie {
        Zeichnung.Linie(spieler: nil, art: .zone, ende: .none,
                        gebogen: false,
                        punkte: [Zeichnung.Punkt(x: 27, y: 8.5),
                                 Zeichnung.Punkt(x: 27, y: 3.5),
                                 Zeichnung.Punkt(x: 33, y: 3.5),
                                 Zeichnung.Punkt(x: 33, y: 8.5)])
    }

    func test_ein_knick_laesst_sich_verschieben() {
        var b = block(mitLinie: route)
        b.werkzeugSetzen(.auswahl)
        let stelle = Zeichenblock.Griffstelle(linie: 0, punkt: 1)
        b.griffAnfassen(stelle)
        b.griffVerschieben(stelle, x: 40, y: 19)
        XCTAssertEqual(b.zeichnung.linien[0].punkte[1].y, 19)
        // Die Nachbarn bleiben, wo sie waren -- verschoben wird EIN
        // Punkt, nicht die Linie.
        XCTAssertEqual(b.zeichnung.linien[0].punkte[0].y, 22.5)
        XCTAssertEqual(b.zeichnung.linien[0].punkte[2].y, 17.5)
    }

    func test_der_spieler_bleibt_stehen() {
        var b = block(mitLinie: route)
        b.griffAnfassen(Zeichenblock.Griffstelle(linie: 0, punkt: 2))
        b.griffVerschieben(Zeichenblock.Griffstelle(linie: 0, punkt: 2),
                           x: 50, y: 10)
        XCTAssertEqual(b.zeichnung.spieler[0].x, 35)
        XCTAssertEqual(b.zeichnung.spieler[0].y, 22.5)
    }

    func test_der_anfang_einer_positionslinie_bewegt_sich_nicht() {
        var b = block(mitLinie: route)
        b.griffVerschieben(Zeichenblock.Griffstelle(linie: 0, punkt: 0),
                           x: 30, y: 10)
        XCTAssertEqual(b.zeichnung.linien[0].punkte[0].x, 35)
        XCTAssertEqual(b.zeichnung.linien[0].punkte[0].y, 22.5)
    }

    func test_bei_einer_zone_ist_jede_ecke_ein_griff() {
        var b = block(mitLinie: zone)
        b.griffVerschieben(Zeichenblock.Griffstelle(linie: 0, punkt: 0),
                           x: 24, y: 8.5)
        XCTAssertEqual(b.zeichnung.linien[0].punkte[0].x, 24,
                       "Eine Zone gehört keiner Position, also ist auch "
                       + "ihre erste Ecke ein Griff")
    }

    func test_ein_zug_ist_ein_schritt_im_verlauf() {
        // DER GRUND: Ein Finger, der einen Punkt über das Feld schiebt,
        // löst dutzendweise Aufrufe aus. Wer danach Rückgängig drückt,
        // will den Punkt dort haben, wo er vor dem Anfassen lag -- und
        // nicht einen Millimeter weiter links.
        var b = block(mitLinie: route)
        let stelle = Zeichenblock.Griffstelle(linie: 0, punkt: 1)
        b.griffAnfassen(stelle)
        for y in stride(from: 22.0, through: 19.0, by: -0.5) {
            b.griffVerschieben(stelle, x: 40, y: y)
        }
        b.loslassen()
        XCTAssertEqual(b.zeichnung.linien[0].punkte[1].y, 19)
        b.rueckgaengig()
        XCTAssertEqual(b.zeichnung.linien[0].punkte[1].y, 22.5,
                       "Rückgängig muss den ganzen Zug zurücknehmen")
        XCTAssertFalse(b.kannRueckgaengig,
                       "Ein Zug, nicht sieben Schritte")
    }

    func test_ein_zug_macht_die_zeichnung_ungesichert() {
        var b = block(mitLinie: route)
        // Erst lesen, dann ändern: `b.gesichert(bis: b.stand)` wäre ein
        // Lesezugriff mitten in einem Schreibzugriff auf denselben Wert.
        let jetzt = b.stand
        b.gesichert(bis: jetzt)
        XCTAssertFalse(b.geaendert)
        let stelle = Zeichenblock.Griffstelle(linie: 0, punkt: 1)
        b.griffAnfassen(stelle)
        b.griffVerschieben(stelle, x: 40, y: 19)
        XCTAssertTrue(b.geaendert,
                      "Sonst geht ein verschobener Knick beim Zurückgehen "
                      + "verloren")
    }

    func test_ein_punkt_auf_derselben_stelle_kostet_keinen_schritt() {
        var b = block(mitLinie: route)
        let stelle = Zeichenblock.Griffstelle(linie: 0, punkt: 1)
        b.griffVerschieben(stelle, x: 40, y: 22.5)
        XCTAssertFalse(b.kannRueckgaengig,
                       "Ein Rückgängig, das nichts tut, ist schlimmer als "
                       + "keines")
    }

    func test_griffe_gibt_es_nur_an_der_ausgewaehlten_linie() {
        var b = block(mitLinie: route)
        XCTAssertTrue(b.griffe.isEmpty,
                      "Ohne Auswahl liegt kein Griff auf dem Feld")
        b.griffAnfassen(Zeichenblock.Griffstelle(linie: 0, punkt: 1))
        XCTAssertEqual(b.griffe.count, 3)
        XCTAssertFalse(b.istGriff(0), "Punkt 0 gehört der Figur")
        XCTAssertTrue(b.istGriff(1))
    }

    func test_beim_zeichnen_liegen_keine_griffe_herum() {
        // Wer gerade zeichnet, kann nichts ziehen -- sichtbare Griffe
        // wären dann ein Versprechen, das die Geste nicht hält.
        var b = block(mitLinie: route)
        b.griffAnfassen(Zeichenblock.Griffstelle(linie: 0, punkt: 1))
        XCTAssertEqual(b.griffe.count, 3)
        b.werkzeugSetzen(.linie(.route))
        XCTAssertTrue(b.griffe.isEmpty)
        XCTAssertNil(b.griffBei(CGPoint(x: 100, y: 100),
                                groesse: CGSize(width: 390, height: 700)))
    }
}

// MARK: - Der Fang (R5)

/// Lässt sich der Fang abschalten -- und gilt das überall?
///
/// **Hieß bis zum 28.08.2026 `FangTests`, genau wie die Klasse in
/// `FangTests.swift`.** Swift erlaubt keine zwei Typen desselben Namens
/// in einem Ziel; der Bau brach mit `invalid redeclaration of
/// 'FangTests'` ab. Aufgefallen ist es erst auf dem Läufer, weil es
/// hier keinen Compiler gibt.
///
/// Die beiden prüfen auch Verschiedenes: Dort die MAGNETISCHE Regel aus
/// Runde 4 gegen die Proben des Servers, hier den SCHALTER aus R5.
/// Der Name sagt das jetzt.
final class FangSchalterTests: XCTestCase {

    private func block() -> Zeichenblock {
        var zeichnung = Zeichnung()
        zeichnung.spieler = [
            Zeichnung.Spieler(id: "o_x", seite: .offense, rolle: "X",
                              kuerzel: "X", farbe: nil, x: 35, y: 22.5),
        ]
        return Zeichenblock(
            zeichnung: zeichnung,
            projektion: Projektion(feld: Feld.afvd, los: 35, richtung: 1))
    }

    func test_voreingestellt_ist_er_an() {
        XCTAssertTrue(block().fang,
                      "Ohne Fang steht eine Aufstellung auf krummen "
                      + "Zehntelyards")
    }

    func test_mit_fang_rastet_nur_was_KNAPP_daneben_liegt() {
        // HIER STAND DIE ALTE REGEL, und der Bau hat sie am 28.08.2026
        // umgeworfen: erwartet wurde, dass 30,31 auf 30,5 springt.
        //
        // Seit Runde 4 ist der Fang MAGNETISCH (Niklas: „Punkte werden
        // gesetzt, wo getippt wird, nicht im Raster"). Er zieht nur
        // innerhalb von 0,12 Yards. 30,31 ist 0,19 von der nächsten
        // Marke entfernt -- und bleibt deshalb liegen, richtigerweise.
        //
        // Die Regel selbst misst `FangTests` gegen die Proben des
        // Servers. Hier geht es nur darum, dass der SCHALTER sie
        // überhaupt anwendet.
        let b = block()

        let nah = b.fangen(x: 30.46, y: 12.05)
        XCTAssertEqual(nah.x, 30.5, accuracy: 1e-9,
                       "Knapp an der Marke zieht der Magnet")
        XCTAssertEqual(nah.y, 12.0, accuracy: 1e-9)

        let weit = b.fangen(x: 30.31, y: 12.19)
        XCTAssertEqual(weit.x, 30.31, accuracy: 1e-9,
                       "Weiter weg bleibt der Punkt, wo er gesetzt wurde")
        XCTAssertEqual(weit.y, 12.19, accuracy: 1e-9)
    }

    func test_ohne_fang_bleibt_der_punkt_liegen() {
        var b = block()
        b.fangUmschalten()
        XCTAssertFalse(b.fang)
        let ziel = b.fangen(x: 30.31, y: 12.19)
        XCTAssertEqual(ziel.x, 30.31, accuracy: 1e-9)
        XCTAssertEqual(ziel.y, 12.19, accuracy: 1e-9)
    }

    func test_ohne_fang_gilt_das_feld_trotzdem() {
        // Das ist kein Fang, sondern eine Grenze: Der Server nimmt
        // nichts ausserhalb des Feldes an, und ein Punkt, der beim
        // Speichern zurückspringt, ist schlimmer als einer, der gar
        // nicht erst hinauskommt.
        var b = block()
        b.fangUmschalten()
        let ziel = b.fangen(x: -12, y: 999)
        XCTAssertEqual(ziel.x, 0)
        XCTAssertEqual(ziel.y, Double(Feld.afvd.breite))
    }

    func test_ohne_fang_bleibt_eine_figur_auf_ihrer_seite() {
        // Die Seitenregel ist Spielregel und keine Zeichenhilfe (R1).
        var b = block()
        b.fangUmschalten()
        let ziel = b.fangen(x: 41.3, y: 12.4, seite: .offense)
        XCTAssertEqual(ziel.x, 35, "Die Offense bleibt hinter der LOS")
        XCTAssertEqual(ziel.y, 12.4, accuracy: 1e-9)
    }

    func test_der_schalter_sagt_was_er_getan_hat() {
        // Ohne Rückmeldung ist ein Schalter, dessen Wirkung man erst beim
        // nächsten Zug sieht, eine Ratesache.
        var b = block()
        b.fangUmschalten()
        XCTAssertNotNil(b.meldung)
    }
}
