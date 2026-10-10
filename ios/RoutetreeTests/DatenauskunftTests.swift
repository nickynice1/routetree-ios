// Auskunft und Mitnahme (R110.9, Art. 15 und 20 DSGVO).
//
// WAS HIER GEMESSEN WIRD, IST EIN RECHT. Die App konnte das Konto
// löschen und sonst nichts mit den eigenen Daten anfangen -- in ihr
// stand also genau der Weg zur Verfügung, nach dem die Daten weg sind,
// und keiner von den beiden davor.
//
// Der Netzweg selbst wird hier NICHT gemessen: Dafür bräuchte es einen
// Server. Gemessen wird, was ohne einen geht und was schiefgehen kann,
// ohne dass es auffällt -- die Ablage.

import XCTest
@testable import Routetree

final class DatenauskunftTests: XCTestCase {

    // MARK: - Der Dateiname

    func testDerNameTraegtDasDatum() {
        // Man holt sie mehrmals. Ohne Datum lägen drei Dateien
        // gleichen Namens im Ordner.
        let tag = Date(timeIntervalSince1970: 1_788_000_000)
        let name = Datenauskunft.dateiname(am: tag)
        XCTAssertTrue(name.hasPrefix("routetree-auskunft-"), name)
        XCTAssertTrue(name.hasSuffix(".json"), name)
    }

    func testDerNameHaengtNichtAnDerSprache() {
        // Ein Datum im deutschen Format enthält Punkte, und ein
        // Dateiname mit Punkten wird an der falschen Stelle geteilt.
        // Deshalb steht das Format fest.
        let tag = Date(timeIntervalSince1970: 1_788_000_000)
        let name = Datenauskunft.dateiname(am: tag)
        XCTAssertEqual(name.filter { $0 == "." }.count, 1, name)
    }

    // MARK: - Die Ablage

    func testSieWirdLesbarEingerueckt() throws {
        // Eine Auskunft ist zum Lesen da, und eine einzige Zeile JSON
        // liest niemand.
        let eng = Data(#"{"b":1,"a":2}"#.utf8)
        let ziel = try Datenauskunft.ablegen(eng, name: "probe-eingerueckt.json")
        defer { try? FileManager.default.removeItem(at: ziel) }
        let text = try String(contentsOf: ziel, encoding: .utf8)
        XCTAssertTrue(text.contains("\n"), text)
    }

    func testUnlesbaresGehtUNVERAENDERT_HINAUS() throws {
        // DER FALL, DER SONST STILL VERSCHWINDET. Kommt statt der
        // Auskunft eine Störseite zurück, ist die Datei die einzige
        // Spur davon. Sie wegzuwerfen, weil sie kein JSON ist, hiesse:
        // Der Mensch bekommt eine leere Datei und keine Erklärung.
        let roh = Data("<html>Wartungsarbeiten</html>".utf8)
        let ziel = try Datenauskunft.ablegen(roh, name: "probe-roh.json")
        defer { try? FileManager.default.removeItem(at: ziel) }
        XCTAssertEqual(try Data(contentsOf: ziel), roh)
    }

    func testSieLiegtImZwischenspeicherUndNichtInDokumenten() throws {
        // In „Dokumente" bliebe eine vollständige Auskunft über die
        // Person dauerhaft auf dem Gerät liegen -- und zwar
        // unverschlüsselt in jeder Sicherung.
        let ziel = try Datenauskunft.ablegen(Data("{}".utf8),
                                             name: "probe-ort.json")
        defer { try? FileManager.default.removeItem(at: ziel) }
        XCTAssertEqual(ziel.deletingLastPathComponent().standardizedFileURL,
                       FileManager.default.temporaryDirectory
                           .standardizedFileURL)
    }

    func testDerInhaltBleibtDerDesServers() throws {
        // Die App entscheidet NICHT mit, was in der Auskunft steht.
        // Ein Swift-Modell dazwischen wäre eine zweite Liste dessen,
        // was als personenbezogen gilt -- und ein Feld, das die App
        // nicht kennt, verschwände daraus, ohne dass es jemandem
        // auffällt.
        let herein = Data(#"{"unbekanntes_feld":"bleibt drin"}"#.utf8)
        let ziel = try Datenauskunft.ablegen(herein, name: "probe-treu.json")
        defer { try? FileManager.default.removeItem(at: ziel) }
        let text = try String(contentsOf: ziel, encoding: .utf8)
        XCTAssertTrue(text.contains("unbekanntes_feld"), text)
        XCTAssertTrue(text.contains("bleibt drin"), text)
    }

    // MARK: - Zwei Auskünfte am selben Tag

    func testZweimalAmSelbenTagOeffnetDasBlattZweimal() {
        // `sheet(item:)` verlangt `Identifiable`. Haengt die Kennung an
        // der ADRESSE, ist es beim zweiten Mal am selben Tag dieselbe --
        // und das Blatt geht nicht auf.
        let gleich = URL(fileURLWithPath: "/tmp/routetree-auskunft-2026-09-10.json")
        XCTAssertNotEqual(Auskunftsdatei(url: gleich).id,
                          Auskunftsdatei(url: gleich).id)
    }
}
