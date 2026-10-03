import XCTest
@testable import Routetree

/// Was hier gemessen wird, ist die GRENZE zum Server.
///
/// Auf diesem Projekt gibt es keinen Mac: Swift wird auf einem
/// Linux-Server geschrieben und erst im CI uebersetzt. Ein Tippfehler in
/// einem Feldnamen faellt deshalb nicht beim Schreiben auf, sondern
/// erst, wenn die App auf dem Geraet nichts anzeigt. Diese Tests fangen
/// genau das ab -- mit echten Antworten, wie der Server sie schickt.
final class ModelleTests: XCTestCase {

    private func entschluesseln<T: Decodable>(_ json: String, als: T.Type) throws -> T {
        try Server.entschluessler.decode(T.self, from: Data(json.utf8))
    }

    func test_playbook_liste_wird_gelesen() throws {
        // Abgeschrieben aus `api_v1_playbooks`, nicht erfunden: `team`
        // ist ein OBJEKT. Beim ersten Anlauf stand hier ein String, und
        // genau das haette auf dem Geraet eine leere Liste ergeben.
        let json = """
        {"playbooks":[{"id":3,"name":"Angriff 2026","saison":"2026",
        "team":{"id":1,"name":"U17"},"plays":12,
        "geaendert":"2026-08-19T18:00:00+00:00"}]}
        """
        let liste = try entschluesseln(json, als: Modell.PlaybookListe.self)
        XCTAssertEqual(liste.playbooks.count, 1)
        XCTAssertEqual(liste.playbooks[0].team.name, "U17")
        XCTAssertEqual(liste.playbooks[0].plays, 12)
    }

    func test_saison_darf_fehlen() throws {
        let json = """
        {"playbooks":[{"id":3,"name":"Ohne Saison","saison":null,
        "team":{"id":1,"name":"U17"},"plays":0,"geaendert":null}]}
        """
        let liste = try entschluesseln(json, als: Modell.PlaybookListe.self)
        XCTAssertNil(liste.playbooks[0].saison)
    }

    func test_play_ohne_nummer_zeigt_nur_den_namen() throws {
        let json = """
        {"plays":[{"id":7,"name":"Slant rechts","nummer":null,"seite":null,
        "kategorie":"Pass kurz","situationen":[]}]}
        """
        let liste = try entschluesseln(json, als: Modell.PlayListe.self)
        // „#0 Slant rechts" waere eine Nummer, die es nicht gibt.
        XCTAssertEqual(liste.plays[0].titel, "Slant rechts")
    }

    func test_play_mit_nummer_zeigt_beides() throws {
        let json = """
        {"plays":[{"id":7,"name":"Slant rechts","nummer":21,"seite":"links",
        "kategorie":null,"situationen":["3rd & lang"]}]}
        """
        let liste = try entschluesseln(json, als: Modell.PlayListe.self)
        XCTAssertEqual(liste.plays[0].titel, "#21 Slant rechts")
    }

    func test_tokenpaar_wird_gelesen() throws {
        // Die Feldnamen stehen mit Unterstrich im JSON und ohne in Swift.
        // Geht der Abgleich kaputt, meldet sich die App als abgemeldet --
        // ohne zu sagen, warum.
        let json = """
        {"zugriff":"pbu_a_b","zugriff_bis":"2026-08-19T18:30:00+00:00",
        "erneuerung":"pbu_c_d","erneuerung_bis":"2026-10-18T18:00:00+00:00"}
        """
        let paar = try entschluesseln(json, als: Anmeldung.Tokenpaar.self)
        XCTAssertEqual(paar.zugriff, "pbu_a_b")
        XCTAssertGreaterThan(paar.erneuerungBis, paar.zugriffBis)
    }

    func test_vereine_werden_gelesen() throws {
        let json = """
        {"vereine":[{"id":1,"name":"TSV Beispiel","rolle":"vereinsadmin",
        "teams":[{"id":2,"name":"U17"}]}]}
        """
        let liste = try entschluesseln(json, als: Modell.VereinsListe.self)
        XCTAssertTrue(liste.vereine[0].istVereinsadmin)
    }
}
