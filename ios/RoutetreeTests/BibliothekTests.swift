import XCTest
@testable import Routetree

/// Die Bibliothek in der App (B11).
///
/// Zwei Dinge werden hier gemessen, und beide fallen sonst still um:
///
/// 1. **Entziffert die App, was der Server schickt?** Die Proben in
///    `BibliothekProben.swift` sind nicht getippt, sondern erzeugt --
///    `scripts/bibliothek_swift.py` lässt den Server antworten, und
///    `backend/designer/test_bibliothek_swift.py` misst diese Antwort
///    gegen eine echte Anfrage. Ein Schlüssel, der auf der Leitung
///    anders heißt als in Swift, ergibt keine Fehlermeldung, sondern
///    eine leere Liste auf dem Gerät.
/// 2. **Entscheidet der Block richtig?** Reihenfolge, Anhaken und die
///    Sätze zur Grenze stehen in `Bibliotheksblock` und nicht in der
///    Ansicht -- es gibt keinen Mac, auf dem sich das ausprobieren
///    ließe.
final class BibliothekTests: XCTestCase {

    private func lesen(_ json: String) throws -> Modell.Bibliothek {
        try Server.entschluessler.decode(Modell.Bibliothek.self,
                                         from: Data(json.utf8))
    }

    // MARK: - Was der Server schickt

    func test_die_antwort_des_servers_wird_gelesen() throws {
        let b = try lesen(BibliothekProben.antwort)
        XCTAssertEqual(b.eintraege.count, BibliothekProben.anzahl)
        XCTAssertNil(b.playsFrei, "Ohne Grenze steht dort nichts")
    }

    func test_jeder_eintrag_hat_eine_zeichnung() throws {
        // DER GANZE PUNKT VON B11. Eine Liste aus Namen wäre wertlos:
        // „Snag" sagt niemandem etwas, der es nicht schon kennt. Eine
        // Zeichnung mit null Spielern sähe in der Liste wie ein leeres
        // Feld aus -- also wie ein Ladefehler und nicht wie ein Fehler
        // im Format.
        let b = try lesen(BibliothekProben.antwort)
        for eintrag in b.eintraege {
            XCTAssertGreaterThanOrEqual(eintrag.zeichnung.spieler.count, 5,
                                        eintrag.schluessel)
            XCTAssertFalse(eintrag.zeichnung.linien.isEmpty,
                           eintrag.schluessel)
            XCTAssertFalse(eintrag.hinweis.isEmpty, eintrag.schluessel)
            XCTAssertFalse(eintrag.name.isEmpty, eintrag.schluessel)
        }
    }

    func test_das_feldformat_kommt_mit() throws {
        // Ohne es zeichnete die Vorschau auf einem Normfeld, auch wenn
        // das Playbook ein kleines hat -- und die Aufstellung stünde
        // neben der Seitenlinie, ohne dass etwas nach einem Fehler
        // aussieht.
        let b = try lesen(BibliothekProben.antwort)
        XCTAssertEqual(b.feld, Feld.afvd)
    }

    func test_schon_da_und_die_grenze_werden_gelesen() throws {
        // Der wunde Punkt: Im Regelfall stehen beide Felder auf `false`
        // und `nil`. Eine App, die sie gar nicht liest, sähe dort
        // zufällig richtig aus.
        let b = try lesen(BibliothekProben.antwortMitGrenze)
        XCTAssertEqual(b.playsFrei, 2)
        let drin = b.eintraege.filter(\.schonDa)
        XCTAssertEqual(drin.count, 1)
        // ÜBER DEN SCHLÜSSEL, NICHT ÜBER DEN NAMEN. `schon_da` geht
        // seit dem 30.09.2026 über `aus_bibliothek`, damit ein
        // Bestandsplay mit dem alten deutschen Namen weiter als „schon
        // im Heft" erkannt wird.
        XCTAssertEqual(drin.first?.schluessel,
                       BibliothekProben.erstesKonzeptSchluessel)
    }

    func test_ein_eintrag_ohne_zeichnung_wirft_nicht() throws {
        // Eine Antwort wird auf EINMAL entziffert: Fiele ein Eintrag
        // aus, fehlte nicht er, sondern die ganze Liste. Lieber ein
        // leeres Feld in der Vorschau als ein leerer Bildschirm.
        let json = """
        {"eintraege":[{"schluessel":"x","name":"Ohne","kategorie":null,
        "hinweis":null,"situationen":null,"schon_da":null}],
        "feld":null,"plays_frei":null}
        """
        let b = try lesen(json)
        XCTAssertEqual(b.eintraege.count, 1)
        XCTAssertTrue(b.eintraege[0].zeichnung.spieler.isEmpty)
        XCTAssertEqual(b.feld, Feld.afvd, "Ohne Angabe das Normfeld")
    }

    func test_das_ergebnis_des_uebernehmens_wird_gelesen() throws {
        let json = """
        {"angelegt":[{"id":7,"name":"Spread Mesh","nummer":null,
        "seite":null,"kategorie":"Short Pass","situationen":[]}],
        "uebergangen":3,"plays_frei":0}
        """
        let ergebnis = try Server.entschluessler.decode(
            Modell.Uebernommen.self, from: Data(json.utf8))
        XCTAssertEqual(ergebnis.angelegt.count, 1)
        XCTAssertEqual(ergebnis.uebergangen, 3)
        XCTAssertEqual(ergebnis.playsFrei, 0)
    }

    // MARK: - Was die App entscheidet

    func test_anhaken_und_wieder_abhaken() {
        var gewaehlt = Bibliotheksblock.umschalten("mesh", in: [])
        XCTAssertEqual(gewaehlt, ["mesh"])
        gewaehlt = Bibliotheksblock.umschalten("flood", in: gewaehlt)
        XCTAssertEqual(gewaehlt, ["mesh", "flood"])
        gewaehlt = Bibliotheksblock.umschalten("mesh", in: gewaehlt)
        XCTAssertEqual(gewaehlt, ["flood"], "Der zweite Tipp nimmt zurück")
    }

    func test_uebernommen_wird_in_der_reihenfolge_der_liste() throws {
        // DIE ENTSCHEIDUNG. `Set` hat keine Reihenfolge; wer es einfach
        // durchgeht, schickt bei jedem Lauf eine andere Folge. Der
        // Server vergibt Platz und Nummer genau danach -- im Heft stünde
        // jedes Mal etwas anderes, ohne dass ein Schritt falsch aussieht.
        let b = try lesen(BibliothekProben.antwort)
        let letzte = b.eintraege[b.eintraege.count - 1].schluessel
        let erste = b.eintraege[0].schluessel

        // Angehakt in umgekehrter Folge.
        var gewaehlt = Bibliotheksblock.umschalten(letzte, in: [])
        gewaehlt = Bibliotheksblock.umschalten(erste, in: gewaehlt)

        XCTAssertEqual(
            Bibliotheksblock.reihenfolge(gewaehlt: gewaehlt,
                                         eintraege: b.eintraege),
            [erste, letzte])
    }

    func test_was_die_liste_nicht_mehr_kennt_faellt_weg() throws {
        // Sonst schickt die App einen Schlüssel, den der Server mit
        // „Diese Konzepte gibt es nicht" ablehnt -- und dann ist auch
        // der Rest der Auswahl nicht angelegt.
        let b = try lesen(BibliothekProben.antwort)
        let reihe = Bibliotheksblock.reihenfolge(
            gewaehlt: [b.eintraege[0].schluessel, "gibtsnicht"],
            eintraege: b.eintraege)
        XCTAssertEqual(reihe, [b.eintraege[0].schluessel])
    }

    func test_ohne_grenze_steht_kein_satz_da() {
        // „Unbegrenzt frei" wäre eine Zeile, die niemand braucht, an der
        // auffälligsten Stelle.
        XCTAssertNil(Bibliotheksblock.freiText(nil))
    }

    func test_die_grenze_steht_da_bevor_jemand_anhakt() {
        XCTAssertEqual(Bibliotheksblock.freiText(0),
                       "In dieses Playbook passt nichts mehr hinein.")
        XCTAssertEqual(Bibliotheksblock.freiText(1),
                       "Noch 1 Play frei in diesem Playbook.")
        XCTAssertEqual(Bibliotheksblock.freiText(3),
                       "Noch 3 Plays frei in diesem Playbook.")
    }

    func test_der_teilerfolg_steht_vorn() {
        // Wer gerade drei Plays bekommen hat, will sie sehen und nicht
        // ein Angebot. Steht die Grenze vorn, liest er die Meldung als
        // Absage und sucht die drei gar nicht erst.
        let satz = Bibliotheksblock.ergebnisText(angelegt: 3, uebergangen: 5)
        XCTAssertTrue(satz.hasPrefix("3 Plays übernommen."), satz)
        XCTAssertTrue(satz.contains("5 weitere passen nicht mehr hinein"),
                      satz)
    }

    func test_ohne_uebergangene_steht_nur_der_erfolg_da() {
        XCTAssertEqual(Bibliotheksblock.ergebnisText(angelegt: 1,
                                                     uebergangen: 0),
                       "1 Play übernommen.")
        XCTAssertTrue(Bibliotheksblock.vollstaendig(angelegt: 1,
                                                    uebergangen: 0))
        XCTAssertFalse(Bibliotheksblock.vollstaendig(angelegt: 1,
                                                     uebergangen: 2))
    }

    func test_die_einzahl_stimmt() {
        // „1 Plays übernommen" ist die Art Satz, die eine App billig
        // aussehen lässt, und sie steht in jeder zweiten.
        XCTAssertTrue(Bibliotheksblock
            .ergebnisText(angelegt: 2, uebergangen: 1)
            .contains("1 weiterer passt nicht mehr hinein"))
    }
}
