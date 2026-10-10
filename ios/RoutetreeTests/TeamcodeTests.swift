// Tippt die App denselben Teamcode ein wie der Server? (B9)
//
// `TeamcodeProben` trägt die Antworten des SERVERS, erzeugt von
// `scripts/teamcode_swift.py` aus `backend/designer/teamcode.py`. Hier
// wird `Teamcodeblock` dagegen gemessen -- Eingabe für Eingabe.
//
// Warum das mehr ist als Formalismus: Die App prüft die FORM eines
// Codes, bevor sie fragt. Kürzt sie dabei still, sucht sie einen Code,
// den es nicht gibt, und sagt „ungültig". Der Server sieht diese
// Anfrage nie -- im Protokoll steht nichts, der Spieler tippt dreimal
// ab und gibt auf.

import XCTest
@testable import Routetree

final class TeamcodeTests: XCTestCase {

    func testEsGibtUeberhauptProben() {
        // Eine Schleife über null Fälle ist grün. Dieselbe Lehre wie aus
        // `AppTexteTest` in B5: Eine Prüfung, die nichts findet, hört
        // still auf zu messen.
        XCTAssertGreaterThanOrEqual(TeamcodeProben.faelle.count, 12)
        XCTAssertGreaterThanOrEqual(TeamcodeProben.spannen.count, 9)
    }

    func testJedeEingabeErgibtDasselbeWieAufDemServer() {
        for fall in TeamcodeProben.faelle {
            XCTAssertEqual(Teamcodeblock.normalisieren(fall.eingabe),
                           fall.ergibt,
                           "Eingabe „\(fall.eingabe)“")
        }
    }

    func testDieGruppierungIstDieselbe() {
        // Sie kommt sonst vom Server mit (`Teamcode.lesbar`), aber die
        // App zeigt den frisch getippten Code auch selbst an. Dreier
        // statt Vierer sähen nicht falsch aus, nur anders -- und wer ihn
        // so vorliest, diktiert einen Code, den niemand wiederfindet.
        for fall in TeamcodeProben.faelle where !fall.ergibt.isEmpty {
            XCTAssertEqual(Teamcodeblock.lesbar(fall.ergibt), fall.lesbar,
                           "Eingabe „\(fall.eingabe)“")
        }
    }

    func testDasAlphabetIstDasDesServers() {
        XCTAssertEqual(Teamcodeblock.alphabet, TeamcodeProben.alphabet)
        XCTAssertEqual(Teamcodeblock.laenge, TeamcodeProben.laenge)
    }

    func testVerwechselbareZeichenFehlen() {
        // Der eigentliche Grund für ein eigenes Alphabet: Ein Code wird
        // abgetippt, oft von einem Zettel. Eine Verwechslung von 0 und O
        // wäre kein Tippfehler, sondern einer, den niemand findet.
        for zeichen in "01OIL" {
            XCTAssertFalse(Teamcodeblock.alphabet.contains(zeichen),
                           String(zeichen))
        }
    }

    func testEinOStattDerNullErgibtNichts() {
        // DER TEUERSTE FALL. Ausdrücklich kein um eine Stelle
        // verschobener Code: Der ginge an den Server, käme als „gibt es
        // nicht" zurück, und niemand wüsste, wo es hakte.
        XCTAssertEqual(Teamcodeblock.normalisieren("O7QK3MRW9XTB"), "")
        XCTAssertFalse(Teamcodeblock.siehtAusWieCode("O7QK3MRW9XTB"))
    }

    func testZuKurzUndZuLangErgebenNichts() {
        XCTAssertEqual(Teamcodeblock.normalisieren("P7QK3MRW9XT"), "")
        XCTAssertEqual(Teamcodeblock.normalisieren("P7QK3MRW9XTBB"), "")
    }

    func testTrennerUndKleinschreibungStoerenNicht() {
        for eingabe in ["p7qk-3mrw-9xtb", "P7QK 3MRW 9XTB",
                        "  P7QK·3MRW·9XTB  ", "P7QK_3MRW_9XTB",
                        "P7QK.3MRW.9XTB"] {
            XCTAssertEqual(Teamcodeblock.normalisieren(eingabe),
                           "P7QK3MRW9XTB", eingabe)
        }
    }

    // MARK: - Haltbarkeit

    func testDieSpannenStimmenBisAufDieMinute() {
        for spanne in TeamcodeProben.spannen where !spanne.wert.isEmpty {
            guard let bekannt = Haltbarkeiten.alle
                .first(where: { $0.wert == spanne.wert }) else {
                // Die letzten beiden Zeilen der Probe sind Unsinn und
                // Leere. Sie stehen absichtlich nicht in der Liste.
                continue
            }
            XCTAssertEqual(bekannt.minuten, spanne.minuten, spanne.wert)
        }
    }

    func testDieVorgabeIstNichtUnbegrenzt() {
        // Die Wahl, die man trifft, ohne hinzusehen, muss die harmlose
        // sein. Stünde hier „unbegrenzt", verschenkte ein Trainer seine
        // Mannschaft auf Dauer, und es sähe aus wie eine Entscheidung.
        XCTAssertEqual(Haltbarkeiten.vorgabe, TeamcodeProben.vorgabe)
        XCTAssertFalse(Haltbarkeiten.mit(wert: Haltbarkeiten.vorgabe)
                        .unbegrenzt)
        XCTAssertNotNil(Haltbarkeiten.mit(wert: Haltbarkeiten.vorgabe).minuten)
    }

    func testUnbekanntesFaelltAufDieVorgabeUndNichtAufEwig() {
        for unsinn in ["hundert-jahre", "", "unbegrenzt "] {
            XCTAssertEqual(Haltbarkeiten.mit(wert: unsinn).wert,
                           Haltbarkeiten.vorgabe, unsinn)
        }
    }

    func testGenauEineSpanneIstUnbegrenztUndStehtZuletzt() {
        let unbegrenzt = Haltbarkeiten.alle.filter(\.unbegrenzt)
        XCTAssertEqual(unbegrenzt.count, 1)
        XCTAssertEqual(Haltbarkeiten.alle.last?.wert, "unbegrenzt")
    }
}
