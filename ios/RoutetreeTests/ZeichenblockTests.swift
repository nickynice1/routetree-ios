import CoreGraphics
import XCTest
@testable import Routetree

/// Zeichnet ein Finger dasselbe wie eine Maus im Browser?
///
/// `Zeichenblock` ist die Antwort der App auf `editor.js`. Gemessen wird
/// hier, was der Auftrag unter B4 verlangt: Wegpunkte, die sechs
/// Linienarten, die Enden -- und die Ausnahmen, an denen sich zwei
/// Editoren still auseinanderleben.
///
/// **Warum das gemessen und nicht angesehen wird.** Es gibt keinen Mac.
/// Eine Regel, die nur in einer SwiftUI-Ansicht steht, lässt sich hier
/// nicht ausprobieren, sondern nur behaupten.
final class ZeichenblockTests: XCTestCase {

    /// Faktor genau 1: Der Ausschnitt ist 370 mal 300 Bildeinheiten, also
    /// rechnet sich jede Erwartung im Kopf nach.
    private let groesse = CGSize(width: 370, height: 300)
    private let feld = Feld.afvd

    private var projektion: Projektion {
        Projektion(feld: feld, los: feld.mitte, richtung: 1)
    }

    private func schirm(_ x: Double, _ y: Double) -> CGPoint {
        projektion.aufBildschirm(x: x, y: y, groesse: groesse)
    }

    /// Zwei Spieler auf der LOS, fünf Yards auseinander.
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

    // MARK: - Anfangen

    func test_ein_tipp_auf_einen_spieler_beginnt_seine_linie() {
        var b = block(.linie(.route))
        b.tippen(schirm(35, 12.5), groesse: groesse)

        XCTAssertEqual(b.entwurf?.spieler, "o_qb")
        XCTAssertEqual(b.entwurf?.punkte.count, 1)
        XCTAssertEqual(b.entwurf?.art, .route)
        XCTAssertEqual(b.fehlendePunkte, 1, "eine Route braucht zwei Punkte")
        XCTAssertTrue(b.zeichnung.linien.isEmpty,
                      "der Entwurf gehört noch nicht in die Zeichnung")
    }

    func test_der_erste_punkt_liegt_genau_auf_dem_spieler() {
        // Ein gefangener Anfang risse die Linie sichtbar von der Figur ab.
        let zeichnung = Zeichnung(spieler: [
            Zeichnung.Spieler(id: "o_x", seite: .offense, kuerzel: "X",
                              x: 35.3, y: 20.2),
        ])
        var b = Zeichenblock(zeichnung: zeichnung, projektion: projektion)
        b.werkzeugSetzen(.linie(.route))
        b.tippen(schirm(35.3, 20.2), groesse: groesse)

        XCTAssertEqual(b.entwurf?.punkte.first?.x ?? 0, 35.3, accuracy: 0.0001)
        XCTAssertEqual(b.entwurf?.punkte.first?.y ?? 0, 20.2, accuracy: 0.0001)
    }

    func test_eine_freie_linie_faengt_magnetisch_an() {
        // Ohne Spieler darunter: Der Anfang wird gefangen, wie im
        // Browser -- aber MAGNETISCH (Runde 4). 41,3 ist 0,2 von der
        // naechsten Marke entfernt und bleibt liegen; 4,4 ist 0,1
        // entfernt und wird gezogen.
        //
        // Beide Werte sind gegen `fang.rasten` auf dem Server
        // nachgerechnet.
        var b = block(.linie(.zone))
        b.tippen(schirm(41.3, 4.4), groesse: groesse)

        XCTAssertNil(b.entwurf?.spieler, "eine Zone hängt an niemandem")
        XCTAssertEqual(b.entwurf?.punkte.first?.x ?? 0, 41.3, accuracy: 0.0001,
                       "0,2 daneben: bleibt liegen")
        XCTAssertEqual(b.entwurf?.punkte.first?.y ?? 0, 4.5, accuracy: 0.0001,
                       "0,1 daneben: der Magnet zieht")
    }

    // MARK: - Wegpunkte

    func test_der_zweite_punkt_rastet_auf_winkel_und_raster() {
        var b = block(.linie(.route))
        b.tippen(schirm(35, 12.5), groesse: groesse)
        // Zwölf Yards nach vorn, etwas schief gezogen.
        b.tippen(schirm(47.3, 12.9), groesse: groesse)

        XCTAssertEqual(b.entwurf?.punkte.count, 2)
        let punkt = b.entwurf?.punkte.last
        // DER WINKEL rastet weiter: 1,9 Grad sind naeher als die sechs
        // Grad, die der Winkelmagnet zieht. Die LAENGE nicht -- 12,3
        // Yards sind 0,2 von der naechsten Marke entfernt.
        //
        // Der Winkelmagnet ist ENGER als der fuer die Laenge, und das
        // ist Absicht: Ein schiefer Winkel faellt im Ausdruck auf, eine
        // schiefe Position nicht. Nachgerechnet mit `fang.richtung` auf
        // dem Server: (47.306502346320826, 12.5).
        XCTAssertEqual(punkt?.y ?? 0, 12.5, accuracy: 0.0001,
                       "auf null Grad gerastet")
        XCTAssertEqual(punkt?.x ?? 0, 47.3065, accuracy: 0.001,
                       "die Länge bleibt, wo gezogen wurde")
    }

    func test_zwei_punkte_aufeinander_entstehen_nicht() {
        // Ein Pfeil ohne Strecke hat keine Richtung. Ein Finger trifft
        // dieselbe Stelle leichter zweimal als eine Maus.
        var b = block(.linie(.route))
        b.tippen(schirm(35, 12.5), groesse: groesse)
        b.tippen(schirm(35, 12.5), groesse: groesse)

        XCTAssertEqual(b.entwurf?.punkte.count, 1)
    }

    func test_ein_weiterer_tipp_haengt_eine_ecke_an() {
        var b = block(.linie(.route))
        b.tippen(schirm(35, 12.5), groesse: groesse)
        b.tippen(schirm(45, 12.5), groesse: groesse)     // zehn nach vorn
        b.tippen(schirm(45, 5), groesse: groesse)        // dann nach außen

        XCTAssertEqual(b.entwurf?.punkte.count, 3, "eine Out-Route")
        XCTAssertEqual(b.fehlendePunkte, 0)
    }

    func test_punkt_zurueck_nimmt_den_letzten_und_am_ende_den_entwurf() {
        var b = block(.linie(.route))
        b.tippen(schirm(35, 12.5), groesse: groesse)
        b.tippen(schirm(45, 12.5), groesse: groesse)
        b.punktZurueck()
        XCTAssertEqual(b.entwurf?.punkte.count, 1)

        b.punktZurueck()
        XCTAssertNil(b.entwurf, "ohne Punkte gibt es keinen Entwurf mehr")
    }

    func test_der_zeiger_ist_nur_vorschau() {
        var b = block(.linie(.route))
        b.tippen(schirm(35, 12.5), groesse: groesse)
        b.zeigen(schirm(45, 12.5), groesse: groesse)

        XCTAssertEqual(b.entwurf?.punkte.count, 1, "der Zeiger setzt nichts")
        XCTAssertEqual(b.zeiger?.x ?? 0, 45, accuracy: 0.0001)

        b.tippen(schirm(45, 12.5), groesse: groesse)
        XCTAssertNil(b.zeiger, "beim Setzen ist die Vorschau vorbei")
    }

    // MARK: - Abschließen

    func test_eine_route_mit_einem_punkt_wird_verworfen() {
        var b = block(.linie(.route))
        b.tippen(schirm(35, 12.5), groesse: groesse)

        XCTAssertFalse(b.abschliessen())
        XCTAssertTrue(b.zeichnung.linien.isEmpty)
        XCTAssertNil(b.entwurf)
        XCTAssertFalse(b.geaendert, "verworfen ist keine Änderung")
    }

    func test_eine_zone_braucht_drei_punkte() {
        var b = block(.linie(.zone))
        b.tippen(schirm(40, 5), groesse: groesse)
        b.tippen(schirm(45, 5), groesse: groesse)
        XCTAssertEqual(b.fehlendePunkte, 1, "zwei Punkte sind keine Fläche")
        XCTAssertFalse(b.abschliessen())

        b.werkzeugSetzen(.linie(.zone))
        b.tippen(schirm(40, 5), groesse: groesse)
        b.tippen(schirm(45, 5), groesse: groesse)
        b.tippen(schirm(45, 10), groesse: groesse)
        XCTAssertEqual(b.fehlendePunkte, 0)
        XCTAssertTrue(b.abschliessen())
        XCTAssertEqual(b.zeichnung.linien.count, 1)
        XCTAssertEqual(b.zeichnung.linien.first?.art, .zone)
    }

    func test_die_fertige_linie_ist_ausgewaehlt() {
        // Direkt danach will man ihr Ende einstellen.
        var b = block(.linie(.route))
        b.tippen(schirm(35, 12.5), groesse: groesse)
        b.tippen(schirm(45, 12.5), groesse: groesse)
        XCTAssertTrue(b.abschliessen())

        XCTAssertEqual(b.auswahl, .linie(0))
        XCTAssertEqual(b.ausgewaehlteLinie?.spieler, "o_qb")
        XCTAssertTrue(b.geaendert)
    }

    func test_eine_neue_linie_ersetzt_die_alte_derselben_position() {
        var b = block(.linie(.route))
        b.tippen(schirm(35, 12.5), groesse: groesse)
        b.tippen(schirm(45, 12.5), groesse: groesse)
        b.abschliessen()

        b.werkzeugSetzen(.linie(.motion))
        b.tippen(schirm(35, 12.5), groesse: groesse)
        b.tippen(schirm(35, 5), groesse: groesse)
        b.abschliessen()

        XCTAssertEqual(b.zeichnung.linien.count, 1,
                       "jede Position hat genau einen Weg")
        XCTAssertEqual(b.zeichnung.linien.first?.art, .motion)
        XCTAssertEqual(b.meldung,
                       "Die bisherige Linie dieser Position wurde ersetzt.")
    }

    // MARK: - Die Option an einer bestehenden Route (R68)

    /// Eine Route zeichnen und daran eine Option ansetzen.
    private func mitOption() -> Zeichenblock {
        var b = block(.linie(.route))
        b.tippen(schirm(35, 12.5), groesse: groesse)
        b.tippen(schirm(45, 12.5), groesse: groesse)
        b.abschliessen()
        // Ausgewählt ist danach die eben fertige Linie -- `optionstellen`
        // fragt genau die.
        b.optionAnsetzen(ab: 1)
        b.tippen(schirm(45, 20), groesse: groesse)
        b.abschliessen()
        return b
    }

    func test_eine_option_laesst_die_route_stehen() {
        // NIKLAS AM 08.09.2026: „denn wird immer editor nur noch die
        // option route angezeigt aber nicht mehr die normale route."
        //
        // Die Regel „jede Position hat genau einen Weg" hat die
        // Originalroute weggeräumt, sobald die Option fertig war -- eine
        // Option gehört ja demselben Spieler. Aus der Gabelung wurde ein
        // einzelner Ast.
        let b = mitOption()
        XCTAssertEqual(b.zeichnung.linien.count, 2)
        XCTAssertEqual(Set(b.zeichnung.linien.map(\.art)), [.route, .option])
        XCTAssertEqual(Set(b.zeichnung.linien.map(\.spieler)), ["o_qb"])
    }

    // MARK: - Snap und Route am selben Spieler (R88)

    func test_ein_snap_laesst_die_route_stehen() {
        // NIKLAS AM 09.09.2026: „Wenn ich einen Spieler eine „Abgabe"
        // bzw. „snap" Linie gebe, kann ich ihm keine normale Route mehr
        // geben, es geht nur eine Sache." Und mit Bild: „wenn ich
        // Speicher denn geht eine von beiden Routen weg."
        //
        // Der Center snappt und läuft danach seine Route. Zwei Wege
        // derselben Figur, aber nicht dasselbe -- der eine ist der Ball,
        // der andere der Mensch.
        var b = block(.linie(.route))
        b.tippen(schirm(35, 12.5), groesse: groesse)
        b.tippen(schirm(45, 12.5), groesse: groesse)
        b.abschliessen()
        b.werkzeugSetzen(.linie(.handoff))
        b.tippen(schirm(35, 12.5), groesse: groesse)
        b.tippen(schirm(30, 8), groesse: groesse)
        b.abschliessen()

        XCTAssertEqual(b.zeichnung.linien.count, 2)
        XCTAssertEqual(Set(b.zeichnung.linien.map(\.art)), [.route, .handoff])
        XCTAssertEqual(Set(b.zeichnung.linien.map(\.spieler)), ["o_qb"])
    }

    func test_eine_zweite_route_ersetzt_die_erste_weiterhin() {
        // Die Regel wird nicht abgeschafft, sie gilt nur je Sorte: Zwei
        // Laufwege an einer Figur wären zwei Wege für einen Menschen.
        var b = block(.linie(.route))
        b.tippen(schirm(35, 12.5), groesse: groesse)
        b.tippen(schirm(45, 12.5), groesse: groesse)
        b.abschliessen()
        b.werkzeugSetzen(.linie(.route))
        b.tippen(schirm(35, 12.5), groesse: groesse)
        b.tippen(schirm(35, 20), groesse: groesse)
        b.abschliessen()

        XCTAssertEqual(b.zeichnung.linien.count, 1)
    }

    func test_die_option_setzt_am_gewaehlten_punkt_an() {
        let b = mitOption()
        let option = b.zeichnung.linien.first { $0.art == .option }
        XCTAssertEqual(option?.punkte.first?.x ?? 0, 45, accuracy: 0.001)
        XCTAssertEqual(option?.punkte.first?.y ?? 0, 12.5, accuracy: 0.001)
    }

    func test_eine_zweite_option_ersetzt_die_erste() {
        // Zwei Gabelungen an einer Route wären keine Gabelung mehr,
        // sondern ein Gestrüpp. Die Regel bleibt, sie gilt nur je Sorte.
        var b = mitOption()
        // Die Route wieder anwählen -- angetippt wird sie auf halbem
        // Weg, wo die Option nicht liegt.
        b.werkzeugSetzen(.auswahl)
        b.tippen(schirm(40, 12.5), groesse: groesse)
        b.optionAnsetzen(ab: 1)
        b.tippen(schirm(45, 5), groesse: groesse)
        b.abschliessen()
        XCTAssertEqual(b.zeichnung.linien.count, 2)
        XCTAssertEqual(b.meldung,
                       "Die bisherige Option dieser Position wurde ersetzt.")
    }

    func test_eine_neue_route_laesst_die_option_stehen() {
        // Wer eine Route nachzieht, soll nicht stillschweigend den
        // zweiten Ast verlieren.
        var b = mitOption()
        b.werkzeugSetzen(.linie(.route))
        b.tippen(schirm(35, 12.5), groesse: groesse)
        b.tippen(schirm(35, 20), groesse: groesse)
        b.abschliessen()
        XCTAssertEqual(b.zeichnung.linien.count, 2)
        XCTAssertEqual(Set(b.zeichnung.linien.map(\.art)), [.route, .option])
    }

    func test_ein_tipp_auf_einen_anderen_spieler_beginnt_dort_neu() {
        // Vorher wurde daraus ein Wegpunkt, und die Linie lief quer durch
        // die Aufstellung.
        var b = block(.linie(.route))
        b.tippen(schirm(35, 12.5), groesse: groesse)
        b.tippen(schirm(45, 12.5), groesse: groesse)
        b.tippen(schirm(35, 20), groesse: groesse)     // der andere Spieler

        XCTAssertEqual(b.zeichnung.linien.count, 1, "die erste ist abgelegt")
        XCTAssertEqual(b.zeichnung.linien.first?.spieler, "o_qb")
        XCTAssertEqual(b.entwurf?.spieler, "o_x")
        XCTAssertEqual(b.entwurf?.punkte.count, 1)
    }

    func test_ein_tipp_auf_den_eigenen_spieler_ist_ein_wegpunkt() {
        // Eine Route, die zum Ausgangspunkt zurückführt, gibt es --
        // deshalb darf der eigene Spieler kein Neuanfang sein.
        var b = block(.linie(.route))
        b.tippen(schirm(35, 12.5), groesse: groesse)
        b.tippen(schirm(45, 12.5), groesse: groesse)
        b.tippen(schirm(35, 12.5), groesse: groesse)

        XCTAssertEqual(b.entwurf?.punkte.count, 3)
        XCTAssertTrue(b.zeichnung.linien.isEmpty)
    }

    func test_abbrechen_wirft_die_angefangene_linie_weg() {
        var b = block(.linie(.route))
        b.tippen(schirm(35, 12.5), groesse: groesse)
        b.tippen(schirm(45, 12.5), groesse: groesse)
        b.abbrechen()

        XCTAssertNil(b.entwurf)
        XCTAssertTrue(b.zeichnung.linien.isEmpty)
        XCTAssertFalse(b.geaendert)
    }

    // MARK: - Die Linienarten und ihre Enden

    func test_das_ende_kommt_von_der_linienart() {
        // Route und Abschirmen sind beide durchgezogen und in Textfarbe;
        // sie unterscheiden sich NUR im Ende.
        let paare: [(Zeichnung.Linie.Art, Zeichnung.Linie.Ende)] = [
            (.route, .arrow), (.block, .tee), (.motion, .arrow),
            (.handoff, .arrow), (.pass, .arrow), (.zone, .none),
        ]
        for (art, ende) in paare {
            var b = block(.linie(art))
            b.tippen(schirm(35, 12.5), groesse: groesse)
            XCTAssertEqual(b.entwurf?.ende, ende, "\(art.rawValue)")
        }
    }

    func test_das_werkzeug_uebernimmt_die_angefangene_linie() {
        var b = block(.linie(.route))
        b.tippen(schirm(35, 12.5), groesse: groesse)
        b.werkzeugSetzen(.linie(.block))

        XCTAssertEqual(b.entwurf?.art, .block)
        XCTAssertEqual(b.entwurf?.ende, .tee, "das Ende geht mit der Art")
        XCTAssertEqual(b.entwurf?.punkte.count, 1, "der Anfang bleibt stehen")
    }

    func test_zurueck_zur_auswahl_beendet_das_zeichnen() {
        var b = block(.linie(.route))
        b.tippen(schirm(35, 12.5), groesse: groesse)
        b.werkzeugSetzen(.auswahl)

        XCTAssertNil(b.entwurf)
        XCTAssertTrue(b.zeichnung.linien.isEmpty)
    }

    func test_das_ende_laesst_sich_nachtraeglich_aendern() {
        var b = block(.linie(.route))
        b.tippen(schirm(35, 12.5), groesse: groesse)
        b.tippen(schirm(45, 12.5), groesse: groesse)
        b.abschliessen()
        b.endeSetzen(.tee)

        XCTAssertEqual(b.zeichnung.linien.first?.ende, .tee)
        XCTAssertTrue(b.geaendert)
    }

    func test_das_ende_trifft_erst_die_angefangene_linie() {
        // Wer zeichnet, meint die Linie unter dem Finger und nicht die,
        // die vorhin ausgewählt war.
        var b = block(.linie(.route))
        b.tippen(schirm(35, 12.5), groesse: groesse)
        b.tippen(schirm(45, 12.5), groesse: groesse)
        b.abschliessen()

        b.werkzeugSetzen(.linie(.route))
        b.tippen(schirm(35, 20), groesse: groesse)
        b.endeSetzen(.none)

        // Ausgeschrieben, weil `.none` an einem Optional die leere Angabe
        // wäre und nicht das offene Linienende.
        XCTAssertEqual(b.entwurf?.ende, Zeichnung.Linie.Ende.none)
        XCTAssertEqual(b.zeichnung.linien.first?.ende, .arrow,
                       "die fertige Linie bleibt, wie sie war")
    }

    // MARK: - Auswählen, löschen

    func test_die_auswahl_findet_eine_linie_zwischen_ihren_punkten() {
        // Eine gerade Route hat zwei Punkte und dazwischen zehn Yards.
        var b = block(.linie(.route))
        b.tippen(schirm(35, 12.5), groesse: groesse)
        b.tippen(schirm(45, 12.5), groesse: groesse)
        b.abschliessen()

        b.werkzeugSetzen(.auswahl)
        b.tippen(schirm(41, 12.5), groesse: groesse)
        XCTAssertEqual(b.auswahl, .linie(0), "mitten auf der Strecke")

        b.tippen(schirm(41, 20), groesse: groesse)
        XCTAssertNil(b.auswahl, "weit daneben ist keine Auswahl")
    }

    func test_der_spieler_gewinnt_gegen_seine_eigene_linie() {
        var b = block(.linie(.route))
        b.tippen(schirm(35, 12.5), groesse: groesse)
        b.tippen(schirm(45, 12.5), groesse: groesse)
        b.abschliessen()

        b.werkzeugSetzen(.auswahl)
        b.tippen(schirm(35, 12.5), groesse: groesse)
        XCTAssertEqual(b.auswahl, .spieler("o_qb"),
                       "sonst käme man an die Figur nicht mehr heran")
    }

    func test_eine_zone_faengt_man_auch_an_der_schlusskante() {
        // Sie wird geschlossen gezeichnet, also gehört die Rückstrecke
        // dazu -- sonst greift man ins Leere, wo eine Linie zu sehen ist.
        var b = block(.linie(.zone))
        b.tippen(schirm(40, 5), groesse: groesse)
        b.tippen(schirm(45, 5), groesse: groesse)
        b.tippen(schirm(45, 10), groesse: groesse)
        b.abschliessen()

        b.werkzeugSetzen(.auswahl)
        b.tippen(schirm(42.5, 7.5), groesse: groesse)   // auf der Schlusskante
        XCTAssertEqual(b.auswahl, .linie(0))
    }

    func test_ein_angefasster_spieler_loest_die_ausgewaehlte_linie_ab() {
        // Sonst zeigt die Fußzeile weiter den Papierkorb einer Linie,
        // während der Finger auf einer Figur liegt.
        var b = block(.linie(.route))
        b.tippen(schirm(35, 12.5), groesse: groesse)
        b.tippen(schirm(45, 12.5), groesse: groesse)
        b.abschliessen()
        XCTAssertEqual(b.auswahl, .linie(0))

        b.werkzeugSetzen(.auswahl)
        b.anfassen("o_x")
        XCTAssertEqual(b.auswahl, .spieler("o_x"))
        XCTAssertNil(b.ausgewaehlteLinie)
        XCTAssertNil(b.ausgewaehlteStelle, "kein Papierkorb ohne Linie")
    }

    func test_loeschen_entfernt_die_ausgewaehlte_linie() {
        var b = block(.linie(.route))
        b.tippen(schirm(35, 12.5), groesse: groesse)
        b.tippen(schirm(45, 12.5), groesse: groesse)
        b.abschliessen()
        b.ausgewaehlteLinieLoeschen()

        XCTAssertTrue(b.zeichnung.linien.isEmpty)
        XCTAssertNil(b.auswahl)
        XCTAssertNil(b.ausgewaehlteLinie)
    }

    // MARK: - Die Kurve (R7 und R12)

    /// Gemeldet von Cyell („Keine abgerundeten Routen") und Niklas
    /// („wie ist das wenn man eine wheel route machen will das geht auch
    /// nicht"). Der Browser hat den Schalter seit jeher; die App konnte
    /// `gebogen` nur anzeigen, nicht anlegen.

    func test_ohne_schalter_bleibt_eine_linie_eckig() {
        var b = block(.linie(.route))
        b.tippen(schirm(35, 20), groesse: groesse)
        b.tippen(schirm(45, 20), groesse: groesse)
        b.abschliessen()

        XCTAssertFalse(b.zeichnung.linien[0].gebogen,
                       "Eckig ist die Voreinstellung, wie im Browser")
    }

    func test_mit_schalter_wird_eine_neue_linie_gebogen() {
        var b = block(.linie(.route))
        b.kurveUmschalten()
        XCTAssertTrue(b.kurveAktiv)

        b.tippen(schirm(35, 20), groesse: groesse)
        b.tippen(schirm(45, 20), groesse: groesse)
        b.abschliessen()

        XCTAssertTrue(b.zeichnung.linien[0].gebogen,
                      "Der Schalter kommt bei der neuen Linie nicht an")
    }

    /// Der Fall aus R12: eine Wheel ist eine Route mit drei Punkten und
    /// einem Bogen. Ohne den Bogen ist sie ein Out mit angesetztem Go.
    func test_eine_wheel_laesst_sich_zeichnen() {
        var b = block(.linie(.route))
        b.kurveUmschalten()
        b.tippen(schirm(35, 20), groesse: groesse)   // flach nach außen
        b.tippen(schirm(35, 24), groesse: groesse)
        b.tippen(schirm(45, 24), groesse: groesse)   // und im Bogen hoch
        b.abschliessen()

        let linie = b.zeichnung.linien[0]
        XCTAssertTrue(linie.gebogen)
        // Der erste Tipp IST der erste Punkt: Er liegt auf der Figur,
        // dort fängt der Weg an.
        XCTAssertEqual(linie.punkte.count, 3)
    }

    /// Eine Zone fängt fast immer auf freier Fläche an, nicht auf einer
    /// Figur -- und lief damit an `beginnen()` vorbei.
    func test_der_schalter_gilt_auch_auf_freier_flaeche() {
        var b = block(.linie(.zone))
        b.kurveUmschalten()
        b.tippen(schirm(20, 5), groesse: groesse)
        b.tippen(schirm(28, 5), groesse: groesse)
        b.tippen(schirm(28, 11), groesse: groesse)
        b.abschliessen()

        XCTAssertEqual(b.zeichnung.linien.count, 1)
        XCTAssertTrue(b.zeichnung.linien[0].gebogen,
                      "Auf freier Fläche begonnene Linien übernehmen den " +
                      "Kurvenschalter nicht")
    }

    func test_der_schalter_gilt_sofort_fuer_den_entwurf() {
        // Sonst zeigt die Vorschau etwas anderes an, als der Knopf sagt
        // -- und man merkt es erst nach „Fertig".
        var b = block(.linie(.route))
        b.tippen(schirm(35, 20), groesse: groesse)
        b.tippen(schirm(45, 20), groesse: groesse)
        XCTAssertNotNil(b.entwurf)

        b.kurveUmschalten()
        XCTAssertEqual(b.entwurf?.gebogen, true)
        b.abschliessen()
        XCTAssertTrue(b.zeichnung.linien[0].gebogen)
    }

    /// R11 im Kleinen: an das herankommen, was gerade gemacht wurde.
    func test_eine_fertige_linie_laesst_sich_nachtraeglich_runden() {
        var b = block(.linie(.route))
        b.tippen(schirm(35, 20), groesse: groesse)
        b.tippen(schirm(45, 20), groesse: groesse)
        b.abschliessen()
        XCTAssertFalse(b.zeichnung.linien[0].gebogen)

        let vorher = b.stand
        b.kurveUmschalten()

        XCTAssertTrue(b.zeichnung.linien[0].gebogen)
        XCTAssertGreaterThan(b.stand, vorher,
                             "Die Änderung zählt nicht als Änderung, also " +
                             "wird sie nie gesichert")
    }

    func test_nachtraegliches_runden_laesst_sich_zuruecknehmen() {
        var b = block(.linie(.route))
        b.tippen(schirm(35, 20), groesse: groesse)
        b.tippen(schirm(45, 20), groesse: groesse)
        b.abschliessen()
        b.kurveUmschalten()
        XCTAssertTrue(b.zeichnung.linien[0].gebogen)

        b.rueckgaengig()
        XCTAssertFalse(b.zeichnung.linien[0].gebogen,
                       "Ohne merken() ist die Rundung nicht im Verlauf")
    }

    /// DER FEHLER, DER BEIM BAUEN AUFFIEL. Wird gegen den VORRAT
    /// umgeschaltet statt gegen das, was der Knopf anzeigt, passiert
    /// beim ersten Druck nichts: Ist eine gerundete Linie ausgewählt,
    /// während der Vorrat auf eckig steht, setzt das Umschalten des
    /// Vorrats sie auf genau den Wert, den sie schon hat.
    func test_der_erste_druck_wirkt_auch_bei_ausgewaehlter_kurve() {
        var b = block(.linie(.route))
        b.kurveUmschalten()                       // Vorrat: gebogen
        b.tippen(schirm(35, 20), groesse: groesse)
        b.tippen(schirm(45, 20), groesse: groesse)
        b.abschliessen()
        b.kurveUmschalten()                       // wieder gerade machen
        XCTAssertFalse(b.zeichnung.linien[0].gebogen)

        b.kurveUmschalten()                       // und wieder runden
        XCTAssertTrue(b.zeichnung.linien[0].gebogen,
                      "Der Knopf reagiert beim zweiten Mal nicht")
    }

    // MARK: - Verschieben

    func test_der_verschobene_spieler_nimmt_seine_linie_mit() {
        var b = block(.linie(.route))
        b.tippen(schirm(35, 12.5), groesse: groesse)
        b.tippen(schirm(45, 12.5), groesse: groesse)
        b.abschliessen()

        b.verschiebe("o_qb", x: 35, y: 10)
        let punkte = b.zeichnung.linien.first?.punkte ?? []
        XCTAssertEqual(punkte.first?.y ?? 0, 10, accuracy: 0.0001)
        XCTAssertEqual(punkte.last?.y ?? 0, 10, accuracy: 0.0001,
                       "sonst begänne der Weg im Nichts")
        XCTAssertEqual(punkte.last?.x ?? 0, 45, accuracy: 0.0001)
    }

    func test_eine_fremde_linie_bleibt_beim_verschieben_stehen() {
        var b = block(.linie(.route))
        b.tippen(schirm(35, 20), groesse: groesse)
        b.tippen(schirm(45, 20), groesse: groesse)
        b.abschliessen()

        b.verschiebe("o_qb", x: 35, y: 10)
        XCTAssertEqual(b.zeichnung.linien.first?.punkte.first?.y ?? 0, 20,
                       accuracy: 0.0001)
    }

    // MARK: - Grenzen

    func test_mehr_als_vierzig_linien_gibt_es_nicht() {
        // Dieselbe Grenze wie in schema.py. Ein Knopf, der beim Sichern
        // eine Fehlermeldung erzeugt, ist ein toter Knopf.
        var b = block()
        b.zeichnung.linien = (0..<Zeichnung.maxLinien).map { i in
            Zeichnung.Linie(spieler: nil, punkte: [
                Zeichnung.Punkt(x: 20 + Double(i) * 0.5, y: 2),
                Zeichnung.Punkt(x: 20 + Double(i) * 0.5, y: 4),
            ])
        }
        b.werkzeugSetzen(.linie(.route))
        // WEIT WEG VON BEIDEN SPIELERN, und das ist keine Zierde: Die
        // Grifffläche reicht 2,6 Yards weit, und ein Punkt darin beginnt
        // eine neue Linie bei DIESEM Spieler. Der erste Entwurf tippte
        // auf (35, 15), zweieinhalb Yards neben dem QB -- gemessen wurde
        // damit nicht die Grenze, sondern der Neuanfang.
        b.tippen(schirm(30, 4), groesse: groesse)
        b.tippen(schirm(35, 4), groesse: groesse)

        XCTAssertFalse(b.abschliessen())
        XCTAssertEqual(b.zeichnung.linien.count, Zeichnung.maxLinien)
        XCTAssertNotNil(b.meldung)
    }

    func test_eine_ersetzende_linie_geht_auch_am_limit_durch() {
        // Sie nimmt keinen Platz weg, also darf die Grenze sie nicht
        // aufhalten -- sonst wäre die alte weg und die neue abgelehnt.
        var b = block()
        b.zeichnung.linien = [Zeichnung.Linie(spieler: "o_qb", punkte: [
            Zeichnung.Punkt(x: 35, y: 12.5), Zeichnung.Punkt(x: 40, y: 12.5),
        ])]
        b.zeichnung.linien += (1..<Zeichnung.maxLinien).map { i in
            Zeichnung.Linie(spieler: nil, punkte: [
                Zeichnung.Punkt(x: 20 + Double(i) * 0.5, y: 2),
                Zeichnung.Punkt(x: 20 + Double(i) * 0.5, y: 4),
            ])
        }
        b.werkzeugSetzen(.linie(.route))
        b.tippen(schirm(35, 12.5), groesse: groesse)
        b.tippen(schirm(45, 12.5), groesse: groesse)

        XCTAssertTrue(b.abschliessen())
        XCTAssertEqual(b.zeichnung.linien.count, Zeichnung.maxLinien)
    }

    func test_eine_linie_bekommt_nicht_beliebig_viele_ecken() {
        var b = block(.linie(.route))
        b.tippen(schirm(35, 12.5), groesse: groesse)
        // Abwechselnd hin und her, damit kein Punkt auf dem vorigen liegt.
        for i in 0..<(Zeichnung.maxPunkteJeLinie + 5) {
            b.tippen(schirm(36 + Double(i % 2) * 2, 12.5), groesse: groesse)
        }
        XCTAssertEqual(b.entwurf?.punkte.count, Zeichnung.maxPunkteJeLinie)
    }

    // MARK: - Gesichert

    func test_nach_dem_sichern_ist_nichts_mehr_offen() {
        var b = block(.linie(.route))
        b.tippen(schirm(35, 12.5), groesse: groesse)
        b.tippen(schirm(45, 12.5), groesse: groesse)
        b.abschliessen()
        XCTAssertTrue(b.geaendert)

        b.gesichert(bis: b.stand)
        XCTAssertFalse(b.geaendert)
        XCTAssertEqual(b.zeichnung.linien.count, 1, "die Zeichnung bleibt")
    }

    /// R4, gemeldet von Cyell am 25.08.2026: „Routen werden manchmal nicht
    /// gespeichert."
    ///
    /// Der Ablauf, der es auslöst: Speichern antippen, und während die
    /// Anfrage unterwegs ist -- im Mobilfunk über eine Sekunde --
    /// weiterzeichnen. Die Antwort gilt dem Stand, der losgeschickt wurde.
    /// Vorher las die Fußzeile danach „Gesichert", und die zweite Linie
    /// war beim Zurückgehen weg.
    func test_wer_waehrend_des_sicherns_weiterzeichnet_bleibt_ungesichert() {
        var b = block(.linie(.route))
        b.tippen(schirm(35, 12.5), groesse: groesse)
        b.tippen(schirm(45, 12.5), groesse: groesse)
        b.abschliessen()

        // Das ist der Stand, der jetzt zum Server ginge.
        let losgeschickt = b.stand

        // Während die Anfrage unterwegs ist: die zweite Linie.
        b.tippen(schirm(35, 20), groesse: groesse)     // auf o_x
        b.tippen(schirm(45, 20), groesse: groesse)
        b.abschliessen()
        XCTAssertEqual(b.zeichnung.linien.count, 2)

        // Jetzt kommt die Antwort auf die ERSTE Anfrage.
        b.gesichert(bis: losgeschickt)
        XCTAssertTrue(b.geaendert,
                      "der Server hat die zweite Linie nie gesehen")

        // Und wenn der zweite Durchgang durch ist, ist Ruhe.
        b.gesichert(bis: b.stand)
        XCTAssertFalse(b.geaendert)
    }

    /// Zweite Hälfte von R4: Eine angefangene Linie, die nicht reicht, darf
    /// nicht kommentarlos verschwinden. „Fertig" ist dann gesperrt, der
    /// Wechsel auf einen anderen Spieler ging aber daran vorbei.
    func test_eine_zu_kurze_linie_verschwindet_nicht_stumm() {
        var b = block(.linie(.route))
        b.tippen(schirm(35, 12.5), groesse: groesse)   // auf o_qb
        XCTAssertEqual(b.entwurf?.punkte.count, 1)

        // Jetzt auf einen anderen Spieler: die angefangene Linie fällt weg.
        b.tippen(schirm(35, 20), groesse: groesse)     // auf o_x
        XCTAssertEqual(b.zeichnung.linien.count, 0)
        XCTAssertNotNil(b.meldung, "und niemand erfährt, warum")
        XCTAssertTrue(b.meldung?.contains("zweiten Punkt") ?? false,
                      "der Satz muss sagen, was gefehlt hat: \(b.meldung ?? "-")")
    }

    // MARK: - Wer da steht (R9)

    /// Gemeldet von Cyell am 25.08.2026: „man kann die Spieler nicht
    /// umbenennen, wenn man doch mal einen anderen Spieler haben möchte".
    /// Der Browser kann es seit dem 25.08.; die App hatte weder ein Feld
    /// noch einen Setzer.
    ///
    /// Angefasst statt getippt: `anfassen` ist der Weg, auf dem ein
    /// Finger eine Figur auswählt. Wer die Auswahl von Hand setzte,
    /// prüfte einen Zustand, den die App so nie erreicht.
    private func blockMitAusgewaehltemSpieler() -> Zeichenblock {
        var b = block()
        b.anfassen("o_x")
        return b
    }

    func test_ohne_auswahl_gibt_es_keinen_spieler() {
        XCTAssertNil(block().ausgewaehlterSpieler)
    }

    func test_der_angefasste_spieler_ist_der_ausgewaehlte() {
        let b = blockMitAusgewaehltemSpieler()
        XCTAssertEqual(b.ausgewaehlterSpieler?.id, "o_x")
        XCTAssertEqual(b.ausgewaehlterSpieler?.rolle, "X")
    }

    /// Eine ausgewählte LINIE ist kein ausgewählter Spieler. Ohne diese
    /// Trennung zeigte die Fußzeile zwei Leisten übereinander -- oder,
    /// schlimmer, die falsche.
    func test_eine_ausgewaehlte_linie_ist_kein_spieler() {
        var b = block(.linie(.route))
        b.tippen(schirm(35, 20), groesse: groesse)
        b.tippen(schirm(45, 20), groesse: groesse)
        XCTAssertTrue(b.abschliessen())
        b.werkzeugSetzen(.auswahl)
        b.tippen(schirm(40, 20), groesse: groesse)
        XCTAssertNotNil(b.ausgewaehlteLinie, "die Linie ist nicht ausgewählt")
        XCTAssertNil(b.ausgewaehlterSpieler)
    }

    func test_die_rolle_laesst_sich_aendern() {
        var b = blockMitAusgewaehltemSpieler()
        let vorher = b.stand
        b.rolleSetzen("Z")

        XCTAssertEqual(b.ausgewaehlterSpieler?.rolle, "Z")
        XCTAssertEqual(b.zeichnung.spieler[1].rolle, "Z",
                       "geändert wurde eine Kopie, nicht die Zeichnung")
        XCTAssertEqual(b.stand, vorher + 1,
                       "ohne höheren Stand sagt die Fußzeile „Gesichert“")
    }

    func test_die_rolle_aendert_nur_den_ausgewaehlten() {
        var b = blockMitAusgewaehltemSpieler()
        b.rolleSetzen("Z")
        XCTAssertEqual(b.zeichnung.spieler[0].rolle, "QB",
                       "der andere Spieler ist mitgewandert")
    }

    func test_das_kuerzel_laesst_sich_aendern() {
        var b = blockMitAusgewaehltemSpieler()
        let vorher = b.stand
        b.kuerzelSetzen("Z")
        XCTAssertEqual(b.ausgewaehlterSpieler?.kuerzel, "Z")
        XCTAssertEqual(b.stand, vorher + 1)
    }

    /// DIE HÄLFTE, NACH DER DIE MELDUNG FRAGT. „Einen anderen Spieler
    /// haben" heißt, aus dem X ein Z zu machen -- und die beiden Felder
    /// sind zwei Dinge. Wer nur das Kürzel setzt, hat einen Spieler, der
    /// „Z" heißt und „X" ist.
    func test_rolle_und_kuerzel_sind_zwei_dinge() {
        var b = blockMitAusgewaehltemSpieler()
        b.kuerzelSetzen("Z")
        XCTAssertEqual(b.ausgewaehlterSpieler?.rolle, "X",
                       "das Kürzel hat die Rolle mitgezogen")
        b.rolleSetzen("Z")
        XCTAssertEqual(b.ausgewaehlterSpieler?.kuerzel, "Z")
        XCTAssertEqual(b.ausgewaehlterSpieler?.rolle, "Z")
    }

    /// Die Grenzen des Servers. `schema.validate_play_data` schneidet
    /// auf sechs und drei Zeichen ab; wer mehr eintippen darf, als
    /// ankommt, bekommt seine Eingabe beim Speichern gekürzt und erfährt
    /// es nicht.
    func test_die_rolle_hoert_bei_sechs_zeichen_auf() {
        var b = blockMitAusgewaehltemSpieler()
        b.rolleSetzen("Cornerback")
        XCTAssertEqual(b.ausgewaehlterSpieler?.rolle, "Corner")
        XCTAssertEqual(b.ausgewaehlterSpieler?.rolle.count,
                       Zeichenblock.maxRolle)
    }

    func test_das_kuerzel_hoert_bei_drei_zeichen_auf() {
        var b = blockMitAusgewaehltemSpieler()
        b.kuerzelSetzen("Cornerback")
        XCTAssertEqual(b.ausgewaehlterSpieler?.kuerzel.count,
                       Zeichenblock.maxKuerzel)
        XCTAssertEqual(b.ausgewaehlterSpieler?.kuerzel, "Cor")
    }

    /// Ein Feld, in dem nichts steht, ist erlaubt: Der Server nimmt eine
    /// leere Rolle an (`decodeIfPresent … ?? ""`). Wer sie verböte,
    /// müsste beim Löschen des letzten Zeichens etwas stehen lassen --
    /// und dann ließe sich „QB" nicht in „X" ändern, ohne zwischendurch
    /// „QBX" zu haben.
    func test_die_rolle_darf_leer_werden() {
        var b = blockMitAusgewaehltemSpieler()
        b.rolleSetzen("")
        XCTAssertEqual(b.ausgewaehlterSpieler?.rolle, "")
    }

    /// Kein Schritt für nichts. SwiftUI ruft den Setzer einer Bindung
    /// auch dann auf, wenn sich der Text nicht geändert hat -- ohne
    /// diese Bremse zählte `stand` beim bloßen Antippen hoch, und die
    /// Fußzeile sagte „Ungesichert", ohne dass jemand etwas geändert
    /// hätte.
    func test_derselbe_wert_ist_keine_aenderung() {
        var b = blockMitAusgewaehltemSpieler()
        let vorher = b.stand
        b.rolleSetzen("X")
        b.kuerzelSetzen("X")
        XCTAssertEqual(b.stand, vorher)
        XCTAssertFalse(b.geaendert)
    }

    /// Ohne Auswahl darf nichts passieren. Sonst schriebe ein Tastendruck
    /// in ein Feld, das gar nicht mehr zu einer Figur gehört, in den
    /// ersten Spieler der Liste -- und das ist irgendeiner.
    func test_ohne_auswahl_aendert_sich_niemand() {
        var b = block()
        b.rolleSetzen("Z")
        b.kuerzelSetzen("Z")
        XCTAssertEqual(b.zeichnung.spieler.map(\.rolle), ["QB", "X"])
        XCTAssertEqual(b.zeichnung.spieler.map(\.kuerzel), ["Q", "X"])
        XCTAssertEqual(b.stand, 0)
    }

    // MARK: - Erst den Spieler wählen, dann das Werkzeug

    /// Niklas am 01.09.2026: „wnen man auf den spieler tippt und denn auf
    /// route das die route dann automatisch bei dem spieler auch beginnt
    /// und man nicht einfach mitten irgendwo im feld anfängt."
    func test_werkzeugwechsel_beginnt_beim_gewaehlten_spieler() {
        var b = block(.auswahl)
        b.tippen(schirm(35, 20), groesse: groesse)
        XCTAssertEqual(b.ausgewaehlterSpieler?.id, "o_x")

        b.werkzeugSetzen(.linie(.route))
        XCTAssertEqual(b.entwurf?.spieler, "o_x")
        XCTAssertEqual(b.entwurf?.punkte.count, 1)
        XCTAssertEqual(b.entwurf?.punkte.first?.x, 35)
        XCTAssertEqual(b.entwurf?.punkte.first?.y, 20)
    }

    func test_ohne_gewaehlten_spieler_beginnt_nichts() {
        var b = block(.auswahl)
        b.werkzeugSetzen(.linie(.route))
        XCTAssertNil(b.entwurf, "Ein Weg aus dem Nichts wäre schlimmer")
    }

    func test_eine_angefangene_linie_wird_nicht_verworfen() {
        // Der alte Zweck des Wechsels: mitten im Zeichnen merken, dass es
        // eine Motion ist. Der bleibt.
        var b = block(.linie(.route))
        b.tippen(schirm(35, 20), groesse: groesse)
        b.tippen(schirm(40, 20), groesse: groesse)
        b.werkzeugSetzen(.linie(.motion))
        XCTAssertEqual(b.entwurf?.art, .motion)
        XCTAssertEqual(b.entwurf?.punkte.count, 2)
    }

    // MARK: - Ein Weg gehört dem, der ihn läuft (R58)

    /// Niklas am 02.09.2026, mit einem Bildschirmfoto, auf dem ein Weg
    /// neben dem Feld schwebte: „Man kann immer noch wild routen
    /// irgendwo machen?"
    func test_eine_route_faengt_nicht_im_leeren_an() {
        var b = block(.linie(.route))
        b.tippen(schirm(20, 6), groesse: groesse)   // weit weg von allen
        XCTAssertNil(b.entwurf,
                     "Eine Route ohne Spieler ist keine Anweisung")
        XCTAssertNotNil(b.meldung, "Ein Tipp, der nichts tut, sieht aus "
                                 + "wie ein Programm, das klemmt")
    }

    func test_das_gilt_fuer_jede_art_ausser_der_zone() {
        for art in Zeichnung.Linie.Art.allCases where art != .zone {
            var b = block(.linie(art))
            b.tippen(schirm(20, 6), groesse: groesse)
            XCTAssertNil(b.entwurf, "\(art) faengt frei an")
        }
    }

    func test_eine_zone_darf_es_weiterhin() {
        // Sie beschreibt einen RAUM, den jemand deckt, und den zeichnet
        // man um eine Stelle des Feldes, nicht um eine Figur.
        var b = block(.linie(.zone))
        b.tippen(schirm(20, 6), groesse: groesse)
        XCTAssertNotNil(b.entwurf, "Eine Zone braucht keinen Spieler")
        XCTAssertNil(b.entwurf?.spieler)
    }

    func test_bei_einem_spieler_geht_es_weiterhin() {
        // Gegenprobe. Ohne sie waere die Pruefung auch dann gruen, wenn
        // gar keine Linie mehr entstuende.
        var b = block(.linie(.route))
        b.tippen(schirm(35, 20), groesse: groesse)
        XCTAssertEqual(b.entwurf?.spieler, "o_x")
    }

    func test_eine_angefangene_route_laesst_sich_frei_weiterziehen() {
        // Der ANFANG gehört einem Spieler, die Wegpunkte nicht: Eine
        // Route läuft ins Feld hinaus, das ist ihr Sinn.
        var b = block(.linie(.route))
        b.tippen(schirm(35, 20), groesse: groesse)
        b.tippen(schirm(42, 20), groesse: groesse)
        XCTAssertEqual(b.entwurf?.punkte.count, 2)
    }

    // MARK: - Die Meldung geht von selbst weg (R75)

    func test_jede_meldung_zaehlt_den_stand_hoch() {
        // Auch die, die der Block selbst setzt -- und das sind fünfzehn
        // Stellen, die `melden` gar nicht anfassen. Ohne sie bliebe
        // genau dort der Satz stehen.
        var b = block(.auswahl)
        let vorher = b.meldungsstand
        b.fangUmschalten()
        XCTAssertGreaterThan(b.meldungsstand, vorher,
                             "Eine direkte Zuweisung zählt nicht mit")
        XCTAssertNotNil(b.meldung)
    }

    func test_zwei_gleiche_meldungen_zaehlen_zweimal() {
        // Der Grund, warum die Ansicht am STAND hängt und nicht am
        // Text: Zweimal derselbe Satz ist für SwiftUI derselbe Wert.
        var b = block(.auswahl)
        b.melden("Zweimal derselbe Satz.")
        let eins = b.meldungsstand
        b.melden("Zweimal derselbe Satz.")
        XCTAssertEqual(b.meldungsstand, eins + 1)
    }

    func test_das_loeschen_zaehlt_nicht_mit() {
        // Sonst liefe die Aufgabe der Ansicht sofort wieder an, fände
        // keinen Text und tut nichts -- eine Aufgabe je Meldung zu viel.
        var b = block(.auswahl)
        b.melden("Ein Satz.")
        let stand = b.meldungsstand
        b.melden(nil)
        XCTAssertEqual(b.meldungsstand, stand)
    }

    func test_die_lesedauer_waechst_mit_der_laenge() {
        let kurz = Zeichenblock.lesedauer("Kurz.")
        let lang = Zeichenblock.lesedauer(String(repeating: "a", count: 90))
        XCTAssertLessThan(kurz, lang)
    }

    func test_die_lesedauer_bleibt_zwischen_vier_und_zehn_sekunden() {
        // Darunter liest niemand mit, darüber steht es im Weg.
        XCTAssertEqual(Zeichenblock.lesedauer(""), 4.0)
        XCTAssertEqual(
            Zeichenblock.lesedauer(String(repeating: "a", count: 5000)), 10.0)
    }
}
