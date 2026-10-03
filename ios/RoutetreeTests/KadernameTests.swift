// Wonach beim Beitritt gefragt wird -- gemessen ohne Bildschirm (R24).
//
// „wo wirklich kein schüler den namen angeben muss weißt du? sondern
// einfach teamcode bekommt und direkt drin ist." (Niklas, 25.08.2026)
//
// Es gibt keinen Mac. Eine Regel, die in einer SwiftUI-Ansicht steht,
// lässt sich hier nicht ausprobieren, sondern nur behaupten. Deshalb
// steht alles Entscheidende in `Kadernameblock`, und die Ansicht
// zeichnet nur, was dort herauskommt -- dieselbe Entscheidung wie bei
// `Kachelblock` (R13) und `Vorratsblock` (R14).
//
// GEMESSEN WIRD AUCH DER WEG DAHIN: Die Auskunft entsteht hier aus
// echtem Server-JSON und nicht aus einem Init. Ein umbenanntes Feld
// fiele sonst erst auf dem Gerät auf -- und zwar als Namensfeld in
// einer Schulmannschaft, also genau dort, wo es niemand melden würde.

import XCTest
@testable import Routetree

final class KadernameblockTests: XCTestCase {

    private func auskunft(kuerzel: Bool? = nil,
                          kuerzelMax: Int? = nil,
                          vorschlag: String = "Lisa Meier")
        -> Modell.Codeauskunft {
        let kuerzelzeile = kuerzel.map { "\"kuerzel\": \($0)," } ?? ""
        let maxzeile = kuerzelMax.map { "\"kuerzel_max\": \($0)," } ?? ""
        let json = """
        {"team": {"id": 3, "name": "Flag AG", "verein": "Gymnasium"},
         "rolle_text": "Zuschauer", "schon_dabei": false,
         \(kuerzelzeile) \(maxzeile)
         "namensvorschlag": "\(vorschlag)"}
        """
        return try! JSONDecoder().decode(Modell.Codeauskunft.self,
                                         from: Data(json.utf8))
    }

    // --- Was der Server sagt, gilt ------------------------------------

    func testInEinerSchuleIstDasFeldFreiwillig() {
        let feld = Kadernameblock.feld(fuer: auskunft(kuerzel: true))
        XCTAssertFalse(feld.pflicht)
        XCTAssertEqual(feld.hoechstens, Kadernameblock.kuerzelMax)
    }

    func testSonstBleibtDerNamePflicht() {
        // A5 gilt weiter: Ein Kader ohne Namen ist eine Liste von
        // Benutzernamen.
        let feld = Kadernameblock.feld(fuer: auskunft(kuerzel: false))
        XCTAssertTrue(feld.pflicht)
    }

    func testOhneAngabeDesServersGiltDerBisherigeWeg() {
        // Eine ältere Fassung des Servers schickt das Feld nicht mit.
        // Die vorsichtige Richtung ist „Name": Ein Name zu viel ist ein
        // Ärgernis, ein Name zu wenig eine Mitgliedschaft, die der
        // Server ablehnt.
        let feld = Kadernameblock.feld(fuer: auskunft())
        XCTAssertTrue(feld.pflicht)
    }

    func testDieHoechstlaengeKommtVomServer() {
        // Und nicht aus der App: Eine Zahl an zwei Stellen ist eine
        // Zahl, die auseinanderläuft.
        let feld = Kadernameblock.feld(fuer: auskunft(kuerzel: true,
                                                      kuerzelMax: 4))
        XCTAssertEqual(feld.hoechstens, 4)
    }

    func testEineNullAlsHoechstlaengeSperrtDasFeldNicht() {
        // Ein Feld, in das kein Zeichen passt, wäre kein freiwilliges
        // Feld, sondern ein kaputtes.
        let feld = Kadernameblock.feld(fuer: auskunft(kuerzel: true,
                                                      kuerzelMax: 0))
        XCTAssertGreaterThanOrEqual(feld.hoechstens, 1)
    }

    // --- Die Vorbelegung ----------------------------------------------

    func testInEinerSchuleBleibtDasFeldLeer() {
        // Sonst stünde der volle Name aus dem Konto ausgefüllt da, und
        // wer nicht aufpasst, schickt ihn ab. Das wäre die Stelle, an
        // der die Namensfreiheit still aufhört.
        let feld = Kadernameblock.feld(fuer: auskunft(kuerzel: true))
        XCTAssertEqual(feld.vorbelegung, "")
    }

    func testSonstSchlaegtDerServerDenKontonamenVor() {
        let feld = Kadernameblock.feld(fuer: auskunft(kuerzel: false))
        XCTAssertEqual(feld.vorbelegung, "Lisa Meier")
    }

    // --- Wann der Knopf darf ------------------------------------------

    func testLeerGehtNurOhnePflicht() {
        let schule = Kadernameblock.feld(fuer: auskunft(kuerzel: true))
        let verein = Kadernameblock.feld(fuer: auskunft(kuerzel: false))
        XCTAssertTrue(Kadernameblock.darfAbsenden("", feld: schule))
        XCTAssertTrue(Kadernameblock.darfAbsenden("   ", feld: schule))
        XCTAssertFalse(Kadernameblock.darfAbsenden("", feld: verein))
    }

    func testEinKuerzelGeht() {
        let feld = Kadernameblock.feld(fuer: auskunft(kuerzel: true))
        XCTAssertTrue(Kadernameblock.darfAbsenden("LM", feld: feld))
        XCTAssertTrue(Kadernameblock.darfAbsenden("7", feld: feld))
    }

    func testEinGanzerNameGehtNicht() {
        // Die Grenze schützt nicht vor Namen -- „Tim" hat drei
        // Buchstaben. Sie sorgt dafür, dass das Feld nicht wie ein
        // Namensfeld aussieht. Und sie steht hier, damit der Knopf
        // nicht erst eine Absage vom Server holt.
        let feld = Kadernameblock.feld(fuer: auskunft(kuerzel: true))
        XCTAssertFalse(Kadernameblock.darfAbsenden("Lisa Meier", feld: feld))
        XCTAssertFalse(Kadernameblock.darfAbsenden("Lisa", feld: feld))
    }

    func testEinLangerNameGehtWeiterhinDurch() {
        // Im Verein ist das Feld ein Namensfeld, und „van der Berg"
        // hat Leerzeichen.
        let feld = Kadernameblock.feld(fuer: auskunft(kuerzel: false))
        XCTAssertTrue(Kadernameblock.darfAbsenden("Robin van der Berg",
                                                  feld: feld))
    }

    // --- Die Beschriftung ---------------------------------------------

    func testDieAufschriftenUnterscheidenSich() {
        // Zwei verschiedene Fragen dürfen nicht gleich heißen: „Dein
        // Name im Team" über einem Feld, das leer bleiben darf, ist die
        // Sorte Beschriftung, die niemand meldet und alle befolgen.
        let schule = Kadernameblock.feld(fuer: auskunft(kuerzel: true))
        let verein = Kadernameblock.feld(fuer: auskunft(kuerzel: false))
        XCTAssertNotEqual(schule.aufschrift, verein.aufschrift)
        XCTAssertNotEqual(schule.hilfe, verein.hilfe)
    }

    // --- Bevor der Server etwas gesagt hat (R24, Nachtrag) ------------

    func testOhneAuskunftGiltDerVorsichtigeFall() {
        // AUF DEM BLATT „KONTO ANLEGEN" steht das Feld schon da, bevor
        // ein Code vollständig getippt ist. Solange gilt „Name ist
        // Pflicht": Ein Name zu viel ist ein Ärgernis, ein Name zu
        // wenig eine Mitgliedschaft ohne Kadereintrag.
        let feld = Kadernameblock.feldOhneAuskunft
        XCTAssertTrue(feld.pflicht)
        XCTAssertFalse(Kadernameblock.darfAbsenden("", feld: feld))
    }

    func testOhneAuskunftGibtEsKeineVorbelegung() {
        // Es gibt noch kein Konto, aus dem ein Name käme. Eine
        // Vorbelegung wäre hier eine Erfindung.
        XCTAssertEqual(Kadernameblock.feldOhneAuskunft.vorbelegung, "")
    }

    func testOhneAuskunftSTEHTDASSELBEDaWieImVerein() {
        // Der Namensfall steht an EINER Stelle. Zwei Fassungen liefen
        // beim nächsten geänderten Satz auseinander, und dann zeigte
        // dasselbe Feld je nach Weg einen anderen Hilfetext -- genau
        // die Sorte Unterschied, die niemand meldet.
        let ohne = Kadernameblock.feldOhneAuskunft
        let verein = Kadernameblock.feld(fuer: auskunft(kuerzel: false))
        XCTAssertEqual(ohne.aufschrift, verein.aufschrift)
        XCTAssertEqual(ohne.hilfe, verein.hilfe)
        XCTAssertEqual(ohne.hoechstens, verein.hoechstens)
    }

    func testDieSchuleUnterscheidetSichAuchVomZustandOhneAuskunft() {
        // Sonst wäre die Prüfung darüber grün, weil ALLE drei Fälle
        // gleich aussehen -- und der Punkt von R24 wäre wieder weg.
        let ohne = Kadernameblock.feldOhneAuskunft
        let schule = Kadernameblock.feld(fuer: auskunft(kuerzel: true))
        XCTAssertNotEqual(ohne.aufschrift, schule.aufschrift)
        XCTAssertNotEqual(ohne.pflicht, schule.pflicht)
    }

    // --- Die Vorschau ohne Konto --------------------------------------

    func testDieVorschauAntwortDecodiertOhneKontofelder() {
        // WAS DER SERVER OHNE KONTO SCHICKT: kein `schon_dabei`, kein
        // `namensvorschlag` -- beides hängt an einem Konto, und auf
        // diesem Blatt gibt es keines. Fehlende Felder dürfen die
        // Auskunft nicht zerbrechen, sonst steht auf dem Blatt „Konto
        // anlegen" gar nichts.
        let json = """
        {"team": {"id": 3, "name": "Flag AG", "verein": "Gymnasium"},
         "rolle_text": "Zuschauer", "kuerzel": true, "kuerzel_max": 3}
        """
        let auskunft = try! JSONDecoder().decode(
            Modell.Codeauskunft.self, from: Data(json.utf8))
        XCTAssertFalse(auskunft.schonDabei)
        XCTAssertEqual(auskunft.namensvorschlag, "")
        XCTAssertTrue(auskunft.kuerzel)

        // UND DAS IST DER PUNKT: Aus genau dieser Antwort muss das
        // freiwillige Kürzelfeld werden.
        let feld = Kadernameblock.feld(fuer: auskunft)
        XCTAssertFalse(feld.pflicht)
        XCTAssertEqual(feld.vorbelegung, "")
    }
}
