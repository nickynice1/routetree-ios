// Ohne Netz am Platz -- gemessen ohne Bildschirm (R14).
//
// Der Auftrag kommt aus der Marktanalyse (25.08.2026), ein Trainer über
// einen Wettbewerber, 1 Stern im App Store:
//
//   „Sie sagt, ich hätte kein Internet. App gelöscht, neu geladen, WLAN
//   aus und wieder an -- kommt trotzdem nicht rein, und ich habe gutes
//   Internet."
//
// Es gibt keinen Mac. Alles, was sich entscheiden lässt, steht deshalb
// in `Vorratsblock` und wird hier gemessen; `Vorrat` fasst die Platte
// an und wird hier ebenfalls gefahren -- der Läufer hat ein Dateisystem.
// Was NICHT hier steht: dass die Ansichten es benutzen. Das misst
// `backend/designer/test_vorrat.py`.

import XCTest
@testable import Routetree

final class VorratsblockTests: XCTestCase {

    // MARK: - Was abgelegt werden darf

    func testDieWegeDesAnsehensDuerfenAufDasGeraet() {
        for weg in ["/api/v1/playbooks/",
                    "/api/v1/playbooks/12/plays/",
                    "/api/v1/playbooks/12/kategorien/",
                    "/api/v1/plays/7/",
                    "/api/v1/plays/7/?svg=1"] {
            XCTAssertTrue(Vorratsblock.gehoertInDenVorrat(weg), weg)
        }
    }

    /// **Schlüssel sind kein Inhalt.** Das Tablet im Vereinsheim reicht
    /// von Hand zu Hand; Teamcode, Einladungen und Maschinenschlüssel
    /// haben darauf nichts verloren. Und was der Server über Grenzen,
    /// Preise und den Lernstand sagt, ist nichts, was am Platz gelesen
    /// wird.
    func testAllesAndereBleibtAufDemServer() {
        for weg in ["/api/v1/teams/",
                    "/api/v1/teams/3/",
                    "/api/v1/auth/token/",
                    "/api/v1/auth/refresh/",
                    "/api/v1/playbooks/12/uebung/",
                    "/api/v1/playbooks/12/lernstand/",
                    "/api/v1/playbooks/12/formationen/",
                    "/api/v1/playbooks/12/bibliothek/",
                    "/api/v1/vereine/",
                    "/api/v1/abo/",
                    "/api/v1/plays/7/sperre/",
                    "/api/v2/playbooks/",
                    "/medien/logos/g.png",
                    ""] {
            XCTAssertFalse(Vorratsblock.gehoertInDenVorrat(weg), weg)
        }
    }

    /// Der Weg, unter dem die App den Play HOLT, muss auch der sein,
    /// den sie ablegen darf. Sonst ist der Vorrat voll und trotzdem
    /// leer -- und zwar lautlos.
    func testDieWegeDerAppSindDieselbenWieDieErlaubten() {
        XCTAssertTrue(Vorratsblock.gehoertInDenVorrat(
            Vorratsblock.wegFuerPlay(7)))
        XCTAssertTrue(Vorratsblock.gehoertInDenVorrat(
            Vorratsblock.wegFuerPlayliste(12)))
        XCTAssertTrue(Vorratsblock.gehoertInDenVorrat(
            Vorratsblock.wegFuerKategorien(12)))
        XCTAssertTrue(Vorratsblock.gehoertInDenVorrat(
            Vorratsblock.wegFuerHefte))
    }

    // MARK: - Wie es auf dem Gerät heißt

    /// Zwei Wege, die sich nur in einem Zeichen unterscheiden, das der
    /// lesbare Teil wegkürzt. Ohne den Streuwert hießen sie gleich --
    /// und ein Play zeigte die Zeichnung eines anderen.
    func testZweiWegeMitDemselbenLesbarenTeilHeissenTrotzdemAnders() {
        let einer = Vorratsblock.dateiname(fuer: "/api/v1/a/b")
        let anderer = Vorratsblock.dateiname(fuer: "/api/v1/a-b")
        XCTAssertNotEqual(einer, anderer)
    }

    func testDerNameIstBeiJedemAufrufDerselbe() {
        let weg = Vorratsblock.wegFuerPlay(7)
        XCTAssertEqual(Vorratsblock.dateiname(fuer: weg),
                       Vorratsblock.dateiname(fuer: weg))
        XCTAssertTrue(Vorratsblock.dateiname(fuer: weg).hasSuffix(".json"))
    }

    /// Der Streuwert steht fest -- **nicht `hashValue`**. Swift salzt
    /// den je Programmstart neu; ein Vorrat, dessen Dateien beim
    /// nächsten Start anders heißen, ist kein Vorrat, sondern Müll auf
    /// der Platte.
    func testDerStreuwertHaengtNichtAmProgrammstart() {
        XCTAssertEqual(Vorratsblock.streuwert("/api/v1/plays/7/?svg=1"),
                       "d35eabb8a96aaada")
        XCTAssertEqual(Vorratsblock.streuwert("/api/v1/playbooks/"),
                       "ecc9757f75088f86")
    }

    func testKeinSchraegstrichImDateinamen() {
        let name = Vorratsblock.dateiname(fuer: "/api/v1/plays/7/?svg=1")
        XCTAssertFalse(name.contains("/"), name)
        XCTAssertFalse(name.contains("?"), name)
    }

    // MARK: - Wann der Vorrat einspringt

    func testOhneNetzSpringtErEin() {
        XCTAssertTrue(Vorratsblock.ausDemVorrat(
            bei: Server.Fehler.netz(URLError(.notConnectedToInternet))))
        XCTAssertTrue(Vorratsblock.ausDemVorrat(
            bei: Server.Fehler.netz(URLError(.timedOut))))
    }

    /// Die vier Fälle, in denen er es NICHT tut -- und jeder aus einem
    /// eigenen Grund:
    ///
    /// * **401**: Wer daraufhin die letzte Kopie zeigte, zeigte einem
    ///   Menschen Plays, die ihm gerade weggenommen wurden.
    /// * **403**: dasselbe in klein, an der Grenze der Demo.
    /// * **429**: Der Server ist sehr wohl erreichbar.
    /// * **500**: Etwas ist kaputt. Wer das hinter einer Kopie von
    ///   gestern versteckt, merkt es nie.
    func testSonstSpringtErNichtEin() {
        let fehler: [Error] = [
            Server.Fehler.abgemeldet,
            Server.Fehler.gebremst(sekunden: 30),
            Server.Fehler.server(text: "Die Demo ist am Ende.", lage: 403,
                                 rumpf: nil),
            Server.Fehler.server(text: "Serverfehler.", lage: 500,
                                 rumpf: nil),
        ]
        for einer in fehler {
            XCTAssertFalse(Vorratsblock.ausDemVorrat(bei: einer),
                           "\(einer)")
        }
    }

    /// Ein `URLError`, der NICHT durch `Server` gelaufen ist, zählt
    /// nicht. Sonst reichte irgendein Fehler mit passendem Namen, um
    /// eine alte Kopie hervorzuholen.
    func testEinFremderFehlerZaehltNicht() {
        XCTAssertFalse(Vorratsblock.ausDemVorrat(
            bei: URLError(.notConnectedToInternet)))
    }

    // MARK: - Wie alt die Kopie ist

    private var kalender: Calendar {
        var eigener = Calendar(identifier: .gregorian)
        eigener.timeZone = TimeZone(identifier: "Europe/Berlin")!
        return eigener
    }

    private func zeit(_ tag: Int, _ stunde: Int) -> Date {
        kalender.date(from: DateComponents(
            timeZone: TimeZone(identifier: "Europe/Berlin"),
            year: 2026, month: 8, day: tag, hour: stunde))!
    }

    func testHeuteGesternUndAelter() {
        let jetzt = zeit(26, 19)
        XCTAssertEqual(Vorratsblock.naehe(zeit(26, 7), jetzt: jetzt,
                                          kalender: kalender), .heute)
        XCTAssertEqual(Vorratsblock.naehe(zeit(25, 23), jetzt: jetzt,
                                          kalender: kalender), .gestern)
        XCTAssertEqual(Vorratsblock.naehe(zeit(24, 23), jetzt: jetzt,
                                          kalender: kalender), .aelter)
    }

    /// „Heute" ist der KALENDERTAG und nicht „vor weniger als 24
    /// Stunden". Um 00:30 wäre eine Kopie von 23:00 sonst „heute", und
    /// sie ist von gestern.
    func testUmMitternachtWirdAusHeuteGestern() {
        XCTAssertEqual(
            Vorratsblock.naehe(zeit(25, 23), jetzt: zeit(26, 0),
                               kalender: kalender), .gestern)
    }

    // MARK: - Was noch fehlt

    private func play(_ id: Int, version: Int) -> Modell.PlayKurz {
        Modell.PlayKurz(id: id, name: "Slant \(id)", nummer: id,
                        position: id, version: version)
    }

    func testOhneKopieMussAllesGeholtWerden() {
        let plays = [play(1, version: 3), play(2, version: 1)]
        XCTAssertEqual(Vorratsblock.nachzuladen(plays, marken: [:]), [1, 2])
    }

    func testWasSchonDaIstUndPasstWirdNichtNochmalGeholt() {
        let plays = [play(1, version: 3), play(2, version: 1)]
        let marken = [1: Vorratsblock.marke(version: 3),
                      2: Vorratsblock.marke(version: 1)]
        XCTAssertEqual(Vorratsblock.nachzuladen(plays, marken: marken), [])
    }

    /// Der Fall, für den die Marke überhaupt da ist: Die Kopie liegt
    /// da, aber jemand hat den Play inzwischen geändert.
    func testEineAeltereFassungWirdNachgeholt() {
        let plays = [play(1, version: 4), play(2, version: 1)]
        let marken = [1: Vorratsblock.marke(version: 3),
                      2: Vorratsblock.marke(version: 1)]
        XCTAssertEqual(Vorratsblock.nachzuladen(plays, marken: marken), [1])
    }

    // MARK: - Woher ein Wert stammt

    func testAusgabeSagtWoherSieKommt() {
        XCTAssertFalse(Vorratsblock.Ausgabe(wert: 1, stand: nil)
                           .ausDemVorrat)
        XCTAssertTrue(Vorratsblock.Ausgabe(wert: 1, stand: Date())
                          .ausDemVorrat)
    }
}

// MARK: - Die Platte

/// `Vorrat` fasst Dateien an. Das lässt sich hier ausnahmsweise fahren
/// und nicht nur lesen: Der Läufer hat ein Dateisystem, und der
/// Testbehälter bekommt sein eigenes `Application Support`.
final class VorratTests: XCTestCase {

    override func setUp() {
        super.setUp()
        Vorrat.leeren()
    }

    override func tearDown() {
        Vorrat.leeren()
        super.tearDown()
    }

    private let weg = "/api/v1/plays/7/?svg=1"
    /// Ganze Sekunden: Abgelegt wird nach ISO-8601, und das kennt keine
    /// Bruchteile. Ein Vergleich mit `Date()` fiele daran um, und zwar
    /// nur manchmal.
    private let stand = Date(timeIntervalSince1970: 1_756_000_000)

    func testAbgelegtesKommtUnveraendertZurueck() {
        let rumpf = Data(#"{"id": 7, "svg": "<svg/>"}"#.utf8)
        Vorrat.merken(rumpf, fuer: weg, marke: "v3", jetzt: stand)

        let eintrag = Vorrat.holen(fuer: weg)
        XCTAssertEqual(eintrag?.rumpf, rumpf)
        XCTAssertEqual(eintrag?.marke, "v3")
        XCTAssertEqual(eintrag?.stand, stand)
    }

    func testWasNichtAbgelegtIstFehlt() {
        XCTAssertNil(Vorrat.holen(fuer: weg))
        XCTAssertNil(Vorrat.marke(fuer: weg))
    }

    func testZweiWegeKommenSichNichtInsGehege() {
        Vorrat.merken(Data("eins".utf8), fuer: weg, marke: "v1",
                      jetzt: stand)
        Vorrat.merken(Data("zwei".utf8),
                      fuer: Vorratsblock.wegFuerPlay(8), marke: "v1",
                      jetzt: stand)
        XCTAssertEqual(Vorrat.holen(fuer: weg)?.rumpf, Data("eins".utf8))
        XCTAssertEqual(
            Vorrat.holen(fuer: Vorratsblock.wegFuerPlay(8))?.rumpf,
            Data("zwei".utf8))
    }

    func testEineNeueKopieErsetztDieAlte() {
        Vorrat.merken(Data("alt".utf8), fuer: weg, marke: "v1",
                      jetzt: stand)
        Vorrat.merken(Data("neu".utf8), fuer: weg, marke: "v2",
                      jetzt: stand)
        XCTAssertEqual(Vorrat.holen(fuer: weg)?.rumpf, Data("neu".utf8))
        XCTAssertEqual(Vorrat.marke(fuer: weg), "v2")
    }

    /// **Die Bedingung dafür, dass es den Vorrat überhaupt geben
    /// darf.** Wer sich abmeldet und das Tablet weitergibt, hat seine
    /// Plays nicht mehr darauf.
    func testAbmeldenLaesstNichtsLiegen() {
        Vorrat.merken(Data("geheim".utf8), fuer: weg, marke: "v1",
                      jetzt: stand)
        Vorrat.leeren()
        XCTAssertNil(Vorrat.holen(fuer: weg))
    }

    /// Nach dem Leeren muss sich wieder ablegen lassen. Sonst wäre die
    /// App nach einem Abmelden dauerhaft ohne Vorrat -- und niemand
    /// wüsste, warum.
    func testNachDemLeerenGehtEsWeiter() {
        Vorrat.leeren()
        Vorrat.merken(Data("wieder".utf8), fuer: weg, marke: "v1",
                      jetzt: stand)
        XCTAssertEqual(Vorrat.holen(fuer: weg)?.rumpf, Data("wieder".utf8))
    }
}
