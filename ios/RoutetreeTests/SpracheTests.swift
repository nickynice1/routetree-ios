import XCTest
@testable import Routetree

/// Kommen die Übersetzungen wirklich im Bündel an? (R22)
///
/// **Warum das eine eigene Prüfung braucht.** Zwischen einem
/// übersetzten Satz in `uebersetzungen/app_*.json` und übersetztem Text
/// auf dem Bildschirm liegen vier Stellen, an denen es scheitern kann,
/// und an KEINER davon wird etwas rot:
///
/// 1. Der Schlüssel im Katalog passt nicht zu dem, den Swift bildet
///    (ein `%@` statt `%lld`).
/// 2. Die `.lproj`-Ordner landen nicht im Bündel.
/// 3. Xcode kennt die Sprache nicht (`knownRegions`).
/// 4. `String(localized:)` steht gar nicht an der Stelle.
///
/// In allen vier Fällen zeigt die App den Schlüssel an -- also den
/// deutschen Satz. Das sieht aus wie eine App, die eben Deutsch spricht,
/// und nicht wie ein Fehler. Genau deshalb wird hier nachgesehen.
final class SpracheTests: XCTestCase {

    private var buendel: Bundle { Bundle(for: Anmeldung.self) }

    /// Ein Satz, der in allen fünf Sprachen verschieden lautet. Er ist
    /// mit Absicht kurz und kommt ohne Platzhalter aus: Diese Prüfung
    /// soll die KETTE messen und nicht die Formatierung.
    private let probe = "Abbrechen"

    func test_das_buendel_traegt_alle_fuenf_sprachen() {
        let da = Set(buendel.localizations)
        for sprache in ["de", "en", "es", "fr", "it"] {
            XCTAssertTrue(
                da.contains(sprache),
                "Im Bündel fehlt „\(sprache)“. Gefunden: \(da.sorted()). "
                + "Entweder liegt ios/Routetree/\(sprache).lproj nicht im "
                + "Projekt, oder XcodeGen hat die Region nicht erkannt.")
        }
    }

    func test_die_pruefungen_laufen_auf_deutsch() {
        // Die Proben aus Python stehen auf Deutsch. Läuft der Simulator
        // auf Englisch, vergleicht die halbe Testsuite „Eigenes Maß“ mit
        // „Custom size“ -- und die Ursache sieht aus wie ein Fehler in
        // der Übersetzung, ist aber eine Zeile in project.yml.
        XCTAssertEqual(
            Bundle.main.preferredLocalizations.first, "de",
            "Der Testlauf steht nicht auf Deutsch. In ios/project.yml "
            + "gehört unter schemes.Routetree.test: language: de.")
    }

    func test_ein_satz_kommt_uebersetzt_heraus() {
        // Nicht über `String(localized:)`, sondern über das Bündel der
        // jeweiligen Sprache: So misst diese Prüfung den Katalog und
        // nicht die Sprache, auf der der Läufer gerade steht.
        let erwartet = ["en": "Cancel", "es": "Cancelar",
                        "fr": "Annuler", "it": "Annulla"]
        for (sprache, soll) in erwartet {
            guard let weg = buendel.path(forResource: sprache,
                                         ofType: "lproj"),
                  let fremd = Bundle(path: weg) else {
                XCTFail("Kein \(sprache).lproj im Bündel.")
                continue
            }
            XCTAssertEqual(
                fremd.localizedString(forKey: probe, value: nil,
                                      table: nil),
                soll,
                "„\(probe)“ kommt auf \(sprache) nicht übersetzt heraus. "
                + "Wenn hier der deutsche Satz steht, ist der Katalog "
                + "nicht im Bündel oder der Schlüssel passt nicht.")
        }
    }

    func test_deutsch_bleibt_deutsch() {
        // Der Schlüssel IST der deutsche Satz. Trotzdem muss es eine
        // de.lproj geben: Ohne sie stünde Deutsch nicht in den
        // knownRegions, und ein deutsches Telefon bekäme die erste
        // Sprache der Liste -- also Englisch.
        guard let weg = buendel.path(forResource: "de", ofType: "lproj"),
              let deutsch = Bundle(path: weg) else {
            return XCTFail("Kein de.lproj im Bündel.")
        }
        XCTAssertEqual(
            deutsch.localizedString(forKey: probe, value: nil, table: nil),
            probe)
    }

    func test_ein_satz_mit_zahl_wird_richtig_gefuellt() {
        // Der Platzhalter ist die Stelle, an der es still schiefgeht:
        // `%@` statt `%lld` ergibt keinen Fehler, sondern Unsinn -- und
        // nur auf einem fremdsprachigen Gerät. Gemessen wird deshalb der
        // Katalogeintrag selbst, gefüllt wie zur Laufzeit.
        let muster = buendel.localizedString(forKey: "%lld Plays",
                                             value: nil, table: nil)
        XCTAssertEqual(String(format: muster, 3), "3 Plays")

        guard let weg = buendel.path(forResource: "it", ofType: "lproj"),
              let fremd = Bundle(path: weg) else {
            return XCTFail("Kein it.lproj im Bündel.")
        }
        // „schemi“, nicht „play“. Der Test stand hier auf „3 play“ --
        // aus der Zeit, als das Italienische das englische Wort
        // uebernahm. Inzwischen heisst es im ganzen Katalog
        // durchgaengig „schemi“, und die DURCHGAENGIGKEIT ist der
        // Punkt: Ein Playbook, in dem dieselbe Sache mal „play“ und mal
        // „schema“ heisst, liest sich wie zwei Programme.
        //
        // Gemessen wird ohnehin nicht das Wort, sondern dass die Zahl
        // richtig eingesetzt wird und der Satz aus dem
        // ITALIENISCHEN Buendel kommt.
        let italienisch = String(
            format: fremd.localizedString(forKey: "%lld Plays",
                                          value: nil, table: nil), 3)
        XCTAssertTrue(italienisch.hasPrefix("3 "),
                      "Die Zahl muss vorne stehen: \(italienisch)")
        XCTAssertNotEqual(italienisch, "3 Plays",
                          "Das waere der deutsche Satz -- dann greift "
                          + "das Buendel nicht.")
        XCTAssertEqual(italienisch, "3 schemi")
    }
}
