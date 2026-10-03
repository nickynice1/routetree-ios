import XCTest
@testable import Routetree

/// Üben und Lernstand in der App (B8).
///
/// Zwei Dinge werden hier gemessen, und beide lassen sich ohne Mac
/// prüfen: die GRENZE zum Server -- ein Tippfehler in einem Feldnamen
/// fällt sonst erst auf, wenn die App auf dem Gerät eine leere Frage
/// zeigt -- und der `Uebungsblock`, in dem alles steht, was ein
/// Fingertipp auslöst.
///
/// Die JSON-Schnipsel unten sind aus `api_v1_uebung` und
/// `api_v1_uebung_antwort` abgeschrieben, nicht erfunden.
final class UebungTests: XCTestCase {

    private func entschluesseln<T: Decodable>(_ json: String,
                                              als: T.Type) throws -> T {
        try Server.entschluessler.decode(T.self, from: Data(json.utf8))
    }

    private static let frageJson = """
    {"frage":{"los":25.0,"richtung":1,
      "zeichnung":{"players":[{"id":"o_c","side":"off","role":"C",
                               "label":"C","x":25.0,"y":12.5}],
                   "routes":[]},
      "feld":{"spiellaenge":50,"endzone":10,"breite":25,
              "kein_lauf":5,"rush":7},
      "aufgabe":false},
     "auswahl":[{"id":3,"name":"Slant"},{"id":7,"name":"Post"},
                {"id":9,"name":"Wheel"},{"id":4,"name":"Drag"}],
     "fortschritt":{"gesamt":10,"sitzen":4,"angefangen":2,"offen":4,
                    "prozent":40,"aus_auftrag":false},
     "serie_fuer_sitzt":3}
    """

    private func probeRunde() throws -> Modell.Uebungsstand.Runde {
        guard case .frage(let runde) = try entschluesseln(
            Self.frageJson, als: Modell.Uebungsstand.self) else {
            throw XCTSkip("keine Frage")
        }
        return runde
    }

    // MARK: - Die Frage kommt an

    func test_eine_frage_wird_gelesen() throws {
        let runde = try probeRunde()
        XCTAssertEqual(runde.frage.los, 25.0)
        XCTAssertEqual(runde.frage.richtung, 1)
        XCTAssertEqual(runde.frage.zeichnung.spieler.count, 1)
        XCTAssertEqual(runde.frage.feld.breite, 25)
        XCTAssertEqual(runde.auswahl.count, 4)
        XCTAssertEqual(runde.serieFuerSitzt, 3)
    }

    func test_die_reihenfolge_der_knoepfe_bleibt_wie_sie_kam() throws {
        // Der Server hat gemischt. Wer hier sortiert, stellt die
        // richtige Antwort irgendwann an eine berechenbare Stelle.
        let runde = try probeRunde()
        XCTAssertEqual(runde.auswahl.map(\.id), [3, 7, 9, 4])
    }

    func test_zu_wenige_plays_sind_kein_fehler() throws {
        let stand = try entschluesseln(#"{"zu_wenige":3,"plays":2}"#,
                                       als: Modell.Uebungsstand.self)
        guard case .zuWenige(let noetig, let hat) = stand else {
            return XCTFail("Erwartet war „zu wenige“")
        }
        XCTAssertEqual(noetig, 3)
        XCTAssertEqual(hat, 2)
    }

    func test_die_marke_der_aufgabe_kommt_mit() throws {
        let json = Self.frageJson.replacingOccurrences(
            of: "\"aufgabe\":false", with: "\"aufgabe\":true")
        guard case .frage(let runde) = try entschluesseln(
            json, als: Modell.Uebungsstand.self) else {
            return XCTFail("Erwartet war eine Frage")
        }
        XCTAssertTrue(runde.frage.aufgabe)
    }

    // MARK: - Die Antwort

    func test_eine_gewertete_antwort_bringt_ergebnis_und_naechste_frage() throws {
        let json = """
        {"gewertet":true,"richtig":false,
         "meldung":"Das war „Slant“, nicht „Post“.",
         "war":{"id":3,"name":"Slant"},"gewaehlt":{"id":7,"name":"Post"},
         "stand":{"richtig":2,"falsch":1,"serie":0,"sitzt":false},
         \(Self.frageJson.dropFirst())
        """
        let runde = try entschluesseln(json, als: Modell.Antwortrunde.self)
        let ergebnis = try XCTUnwrap(runde.ergebnis)
        XCTAssertFalse(ergebnis.richtig)
        XCTAssertEqual(ergebnis.war.name, "Slant")
        XCTAssertEqual(ergebnis.gewaehlt?.name, "Post")
        XCTAssertEqual(ergebnis.stand.serie, 0)
        XCTAssertFalse(ergebnis.stand.sitzt)
        // Und die nächste Frage steckt in derselben Antwort.
        guard case .frage = runde.naechste else {
            return XCTFail("Die nächste Frage gehört dazu")
        }
    }

    func test_ohne_wertung_gibt_es_kein_ergebnis() throws {
        // Der Normalfall nach einem Neustart oder einem doppelten Tipp.
        let json = "{\"gewertet\":false,\(Self.frageJson.dropFirst())"
        let runde = try entschluesseln(json, als: Modell.Antwortrunde.self)
        XCTAssertNil(runde.ergebnis)
        guard case .frage = runde.naechste else {
            return XCTFail("Gefragt wird trotzdem weiter")
        }
    }

    func test_ein_geloeschter_play_laesst_gewaehlt_leer() throws {
        let json = """
        {"gewertet":true,"richtig":false,"meldung":"Das war „Slant“.",
         "war":{"id":3,"name":"Slant"},"gewaehlt":null,
         "stand":{"richtig":0,"falsch":1,"serie":0,"sitzt":false},
         \(Self.frageJson.dropFirst())
        """
        let runde = try entschluesseln(json, als: Modell.Antwortrunde.self)
        XCTAssertNil(try XCTUnwrap(runde.ergebnis).gewaehlt)
    }

    // MARK: - Der Fortschritt

    func test_der_anteil_kommt_aus_den_zahlen_des_servers() throws {
        let runde = try probeRunde()
        XCTAssertEqual(runde.fortschritt.anteil, 0.4, accuracy: 0.0001)
        XCTAssertEqual(runde.fortschritt.prozent, 40)
    }

    func test_ohne_plays_ist_der_anteil_null_und_kein_absturz() {
        let leer = Modell.Fortschritt(gesamt: 0, sitzen: 0)
        XCTAssertEqual(leer.anteil, 0)
    }

    // MARK: - Der Übungsblock

    func test_am_anfang_laedt_er_und_es_gibt_nichts_zu_antworten() {
        let block = Uebungsblock()
        XCTAssertEqual(block.zustand, .laedt)
        XCTAssertFalse(block.darfAntworten)
    }

    func test_der_zweite_fingertipp_zaehlt_nicht() throws {
        // DIE WICHTIGSTE PRUEFUNG HIER. Auf einem langsamen Netz tippt
        // ein Kind zweimal. Die zweite Antwort träfe eine Frage, die es
        // nicht mehr gibt -- und auf dem Schirm stünde eine Meldung zu
        // einer Frage, die gar nicht mehr gestellt war.
        var block = Uebungsblock()
        block.uebernimm(.frage(try probeRunde()))
        XCTAssertTrue(block.antworten(3))
        XCTAssertFalse(block.antworten(7))
        XCTAssertEqual(block.unterwegs, 3)
        XCTAssertFalse(block.darfAntworten)
    }

    func test_ohne_frage_loest_ein_tipp_nichts_aus() {
        var block = Uebungsblock()
        XCTAssertFalse(block.antworten(3))
        block.uebernimm(.zuWenige(noetig: 3, hat: 2))
        XCTAssertFalse(block.antworten(3))
    }

    func test_nach_der_antwort_steht_die_meldung_ueber_der_neuen_frage() throws {
        var block = Uebungsblock()
        block.uebernimm(.frage(try probeRunde()))
        _ = block.antworten(3)

        let json = """
        {"gewertet":true,"richtig":true,"meldung":"Richtig. Das war „Slant“.",
         "war":{"id":3,"name":"Slant"},"gewaehlt":{"id":3,"name":"Slant"},
         "stand":{"richtig":1,"falsch":0,"serie":1,"sitzt":false},
         \(Self.frageJson.dropFirst())
        """
        block.uebernimm(try entschluesseln(json, als: Modell.Antwortrunde.self))

        XCTAssertNil(block.unterwegs)
        XCTAssertTrue(block.darfAntworten)
        XCTAssertEqual(block.meldung?.text, "Richtig. Das war „Slant“.")
        XCTAssertEqual(block.meldung?.richtig, true)
    }

    func test_ohne_wertung_steht_keine_meldung_da() throws {
        // Ein Satz dazu würde etwas behaupten, das nicht passiert ist.
        var block = Uebungsblock()
        block.uebernimm(.frage(try probeRunde()))
        _ = block.antworten(3)
        let json = "{\"gewertet\":false,\(Self.frageJson.dropFirst())"
        block.uebernimm(try entschluesseln(json, als: Modell.Antwortrunde.self))
        XCTAssertNil(block.meldung)
        XCTAssertTrue(block.darfAntworten)
    }

    func test_die_alte_meldung_geht_beim_naechsten_tipp_weg() throws {
        var block = Uebungsblock()
        block.uebernimm(.frage(try probeRunde()))
        _ = block.antworten(3)
        let json = """
        {"gewertet":true,"richtig":true,"meldung":"Richtig. Das war „Slant“.",
         "war":{"id":3,"name":"Slant"},"gewaehlt":{"id":3,"name":"Slant"},
         "stand":{"richtig":1,"falsch":0,"serie":1,"sitzt":false},
         \(Self.frageJson.dropFirst())
        """
        block.uebernimm(try entschluesseln(json, als: Modell.Antwortrunde.self))
        _ = block.antworten(7)
        XCTAssertNil(block.meldung,
                     "Sonst stünde der Satz zur vorletzten Frage noch da")
    }

    func test_ein_fehler_beim_absenden_laesst_die_frage_stehen() throws {
        // Sonst nähme ein Netzfehler das Diagramm vom Schirm, und der
        // nächste Fingertipp träfe eine leere Seite.
        var block = Uebungsblock()
        let runde = try probeRunde()
        block.uebernimm(.frage(runde))
        _ = block.antworten(3)
        block.fehlgeschlagen("Keine Verbindung zum Server.")

        XCTAssertEqual(block.zustand, .frage(runde))
        XCTAssertNil(block.unterwegs)
        XCTAssertTrue(block.darfAntworten)
        XCTAssertEqual(block.meldung?.text, "Keine Verbindung zum Server.")
        XCTAssertEqual(block.meldung?.richtig, false)
    }

    func test_ein_fehler_ganz_am_anfang_ist_das_einzige_was_dasteht() {
        var block = Uebungsblock()
        block.fehlgeschlagen("Keine Verbindung zum Server.")
        XCTAssertEqual(block.zustand, .fehler("Keine Verbindung zum Server."))
        XCTAssertNil(block.meldung)
    }

    func test_zu_wenige_plays_raeumen_die_meldung_ab() throws {
        // Sonst stünde unter „Zum Üben fehlen Plays" noch der Satz zur
        // letzten Antwort aus einem anderen Playbook.
        var block = Uebungsblock()
        block.uebernimm(.frage(try probeRunde()))
        _ = block.antworten(3)
        block.fehlgeschlagen("Keine Verbindung zum Server.")
        block.uebernimm(.zuWenige(noetig: 3, hat: 2))
        XCTAssertNil(block.meldung)
    }

    // MARK: - Der Lernstand

    func test_die_uebersicht_wird_gelesen() throws {
        let json = """
        {"plays":10,"serie_fuer_sitzt":3,
         "zeilen":[{"mitglied":4,"name":"Robin Bergman","rolle":"Zuschauer",
                    "fortschritt":{"gesamt":6,"sitzen":2,"angefangen":1,
                                   "offen":3,"prozent":33,
                                   "aus_auftrag":true}}],
         "schwierig":[{"id":9,"name":"Wheel","nummer":null,"sitzen":0,
                       "von":4,"falsch":6}]}
        """
        let liste = try entschluesseln(json, als: Modell.Lernstandsliste.self)
        XCTAssertEqual(liste.serieFuerSitzt, 3)
        XCTAssertEqual(liste.zeilen.first?.name, "Robin Bergman")
        XCTAssertEqual(liste.zeilen.first?.id, 4,
                       "Die Kennung ist die der Mitgliedschaft (A5)")
        XCTAssertTrue(try XCTUnwrap(liste.zeilen.first).fortschritt.ausAuftrag)
        XCTAssertNil(liste.schwierig.first?.nummer)
        XCTAssertEqual(liste.schwierig.first?.falsch, 6)
    }

    // MARK: - Was die Playliste über das Üben sagt

    func test_der_kopf_nennt_knopf_und_schwelle() throws {
        let json = """
        {"playbook":{"id":2,"name":"Saison","darf_anlegen":true,
                     "darf_aendern":true,"plays_frei":null,
                     "darf_lernstand":true,"uebung_ab":3},
         "plays":[]}
        """
        let liste = try entschluesseln(json, als: Modell.PlayListe.self)
        XCTAssertEqual(liste.playbook?.darfLernstand, true)
        XCTAssertEqual(liste.playbook?.uebungAb, 3)
    }

    func test_ohne_schwelle_wird_nicht_geuebt() throws {
        // Ein geratener Schwellwert wäre ein Knopf, der beim Drücken
        // „zu wenige Plays" sagt -- und das ist ein toter Knopf.
        let json = """
        {"playbook":{"id":2,"name":"Saison"},"plays":[]}
        """
        let liste = try entschluesseln(json, als: Modell.PlayListe.self)
        XCTAssertEqual(liste.playbook?.uebungAb, Int.max)
        XCTAssertEqual(liste.playbook?.darfLernstand, false)
    }

    func test_ein_play_traegt_seine_aufgabe() throws {
        let json = """
        {"plays":[{"id":3,"name":"Slant","nummer":1,"position":1,
                   "version":2,"aufgabe":true},
                  {"id":4,"name":"Post","nummer":2,"position":2,
                   "version":1,"aufgabe":false}]}
        """
        let liste = try entschluesseln(json, als: Modell.PlayListe.self)
        XCTAssertTrue(liste.plays[0].aufgabe)
        XCTAssertFalse(liste.plays[1].aufgabe)
    }

    func test_ohne_angabe_ist_ein_play_keine_aufgabe() throws {
        // Ein Maschinenschlüssel gehört keinem Menschen; der Server
        // lässt den Schlüssel dann weg.
        let json = #"{"plays":[{"id":3,"name":"Slant","nummer":1,"#
            + #""position":1,"version":1}]}"#
        let liste = try entschluesseln(json, als: Modell.PlayListe.self)
        XCTAssertFalse(liste.plays[0].aufgabe)
    }

    // MARK: - Die Aufgabe steht oben (A7)

    private func plays(aufgabe: Set<Int>) -> [Modell.PlayKurz] {
        [(1, "Slant", "Pass"), (2, "Dive", "Lauf"), (3, "Post", "Pass")]
            .map { id, name, kategorie in
                Modell.PlayKurz(id: id, name: name, nummer: id,
                                kategorie: kategorie, position: id,
                                aufgabe: aufgabe.contains(id))
            }
    }

    private let kategorien = [
        Modell.Kategorie(id: 1, name: "Pass", farbe: "#1a5364", position: 1),
        Modell.Kategorie(id: 2, name: "Lauf", farbe: "#8e3320", position: 2),
    ]

    func test_aufgegebene_plays_stehen_in_einem_eigenen_abschnitt_oben() {
        let abschnitte = Abschnitte.gruppieren(
            plays(aufgabe: [2, 3]), kategorien: kategorien,
            aufgabeZuerst: true)
        XCTAssertEqual(abschnitte.first?.name, Abschnitte.aufgabe)
        XCTAssertEqual(abschnitte.first?.plays.map(\.id), [2, 3])
    }

    func test_ein_aufgegebener_play_steht_nur_einmal_da() {
        // Zweimal dieselbe Kachel: Wer die zweite antippt, glaubt, es
        // sei eine andere.
        let abschnitte = Abschnitte.gruppieren(
            plays(aufgabe: [2]), kategorien: kategorien, aufgabeZuerst: true)
        let alle = abschnitte.flatMap { $0.plays.map(\.id) }
        XCTAssertEqual(alle.count, Set(alle).count)
        XCTAssertEqual(abschnitte.map(\.name),
                       [Abschnitte.aufgabe, "Pass"])
    }

    func test_ohne_die_fahne_bleibt_die_liste_wie_sie_war() {
        // Für einen Coach IST diese Liste die Reihenfolge -- er zieht
        // die Kacheln darin. Eine Ansicht, die sie stillschweigend
        // anders legt, macht aus dem Ziehen eine Behauptung.
        let abschnitte = Abschnitte.gruppieren(
            plays(aufgabe: [2, 3]), kategorien: kategorien)
        XCTAssertEqual(abschnitte.map(\.name), ["Pass", "Lauf"])
    }

    func test_ohne_aufgabe_entsteht_kein_leerer_abschnitt() {
        let abschnitte = Abschnitte.gruppieren(
            plays(aufgabe: []), kategorien: kategorien, aufgabeZuerst: true)
        XCTAssertEqual(abschnitte.map(\.name), ["Pass", "Lauf"])
    }

    func test_eine_kategorie_namens_deine_aufgabe_verdeckt_nichts() {
        // `Abschnitt.id` ist NICHT der Name: Zwei gleiche Kennungen, und
        // SwiftUI zeigt einen der beiden gar nicht an -- ohne dass
        // irgendwo ein Fehler stünde.
        let eigen = [Modell.PlayKurz(id: 9, name: "Trick", nummer: 9,
                                     kategorie: Abschnitte.aufgabe,
                                     position: 9)]
        let abschnitte = Abschnitte.gruppieren(
            plays(aufgabe: [2]) + eigen,
            kategorien: kategorien + [Modell.Kategorie(
                id: 3, name: Abschnitte.aufgabe, farbe: "#111111",
                position: 3)],
            aufgabeZuerst: true)
        let kennungen = abschnitte.map(\.id)
        XCTAssertEqual(kennungen.count, Set(kennungen).count)
    }
}
