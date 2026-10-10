// Die Situationen folgen der Spielform (R110.8).
//
// WAS HIER GEMESSEN WIRD, IST EINE REGELAUSKUNFT. „No-Run-Zone" gibt es
// nur da, wo vor der Endzone gepasst werden muss: im Flag und im
// 5er-Tackle. In jeder anderen Tackle-Form ist ein Kästchen mit dieser
// Aufschrift kein Angebot, sondern schlicht falsch -- und wer es anhakt,
// sortiert seinen Play im Call Sheet unter eine Lage, die es im Spiel
// nicht gibt.
//
// Der Browser fragt das seit dem 07.09.2026 beim Server ab. Die App
// zeigte weiter alle zehn.

import XCTest
@testable import Routetree

final class SituationTests: XCTestCase {

    // MARK: - Die Liste hängt an der Zone

    func testImFlagStehtDieNoRunZoneDa() {
        let werte = Situation.fuer(Spielform.zu("flag5")).map(\.wert)
        XCTAssertTrue(werte.contains("norun"), "\(werte)")
    }

    func testImElferStehtSieNichtDa() {
        // DER FUND. Elfer-Tackle hat keine No-Run-Zone.
        let elfer = Spielform.alle.first {
            $0.kontakt && $0.feld.keinLauf <= 0
        }
        guard let elfer else {
            return XCTFail("Keine Tackle-Form ohne No-Run-Zone gefunden")
        }
        let werte = Situation.fuer(elfer).map(\.wert)
        XCTAssertFalse(werte.contains("norun"), "\(elfer.schluessel): \(werte)")
    }

    func testAlleAnderenBleibenUeberall() {
        // Opener, die Versuche, Red Zone und Zwei-Minuten gibt es in
        // jeder Form. Eine Liste, die je nach Form ganz anders aussieht,
        // wäre für einen Trainer, der beides betreut, unbrauchbar.
        for form in Spielform.alle {
            let werte = Set(Situation.fuer(form).map(\.wert))
            for pflicht in ["opener", "first", "redzone", "zweiminuten"] {
                XCTAssertTrue(werte.contains(pflicht),
                              "\(form.schluessel) ohne \(pflicht)")
            }
        }
    }

    func testDieReihenfolgeBleibtDieDesBogens() {
        // Sie ist die Gliederung des Bogens, den der Trainer in der Hand
        // hält. Filtern darf sie nicht umsortieren.
        let alle = Situation.alle.map(\.wert)
        for form in Spielform.alle {
            let gefiltert = Situation.fuer(form).map(\.wert)
            XCTAssertEqual(gefiltert, alle.filter(gefiltert.contains),
                           form.schluessel)
        }
    }

    // MARK: - Über den Schlüssel

    func testEinUnbekannterSchluesselGibtDieVoreinstellung() {
        // Ein Bildschirm ohne jede Situation sähe aus wie ein Fehler.
        XCTAssertFalse(Situation.fuer(schluessel: "gibtesnicht").isEmpty)
        XCTAssertEqual(Situation.fuer(schluessel: "gibtesnicht").map(\.wert),
                       Situation.fuer(Spielform.zu(nil)).map(\.wert))
    }

    func testNilGehtAuch() {
        XCTAssertFalse(Situation.fuer(schluessel: nil).isEmpty)
    }

    // MARK: - Die Kennzeichnung selbst

    func testGenauEineSituationHaengtAnDerZone() {
        // Sie ist ERZEUGT und nicht getippt: Der Erzeuger fragt den
        // Server zweimal. Steht hier plötzlich keine oder stehen zwei,
        // hat sich die Regel auf dem Server geändert -- und dann gehört
        // dieser Test angesehen und nicht die Zahl angepasst.
        XCTAssertEqual(Situation.alle.filter(\.nurMitKeinLaufZone).count, 1)
        XCTAssertEqual(Situation.alle.first(where: \.nurMitKeinLaufZone)?.wert,
                       "norun")
    }
}
