// Der Stapel der Abo-Stufen -- gemessen ohne Bildschirm (R117).
//
// Es gibt keinen Mac. Eine Regel, die in einer SwiftUI-Ansicht steht,
// lässt sich hier nicht ausprobieren, sondern nur behaupten, und eine
// Rückmeldung vom Läufer dauert eine halbe Stunde. Deshalb steht alles
// Entscheidende in `Stufenblock`, und `StufenAnsicht` zeichnet nur, was
// dort herauskommt. Dieselbe Entscheidung wie bei `Kachelblock` (R13)
// und `Kaderblock` (B9).
//
// WAS HIER GEMESSEN WIRD, IST GELD. Zwei Fehler kosten hier sofort:
// „das hast du aktuell" unter der falschen Stufe verhindert einen Kauf,
// und ein Kaufknopf unter einer schon gekauften Stufe erzeugt eine
// zweite Abbuchung.

import XCTest
@testable import Routetree

final class StufenblockTests: XCTestCase {

    /// Über den Entschlüssler und nicht über einen Init: So wird
    /// nebenbei gemessen, dass die Feldnamen des Servers ankommen. Ein
    /// umbenanntes `apple_produkte` fiele sonst erst auf dem Gerät auf,
    /// und zwar als fehlender Kaufknopf.
    private func abo(demo: Bool, stufe: String? = nil,
                     mitProdukten: Bool = true,
                     vertrag: (String, String)? = nil) -> Modell.Abo {
        let produkte = mitProdukten ? """
            [{"stufe": "basis", "name": "Standard", "laufzeit": "monat",
              "produkt": "de.routetree.app.basis.monat",
              "betrag_text": "8,00 €", "geschenkt": null},
             {"stufe": "unbegrenzt", "name": "Premium", "laufzeit": "monat",
              "produkt": "de.routetree.app.unbegrenzt.monat",
              "betrag_text": "15,00 €", "geschenkt": null},
             {"stufe": "basis", "name": "Standard", "laufzeit": "jahr",
              "produkt": "de.routetree.app.basis.jahr",
              "betrag_text": "80,00 €", "geschenkt": 2},
             {"stufe": "unbegrenzt", "name": "Premium", "laufzeit": "jahr",
              "produkt": "de.routetree.app.unbegrenzt.jahr",
              "betrag_text": "150,00 €", "geschenkt": 2}]
            """ : "[]"
        let json = """
        {"demo": \(demo), "plaetze": 3, "waehrung": "EUR",
         "hinweis": "Wir schalten frei.", "kontakt": "", "betreff": "Abo",
         "preis_je_platz": null, "je_platz_text": null,
         "preis_grundgebuehr": null, "grundgebuehr_text": null,
         "plaetze_inklusive": 0, "modell": "stufen",
         "stufe": \(stufe.map { "\"\($0)\"" } ?? "null"),
         "preis_basis": 800, "preis_unbegrenzt": 1500,
         "basis_plaetze": 5, "basis_text": "8,00 €",
         "unbegrenzt_text": "15,00 €",
         "monatlich": 800, "monatlich_text": "8,00 €",
         "hebt_auf": [
            {"was": "Mannschaften",
             "werte": {"demo": "1", "basis": "beliebig viele",
                       "unbegrenzt": "beliebig viele"}},
            {"was": "Playbooks",
             "werte": {"demo": "1", "basis": "beliebig viele",
                       "unbegrenzt": "beliebig viele"}},
            {"was": "Trainer mit Schreibrecht",
             "werte": {"demo": "unbegrenzt", "basis": "bis zu 5",
                       "unbegrenzt": "unbegrenzt"}}],
         "apple_produkte": \(produkte),
         "vertrag": \(vertrag.map { "{\"stufe\": \"\($0.0)\", \"laufzeit\": \"\($0.1)\"}" } ?? "null")}
        """
        return try! JSONDecoder().decode(Modell.Abo.self,
                                         from: Data(json.utf8))
    }

    // MARK: - Demo gegen Abo (R119)

    func testGleicheWerteBekommenEINEspalte() {
        // Zwei Spalten mit demselben Wort sind auf einem Telefon zwei
        // Spalten zu viel -- und sie behaupten einen Unterschied, den
        // es nicht gibt.
        let zeilen = Stufenblock.vergleich(abo(demo: true))
        let mannschaften = zeilen.first { $0.was == "Mannschaften" }
        XCTAssertEqual(mannschaften?.demo, "1")
        XCTAssertEqual(mannschaften?.abo, "beliebig viele")
    }

    func testWoDieStufenSICHUNTERSCHEIDENstehenBeide() {
        // DER FALL AUS TESTFLIGHT. Unter „Standard" stand „unbegrenzt",
        // obwohl Standard bis zu fünf trägt -- und das ist die Zeile,
        // die den Unterschied der beiden Stufen ausmacht.
        let zeilen = Stufenblock.vergleich(abo(demo: true))
        let trainer = zeilen.first { $0.was == "Trainer mit Schreibrecht" }
        XCTAssertNil(trainer?.abo, "Eine gemeinsame Spalte wäre gelogen")
        XCTAssertEqual(trainer?.jeStufe.map(\.name), ["Standard", "Premium"])
        XCTAssertEqual(trainer?.jeStufe.map(\.wert),
                       ["bis zu 5", "unbegrenzt"])
    }

    func testJedeStufeStehtGENAUEINMALda() {
        // `kaufbareStufen` führt jede Stufe je Laufzeit auf (Monat und
        // Jahr). Zweimal „Standard" nebeneinander wäre eine Spalte, die
        // niemand erklären kann.
        let trainer = Stufenblock.vergleich(abo(demo: true))
            .first { $0.was == "Trainer mit Schreibrecht" }
        XCTAssertEqual(trainer?.jeStufe.count, 2)
    }

    func testOhneProdukteBleibenDieStufenTrotzdemStehen() {
        // Solange bei Apple nichts hinterlegt ist, kennt die App keine
        // Stufen -- die Gegenüberstellung soll dann trotzdem mehr
        // zeigen als die Demo-Spalte und daneben nichts.
        let zeilen = Stufenblock.vergleich(
            abo(demo: true, mitProdukten: false))
        let trainer = zeilen.first { $0.was == "Trainer mit Schreibrecht" }
        XCTAssertEqual(trainer?.jeStufe.map(\.wert),
                       ["bis zu 5", "unbegrenzt"])
    }

    // MARK: - Die Seiten

    func testDemoStehtVorn() {
        // Wer den Stapel aufmacht, steht in aller Regel auf der Demo.
        // Sie ist der Ausgangspunkt des Vergleichs.
        let seiten = Stufenblock.seiten(abo(demo: true))
        XCTAssertEqual(seiten.map(\.stufe),
                       ["demo", "basis", "unbegrenzt"])
    }

    func testDieReihenfolgeKommtVomServer() {
        // Hier wird NICHT nach Betrag sortiert: Der Server gibt die
        // Stufen nach dem Preis heraus, und eine zweite Sortierregel
        // liefe beim ersten Jahrespreis auseinander.
        let seiten = Stufenblock.seiten(abo(demo: true))
        XCTAssertEqual(seiten[1].produkt, "de.routetree.app.basis.monat")
        XCTAssertEqual(seiten[2].produkt, "de.routetree.app.unbegrenzt.monat")
    }

    func testOhneProdukteBleibtNurDieDemo() {
        // Kein Kaufknopf ist besser als einer, der ins Leere greift.
        let seiten = Stufenblock.seiten(abo(demo: true, mitProdukten: false))
        XCTAssertEqual(seiten.map(\.stufe), ["demo"])
    }

    func testDieDemoHatKeinProdukt() {
        let seiten = Stufenblock.seiten(abo(demo: true))
        XCTAssertNil(seiten[0].produkt)
    }

    // MARK: - „Das hast du aktuell"

    func testAufDemoStehtEsBeiDerDemo() {
        let seiten = Stufenblock.seiten(abo(demo: true))
        XCTAssertTrue(seiten[0].aktuell)
        XCTAssertFalse(seiten[1].aktuell)
        XCTAssertFalse(seiten[2].aktuell)
    }

    func testEinDemoVereinHatKEINEBasisstufe() {
        // DER FALL, DER EINEN KAUF VERHINDERT HÄTTE. `Abo.stufe` sagt
        // auch bei einem Demo-Verein „basis" -- das kommt aus dem
        // Preismodell und heisst „so würde gerechnet", nicht „das ist
        // gekauft". Stünde „das hast du aktuell" deshalb unter der
        // Standardstufe, kaufte sie niemand mehr.
        let seiten = Stufenblock.seiten(abo(demo: true, stufe: "basis"))
        XCTAssertTrue(seiten[0].aktuell, "Die Demo ist nicht als aktuell markiert")
        XCTAssertFalse(seiten[1].aktuell,
                       "Der Hinweis steht unter einer Stufe, die der "
                       + "Verein gar nicht gekauft hat")
    }

    func testMitAboStehtEsBeiDerGekauftenStufe() {
        let seiten = Stufenblock.seiten(
            abo(demo: false, stufe: "unbegrenzt",
                vertrag: ("unbegrenzt", "monat")))
        XCTAssertFalse(seiten[0].aktuell)
        XCTAssertFalse(seiten[1].aktuell)
        XCTAssertTrue(seiten[2].aktuell)
    }

    // DIESER TEST STAND BIS ZUM 18.09.2026 ANDERSHERUM DA.
    //
    // Er hiess `testMitAboStehtEsBeiDerGekauftenStufe` und gab dem Abo
    // KEINEN Vertrag: `demo: false, stufe: "unbegrenzt"` genuegte, und
    // erwartet wurde „das hast du aktuell" unter Premium. Damit hielt er
    // genau die Regel fest, die Niklas an diesem Tag auf dem Bildschirm
    // hatte -- sein Verein steht als `kunde` in der Tabelle, hat aber
    // keinen laufenden Vertrag, und unter „Standard" stand „Du bezahlst
    // diese Stufe bereits". Es gab nichts zu kaufen.
    //
    // Der Test war gruen und die Aussage falsch. Ein Waechter, der eine
    // ueberholte Wirklichkeit festhaelt, verteidigt den Fehler, statt
    // ihn zu melden: Wer die Regel richtigstellt, macht ihn rot und
    // nimmt an, er habe etwas kaputtgemacht.
    //
    // Der Vertrag steht jetzt im Aufbau, wo er hingehoert, und der Fall
    // ohne Vertrag hat einen eigenen Test bekommen.
    func testOhneVertragIstKeineBezahlteStufeAktuell() {
        // Der Fall von Niklas' Verein am 18.09.2026.
        let ohneVertrag = abo(demo: false, stufe: "basis")
        let seiten = Stufenblock.seiten(ohneVertrag)
        XCTAssertTrue(seiten[0].aktuell,
                      "Ohne Vertrag ist die Demo der aktuelle Stand")
        XCTAssertFalse(seiten[1].aktuell,
                       "„Du bezahlst diese Stufe bereits\" unter einer "
                       + "Stufe, fuer die kein Vertrag laeuft")
        XCTAssertFalse(seiten[2].aktuell)
    }

    func testOhneVertragSindBeideStufenZuHaben() {
        // Die Folge, auf die es ankommt: Wo „das hast du aktuell" steht,
        // steht kein Kaufknopf.
        let seiten = Stufenblock.seiten(abo(demo: false, stufe: "basis"))
        XCTAssertTrue(Stufenblock.kaufbar(
            seiten[1],
            bekannteProdukte: ["de.routetree.app.basis.monat"]))
        XCTAssertTrue(Stufenblock.kaufbar(
            seiten[2],
            bekannteProdukte: ["de.routetree.app.unbegrenzt.monat"]))
    }

    func testDieDemoSeiteFolgtDerselbenRegelWieDieAnderen() {
        // DER FEHLER VOM 18.09.2026, ALS TEST.
        //
        // `seiten()` rechnete den Stand der Demo-Seite selbst aus
        // (`abo.vertrag == nil && abo.demo`), statt `istAktuell` zu
        // fragen. Als `istAktuell` lernte, dass ohne Vertrag nichts
        // gekauft ist, zog die Demo-Seite nicht mit -- und der Verein
        // hatte NIRGENDS einen aktuellen Stand. Der Bau auf dem Laeufer
        // fiel darueber, eine halbe Stunde nach dem Abschicken.
        //
        // Zwei Regeln fuer dieselbe Frage laufen auseinander, sobald
        // eine davon dazulernt. Dieser Test haelt sie zusammen.
        let faelle: [(String, Modell.Abo)] = [
            ("ohne Vertrag", abo(demo: false, stufe: "basis")),
            ("auf Demo", abo(demo: true)),
            ("mit Vertrag", abo(demo: false, stufe: "basis",
                                vertrag: ("basis", "monat"))),
            ("Demo mit Vertrag", abo(demo: true,
                                     vertrag: ("basis", "monat"))),
        ]
        for (was, vorschlag) in faelle {
            XCTAssertEqual(
                Stufenblock.seiten(vorschlag)[0].aktuell,
                Stufenblock.istAktuell(Stufenblock.demo, laut: vorschlag),
                "Die Demo-Seite rechnet wieder selbst (\(was))")
        }
    }

    func testEinAeltererServerBehaeltDieAlteRegel() {
        // FEHLT DAS FELD GANZ, laesst sich „kein Vertrag" nicht von
        // „der Server kennt das Feld nicht" unterscheiden. Dann gilt
        // weiter die Platzzahl -- eine schlechtere Auskunft als der
        // Vertrag, aber die einzige, die es dort gibt.
        //
        // `mitProdukten: false` taugt dafuer NICHT: Das schickt eine
        // leere Liste, und eine leere Liste ist eine Aussage. Nur der
        // fehlende Schluessel heisst „aelterer Server".
        let json = """
        {"demo": false, "plaetze": 3, "waehrung": "EUR",
         "hinweis": "", "kontakt": "", "betreff": "",
         "preis_je_platz": null, "je_platz_text": null,
         "preis_grundgebuehr": null, "grundgebuehr_text": null,
         "plaetze_inklusive": 0, "modell": "stufen",
         "stufe": "unbegrenzt",
         "preis_basis": null, "preis_unbegrenzt": null,
         "basis_plaetze": null, "basis_text": null,
         "unbegrenzt_text": null, "monatlich": null,
         "monatlich_text": null, "hebt_auf": []}
        """
        guard let alterServer = try? JSONDecoder().decode(
            Modell.Abo.self, from: Data(json.utf8)) else {
            return XCTFail("Der Vorschlag liess sich nicht lesen")
        }
        XCTAssertNil(alterServer.appleProdukte,
                     "Der Aufbau taugt nicht als aelterer Server")
        XCTAssertTrue(
            Stufenblock.istAktuell("unbegrenzt", laut: alterServer))
    }

    // MARK: - Was darunter steht

    func testUnterDerDemoStehtWasDieDemoKann() {
        let seiten = Stufenblock.seiten(abo(demo: true))
        XCTAssertEqual(seiten[0].leistungen.map(\.wert),
                       ["1", "1", "unbegrenzt"])
    }

    func testUnterEinerStufeStehtWasDIESEStufeKann() {
        let seiten = Stufenblock.seiten(abo(demo: true))
        XCTAssertEqual(seiten[1].leistungen.map(\.wert),
                       ["beliebig viele", "beliebig viele", "bis zu 5"])
    }

    /// DER FUND VOM 10.09.2026, als Test.
    ///
    /// Niklas in TestFlight: „Beim Standard Abo ist dir wohl ein Fehler
    /// unterlaufen, da stimmen die Details nicht." Unter „Standard"
    /// stand die Spalte „Mit Abo" -- dieselbe wie unter „Premium". Die
    /// eine Zeile, in der sich die beiden unterscheiden, war damit
    /// unter Standard falsch: Standard trägt fünf Trainer mit
    /// Schreibrecht, nicht beliebig viele.
    func testStandardUndPremiumSagenNichtDasselbe() {
        let seiten = Stufenblock.seiten(abo(demo: true))
        XCTAssertNotEqual(seiten[1].leistungen.map(\.wert),
                          seiten[2].leistungen.map(\.wert))
        XCTAssertEqual(seiten[2].leistungen.map(\.wert),
                       ["beliebig viele", "beliebig viele", "unbegrenzt"])
    }

    func testDieZeilenBleibenInDerReihenfolgeDesServers() {
        let seiten = Stufenblock.seiten(abo(demo: true))
        XCTAssertEqual(seiten[0].leistungen.map(\.was),
                       ["Mannschaften", "Playbooks",
                        "Trainer mit Schreibrecht"])
    }

    /// Eine Zeile, die für DIESE Stufe nichts sagt, fällt weg.
    ///
    /// Ein älterer Server, der eine Stufe nicht kennt, ergibt eine
    /// kürzere Liste -- und nicht eine Zeile mit dem Wert einer
    /// anderen Stufe darunter. Genau das war der Fehler.
    func testEineZeileOhneWertFuerDieseStufeFaelltWeg() {
        let zeile = Modell.Abozeile(was: "Nur fuer Premium",
                                    werte: ["unbegrenzt": "ja"])
        XCTAssertNil(zeile.wert(fuer: "basis"))
        XCTAssertEqual(zeile.wert(fuer: "unbegrenzt"), "ja")
    }

    // MARK: - Wie die Stufen heissen

    /// Der Name kommt vom Server, damit Browser, App und Apples
    /// Abrechnung dasselbe Wort benutzen.
    func testDerNameKommtVomServer() {
        let seiten = Stufenblock.seiten(abo(demo: true))
        XCTAssertEqual(seiten[1].name, "Standard")
        XCTAssertEqual(seiten[2].name, "Premium")
        XCTAssertNil(seiten[0].name)
    }

    // MARK: - Wo gekauft werden darf

    func testDieDemoLaesstSichNichtKaufen() {
        let seiten = Stufenblock.seiten(abo(demo: true))
        XCTAssertFalse(Stufenblock.kaufbar(
            seiten[0], bekannteProdukte: ["de.routetree.app.basis.monat"]))
    }

    func testEineStufeIstKaufbarWennAppleSieKennt() {
        let seiten = Stufenblock.seiten(abo(demo: true))
        XCTAssertTrue(Stufenblock.kaufbar(
            seiten[1], bekannteProdukte: ["de.routetree.app.basis.monat"]))
    }

    func testOhneAntwortVonAppleKeinKnopf() {
        // Solange StoreKit lädt oder nicht antwortet, steht dort ein
        // Satz und keine Schaltfläche.
        let seiten = Stufenblock.seiten(abo(demo: true))
        XCTAssertFalse(Stufenblock.kaufbar(seiten[1], bekannteProdukte: []))
    }

    func testWasManHatWirdNichtNochmalGekauft() {
        // Ein zweites Abo derselben Stufe wäre eine zweite Abbuchung.
        //
        // DER VERTRAG STEHT SEIT DEM 18.09.2026 IM AUFBAU. Vorher
        // genuegte `stufe: "basis"`, und genau das war die Falle: Ein
        // Verein OHNE Vertrag hat nichts gekauft, auch wenn die
        // Platzzahl in die Basis faellt. Der Test hielt die falsche
        // Regel fest und war dabei gruen.
        let seiten = Stufenblock.seiten(
            abo(demo: false, stufe: "basis",
                vertrag: ("basis", "monat")))
        XCTAssertFalse(Stufenblock.kaufbar(
            seiten[1], bekannteProdukte: ["de.routetree.app.basis.monat"]))
        XCTAssertTrue(Stufenblock.kaufbar(
            seiten[2],
            bekannteProdukte: ["de.routetree.app.unbegrenzt.monat"]))
    }

    // MARK: - Wo der Stapel aufgeht

    func testDerStapelBeginntBeiDerEigenenStufe() {
        // Wer schon zahlt, sucht nicht die Demo, sondern das, was die
        // nächste Stufe mehr kann. „Wer schon zahlt" heisst: mit
        // Vertrag -- ohne ihn zahlt niemand, egal was die Platzzahl
        // sagt.
        let seiten = Stufenblock.seiten(
            abo(demo: false, stufe: "unbegrenzt",
                vertrag: ("unbegrenzt", "monat")))
        XCTAssertEqual(Stufenblock.anfangsseite(seiten), "unbegrenzt")
    }

    func testAufDemoBeginntErBeiDerDemo() {
        let seiten = Stufenblock.seiten(abo(demo: true))
        XCTAssertEqual(Stufenblock.anfangsseite(seiten), "demo")
    }

    func testOhneSeitenGibtEsKeineAnfangsseite() {
        XCTAssertNil(Stufenblock.anfangsseite([]))
    }

    // MARK: - Monat oder Jahr (R118)

    // GEMESSEN AM PRODUKT und nicht mehr am Preistext: Der Preis der
    // Karte kommt seit R122 nur noch von StoreKit. Welche Laufzeit
    // gemeint ist, sagt die Produktkennung genauso eindeutig -- und
    // sie ist es, an der Apple den Betrag festmacht.
    func testOhneAngabeStehenDieMonatsprodukte() {
        let seiten = Stufenblock.seiten(abo(demo: true))
        XCTAssertEqual(seiten.map(\.produkt),
                       [nil, "de.routetree.app.basis.monat",
                        "de.routetree.app.unbegrenzt.monat"])
    }

    func testMitJahrStehenDieJahresprodukte() {
        let seiten = Stufenblock.seiten(abo(demo: true),
                                        laufzeit: Stufenblock.jahr)
        XCTAssertEqual(seiten.map(\.produkt),
                       [nil, "de.routetree.app.basis.jahr",
                        "de.routetree.app.unbegrenzt.jahr"])
    }

    // MARK: - Preis und Steuer (R122)

    func testDerPreisKommtNURvonStoreKit() {
        // Der Servertext war der Rückfall und ist weg: Auf einem Gerät
        // im US-Store stand erst „8,00 €" und danach „$7.00".
        let seite = Stufenblock.seiten(abo(demo: true))[1]
        XCTAssertEqual(Stufenblock.preistext(seite, ausStoreKit: "$7.00"),
                       "$7.00")
        XCTAssertNil(Stufenblock.preistext(seite, ausStoreKit: nil))
    }

    func testOhneProduktStehtNIEeinPreis() {
        // Die Demo hat kein Produkt. Selbst wenn StoreKit etwas
        // hergäbe, gehörte es nicht unter „Kostenlos, mit Grenzen".
        let demo = Stufenblock.seiten(abo(demo: true))[0]
        XCTAssertNil(Stufenblock.preistext(demo, ausStoreKit: "$7.00"))
    }

    func testDerSteuerhinweisGiltNURimDeutschenStore() {
        // „19 % Umsatzsteuer" ist deutsches Recht. Niklas hat den Satz
        // in TestFlight unter „$7.00" gesehen.
        XCTAssertTrue(Stufenblock.steuerhinweisZeigen(storefront: "DEU"))
        XCTAssertFalse(Stufenblock.steuerhinweisZeigen(storefront: "USA"))
        XCTAssertFalse(Stufenblock.steuerhinweisZeigen(storefront: "AUT"))
    }

    func testOhneBekanntenStoreStehtKEINsteuersatz() {
        // Lieber keine Angabe als eine falsche.
        XCTAssertFalse(Stufenblock.steuerhinweisZeigen(storefront: nil))
    }

    func testDieGeschenktenMonateKommenMit() {
        // „Zwei Monate geschenkt" versteht ein Vorstand ohne zu
        // rechnen, „16,7 % Nachlass" nicht.
        let seiten = Stufenblock.seiten(abo(demo: true),
                                        laufzeit: Stufenblock.jahr)
        XCTAssertEqual(seiten[1].geschenkt, 2)
        XCTAssertNil(Stufenblock.seiten(abo(demo: true))[1].geschenkt)
    }

    func testBeideLaufzeitenWerdenAngeboten() {
        XCTAssertEqual(Stufenblock.laufzeiten(abo(demo: true)),
                       ["monat", "jahr"])
    }

    func testOhneJahresproduktGibtEsNurDenMonat() {
        // Solange bei Apple kein Jahresprodukt angelegt ist, soll kein
        // Umschalter erscheinen -- er fuehrte auf eine leere Seite.
        let json = """
        {"demo": true, "plaetze": 0, "waehrung": "EUR", "hinweis": "",
         "kontakt": "", "betreff": "", "preis_je_platz": null,
         "je_platz_text": null, "preis_grundgebuehr": null,
         "grundgebuehr_text": null, "plaetze_inklusive": 0,
         "modell": "stufen", "stufe": null, "preis_basis": 800,
         "preis_unbegrenzt": 1500, "basis_plaetze": 5,
         "basis_text": "8,00 €", "unbegrenzt_text": "15,00 €",
         "monatlich": 800, "monatlich_text": "8,00 €", "hebt_auf": [],
         "apple_produkte": [{"stufe": "basis", "laufzeit": "monat",
                             "produkt": "p", "betrag_text": "8,00 €",
                             "geschenkt": null}],
         "vertrag": null}
        """
        let nurMonat = try! JSONDecoder().decode(
            Modell.Abo.self, from: Data(json.utf8))
        XCTAssertEqual(Stufenblock.laufzeiten(nurMonat), ["monat"])
    }

    // MARK: - Was wirklich gekauft ist

    func testDerVertragSchlaegtDieRechnung() {
        // DER FALL, DER EINEN WECHSEL VERHINDERT HAETTE. `abo.stufe`
        // kommt aus der Platzzahl und sagt nicht, was gekauft wurde.
        // Wer monatlich zahlt, muss auf der Jahresseite kaufen koennen
        // -- dort darf nicht „das hast du aktuell" stehen.
        let monatskunde = abo(demo: false, stufe: "basis",
                              vertrag: ("basis", "monat"))
        let imMonat = Stufenblock.seiten(monatskunde)
        XCTAssertTrue(imMonat[1].aktuell)

        let imJahr = Stufenblock.seiten(monatskunde,
                                        laufzeit: Stufenblock.jahr)
        XCTAssertFalse(imJahr[1].aktuell,
                       "Der Monatskunde kann nicht auf Jahreszahlung "
                       + "wechseln")
        XCTAssertTrue(Stufenblock.kaufbar(
            imJahr[1], bekannteProdukte: ["de.routetree.app.basis.jahr"]))
    }

    func testDerJahreskundeSiehtEsAufDerJahresseite() {
        let jahreskunde = abo(demo: false, stufe: "basis",
                              vertrag: ("unbegrenzt", "jahr"))
        let imJahr = Stufenblock.seiten(jahreskunde,
                                        laufzeit: Stufenblock.jahr)
        XCTAssertTrue(imJahr[2].aktuell)
        XCTAssertFalse(imJahr[1].aktuell)
    }

    func testMitVertragIstDieDemoNichtMehrAktuell() {
        // Sonst stuende „das hast du aktuell" bei der Demo UND bei der
        // gekauften Stufe.
        let kunde = abo(demo: true, vertrag: ("basis", "monat"))
        XCTAssertFalse(Stufenblock.seiten(kunde)[0].aktuell)
        XCTAssertTrue(Stufenblock.seiten(kunde)[1].aktuell)
    }

    // MARK: - Ein älterer Server

    func testEinServerOhneDasFeldBrichtNichts() {
        // Eine App im Store spricht mit dem Server, der gerade läuft --
        // auch mit einem älteren. Wäre `apple_produkte` verpflichtend,
        // bräche dort das Entschlüsseln des GANZEN Vorschlags, und der
        // Verein sähe statt eines fehlenden Kaufknopfes gar nichts mehr.
        let json = """
        {"demo": true, "plaetze": 0, "waehrung": "EUR",
         "hinweis": "", "kontakt": "", "betreff": "",
         "preis_je_platz": null, "je_platz_text": null,
         "preis_grundgebuehr": null, "grundgebuehr_text": null,
         "plaetze_inklusive": 0, "modell": "stufen", "stufe": null,
         "preis_basis": null, "preis_unbegrenzt": null,
         "basis_plaetze": null, "basis_text": null,
         "unbegrenzt_text": null, "monatlich": null,
         "monatlich_text": null, "hebt_auf": []}
        """
        let alt = try? JSONDecoder().decode(Modell.Abo.self,
                                            from: Data(json.utf8))
        XCTAssertNotNil(alt, "Ein älterer Server macht den Vorschlag unlesbar")
        XCTAssertEqual(alt?.kaufbareStufen.count, 0)
        XCTAssertEqual(Stufenblock.seiten(alt!).map(\.stufe), ["demo"])
    }
}
