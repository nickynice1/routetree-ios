import Foundation

/// Wonach beim Beitritt gefragt wird: nach einem Namen oder nach einem
/// Kürzel (R24).
///
/// **Der Auftrag, wörtlich:** Niklas am 25.08.2026: „können wir doch ein
/// seperates schülerlizenz modul machen wo wirklich kein schüler den
/// namen angeben muss weißt du? sondern einfach teamcode bekommt und
/// direkt drin ist."
///
/// **Warum das eine eigene Datei ist.** Aus demselben Grund wie
/// `Kachelblock` (R13), `Vorratsblock` (R14) und `Kurve` (R7): In einer
/// SwiftUI-Ansicht ließe sich diese Regel ohne Mac nicht messen,
/// sondern nur behaupten. Hier steht, WAS gefragt wird; wie es aussieht,
/// steht in `BeitretenAnsicht`.
///
/// **Und entschieden wird es vom SERVER, nicht hier.** Ob eine
/// Mannschaft zu einer Schule gehört, steht im Zustand ihres Vereins.
/// Diese Datei rechnet das nicht nach -- sie liest `auskunft.kuerzel`.
/// Eine zweite Regel in Swift sähe nie falsch aus, sondern nur nach
/// einem anderen Formular; dieselbe Begründung wie bei der Gewichtung
/// des Lernmodus (B8).
enum Kadernameblock {

    /// Höchstlänge eines Kürzels. Dieselbe Zahl wie `schule.KUERZEL_MAX`
    /// auf dem Server, und `test_schulantrag.py` hält beide
    /// gegeneinander: Ein Feld, in das man zehn Zeichen tippt, von denen
    /// drei ankommen, ist schlimmer als eines, das bei dreien aufhört --
    /// die Kürzung passiert am Server und wird erst beim nächsten Laden
    /// sichtbar. Dieselbe Lehre wie bei den Rollenfeldern aus R9.
    ///
    /// Sie steht hier als Rückfall für den Fall, dass eine ältere
    /// Fassung des Servers das Feld nicht mitschickt.
    static let kuerzelMax = 3

    /// Was auf dem Beitrittsblatt steht.
    struct Feld: Equatable {
        let aufschrift: String
        let hilfe: String
        /// Muss etwas dastehen? In einer Schule nicht -- das ist der
        /// ganze Punkt von R24.
        let pflicht: Bool
        let hoechstens: Int
        /// Womit das Feld vorbelegt wird. In einer Schule LEER, auch
        /// wenn der Server einen Vorschlag mitschickt: Ein
        /// ausgefülltes Feld ist die Stelle, an der die Namensfreiheit
        /// still aufhört.
        let vorbelegung: String
    }

    static func feld(fuer auskunft: Modell.Codeauskunft) -> Feld {
        if auskunft.kuerzel {
            return Feld(
                aufschrift: String(localized: "Kürzel (freiwillig)"),
                hilfe: String(localized: """
                    Das hier ist eine Schulmannschaft. Deinen Namen musst du \
                    nicht angeben: Ein Kürzel reicht, damit deine Lehrkraft \
                    dich ansprechen kann, und leer lassen darfst du es auch.
                    """),
                pflicht: false,
                hoechstens: max(1, auskunft.kuerzelMax),
                vorbelegung: "")
        }
        return namensfeld(vorbelegung: auskunft.namensvorschlag)
    }

    /// Was gefragt wird, solange der Server noch nichts gesagt hat.
    ///
    /// **Auf dem Blatt „Konto anlegen" steht das Feld schon da, bevor
    /// ein Code vollständig getippt ist** (R24). Dann gilt der
    /// VORSICHTIGE Fall: Name ist Pflicht. Ein Name zu viel ist ein
    /// Ärgernis, ein Name zu wenig eine Mitgliedschaft ohne
    /// Kadereintrag -- dieselbe Richtung, die `Codeauskunft.kuerzel`
    /// schon für eine ältere Serverfassung wählt.
    ///
    /// Und keine Vorbelegung: Es gibt noch kein Konto, aus dem ein Name
    /// käme.
    static var feldOhneAuskunft: Feld { namensfeld(vorbelegung: "") }

    /// Der Namensfall, an EINER Stelle. Zwei Fassungen davon liefen
    /// beim nächsten geänderten Satz auseinander, und die Ansicht
    /// zeigte dann je nach Weg einen anderen Hilfetext.
    private static func namensfeld(vorbelegung: String) -> Feld {
        Feld(
            aufschrift: String(localized: "Dein Name im Team"),
            hilfe: String(localized: """
                So stehst du im Kader dieser Mannschaft. Der Coach sieht \
                diesen Namen, nicht deinen Benutzernamen.
                """),
            pflicht: true,
            hoechstens: 60,
            vorbelegung: vorbelegung)
    }

    /// Darf der Knopf „Beitreten" gedrückt werden?
    ///
    /// Zwei Fälle, und der zweite ist der neue: Ein Name muss dastehen,
    /// ein Kürzel darf fehlen -- aber wenn eines dasteht, muss es eines
    /// SEIN. „Lisa Meier" ist keins, und der Server lehnte es ohnehin
    /// ab; ein Knopf, der eine Absage auswirft, ist ein kaputter Knopf.
    static func darfAbsenden(_ eingabe: String, feld: Feld) -> Bool {
        let text = eingabe.trimmingCharacters(in: .whitespaces)
        if text.isEmpty { return !feld.pflicht }
        if feld.pflicht { return true }
        return text.count <= feld.hoechstens
            && !text.contains(" ")
    }
}
