// Üben ohne Empfang: die Regel (R14).
//
// `Paketblock` sagt, welche Frage aus einem vorausberechneten Paket noch
// offen ist, wie weit man ist und wann Nachschub fällig wird. Er rechnet
// NICHT, welcher Play drankommt -- das hat der Server getan, als er das
// Paket baute. Eine zweite Gewichtung in Swift sähe nie falsch aus,
// sondern nur nach Zufall.
//
// WARUM DAS EINE EIGENE DATEI IST, aus demselben Grund wie
// `Vorratsblock` und `Kachelblock`: Zwischen Dateizugriffen und einer
// Ansicht ließe sich diese Rechnung ohne Mac nicht messen, sondern nur
// behaupten.

import XCTest
@testable import Routetree

final class PaketblockTests: XCTestCase {

    /// Ein Paket mit `anzahl` Fragen, Marken „m0" bis „m<n-1>".
    ///
    /// Über den Entschlüssler gebaut und nicht über einen Bauweg: So
    /// misst der Test denselben Weg, den eine echte Antwort geht -- und
    /// ein Feld, das in `CodingKeys` fehlt, fällt hier auf statt erst
    /// auf dem Gerät.
    ///
    /// **Das Prüfstück ist VOLLSTÄNDIG, und das musste es lernen.** Der
    /// erste Anlauf kürzte `"feld": {}` und ließ den `fortschritt` weg
    /// -- der Bau war dann rot mit
    /// `keyNotFound("spiellaenge")`. Ein abgekürztes Prüfstück misst
    /// den eigenen Bauweg und nicht den echten; die Maße stehen
    /// deshalb ausgeschrieben, so wie `_play_voll` sie schickt (siehe
    /// `UebungTests`, dasselbe Stück).
    private func paket(_ anzahl: Int) throws -> Modell.Uebungspaket {
        let fragen = (0..<anzahl).map { nr in
            """
            {
              "marke": "m\(nr)",
              "loesung": \(100 + nr),
              "saetze": {"\(100 + nr)": "Richtig. Das war „A“.",
                         "999": "Das war „A“, nicht „B“."},
              "frage": {"los": 20.0, "richtung": 1,
                        "zeichnung": {"players": [], "routes": []},
                        "feld": {"spiellaenge": 50, "endzone": 10,
                                 "breite": 25, "kein_lauf": 5, "rush": 7},
                        "aufgabe": false},
              "auswahl": [{"id": \(100 + nr), "name": "A"},
                          {"id": 999, "name": "B"}],
              "fortschritt": {"gesamt": 10, "sitzen": 4, "angefangen": 2,
                              "offen": 4, "prozent": 40,
                              "aus_auftrag": false},
              "serie_fuer_sitzt": 3
            }
            """
        }.joined(separator: ",")
        let roh = """
        {"fragen": [\(fragen)], "haltbar_tage": 14}
        """
        return try Server.entschluessler.decode(
            Modell.Uebungspaket.self, from: Data(roh.utf8))
    }

    private func antwort(_ marke: String, gewaehlt: Int = 1,
                         vor sekunden: TimeInterval = 0)
        -> Modell.OffeneAntwort {
        Modell.OffeneAntwort(marke: marke, gewaehlt: gewaehlt,
                             wann: Date(timeIntervalSince1970: 1_000_000
                                        - sekunden))
    }

    // MARK: - Was noch offen ist

    func test_ohne_antworten_ist_alles_offen() throws {
        let p = try paket(5)
        XCTAssertEqual(Paketblock.offen(p, beantwortet: []).count, 5)
    }

    func test_beantwortete_fragen_fallen_raus() throws {
        let p = try paket(5)
        let offen = Paketblock.offen(
            p, beantwortet: [antwort("m0"), antwort("m2")])
        XCTAssertEqual(offen.map(\.marke), ["m1", "m3", "m4"])
    }

    func test_die_reihenfolge_des_servers_bleibt() throws {
        // **Sie ist seine Gewichtung.** Wer sie umsortiert, übergeht
        // genau die Rechnung, für die es das Paket gibt.
        let p = try paket(4)
        XCTAssertEqual(Paketblock.offen(p, beantwortet: []).map(\.marke),
                       ["m0", "m1", "m2", "m3"])
    }

    func test_die_naechste_ist_die_erste_offene() throws {
        let p = try paket(3)
        XCTAssertEqual(
            Paketblock.naechste(p, beantwortet: [antwort("m0")])?.marke, "m1")
    }

    func test_ein_durchgearbeitetes_paket_hat_keine_naechste() throws {
        let p = try paket(2)
        XCTAssertNil(Paketblock.naechste(
            p, beantwortet: [antwort("m0"), antwort("m1")]))
    }

    // MARK: - Der Stand

    func test_der_stand_zaehlt_das_PAKET_und_nicht_den_lernstand() throws {
        // Der `Fortschritt` des Servers zählt, wie viele Plays SITZEN,
        // und ändert sich ohne Netz nicht. Am Platz braucht es eine
        // Zahl, die sich bewegt.
        let p = try paket(10)
        let stand = Paketblock.stand(
            p, beantwortet: [antwort("m0"), antwort("m1"), antwort("m2")])
        XCTAssertEqual(stand.fertig, 3)
        XCTAssertEqual(stand.gesamt, 10)
    }

    // MARK: - Nachschub

    func test_ohne_paket_braucht_es_eins() {
        XCTAssertTrue(Paketblock.brauchtNachschub(nil, beantwortet: []))
    }

    func test_ein_leeres_paket_zaehlt_wie_keins() throws {
        let p = try paket(0)
        XCTAssertTrue(Paketblock.brauchtNachschub(p, beantwortet: []))
    }

    func test_frisch_gefuellt_braucht_es_keinen() throws {
        let p = try paket(20)
        XCTAssertFalse(Paketblock.brauchtNachschub(p, beantwortet: []))
    }

    func test_ab_der_HAELFTE_wird_nachgeholt() throws {
        // **Nicht erst, wenn es leer ist.** Wer die letzte Frage
        // beantwortet und dann kein Netz hat, steht vor einem leeren
        // Übungsmodus -- genau in dem Moment, für den das Ganze gebaut
        // ist.
        let p = try paket(10)
        let vier = (0..<4).map { antwort("m\($0)") }
        XCTAssertFalse(Paketblock.brauchtNachschub(p, beantwortet: vier))
        let fuenf = (0..<5).map { antwort("m\($0)") }
        XCTAssertTrue(Paketblock.brauchtNachschub(p, beantwortet: fuenf))
    }

    // MARK: - Bewerten am Platz

    func test_die_loesung_entscheidet() throws {
        let frage = try XCTUnwrap(paket(1).fragen.first)
        XCTAssertTrue(Paketblock.warRichtig(frage, gewaehlt: 100))
        XCTAssertFalse(Paketblock.warRichtig(frage, gewaehlt: 999))
    }

    func test_der_satz_kommt_vom_SERVER() throws {
        // Er wird nicht in Swift gebaut. Denselben Satz liest der
        // Browser; in Swift nachgebaut wäre er beim nächsten Wort ein
        // anderer, und `test_ton.py` käme an ihn nicht heran.
        let frage = try XCTUnwrap(paket(1).fragen.first)
        XCTAssertEqual(frage.satz(fuer: 100), "Richtig. Das war „A“.")
        XCTAssertEqual(frage.satz(fuer: 999), "Das war „A“, nicht „B“.")
    }

    func test_zu_einer_unbekannten_antwort_gibt_es_KEINEN_satz() throws {
        // Leer und nicht selbstgebaut: Besser nichts als ein Satz, den
        // der Server nie gesagt hat.
        let frage = try XCTUnwrap(paket(1).fragen.first)
        XCTAssertEqual(frage.satz(fuer: 4711), "")
    }

    // MARK: - Die Fuhre

    func test_die_aeltesten_gehen_zuerst() {
        // **Die Reihenfolge ist die zeitliche**, und `Lernstand.serie`
        // hängt daran: erst richtig und dann falsch ergibt eine andere
        // Serie als umgekehrt.
        let liste = [antwort("neu", vor: 0),
                     antwort("alt", vor: 500),
                     antwort("mittel", vor: 200)]
        XCTAssertEqual(Paketblock.naechsteFuhre(liste).map(\.marke),
                       ["alt", "mittel", "neu"])
    }

    func test_eine_fuhre_bleibt_unter_der_grenze_des_servers() {
        // Der Server weist mehr als 200 ab. Mit Abstand, denn wer genau
        // an die Grenze geht, bekommt beim nächsten Feld darüber eine
        // Absage, die niemand erwartet hat.
        let viele = (0..<300).map { antwort("m\($0)", vor: TimeInterval(300 - $0)) }
        let fuhre = Paketblock.naechsteFuhre(viele)
        XCTAssertEqual(fuhre.count, Paketblock.hoechstensJeAnfrage)
        XCTAssertLessThan(Paketblock.hoechstensJeAnfrage, 200)
        XCTAssertEqual(fuhre.first?.marke, "m0",
                       "Auch bei einer Kappung gehen die ältesten zuerst.")
    }

    func test_wartend_zaehlt_was_niemand_kennt() {
        XCTAssertEqual(Paketblock.wartend([antwort("a"), antwort("b")]), 2)
    }
}
