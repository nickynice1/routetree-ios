// Die Serveradresse -- und die Umleitung, die alles Schreiben verschluckt hat.
//
// DER GEMELDETE FALL, Niklas am 28.08.2026:
//
// > „wenn ich auf google anmelden gehe und den account wähle passiert
// > nix bin nicht angemeldet"
//
// Im Serverprotokoll stand dazu:
//
//     "GET /api/v1/auth/fremd/ HTTP/1.0" 405 "Routetree/2608280259"
//
// Ein `GET`. Im Swift-Code steht an dieser Stelle `methode: "POST"`.
//
// DIE URSACHE war nicht die Anmeldung, sondern eine Zeile weiter unten
// im Stapel: `Server.basis` zeigte auf `https://playbook.afcv-mv.de`.
// Diese Adresse antwortet seit dem Umzug mit `301` auf
// `https://routetree.de`. `URLSession` folgt der Umleitung -- und macht
// dabei aus einem `POST` ein `GET` und wirft den Rumpf weg. Altes
// HTTP-Verhalten, kein Fehler der Bibliothek.
//
// WARUM DAS NIEMANDEM AUFFIEL: Ein `GET` überlebt eine Umleitung
// unbeschadet. Lesen ging also weiter, die ganze App sah gesund aus, und
// kaputt war ausschließlich alles, was etwas verändert -- anmelden,
// speichern, anlegen, löschen. Die Anmeldung mit Google war nur die
// erste Stelle, an der jemand es gemerkt hat.
//
// Diese Datei hält beide Hälften fest: die richtige Adresse, und dass
// eine Umleitung nie wieder still bleibt.

import XCTest
@testable import Routetree

final class ServeradresseTests: XCTestCase {

    // --- Die Adresse selbst ----------------------------------------------

    func test_die_basis_ist_die_endgueltige_adresse() {
        XCTAssertEqual(Server.basis.absoluteString, "https://routetree.de",
                       "playbook.afcv-mv.de leitet mit 301 weiter, und eine "
                       + "Umleitung macht aus jedem POST ein GET.")
    }

    func test_die_basis_traegt_keinen_schraegstrich_am_ende() {
        // `URL(string:relativeTo:)` fügt ihn selbst ein. Stünde er hier
        // AUCH, entstünde `https://routetree.de//api/v1/...` -- und
        // darauf antwortet Django mit einer Umleitung, also genau mit
        // dem Fehler, den diese Datei verhindern soll.
        XCTAssertFalse(Server.basis.absoluteString.hasSuffix("/"))
    }

    func test_ein_weg_haengt_sich_richtig_an_die_basis() {
        let anfrage = try? Server.anfrage("/api/v1/auth/fremd/", methode: "POST")
        XCTAssertEqual(anfrage?.url?.absoluteString,
                       "https://routetree.de/api/v1/auth/fremd/")
    }

    // --- Die Regel gegen die stille Umleitung -----------------------------

    func test_ein_umgeleiteter_post_gilt_als_fehler() {
        let anfrage = try! Server.anfrage("/api/v1/auth/fremd/", methode: "POST")
        let angekommen = URL(string: "https://routetree.de/api/v1/auth/fremd/")!
        let umgezogen = URL(string: "https://anderswo.example/api/v1/auth/fremd/")!

        XCTAssertFalse(Server.umgeleitet(anfrage, nach: angekommen),
                       "Ohne Umleitung ist nichts zu melden.")
        XCTAssertTrue(Server.umgeleitet(anfrage, nach: umgezogen),
                      "GENAU DER GEMELDETE FALL: Der Rumpf ist unterwegs "
                      + "verlorengegangen, und die Antwort erzählt davon "
                      + "nichts.")
    }

    func test_ein_get_darf_umgeleitet_werden() {
        // Sonst zerbräche jeder Bildabruf an einem Schrägstrich zu viel
        // -- und ein Test, der auch GET verbietet, macht die App
        // kaputter als der Fehler, den er fangen soll.
        let anfrage = try! Server.anfrage("/api/v1/playbooks/")
        XCTAssertFalse(Server.umgeleitet(
            anfrage, nach: URL(string: "https://routetree.de/woanders/")!))
    }

    func test_ohne_angekommene_adresse_wird_nichts_behauptet() {
        // `HTTPURLResponse.url` ist ein Optional. Nichts zu wissen ist
        // kein Grund, eine gültige Antwort wegzuwerfen.
        let anfrage = try! Server.anfrage("/api/v1/auth/fremd/", methode: "POST")
        XCTAssertFalse(Server.umgeleitet(anfrage, nach: nil))
    }

    func test_auch_delete_und_patch_sind_geschuetzt() {
        // Nicht nur POST. `DELETE` ohne Rumpf käme als `GET` an und
        // löschte nichts -- lautlos, mit einer 405, die aussieht wie ein
        // Fehler der Schnittstelle.
        let ziel = URL(string: "https://anderswo.example/api/v1/plays/1/")!
        for methode in ["POST", "PATCH", "PUT", "DELETE"] {
            let anfrage = try! Server.anfrage("/api/v1/plays/1/",
                                              methode: methode)
            XCTAssertTrue(Server.umgeleitet(anfrage, nach: ziel), methode)
        }
    }
}
