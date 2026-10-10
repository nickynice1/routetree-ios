// Was auf der Mannschaftskachel steht -- gemessen ohne Bildschirm (R13).
//
// Es gibt keinen Mac. Eine Regel, die in einer SwiftUI-Ansicht steht,
// lässt sich hier nicht ausprobieren, sondern nur behaupten. Deshalb
// steht alles Entscheidende in `Kachelblock`, und die Ansicht zeichnet
// nur, was dort herauskommt -- dieselbe Entscheidung wie bei
// `Kaderblock` (B9) und `Kurve` (R7).
//
// GEMESSEN WIRD AUCH DER WEG DAHIN: Jede Mannschaft entsteht hier aus
// echtem Server-JSON und nicht aus einem Init. Ein umbenanntes Feld
// fiele sonst erst auf dem Gerät auf, und zwar als leeres Wappen.

import XCTest
@testable import Routetree

final class KachelblockTests: XCTestCase {

    private func team(id: Int = 7,
                      name: String = "Rostock Griffins U17",
                      logo: String? = nil,
                      initialen: String = "RU",
                      rolle: String? = "Head Coach",
                      vereinsadmin: Bool = false,
                      mitglieder: Int = 12,
                      playbooks: Int = 2) -> Modell.Mannschaft {
        let logozeile = logo.map { "\"logo\": \"\($0)\"," } ?? ""
        let rollezeile = rolle.map { "\"rolle_text\": \"\($0)\"," } ?? ""
        let json = """
        {"id": \(id), "name": "\(name)", "farbe": "#2E7D96",
         \(logozeile)
         "initialen": "\(initialen)",
         "verein": {"id": 1, "name": "Griffins e. V.", "demo": false},
         "rolle": "head", \(rollezeile)
         "ist_vereinsadmin": \(vereinsadmin),
         "darf_aendern": true, "darf_fuehren": true,
         "mitglieder": \(mitglieder), "playbooks": \(playbooks)}
        """
        return try! JSONDecoder().decode(Modell.Mannschaft.self,
                                         from: Data(json.utf8))
    }

    // MARK: - Das Wappen

    func testMitLogoStehtDasLogoDa() {
        let bild = team(logo: "https://playbook.afcv-mv.de/medien/logos/g.png")
        XCTAssertEqual(
            Kachelblock.wappen(bild),
            .bild(URL(string:
                "https://playbook.afcv-mv.de/medien/logos/g.png")!))
    }

    func testOhneLogoStehenDieInitialenDa() {
        XCTAssertEqual(Kachelblock.wappen(team()), .initialen("RU"))
    }

    /// Die Initialen kommen vom Server. Schickt er keine -- ein älterer
    /// Stand, eine halbe Antwort --, wird hier NICHTS gerechnet: Eine
    /// zweite Abkürzungsregel hieße, dieselbe Mannschaft heißt auf dem
    /// Ausdruck „RU" und im Telefon „RO".
    func testOhneInitialenStehtEinZeichenDaUndKeineErfindung() {
        XCTAssertEqual(Kachelblock.wappen(team(initialen: "")), .zeichen)
    }

    /// Der Fall vom Spielfeldrand (R14): Es GIBT ein Logo, es kommt nur
    /// nicht an. Ein leerer Kreis sähe dort aus wie ein Fehler der App.
    func testEinLogoDasNichtAnkommtWirdZuDenInitialen() {
        let bild = team(logo: "https://playbook.afcv-mv.de/medien/logos/g.png")
        XCTAssertEqual(Kachelblock.wappen(bild),
                       .bild(bild.logo!))
        XCTAssertEqual(Kachelblock.ohneBild(bild), .initialen("RU"))
    }

    /// Eine Adresse, aus der sich keine URL machen lässt, kostet das
    /// Wappen -- nicht die Mannschaftsliste.
    func testEineKaputteAdresseWirftNicht() {
        XCTAssertEqual(Kachelblock.wappen(team(logo: "")), .initialen("RU"))
    }

    // MARK: - Die Seiten

    func testHinterDerLetztenMannschaftLiegtDasPlus() {
        let seiten = Kachelblock.seiten([team(id: 7), team(id: 9)])
        XCTAssertEqual(seiten.count, 3)
        XCTAssertEqual(seiten.last, .hinzufuegen)
        // Und zwar DAHINTER: Wer die App aufmacht, will seine
        // Mannschaft sehen und nicht ein Formular.
        XCTAssertEqual(seiten.first?.id, "team-7")
    }

    func testOhneMannschaftBleibtNurDasPlus() {
        XCTAssertEqual(Kachelblock.seiten([]), [.hinzufuegen])
    }

    /// Die Kennung hängt an der Mannschaft und nicht an ihrer Stelle in
    /// der Liste. Sonst springt der Stapel auf eine andere Kachel,
    /// sobald jemand eine Mannschaft anlegt -- und der Trainer sieht
    /// plötzlich einen fremden Kader.
    func testDieKennungHaengtAnDerMannschaft() {
        let vorher = Kachelblock.seiten([team(id: 9)])
        let nachher = Kachelblock.seiten([team(id: 7), team(id: 9)])
        XCTAssertEqual(vorher.first?.id, "team-9")
        XCTAssertEqual(nachher.last(where: { $0 != .hinzufuegen })?.id,
                       "team-9")
    }

    func testDerWischhinweisStehtNichtAufDemPlus() {
        XCTAssertTrue(Kachelblock.zeigtWischhinweis(seiteId: "team-7"))
        XCTAssertFalse(Kachelblock.zeigtWischhinweis(
            seiteId: Kachelblock.Seite.hinzufuegen.id))
    }

    // MARK: - Der Untertitel

    func testDerUntertitelNenntVereinRolleUndZahlen() {
        XCTAssertEqual(
            Kachelblock.untertitel(team()),
            "Griffins e. V. · Head Coach · 12 Leute · 2 Playbooks")
    }

    /// „1 Leute" liest sich wie ein Fehler, und es ist einer.
    func testEinzahlUndMehrzahl() {
        let allein = team(mitglieder: 1, playbooks: 1)
        XCTAssertEqual(
            Kachelblock.untertitel(allein),
            "Griffins e. V. · Head Coach · 1 Person · 1 Playbook")
    }

    /// Kein Mitglied und trotzdem hier: Ein Vereinsadmin sieht jede
    /// Mannschaft seines Vereins. Eine Lücke an dieser Stelle sähe aus
    /// wie ein Fehler.
    func testDerVereinsadminOhneRolleHeisstVereinsverwaltung() {
        let verwaltung = team(rolle: nil, vereinsadmin: true)
        XCTAssertEqual(
            Kachelblock.untertitel(verwaltung),
            "Griffins e. V. · Vereinsverwaltung · 12 Leute · 2 Playbooks")
    }
}
