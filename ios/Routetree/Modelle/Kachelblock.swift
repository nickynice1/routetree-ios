import Foundation

/// Was auf einer Mannschaftskachel steht -- und in welcher Reihenfolge
/// die Kacheln liegen (R13).
///
/// **Warum das hier steht und nicht in der Ansicht.** Es gibt keinen
/// Mac. Eine Regel, die in einer SwiftUI-Ansicht steht, lässt sich hier
/// nicht ausprobieren, sondern nur behaupten, und eine Rückmeldung vom
/// Läufer dauert eine halbe Stunde. Dieselbe Entscheidung wie bei
/// `Kaderblock` (B9), `Zeichenblock` (B4) und `Kurve` (R7).
///
/// **Was hier NICHT entschieden wird: wie eine Kachel aussieht.** Das
/// ist Sache der Ansicht. Hier steht, WAS darauf steht: welches Bild,
/// welcher Untertitel, und dass hinter der letzten Mannschaft das Plus
/// liegt.
enum Kachelblock {

    // MARK: - Die Seiten

    /// Eine Seite im Kachelstapel.
    ///
    /// Das Plus ist eine SEITE und kein Knopf in der Ecke. Der Auftrag
    /// dazu (Niklas, 25.08.2026): „Und denn wenn man nach rechts wischt
    /// kann man aufs plus und noch eine Mannschaft hinzufügen." Auf
    /// einem großen Telefon ist die obere rechte Ecke die am schwersten
    /// erreichbare Stelle des Bildschirms; der Daumen liegt in der
    /// Mitte.
    enum Seite: Identifiable, Hashable {
        case mannschaft(Modell.Mannschaft)
        case hinzufuegen

        /// Stabil über das Neuladen hinweg: Die Kennung der Mannschaft,
        /// nicht ihre Stelle in der Liste. Sonst springt der Stapel auf
        /// eine andere Kachel, sobald jemand eine Mannschaft anlegt.
        var id: String {
            switch self {
            case .mannschaft(let team): return "team-\(team.id)"
            case .hinzufuegen: return "plus"
            }
        }
    }

    /// Die Mannschaften, und dahinter das Plus.
    ///
    /// **Immer dahinter, nie davor.** Wer die App aufmacht, will seine
    /// Mannschaft sehen und nicht ein Formular; die erste Kachel ist die
    /// erste Mannschaft.
    static func seiten(_ teams: [Modell.Mannschaft]) -> [Seite] {
        teams.map(Seite.mannschaft) + [.hinzufuegen]
    }

    // MARK: - Das Wappen

    /// Was im Wappen steht: das Logo, die Initialen oder ein Zeichen.
    enum Wappen: Equatable {
        case bild(URL)
        case initialen(String)
        /// Weder noch. Kommt vor, wenn ein älterer Server die Initialen
        /// nicht mitschickt -- dann steht dort ein Sinnbild und keine
        /// selbstgerechnete Abkürzung.
        case zeichen
    }

    /// **Die Initialen werden hier nicht gerechnet.** Sie stehen auf
    /// jedem Ausdruck (`printing._wappen` im Backend), und zwei Regeln
    /// für dieselbe Abkürzung heißen: Dieselbe Mannschaft heißt auf dem
    /// Blatt „RU" und im Telefon „RO", und niemand kann sagen, welche
    /// der beiden die richtige ist.
    static func wappen(_ team: Modell.Mannschaft) -> Wappen {
        if let bild = team.logo { return .bild(bild) }
        return ohneBild(team)
    }

    /// Was dasteht, wenn kein Bild da ist -- **auch dann, wenn es eines
    /// GIBT und es gerade nicht ankommt.**
    ///
    /// Am Spielfeldrand ohne Empfang ist genau das der Normalfall (R14).
    /// Ein leerer Kreis sähe dort aus wie ein Fehler der App; die
    /// Initialen stehen schon in der Antwort und brauchen keine zweite
    /// Anfrage.
    static func ohneBild(_ team: Modell.Mannschaft) -> Wappen {
        let kurz = team.initialen.trimmingCharacters(in: .whitespaces)
        return kurz.isEmpty ? .zeichen : .initialen(kurz)
    }

    // MARK: - Der Text

    /// „Griffins e. V. · Head Coach · 12 Leute · 2 Playbooks".
    ///
    /// Einzahl und Mehrzahl auseinandergehalten: „1 Leute" liest sich
    /// wie ein Fehler, und es ist einer.
    static func untertitel(_ team: Modell.Mannschaft) -> String {
        var teile = [team.verein.name]
        if let rolle = team.rolleText {
            teile.append(rolle)
        } else if team.istVereinsadmin {
            // Kein Mitglied und trotzdem hier: Ein Vereinsadmin sieht
            // jede Mannschaft seines Vereins. „Keine Rolle" wäre an
            // dieser Stelle eine Lücke, die aussieht wie ein Fehler.
            teile.append(String(localized: "Vereinsverwaltung"))
        }
        teile.append(team.mitglieder == 1
                     ? String(localized: "1 Person")
                     : String(localized: "\(team.mitglieder) Leute"))
        teile.append(team.playbooks == 1
                     ? String(localized: "1 Playbook")
                     : String(localized:
                        "\(team.playbooks) Playbooks"))
        return teile.joined(separator: " · ")
    }

    /// Der Hinweis unter dem Stapel, solange eine Mannschaft zu sehen
    /// ist. Auf der Plus-Kachel selbst wäre er falsch: Dort IST man
    /// schon.
    static let wischhinweis = String(localized:
        "Weiterwischen: noch eine Mannschaft")

    /// Ob der Hinweis überhaupt hingehört. Bei genau einer Mannschaft
    /// sagt er, was hinter der Kachel liegt -- ohne ihn sieht der
    /// Bildschirm aus, als gäbe es nur diese eine Seite.
    ///
    /// Gefragt wird nach der KENNUNG und nicht nach der Seite selbst:
    /// Die Ansicht merkt sich die Kennung, weil eine Mannschaft nach
    /// dem Neuladen ein anderer Wert mit denselben Daten ist -- und ein
    /// Stapel, der beim Aktualisieren auf die erste Kachel
    /// zurückspringt, hat den Trainer seine Stelle gekostet.
    static func zeigtWischhinweis(seiteId: String) -> Bool {
        seiteId != Seite.hinzufuegen.id
    }
}
