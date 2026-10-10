import XCTest
@testable import Routetree

/// Fragt die App denselben Ausdruck an wie der Browser? (B10)
///
/// **Warum das die eigentliche Frage ist.** Seit B10 gibt es die
/// Druckseite zweimal: im Browser und in der App. Beide stellen dieselbe
/// Anfrage an denselben Server, und beide bauen die Einstellungen selbst
/// zusammen. Läuft das auseinander, entsteht kein Fehler, den jemand
/// sieht, sondern ein Ausdruck, der einfach anders ist:
///
/// * Ein Armband, das 127 statt 125 Millimeter breit gedruckt wird, sieht
///   aus wie ein schlecht sitzendes Armband. Zwölf davon werden
///   ausgeschnitten, bevor es auffällt.
/// * Zwölf Einlagen, von denen der Server nur acht setzt, sehen aus wie
///   ein Bogen, der halt so voll ist.
/// * Eine Kartenzahl, die es nicht gibt, wird stillschweigend zu vier.
///   Wer neun bestellt hat, zählt nicht nach.
///
/// Deshalb steht hier kein selbst ausgedachtes Ergebnis. Die Adressen in
/// `DruckProben` hat der SERVER gebaut (`backend/designer/druck.py`,
/// dieselben Zahlen, mit denen `printing.py` die Seite setzt).
final class DruckTests: XCTestCase {

    // --- Die Proben vom Server -------------------------------------------

    /// EINE SCHLEIFE ÜBER NULL FÄLLE IST GRÜN. Dieselbe Lehre wie in
    /// `OrdnenTests`: Eine leere Probendatei misst nichts und meldet es
    /// nicht.
    func testEsGibtUeberhauptProben() {
        XCTAssertGreaterThanOrEqual(
            DruckProben.faelle.count, 15,
            "Die Probendatei ist leer oder geschrumpft. "
            + "Neu erzeugen: ./scripts/druck_swift.py")
        XCTAssertGreaterThanOrEqual(DruckProben.masse.count, 8)
    }

    /// Jede Art aus `Druckwahl` kommt in den Proben auch wirklich vor.
    ///
    /// Ohne das wäre eine neue Ausgabe zwar in der Liste, aber ungeprüft
    /// -- und ausgerechnet die neue ist die, deren Adresse noch niemand
    /// gesehen hat.
    func testJedeAusgabeIstInDenProben() {
        let geprueft = Set(DruckProben.faelle.map(\.art))
        for ausgabe in Druckwahl.ausgaben + Druckwahl.playAusgaben {
            XCTAssertTrue(
                geprueft.contains(ausgabe.art),
                "Für „\(ausgabe.art)“ gibt es keine Probe. "
                + "Neu erzeugen: ./scripts/druck_swift.py")
        }
    }

    func testDieAppBautDieselbeAdresseWieDerServer() {
        for fall in DruckProben.faelle {
            XCTAssertEqual(
                wunsch(fall).weg(kennung: DruckProben.kennung), fall.adresse,
                "Andere Adresse als der Server bei „\(fall.art)“.")
        }
    }

    func testDieAppNenntDieDateiWieDerServer() {
        for fall in DruckProben.faelle {
            XCTAssertEqual(
                Druckblock.dateiname(art: fall.art, stamm: DruckProben.stamm),
                fall.dateiname,
                "Anderer Dateiname als der Server bei „\(fall.art)“.")
        }
    }

    func testDieAppLoestDieEinlagemasseWieDerServerAuf() {
        for probe in DruckProben.masse {
            let ergebnis = Druckblock.einlagemass(
                groesse: probe.groesse.isEmpty ? nil : probe.groesse,
                breite: probe.breite, hoehe: probe.hoehe)
            XCTAssertEqual(ergebnis.breite, probe.istBreite, accuracy: 0.001)
            XCTAssertEqual(ergebnis.hoehe, probe.istHoehe, accuracy: 0.001)
            XCTAssertEqual(ergebnis.groesse, probe.istGroesse)
            XCTAssertEqual(ergebnis.label, probe.label)
        }
    }

    // --- Die Stellen, an denen es still schiefgeht ------------------------

    /// **Kein Feld darf durchfallen.**
    ///
    /// `Druckwunsch.paare` läuft über `felder` und hat für Unbekanntes
    /// ein `default: break`. Genau das ist der stille Fall: Der Server
    /// bekommt eine neue Einstellung, die erzeugte Liste trägt sie, und
    /// die App lässt sie weg. Gedruckt wird dann etwas Richtiges, nur
    /// nicht das Bestellte.
    ///
    /// Gemessen wird mit einer gesetzten Seite, denn `seite` ist das
    /// einzige Feld, das leer WEGFALLEN darf.
    func testJedesFeldLandetInDerAdresse() {
        for ausgabe in Druckwahl.ausgaben + Druckwahl.playAusgaben {
            var wunsch = Druckwunsch(art: ausgabe.art)
            wunsch.seite = "offense"
            XCTAssertGreaterThanOrEqual(
                wunsch.paare.count, ausgabe.felder.count,
                "„\(ausgabe.art)“ hat \(ausgabe.felder.count) Felder, aber "
                + "nur \(wunsch.paare.count) landen in der Adresse. Eines "
                + "davon kennt `Druckwunsch.paare` nicht.")
        }
    }

    /// Die Reihenfolge in der Adresse ist die von `felder`.
    ///
    /// Für den Server ist sie gleichgültig. Für diesen Vergleich nicht:
    /// Eine Ordnung, die sich beim nächsten Übersetzen ändert, ergibt
    /// ein rotes Testergebnis ohne einen Fehler dahinter, und nach dem
    /// zweiten Mal sieht niemand mehr hin.
    func testDieSeiteFaelltNurWegWennSieLeerIst() {
        var wunsch = Druckwunsch(art: "playcards")
        XCTAssertFalse(wunsch.paare.contains { $0.0 == "seite" })
        wunsch.seite = "defense"
        XCTAssertEqual(wunsch.paare.last?.0, "seite")
        XCTAssertEqual(wunsch.paare.last?.1, "defense")
    }

    /// Ein freies Maß schickt Breite und Höhe STATT der Größe.
    ///
    /// Beides zu schicken hieße, dem Server dieselbe Frage zweimal zu
    /// stellen. Er nähme dann das freie Maß, aber der Adresse sähe man
    /// den Widerspruch nicht an.
    func testFreiesMassErsetztDieGroesse() {
        var wunsch = Druckwunsch(art: "wristband")
        wunsch.groesse = Druckwahl.groesseFrei
        wunsch.breite = 110
        wunsch.hoehe = 64.5
        let namen = wunsch.paare.map { $0.0 }
        XCTAssertFalse(namen.contains("groesse"))
        XCTAssertTrue(namen.contains("breite"))
        XCTAssertTrue(namen.contains("hoehe"))
    }

    /// Ein frei getipptes Maß, das zufällig eine Größe trifft, HEISST so.
    ///
    /// Sonst stünde auf dem Bogen „Eigenes Maß" und im Formular
    /// „Eigenes Maß", während der Server „Jugend" druckt.
    func testEinGetroffenesMassBekommtSeinenNamen() {
        let ergebnis = Druckblock.einlagemass(breite: 95, hoehe: 60)
        XCTAssertEqual(ergebnis.groesse, "jugend")
        XCTAssertNotEqual(ergebnis.label, Druckwahl.freiLabel)
    }

    func testUnsinnFaelltAufDieVoreinstellungZurueck() {
        XCTAssertEqual(Druckblock.kartenZahl(7), Druckwahl.kartenStandard)
        XCTAssertEqual(Druckblock.spaltenZahl(5), Druckwahl.spaltenStandard)
        XCTAssertEqual(Druckblock.stil("bunt"), Druckwahl.stilStandard)
        XCTAssertEqual(Druckblock.einlagemass(groesse: "riesig").groesse,
                       Druckwahl.groesseStandard)
    }

    func testDieGrenzenSindDieDesServers() {
        XCTAssertEqual(Druckblock.kopien(20), Druckwahl.kopienMax)
        XCTAssertEqual(Druckblock.kopien(0), Druckwahl.kopienMin)
        XCTAssertEqual(Druckblock.bildbreite(0), Druckwahl.bildBreiteMin)
        XCTAssertEqual(Druckblock.bildbreite(99999), Druckwahl.bildBreiteMax)
        XCTAssertEqual(Druckblock.einlagemass(breite: 1, hoehe: 9999).breite,
                       Druckwahl.breiteMin)
        XCTAssertEqual(Druckblock.einlagemass(breite: 1, hoehe: 9999).hoehe,
                       Druckwahl.hoeheMax)
    }

    /// `125.0` und `125` sind dasselbe Maß und zwei Adressen.
    func testMassSchreibtSichOhneNachlaufendeNull() {
        XCTAssertEqual(Druckblock.mass(125), "125")
        XCTAssertEqual(Druckblock.mass(125.0), "125")
        XCTAssertEqual(Druckblock.mass(95.5), "95.5")
        XCTAssertEqual(Druckblock.mass(64.5), "64.5")
        XCTAssertEqual(Druckblock.mass(40), "40")
    }

    /// Ein Archiv voller SVG lässt sich teilen, aber nicht drucken.
    func testNurWasSichDruckenLaesstHeisstDruckbar() {
        XCTAssertTrue(Druckblock.druckbar("playcards"))
        XCTAssertTrue(Druckblock.druckbar("callsheet"))
        XCTAssertTrue(Druckblock.druckbar("wristband"))
        XCTAssertTrue(Druckblock.druckbar("blatt"))
        XCTAssertFalse(Druckblock.druckbar("bilder"))
        XCTAssertFalse(Druckblock.druckbar("bild"))
        // Und was es nicht gibt, ist erst recht nicht druckbar.
        XCTAssertFalse(Druckblock.druckbar("poster"))
    }

    /// Ein Play liegt unter `/plays/`, ein Heft unter `/playbooks/`.
    ///
    /// Verwechselt heißt es nicht „falsche Adresse", sondern „gibt es
    /// nicht" -- dieselbe Antwort wie bei einem fremden Playbook, und
    /// damit die, die man am längsten falsch deutet.
    func testJedeArtLiegtAufIhremStamm() {
        XCTAssertTrue(Druckwunsch(art: "playcards").weg(kennung: 3)
            .hasPrefix("/api/v1/playbooks/3/druck/playcards/"))
        XCTAssertTrue(Druckwunsch(art: "blatt").weg(kennung: 3)
            .hasPrefix("/api/v1/plays/3/druck/blatt/"))
    }

    // --- Der Dateiname des Servers ---------------------------------------

    func testDateinameAusDemKopfWirdGelesen() {
        XCTAssertEqual(
            Druckblock.dateinameAusKopf(
                "attachment; filename=\"u17-playcards.pdf\""),
            "u17-playcards.pdf")
        XCTAssertEqual(
            Druckblock.dateinameAusKopf("inline; filename=u17.pdf"),
            "u17.pdf")
        XCTAssertNil(Druckblock.dateinameAusKopf("attachment"))
        XCTAssertNil(Druckblock.dateinameAusKopf(nil))
    }

    /// **Der Name wird gleich zu einem Pfad.**
    ///
    /// Der eigene Server schickt so etwas nicht. Diese Stelle ist aber
    /// die einzige, an der es auffiele, und sie kostet drei Zeilen.
    /// Abgewiesen wird ganz, nicht gekürzt: Ein Name, aus dem etwas
    /// herausgeschnitten wurde, sieht danach richtig aus.
    func testEinNameMitPfadWirdAbgewiesenUndNichtGekuerzt() {
        XCTAssertNil(Druckblock.dateinameAusKopf(
            "attachment; filename=\"../../geheim.pdf\""))
        XCTAssertNil(Druckblock.unbedenklich("a/b.pdf"))
        XCTAssertNil(Druckblock.unbedenklich("a\\b.pdf"))
        XCTAssertNil(Druckblock.unbedenklich(".."))
        XCTAssertNil(Druckblock.unbedenklich("   "))
        XCTAssertNil(Druckblock.unbedenklich(
            String(repeating: "x", count: 200) + ".pdf"))
        XCTAssertEqual(Druckblock.unbedenklich(" u17.pdf "), "u17.pdf")
    }

    /// Ohne Namen vom Server fällt die App auf einen eigenen zurück.
    // MARK: - Was auf einer Einlage steht (R124)

    func testDasHeftWirdGETEILTwieAufDemServer() {
        // Acht je Einlage aus neun Plays sind zwei Zuschnitte -- der
        // zweite mit einem einzigen Play.
        let teile = Druckblock.einlagenTeilen(Array(1...9), jeEinlage: 8)
        XCTAssertEqual(teile, [Array(1...8), [9]])
    }

    func testNullHeisstALLEaufEINE() {
        XCTAssertEqual(Druckblock.einlagenTeilen(Array(1...9), jeEinlage: 0),
                       [Array(1...9)])
    }

    func testEinLeeresHeftGibtTROTZDEMeineEinlage() {
        // Ein Bogen ohne einen einzigen Zuschnitt sähe aus wie ein
        // Fehler des Druckers -- dabei ist es ein Heft ohne Plays.
        XCTAssertEqual(Druckblock.einlagenTeilen([Int](), jeEinlage: 8),
                       [[]])
    }

    func testUntereinanderIstIMMEReineSpalte() {
        XCTAssertEqual(
            Druckblock.einlagenSpalten(posten: 15, anordnung: "spalte"), 1)
    }

    func testImRasterErstAbZEHNpostenZWEIspalten() {
        // Dieselbe Schwelle wie `printing._wristband_liste`: Zwei
        // Spalten mit je vier Zeilen sind am Handgelenk schlechter zu
        // lesen als acht untereinander.
        XCTAssertEqual(
            Druckblock.einlagenSpalten(posten: 9, anordnung: "raster"), 1)
        XCTAssertEqual(
            Druckblock.einlagenSpalten(posten: 10, anordnung: "raster"), 2)
    }

    func testUnsinnBeiDerAnordnungFaelltAufDasRasterZurueck() {
        XCTAssertEqual(
            Druckblock.einlagenSpalten(posten: 12, anordnung: "quer"), 2)
    }

    func testOhneStammEntstehtTrotzdemEinName() {
        XCTAssertEqual(Druckblock.dateiname(art: "playcards", stamm: ""),
                       "routetree-playcards.pdf")
    }

    // --- Hilfsmittel ------------------------------------------------------

    private func wunsch(_ fall: DruckProben.Fall) -> Druckwunsch {
        var heraus = Druckwunsch(art: fall.art)
        heraus.proSeite = fall.proSeite
        heraus.spalten = fall.spalten
        heraus.groesse = fall.groesse
        heraus.breite = fall.breite
        heraus.hoehe = fall.hoehe
        heraus.kopien = fall.kopien
        heraus.stil = fall.stil
        heraus.jeEinlage = fall.jeEinlage
        heraus.anordnung = fall.anordnung
        heraus.kartenfuss = fall.kartenfuss
        heraus.jeBlock = fall.jeBlock
        heraus.diagramme = fall.diagramme
        heraus.zoom = fall.zoom
        heraus.zeichenstil = fall.zeichenstil
        heraus.bildbreite = fall.bildbreite
        heraus.logo = fall.logo
        heraus.sw = fall.sw
        heraus.seite = fall.seite
        return heraus
    }
}
