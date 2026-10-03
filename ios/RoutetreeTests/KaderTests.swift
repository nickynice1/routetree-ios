// Was der Finger im Kader auslöst -- gemessen ohne Bildschirm (B9).
//
// Es gibt keinen Mac. Eine Regel, die in einer SwiftUI-Ansicht steht,
// lässt sich hier nicht ausprobieren, sondern nur behaupten, und eine
// Rückmeldung vom Läufer dauert eine halbe Stunde. Deshalb steht alles
// Entscheidende in `Kaderblock` und `Aufgabenblock`, und die Ansicht
// zeichnet nur, was dort herauskommt. Dieselbe Entscheidung wie bei
// `Zeichenblock` (B4) und `Uebungsblock` (B8).
//
// WAS HIER NICHT ENTSCHIEDEN WIRD: ob jemand etwas darf. Das sagt der
// Server. Hier wird gemessen, welche Knöpfe daraus folgen -- und genau
// da bekommt eine Ansicht sonst ein `||` statt eines `&&`, ohne dass es
// jemandem auffällt, weil der Knopf ja da ist.

import XCTest
@testable import Routetree

final class KaderblockTests: XCTestCase {

    private func team(fuehrt: Bool, aendert: Bool,
                      plays: Int = 12) -> Modell.Mannschaft {
        // Über den Entschlüssler und nicht über einen Init: So wird
        // nebenbei gemessen, dass die Feldnamen des Servers ankommen.
        // Ein umbenanntes `darf_fuehren` fiele sonst erst auf dem Gerät
        // auf, und zwar als fehlender Knopf.
        let json = """
        {"id": 7, "name": "Griffins U17", "farbe": "#1a5364",
         "verein": {"id": 1, "name": "Griffins e. V.", "demo": false},
         "rolle": "head", "rolle_text": "Head Coach",
         "ist_vereinsadmin": false,
         "darf_aendern": \(aendert), "darf_fuehren": \(fuehrt),
         "mitglieder": 3, "playbooks": 1, "plays": \(plays),
         "kader": [], "rollen": []}
        """
        return try! JSONDecoder().decode(Modell.Mannschaft.self,
                                         from: Data(json.utf8))
    }

    private func zeile(letzterHead: Bool = false, darfName: Bool = false,
                       ich: Bool = false,
                       fortschritt: Modell.Fortschritt? = nil)
        -> Modell.Kadermitglied {
        Modell.Kadermitglied(id: 3, name: "Robin Bergman",
                             rolle: "viewer", rolleText: "Nur Ansicht",
                             ich: ich, letzterHead: letzterHead,
                             darfName: darfName, fortschritt: fortschritt)
    }

    func testDerHeadCoachDarfAlles() {
        let kann = Kaderblock.moeglichkeiten(
            fuer: zeile(darfName: true),
            in: team(fuehrt: true, aendert: true))
        XCTAssertTrue(kann.rolleAendern)
        XCTAssertTrue(kann.entfernen)
        XCTAssertTrue(kann.umbenennen)
        XCTAssertTrue(kann.aufgeben)
        XCTAssertNil(kann.grund)
    }

    // MARK: - Selbst gehen (R110.11)

    func testJederDarfSelbstGehen() {
        // DER FUND. Bis zum 10.09.2026 musste jemand, der nicht mehr in
        // einer Mannschaft sein will, den Head Coach darum bitten -- in
        // der App wie in der Schnittstelle. Das ist keine
        // Verwaltungsentscheidung, sondern die eigene.
        let kann = Kaderblock.moeglichkeiten(
            fuer: zeile(ich: true),
            in: team(fuehrt: false, aendert: false))
        XCTAssertTrue(kann.austreten)
    }

    func testFuerFremdeGibtEsKeinAustreten() {
        let kann = Kaderblock.moeglichkeiten(
            fuer: zeile(), in: team(fuehrt: true, aendert: true))
        XCTAssertFalse(kann.austreten)
        XCTAssertTrue(kann.entfernen)
    }

    func testAnDerEIGENENZeileStehtVerlassenUndNichtEntfernen() {
        // Zwei Knöpfe nebeneinander, die dasselbe tun, wären eine
        // Frage, die niemand stellen wollte.
        let kann = Kaderblock.moeglichkeiten(
            fuer: zeile(darfName: true, ich: true),
            in: team(fuehrt: true, aendert: true))
        XCTAssertTrue(kann.austreten)
        XCTAssertFalse(kann.entfernen)
    }

    func testDerLetzteHeadCoachGehtAuchNichtSelbst() {
        // Sonst stünde die Mannschaft ohne jemanden da, der sie
        // verwalten kann, und niemand könnte sich selbst dazu machen.
        // Der Server lehnt es mit 409 ab.
        let kann = Kaderblock.moeglichkeiten(
            fuer: zeile(letzterHead: true, ich: true),
            in: team(fuehrt: true, aendert: true))
        XCTAssertFalse(kann.austreten)
    }

    func testAmLetztenHeadCoachAendertNiemandEtwas() {
        // Auch der Head Coach selbst nicht. Sonst stünde die Mannschaft
        // ohne jemanden da, der sie verwalten kann -- und der Server
        // lehnt es mit 409 ab. Ein Knopf, der beim Drücken 409 bekommt,
        // ist ein toter Knopf.
        let kann = Kaderblock.moeglichkeiten(
            fuer: zeile(letzterHead: true, ich: true),
            in: team(fuehrt: true, aendert: true))
        XCTAssertFalse(kann.rolleAendern)
        XCTAssertFalse(kann.entfernen)
    }

    func testDieAssistenzVerteiltAufgabenAberKeineRollen() {
        // Der Unterschied zwischen `darfAendern` und `darfFuehren`, und
        // er ist die ganze Rechtestufe: Zugänge vergibt nur der Head
        // Coach, Aufgaben verteilt der ganze Trainerstab.
        let kann = Kaderblock.moeglichkeiten(
            fuer: zeile(),
            in: team(fuehrt: false, aendert: true))
        XCTAssertFalse(kann.rolleAendern)
        XCTAssertFalse(kann.entfernen)
        XCTAssertTrue(kann.aufgeben)
    }

    func testEinZuschauerBekommtNurSeinenEigenenNamen() {
        let team = team(fuehrt: false, aendert: false)
        let eigen = Kaderblock.moeglichkeiten(
            fuer: zeile(darfName: true, ich: true), in: team)
        XCTAssertTrue(eigen.umbenennen)
        XCTAssertFalse(eigen.aufgeben)

        let fremd = Kaderblock.moeglichkeiten(fuer: zeile(), in: team)
        XCTAssertFalse(fremd.umbenennen)
        XCTAssertFalse(fremd.rolleAendern)
    }

    func testOhneEinenEinzigenPlayGibtEsNichtsAufzugeben() {
        // Sonst wäre die Aufgabenseite eine leere Liste mit einem
        // Sichern-Knopf.
        let kann = Kaderblock.moeglichkeiten(
            fuer: zeile(),
            in: team(fuehrt: true, aendert: true, plays: 0))
        XCTAssertFalse(kann.aufgeben)
    }

    func testWennNichtsGehtStehtWenigstensDerGrundDa() {
        // Eine Zeile ohne Knöpfe sieht sonst aus wie eine, die noch lädt.
        let kann = Kaderblock.moeglichkeiten(
            fuer: zeile(letzterHead: true),
            in: team(fuehrt: true, aendert: true, plays: 0))
        XCTAssertEqual(kann.grund, Kaderblock.einzigerHead)
    }

    func testDerAufgabenknopfSagtObEsSchonEineGibt() {
        // „Plays aufgeben" bei jemandem, der schon sechs aufhat, liest
        // sich, als würde man von vorn anfangen.
        XCTAssertEqual(Kaderblock.aufgabenknopf(fuer: zeile()),
                       "Plays aufgeben")
        let mitAuftrag = zeile(fortschritt: Modell.Fortschritt(
            gesamt: 6, sitzen: 2, ausAuftrag: true))
        XCTAssertEqual(Kaderblock.aufgabenknopf(fuer: mitAuftrag),
                       "Aufgabe ändern")
    }

    func testOhneDatumStehtNurDieRolleDa() {
        // Leer heißt „nie aufgeschrieben" (A6). „dabei seit —" sähe aus
        // wie ein Fehler, und ein erfundener Tag sähe aus wie gemessen.
        XCTAssertEqual(Kaderblock.unterzeile(zeile()), "Nur Ansicht")
    }

    func testMitDatumStehtEsDabei() {
        let zeile = Modell.Kadermitglied(
            id: 4, name: "Mia Voss", rolle: "assistant",
            rolleText: "Assistenz",
            seit: Date(timeIntervalSince1970: 1_756_080_000))
        let satz = Kaderblock.unterzeile(zeile)
        XCTAssertTrue(satz.hasPrefix("Assistenz · dabei seit "), satz)
    }
}

final class AufgabenblockTests: XCTestCase {

    private func blatt() -> Modell.Aufgabenblatt {
        let json = """
        {"ziel": {"id": 3, "name": "Robin Bergman",
                  "rolle_text": "Nur Ansicht"},
         "hefte": [
           {"id": 1, "name": "Offense", "plays": [
             {"id": 11, "name": "Mesh", "nummer": 1, "angehakt": true},
             {"id": 12, "name": "Smash", "nummer": 2, "angehakt": false}]},
           {"id": 2, "name": "Defense", "plays": [
             {"id": 21, "name": "Cover 2", "nummer": 1, "angehakt": true}]}],
         "wieviele": 2, "plays_gesamt": 3}
        """
        return try! JSONDecoder().decode(Modell.Aufgabenblatt.self,
                                         from: Data(json.utf8))
    }

    func testDerAnfangIstDasWasAngehaktKam() {
        let stand = Aufgabenblock(blatt: blatt())
        XCTAssertEqual(stand.anzahl, 2)
        XCTAssertTrue(stand.istAngehakt(11))
        XCTAssertFalse(stand.istAngehakt(12))
        XCTAssertFalse(stand.geaendert)
    }

    func testUmschaltenUndZurueckIstKeineAenderung() {
        // Sonst bliebe „Sichern" hell, nachdem jemand einen Haken
        // gesetzt und wieder weggenommen hat -- und eine Absendung, die
        // nichts ändert, macht aus „hat angesehen" ein „hat neu
        // aufgegeben" (`angelegt_am`).
        var stand = Aufgabenblock(blatt: blatt())
        stand.umschalten(12)
        XCTAssertTrue(stand.geaendert)
        stand.umschalten(12)
        XCTAssertFalse(stand.geaendert)
    }

    func testDieListeStehtInFesterReihenfolge() {
        // Eine Menge hat keine. Zwei gleiche Auswahlen müssen dieselbe
        // Anfrage ergeben, sonst sieht jeder Vergleich zufällig aus.
        var stand = Aufgabenblock(blatt: blatt())
        stand.umschalten(12)
        XCTAssertEqual(stand.alsListe, [11, 12, 21])
    }

    func testEinHeftAnhakenNimmtDasAndereNichtMit() {
        // DER REFLEXFEHLER. „Alles abwählen" auf die ganze Liste zu
        // legen heißt: Ein Coach, der bei der Offense aufräumt, nimmt
        // nebenbei die Defense-Aufgaben mit weg -- und merkt es nicht,
        // weil er das andere Heft gar nicht aufgeklappt hatte.
        let blatt = blatt()
        var stand = Aufgabenblock(blatt: blatt)
        stand.heft(blatt.hefte[0], an: false)
        XCTAssertFalse(stand.istAngehakt(11))
        XCTAssertTrue(stand.istAngehakt(21))

        stand.heft(blatt.hefte[0], an: true)
        XCTAssertTrue(stand.heftIstGanzAn(blatt.hefte[0]))
        XCTAssertEqual(stand.anzahl, 3)
    }

    func testAllesAbwaehlenIstEineEntscheidungUndKeinVersehen() {
        // Danach wird wieder aus dem ganzen Playbook geübt. Deshalb ein
        // eigener Weg und nicht „einzeln alle abhaken": Wer ihn geht,
        // hat ihn gewählt.
        var stand = Aufgabenblock(blatt: blatt())
        stand.alleAus()
        XCTAssertEqual(stand.anzahl, 0)
        XCTAssertEqual(stand.alsListe, [])
        XCTAssertTrue(stand.geaendert)
    }

    func testEinLeeresHeftIstNichtGanzAn() {
        // `allSatisfy` über null Einträge ist `true`. Ohne die
        // ausdrückliche Prüfung stünde am leeren Heft „Keins" statt
        // „Alle" -- und der Knopf täte nichts.
        let leer = Modell.Aufgabenblatt.Heft(id: 9, name: "Leer", plays: [])
        let stand = Aufgabenblock(blatt: blatt())
        XCTAssertFalse(stand.heftIstGanzAn(leer))
    }
}
