import XCTest
@testable import Routetree

/// Die sechs Felder am Play, die nicht die Zeichnung sind (B7, R41).
///
/// Auf diesem Projekt gibt es keinen Mac. Ein Feld, das der Server
/// schickt und das `init(from:)` überliest, fällt deshalb nicht beim
/// Schreiben auf, sondern erst, wenn ein Trainer im Editor eine leere
/// Auswahl vorfindet. Genau das ist am 28.08.2026 mit `Verein.logo`
/// passiert und am 02.09. beinahe wieder: `seite`, `kategorie_id` und
/// `situationen` standen in `CodingKeys` und wurden nicht gelesen.
///
/// Die JSON-Schnipsel unten sind aus `_play_kurz` und `_play_voll`
/// abgeschrieben, nicht erfunden.
final class PlayangabenTests: XCTestCase {

    private func entschluesseln<T: Decodable>(_ json: String,
                                              als: T.Type) throws -> T {
        try Server.entschluessler.decode(T.self, from: Data(json.utf8))
    }

    private let vollstaendig = """
    {"id":7,"name":"Slant","nummer":3,"seite":"def","kategorie":"Pass kurz",
    "kategorie_id":4,"kategorie_farbe":"#1a5364",
    "situationen":["redzone","first"],"playbook":12,
    "hinweise":"Gegen Zone kurz sitzen","los":25.0,"richtung":1,
    "version":2,"zeichnung":{},"darf_aendern":true}
    """

    // MARK: - Lesen

    func test_die_drei_neuen_felder_kommen_wirklich_an() throws {
        let voll = try entschluesseln(vollstaendig, als: Modell.PlayVoll.self)
        XCTAssertEqual(voll.seite, "def")
        XCTAssertEqual(voll.kategorieId, 4)
        XCTAssertEqual(voll.situationen, ["redzone", "first"])
    }

    func test_ohne_die_felder_gibt_es_keinen_absturz() throws {
        // Eine ältere Serverfassung oder eine schmalere Antwort. Der
        // Editor soll dann Vorgaben zeigen, nicht sterben.
        let schmal = """
        {"id":7,"name":"Slant","hinweise":"","los":25.0,"richtung":1,
        "version":2,"zeichnung":{}}
        """
        let voll = try entschluesseln(schmal, als: Modell.PlayVoll.self)
        XCTAssertNil(voll.seite)
        XCTAssertNil(voll.kategorieId)
        XCTAssertEqual(voll.situationen, [],
                       "Leer, nicht nil -- sonst braucht jede Stelle ein ??")
    }

    // MARK: - Der Stand auf dem Blatt

    func test_der_stand_kommt_aus_dem_geladenen_play() throws {
        let voll = try entschluesseln(vollstaendig, als: Modell.PlayVoll.self)
        let stand = Playangaben.Stand(von: voll)
        XCTAssertEqual(stand.name, "Slant")
        XCTAssertEqual(stand.nummer, "3")
        XCTAssertEqual(stand.seite, "def")
        XCTAssertEqual(stand.kategorie, 4)
        XCTAssertEqual(stand.situationen, ["redzone", "first"])
        XCTAssertEqual(stand.hinweise, "Gegen Zone kurz sitzen")
    }

    func test_ohne_nummer_steht_dort_nichts_und_keine_null() throws {
        let ohne = """
        {"id":7,"name":"Slant","nummer":null,"hinweise":"","los":25.0,
        "richtung":1,"version":2,"zeichnung":{}}
        """
        let voll = try entschluesseln(ohne, als: Modell.PlayVoll.self)
        let stand = Playangaben.Stand(von: voll)
        XCTAssertEqual(stand.nummer, "",
                       "Eine 0 wäre eine Nummer, die niemand vergeben hat")
        // Und die Vorgabe für die Seite kommt aus der erzeugten Liste,
        // nicht aus einer getippten Zeichenkette.
        XCTAssertEqual(stand.seite, Seite.alle.first?.wert)
    }

    // MARK: - Was hinausgeht

    func test_ohne_aenderung_geht_gar_nichts_hinaus() throws {
        // DER WICHTIGSTE FALL. Wer nur eine Route zieht, darf keine
        // Namens- und keine Nummernprüfung auslösen: Sonst scheitert
        // das Sichern einer Linie daran, dass jemand anderes inzwischen
        // dieselbe Playnummer vergeben hat.
        let voll = try entschluesseln(vollstaendig, als: Modell.PlayVoll.self)
        let stand = Playangaben.Stand(von: voll)
        XCTAssertTrue(stand.unterschied(zu: stand).rumpf.isEmpty)
    }

    func test_nur_das_geaenderte_geht_hinaus() throws {
        let voll = try entschluesseln(vollstaendig, als: Modell.PlayVoll.self)
        let alt = Playangaben.Stand(von: voll)
        var neu = alt
        neu.hinweise = "Neu"
        let rumpf = neu.unterschied(zu: alt).rumpf
        XCTAssertEqual(Set(rumpf.keys), ["hinweise"])
        XCTAssertEqual(rumpf["hinweise"] as? String, "Neu")
    }

    func test_eine_geloeschte_nummer_wird_ausdruecklich_geloescht() throws {
        // Der Unterschied zwischen „nicht erwähnt" und „ausdrücklich
        // keine". Ohne das behielte der Server die alte Nummer, und die
        // App zeigte danach ein leeres Feld über einer vergebenen
        // Nummer.
        let voll = try entschluesseln(vollstaendig, als: Modell.PlayVoll.self)
        let alt = Playangaben.Stand(von: voll)
        var neu = alt
        neu.nummer = ""
        let rumpf = neu.unterschied(zu: alt).rumpf
        XCTAssertTrue(rumpf["nummer"] is NSNull,
                      "Eine geleerte Nummer muss als null hinausgehen")
    }

    func test_eine_geloeschte_kategorie_wird_ausdruecklich_geloescht() throws {
        let voll = try entschluesseln(vollstaendig, als: Modell.PlayVoll.self)
        let alt = Playangaben.Stand(von: voll)
        var neu = alt
        neu.kategorie = nil
        XCTAssertTrue(neu.unterschied(zu: alt).rumpf["kategorie"] is NSNull)
    }

    func test_die_situationen_gehen_in_der_reihenfolge_des_bogens_hinaus() throws {
        // Die Auswahl ist eine Menge, der Bogen hat eine Reihenfolge.
        // Ginge sie zufällig hinaus, sprängen die Haken nach dem
        // Sichern um.
        var stand = Playangaben.Stand()
        stand.situationen = ["zweiminuten", "opener", "redzone"]
        let rumpf = stand.unterschied(zu: Playangaben.Stand()).rumpf
        XCTAssertEqual(rumpf["situationen"] as? [String],
                       ["opener", "redzone", "zweiminuten"])
    }

    func test_der_name_geht_ohne_umgebende_leerzeichen_hinaus() throws {
        var stand = Playangaben.Stand()
        stand.name = "  Slant  "
        XCTAssertEqual(
            stand.unterschied(zu: Playangaben.Stand()).rumpf["name"] as? String,
            "Slant")
    }

    // MARK: - Was das Blatt nicht durchlässt

    func test_ohne_namen_taugt_der_stand_nicht() {
        var stand = Playangaben.Stand()
        stand.name = "   "
        XCTAssertFalse(stand.taugt)
    }

    func test_eine_nummer_ausserhalb_der_grenze_taugt_nicht() {
        var stand = Playangaben.Stand()
        stand.name = "Slant"
        for roh in ["0", "\(Playgrenzen.nummerMax + 1)", "abc", "-3"] {
            stand.nummer = roh
            XCTAssertFalse(stand.taugt, "\(roh) ging durch")
        }
        stand.nummer = "\(Playgrenzen.nummerMax)"
        XCTAssertTrue(stand.taugt, "Die Grenze selbst muss erlaubt sein")
        stand.nummer = ""
        XCTAssertTrue(stand.taugt, "Leer ist ohne Nummer, kein Fehler")
    }

    func test_zu_lange_hinweise_taugen_nicht() {
        // Der Server SCHNEIDET AB und antwortet trotzdem mit 200. Hielte
        // die App nicht selbst an, verlöre ein Trainer die zweite
        // Hälfte seiner Notiz, ohne dass irgendwo etwas steht.
        var stand = Playangaben.Stand()
        stand.name = "Slant"
        stand.hinweise = String(repeating: "x",
                                count: Playgrenzen.hinweiseLaenge)
        XCTAssertTrue(stand.taugt, "Die Grenze selbst muss erlaubt sein")
        XCTAssertEqual(stand.hinweiseUebrig, 0)
        stand.hinweise += "x"
        XCTAssertFalse(stand.taugt)
        XCTAssertEqual(stand.hinweiseUebrig, -1)
    }

    func test_ein_zu_langer_name_taugt_nicht() {
        var stand = Playangaben.Stand()
        stand.name = String(repeating: "x", count: Playgrenzen.nameLaenge)
        XCTAssertTrue(stand.taugt)
        stand.name += "x"
        XCTAssertFalse(stand.taugt)
    }

    // MARK: - Die erzeugten Listen

    func test_die_seiten_sind_die_des_servers() {
        XCTAssertEqual(Seite.alle.map(\.wert), ["off", "def", "st"])
        XCTAssertEqual(Seite.vorgabe, "off")
        XCTAssertEqual(Seite.name(fuer: "gibtsnicht"), "gibtsnicht",
                       "Ein leeres Feld sähe aus wie ein Fehler der Liste")
    }
}
