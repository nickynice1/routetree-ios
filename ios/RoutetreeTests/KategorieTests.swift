import XCTest
@testable import Routetree

/// Was hier gemessen wird, ist die GRENZE zum Server -- und der eine
/// Handgriff, der die Zeichnung anfasst (B7).
///
/// Auf diesem Projekt gibt es keinen Mac. Ein Tippfehler in einem
/// Feldnamen fällt deshalb nicht beim Schreiben auf, sondern erst, wenn
/// die App auf dem Gerät eine leere Liste zeigt. Die JSON-Schnipsel
/// unten sind aus `api_v1_kategorien`, `api_v1_kategorie` und
/// `api_v1_formationen` abgeschrieben, nicht erfunden.
final class KategorieTests: XCTestCase {

    private func entschluesseln<T: Decodable>(_ json: String,
                                              als: T.Type) throws -> T {
        try Server.entschluessler.decode(T.self, from: Data(json.utf8))
    }

    // MARK: - Kategorien lesen

    func test_die_kategorienliste_wird_gelesen() throws {
        let json = """
        {"kategorien":[
          {"id":4,"name":"Pass kurz","farbe":"#1a5364","position":1,
           "plays":6},
          {"id":5,"name":"Red Zone","farbe":"#8e3320","position":2,
           "plays":0}]}
        """
        let liste = try entschluesseln(json, als: Modell.KategorienListe.self)
        XCTAssertEqual(liste.kategorien.count, 2)
        XCTAssertEqual(liste.kategorien[0].name, "Pass kurz")
        XCTAssertEqual(liste.kategorien[0].farbe, "#1a5364")
        XCTAssertEqual(liste.kategorien[0].position, 1)
        XCTAssertEqual(liste.kategorien[1].plays, 0)
    }

    func test_eine_nicht_gezaehlte_kategorie_hat_nil_und_nicht_null() throws {
        // Nach dem Umsortieren schickt der Server die Zahl nicht mit.
        // „0 Plays" wäre dann schlicht falsch, und in der Liste stünde
        // eine Auskunft, die niemand erhoben hat.
        let json = """
        {"kategorien":[{"id":4,"name":"Trick","farbe":"#7d5ba6",
        "position":3}]}
        """
        let liste = try entschluesseln(json, als: Modell.KategorienListe.self)
        XCTAssertNil(liste.kategorien[0].plays)
    }

    // MARK: - Ein Play und seine Kategorie

    func test_der_play_bringt_kennung_und_farbe_mit() throws {
        // Der Grund, warum B7 die beiden Felder ergänzt hat: Gesetzt
        // wird die Kategorie mit der KENNUNG, gelesen wurde bis dahin
        // nur der Name.
        let json = """
        {"plays":[{"id":7,"name":"Slant","nummer":3,"seite":"off",
        "kategorie":"Pass kurz","kategorie_id":4,
        "kategorie_farbe":"#1a5364","situationen":[],
        "geaendert":"2026-08-25T10:00:00+00:00","position":1,"version":2}]}
        """
        let liste = try entschluesseln(json, als: Modell.PlayListe.self)
        XCTAssertEqual(liste.plays[0].kategorieId, 4)
        XCTAssertEqual(liste.plays[0].kategorieFarbe, "#1a5364")
    }

    func test_ein_play_ohne_kategorie_hat_beide_auf_nil() throws {
        let json = """
        {"plays":[{"id":7,"name":"Slant","nummer":null,"seite":"off",
        "kategorie":null,"kategorie_id":null,"kategorie_farbe":null,
        "situationen":[],"geaendert":"2026-08-25T10:00:00+00:00",
        "position":1,"version":1}]}
        """
        let liste = try entschluesseln(json, als: Modell.PlayListe.self)
        XCTAssertNil(liste.plays[0].kategorieId)
        XCTAssertNil(liste.plays[0].kategorieFarbe)
    }

    func test_eine_aeltere_serverfassung_laesst_die_felder_weg() throws {
        // Fehlende Schlüssel dürfen die App nicht abstürzen lassen: Sie
        // heißen „nicht gefragt", und dann fehlt eben der Punkt.
        let json = """
        {"plays":[{"id":7,"name":"Slant","nummer":null,"seite":"off",
        "kategorie":"Pass kurz","situationen":[],
        "geaendert":"2026-08-25T10:00:00+00:00","position":1,"version":1}]}
        """
        let liste = try entschluesseln(json, als: Modell.PlayListe.self)
        XCTAssertEqual(liste.plays[0].kategorie, "Pass kurz")
        XCTAssertNil(liste.plays[0].kategorieId)
    }

    func test_der_play_nennt_sein_playbook() throws {
        // Der Editor braucht die Zahl für die gespeicherten
        // Aufstellungen. Fehlt sie, gibt es dort keinen Knopf -- und
        // keinen Absturz.
        let json = """
        {"id":7,"name":"Slant","nummer":3,"playbook":12,"hinweise":"",
        "los":25.0,"richtung":1,"version":2,"zeichnung":{},
        "darf_aendern":true}
        """
        let voll = try entschluesseln(json, als: Modell.PlayVoll.self)
        XCTAssertEqual(voll.playbook, 12)

        let ohne = """
        {"id":7,"name":"Slant","nummer":3,"hinweise":"","los":25.0,
        "richtung":1,"version":2,"zeichnung":{}}
        """
        XCTAssertNil(try entschluesseln(ohne, als: Modell.PlayVoll.self)
                        .playbook)
    }

    // MARK: - Formationen

    func test_die_formationsliste_wird_gelesen() throws {
        let json = """
        {"formationen":[{"id":2,"name":"Trips rechts","anzahl":2,
        "data":{"players":[
          {"id":"o_c","side":"off","role":"C","label":"C","x":25.0,"y":12.5},
          {"id":"o_qb","side":"off","role":"QB","label":"QB","x":20.0,
           "y":12.5}]}}]}
        """
        let liste = try entschluesseln(json, als: Modell.FormationsListe.self)
        XCTAssertEqual(liste.formationen.count, 1)
        XCTAssertEqual(liste.formationen[0].name, "Trips rechts")
        XCTAssertEqual(liste.formationen[0].anzahl, 2)
        XCTAssertEqual(liste.formationen[0].data.spieler.count, 2)
        XCTAssertEqual(liste.formationen[0].data.spieler[1].rolle, "QB")
    }

    func test_die_antwort_aufs_umbenennen_hat_keine_aufstellung() throws {
        // `PATCH` gibt nur id, name und anzahl zurück. Ein `data`, das
        // die App als Pflicht läse, machte aus einem gelungenen
        // Umbenennen einen Entschlüsselungsfehler.
        let json = """
        {"id":2,"name":"Trips links","anzahl":2}
        """
        let formation = try entschluesseln(json, als: Modell.Formation.self)
        XCTAssertEqual(formation.name, "Trips links")
        XCTAssertEqual(formation.anzahl, 2)
        XCTAssertTrue(formation.data.spieler.isEmpty)
    }

    // MARK: - Eine Formation anwenden

    private var projektion: Projektion {
        Projektion(feld: Feld.afvd, los: Feld.afvd.mitte, richtung: 1)
    }

    private func spieler(_ id: String, x: Double,
                         y: Double) -> Zeichnung.Spieler {
        Zeichnung.Spieler(id: id, seite: .offense, rolle: "X", kuerzel: "X",
                          x: x, y: y)
    }

    /// Ein Block mit zwei Spielern und einer Linie am ersten.
    private func block() -> Zeichenblock {
        let zeichnung = Zeichnung(
            spieler: [spieler("o_qb", x: 35, y: 12.5),
                      spieler("o_x", x: 35, y: 20)],
            linien: [Zeichnung.Linie(
                spieler: "o_x", art: .route, ende: .arrow,
                punkte: [Zeichnung.Punkt(x: 35, y: 20),
                         Zeichnung.Punkt(x: 45, y: 20)])])
        return Zeichenblock(zeichnung: zeichnung, projektion: projektion)
    }

    func test_anwenden_ersetzt_die_spieler() {
        // Hier stand „…und laesst die Linien", mit der Begruendung
        // „Genau so macht es der Browser". Beides stimmte, und beides
        // war falsch (R26): Der Browser liess sie ebenfalls liegen, und
        // Niklas hat genau das am 27.08.2026 als Fehler gemeldet.
        var b = block()
        XCTAssertTrue(b.formationAnwenden(
            [spieler("o_c", x: 25, y: 12.5)], name: "Trips rechts"))

        XCTAssertEqual(b.zeichnung.spieler.count, 1)
        XCTAssertEqual(b.zeichnung.spieler[0].id, "o_c")
        XCTAssertEqual(b.zeichnung.linien.count, 1)
        XCTAssertTrue(b.geaendert)
        // SEIT R47 SAGT DIE MELDUNG, WER DABEI VERLORENGEHT.
        //
        // Die neue Aufstellung hat kein „o_x", und „o_x" hatte eine
        // Linie -- die gehört jetzt niemandem. Bis zum 02.09.2026 stand
        // hier nur „Aufstellung übernommen", und der Trainer verlor
        // eine Route, ohne es zu erfahren.
        XCTAssertEqual(
            b.meldung,
            "Aufstellung „Trips rechts“ übernommen. X gibt es dort nicht "
            + "mehr, sein Weg hängt jetzt frei.")
    }

    func test_anwenden_schweigt_wenn_nichts_verlorengeht() {
        // DIE ANDERE HÄLFTE VON R47, und sie ist die wichtigere: Eine
        // Meldung, die IMMER etwas beklagt, liest nach dem dritten Mal
        // niemand mehr. Hier bleibt „o_x" mit seiner Linie erhalten;
        // nur „o_qb" fällt weg, und der hatte keinen Weg.
        var b = block()
        XCTAssertTrue(b.formationAnwenden(
            [spieler("o_x", x: 30, y: 8)], name: "Trips rechts"))
        XCTAssertEqual(b.meldung, "Aufstellung „Trips rechts“ übernommen.")
    }

    func test_anwenden_nimmt_die_linie_des_spielers_mit() {
        // DER GEMELDETE FALL (R26). „o_x" steht bei (35, 20) und hat
        // eine Linie, die dort beginnt. Die neue Aufstellung setzt ihn
        // auf (30, 8) -- die Linie muss um dieselbe Strecke mitkommen,
        // sonst beginnt sie bei niemandem.
        var b = block()
        b.formationAnwenden([spieler("o_x", x: 30, y: 8)],
                            name: "Trips rechts")

        XCTAssertEqual(b.zeichnung.linien.count, 1)
        let punkte = b.zeichnung.linien[0].punkte
        XCTAssertEqual(punkte[0].x, 30, accuracy: 0.001,
                       "Die Linie muss beim Spieler beginnen.")
        XCTAssertEqual(punkte[0].y, 8, accuracy: 0.001)
        // Und die FORM bleibt: Der zweite Punkt lag zehn Yards weiter
        // vorne, das muss er danach auch.
        XCTAssertEqual(punkte[1].x - punkte[0].x, 10, accuracy: 0.001,
                       "Nur den Anfang nachzuziehen wuerde die Route "
                       + "verzerren -- aus einem Slant wuerde ein Post.")
        XCTAssertEqual(punkte[1].y - punkte[0].y, 0, accuracy: 0.001)
    }

    func test_anwenden_laesst_fremde_linien_liegen() {
        // Nur die Linien der Spieler, die WIRKLICH wandern. „o_x" ist in
        // dieser Aufstellung gar nicht enthalten -- seine Linie gehoert
        // danach niemandem mehr und bleibt, wo sie war.
        var b = block()
        b.formationAnwenden([spieler("o_c", x: 25, y: 12.5)],
                            name: "Nur Center")
        XCTAssertEqual(b.zeichnung.linien[0].punkte[0].x, 35, accuracy: 0.001)
        XCTAssertEqual(b.zeichnung.linien[0].punkte[0].y, 20, accuracy: 0.001)
    }

    func test_anwenden_ist_EIN_schritt_im_verlauf() {
        // Eine Formation setzt zehn Figuren auf einmal. Wer sich vertut,
        // drückt einmal Rückgängig und hat seine alte Aufstellung
        // zurück -- nicht zehnmal.
        var b = block()
        b.formationAnwenden([spieler("o_c", x: 25, y: 12.5)],
                            name: "Trips rechts")
        XCTAssertTrue(b.kannRueckgaengig)

        b.rueckgaengig()
        XCTAssertEqual(b.zeichnung.spieler.map(\.id), ["o_qb", "o_x"])
        XCTAssertFalse(b.kannRueckgaengig)
    }

    func test_eine_leere_aufstellung_kostet_keinen_schritt() {
        // Sonst täte Rückgängig beim ersten Drücken nichts. Dieselbe
        // Regel wie überall im Verlauf: Ein Schritt für eine Änderung,
        // die nicht stattgefunden hat, ist ein toter Knopf.
        var b = block()
        XCTAssertFalse(b.formationAnwenden([], name: "Leer"))
        XCTAssertFalse(b.kannRueckgaengig)
        XCTAssertEqual(b.zeichnung.spieler.count, 2)
        XCTAssertNotNil(b.meldung)
    }

    // MARK: - Die Abschnitte der Playliste

    private func play(_ id: Int, _ name: String,
                      kategorie: String?) -> Modell.PlayKurz {
        Modell.PlayKurz(id: id, name: name, nummer: nil,
                        kategorie: kategorie, position: id)
    }

    /// Drei Kategorien, absichtlich NICHT alphabetisch aufgestellt:
    /// „Red Zone" steht oben, obwohl es hinten im Alphabet steht. Genau
    /// daran fällt eine alphabetische Sortierung auf.
    private var dreiKategorien: [Modell.Kategorie] {
        [Modell.Kategorie(id: 1, name: "Red Zone", farbe: "#8e3320",
                          position: 1),
         Modell.Kategorie(id: 2, name: "Pass", farbe: "#1a5364", position: 2),
         Modell.Kategorie(id: 3, name: "Lauf", farbe: "#3f8f5c", position: 3)]
    }

    func test_die_abschnitte_stehen_in_der_reihenfolge_der_kategorien() {
        // Es ist dieselbe Reihenfolge, in der die Wristcoach-Einlage
        // druckt. Alphabetisch stünde hier Lauf, Pass, Red Zone -- und
        // die Liste in der Hand sähe anders aus als die am Bildschirm.
        let abschnitte = Abschnitte.gruppieren(
            [play(1, "Slant", kategorie: "Pass"),
             play(2, "Dive", kategorie: "Lauf"),
             play(3, "Fade", kategorie: "Red Zone")],
            kategorien: dreiKategorien)

        XCTAssertEqual(abschnitte.map(\.name), ["Red Zone", "Pass", "Lauf"])
        XCTAssertEqual(abschnitte[0].plays.map(\.name), ["Fade"])
    }

    func test_ohne_kategorie_steht_am_ende() {
        let abschnitte = Abschnitte.gruppieren(
            [play(1, "Trick", kategorie: nil),
             play(2, "Slant", kategorie: "Pass")],
            kategorien: dreiKategorien)

        XCTAssertEqual(abschnitte.map(\.name),
                       ["Pass", Abschnitte.ohneKategorie])
    }

    func test_ohne_kategorienliste_steht_die_restgruppe_trotzdem_unten() {
        // Die Kategorien werden getrennt geladen und getrennt gefangen:
        // Kommt die zweite Anfrage in der Umkleide nicht durch, zeigt
        // die Liste trotzdem die Plays. Dann bleibt nur der Name als
        // Ordnung -- aber „Ohne Kategorie" gehört weiter nach unten und
        // nicht zwischen „Lauf" und „Pass".
        let abschnitte = Abschnitte.gruppieren(
            [play(1, "Trick", kategorie: nil),
             play(2, "Slant", kategorie: "Pass"),
             play(3, "Dive", kategorie: "Lauf")],
            kategorien: [])

        XCTAssertEqual(abschnitte.map(\.name),
                       ["Lauf", "Pass", Abschnitte.ohneKategorie])
    }

    func test_eine_unbekannte_kategorie_steht_hinten_aber_fest() {
        // Gerade gelöscht, oder eine ältere Serverfassung: Die App kennt
        // den Namen nicht. Er darf nicht dorthin rutschen, wo die
        // Wörterbuchschlüssel ihn zufällig ausspucken -- sonst sähe
        // dieselbe Liste bei jedem Öffnen anders aus.
        let abschnitte = Abschnitte.gruppieren(
            [play(1, "Slant", kategorie: "Pass"),
             play(2, "Screen", kategorie: "Weg"),
             play(3, "Bomb", kategorie: "Alt"),
             play(4, "Trick", kategorie: nil)],
            kategorien: dreiKategorien)

        XCTAssertEqual(abschnitte.map(\.name),
                       ["Pass", "Alt", "Weg", Abschnitte.ohneKategorie])
    }

    func test_kein_play_geht_beim_gruppieren_verloren() {
        // Die stillste Art, wie eine Gruppierung falsch wird: Ein Play
        // taucht in keinem Abschnitt auf, und niemand vermisst ihn,
        // weil die Liste vollständig AUSSIEHT.
        let plays = [play(1, "Slant", kategorie: "Pass"),
                     play(2, "Dive", kategorie: "Lauf"),
                     play(3, "Trick", kategorie: nil),
                     play(4, "Screen", kategorie: "Pass")]
        let abschnitte = Abschnitte.gruppieren(plays,
                                               kategorien: dreiKategorien)

        XCTAssertEqual(abschnitte.flatMap(\.plays).map(\.id).sorted(),
                       [1, 2, 3, 4])
    }

    func test_ohne_plays_gibt_es_keine_leeren_abschnitte() {
        // Eine Überschrift ohne Zeilen darunter ist kein Hinweis, dass
        // die Kategorie existiert, sondern sieht aus wie ein Fehler.
        XCTAssertTrue(Abschnitte.gruppieren([], kategorien: dreiKategorien)
                        .isEmpty)
    }
}
