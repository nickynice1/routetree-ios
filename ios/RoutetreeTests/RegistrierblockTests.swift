import XCTest
@testable import Routetree

/// Beanstandet die App genau das, was der Server beanstandet? (B12)
///
/// Seit B12 gibt es das Registrierformular zweimal: im Browser und in
/// der App. Beide beurteilen eine Eingabe, bevor jemand sie abschickt,
/// und genau diese Hälfte fällt still um.
///
/// Zwei Richtungen, beide teuer, keine davon sichtbar:
///
/// * Die App ist **strenger**. Sie weist eine gültige Eingabe ab, der
///   Server sieht die Anfrage nie, im Protokoll steht nichts. Der
///   Verein probiert es zweimal und hält das Produkt für kaputt.
/// * Die App **formuliert anders**. Derselbe Fehler heißt im Browser so
///   und in der App fast so. Das sieht nicht falsch aus, sondern nach
///   zwei Produkten.
///
/// Verglichen wird gegen `RegistrierProben.swift`. Was dort steht, hat
/// der SERVER gerechnet -- `backend/designer/registrierung.py`, dasselbe
/// Modul, das auch Djangos Formular begleitet.
final class RegistrierblockTests: XCTestCase {

    /// Die Längen so, wie sie der Server in der Auskunft schickt.
    private var laengen: [String: Int] {
        Dictionary(uniqueKeysWithValues:
            RegistrierProben.laengen.map { ($0.feld, $0.zeichen) })
    }

    // MARK: - Gleichstand mit dem Server

    func test_jede_probe_ergibt_denselben_satz() {
        XCTAssertFalse(RegistrierProben.faelle.isEmpty,
                       "Ohne Fälle misst diese Datei nichts.")
        for fall in RegistrierProben.faelle {
            XCTAssertEqual(
                Registrierblock.pruefen(feld: fall.feld,
                                        eingabe: fall.eingabe,
                                        laengen: laengen),
                fall.meldung,
                "Feld \(fall.feld), Eingabe „\(fall.eingabe.prefix(30))“")
        }
    }

    func test_jede_passwortprobe_ergibt_denselben_satz() {
        XCTAssertFalse(RegistrierProben.passwoerter.isEmpty)
        for fall in RegistrierProben.passwoerter {
            XCTAssertEqual(
                Registrierblock.passwort(fall.passwort,
                                         wiederholung: fall.wiederholung,
                                         mindestlaenge: fall.mindestlaenge),
                fall.meldung,
                "Passwort mit \(fall.passwort.count) Zeichen, "
                    + "Mindestlänge \(fall.mindestlaenge)")
        }
    }

    // MARK: - Die Regel selbst

    func test_leerraum_am_rand_ist_kein_fehler() {
        /// Der wunde Punkt, ausdrücklich und einzeln.
        ///
        /// Djangos Formularfelder schneiden Leerraum ab. Eine App, die
        /// „  jamie  " abweist, weist etwas ab, das der Server
        /// anstandslos genommen hätte -- und zwar an dem Feld, das
        /// jemand aus einer Nachricht einfügt.
        for (feld, eingabe) in [("verein", "  Rostock Griffins  "),
                                ("benutzername", "  jamie  "),
                                ("email", "  jamie@example.org  "),
                                ("mannschaft", "\tU17\n")] {
            XCTAssertEqual(
                Registrierblock.pruefen(feld: feld, eingabe: eingabe,
                                        laengen: laengen), "",
                "\(feld) hat über Leerraum am Rand gemeckert")
        }
    }

    func test_leerraum_mitten_im_benutzernamen_faellt_auf() {
        XCTAssertFalse(
            Registrierblock.pruefen(feld: "benutzername",
                                    eingabe: "Björn Müller",
                                    laengen: laengen).isEmpty)
        // Ein Umlaut allein ist KEIN Fehler: Djangos Regel erlaubt ihn,
        // und wer hier meckert, ist strenger als der Server.
        XCTAssertEqual(
            Registrierblock.pruefen(feld: "benutzername", eingabe: "Björn",
                                    laengen: laengen), "")
    }

    func test_ohne_bekannte_laenge_wird_die_laenge_nicht_geprueft() {
        /// Die sichere Richtung. Ein Feld, über das die App nichts weiß,
        /// ist eines, über das nur der Server entscheidet -- und ein
        /// geratenes Maximum wäre die Stelle, an der ein gültiger
        /// Vereinsname nie ankommt.
        XCTAssertEqual(
            Registrierblock.pruefen(feld: "verein",
                                    eingabe: String(repeating: "x",
                                                    count: 5000),
                                    laengen: [:]), "")
    }

    func test_ein_unbekanntes_feld_wird_durchgelassen() {
        XCTAssertEqual(
            Registrierblock.pruefen(feld: "lieblingsfarbe", eingabe: "",
                                    laengen: laengen), "")
    }

    func test_jedes_bekannte_feld_meckert_ueber_leer() {
        /// Fängt einen Tippfehler in der Verteilung.
        ///
        /// `pruefen` gibt für unbekannte Feldnamen `""` zurück, und das
        /// ist richtig. Es heißt aber auch: Ein Schreibfehler in einem
        /// `case` sieht aus wie „alles in Ordnung", und das Feld wird
        /// nie wieder geprüft. Beide Sätze für sich gelesen sind
        /// richtig; zusammen ergeben sie ein Formular, das schweigt.
        for feld in RegistrierProben.felder {
            XCTAssertFalse(
                Registrierblock.pruefen(feld: feld, eingabe: "",
                                        laengen: laengen).isEmpty,
                "Das Feld \(feld) kennt die Verteilung nicht mehr")
        }
    }

    func test_der_leerraum_ist_derselbe_wie_auf_dem_server() {
        XCTAssertEqual(Set(RegistrierProben.leerraum),
                       Registrierblock.leerraum)
    }

    func test_straffen_nimmt_nur_den_rand() {
        XCTAssertEqual(Registrierblock.straffen("  a b  "), "a b")
        XCTAssertEqual(Registrierblock.straffen("\u{A0}x\u{A0}"), "x")
        XCTAssertEqual(Registrierblock.straffen("   "), "")
        XCTAssertEqual(Registrierblock.straffen(""), "")
    }

    func test_der_satz_beim_leeren_namen_ist_der_des_browsers() {
        /// Er steht in `registrierung.py` und geht von dort als Probe
        /// nach Swift. Zwei Fassungen desselben Satzes wären zwei
        /// Produkte.
        let ausProbe = RegistrierProben.faelle.first {
            $0.feld == "name_im_team" && $0.eingabe.isEmpty
        }
        XCTAssertEqual(ausProbe?.meldung, Registrierblock.nameFehlt)
    }
}
