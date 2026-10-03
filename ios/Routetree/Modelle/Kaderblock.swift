import Foundation

/// Was an einer Kaderzeile möglich ist -- und was nicht.
///
/// **Warum das hier steht und nicht in der Ansicht.** Es gibt keinen
/// Mac. Eine Regel, die in einer SwiftUI-Ansicht steht, lässt sich hier
/// nicht ausprobieren, sondern nur behaupten, und eine Rückmeldung vom
/// Läufer dauert eine halbe Stunde. Dieselbe Entscheidung wie bei
/// `Zeichenblock` (B4) und `Uebungsblock` (B8).
///
/// **Was hier NICHT entschieden wird: ob jemand etwas darf.** Das sagt
/// der Server, und zwar an jeder Zeile einzeln (`darfName`,
/// `letzterHead`) und an der Mannschaft (`darfFuehren`, `darfAendern`).
/// Hier wird nur zusammengesetzt, welche Knöpfe daraus folgen -- und
/// genau das ist die Stelle, an der eine Ansicht sonst ein `||` statt
/// eines `&&` bekommt und niemandem fällt es auf, weil der Knopf ja da
/// ist.
enum Kaderblock {

    /// Welche Knöpfe eine Zeile bekommt.
    struct Moeglichkeiten: Equatable {
        let rolleAendern: Bool
        let entfernen: Bool
        /// Selbst gehen (R110.11).
        ///
        /// **Getrennt von `entfernen`, obwohl beides dieselbe Anfrage
        /// schickt.** Es ist nicht dieselbe Handlung: Wer jemanden aus
        /// dem Kader nimmt, verwaltet; wer selbst geht, entscheidet
        /// über sich. Der Knopf heisst anders, die Rückfrage heisst
        /// anders, und danach steht man woanders -- nämlich nicht mehr
        /// in dieser Mannschaft.
        let austreten: Bool
        let umbenennen: Bool
        let aufgeben: Bool
        /// Warum nichts geht, wenn nichts geht. `nil` heißt: Es geht
        /// etwas. Der Satz steht da, weil eine Zeile ohne Knöpfe sonst
        /// aussieht wie eine, die noch lädt.
        let grund: String?
    }

    /// Der Satz am einzigen Head Coach. Er steht hier und nicht in der
    /// Ansicht, damit ihn ein Test lesen kann.
    static let einzigerHead =
        String(localized: """
            Der einzige Head Coach. Damit die Mannschaft verwaltbar bleibt, \
            ändert daran niemand etwas.
            """)

    static func moeglichkeiten(fuer zeile: Modell.Kadermitglied,
                               in team: Modell.Mannschaft) -> Moeglichkeiten {
        // Rolle und Entfernen: nur der Head Coach, und nie am letzten.
        // Der Server lehnt beides mit 409 ab -- die App zeigt es
        // deshalb gar nicht erst an.
        let fuehrt = team.darfFuehren && !zeile.letzterHead
        // SELBST GEHEN DARF JEDER (R110.11), und zwar auch, wer die
        // Mannschaft nicht führt. Bis zum 10.09.2026 musste man den
        // Head Coach darum bitten -- das ist keine
        // Verwaltungsentscheidung, sondern die eigene. Der Browser hat
        // dieselbe Lücke am 02.09.2026 geschlossen.
        //
        // NUR DER LETZTE HEAD COACH BLEIBT. Sonst stünde die
        // Mannschaft ohne jemanden da, der sie verwalten kann, und
        // niemand könnte sich selbst dazu machen. Der Server lehnt es
        // ohnehin ab (409); die App zeigt es deshalb gar nicht erst an.
        let austreten = zeile.ich && !zeile.letzterHead
        // Aufgeben kann der ganze Trainerstab, und nur wenn es
        // überhaupt Plays gibt. Ohne einen einzigen wäre die Seite eine
        // leere Liste mit einem Sichern-Knopf.
        let aufgeben = team.darfAendern && team.plays > 0
        let nichts = !fuehrt && !austreten && !zeile.darfName && !aufgeben
        return Moeglichkeiten(
            rolleAendern: fuehrt,
            // Die EIGENE Zeile bekommt „verlassen" und nicht „aus dem
            // Kader nehmen". Zwei Knöpfe nebeneinander, die dasselbe
            // tun, wären eine Frage, die niemand stellen wollte.
            entfernen: fuehrt && !zeile.ich,
            austreten: austreten,
            umbenennen: zeile.darfName,
            aufgeben: aufgeben,
            grund: nichts && zeile.letzterHead && team.darfFuehren
                ? einzigerHead : nil)
    }

    /// Was am Knopf steht: „Plays aufgeben" oder „Aufgabe ändern".
    ///
    /// Derselbe Unterschied wie im Browser. Er ist keine Kosmetik: „Plays
    /// aufgeben" bei jemandem, der schon sechs aufhat, liest sich, als
    /// würde man von vorn anfangen.
    static func aufgabenknopf(fuer zeile: Modell.Kadermitglied) -> String {
        (zeile.fortschritt?.ausAuftrag ?? false)
            ? String(localized: "Aufgabe ändern")
            : String(localized: "Plays aufgeben")
    }

    /// „Head Coach · dabei seit 24. August 2026".
    ///
    /// Ohne Datum nur die Rolle -- leer heißt „nie aufgeschrieben", und
    /// „dabei seit —" sähe aus wie ein Fehler.
    static func unterzeile(_ zeile: Modell.Kadermitglied) -> String {
        var teile = [zeile.letzterHead
                        ? String(localized: """
                            \(zeile.rolleText). Der einzige, deshalb \
                            unveränderlich.
                            """)
                        : zeile.rolleText]
        if let seit = zeile.seit {
            teile.append(String(localized:
                "dabei seit \(tagform.string(from: seit))"))
        }
        return teile.joined(separator: " · ")
    }

    /// **Kein festes `de_DE` mehr (R22).** Es stand hier, solange die App
    /// nur Deutsch konnte; jetzt hieße es „24. August 2026" auf einem
    /// englischen Telefon -- ein deutscher Monatsname mitten in einem
    /// englischen Satz. `setLocalizedDateFormatFromTemplate` nimmt
    /// dieselben drei Bestandteile und ordnet sie so, wie die Sprache es
    /// tut: „August 24, 2026" statt „24. August 2026".
    private static let tagform: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale.autoupdatingCurrent
        f.setLocalizedDateFormatFromTemplate("dMMMMy")
        return f
    }()
}

/// Die Auswahl beim Aufgeben (A7) -- angehakt, abgehakt, geändert.
///
/// **Die Entscheidung, an der hier alles hängt: eine Absendung bedeutet
/// den VOLLSTÄNDIGEN Stand.** Was nicht angehakt ist, ist nicht
/// aufgegeben. Deshalb schickt die App eine Liste und keine zwei
/// (`dazu`, `weg`): Zwei Listen wären zwei Gelegenheiten, das Wegnehmen
/// zu vergessen, und dann sammeln sich Aufträge an, die niemand mehr
/// loswird -- lautlos, denn eine Kreuzchenliste zeigt nicht, was sie
/// nicht zeigt.
///
/// **Und nichts wird gesichert, was sich nicht geändert hat.** Wer eine
/// Aufgabe nur ansieht, soll nicht als „hat neu aufgegeben" dastehen:
/// `angelegt_am` beantwortet „seit wann muss ich das".
struct Aufgabenblock: Equatable {

    /// Wie es beim Öffnen aussah. Daran wird „geändert" gemessen.
    let anfang: Set<Int>
    private(set) var angehakt: Set<Int>

    init(blatt: Modell.Aufgabenblatt) {
        let start = Set(blatt.hefte.flatMap(\.plays)
                            .filter(\.angehakt).map(\.id))
        anfang = start
        angehakt = start
    }

    /// Nur für Tests.
    init(anfang: Set<Int>) {
        self.anfang = anfang
        self.angehakt = anfang
    }

    var anzahl: Int { angehakt.count }
    var geaendert: Bool { angehakt != anfang }
    /// In fester Reihenfolge, damit zwei gleiche Auswahlen dieselbe
    /// Anfrage ergeben -- eine Menge hat keine.
    var alsListe: [Int] { angehakt.sorted() }

    func istAngehakt(_ id: Int) -> Bool { angehakt.contains(id) }

    mutating func umschalten(_ id: Int) {
        if angehakt.contains(id) {
            angehakt.remove(id)
        } else {
            angehakt.insert(id)
        }
    }

    /// Ein ganzes Heft an- oder abhaken.
    ///
    /// **Nur dieses Heft.** Der Reflex wäre, „alles abwählen" auf die
    /// ganze Liste zu legen; dann nähme ein Coach, der bei der Offense
    /// aufräumt, nebenbei die Defense-Aufgaben mit weg.
    mutating func heft(_ heft: Modell.Aufgabenblatt.Heft, an: Bool) {
        for eintrag in heft.plays {
            if an { angehakt.insert(eintrag.id) } else {
                angehakt.remove(eintrag.id)
            }
        }
    }

    func heftIstGanzAn(_ heft: Modell.Aufgabenblatt.Heft) -> Bool {
        !heft.plays.isEmpty && heft.plays.allSatisfy {
            angehakt.contains($0.id)
        }
    }

    /// Alles abwählen. Danach wird wieder aus dem ganzen Playbook geübt
    /// -- das ist eine Entscheidung und kein Versehen, deshalb steht sie
    /// als eigener Weg da und nicht als „einzeln alle abhaken".
    mutating func alleAus() {
        angehakt.removeAll()
    }
}
