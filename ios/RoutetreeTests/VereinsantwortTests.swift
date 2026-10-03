// Kommt beim Verein WIRKLICH alles an, was der Server schickt? (R30)
//
// DER STILLE FEHLER, gefunden am 28.08.2026 beim Bauen des Bildschirms
// zum Ändern des Vereinswappens.
//
// `Modell.Verein` hat einen EIGENEN `init(from decoder:)`. Zwei Felder
// standen als Eigenschaft da -- `logo` und `initialen` --, aber weder in
// `CodingKeys` noch im Entschlüssler. Swift meldet das nicht: Beide
// haben einen Vorgabewert (`nil` und `""`), also übersetzt es sauber,
// und die Felder bleiben für immer leer.
//
// Der Server liefert das Wappen seit R30. Die App warf es weg. In der
// Konto-Ansicht stand deshalb weiter die Initialen-Ersatzdarstellung --
// also genau das, was R30 abstellen sollte, und der Punkt galt als
// erledigt.
//
// WARUM DIESE PRÜFUNG GEGEN EINE ECHTE ANTWORT LÄUFT und nicht gegen
// einen Bauweg: `Modell.Verein(id:name:...)` setzt jedes Feld von Hand
// und wäre grün geblieben. Was hier zählt, ist der Weg von einer
// Server-Antwort in den Typ -- und das ist der Weg, an dem es lag.
//
// UND WARUM SIE ALLE FELDER PRÜFT, nicht nur die zwei: Ein Test, der
// genau den einen Fehler von damals abdeckt, findet den nächsten nicht.
// Das nächste Feld wird auf dieselbe Art vergessen.

import XCTest
@testable import Routetree

final class VereinsantwortTests: XCTestCase {

    /// Eine Antwort, wie `api_v1_vereine` sie schickt.
    private let antwort = """
    {
      "id": 7,
      "name": "Strelitz Dukes",
      "rolle": "vereinsadmin",
      "teams": [],
      "demo": false,
      "logo": "https://routetree.de/medien/logos/dukes.png",
      "initialen": "SD",
      "grenzen": {},
      "abo": null
    }
    """

    private func gelesen() throws -> Modell.Verein {
        try Server.entschluessler.decode(
            Modell.Verein.self, from: Data(antwort.utf8))
    }

    func test_das_wappen_kommt_an() throws {
        let verein = try gelesen()
        XCTAssertEqual(verein.logo,
                       "https://routetree.de/medien/logos/dukes.png",
                       "GENAU DER FEHLER von R30: Der Server schickt das "
                       + "Wappen, und der eigene Entschlüssler ließ es "
                       + "unter den Tisch fallen.")
    }

    func test_die_initialen_kommen_an() throws {
        // Sie kommen VOM SERVER, aus derselben Regel wie auf jedem
        // Ausdruck. Rechnet die App sie selbst, heißt derselbe Verein
        // auf dem Blatt „SD" und im Telefon „SU".
        XCTAssertEqual(try gelesen().initialen, "SD")
    }

    func test_die_rolle_kommt_an() throws {
        // Sie entscheidet, ob der Knopf zum Ändern des Wappens
        // überhaupt erscheint (R30, Rest).
        let verein = try gelesen()
        XCTAssertEqual(verein.rolle, "vereinsadmin")
        XCTAssertTrue(verein.istVereinsadmin)
    }

    // DIE EIGENTLICHE ZUSAGE, und der Grund, warum diese Datei mehr
    // prüft als den einen Fehler.
    //
    // Jeder Schlüssel der Antwort muss in `CodingKeys` vorkommen. Fehlt
    // einer, behält sein Feld stillschweigend den Vorgabewert -- so ist
    // es bei `logo` und `initialen` gelaufen.
    //
    // Gemessen an den Schlüsseln der Antwort oben, nicht an einer
    // zweiten Liste: Eine Liste, die man von Hand pflegt, ist beim
    // nächsten Feld die, die man vergisst.
    func test_jedes_feld_der_antwort_landet_auch_im_typ() throws {
        let roh = try XCTUnwrap(
            try JSONSerialization.jsonObject(
                with: Data(antwort.utf8)) as? [String: Any])
        let bekannt = Set(Modell.Verein.CodingKeys.allCases.map(\.rawValue))
        let unbekannt = Set(roh.keys).subtracting(bekannt)
        XCTAssertEqual(
            unbekannt, [],
            "Diese Felder schickt der Server und der Typ kennt sie nicht. "
            + "Sie behalten ihren Vorgabewert, ohne dass etwas rot wird.")
    }

    func test_eine_aeltere_serverfassung_macht_nichts_kaputt() throws {
        // Die Gegenprobe zur Regel darüber: Fehlt ein Feld, darf NICHT
        // die ganze Antwort ausfallen. Eine Antwort wird auf einmal
        // entschlüsselt -- sonst fiele nicht das Wappen aus, sondern
        // die Vereinsliste und mit ihr der Einstieg der App.
        let knapp = """
        {"id": 1, "name": "Alt", "rolle": "team", "teams": [], "demo": true}
        """
        let verein = try Server.entschluessler.decode(
            Modell.Verein.self, from: Data(knapp.utf8))
        XCTAssertNil(verein.logo)
        XCTAssertEqual(verein.initialen, "")
    }
}
