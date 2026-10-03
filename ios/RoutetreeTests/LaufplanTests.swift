import XCTest
@testable import Routetree

/// Spielt die App denselben Ablauf ab wie der Browser?
///
/// Die Zeitachse kommt aus `static/designer/laufplan.js`. Die erwarteten
/// Zahlen hier hat dieses JavaScript selbst gerechnet, unter Node, in
/// `scripts/laufplan_swift.py` -- abgeschrieben ist nichts.
///
/// **Der Fehler, für den das gebaut ist.** Ein Ablauf, der um
/// zweihundert Millisekunden anders läuft, sieht nicht falsch aus, er
/// sieht nur anders aus. Ein Trainer, der ein Mesh im Browser einstellt
/// und es der Mannschaft auf dem Handy zeigt, merkt nicht, dass die
/// beiden Receiver dort gleichzeitig kreuzen statt nacheinander. Er
/// merkt nur, dass die Spieler es nicht verstehen.
final class LaufplanTests: XCTestCase {

    /// Die Zeitachse, wie `laufplan.js` sie ausgibt.
    private struct ErwarteteAchse: Decodable {
        struct Eintrag: Decodable {
            let start: Double
            let ende: Double
            let vorSnap: Bool
            let kind: String
        }
        let eintraege: [Eintrag]
        let hatMotion: Bool
        let snapZeit: Double
        let routenStart: Double
        let gesamt: Double
        let nachlauf: Double
    }

    private func linien(_ fall: LaufplanProben.Fall) throws
        -> [Zeichnung.Linie] {
        try JSONDecoder().decode([Zeichnung.Linie].self,
                                 from: Data(fall.linien.utf8))
    }

    private func erwartet(_ fall: LaufplanProben.Fall) throws
        -> ErwarteteAchse {
        try JSONDecoder().decode(ErwarteteAchse.self,
                                 from: Data(fall.erwartet.utf8))
    }

    // MARK: - Gegen den Browser

    func test_jede_zeitachse_stimmt_mit_dem_browser_ueberein() throws {
        for fall in LaufplanProben.alle {
            let soll = try erwartet(fall)
            let ist = Laufplan.zeitachse(try linien(fall))

            XCTAssertEqual(ist.eintraege.count, soll.eintraege.count,
                           "„\(fall.schluessel)“: andere Zahl von Läufern")
            for (i, eintrag) in soll.eintraege.enumerated()
            where i < ist.eintraege.count {
                let hier = ist.eintraege[i]
                XCTAssertEqual(hier.start, eintrag.start, accuracy: 0.000_1,
                               "„\(fall.schluessel)“, Linie \(i): Start")
                XCTAssertEqual(hier.ende, eintrag.ende, accuracy: 0.000_1,
                               "„\(fall.schluessel)“, Linie \(i): Ende")
                XCTAssertEqual(hier.vorSnap, eintrag.vorSnap,
                               "„\(fall.schluessel)“, Linie \(i): vor dem Snap")
                XCTAssertEqual(hier.linie.art.rawValue, eintrag.kind,
                               "„\(fall.schluessel)“, Linie \(i): Art")
            }

            XCTAssertEqual(ist.hatMotion, soll.hatMotion, fall.schluessel)
            XCTAssertEqual(ist.snapZeit, soll.snapZeit, accuracy: 0.000_1,
                           "„\(fall.schluessel)“: Snap")
            XCTAssertEqual(ist.routenStart, soll.routenStart, accuracy: 0.000_1,
                           "„\(fall.schluessel)“: Start der Routen")
            XCTAssertEqual(ist.gesamt, soll.gesamt, accuracy: 0.000_1,
                           "„\(fall.schluessel)“: Gesamtdauer")
            XCTAssertEqual(ist.nachlauf, soll.nachlauf, accuracy: 0.000_1,
                           "„\(fall.schluessel)“: Nachlauf")
        }
    }

    func test_alle_faelle_sind_dabei() {
        // Sonst prüfte der Vergleich irgendwann eine Auswahl, und
        // niemand merkte, dass die Hälfte fehlt.
        XCTAssertEqual(LaufplanProben.alle.count, 12)
    }

    // MARK: - Die Reihenfolge auf dem Feld

    func test_die_motion_ist_vor_dem_snap_fertig() throws {
        let achse = Laufplan.zeitachse(try linien(LaufplanProben.mitMotion))
        let motion = try XCTUnwrap(achse.eintraege.first { $0.vorSnap })
        let route = try XCTUnwrap(achse.eintraege.first { !$0.vorSnap })
        XCTAssertLessThanOrEqual(motion.ende, route.start,
                                 "der Snap darf die Motion nicht abschneiden")
        XCTAssertEqual(achse.routenStart, achse.snapZeit + 260,
                       accuracy: 0.000_1, "260 ms Innehalten beim Snap")
    }

    func test_eine_zone_laeuft_nicht_mit() throws {
        let achse = Laufplan.zeitachse(try linien(LaufplanProben.zoneLaeuftNicht))
        XCTAssertEqual(achse.eintraege.count, 1)
        XCTAssertFalse(achse.eintraege.contains { $0.linie.art == .zone })
    }

    func test_ein_play_ohne_laufende_linien_hat_keine_dauer() throws {
        for fall in [LaufplanProben.leer, LaufplanProben.nurEineZone] {
            let plan = Laufplan(linien: try linien(fall))
            XCTAssertTrue(plan.istLeer, fall.schluessel)
            XCTAssertEqual(plan.gesamt, 0, fall.schluessel)
            XCTAssertTrue(plan.marken(bei: 1000).isEmpty, fall.schluessel)
        }
    }

    // MARK: - Der Weg

    /// Eine Route über zwei Strecken: drei Yards, dann neun.
    private var geknickt: Zeichnung.Linie {
        Zeichnung.Linie(spieler: "o_x", art: .route,
                        punkte: [.init(x: 35, y: 5), .init(x: 38, y: 5),
                                 .init(x: 38, y: 14)])
    }

    func test_der_laeufer_folgt_der_strecke_und_nicht_den_punkten() {
        // Der Fehler, den das ausschließt: Wer je Stützpunkt gleich viel
        // Zeit gibt, lässt den Spieler über den kurzen Haken schleichen
        // und die lange Gerade hinunterschießen.
        let plan = Laufplan(linien: [geknickt])
        let laeufer = plan.laeufer[0]
        XCTAssertEqual(laeufer.laenge, 12, accuracy: 0.000_1)

        let viertel = laeufer.punkt(bei: 0.25)
        XCTAssertEqual(viertel.x, 38, accuracy: 0.000_1,
                       "drei von zwölf Yards: genau am Knick")
        XCTAssertEqual(viertel.y, 5, accuracy: 0.000_1)

        let halb = laeufer.punkt(bei: 0.5)
        XCTAssertEqual(halb.x, 38, accuracy: 0.000_1)
        XCTAssertEqual(halb.y, 8, accuracy: 0.000_1)
    }

    func test_anfang_und_ende_liegen_genau_auf_den_punkten() {
        let laeufer = Laufplan(linien: [geknickt]).laeufer[0]
        XCTAssertEqual(laeufer.punkt(bei: 0).x, 35, accuracy: 0.000_1)
        XCTAssertEqual(laeufer.punkt(bei: 1).x, 38, accuracy: 0.000_1)
        XCTAssertEqual(laeufer.punkt(bei: 1).y, 14, accuracy: 0.000_1)
        // Über die Ränder hinaus wird geklemmt und nicht extrapoliert.
        XCTAssertEqual(laeufer.punkt(bei: 2).y, 14, accuracy: 0.000_1)
        XCTAssertEqual(laeufer.punkt(bei: -1).x, 35, accuracy: 0.000_1)
    }

    func test_eine_linie_ohne_laenge_faellt_heraus() {
        // Der Browser lässt sie aus demselben Grund weg: Dort ist
        // `getTotalLength()` null. Bliebe sie hier drin, verlängerte ein
        // Doppelklick auf denselben Punkt den ganzen Ablauf.
        let stehend = Zeichnung.Linie(
            spieler: "o_y", art: .route, verzoegerung: 5,
            punkte: [.init(x: 35, y: 5), .init(x: 35, y: 5)])
        let plan = Laufplan(linien: [geknickt, stehend])
        XCTAssertEqual(plan.laeufer.count, 1)
        XCTAssertEqual(plan.gesamt, 2160, accuracy: 0.000_1,
                       "die stehende Linie darf den Ablauf nicht verlängern")
    }

    func test_eine_linie_mit_einem_punkt_faellt_heraus() {
        let plan = Laufplan(linien: [
            Zeichnung.Linie(spieler: "o_x", art: .route,
                            punkte: [.init(x: 35, y: 5)]),
        ])
        XCTAssertTrue(plan.istLeer)
    }

    // MARK: - Wer läuft

    func test_der_ball_traegt_abgabe_und_pass() {
        // Die Linie hängt am Quarterback, dort fängt sie an. Unterwegs
        // ist aber der Ball, nicht er -- sein Symbol bliebe sonst am
        // Startpunkt gar nicht stehen.
        let plan = Laufplan(linien: [
            Zeichnung.Linie(spieler: "o_qb", art: .pass,
                            punkte: [.init(x: 30, y: 12), .init(x: 40, y: 5)]),
            Zeichnung.Linie(spieler: "o_x", art: .route,
                            punkte: [.init(x: 35, y: 5), .init(x: 45, y: 5)]),
        ])
        let marken = plan.marken(bei: 0)
        XCTAssertEqual(marken.count, 2)
        XCTAssertEqual(marken[0].traeger, .ball)
        XCTAssertEqual(marken[1].traeger, .spieler("o_x"))
        XCTAssertEqual(plan.laufendeSpieler, ["o_x"],
                       "der Quarterback läuft beim Pass nicht mit")
    }

    func test_eine_freie_linie_bekommt_einen_punkt() {
        let plan = Laufplan(linien: [
            Zeichnung.Linie(spieler: nil, art: .route,
                            punkte: [.init(x: 35, y: 5), .init(x: 45, y: 5)]),
        ])
        XCTAssertEqual(plan.marken(bei: 0).first?.traeger, .punkt)
        XCTAssertTrue(plan.laufendeSpieler.isEmpty)
    }

    // MARK: - Die Bewegung

    func test_vor_dem_start_steht_die_figur_am_anfang() {
        let plan = Laufplan(linien: [geknickt])
        let marke = plan.marken(bei: 0)[0]
        XCTAssertEqual(marke.x, 35, accuracy: 0.000_1)
        XCTAssertEqual(marke.y, 5, accuracy: 0.000_1)
    }

    func test_nach_dem_ende_bleibt_sie_stehen() {
        let plan = Laufplan(linien: [geknickt])
        let marke = plan.marken(bei: 99_000)[0]
        XCTAssertEqual(marke.x, 38, accuracy: 0.000_1)
        XCTAssertEqual(marke.y, 14, accuracy: 0.000_1)
    }

    func test_die_bewegung_laeuft_aus_statt_gleichmaessig() {
        // `ease-out-cubic`, dieselbe Kurve wie im Browser: Nach der
        // halben Zeit ist mehr als die halbe Strecke zurückgelegt.
        XCTAssertEqual(Laufplan.weich(0), 0, accuracy: 0.000_1)
        XCTAssertEqual(Laufplan.weich(1), 1, accuracy: 0.000_1)
        XCTAssertEqual(Laufplan.weich(0.5), 0.875, accuracy: 0.000_1)
        XCTAssertGreaterThan(Laufplan.weich(0.25), 0.25)
    }

    // MARK: - Der Ablauf als Zustand

    private var ablauf: Ablauf {
        Ablauf(plan: Laufplan(linien: [geknickt]))
    }

    func test_ein_neuer_ablauf_steht_am_anfang_und_still() {
        let lauf = ablauf
        XCTAssertEqual(lauf.zeit, 0)
        XCTAssertFalse(lauf.laeuft)
        XCTAssertEqual(lauf.knopf, "Weiter")
        XCTAssertEqual(lauf.zeittext, "0,0 s")
    }

    func test_er_haelt_am_ende_an_und_bleibt_stehen() {
        var lauf = ablauf
        lauf.weiter()
        lauf.schritt(99_000)
        XCTAssertFalse(lauf.laeuft, "am Ende hält er sich selbst an")
        XCTAssertEqual(lauf.zeit, lauf.plan.gesamt, accuracy: 0.000_1,
                       "und läuft nicht darüber hinaus")
        XCTAssertTrue(lauf.amEnde)
        XCTAssertEqual(lauf.knopf, "Nochmal")
    }

    func test_nochmal_faengt_wieder_von_vorn_an() {
        var lauf = ablauf
        lauf.weiter()
        lauf.schritt(99_000)
        lauf.weiter()
        XCTAssertEqual(lauf.zeit, 0, "sonst wäre „Nochmal“ ein toter Knopf")
        XCTAssertTrue(lauf.laeuft)
    }

    func test_ein_angehaltener_ablauf_bewegt_sich_nicht() {
        var lauf = ablauf
        lauf.schritt(500)
        XCTAssertEqual(lauf.zeit, 0, "ohne „Weiter“ passiert nichts")

        lauf.weiter()
        lauf.schritt(500)
        lauf.anhalten()
        lauf.schritt(500)
        XCTAssertEqual(lauf.zeit, 500, accuracy: 0.000_1)
    }

    func test_das_tempo_streckt_die_wanduhr() {
        var lauf = ablauf
        lauf.tempoSetzen(2)
        lauf.weiter()
        lauf.schritt(500)
        XCTAssertEqual(lauf.zeit, 1000, accuracy: 0.000_1)
    }

    func test_das_tempo_bleibt_in_den_grenzen() {
        var lauf = ablauf
        lauf.tempoSetzen(9)
        XCTAssertEqual(lauf.tempo, Ablauf.tempoMax)
        lauf.tempoSetzen(0)
        XCTAssertEqual(lauf.tempo, Ablauf.tempoMin)
        lauf.tempoSetzen(.nan)
        XCTAssertEqual(lauf.tempo, Ablauf.tempoMin, "Unsinn ändert nichts")
    }

    func test_spulen_haelt_an_und_bleibt_im_ablauf() {
        var lauf = ablauf
        lauf.weiter()
        lauf.spulen(zu: 1000)
        XCTAssertFalse(lauf.laeuft,
                       "wer eine Stelle sucht, will sie nicht davonlaufen sehen")
        XCTAssertEqual(lauf.zeit, 1000, accuracy: 0.000_1)

        lauf.spulen(zu: 99_000)
        XCTAssertEqual(lauf.zeit, lauf.plan.gesamt, accuracy: 0.000_1)
        lauf.spulen(zu: -5)
        XCTAssertEqual(lauf.zeit, 0, accuracy: 0.000_1)
    }

    func test_anfang_haelt_einen_laufenden_ablauf_nicht_an() {
        // Wer auf „Anfang" drückt, will es noch einmal sehen.
        var lauf = ablauf
        lauf.weiter()
        lauf.schritt(800)
        lauf.anfang()
        XCTAssertEqual(lauf.zeit, 0)
        XCTAssertTrue(lauf.laeuft)
    }

    func test_ein_leerer_play_laeuft_nicht_los() {
        var lauf = Ablauf(plan: Laufplan(linien: []))
        lauf.weiter()
        XCTAssertFalse(lauf.laeuft,
                       "sonst stünde „Pause“ über einem Feld, auf dem nichts "
                       + "passiert")
    }

    func test_die_zeit_steht_mit_deutschem_komma_da() {
        var lauf = ablauf
        lauf.weiter()
        lauf.schritt(1440)
        XCTAssertEqual(lauf.zeittext, "1,4 s")
    }
}
