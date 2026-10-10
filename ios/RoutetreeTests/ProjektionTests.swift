import CoreGraphics
import XCTest
@testable import Routetree

/// Rechnet die App Yards genauso in Bildpunkte um wie der Server?
///
/// Die erwarteten Werte stammen aus `render.Projection` in Python,
/// ausgerechnet und hier eingetragen. Sie sind wenige und rund genug, um
/// sie im Kopf nachzuvollziehen -- deshalb stehen sie hier von Hand und
/// nicht in einer erzeugten Datei.
///
/// **Wofür das gebaut ist.** Im Editor tippt ein Finger auf Bildpunkte,
/// gespeichert werden Yards. Rechnet die App anders als der Server,
/// steht der Spieler nach dem Speichern woanders als da, wo der Finger
/// war, und der Ausdruck zeigt wieder etwas anderes.
final class ProjektionTests: XCTestCase {

    private let feld = Feld.afvd

    private func projektion(_ richtung: Int) -> Projektion {
        Projektion(feld: feld, los: feld.mitte, richtung: richtung)
    }

    private func gleich(_ a: CGPoint, _ x: Double, _ y: Double,
                        _ was: String) {
        XCTAssertEqual(Double(a.x), x, accuracy: 0.0001, "\(was): x")
        XCTAssertEqual(Double(a.y), y, accuracy: 0.0001, "\(was): y")
    }

    // MARK: - Dieselben Zahlen wie Python

    func test_die_los_liegt_auf_null() {
        // Der Nullpunkt der Zeichnung. Steht er falsch, ist alles falsch.
        for richtung in [1, -1] {
            let p = projektion(richtung)
            let mitte = p.zuBild(x: feld.mitte, y: 12.5)
            gleich(mitte, 125, 0, "Mitte der LOS, Richtung \(richtung)")
        }
    }

    func test_nach_rechts_angreifend() {
        let p = projektion(1)
        // Werte aus render.Projection(AFVD_FIELD, 35, 1).to_svg(...)
        gleich(p.zuBild(x: 35, y: 0), 250, 0, "Seitenlinie y=0")
        gleich(p.zuBild(x: 35, y: 25), 0, 0, "Seitenlinie y=25")
        gleich(p.zuBild(x: 45, y: 5), 200, -100, "zehn Yards voraus")
        gleich(p.zuBild(x: 25, y: 20), 50, 100, "zehn Yards zurück")
        gleich(p.zuBild(x: 35.5, y: 7.5), 175, -5, "halbe Yards")
    }

    func test_nach_links_angreifend() {
        // Dieselbe Zeichnung, gespiegelte Grundrichtung: Die Offense
        // greift auf dem Bildschirm weiter nach oben an, aber quer
        // kippt die Zuordnung.
        let p = projektion(-1)
        gleich(p.zuBild(x: 35, y: 0), 0, 0, "Seitenlinie y=0")
        gleich(p.zuBild(x: 35, y: 25), 250, 0, "Seitenlinie y=25")
        gleich(p.zuBild(x: 45, y: 5), 50, 100, "zehn Yards zurück")
        gleich(p.zuBild(x: 25, y: 20), 200, -100, "zehn Yards voraus")
        gleich(p.zuBild(x: 35.5, y: 7.5), 75, 5, "halbe Yards")
    }

    func test_der_ausschnitt_ist_der_der_viewbox() {
        // Python: viewBox „-60 -220 370 300", aspect 1,2333...
        let p = projektion(1)
        XCTAssertEqual(Double(p.ausschnitt.minX), -60, accuracy: 0.0001)
        XCTAssertEqual(Double(p.ausschnitt.minY), -220, accuracy: 0.0001)
        XCTAssertEqual(Double(p.ausschnitt.width), 370, accuracy: 0.0001)
        XCTAssertEqual(Double(p.ausschnitt.height), 300, accuracy: 0.0001)
        XCTAssertEqual(p.seitenverhaeltnis, 370.0 / 300.0, accuracy: 0.0001)
    }

    func test_hin_und_zurueck_trifft_denselben_punkt() {
        for richtung in [1, -1] {
            let p = projektion(richtung)
            for (x, y) in [(35.0, 12.5), (35.0, 0.0), (45.0, 5.0),
                           (25.0, 20.0), (35.5, 7.5), (12.0, 24.5)] {
                let zurueck = p.zuFeld(p.zuBild(x: x, y: y))
                XCTAssertEqual(zurueck.x, x, accuracy: 0.0001)
                XCTAssertEqual(zurueck.y, y, accuracy: 0.0001)
            }
        }
    }

    // MARK: - Auf den Bildschirm

    func test_der_ausschnitt_passt_mittig_in_die_flaeche() {
        let p = projektion(1)
        let groesse = CGSize(width: 740, height: 300)   // doppelt so breit
        let (faktor, _) = p.aufFlaeche(groesse)
        XCTAssertEqual(faktor, 1, accuracy: 0.0001,
                       "die Höhe ist das Engere, also Faktor 1")

        // Der Mittelpunkt des Ausschnitts liegt in der Mitte der Fläche.
        let mitte = p.aufBildschirm(x: feld.mitte, y: 12.5, groesse: groesse)
        XCTAssertEqual(Double(mitte.x), 370, accuracy: 0.0001)
        // y = 0 ist die LOS; sie liegt nicht in der Bildmitte, weil vor
        // ihr mehr Feld gezeigt wird als hinter ihr.
        XCTAssertEqual(Double(mitte.y), 220, accuracy: 0.0001)
    }

    func test_der_finger_kommt_wieder_bei_yards_an() {
        let p = projektion(1)
        let groesse = CGSize(width: 390, height: 700)
        for (x, y) in [(35.0, 12.5), (41.0, 3.0), (30.5, 22.0)] {
            let punkt = p.aufBildschirm(x: x, y: y, groesse: groesse)
            let zurueck = p.vomBildschirm(punkt, groesse: groesse)
            XCTAssertEqual(zurueck.x, x, accuracy: 0.0001)
            XCTAssertEqual(zurueck.y, y, accuracy: 0.0001)
        }
    }

    func test_eine_flaeche_ohne_groesse_stuerzt_nicht_ab() {
        // SwiftUI misst beim ersten Durchlauf gern null.
        let p = projektion(1)
        let (faktor, _) = p.aufFlaeche(.zero)
        XCTAssertEqual(faktor, 1)
    }

    // MARK: - Der Fang

    func test_der_fang_zieht_nur_was_KNAPP_daneben_liegt() {
        // HIER STAND DIE REGEL VOR RUNDE 4: „12,3 rastet auf 12,5".
        //
        // Seither ist der Fang magnetisch (Niklas, 27.08.2026: „Punkte
        // werden gesetzt, wo getippt wird, nicht im Raster"). Er zieht
        // nur innerhalb von 0,12 Yards; 12,3 ist 0,2 entfernt und
        // bleibt liegen.
        //
        // ALLE ZAHLEN HIER SIND GEGEN `fang.rasten` AUF DEM SERVER
        // NACHGERECHNET, nicht ausgedacht. Dieselbe Regel, zwei
        // Fassungen -- und `FangTests` faehrt beide durch dieselben
        // Proben.
        XCTAssertEqual(Projektion.fangen(12.1), 12.0, accuracy: 0.0001,
                       "0,1 daneben: der Magnet zieht")
        XCTAssertEqual(Projektion.fangen(12.3), 12.3, accuracy: 0.0001,
                       "0,2 daneben: bleibt liegen")
        XCTAssertEqual(Projektion.fangen(-0.2), -0.2, accuracy: 0.0001,
                       "auch am Nullpunkt wird nicht gezogen")
    }

    func test_genau_zwischen_zwei_marken_wird_nicht_gezogen() {
        // 12,25 liegt genau zwischen 12,0 und 12,5 -- also 0,25 von
        // beiden entfernt und damit weiter, als der Magnet reicht.
        //
        // Vorher stand hier die Frage, WIE gerundet wird (kaufmaennisch
        // zur geraden Zahl, wie Python). Die stellt sich seit Runde 4
        // gar nicht mehr: Was genau in der Mitte liegt, wird
        // ueberhaupt nicht mehr gezogen. Die Rundungsregel steht
        // trotzdem noch in `fang.py` -- sie war einmal wichtig, und wer
        // sie beim naechsten Umbau wegnimmt, holt den alten Fehler
        // zurueck.
        XCTAssertEqual(Projektion.fangen(12.25), 12.25, accuracy: 0.0001)
        XCTAssertEqual(Projektion.fangen(12.75), 12.75, accuracy: 0.0001)
    }

    func test_der_fang_haelt_den_punkt_im_feld() {
        let p = projektion(1)
        let raus = p.fangen(x: -3, y: 99)
        XCTAssertEqual(raus.x, 0, accuracy: 0.0001)
        XCTAssertEqual(raus.y, Double(feld.breite), accuracy: 0.0001)
    }

    func test_der_winkelfang_rastet_richtung_und_laenge() {
        // ERST DIE RICHTUNG, DANN DIE LÄNGE, wie `gefangeneRichtung` in
        // editor.js. Bis B4 blieb die Länge hier stehen; dieselbe Geste
        // ergab im Browser eine Route über 12,0 Yards und in der App eine
        // über 12,0067 -- ein Unterschied, den man erst sieht, wenn man
        // beides nebeneinander legt, und dann ist er teuer.
        let p = projektion(1)
        let von = (x: 35.0, y: 12.5)
        // Zwölf Yards nach vorn, zwei Grad schief gezogen.
        let schief = (x: 47.0, y: 12.5 + 0.4)
        let gerastet = p.fangenAufWinkel(von: von, nach: schief)
        XCTAssertEqual(gerastet.y, 12.5, accuracy: 0.0001,
                       "auf 0 Grad gerastet")
        XCTAssertEqual(gerastet.x, 47.0, accuracy: 0.0001,
                       "und die Länge aufs halbe Yard")
    }

    func test_eine_kurze_strecke_bekommt_einen_ganzen_rasterschritt() {
        // GENAU EIN VIERTEL YARD ist der Fall, für den der `max` da ist:
        // Er kommt gerade durch die Sperre unten, und das Raster machte
        // daraus die Länge null -- der Punkt läge auf seinem Vorgänger,
        // und der Pfeil hätte keine Richtung mehr. (0,25 / 0,5 ist 0,5,
        // und kaufmännisch gerundet ist das 0.)
        let p = projektion(1)
        let gerastet = p.fangenAufWinkel(von: (x: 35, y: 12.5),
                                         nach: (x: 35.25, y: 12.5))
        XCTAssertEqual(gerastet.x, 35.5, accuracy: 0.0001)
        XCTAssertEqual(gerastet.y, 12.5, accuracy: 0.0001)
    }

    func test_kuerzer_als_ein_halber_rasterschritt_bleibt_liegen() {
        // Ein Zittern ist kein Wegpunkt. Dieselbe Sperre wie in
        // `gefangeneRichtung`, sonst setzte ein Finger auf dem Handy
        // Ecken, die im Browser nie entstünden.
        let p = projektion(1)
        let gerastet = p.fangenAufWinkel(von: (x: 35, y: 12.5),
                                         nach: (x: 35.2, y: 12.6))
        XCTAssertEqual(gerastet.x, 35, accuracy: 0.0001)
        XCTAssertEqual(gerastet.y, 12.5, accuracy: 0.0001)
    }

    func test_der_winkelfang_kennt_die_diagonale() {
        let p = projektion(1)
        let gerastet = p.fangenAufWinkel(von: (x: 35, y: 12.5),
                                         nach: (x: 40, y: 17.8))
        // 45 Grad: gleich viel nach vorn wie zur Seite.
        XCTAssertEqual(gerastet.x - 35, gerastet.y - 12.5, accuracy: 0.0001)
    }

    func test_ohne_laenge_gibt_es_keine_richtung() {
        // Ein Tippen ohne Ziehen. Ohne diesen Fall käme `atan2(0, 0)`
        // heraus, und der Punkt spränge irgendwohin.
        let p = projektion(1)
        let gerastet = p.fangenAufWinkel(von: (x: 35, y: 12.5),
                                         nach: (x: 35, y: 12.5))
        XCTAssertEqual(gerastet.x, 35, accuracy: 0.0001)
        XCTAssertEqual(gerastet.y, 12.5, accuracy: 0.0001)
    }

    // MARK: - Das Feld füllt den Bildschirm

    /// Niklas am 01.09.2026: „das feld an bildschirmränder angepasst
    /// werden sollte ... da ist halt super viel platz." Gemessen wird
    /// deshalb genau das: Bleibt nach dem Dehnen noch schwarzer Rand?
    ///
    /// **Wozu diese Prüfung taugt.** Sie fällt um, wenn jemand das Dehnen
    /// wieder herausnimmt, und sie fällt um, wenn es zu weit dehnt --
    /// beides sieht man auf einem Bild sofort und in einer Zahl nie.
    private func fuelltAus(_ p: Projektion, _ groesse: CGSize) -> Bool {
        let (faktor, _) = p.aufFlaeche(groesse)
        let hoehe = Double(p.ausschnitt.height) * faktor
        let breite = Double(p.ausschnitt.width) * faktor
        return abs(hoehe - Double(groesse.height)) < 0.5
            && abs(breite - Double(groesse.width)) < 0.5
    }

    func test_hochkant_bleibt_kein_schwarzer_rand() {
        let hoch = CGSize(width: 390, height: 620)
        let eng = projektion(1)
        XCTAssertFalse(fuelltAus(eng, hoch),
                       "Ohne Dehnen bliebe Rand -- sonst misst der Test nichts")
        XCTAssertTrue(fuelltAus(eng.gedehnt(auf: hoch), hoch))
    }

    func test_der_massstab_bleibt_gleich() {
        // Das Feld wird nicht größer, es kommt Rasen dazu. Ein Yard muss
        // hinterher so viele Bildpunkte breit sein wie vorher, sonst
        // springen die Figuren beim Drehen des Telefons in der Größe.
        let hoch = CGSize(width: 390, height: 620)
        let eng = projektion(1)
        let weit = eng.gedehnt(auf: hoch)
        XCTAssertEqual(eng.aufFlaeche(hoch).faktor,
                       weit.aufFlaeche(hoch).faktor, accuracy: 0.0001)
    }

    func test_gedehnt_wird_nur_nach_aussen() {
        let weit = projektion(1).gedehnt(auf: CGSize(width: 390, height: 620))
        XCTAssertGreaterThanOrEqual(weit.vorne, 22)
        XCTAssertGreaterThanOrEqual(weit.hinten, 8)
    }

    // WAS DAS DEHNEN ZUSAGT -- und was nicht.
    //
    // Es sagt NICHT zu, dass der Ausschnitt im Feld liegt: Das feste
    // Fenster von 22 Yards nach vorn reicht schon ungedehnt ueber das
    // Feldende hinaus, sobald die LOS naeher als 22 Yards davor liegt.
    // Das ist so, seit es das Fenster gibt, und im Ausdruck genauso.
    //
    // Es sagt zu, NICHTS DAZUZULEGEN, was nicht mehr auf dem Feld ist.
    // Was vorn nicht mehr hingeht, geht nach hinten.
    //
    // Die erste Fassung dieser Pruefung hat das Falsche gemessen und ist
    // auf dem Laeufer umgefallen -- richtigerweise: Sie verlangte etwas,
    // was nie jemand versprochen hatte.

    func test_nie_ueber_das_feldende_hinaus_dazulegen() {
        // Die LOS liegt einen Yard vor der Torlinie: Nach vorn sind nur
        // noch elf Yards Feld (die Endzone), also muss fast alles nach
        // hinten gehen.
        let los = Double(feld.torlinieRechts) - 1
        let eng = Projektion(feld: feld, los: los, richtung: 1)
        let weit = eng.gedehnt(auf: CGSize(width: 390, height: 900))
        let vorPlatz = Double(feld.gesamtLaenge) - los

        XCTAssertEqual(weit.vorne, max(eng.vorne, vorPlatz), accuracy: 0.0001,
                       "Vor der Endzone darf nichts dazukommen")
        XCTAssertGreaterThan(weit.hinten, eng.hinten,
                             "Was vorn nicht hingeht, gehoert nach hinten")
        XCTAssertLessThanOrEqual(weit.hinten, los + 0.0001,
                                 "Hinter dem Nullpunkt ist auch kein Feld")
    }

    func test_andere_richtung_ebenso() {
        // Richtung -1: Die Offense greift zum Nullpunkt hin an, „vorne"
        // zeigt also dorthin. Bei los = 1 ist da fast nichts mehr.
        let eng = Projektion(feld: feld, los: 1, richtung: -1)
        let weit = eng.gedehnt(auf: CGSize(width: 390, height: 900))

        XCTAssertEqual(weit.vorne, max(eng.vorne, 1), accuracy: 0.0001)
        XCTAssertGreaterThan(weit.hinten, eng.hinten)
        XCTAssertLessThanOrEqual(
            weit.hinten, Double(feld.gesamtLaenge) - 1 + 0.0001)
    }

    func test_in_der_feldmitte_waechst_beides() {
        // Der Normalfall: Platz nach beiden Seiten, also waechst beides
        // -- und zusammen genau so weit, dass die Flaeche voll wird.
        //
        // NICHT geprueft wird, welche Seite mehr abbekommt. Anteilig
        // bekaeme vorne mehr; die Deckelung am Feldende dreht das
        // gelegentlich um. Eine Pruefung darauf misst die Arithmetik der
        // Verteilung und nicht das, was zu sehen ist.
        let hoch = CGSize(width: 390, height: 620)
        let eng = projektion(1)
        let weit = eng.gedehnt(auf: hoch)
        XCTAssertGreaterThan(weit.vorne, eng.vorne)
        XCTAssertGreaterThan(weit.hinten, eng.hinten)

        let quer = Double(feld.breite) + 2 * eng.rand
        XCTAssertEqual(weit.vorne + weit.hinten,
                       quer * Double(hoch.height) / Double(hoch.width),
                       accuracy: 0.0001)
    }

    func test_quer_bleibt_es_wie_es_war() {
        // Ist die Fläche breiter als der Ausschnitt, gibt es nichts zu
        // dehnen -- sonst liefe das Feld beim Drehen aus dem Bild.
        let quer = CGSize(width: 900, height: 300)
        let eng = projektion(1)
        XCTAssertEqual(eng.gedehnt(auf: quer), eng)
    }

    func test_ohne_flaeche_passiert_nichts() {
        let eng = projektion(1)
        XCTAssertEqual(eng.gedehnt(auf: .zero), eng)
    }

    func test_gedehnt_wird_nie_ueber_das_ziel_hinaus() {
        // DIE PRUEFUNG, DIE DEN FEHLER VOM 01.09.2026 GEFANGEN HAETTE.
        //
        // Wird der Ausschnitt GROESSER als gebraucht, begrenzt nicht
        // mehr die Breite den Massstab, sondern die Hoehe -- und dann
        // schrumpft das Feld, statt zu wachsen. Das ist genau das
        // Gegenteil dessen, wofuer das Dehnen da ist, und es sieht auf
        // einem Bildschirmfoto aus wie ein zufaellig zu kleines Feld.
        //
        // Ueber JEDE Lage der Line of Scrimmage und beide Richtungen,
        // weil der Fehler nur dicht an der Torlinie auftrat.
        for hoch in [CGSize(width: 390, height: 620),
                     CGSize(width: 390, height: 900),
                     CGSize(width: 320, height: 1000)] {
            let gebraucht = (Double(feld.breite) + 12)
                * Double(hoch.height) / Double(hoch.width)
            for richtung in [1, -1] {
                for los in stride(from: 0.0,
                                  through: Double(feld.gesamtLaenge),
                                  by: 1.0) {
                    let eng = Projektion(feld: feld, los: los,
                                         richtung: richtung)
                    let weit = eng.gedehnt(auf: hoch)
                    XCTAssertLessThanOrEqual(
                        weit.vorne + weit.hinten, gebraucht + 0.0001,
                        "los \(los), Richtung \(richtung): gedehnt auf "
                        + "\(weit.vorne + weit.hinten) statt \(gebraucht)")
                    // Und nie schmaler als vorher: Das Dehnen nimmt
                    // nichts weg.
                    XCTAssertGreaterThanOrEqual(weit.vorne, eng.vorne)
                    XCTAssertGreaterThanOrEqual(weit.hinten, eng.hinten)
                }
            }
        }
    }

    func test_das_feld_wird_dabei_nie_kleiner() {
        // Dieselbe Sache, aber gemessen an dem, was man SIEHT: Der
        // Massstab darf durch das Dehnen nicht sinken.
        let hoch = CGSize(width: 390, height: 900)
        for richtung in [1, -1] {
            for los in stride(from: 0.0,
                              through: Double(feld.gesamtLaenge), by: 1.0) {
                let eng = Projektion(feld: feld, los: los,
                                     richtung: richtung)
                let weit = eng.gedehnt(auf: hoch)
                XCTAssertGreaterThanOrEqual(
                    weit.aufFlaeche(hoch).faktor,
                    eng.aufFlaeche(hoch).faktor - 0.0001,
                    "los \(los), Richtung \(richtung): Feld geschrumpft")
            }
        }
    }
}

/// Der Ausschnitt, den die APP zeigt (R48).
///
/// Cyell am 01.09.2026: „bei der Detail Ansicht würde ich nur 10 yrs
/// hinter der los sowie 20 nach der los anzeigen." Vorher waren es 8
/// und 22 -- die Zahlen des Ausdrucks, und dort sind sie richtig.
///
/// Dabei fiel eine Lücke auf, die älter ist als R48: Auf dem Server
/// weitet `fenster_fuer` das Fenster, bis der ganze Play hineinpasst.
/// Diese Rechnung gab es in der App nicht, obwohl sie seit B3 selbst
/// zeichnet -- ein Weg über die Kante hinaus wurde schlicht
/// abgeschnitten.
final class AppausschnittTests: XCTestCase {

    private let feld = Feld.afvd

    private func sicht(_ richtung: Int = 1) -> Projektion {
        Projektion.fuerDieApp(feld: feld, los: feld.mitte,
                              richtung: richtung)
    }

    func test_die_app_zeigt_zehn_hinten_und_zwanzig_vorn() {
        XCTAssertEqual(sicht().hinten, 10, accuracy: 0.0001)
        XCTAssertEqual(sicht().vorne, 20, accuracy: 0.0001)
    }

    func test_die_app_zeichnet_ohne_beschriftungsrand() {
        // Der Streifen ist auf dem Papier richtig und in der App leer:
        // `Feldansicht` schreibt dort nichts hinein.
        XCTAssertEqual(sicht().rand, 0, accuracy: 0.0001)
    }

    func test_der_ausdruck_behaelt_seine_eigenen_zahlen() {
        // Die Vorgabe ist die des Servers, und `ProjektionTests` rechnet
        // gegen dessen Zahlen. Wer den App-Ausschnitt ändert, darf sie
        // nicht mitnehmen.
        let normal = Projektion(feld: feld, los: feld.mitte, richtung: 1)
        XCTAssertEqual(normal.hinten, 8, accuracy: 0.0001)
        XCTAssertEqual(normal.vorne, 22, accuracy: 0.0001)
        XCTAssertEqual(normal.rand, 6, accuracy: 0.0001)
    }

    // MARK: - passendFuer

    private func zeichnungMit(_ x: Double) -> Zeichnung {
        var z = Zeichnung()
        z.spieler = [Zeichnung.Spieler(
            id: "a", seite: .offense, rolle: "X", kuerzel: "X",
            x: feld.mitte, y: 5)]
        z.linien = [Zeichnung.Linie(
            spieler: "a", art: .route,
            punkte: [Zeichnung.Punkt(x: feld.mitte, y: 5),
                     Zeichnung.Punkt(x: x, y: 5)])]
        return z
    }

    func test_ein_kurzer_play_weitet_nichts() {
        // Sonst wäre ein Play mit kurzen Wegen plötzlich
        // formatfüllend -- dieselbe Zusage wie `fenster_fuer`.
        let eng = sicht()
        let passend = eng.passendFuer(zeichnungMit(feld.mitte + 5))
        XCTAssertEqual(passend.vorne, eng.vorne, accuracy: 0.0001)
        XCTAssertEqual(passend.hinten, eng.hinten, accuracy: 0.0001)
    }

    func test_eine_lange_route_weitet_nach_vorn() {
        // DER FALL, DER VORHER ABGESCHNITTEN WURDE. 30 Yards nach vorn
        // bei einem Fenster von 20: zehn Yards lagen ausserhalb.
        let passend = sicht().passendFuer(zeichnungMit(feld.mitte + 30))
        XCTAssertGreaterThanOrEqual(passend.vorne, 30,
                                    "Das Ende der Route liegt draussen")
        // Mit Saum, damit sie nicht auf der Kante endet.
        XCTAssertEqual(passend.vorne, 30 + Projektion.appSaum,
                       accuracy: 0.0001)
    }

    func test_ein_weg_nach_hinten_weitet_nach_hinten() {
        let passend = sicht().passendFuer(zeichnungMit(feld.mitte - 18))
        XCTAssertEqual(passend.hinten, 18 + Projektion.appSaum,
                       accuracy: 0.0001)
        XCTAssertEqual(passend.vorne, sicht().vorne, accuracy: 0.0001,
                       "Nach vorn war nichts zu weiten")
    }

    func test_bei_richtung_minus_eins_zaehlt_dieselbe_richtung() {
        // „Vorne" ist die Angriffsrichtung, nicht die Feldrichtung.
        let passend = sicht(-1).passendFuer(zeichnungMit(feld.mitte - 30))
        XCTAssertEqual(passend.vorne, 30 + Projektion.appSaum,
                       accuracy: 0.0001)
    }

    func test_mehr_als_das_feld_gibt_es_nicht_zu_sehen() {
        // Dieselbe Grenze wie auf dem Server. Ohne sie ergäbe ein
        // verrutschter Punkt einen Ausschnitt von tausend Yards, und
        // der Play wäre ein Punkt in der Mitte.
        let weit = sicht().passendFuer(zeichnungMit(feld.mitte + 10_000))
        XCTAssertLessThanOrEqual(weit.vorne, Double(feld.gesamtLaenge))
    }

    func test_die_leere_zeichnung_aendert_nichts() {
        let eng = sicht()
        let passend = eng.passendFuer(Zeichnung())
        XCTAssertEqual(passend.vorne, eng.vorne, accuracy: 0.0001)
        XCTAssertEqual(passend.hinten, eng.hinten, accuracy: 0.0001)
        XCTAssertEqual(passend.rand, eng.rand, accuracy: 0.0001)
    }
}
