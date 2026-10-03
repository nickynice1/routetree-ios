import Foundation

/// Was auf dem Gerät liegen darf, wie es dort heißt, und wann die App
/// darauf zurückgreift (R14).
///
/// **Der Auftrag, wörtlich** (aus der Marktanalyse, 25.08.2026, über
/// einen Wettbewerber, 1 Stern im App Store):
///
///   „Sie sagt, ich hätte kein Internet. App gelöscht, neu geladen, WLAN
///   aus und wieder an -- kommt trotzdem nicht rein, und ich habe gutes
///   Internet."
///
/// **Warum das hier steht und nicht in der Ansicht oder im `Vorrat`.**
/// Es gibt keinen Mac. Eine Regel, die zwischen `FileManager`-Aufrufen
/// steht, lässt sich hier nicht ausprobieren, sondern nur behaupten --
/// und eine Rückmeldung vom Läufer dauert eine halbe Stunde. Dieselbe
/// Entscheidung wie bei `Kachelblock` (R13), `Kurve` (R7) und
/// `Griffe` (R11).
///
/// **Was hier NICHT passiert: keine Datei wird angefasst.** Das tut
/// `Vorrat`. Hier steht, WELCHE Antwort abgelegt werden darf, unter
/// welchem Namen, und WANN eine abgelegte hervorgeholt wird.
enum Vorratsblock {

    // MARK: - Was herauskommt

    /// Ein Wert und die Auskunft, woher er stammt.
    ///
    /// **`stand` ist die halbe Funktion.** Eine alte Kopie ohne Hinweis
    /// anzuzeigen ist schlimmer als ein Fehler: Der Trainer am Platz
    /// liest eine Aufstellung und weiß nicht, ob sie die von gestern
    /// ist. Deshalb kommt der Zeitpunkt mit heraus und nicht nur der
    /// Wert -- `nil` heißt „frisch vom Server", alles andere heißt „vom
    /// Gerät, und zwar von dann".
    struct Ausgabe<Wert> {
        let wert: Wert
        let stand: Date?

        var ausDemVorrat: Bool { stand != nil }
    }

    // MARK: - Was abgelegt werden darf

    /// Ob die Antwort auf diesen Weg auf dem Gerät liegen darf.
    ///
    /// **Eine Positivliste, und das ist die Entscheidung.** Eine
    /// Sperrliste wäre bequemer und wäre falsch: Der nächste Weg, den
    /// jemand hinzufügt, landete dann von selbst auf der Platte. Unter
    /// den Wegen dieser App sind Teamcode, Einladungen und
    /// Maschinenschlüssel -- das sind SCHLÜSSEL und kein Inhalt, und
    /// das Tablet im Vereinsheim reicht von Hand zu Hand. Was hier
    /// nicht ausdrücklich steht, bleibt auf dem Server.
    ///
    /// Abgelegt wird deshalb genau das, was „ansehen ohne Netz"
    /// braucht: die Heftliste, die Playliste eines Hefts, ein einzelner
    /// Play samt Zeichnung, und die Kategorien, nach denen die Liste
    /// ihre Abschnitte ordnet.
    static func gehoertInDenVorrat(_ weg: String) -> Bool {
        let pfad = weg.split(separator: "?", maxSplits: 1,
                             omittingEmptySubsequences: false)
            .first.map(String.init) ?? weg
        let teile = pfad.split(separator: "/").map(String.init)
        guard teile.count >= 3, teile[0] == "api", teile[1] == "v1" else {
            return false
        }
        let rest = Array(teile.dropFirst(2))
        if rest == ["playbooks"] { return true }
        if rest.count == 2, rest[0] == "plays", istZahl(rest[1]) {
            return true
        }
        if rest.count == 3, rest[0] == "playbooks", istZahl(rest[1]),
           rest[2] == "plays" || rest[2] == "kategorien" {
            return true
        }
        // DIE HILFE (B6). Sie enthält nichts, was jemandem gehört: keine
        // Namen, keine Playbooks, keine Zugänge -- nur die Abschnitte,
        // die der Server aus seinem eigenen Bestand zusammensetzt. Sie
        // liegt deshalb gefahrlos auf der Platte, und genau dort wird
        // sie gebraucht: Wer am Spielfeldrand nicht weiterkommt, hat oft
        // auch kein Netz.
        if rest == ["hilfe"] { return true }
        return false
    }

    private static func istZahl(_ text: String) -> Bool {
        !text.isEmpty && text.allSatisfy(\.isNumber)
    }

    // MARK: - Wie es auf dem Gerät heißt

    /// Der Dateiname zu einem Weg: lesbar, und trotzdem eindeutig.
    ///
    /// **Warum nicht nur „Schrägstriche durch Bindestriche".** Dann
    /// hießen `/a/b` und `/a-b` gleich. Heute enthält kein Weg dieser
    /// App einen Bindestrich, aber das ist eine Beobachtung und keine
    /// Regel -- und eine Kollision hier heißt, dass ein Play die
    /// Zeichnung eines anderen zeigt. Der lesbare Teil ist deshalb nur
    /// zum Nachsehen da; eindeutig macht ihn der Streuwert dahinter.
    static func dateiname(fuer weg: String) -> String {
        var lesbar = ""
        for zeichen in weg {
            lesbar.append(zeichen.isLetter || zeichen.isNumber ? zeichen : "-")
        }
        return "\(lesbar)-\(streuwert(weg)).json"
    }

    /// FNV-1a, von Hand.
    ///
    /// Bewusst ohne `CryptoKit` und ohne `hashValue`: Das eine ist ein
    /// Rahmenwerk für einen Dateinamen, das andere ist in Swift je
    /// Programmstart anders gesalzen -- ein Vorrat, dessen Namen sich
    /// beim nächsten Start ändern, ist kein Vorrat, sondern Müll auf
    /// der Platte.
    static func streuwert(_ text: String) -> String {
        var wert: UInt64 = 0xcbf2_9ce4_8422_2325
        for byte in Array(text.utf8) {
            wert = (wert ^ UInt64(byte)) &* 0x100_0000_01b3
        }
        return String(wert, radix: 16)
    }

    // MARK: - Wann der Vorrat einspringt

    /// Ob dieser Fehler „kein Netz" heißt.
    ///
    /// **Nur `Server.Fehler.netz`, und das ist eine enge Grenze mit
    /// Absicht.** Eine 401 heißt, dass die Anmeldung nicht mehr gilt --
    /// wer daraufhin die letzte Kopie zeigte, zeigte einem Menschen
    /// Plays, die ihm gerade weggenommen wurden. Eine 403 an der Grenze
    /// der Demo ist dasselbe in klein. Eine 429 heißt, dass der Server
    /// sehr wohl erreichbar ist. Und eine 500 heißt, dass etwas kaputt
    /// ist; wer sie hinter einer Kopie von gestern versteckt, merkt es
    /// nie.
    ///
    /// **Was hier bewusst NICHT dazugehört, obwohl es sich am Platz
    /// gleich anfühlt: das Anmeldeportal im WLAN der Sportanlage.** Es
    /// antwortet mit 200 und einer HTML-Seite; daraus wird
    /// `.server(text: "Die Antwort des Servers war nicht lesbar.")`.
    /// Diesen Fall hier mitzunehmen hieße, jeden echten
    /// Entschlüsselungsfehler hinter einer alten Kopie zu verstecken --
    /// und der fällt dann nie wieder auf. Er gehört gesondert erkannt
    /// und steht als eigener Punkt in der ROADMAP.
    static func ausDemVorrat(bei fehler: Error) -> Bool {
        guard let unserer = fehler as? Server.Fehler else { return false }
        if case .netz = unserer { return true }
        return false
    }

    /// Wie alt die Kopie ist -- in den drei Stufen, die ein Mensch
    /// unterscheidet.
    ///
    /// **Kein „zu alt".** Eine Kopie von letzter Woche ist am
    /// Spielfeldrand immer noch besser als ein leerer Bildschirm; die
    /// Plays eines Playbooks ändern sich in Wochen, nicht in Stunden.
    /// Was sie nicht sein darf, ist unbeschriftet -- deshalb gibt es
    /// hier eine Stufe und keine Schwelle.
    enum Naehe: Equatable {
        case heute
        case gestern
        case aelter
    }

    static func naehe(_ stand: Date, jetzt: Date,
                      kalender: Calendar = .current) -> Naehe {
        if kalender.isDate(stand, inSameDayAs: jetzt) { return .heute }
        guard let gestern = kalender.date(byAdding: .day, value: -1,
                                          to: jetzt) else { return .aelter }
        return kalender.isDate(stand, inSameDayAs: gestern) ? .gestern
                                                            : .aelter
    }

    // MARK: - Die Wege, an einer Stelle

    /// Der Weg zu einem Play -- **einmal geschrieben**.
    ///
    /// Stünde er in `Laden` ein zweites Mal, holte die App den Play
    /// unter einem Weg und suchte die Kopie unter einem anderen. Der
    /// Vorrat wäre dann voll und trotzdem leer, und zwar lautlos.
    static func wegFuerPlay(_ id: Int) -> String {
        "/api/v1/plays/\(id)/?svg=1"
    }

    static func wegFuerPlayliste(_ playbook: Int) -> String {
        "/api/v1/playbooks/\(playbook)/plays/"
    }

    static func wegFuerKategorien(_ playbook: Int) -> String {
        "/api/v1/playbooks/\(playbook)/kategorien/"
    }

    static let wegFuerHefte = "/api/v1/playbooks/"

    /// Die Hilfe, JE SPRACHE abgelegt.
    ///
    /// Der Server übersetzt sie, bevor er sie herausgibt (`gettext_lazy`
    /// wird beim Verpacken aufgelöst). Eine einzige Ablage hieße: Wer
    /// die Sprache wechselt, sieht offline weiter die alte -- und merkt
    /// nicht, warum.
    static func wegFuerHilfe(_ sprache: String) -> String {
        "/api/v1/hilfe/?sprache=\(sprache)"
    }

    // MARK: - Was noch fehlt

    /// Die Fassung, unter der eine Kopie abgelegt ist.
    ///
    /// Die Versionsnummer steht an jedem Play (`PlayKurz.version`) und
    /// zählt bei jeder Änderung hoch. Damit ist „ist meine Kopie noch
    /// die richtige" eine Frage mit einer genauen Antwort -- und nicht
    /// eine Frage nach dem Alter, die man nur schätzen kann.
    static func marke(version: Int) -> String { "v\(version)" }

    /// Welche Plays noch auf das Gerät müssen.
    ///
    /// **Warum überhaupt vorsorglich holen.** „Der zuletzt geöffnete
    /// Play liegt auf dem Gerät" nützt am Platz nichts: Dort will der
    /// Trainer den Play sehen, den er NICHT vorher aufgemacht hat. Also
    /// wird die ganze Liste geholt, solange noch Netz da ist.
    ///
    /// **Und warum nicht jedes Mal alle.** Ein Heft mit vierzig Plays
    /// wären vierzig Anfragen bei jedem Öffnen der Liste. Mit der
    /// Fassung daneben ist es beim zweiten Mal keine einzige.
    static func nachzuladen(_ plays: [Modell.PlayKurz],
                            marken: [Int: String]) -> [Int] {
        plays.filter { marken[$0.id] != marke(version: $0.version) }
             .map(\.id)
    }
}
