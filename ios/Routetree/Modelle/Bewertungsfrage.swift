import Foundation

/// Wann Routetree nach einer Bewertung fragt -- und wann nicht.
///
/// **Der Anlass** (30.09.2026). Nach fünf Wochen im Store hatte die App
/// **zwei** Bewertungen in Deutschland und **null** in den USA. Beim
/// Durchsuchen des Swift-Codes: kein einziges `requestReview`. Die App
/// hat nie gefragt.
///
/// Das ist nicht nur eine verpasste Höflichkeit. Apples Suche gewichtet
/// Bewertungen stark, und gemessen am selben Tag: Im US-Store stehen
/// dreizehn fremde Apps vor uns, wenn jemand „routetree" sucht -- also
/// unseren eigenen Namen. In Deutschland, mit zwei Bewertungen, stehen
/// wir dort auf Platz eins.
///
/// ## Die Regeln, und warum jede davon da ist
///
/// Eine Abfrage zur falschen Zeit ist schlimmer als keine: Sie
/// unterbricht, sie nervt, und sie erzeugt genau die Ein-Stern-Wertung,
/// die man vermeiden wollte. Deshalb:
///
/// * **Nur nach einem Erfolg.** Gezählt wird, was der Trainer wirklich
///   erreichen wollte: ein Playbook in der Hand, eine Übungsrunde
///   geschafft. Nie nach einem Fehler, nie mitten in einer Aufgabe.
/// * **Erst ab dem dritten Mal.** Wer einmal gedruckt hat, weiß noch
///   nicht, ob ihm das Programm hilft. Beim dritten Mal weiß er es.
/// * **Nicht in den ersten zwei Tagen.** Ein Mensch, der die App
///   gerade geladen hat, hat nichts zu bewerten.
/// * **Höchstens einmal je Fassung und höchstens alle 120 Tage.** Apple
///   deckelt ohnehin auf dreimal im Jahr und verschluckt alles darüber
///   STILL -- wer öfter fragt, verbrennt seine Gelegenheiten, ohne es
///   zu merken.
///
/// ## Was diese Datei NICHT tut
///
/// Sie zeigt nichts an. `requestReview` gehört in SwiftUI und braucht
/// eine Ansicht; hier steht nur die Entscheidung. So lässt sie sich
/// ohne Oberfläche prüfen -- `BewertungsfrageTests` tut das.
///
/// Und sie schickt nichts an uns. Was ein Mensch bei Apple schreibt,
/// erfahren wir über den Store, nicht über die App.
enum Bewertungsfrage {

    /// Was als Erfolg zählt.
    ///
    /// **Eine Aufzählung und kein freier Text**, damit die Liste an
    /// einer Stelle steht. Wer einen vierten Anlass findet, trägt ihn
    /// hier ein und sieht dabei die drei anderen.
    enum Erfolg: String {
        /// Ein Playbook ist gedruckt oder geteilt worden.
        case gedruckt
        /// Eine Übungsrunde ist zu Ende gespielt.
        case geuebt
        /// Ein fremdes Playbook ist eingelesen worden.
        case eingelesen
    }

    // MARK: - Die Schwellen

    /// Ab wie vielen Erfolgen gefragt wird.
    static let abErfolgen = 3
    /// Wie viele Tage nach der ersten Benutzung frühestens.
    static let nachTagen = 2.0
    /// Wie viele Tage zwischen zwei Fragen mindestens.
    static let abstandTage = 120.0

    // MARK: - Ablage
    //
    // `UserDefaults` und nicht der Schlüsselbund: Hier steht nichts,
    // was jemandem gehört -- eine Zählung und zwei Zeitpunkte. Der
    // Schlüsselbund ist für Token da (siehe `Netz/Anmeldung.swift`).

    private static let zaehler = "routetree.bewertung.erfolge"
    private static let ersterTag = "routetree.bewertung.erstmals"
    private static let zuletzt = "routetree.bewertung.gefragt"
    private static let fassung = "routetree.bewertung.fassung"

    /// Die laufende Fassung der App, wie sie im Store steht.
    static var jetzigeFassung: String {
        (Bundle.main.infoDictionary?["CFBundleShortVersionString"]
            as? String) ?? "?"
    }

    /// Wie viele Erfolge bisher gezählt sind.
    ///
    /// Mit `speicher`, damit eine Probe ihren eigenen Bereich
    /// mitgeben kann -- sonst müsste sie den Schlüssel abschreiben,
    /// und dann misst sie eine Zeichenkette statt der Zählung.
    static func erfolge(speicher: UserDefaults = .standard) -> Int {
        speicher.integer(forKey: zaehler)
    }

    // MARK: - Zählen

    /// Einen Erfolg merken.
    ///
    /// **Der erste Aufruf setzt auch den Anfangszeitpunkt.** Nicht der
    /// Programmstart: Wer die App lädt und drei Wochen liegen lässt,
    /// hat sie nicht benutzt, und die Zwei-Tage-Regel soll sich auf
    /// das Benutzen beziehen.
    static func merken(_ was: Erfolg,
                       speicher: UserDefaults = .standard,
                       jetzt: Date = Date()) {
        if speicher.object(forKey: ersterTag) == nil {
            speicher.set(jetzt.timeIntervalSince1970, forKey: ersterTag)
        }
        speicher.set(speicher.integer(forKey: zaehler) + 1, forKey: zaehler)
    }

    // MARK: - Entscheiden

    /// Soll jetzt gefragt werden?
    ///
    /// **Fragt NICHT.** Der Aufrufer zeigt die Abfrage und ruft danach
    /// `gefragt()`. Zwei Schritte, weil `requestReview` nicht sagt, ob
    /// es wirklich etwas gezeigt hat -- Apple entscheidet das selbst
    /// und schweigt darüber. Wer den Zähler erst bei einer wirklich
    /// gezeigten Abfrage zurücksetzte, wartete ewig.
    static func soll(speicher: UserDefaults = .standard,
                     jetzt: Date = Date()) -> Bool {
        guard speicher.integer(forKey: zaehler) >= abErfolgen else {
            return false
        }
        let anfang = speicher.double(forKey: ersterTag)
        guard anfang > 0,
              jetzt.timeIntervalSince1970 - anfang >= nachTagen * 86_400
        else { return false }

        // EINMAL JE FASSUNG. Wer nach dem Aktualisieren wieder etwas
        // Neues sieht, darf wieder gefragt werden -- aber nur einmal.
        if (speicher.string(forKey: fassung) ?? "") == jetzigeFassung {
            return false
        }
        let vorhin = speicher.double(forKey: zuletzt)
        if vorhin > 0,
           jetzt.timeIntervalSince1970 - vorhin < abstandTage * 86_400 {
            return false
        }
        return true
    }

    /// Festhalten, dass gefragt wurde.
    static func gefragt(speicher: UserDefaults = .standard,
                        jetzt: Date = Date()) {
        speicher.set(jetzt.timeIntervalSince1970, forKey: zuletzt)
        speicher.set(jetzigeFassung, forKey: fassung)
        speicher.set(0, forKey: zaehler)
    }

    /// Alles vergessen -- nur für Proben.
    static func zuruecksetzen(speicher: UserDefaults = .standard) {
        for s in [zaehler, ersterTag, zuletzt, fassung] {
            speicher.removeObject(forKey: s)
        }
    }
}
