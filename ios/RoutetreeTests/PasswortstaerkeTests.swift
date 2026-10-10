// Der Passwort-Stärkebalken in der App (R110.10).
//
// WAS HIER GEMESSEN WIRD, IST EINE ZUSAGE. Der Balken prüft nicht noch
// einmal, sondern zeigt vorher an, was der Server gleich entscheidet.
// Sagt er „stark" und der Server lehnt danach ab, ist er schlimmer als
// keiner -- deshalb steht hier vor allem, was er NICHT durchgehen
// lässt.
//
// Der Browser hat ihn seit R108. Die Zahlen und die fünf Stände sind
// dieselben; wer beides benutzt, soll nicht zweimal etwas anderes
// lesen.

import XCTest
@testable import Routetree

final class PasswortstaerkeTests: XCTestCase {

    private let mindestens = 12

    private func stand(_ wort: String, umfeld: [String] = [])
        -> Passwortstaerke.Stand? {
        Passwortstaerke.bewerten(wort, mindestens: mindestens, umfeld: umfeld)
    }

    // MARK: - Über einem leeren Feld steht nichts

    func testLeerGibtGarNichts() {
        // Ein Balken, bevor jemand angefangen hat, sieht aus wie ein
        // Vorwurf.
        XCTAssertNil(stand(""))
    }

    // MARK: - Was der Server ablehnt

    func testZuKurzSagtWIEVIELFehlt() {
        // „Zu kurz" allein lässt einen zählen. Die Zahl steht da.
        let s = stand("abcDEF12")
        XCTAssertEqual(s?.stufe, .zuKurz)
        XCTAssertTrue(s?.wort.contains("4") ?? false, s?.wort ?? "")
    }

    func testNurZiffernReichtNichtEgalWieLang() {
        // Der `NumericPasswordValidator` lehnt sie unabhängig von der
        // Länge ab: „12345678901234" ist vierzehn Zeichen lang und
        // trotzdem raus.
        let s = stand("12345678901234")
        XCTAssertEqual(s?.stufe, .zuKurz)
        XCTAssertFalse(s?.stufe.reicht ?? true)
    }

    func testZuNahAmNamen() {
        let s = stand("niklas2026niklas", umfeld: ["niklas"])
        XCTAssertEqual(s?.stufe, .zuKurz)
    }

    func testKurzeUmfeldteileZaehlenNicht() {
        // Unter vier Zeichen wäre jedes zweite Passwort „zu nah am
        // Namen" -- ein Balken, der ständig falschen Alarm gibt, wird
        // ignoriert statt befolgt.
        XCTAssertNotEqual(stand("abcABC123!xyz", umfeld: ["abc"])?.stufe,
                          .zuKurz)
    }

    // MARK: - Und was er durchlässt

    func testEinBrauchbaresPasswortReicht() {
        let s = stand("Trainingslager")
        XCTAssertTrue(s?.stufe.reicht ?? false)
    }

    func testMehrEigenschaftenGebenMehrStriche() {
        let einfach = stand("trainingslager")
        let voll = stand("Trainingslager7!")
        XCTAssertNotNil(einfach)
        XCTAssertNotNil(voll)
        XCTAssertGreaterThan(voll!.stufe.rawValue, einfach!.stufe.rawValue)
    }

    func testUeberlaengeZaehltMit() {
        // GEMESSEN AN EINEM WORT, DAS NOCH LUFT NACH OBEN HAT. Mit
        // Grossbuchstabe, Ziffer und Zeichen sind die vier Striche
        // schon voll -- dort kann die Länge nichts mehr hinzufügen,
        // und der Vergleich prüfte nur die Obergrenze. Ein langes Wort
        // aus lauter Kleinbuchstaben ist der Fall, um den es geht --
        // und beide müssen über der Mindestlänge liegen, sonst
        // vergliche der Test „zu kurz" mit „geht so".
        let knapp = stand("trainingslager")        // 14 Zeichen
        let lang = stand("trainingslagerabcd")      // 18, also 12 + 6
        XCTAssertGreaterThan(lang!.stufe.rawValue, knapp!.stufe.rawValue)
    }

    func testDieStufeHatHoechstensVierStriche() {
        // Es sind vier Striche. Fünf Punkte dürfen nicht fünf Striche
        // werden -- der fünfte wäre einer, den es auf dem Bildschirm
        // nicht gibt.
        for wort in ["Trainings7!abcdefghij", "aA1!" + String(repeating: "x", count: 40)] {
            XCTAssertLessThanOrEqual(stand(wort)?.stufe.striche ?? 0, 4, wort)
        }
    }

    // MARK: - Die Mindestlänge kommt von aussen

    func testDieZahlWirdWIRKLICHBenutzt() {
        // DIE FALLE, GEGEN DIE DIESE ZEILE STEHT: eine getippte Acht.
        // Sie sagt „mindestens 8 Zeichen", während der Server zwölf
        // verlangt -- und dann macht der Balken die Zusage, die er
        // nicht halten kann.
        let wort = "abcDEFghi12"          // elf Zeichen
        XCTAssertEqual(
            Passwortstaerke.bewerten(wort, mindestens: 20)?.stufe, .zuKurz)
        XCTAssertNotEqual(
            Passwortstaerke.bewerten(wort, mindestens: 8)?.stufe, .zuKurz)
    }

    // MARK: - Die fünf Stände

    func testEsSindGenauFuenfUndInDieserReihenfolge() {
        XCTAssertEqual(Passwortstaerke.Stufe.allCases.map(\.rawValue),
                       [0, 1, 2, 3, 4])
        XCTAssertFalse(Passwortstaerke.Stufe.zuKurz.reicht)
        XCTAssertTrue(Passwortstaerke.Stufe.schwach.reicht)
    }
}
